
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
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
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
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
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
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

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

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
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// File: contracts/SupChainPresale.sol



pragma solidity 0.8.20;



interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function getAmountsOut(
        uint amountIn, 
        address[] memory path
        ) external view returns (uint[] memory amounts);
    
    function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);

}


contract SUPCPresale is ReentrancyGuard, Ownable(msg.sender) {
    using SafeERC20 for IERC20;

    struct Phase {
        uint256 maxTokens;
        uint256 price;
        uint256 minPerWallet;
        uint256 maxPerWallet;
        
        uint256 startTime;
        uint256 endTime;

        uint256 soldTokens;
    }

    uint256 public activePhase;
    bool public isAutoMovePhase;

    Phase[] public phases;

    IERC20 USDT;
    IERC20 SUPCToken;
    IRouter public router;
    
    uint256 private constant TOKEN_DECIMAL = 1e18;
    uint256 private constant USDT_DECIMAL = 1e6;
    address public SALE_WITH_CARD_PAYMENT_MANAGER;

    mapping (address => mapping(uint256 => uint256)) private userPaidUSD;

    event Buy(address _to, uint256 _amount, uint256 _phaseNum);
    event Burn(uint256 _amount, uint256 _phaseNum);
    event SetStartAndEndTime(uint256 _startTime, uint256 _endTime, uint256 _phaseNum);
    event SetEndTime(uint256 _time, uint256 _phaseNum);
    event SetCardPaymentManager(address _address);
    event RefundAmount2CardOrBNBPayer(uint256 _phaseNum, address _user, uint256 _owingAmount);

    receive() payable external {}

    constructor(address _router, address _usdt, address _token) {
        router = IRouter(_router);
        SUPCToken = IERC20(_token);
        USDT = IERC20(_usdt);
        SALE_WITH_CARD_PAYMENT_MANAGER = msg.sender;

        addPhase(250_000_000, 4500, 200, 15000);
        addPhase(750_000_000, 5500, 100, 10000);
        addPhase(500_000_000, 6000, 100, 8000);
        addPhase(850_000_000, 7500, 100, 6375000); // 6375000 means no limit.
    }

    function addPhase(uint256 _maxTokens, uint256 _price, uint256 _minPerWallet, uint256 _maxPerWallet) private {
        phases.push(
            Phase({
                maxTokens: _maxTokens * TOKEN_DECIMAL,
                price: _price,
                minPerWallet: _minPerWallet * USDT_DECIMAL,
                maxPerWallet: _maxPerWallet * USDT_DECIMAL,
                startTime: 0,
                endTime: 0,
                soldTokens: 0
            })
        );
    }

    /**
    * @notice Buy tokens with usdt.
    * @param _usdtAmount Amount of usdt to buy token.
    */
    function buyTokensWithUSDT(uint256 _usdtAmount) external nonReentrant {
        uint256 maxTokens = phases[activePhase].maxTokens;
        uint256 price = phases[activePhase].price;
        uint256 minPerWallet = phases[activePhase].minPerWallet;
        uint256 maxPerWallet = phases[activePhase].maxPerWallet;
        uint256 start_time = phases[activePhase].startTime;
        uint256 end_time = phases[activePhase].endTime;
        uint256 soldTokens = phases[activePhase].soldTokens;

        uint256 user_paid = userPaidUSD[msg.sender][activePhase];

        require(block.timestamp >= start_time && block.timestamp <= end_time, "SUPPresale: Not presale period");

        uint256 currentPaid = user_paid;
        require(currentPaid + _usdtAmount >= minPerWallet && currentPaid + _usdtAmount <= maxPerWallet, "SUPPresale: The price is not allowed for presale.");
        
        bool isReachMaxAmount;

        // token amount user want to buy
        uint256 tokenAmount = _usdtAmount * TOKEN_DECIMAL / price;

        // transfer USDT to here
        USDT.safeTransferFrom(msg.sender, address(this), _usdtAmount);

        if (phases[activePhase].maxTokens < tokenAmount + soldTokens && isAutoMovePhase) {
            uint256 tokenAmount2 = maxTokens - soldTokens;
            uint256 returnAmount = _usdtAmount - (_usdtAmount * tokenAmount2 / tokenAmount);
            IERC20(USDT).safeTransfer(msg.sender, returnAmount);

            tokenAmount = tokenAmount2;
            isReachMaxAmount = true;
        }

        // transfer SUPC token to user
        SUPCToken.safeTransfer(msg.sender, tokenAmount);
        
        phases[activePhase].soldTokens += tokenAmount;
        // add USD user bought
        userPaidUSD[msg.sender][activePhase] += _usdtAmount;

        emit Buy(msg.sender, tokenAmount, activePhase);

        if(isReachMaxAmount){
            activePhase++;
        } 
    }

    /**
    * @notice Buy tokens with eth.
    */
    function buyTokensWithETH() external payable nonReentrant {
        uint256 maxTokens = phases[activePhase].maxTokens;
        uint256 price = phases[activePhase].price;
        uint256 minPerWallet = phases[activePhase].minPerWallet;
        uint256 maxPerWallet = phases[activePhase].maxPerWallet;
        uint256 start_time = phases[activePhase].startTime;
        uint256 end_time = phases[activePhase].endTime;
        uint256 soldTokens = phases[activePhase].soldTokens;

        require(block.timestamp >= start_time && block.timestamp <= end_time, "SUPCPresale: Not presale period");
        
        require(msg.value > 0, "Insufficient ETH amount");

        uint256 ethAmount = msg.value;
        uint256 usdtAmount = getLatestETHPrice(ethAmount);
 
        uint256 currentPaid = userPaidUSD[msg.sender][activePhase];
        require(currentPaid + usdtAmount >= minPerWallet && currentPaid + usdtAmount <= maxPerWallet, "SUPCPresale: The price is not allowed for presale.");

        bool isReachMaxAmount;

        // token amount user want to buy
        uint256 tokenAmount = usdtAmount * TOKEN_DECIMAL / price;

        if (phases[activePhase].maxTokens < tokenAmount + soldTokens && isAutoMovePhase) {
            uint256 tokenAmount2 = maxTokens - soldTokens;
            uint256 returnAmount = ethAmount - (ethAmount * tokenAmount2 / tokenAmount);
            returnEth(msg.sender, returnAmount);

            usdtAmount = usdtAmount * tokenAmount2 / tokenAmount;
            tokenAmount = tokenAmount2;
            isReachMaxAmount = true;
        }

        // transfer SUPC token to user
        SUPCToken.safeTransfer(msg.sender, tokenAmount);

        phases[activePhase].soldTokens += tokenAmount;
        // add USD user bought
        userPaidUSD[msg.sender][activePhase] += usdtAmount;

        emit Buy(msg.sender, tokenAmount, activePhase);

        if(isReachMaxAmount){
            activePhase++;
        } 
    }

    /**
    * @notice Purchase tokens with USD using a credit card payment. A manager's wallet will then transfer the tokens to the user who paid with BNB or a credit card.
    * @param _usdtAmount Amount of usdt to buy token.
    * @param _user Address of user
    */
    function giveTokenToBuyer(uint256 _usdtAmount, address _user) external nonReentrant {
        require(msg.sender == SALE_WITH_CARD_PAYMENT_MANAGER, "SUPCPresale: Invalid caller");

        uint256 maxTokens = phases[activePhase].maxTokens;
        uint256 price = phases[activePhase].price;
        uint256 minPerWallet = phases[activePhase].minPerWallet;
        uint256 maxPerWallet = phases[activePhase].maxPerWallet;
        uint256 start_time = phases[activePhase].startTime;
        uint256 end_time = phases[activePhase].endTime;
        uint256 soldTokens = phases[activePhase].soldTokens;

        uint256 user_paid = userPaidUSD[_user][activePhase];

        require(block.timestamp >= start_time && block.timestamp <= end_time, "SUPCPresale: Not presale period");

        uint256 currentPaid = user_paid;
        require(currentPaid + _usdtAmount >= minPerWallet && currentPaid + _usdtAmount <= maxPerWallet, "SUPPresale: The price is not allowed for presale.");
        
        bool isReachMaxAmount;

        // token amount user want to buy
        uint256 tokenAmount = _usdtAmount * TOKEN_DECIMAL / price;

        if (phases[activePhase].maxTokens < tokenAmount + soldTokens && isAutoMovePhase) {
            uint256 returnAmount = _usdtAmount -  (_usdtAmount * (maxTokens - soldTokens) / tokenAmount);
            if(IERC20(USDT).balanceOf(address(this)) >= returnAmount){
            IERC20(USDT).safeTransfer(_user, returnAmount);
            }else {
                emit RefundAmount2CardOrBNBPayer(activePhase, _user, returnAmount);
            }
            tokenAmount = maxTokens - soldTokens;
            isReachMaxAmount = true;
        }

       // transfer SUPC token to user
        SUPCToken.safeTransfer(_user, tokenAmount);
        
        phases[activePhase].soldTokens += tokenAmount;
        // add USD user bought
        userPaidUSD[_user][activePhase] += _usdtAmount;

        emit Buy(_user, tokenAmount, activePhase);

        if(isReachMaxAmount){
            activePhase++;
        } 
    }

    /**
    * @dev Get latest ETH price from dex.
    * @param _amount ETH amount.
    */
    function getLatestETHPrice(uint256 _amount) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(USDT);

        uint256[] memory price_out = router.getAmountsOut(_amount, path);
        uint256 price_round = price_out[1] / USDT_DECIMAL;
        return price_round * USDT_DECIMAL;
    }

    /**
    * @dev Get paid usdt of a user on specified phase.
    * @param _account User address.
    * @param _phaseNum Number of phase.
    */
    function getUserPaidUSDT (address _account, uint256 _phaseNum) public view returns (uint256) {
        return userPaidUSD[_account][_phaseNum];
    }

    /**
    * @dev Set start and end time of a phase.
    * @param _phaseNum Number of phase.
    * @param _startTime Start time of a phase.
    * @param _endTime End time of a phase.
    */
    function setStartAndEndTime(uint256 _phaseNum, uint256 _startTime, uint256 _endTime) external onlyOwner {
        phases[_phaseNum].startTime = _startTime;
        phases[_phaseNum].endTime = _endTime;
        emit SetStartAndEndTime(_startTime, _endTime, _phaseNum);
    }

    /**
    * @dev Set end time of a phase.
    * @param _phaseNum Number of phase.
    * @param _time End time of a phase.
    */
    function setEndTime(uint256 _phaseNum, uint256 _time) external onlyOwner {
        phases[_phaseNum].endTime = _time;

        emit SetEndTime(_time, _phaseNum);
    }

    /**
    * @dev Set wallet address that is used to withdraw Supchain along card payment amount
    * @param _address A Wallet address.
    */
    function setCardPaymentManager(address _address) external onlyOwner {
        require(_address != address(0), "cannot be zero address");
        SALE_WITH_CARD_PAYMENT_MANAGER = _address;

        emit SetCardPaymentManager(_address);
    }

    /**
    * @dev Set active phase.
    * @param _phaseNum Number of phase.
    * @param _isAutoPhase Auto move phase, TRUE: Auto move to next phase if a phase end.
    */
    function setActivePhase(uint256 _phaseNum, bool _isAutoPhase) external onlyOwner {
        activePhase = _phaseNum;
        isAutoMovePhase = _isAutoPhase;
    }

    /**
    * @dev Burn unsold tokens at the end of a phase.
    */
    function burnUnsoldTokens() external onlyOwner {
        require(phases[activePhase].endTime != 0 && block.timestamp > phases[activePhase].endTime);
        uint256 unsoldTokens = phases[activePhase].maxTokens - phases[activePhase].soldTokens;
        require(unsoldTokens > 0, "no unsold tokens");

        SUPCToken.safeTransfer(address(0), unsoldTokens);

        emit Burn(unsoldTokens, activePhase);
    }

    /**
    * @notice Withdraw ETH.
    * @dev Withdraw eth from this contract.
    * @param _ethAmount Amount of eth to withdraw.
    */
    function withdrawETH(uint256 _ethAmount) external onlyOwner {

        ( bool success,) = owner().call{value: _ethAmount}("");
        require(success, "Withdrawal was not successful");
    }

    function returnEth(address _account, uint256 _amount) internal {
        ( bool success,) = _account.call{value: _amount}("");
        require(success, "Withdrawal was not successful");
    }

    /**
    * @notice Withdraw tokens.
    * @dev Withdraw tokens from this contract.
    * @param _tokenAddress Address of the token.
    * @param _amount Amount of the token to withdraw.
    */
    function withdrawToken(address _tokenAddress,uint256 _amount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(owner(),_amount);
    }
}