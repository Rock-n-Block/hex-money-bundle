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
    //QueueLib.Queue public userFreezeQueue;
    //mapping(address => QueueLib.Queue) internal freezingsByUser;


    struct Freezing {
        address user;
        uint256 startDate;
        uint256 freezeDays;
        uint256 baseFreezeDays;
        uint256 freezeAmount;
        bool firstTimeLockPassed;
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


    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }
    
    function getUserFreezings(address _user) public view returns (bytes32[] memory userFreezings) {
        return freezingsByUser[_user];
    }

    function getFreezingById(bytes32 freezingId) public view returns (address user, uint256 startDate, uint256 freezeDays, uint256 freezeAmount) {
        Freezing memory userFreeze = freezings[freezingId];
        user = userFreeze.user;
        startDate = userFreeze.startDate;
        freezeDays = userFreeze.freezeDays;
        freezeAmount = userFreeze.freezeAmount;
    }


    function freeze(address _to, uint256 _start, uint256 _freezeDays, uint256 _amount) internal {
        require(_to != address(0x0), "FreezeContract: address cannot be zero");
        require(_start >= block.timestamp, "FreezeContract: start date cannot be in past");
        require(_freezeDays >= 0, "FreezeContract: amount of freeze days cannot be zero");
        require(_amount <= _balances[_to]);

        Freezing memory userFreeze = Freezing({
            user: _to,
            startDate: _start,
            freezeDays: _freezeDays,
            baseFreezeDays: _freezeDays,
            freezeAmount: _amount,
            firstTimeLockPassed: false
        });

        bytes32 freezeId = _toFreezeKey(_to, _start);

        _balances[msg.sender] = _balances[msg.sender].sub(_amount);
        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        freezings[freezeId] = userFreeze;
        freezingsByUser[_to].push(freezeId);
        //QueueLib.push(freezingsByUser[_to], freezeId);

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
            baseFreezeDays: _freezeDays,
            freezeAmount: _amount,
            firstTimeLockPassed: false
        });

        bytes32 freezeId = _toFreezeKey(_to, _start);

        freezingBalance[_to] = freezingBalance[_to].add(_amount);

        freezings[freezeId] = userFreeze;
        //QueueLib.push(freezingsByUser[_to], freezeId);
        freezingsByUser[_to].push(freezeId);

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
        require(block.timestamp >= lockUntil);

        uint256 amount = userFreeze.freezeAmount;

        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        freezingBalance[_msgSender()] = freezingBalance[_msgSender()].sub(amount);

        _deleteFreezing(freezeId, freezingsByUser[_msgSender()]);
        //QueueLib.drop(freezingsByUser[_msgSender()], freezeId);

        emit Released(_msgSender(), amount);
    }

    function refreeze(uint256 _startTime, uint256 addAmount) internal {
        bytes32 freezeId = _toFreezeKey(_msgSender(), _startTime);
        Freezing memory userFreeze = freezings[freezeId];

        if (!userFreeze.firstTimeLockPassed) {
            uint256 lockUntil = _daysToTimestampFrom(userFreeze.startDate, userFreeze.freezeDays);
            require(block.timestamp >= lockUntil, "cannot refreeze in first lock period");

            userFreeze.firstTimeLockPassed = true;
        }

        userFreeze.freezeDays = SafeMath.add(userFreeze.freezeDays, userFreeze.baseFreezeDays);
        userFreeze.freezeAmount = SafeMath.add(userFreeze.freezeAmount, addAmount);

        freezingBalance[_msgSender()] = freezingBalance[_msgSender()].add(addAmount);
    }

    function _deleteFreezing(bytes32 freezingId, bytes32[] storage userFreezings) internal {
        for (uint256 i; i < userFreezings.length; i++) {
            if (userFreezings[i] == freezingId) {
                delete userFreezings[i];
            }
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
