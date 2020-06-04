pragma solidity ^0.6.2;

import "./ERC20.sol";
import "../base/HexMoneyInternal.sol";

/**
 * @dev Extension of {ERC20} that adds a cap to the supply of tokens.
 */
abstract contract ERC20FreezableCapped is ERC20, HexMoneyInternal {
    uint256 public constant MINIMAL_FREEZE_PERIOD = 7;    // 7 days

    // freezing chains
    mapping (bytes32 => uint256) internal chains;
    // freezing amounts for each chain
    mapping (bytes32 => uint) internal freezings;
    // total freezing balance per address
    mapping (address => uint) internal freezingBalance;

    event Freezed(address indexed to, uint256 release, uint amount);
    event Released(address indexed owner, uint amount);

    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor (uint256 cap) public {
        require(cap > 0, "ERC20Capped: cap is 0");
        _cap = cap;
    }

    /**
     * @dev Gets the balance of the specified address include freezing tokens.
     * @param account The address to query the the balance of.
     * @return balance An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return super.balanceOf(account) + freezingBalance[account];
    }

    /**
     * @dev Gets the balance of the specified address without freezing tokens.
     * @param account The address to query the the balance of.
     * @return balance An uint256 representing the amount owned by the passed address.
     */
    function actualBalanceOf(address account) public view returns (uint256 balance) {
        return super.balanceOf(account);
    }

    function freezingBalanceOf(address account) public view returns (uint256 balance) {
        return freezingBalance[account];
    }

    /**
     * @dev gets freezing count
     * @param _addr Address of freeze tokens owner.
     */
    function freezingCount(address _addr) public view returns (uint count) {
        uint256 release = chains[toKey(_addr, 0)];
        while (release != 0) {
            count++;
            release = chains[toKey(_addr, release)];
        }
    }

    /**
     * @dev gets freezing end date and freezing balance for the freezing portion specified by index.
     * @param _addr Address of freeze tokens owner.
     * @param _index Freezing portion index. It ordered by release date descending.
     */
    function getFreezing(address _addr, uint _index) public view returns (uint256 _release, uint _balance) {
        for (uint i = 0; i < _index + 1; i++) {
            _release = chains[toKey(_addr, _release)];
            if (_release == 0) {
                return (0, 0);
            }
        }
        _balance = freezings[toKey(_addr, _release)];
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev freeze your tokens to the specified address.
     *      Be careful, gas usage is not deterministic,
     *      and depends on how many freezes _to address already has.
     * @param _to Address to which token will be freeze.
     * @param _amount Amount of token to freeze.
     * @param _start Start  date.
     */
    function _freezeTo(address _to, uint _amount, uint256 _start) internal {
        require(_to != address(0));
        require(_amount <= _balances[msg.sender]);

        _balances[msg.sender] = _balances[msg.sender].sub(_amount);

        bytes32 currentKey = toKey(_to, _start);
        freezings[currentKey] = freezings[currentKey].add(_amount);
        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        _freeze(_to, _start);
        emit Transfer(msg.sender, _to, _amount);
        emit Freezed(_to, _start, _amount);
    }

    function _mintAndFreezeTo(address _to, uint _amount, uint256 _start) internal returns (bool) {
        _totalSupply = _totalSupply.add(_amount);

        bytes32 currentKey = toKey(_to, _start);
        freezings[currentKey] = freezings[currentKey].add(_amount);
        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        _freeze(_to, _start);
        emit Freezed(_to, _start, _amount);
        emit Transfer(msg.sender, _to, _amount);
        return true;

    }

    /**
     * @dev release first available freezing tokens.
     */
    function _releaseOnce(uint256 _timeLock) internal {
        bytes32 headKey = toKey(msg.sender, 0);
        uint256 head = chains[headKey];
        require(head != 0);

        uint256 timeLock = _daysToTimestampFrom(head, _timeLock);
        require(uint256(block.timestamp) > timeLock);
        bytes32 currentKey = toKey(msg.sender, head);

        uint256 next = chains[currentKey];

        uint amount = freezings[currentKey];
        delete freezings[currentKey];

        _balances[msg.sender] = _balances[msg.sender].add(amount);
        freezingBalance[msg.sender] = freezingBalance[msg.sender].sub(amount);

        if (next == 0) {
            delete chains[headKey];
        } else {
            chains[headKey] = next;
            delete chains[currentKey];
        }
        emit Released(msg.sender, amount);
    }

//    /**
//     * @dev release all available for release freezing tokens. Gas usage is not deterministic!
//     * @return tokens How many tokens was released
//     */
//    function _releaseAll() internal returns (uint tokens) {
//        uint release;
//        uint balance;
//        (release, balance) = getFreezing(msg.sender, 0);
//        while (release != 0 && block.timestamp > release) {
//            _releaseOnce();
//            tokens += balance;
//            (release, balance) = getFreezing(msg.sender, 0);
//        }
//    }

    function toKey(address _addr, uint _release) internal pure returns (bytes32 result) {
        // WISH masc to increase entropy
        result = 0x5749534800000000000000000000000000000000000000000000000000000000;
        assembly {
            result := or(result, mul(_addr, 0x10000000000000000))
            result := or(result, and(_release, 0xffffffffffffffff))
        }
    }

    function _freeze(address _to, uint256 _start) internal {
        require(_start >= block.timestamp);
        bytes32 key = toKey(_to, _start);
        bytes32 parentKey = toKey(_to, uint256(0));
        uint256 next = chains[parentKey];

        if (next == 0) {
            chains[parentKey] = _start;
            return;
        }

        bytes32 nextKey = toKey(_to, next);
        uint parent;

        while (next != 0 && _start > next) {
            parent = next;
            parentKey = nextKey;

            next = chains[nextKey];
            nextKey = toKey(_to, next);
        }

        if (_start == next) {
            return;
        }

        if (next != 0) {
            chains[key] = next;
        }

        chains[parentKey] = _start;
    }

    function _daysToTimestampFrom(uint256 from, uint256 lockDays) internal pure returns(uint256) {
        return SafeMath.add(from, SafeMath.mul(lockDays, SECONDS_IN_DAY));
    }

    function _daysToTimestamp(uint256 lockDays) internal view returns(uint256) {
        return _daysToTimestampFrom(block.timestamp, lockDays);
    }

    function _getBaseLockDays() internal view returns (uint256) {
        return _daysToTimestamp(MINIMAL_FREEZE_PERIOD);
    }

    function _getBaseLockDaysFrom(uint256 from) internal pure returns (uint256) {
        return _daysToTimestampFrom(from, MINIMAL_FREEZE_PERIOD);
    }


    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { // When minting tokens
            require(totalSupply().add(amount) <= _cap, "ERC20Capped: cap exceeded");
        }
    }
}
