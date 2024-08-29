// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;



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
/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
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



contract Plans is Ownable {
	using Counters for Counters.Counter;

	Counters.Counter private planIds;
	PlanStruct[] private plans;


	constructor() {}

	/**
	 * @dev Returns plan ID of last added plan or 0 if none was added.
	 */
	function getPlanId() external view returns (uint256) {
		return planIds.current();
	}

	/**
	 * @dev Returns the plan by the given ID.
	 * Reverts if the plan does not exist.
	 * @param id The ID of the plan.
	 */
	function getPlanById(uint256 id) external view returns (PlanStruct memory) {
		uint256 maxId = planIds.current();
		if (maxId == 0) {
			revert("No any subscriptions");
		}
		if (id == 0 || id > maxId) {
			revert("Invalid plan ID");
		}
		return plans[id - 1];
	}

	/**
	 * @dev Returns the list of all plans.
	 */
	function getPlansList() external view returns (PlanStruct[] memory) {
		return this.getPlansList(0, plans.length - 1);
	}

	/**
	 * @dev Returns a sublist of plans from startIndex to endIndex (inclusive).
	 * Reverts if indices are out of bounds.
	 * @param startIndex The starting index of the sublist.
	 * @param endIndex The ending index of the sublist.
	 */
	function getPlansList(
		uint256 startIndex,
		uint256 endIndex
	) external view returns (PlanStruct[] memory) {
		if (endIndex < startIndex) {
			revert("Invalid index range");
		}
		if (endIndex >= plans.length) {
			revert("EndIndex out of bounds");
		}
		PlanStruct[] memory list = new PlanStruct[](endIndex - startIndex + 1);
		for (uint256 i = startIndex; i <= endIndex; i++) {
			list[i - startIndex] = plans[i];
		}
		return list;
	}

	/* ********************************* */

	/**
	 * @dev Adds a new plan. Only the owner can call this function.
	 * @param title The title of the plan.
	 * @param paytokenAddress The address of the payment token.
	 * @param paytokenPrice The price of the plan.
	 * @param limits The user's limits of the plan.
	 */
	function addPlan(
		string memory title,
		address paytokenAddress,
		uint256 paytokenPrice,
		PlanLimits memory limits
	) external onlyOwner {
		planIds.increment();
		uint256 newId = planIds.current();
		plans.push(
			PlanStruct(
				newId,
				paytokenPrice,
				paytokenAddress,
				true,
				limits,
				title
			)
		);
	}

	/**
	 * @dev Toggles the active status of a plan. Only the owner can call this function.
	 * @param planId The ID of the plan to toggle.
	 * @param isActive The new active status of the plan.
	 */
	function togglePlan(uint256 planId, bool isActive) external onlyOwner {
		uint256 length = plans.length;
		for (uint256 i = 0; i < length; i++) {
			if (plans[i].id == planId) {
				plans[i].isActive = isActive;
				return;
			}
		}
		revert("Plan ID not found");
	}
}