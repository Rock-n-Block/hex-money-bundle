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
    //mapping (bytes32 => uint) internal freezings;
    mapping(bytes32 => Freezing) internal freezings;
    // total freezing balance per address
    mapping (address => uint) internal freezingBalance;

    mapping(address => bytes32[]) internal freezingsByUser;

    mapping (address => uint256) internal latestFreezingTime;

    struct Freezing {
        address user;
        uint256 startDate;
        uint256 freezeDays;
        uint256 freezeAmount;
        bool capitalized;
    }



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

    function latestFreezeTimeOf(address account) public view returns (uint256) {
        return latestFreezingTime[account];
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }
    
    function getUserFreezings(address _user) public view returns (bytes32[] memory userFreezings) {
        return freezingsByUser[_user];
    }

    function getFreezingById(bytes32 freezingId)
        public
        view
        returns (address user, uint256 startDate, uint256 freezeDays, uint256 freezeAmount, bool capitalized)
    {
        Freezing memory userFreeze = freezings[freezingId];
        user = userFreeze.user;
        startDate = userFreeze.startDate;
        freezeDays = userFreeze.freezeDays;
        freezeAmount = userFreeze.freezeAmount;
        capitalized = userFreeze.capitalized;
    }


    function freeze(address _to, uint256 _start, uint256 _freezeDays, uint256 _amount) internal {
        require(_to != address(0x0), "FreezeContract: address cannot be zero");
        require(_start >= block.timestamp, "FreezeContract: start date cannot be in past");
        require(_freezeDays >= 0, "FreezeContract: amount of freeze days cannot be zero");
        require(_amount <= _balances[_msgSender()], "FreezeContract: freeze amount exceeds unfrozen balance");

        Freezing memory userFreeze = Freezing({
            user: _to,
            startDate: _start,
            freezeDays: _freezeDays,
            freezeAmount: _amount,
            capitalized: false
        });

        bytes32 freezeId = _toFreezeKey(_to, _start);

        _balances[_msgSender()] = _balances[_msgSender()].sub(_amount);
        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        freezings[freezeId] = userFreeze;
        freezingsByUser[_to].push(freezeId);
        latestFreezingTime[_to] = _start;

        emit Transfer(_msgSender(), _to, _amount);
        emit Freezed(_to, _start, _amount);
    }

    function mintAndFreeze(address _to, uint256 _start, uint256 _freezeDays, uint256 _amount) internal {
        require(_to != address(0x0), "FreezeContract: address cannot be zero");
        require(_start >= block.timestamp, "FreezeContract: start date cannot be in past");
        require(_freezeDays >= 0, "FreezeContract: amount of freeze days cannot be zero");

        Freezing memory userFreeze = Freezing({
            user: _to,
            startDate: _start,
            freezeDays: _freezeDays,
            freezeAmount: _amount,
            capitalized: false
        });

        bytes32 freezeId = _toFreezeKey(_to, _start);

        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        freezings[freezeId] = userFreeze;
        freezingsByUser[_to].push(freezeId);
        latestFreezingTime[_to] = _start;

        _totalSupply = _totalSupply.add(_amount);

        emit Transfer(_msgSender(), _to, _amount);
        emit Freezed(_to, _start, _amount);
    }

    function _toFreezeKey(address _user, uint256 _startDate) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _startDate));
    }

    function release(uint256 _startTime) internal {
        bytes32 freezeId = _toFreezeKey(_msgSender(), _startTime);
        Freezing memory userFreeze = freezings[freezeId];

        uint256 lockUntil = _daysToTimestampFrom(userFreeze.startDate, userFreeze.freezeDays);
        require(block.timestamp >= lockUntil, "cannot release before lock");

        uint256 amount = userFreeze.freezeAmount;

        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        freezingBalance[_msgSender()] = freezingBalance[_msgSender()].sub(amount);

        _deleteFreezing(freezeId, freezingsByUser[_msgSender()]);

        emit Released(_msgSender(), amount);
    }

    function refreeze(uint256 _startTime, uint256 addAmount) internal {
        bytes32 freezeId = _toFreezeKey(_msgSender(), _startTime);
        Freezing storage userFreeze = freezings[freezeId];

        uint256 lockUntil;
        if (!userFreeze.capitalized) {
            lockUntil = _daysToTimestampFrom(userFreeze.startDate, userFreeze.freezeDays);
        } else {
            lockUntil = _daysToTimestampFrom(userFreeze.startDate, 1);
        }

        require(block.timestamp >= lockUntil, "cannot refreeze before lock");

        bytes32 newFreezeId = _toFreezeKey(userFreeze.user, block.timestamp);
        uint256 oldFreezeAmount = userFreeze.freezeAmount;
        uint256 newFreezeAmount = SafeMath.add(userFreeze.freezeAmount, addAmount);

        Freezing memory newFreeze = Freezing({
            user: userFreeze.user,
            startDate: block.timestamp,
            freezeDays: userFreeze.freezeDays,
            freezeAmount: newFreezeAmount,
            capitalized: true
        });

        freezingBalance[_msgSender()] = freezingBalance[_msgSender()].add(addAmount);

        freezings[newFreezeId] = newFreeze;
        freezingsByUser[userFreeze.user].push(newFreezeId);
        latestFreezingTime[userFreeze.user] = block.timestamp;

        _deleteFreezing(freezeId, freezingsByUser[_msgSender()]);
        delete freezings[freezeId];

        emit Released(_msgSender(), oldFreezeAmount);
        emit Transfer(_msgSender(), _msgSender(), addAmount);
        emit Freezed(_msgSender(), block.timestamp, newFreezeAmount);
    }

    function _deleteFreezing(bytes32 freezingId, bytes32[] storage userFreezings) internal {
        uint256 freezingIndex;
        bool freezingFound;
        for (uint256 i; i < userFreezings.length; i++) {
            if (userFreezings[i] == freezingId) {
                freezingIndex = i;
                freezingFound = true;
            }
        }

        if (freezingFound) {
            userFreezings[freezingIndex] = userFreezings[userFreezings.length - 1];
            delete userFreezings[userFreezings.length - 1];
            userFreezings.pop();
        }
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
