// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// Interface for wrapped native token
interface IWrappedNativeToken {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

// Interface for ERC20 tokens
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

/**
 * @title PredictionGame
 * @dev A prediction game contract similar to PancakeSwap's prediction game
 * Users can bet on whether the price will go UP or DOWN in the next round
 * Uses wrapped native tokens for all transactions
 */
contract PredictionGame is 
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    enum Position {
        Bull, // UP
        Bear // DOWN
    }

    enum Status {
        Pending, // Round is open for bets
        Live, // Round is live, no more bets
        Ended // Round has ended, ready for next round
    }

    struct Round {
        uint256 epoch;
        address asset;
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 endTimestamp;
        int256 lockPrice;
        int256 endPrice;
        uint256 totalAmount;
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        bool oracleCalled;
        Status status;
    }

    struct BetInfo {
        Position position;
        uint256 amount;
        bool claimed; // default false
    }

    // paymentTokenAddress => gameTokenAddress => epochNum => Round
    mapping(address => mapping(address => mapping(uint256 => Round)))
        public rounds;
    // paymentTokenAddress => gameTokenAddress => epochNum => userAddress => BetInfo
    mapping(address => mapping(address => mapping(uint256 => mapping(address => BetInfo))))
        public ledger;
    // paymentTokenAddress => gameTokenAddress => userAddress => uint256[]
    mapping(address => mapping(address => mapping(address => uint256[])))
        public userRounds;

    // paymentTokenAddress => gameTokenAddress => currentEpoch
    mapping(address => mapping(address => uint256)) public currentEpoch;
    // paymentTokenAddress => minBetAmount
    mapping(address => uint256) public minBetAmount;
    uint256 public intervalSeconds = 300; // 5 minutes
    uint256 public treasuryFee = 300; // 3%
    uint256 public constant MAX_TREASURY_FEE = 1000; // 10%

    address public operatorAddress;
    address public treasuryAddress;
    address public wrappedNativeToken;

    // paymentTokenAddress => treasuryAmount
    mapping(address => uint256) public treasuryAmount;
    uint256 public constant TOTAL_RATE = 10000; // 100%


    event BetBull(
        address indexed sender,
        address indexed paymentToken,
        address indexed gameToken,
        uint256 epoch,
        uint256 amount
    );
    event BetBear(
        address indexed sender,
        address indexed paymentToken,
        address indexed gameToken,
        uint256 epoch,
        uint256 amount
    );
    event Claim(
        address indexed sender,
        address indexed paymentToken,
        address indexed gameToken,
        uint256 epoch,
        uint256 amount
    );
    event EndRound(
        uint256 indexed epoch,
        address indexed paymentToken,
        address indexed gameToken,
        int256 price
    );
    event LockRound(
        uint256 indexed epoch,
        address indexed paymentToken,
        address indexed gameToken,
        int256 price
    );
    event NewAdminAddress(address admin);
    event NewBufferAndIntervalSeconds(
        uint256 bufferSeconds,
        uint256 intervalSeconds
    );
    event NewMinBetAmount(
        address indexed paymentTokenAddress,
        uint256 minBetAmount
    );
    event NewTreasuryFee(uint256 indexed epoch, uint256 treasuryFee);
    event NewOperatorAddress(address operator);
    event NewOracle(address oracle);
    event NewOracleUpdateAllowance(uint256 oracleUpdateAllowance);
    event Pause(uint256 indexed epoch);
    event RewardsCalculated(
        uint256 indexed epoch,
        address indexed paymentToken,
        address indexed gameToken,
        uint256 rewardBaseCalAmount,
        uint256 rewardAmount,
        uint256 treasuryAmount
    );
    event StartRound(
        uint256 indexed epoch,
        address indexed paymentToken,
        address indexed gameToken
    );
    event TokenRecovery(address indexed token, uint256 amount);
    event TreasuryClaim(address indexed paymentToken, uint256 amount);
    event Unpause(uint256 indexed epoch);

    modifier onlyAdminOrOperator() {
        require(
            msg.sender == owner() || msg.sender == operatorAddress,
            "Not operator/admin"
        );
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }


    /**
     * @notice Initialize function (replaces constructor for upgradeable contracts)
     * @param _operatorAddress: operator address
     * @param _treasuryAddress: treasury address
     * @param _wrappedNativeToken: wrapped native token address
     * @param _intervalSeconds: number of seconds for valid execution of a prediction round
     * @param _treasuryFee: treasury fee (1000 = 10%)
     */
    function initialize(
        address _operatorAddress,
        address _treasuryAddress,
        address _wrappedNativeToken,
        uint256 _intervalSeconds,
        uint256 _treasuryFee
    ) public initializer {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");
        require(
            _wrappedNativeToken != address(0),
            "Wrapped token address cannot be zero"
        );

        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();

        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;
        wrappedNativeToken = _wrappedNativeToken;
        intervalSeconds = _intervalSeconds;
        treasuryFee = _treasuryFee;
    }

    /**
     * @notice Bet bull position
     * @param paymentTokenAddress: payment token address (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to bet on
     * @param epoch: epoch
     * @param amount: amount of payment tokens to bet (0 for native tokens, will use msg.value)
     */
    function betBull(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch,
        uint256 amount
    ) external payable whenNotPaused nonReentrant {
        require(
            epoch == currentEpoch[paymentTokenAddress][gameTokenAddress],
            "Bet is too early/late"
        );
        require(
            bettable(paymentTokenAddress, gameTokenAddress, epoch),
            "Round not bettable"
        );

        uint256 betAmount;
        if (paymentTokenAddress == wrappedNativeToken) {
            // Native token payment
            require(
                msg.value >= minBetAmount[paymentTokenAddress],
                "Bet amount must be greater than minBetAmount"
            );
            betAmount = msg.value;
            // Wrap native tokens - this mints wrapped tokens to this contract
            IWrappedNativeToken(wrappedNativeToken).deposit{value: betAmount}();
        } else {
            // ERC20 token payment
            require(
                amount >= minBetAmount[paymentTokenAddress],
                "Bet amount must be greater than minBetAmount"
            );
            betAmount = amount;
            // Transfer ERC20 tokens from user to this contract
            IERC20(paymentTokenAddress).transferFrom(
                msg.sender,
                address(this),
                betAmount
            );
        }

        // Allow multiple bets - check if user already has a bet with different position
        BetInfo storage existingBet = ledger[paymentTokenAddress][gameTokenAddress][epoch][msg.sender];
        require(
            existingBet.amount == 0 || existingBet.position == Position.Bull,
            "Cannot bet on different position in same round"
        );

        // Update round data
        Round storage round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];
        round.totalAmount = round.totalAmount + betAmount;
        round.bullAmount = round.bullAmount + betAmount;

        // Update user data
        BetInfo storage betInfo = ledger[paymentTokenAddress][gameTokenAddress][
            epoch
        ][msg.sender];
        betInfo.position = Position.Bull;
        betInfo.amount = betInfo.amount + betAmount;
        
        // Only add to userRounds if this is the first bet for this round
        if (betInfo.amount == betAmount) {
            userRounds[paymentTokenAddress][gameTokenAddress][msg.sender].push(
                epoch
            );
        }

        emit BetBull(
            msg.sender,
            paymentTokenAddress,
            gameTokenAddress,
            epoch,
            betAmount
        );
    }

    /**
     * @notice Bet bear position
     * @param paymentTokenAddress: payment token address (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to bet on
     * @param epoch: epoch
     * @param amount: amount of payment tokens to bet (0 for native tokens, will use msg.value)
     */
    function betBear(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch,
        uint256 amount
    ) external payable whenNotPaused nonReentrant {
        require(
            epoch == currentEpoch[paymentTokenAddress][gameTokenAddress],
            "Bet is too early/late"
        );
        require(
            bettable(paymentTokenAddress, gameTokenAddress, epoch),
            "Round not bettable"
        );

        uint256 betAmount;
        if (paymentTokenAddress == wrappedNativeToken) {
            // Native token payment
            require(
                msg.value >= minBetAmount[paymentTokenAddress],
                "Bet amount must be greater than minBetAmount"
            );
            betAmount = msg.value;
            // Wrap native tokens for the user
            IWrappedNativeToken(wrappedNativeToken).deposit{value: betAmount}();
        } else {
            // ERC20 token payment
            require(
                amount >= minBetAmount[paymentTokenAddress],
                "Bet amount must be greater than minBetAmount"
            );
            betAmount = amount;
            // Transfer ERC20 tokens from user to this contract
            IERC20(paymentTokenAddress).transferFrom(
                msg.sender,
                address(this),
                betAmount
            );
        }

        // Allow multiple bets - check if user already has a bet with different position
        BetInfo storage existingBet = ledger[paymentTokenAddress][gameTokenAddress][epoch][msg.sender];
        require(
            existingBet.amount == 0 || existingBet.position == Position.Bear,
            "Cannot bet on different position in same round"
        );

        // Update round data
        Round storage round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];
        round.totalAmount = round.totalAmount + betAmount;
        round.bearAmount = round.bearAmount + betAmount;

        // Update user data
        BetInfo storage betInfo = ledger[paymentTokenAddress][gameTokenAddress][
            epoch
        ][msg.sender];
        betInfo.position = Position.Bear;
        betInfo.amount = betInfo.amount + betAmount;
        
        // Only add to userRounds if this is the first bet for this round
        if (betInfo.amount == betAmount) {
            userRounds[paymentTokenAddress][gameTokenAddress][msg.sender].push(
                epoch
            );
        }

        emit BetBear(
            msg.sender,
            paymentTokenAddress,
            gameTokenAddress,
            epoch,
            betAmount
        );
    }

    /**
     * @notice Claim reward for an array of epochs
     * @param paymentTokenAddress: payment token address to claim (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to claim for
     * @param epochs: array of epochs
     */
    function claim(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256[] calldata epochs
    ) external nonReentrant {
        uint256 reward; // Initializes reward

        for (uint256 i = 0; i < epochs.length; i++) {
            require(
                rounds[paymentTokenAddress][gameTokenAddress][epochs[i]]
                    .startTimestamp != 0,
                "Round has not started"
            );
            require(
                block.timestamp >
                    rounds[paymentTokenAddress][gameTokenAddress][epochs[i]]
                        .endTimestamp,
                "Round has not ended"
            );

            uint256 addedReward = 0;

            // Round valid, claim rewards
            if (
                rounds[paymentTokenAddress][gameTokenAddress][epochs[i]]
                    .oracleCalled
            ) {
                require(
                    claimable(
                        paymentTokenAddress,
                        gameTokenAddress,
                        epochs[i],
                        msg.sender
                    ),
                    "Not eligible for claim"
                );
                Round memory round = rounds[paymentTokenAddress][
                    gameTokenAddress
                ][epochs[i]];
                addedReward =
                    (ledger[paymentTokenAddress][gameTokenAddress][epochs[i]][
                        msg.sender
                    ].amount * round.rewardAmount) /
                    round.rewardBaseCalAmount;
            }
            // Round invalid, refund bet amount
            else {
                require(
                    refundable(
                        paymentTokenAddress,
                        gameTokenAddress,
                        epochs[i],
                        msg.sender
                    ),
                    "Not eligible for refund"
                );
                addedReward = ledger[paymentTokenAddress][gameTokenAddress][
                    epochs[i]
                ][msg.sender].amount;
            }

            ledger[paymentTokenAddress][gameTokenAddress][epochs[i]][msg.sender]
                .claimed = true;
            reward += addedReward;

            emit Claim(
                msg.sender,
                paymentTokenAddress,
                gameTokenAddress,
                epochs[i],
                addedReward
            );
        }

        if (reward > 0) {
            if (paymentTokenAddress == wrappedNativeToken) {
                // Unwrap tokens and send native tokens to user
                IWrappedNativeToken(wrappedNativeToken).withdraw(reward);
                _safeTransferBNB(msg.sender, reward);
            } else {
                // Transfer ERC20 tokens to user
                IERC20(paymentTokenAddress).transfer(msg.sender, reward);
            }
        }
    }

    /**
     * @notice Start genesis round for a token with initial price
     * @param paymentTokenAddress: payment token address to use (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to initialize
     * @param price: initial price for the token
     */
    function genesisStartRound(
        address paymentTokenAddress,
        address gameTokenAddress,
        int256 price,
        bytes32 /*zkProof*/
    ) external whenNotPaused onlyOperator {
        require(
            paymentTokenAddress != address(0),
            "Payment token address cannot be zero"
        );
        require(
            gameTokenAddress != address(0),
            "Game token address cannot be zero"
        );
        require(
            currentEpoch[paymentTokenAddress][gameTokenAddress] == 0,
            "Token already initialized"
        );

        _initializeTokenGenesis(paymentTokenAddress, gameTokenAddress, price);
    }

    /**
     * @notice Internal function to initialize genesis for a specific token
     * @param paymentTokenAddress: payment token address to use
     * @param gameTokenAddress: game token address to initialize
     * @param price: initial price for the token
     */
    function _initializeTokenGenesis(
        address paymentTokenAddress,
        address gameTokenAddress,
        int256 price
    ) internal {
        // Create and immediately complete the genesis round (house wins)
        currentEpoch[paymentTokenAddress][gameTokenAddress] =
            currentEpoch[paymentTokenAddress][gameTokenAddress] +
            1;
        _startRound(
            paymentTokenAddress,
            gameTokenAddress,
            currentEpoch[paymentTokenAddress][gameTokenAddress]
        );

        // Lock and end the genesis round with the same price
        Round storage genesisRound = rounds[paymentTokenAddress][
            gameTokenAddress
        ][currentEpoch[paymentTokenAddress][gameTokenAddress]];
        genesisRound.lockPrice = price;
        genesisRound.endPrice = price;
        genesisRound.oracleCalled = true;
        genesisRound.status = Status.Ended;

        emit LockRound(
            currentEpoch[paymentTokenAddress][gameTokenAddress],
            paymentTokenAddress,
            gameTokenAddress,
            genesisRound.lockPrice
        );
        emit EndRound(
            currentEpoch[paymentTokenAddress][gameTokenAddress],
            paymentTokenAddress,
            gameTokenAddress,
            genesisRound.endPrice
        );

        // Calculate rewards for the genesis round (house wins since lockPrice == endPrice)
        _calculateRewards(
            paymentTokenAddress,
            gameTokenAddress,
            currentEpoch[paymentTokenAddress][gameTokenAddress]
        );

        // Start the first betting round with correct timing
        currentEpoch[paymentTokenAddress][gameTokenAddress] =
            currentEpoch[paymentTokenAddress][gameTokenAddress] +
            1;
        _startRound(
            paymentTokenAddress,
            gameTokenAddress,
            currentEpoch[paymentTokenAddress][gameTokenAddress]
        );

        // Set the endTimestamp for the betting round to be 1 * intervalSeconds after the genesis round
        Round storage bettingRound = rounds[paymentTokenAddress][
            gameTokenAddress
        ][currentEpoch[paymentTokenAddress][gameTokenAddress]];
        bettingRound.endTimestamp = genesisRound.endTimestamp + intervalSeconds;
    }

    /**
     * @notice Execute round
     * @param paymentTokenAddress: payment token address to use (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to execute round for
     * @param currentPrice: current price for the token
     */
    function executeRound(
        address paymentTokenAddress,
        address gameTokenAddress,
        int256 currentPrice,
        bytes32 /* zkProof */
    ) external whenNotPaused onlyOperator {
        require(
            paymentTokenAddress != address(0),
            "Payment token address cannot be zero"
        );
        require(
            gameTokenAddress != address(0),
            "Game token address cannot be zero"
        );
        require(
            currentEpoch[paymentTokenAddress][gameTokenAddress] > 0,
            "Token must be initialized first"
        );

        // CurrentEpoch refers to previous round (n-1)
        _safeLockRound(
            paymentTokenAddress,
            gameTokenAddress,
            currentEpoch[paymentTokenAddress][gameTokenAddress],
            currentPrice
        );

        if (currentEpoch[paymentTokenAddress][gameTokenAddress] - 1 > 0) {
            _safeEndRound(
                paymentTokenAddress,
                gameTokenAddress,
                currentEpoch[paymentTokenAddress][gameTokenAddress] - 1,
                currentPrice
            );

            _calculateRewards(
                paymentTokenAddress,
                gameTokenAddress,
                currentEpoch[paymentTokenAddress][gameTokenAddress] - 1
            );
        }

        // Increment currentEpoch to current round (n)
        currentEpoch[paymentTokenAddress][gameTokenAddress] =
            currentEpoch[paymentTokenAddress][gameTokenAddress] +
            1;
        _safeStartRound(
            paymentTokenAddress,
            gameTokenAddress,
            currentEpoch[paymentTokenAddress][gameTokenAddress]
        );
    }

    /**
     * @notice called by the admin to pause, triggers stopped state
     */
    function pause() external whenNotPaused onlyAdminOrOperator {
        _pause();
    }

    /**
     * @notice called by the admin to unpause, returns to normal state
     * Reset genesis state. Once paused, the rounds would need to be kickstarted by genesis
     */
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    /**
     * @notice Set minBetAmount for a specific payment token
     * callable by admin
     * @param paymentTokenAddress: payment token address to set min bet amount for
     * @param _minBetAmount: minimum bet amount for this payment token
     */
    function setMinBetAmount(
        address paymentTokenAddress,
        uint256 _minBetAmount
    ) external whenPaused onlyOwner {
        require(
            paymentTokenAddress != address(0),
            "Payment token address cannot be zero"
        );
        require(_minBetAmount != 0, "Must be superior to 0");
        minBetAmount[paymentTokenAddress] = _minBetAmount;

        emit NewMinBetAmount(paymentTokenAddress, _minBetAmount);
    }

    /**
     * @notice Set treasury fee
     * callable by admin
     */
    function setTreasuryFee(
        uint256 _treasuryFee
    ) external whenPaused onlyOwner {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");
        treasuryFee = _treasuryFee;

        emit NewTreasuryFee(0, treasuryFee); // Using 0 as epoch since we now have multiple assets
    }

    /**
     * @notice Set operator address
     * callable by admin
     */
    function setOperator(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;

        emit NewOperatorAddress(_operatorAddress);
    }

    /**
     * @notice Set interval seconds
     * callable by admin
     */
    function setIntervalSeconds(
        uint256 _intervalSeconds
    ) external whenPaused onlyOwner {
        require(_intervalSeconds > 0, "Must be superior to 0");
        intervalSeconds = _intervalSeconds;

        emit NewBufferAndIntervalSeconds(0, intervalSeconds);
    }

    /**
     * @notice Claim all rewards in treasury
     * callable by admin
     * @param paymentTokenAddress: payment token address to claim treasury for (use wrappedNativeToken for native payments)
     */
    function claimTreasury(address paymentTokenAddress) external onlyOwner {
        require(
            paymentTokenAddress != address(0),
            "Payment token address cannot be zero"
        );
        uint256 currentTreasuryAmount = treasuryAmount[paymentTokenAddress];
        treasuryAmount[paymentTokenAddress] = 0;

        if (paymentTokenAddress == wrappedNativeToken) {
            // Unwrap tokens and send native tokens to treasury
            IWrappedNativeToken(wrappedNativeToken).withdraw(
                currentTreasuryAmount
            );
            _safeTransferBNB(treasuryAddress, currentTreasuryAmount);
        } else {
            // Transfer ERC20 tokens to treasury
            IERC20(paymentTokenAddress).transfer(
                treasuryAddress,
                currentTreasuryAmount
            );
        }

        emit TreasuryClaim(paymentTokenAddress, currentTreasuryAmount);
    }

    /**
     * @notice Returns round epochs and bet information for a user that has participated
     * @param user: user address
     * @param paymentTokenAddress: payment token address (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to get rounds for
     * @param cursor: cursor
     * @param size: size
     */
    function getUserRounds(
        address user,
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, BetInfo[] memory, uint256) {
        uint256[] storage userTokenRounds = userRounds[paymentTokenAddress][
            gameTokenAddress
        ][user];
        uint256 length = size;

        if (length > userTokenRounds.length - cursor) {
            length = userTokenRounds.length - cursor;
        }

        uint256[] memory values = new uint256[](length);
        BetInfo[] memory betInfo = new BetInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            values[i] = userTokenRounds[cursor + i];
            betInfo[i] = ledger[paymentTokenAddress][gameTokenAddress][
                values[i]
            ][user];
        }

        return (values, betInfo, cursor + length);
    }

    /**
     * @notice Returns round epochs length
     * @param user: user address
     * @param paymentTokenAddress: payment token address (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to get rounds length for
     */
    function getUserRoundsLength(
        address user,
        address paymentTokenAddress,
        address gameTokenAddress
    ) external view returns (uint256) {
        return userRounds[paymentTokenAddress][gameTokenAddress][user].length;
    }

    /**
     * @notice Get next round end timestamp and prize pool
     * @param paymentTokenAddress: payment token address (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address to get next round info for
     * @return nextRoundEndTime When next round ends
     * @return nextRoundPrizePool Total amount (prize pool) in next round
     */
    function getNextRoundEndInfo(
        address paymentTokenAddress,
        address gameTokenAddress
    )
        external
        view
        returns (uint256 nextRoundEndTime, uint256 nextRoundPrizePool)
    {
        Round memory nextRound = rounds[paymentTokenAddress][gameTokenAddress][
            currentEpoch[paymentTokenAddress][gameTokenAddress] + 1
        ];
        nextRoundEndTime = nextRound.endTimestamp;
        nextRoundPrizePool = nextRound.totalAmount;
    }

    /**
     * @notice Get the claimable stats of specific epoch and user account
     * @param paymentTokenAddress: payment token address for the round (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     * @param user: user address
     */
    function claimable(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[paymentTokenAddress][gameTokenAddress][
            epoch
        ][user];
        Round memory round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];
        if (round.lockPrice == round.endPrice) {
            return false;
        }

        return
            round.oracleCalled &&
            betInfo.amount != 0 &&
            !betInfo.claimed &&
            ((round.endPrice > round.lockPrice &&
                betInfo.position == Position.Bull) ||
                (round.endPrice < round.lockPrice &&
                    betInfo.position == Position.Bear));
    }

    /**
     * @notice Get the refundable stats of specific epoch and user account
     * @param paymentTokenAddress: payment token address for the round (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     * @param user: user address
     */
    function refundable(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[paymentTokenAddress][gameTokenAddress][
            epoch
        ][user];
        Round memory round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];
        return
            !round.oracleCalled &&
            !betInfo.claimed &&
            block.timestamp > round.endTimestamp + intervalSeconds &&
            betInfo.amount != 0;
    }

    /**
     * @notice Calculate rewards for round
     * @param paymentTokenAddress: payment token address for the round
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     */
    function _calculateRewards(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch
    ) internal {
        require(
            rounds[paymentTokenAddress][gameTokenAddress][epoch]
                .rewardBaseCalAmount ==
                0 &&
                rounds[paymentTokenAddress][gameTokenAddress][epoch]
                    .rewardAmount ==
                0,
            "Rewards calculated"
        );
        Round storage round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];
        uint256 rewardBaseCalAmount;
        uint256 treasuryAmt;
        uint256 rewardAmount;

        // Bull wins
        if (round.endPrice > round.lockPrice) {
            rewardBaseCalAmount = round.bullAmount;
            treasuryAmt = (round.totalAmount * treasuryFee) / TOTAL_RATE;
            rewardAmount = round.totalAmount - treasuryAmt;
        }
        // Bear wins
        else if (round.endPrice < round.lockPrice) {
            rewardBaseCalAmount = round.bearAmount;
            treasuryAmt = (round.totalAmount * treasuryFee) / TOTAL_RATE;
            rewardAmount = round.totalAmount - treasuryAmt;
        }
        // House wins
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
            treasuryAmt = round.totalAmount;
        }
        round.rewardBaseCalAmount = rewardBaseCalAmount;
        round.rewardAmount = rewardAmount;

        // Add to treasury
        treasuryAmount[paymentTokenAddress] += treasuryAmt;

        emit RewardsCalculated(
            epoch,
            paymentTokenAddress,
            gameTokenAddress,
            rewardBaseCalAmount,
            rewardAmount,
            treasuryAmt
        );
    }

    /**
     * @notice End round
     * @param paymentTokenAddress: payment token address for the round
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     * @param price: price of the round
     */
    function _safeEndRound(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch,
        int256 price
    ) internal {
        require(
            rounds[paymentTokenAddress][gameTokenAddress][epoch]
                .lockTimestamp != 0,
            "Can only end round after round has locked"
        );
        require(
            block.timestamp >=
                rounds[paymentTokenAddress][gameTokenAddress][epoch]
                    .endTimestamp,
            "Can only end round after endTimestamp"
        );

        Round storage round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];

        round.endPrice = price;
        round.oracleCalled = true;
        round.status = Status.Ended;

        emit EndRound(
            epoch,
            paymentTokenAddress,
            gameTokenAddress,
            round.endPrice
        );
    }

    /**
     * @notice Lock round
     * @param paymentTokenAddress: payment token address for the round
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     * @param price: price of the round
     */
    function _safeLockRound(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch,
        int256 price
    ) internal {
        require(
            rounds[paymentTokenAddress][gameTokenAddress][epoch].startTimestamp != 0,
            "Can only lock round after round has started"
        );

        Round storage round = rounds[paymentTokenAddress][gameTokenAddress][epoch];
        round.lockPrice = price;
        round.status = Status.Live;

        emit LockRound(epoch, paymentTokenAddress, gameTokenAddress, round.lockPrice);
    }

    /**
     * @notice Start round
     * Previous round n-2 must end
     * @param paymentTokenAddress: payment token address for the round
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     */
    function _safeStartRound(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch
    ) internal {
        require(
            currentEpoch[paymentTokenAddress][gameTokenAddress] > 0,
            "Token must be initialized first"
        );
        require(
            rounds[paymentTokenAddress][gameTokenAddress][epoch - 2]
                .endTimestamp != 0,
            "Can only start round after round n-2 has ended"
        );
        require(
            block.timestamp >=
                rounds[paymentTokenAddress][gameTokenAddress][epoch - 2]
                    .endTimestamp,
            "Can only start new round after round n-2 endTimestamp"
        );
        _startRound(paymentTokenAddress, gameTokenAddress, epoch);
    }

    /**
     * @notice Start round
     * @param paymentTokenAddress: payment token address for the round
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     */
    function _startRound(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch
    ) internal {
        Round storage round = rounds[paymentTokenAddress][gameTokenAddress][
            epoch
        ];
        round.epoch = epoch;
        round.asset = gameTokenAddress;
        round.startTimestamp = block.timestamp;
        round.lockTimestamp = block.timestamp + intervalSeconds;
        round.endTimestamp = block.timestamp + intervalSeconds;
        round.totalAmount = 0;
        round.bullAmount = 0;
        round.bearAmount = 0;
        round.rewardBaseCalAmount = 0;
        round.rewardAmount = 0;
        round.oracleCalled = false;
        round.status = Status.Pending;

        emit StartRound(epoch, paymentTokenAddress, gameTokenAddress);
    }

    /**
     * @notice Determine if a round is valid for receiving bets
     * Round must have started and locked
     * Current timestamp must be within startTimestamp and lockTimestamp
     * @param paymentTokenAddress: payment token address for the round (use wrappedNativeToken for native payments)
     * @param gameTokenAddress: game token address for the round
     * @param epoch: epoch
     */
    function bettable(
        address paymentTokenAddress,
        address gameTokenAddress,
        uint256 epoch
    ) public view returns (bool) {
        return
            rounds[paymentTokenAddress][gameTokenAddress][epoch]
                .startTimestamp !=
            0 &&
            rounds[paymentTokenAddress][gameTokenAddress][epoch]
                .lockTimestamp !=
            0 &&
            block.timestamp >
            rounds[paymentTokenAddress][gameTokenAddress][epoch]
                .startTimestamp &&
            block.timestamp <
            rounds[paymentTokenAddress][gameTokenAddress][epoch].lockTimestamp;
    }



    /**
     * @notice Transfer BNB in a safe way
     * @param to: address to transfer BNB to
     * @param value: BNB amount to transfer (in wei)
     */
    function _safeTransferBNB(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: BNB_TRANSFER_FAILED");
    }

    /**
     * @notice Receive function to accept native tokens from wrapped token contract
     */
    receive() external payable {
        // This function allows the contract to receive native tokens
        // when the wrapped token contract calls withdraw()
    }
}
