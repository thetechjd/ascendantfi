// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract VestingContract {
    // ERC-20 token contract address
    address public tokenAddress;
    address public owner; // Contract owner

    // Vesting schedule data structure
    struct VestingSchedule {
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 initialUnlockPercent; // Initial unlock percentage (e.g., 5% as 5)
        uint256 totalAmount; // Total amount of tokens to vest
        uint256 amountVested; // Amount already vested
        uint256 lastClaimTime; // Time of last token claim
    }

    // Mapping of beneficiary addresses to their vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // Event emitted when tokens are vested
    event TokensVested(address indexed beneficiary, uint256 amount);

    // Constructor function, sets the owner of the contract
    constructor(address _tokenAddress) {
        owner = msg.sender;
        tokenAddress = _tokenAddress;
        initializeVestingSchedules();
    }

    // Modifier for functions restricted to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Function to set up the vesting schedules for each allocation
    function initializeVestingSchedules() internal onlyOwner {
        // Seed round
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with seed round beneficiary address
            block.timestamp, // Start time (current time)
            0, // No cliff period
            20 * 30 * 24 * 60 * 60, // Vesting duration (20 months in seconds)
            5, // Initial unlock percentage (5% as integer)
            2300000000 // Total amount of tokens for seed round (23% of total supply)
        );

        // Presale 1
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with presale 1 beneficiary address
            block.timestamp,
            0,
            18 * 30 * 24 * 60 * 60, // Vesting duration (18 months)
            10, // Initial unlock percentage (10% as integer)
            1500000000 // Total amount of tokens for presale 1
        );

        // Presale 2
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with presale 2 beneficiary address
            block.timestamp,
            0,
            15 * 30 * 24 * 60 * 60, // Vesting duration (15 months)
            15, // Initial unlock percentage (15% as integer)
            1500000000 // Total amount of tokens for presale 2
        );

        // Public round
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with public round beneficiary address
            block.timestamp,
            0,
            12 * 30 * 24 * 60 * 60, // Vesting duration (12 months)
            15, // Initial unlock percentage (15% as integer)
            200000000 // Total amount of tokens for public round
        );

        // Team tokens
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with team beneficiary address
            block.timestamp + 6 * 30 * 24 * 60 * 60, // Start time (6 months lock period)
            6 * 30 * 24 * 60 * 60, // Cliff duration (6 months)
            25 * 30 * 24 * 60 * 60, // Vesting duration (25 months)
            0, // No initial unlock
            1000000000 // Total amount of tokens for team
        );

        // Marketing and development tokens
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with marketing & development beneficiary address
            block.timestamp,
            0,
            36 * 30 * 24 * 60 * 60, // Vesting duration (36 months)
            0, // No initial unlock
            1500000000 // Total amount of tokens for marketing and development
        );

        // Staking rewards tokens
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with staking rewards beneficiary address
            block.timestamp,
            0,
            10 * 30 * 24 * 60 * 60, // Vesting duration (10 months)
            0, // No initial unlock
            1200000000 // Total amount of tokens for staking rewards
        );

        // Ecosystem tokens
        addVestingSchedule(
            0x0000000000000000000000000000000000000000, // Replace with ecosystem beneficiary address
            block.timestamp,
            12 * 30 * 24 * 60 * 60, // Cliff duration (12 months)
            25 * 30 * 24 * 60 * 60, // Vesting duration (25 months)
            25, // Initial unlock percentage (25% as integer)
            2280000000 // Total amount of tokens for ecosystem
        );
    }

    // Function to add a vesting schedule
    function addVestingSchedule(
        address _beneficiary,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        uint256 _initialUnlockPercent,
        uint256 _totalAmount
    ) internal onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_totalAmount > 0, "Total amount must be greater than zero");
        require(vestingSchedules[_beneficiary].totalAmount == 0, "Vesting schedule already exists");

        VestingSchedule memory schedule;
        schedule.startTime = _startTime;
        schedule.cliffDuration = _cliffDuration;
        schedule.vestingDuration = _vestingDuration;
        schedule.initialUnlockPercent = _initialUnlockPercent;
        schedule.totalAmount = _totalAmount;
        schedule.amountVested = 0;
        schedule.lastClaimTime = _startTime;

        vestingSchedules[_beneficiary] = schedule;
    }

    // Function to claim vested tokens
    function claimVestedTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];

        // Check if the beneficiary has a vesting schedule
        require(schedule.totalAmount > 0, "No vesting schedule found");

        // Calculate the time since the start of the vesting schedule
        uint256 currentTime = block.timestamp;
        require(currentTime > schedule.startTime + schedule.cliffDuration, "Vesting cliff not passed");

        // Calculate the vested amount
        uint256 vestedAmount = calculateVestedAmount(schedule, currentTime);

        // Check if there are any vested tokens to claim
        require(vestedAmount > 0, "No tokens available for claim");

        // Update the schedule and transfer the tokens
        schedule.amountVested += vestedAmount;
        schedule.lastClaimTime = currentTime;

        // Transfer the vested tokens to the beneficiary
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(msg.sender, vestedAmount);
        require(success, "Token transfer failed");

        // Emit event
        emit TokensVested(msg.sender, vestedAmount);
    }

    // Function to calculate the vested amount at a given time
    function calculateVestedAmount(VestingSchedule storage schedule, uint256 currentTime) internal view returns (uint256) {
        // Calculate the elapsed time since the start of the vesting schedule
        uint256 elapsedTime = currentTime - schedule.startTime;

        // Calculate the total vested amount based on the vesting duration
        uint256 totalVested = schedule.totalAmount * elapsedTime / schedule.vestingDuration;

        // Calculate the amount already vested
        uint256 alreadyVested = schedule.amountVested;

        // Calculate the available vested amount
        uint256 vestedAmount = totalVested - alreadyVested;

        // Return the vested amount
        return vestedAmount;
    }

    // Function to pause the contract (disable claiming of tokens)
    function pause() external onlyOwner {
        // Add logic to pause the contract if necessary
    }

    // Function to unpause the contract (enable claiming of tokens)
    function unpause() external onlyOwner {
        // Add logic to unpause the contract if necessary
    }

    // Function for emergency withdrawal of tokens (by owner only)
    function emergencyWithdrawal(uint256 amount) external onlyOwner {
        // Withdraw tokens from the contract
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(owner, amount);
        require(success, "Token withdrawal failed");
    }

    // Function to change the contract owner
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }
}
