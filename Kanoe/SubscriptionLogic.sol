// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;




struct SubscriptionStruct {
	uint256 id;
	address account;
	address[] extraAccounts;
	uint256 planId;
	uint256 startTime;
	uint256 endTime;
}

struct PaymentStruct {
	uint256 id;
	uint256 planId;
	uint256 payedPeriods;
	address payer;
	address paytokenAddress;
	uint256 paytokenAmount;
	uint256 timestamp;
}

struct OneTrigger {
	address addr;
	bool isEnabled;
}

struct PlanLimits {
	uint256 successorsMaxCount;
	uint256 inheritancesMaxCount;
	uint256 tokensMaxCount;
	uint256 stableMaxSum;
	uint256 maxWalletsCount;
}

struct PlanStruct {
	uint256 id;
	uint256 paytokenPrice;
	address paytokenAddress;
	bool isActive;
	PlanLimits limits;
	string title;
}


interface ISubscriptions {
	function addPayment(
		address account,
		uint256 payedPeriods,
		uint256 planId,
		uint256 paytokenPrice,
		address paytokenAddress
	) external;

	function getSubscriptionsList(
		uint256 startIndex,
		uint256 endIndex
	) external view returns (SubscriptionStruct[] memory);

	function getPaymentsList(
		uint256 startIndex,
		uint256 endIndex
	) external view returns (PaymentStruct[] memory);

	function getMaxSubscriptionId() external view returns (uint256);

	function getMaxPaymentId() external view returns (uint256);

	function getSubscriptionById(
		uint256 id
	) external view returns (SubscriptionStruct memory);

	function getUserSubscription(
		address account
	) external view returns (SubscriptionStruct memory);
}

interface IPlans {
	function getPlanById(
		uint256 planId
	) external view returns (PlanStruct memory);

	function getPlansList(
		uint256 startIndex,
		uint256 endIndex
	) external view returns (PlanStruct[] memory);

	function getPlansList() external view returns (PlanStruct[] memory);
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */


contract SubscriptionLogic is Ownable {
	IPlans private plansContract;
	ISubscriptions private subscriptionsContract;
	address private paymentHolder;
	address private systemWallet;

	event PlansContractChanged(
		address indexed oldPlanContract,
		address indexed newPlanContract
	);
	event SubscriptionContractChanged(
		address indexed oldSubscriptionContract,
		address indexed newSubscriptionContract
	);
	event SystemWalletChanged(
		address indexed oldSystemWallet,
		address indexed newSystemWallet
	);
	event PaymentMade(
		address indexed account,
		uint256 planId,
		uint256 periodsCount,
		uint256 amount
	);
	event SubscriptionAutoExtended(
		address indexed account,
		uint256 planId,
		uint256 amount
	);

	/* ********************************* */

	constructor(
		address _plansContract,
		address _subscriptionsContract,
		address _paymentHolder,
		address _systemWallet
	) {
		plansContract = IPlans(_plansContract);
		subscriptionsContract = ISubscriptions(_subscriptionsContract);
		paymentHolder = _paymentHolder;
		systemWallet = _systemWallet;
	}

	/**
	 * @dev Returns the plan by the given ID.
	 * @param planId The ID of the plan.
	 */
	function getPlanById(
		uint256 planId
	) external view returns (PlanStruct memory) {
		return plansContract.getPlanById(planId);
	}

	/**
	 * @dev Returns the list of all plans.
	 */
	function getPlansList() external view returns (PlanStruct[] memory) {
		return plansContract.getPlansList();
	}

	/**
	 * @dev Returns the maximum payment ID.
	 */
	function getMaxPaymentId() external view returns (uint256) {
		return subscriptionsContract.getMaxPaymentId();
	}

	/**
	 * @dev Returns a sublist of payments from startIndex to endIndex (inclusive).
	 * @param startIndex The starting index of the sublist.
	 * @param endIndex The ending index of the sublist.
	 */
	function getPaymentsList(
		uint256 startIndex,
		uint256 endIndex
	) external view returns (PaymentStruct[] memory) {
		return subscriptionsContract.getPaymentsList(startIndex, endIndex);
	}

	/**
	 * @dev Returns updates since the given last known payment ID.
	 * @param lastKnownPaymentId The last known payment ID.
	 */
	function getUpdates(
		uint256 lastKnownPaymentId
	) external view returns (SubscriptionStruct[] memory) {
		uint256 lastPayment = subscriptionsContract.getMaxPaymentId();
		uint256 count = lastPayment > lastKnownPaymentId
			? lastPayment - lastKnownPaymentId
			: 0;
		SubscriptionStruct[] memory _subs = new SubscriptionStruct[](count);
		if (count > 0) {
			PaymentStruct[] memory _payments = this.getPaymentsList(
				lastKnownPaymentId,
				lastPayment - 1
			);
			for (uint256 i = 0; i < _payments.length; i++) {
				_subs[i] = this.getUserSubscription(_payments[i].payer);
			}
		}
		return _subs;
	}

	/**
	 * @dev Auto-extend subscription by system wallet
	 * @param account The address of the user.
	 */
	function payExtend(address account) external onlyAdmin {
		SubscriptionStruct memory subscription = subscriptionsContract
			.getUserSubscription(account);
		PlanStruct memory plan = plansContract.getPlanById(subscription.planId);
		IERC20(plan.paytokenAddress).transferFrom(
			account,
			paymentHolder,
			plan.paytokenPrice
		);
		subscriptionsContract.addPayment(
			account,
			1,
			subscription.planId,
			plan.paytokenPrice,
			plan.paytokenAddress
		);
		emit SubscriptionAutoExtended(
			account,
			subscription.planId,
			plan.paytokenPrice
		);
	}

	/**
	 * @dev Allows a user to pay for a subscription plan for a given number of periods.
	 * @param planId The ID of the plan.
	 * @param periodsCount The number of periods to pay for.
	 */
	function pay(uint256 planId, uint256 periodsCount) external {
		PlanStruct memory plan = plansContract.getPlanById(planId);
		uint256 amount = plan.paytokenPrice * periodsCount;
		IERC20(plan.paytokenAddress).transferFrom(
			msg.sender,
			paymentHolder,
			amount
		);
		subscriptionsContract.addPayment(
			msg.sender,
			periodsCount,
			planId,
			amount,
			plan.paytokenAddress
		);
		emit PaymentMade(msg.sender, planId, periodsCount, amount);
	}

	/**
	 * @dev Returns the subscription of the given user.
	 * @param account The address of the user.
	 */
	function getUserSubscription(
		address account
	) external view returns (SubscriptionStruct memory) {
		return subscriptionsContract.getUserSubscription(account);
	}

	/**
	 * @dev Changes the address of the plans contract. Only the owner can call this function.
	 * @param _plansContract The new address of the plans contract.
	 */

	function changePlansContract(address _plansContract) external onlyOwner {
		address oldPlansContract = address(plansContract);
		plansContract = IPlans(_plansContract);
		emit PlansContractChanged(oldPlansContract, _plansContract);
	}

	/**
	 * @dev Changes the address of the subscriptions contract. Only the owner can call this function.
	 * @param _subscriptionsContract The new address of the subscriptions contract.
	 */
	function changeSubscriptionContract(
		address _subscriptionsContract
	) external onlyOwner {
		address oldSubscriptionsContract = address(subscriptionsContract);
		subscriptionsContract = ISubscriptions(_subscriptionsContract);
		emit SubscriptionContractChanged(
			oldSubscriptionsContract,
			_subscriptionsContract
		);
	}

	/**
	 * @dev Changes the address of the system wallet. Only the owner can call this function.
	 * @param newSystemWallet The new address of the system wallet.
	 */
	function changeSystemWallet(address newSystemWallet) external onlyOwner {
		address oldSystemWallet = systemWallet;
		systemWallet = newSystemWallet;
		emit SystemWalletChanged(oldSystemWallet, newSystemWallet);
	}

	/**
	 * @dev Modifier to restrict access to only the system wallet.
	 */
	modifier onlyAdmin() {
		if (msg.sender != systemWallet) {
			revert("Only admin");
		}
		_;
	}
}