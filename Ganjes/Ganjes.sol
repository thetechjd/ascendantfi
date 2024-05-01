// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GANJESToken is ERC20, Ownable {
    constructor(uint256 _TOTAL_SUPPLY) Ownable(msg.sender) ERC20("GANJES Token", "GANJES") {
        // Total supply of 3.33 billion tokens
        _TOTAL_SUPPLY = _TOTAL_SUPPLY * (10 ** decimals());

        // Transfer the total supply to the contract's owner
        _mint(msg.sender, _TOTAL_SUPPLY);
    }
}


contract  GANJESVesting {
    // using SafeERC20 for IERC20;
    GANJESToken public token;
    // IERC20 public token;
    mapping(address => VestingWallet) public vestingWallets;


    

    function startBackersVesting(address _backersAddress, uint64 backersDuration) internal {
        require(_backersAddress != address(0), "Address cannot be zero");

        vestingWallets[_backersAddress] = new VestingWallet(
            _backersAddress,
            uint64(block.timestamp),
            backersDuration
        );
    }

    function fundVestingWallet(address beneficiary, uint256 amount, address ICOContract, uint duration) internal {
        require(msg.sender == address(ICOContract), "Only ICO contract can fund");
        VestingWallet wallet = vestingWallets[beneficiary];
        require(address(wallet) != address(0), "Vesting wallet does not exist");
        startBackersVesting(beneficiary, uint64(duration));
        token.transferFrom(ICOContract, address(wallet), amount);
    }

    function tokensRelease(address beneficiary) internal  {
        VestingWallet wallet = vestingWallets[beneficiary];
        require(address(wallet) != address(0), "Not eligible to claim");
        if (block.timestamp >= wallet.start() + wallet.duration()) {
            uint256 amount = wallet.releasable();
            require(amount>0, "Tokens Not Enough");
            wallet.release();
        }
    }
}

contract GANJESICO is ReentrancyGuard, GANJESVesting, Ownable {

    uint256 public tokenPrice;
    uint256 public tokensSold;
    uint256 public maxPurchase;
    uint256 public balanceGanjes;
    address public tokenAddress;
    uint64 public vestingDurationCurrent;
    
    
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event TokensPurchased(address indexed buyer, uint256 amount);

    constructor (uint256 _tokenSupply,uint256 _tokenPrice) payable Ownable(msg.sender)  {
        token = new GANJESToken(_tokenSupply);
        tokenPrice = _tokenPrice;
        maxPurchase = (token.totalSupply() * 33 / 100) * 10 / 100;
        balanceGanjes=token.balanceOf(address(this));
        tokenAddress=address(token);
        vestingDurationCurrent=6*30 days;
    }

   


    function buyTokens(uint256 _numberOfTokens) external payable nonReentrant {
        require(msg.value == _numberOfTokens * tokenPrice, "Incorrect Ether sent");
        require(token.balanceOf(address(this)) >= _numberOfTokens, "Not enough tokens in the contract");
        require(_numberOfTokens <= maxPurchase, "You can't buy more than the maximum allowed");
        
        tokensSold += _numberOfTokens;
        fundVestingWallet(msg.sender, _numberOfTokens, address(this), vestingDurationCurrent);

        emit TokensPurchased(msg.sender, _numberOfTokens);
    }

    function releaseVestedTokens(address beneficiary) external {
        require(beneficiary != address(0), "Invalid Address");
        tokensRelease(beneficiary);

    }

    function setVestingDuration(uint64 durationInMonths) external onlyOwner {
        vestingDurationCurrent=durationInMonths*30 days;
    }

    function endSale() external onlyOwner nonReentrant {
        require(token.transfer(msg.sender, token.balanceOf(address(this))), "Unable to transfer tokens to admin");
    }
}

