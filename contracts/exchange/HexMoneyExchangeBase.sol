pragma solidity ^0.6.2;


import "../base/HexMoneyInternal.sol";
import "../HexMoneyDividends.sol";

import "../token/HXY.sol";

abstract contract HexMoneyExchangeBase is HexMoneyInternal {
    HXY internal hxyToken;
    address payable dividendsContract;

    uint256 internal decimals;
    uint256 internal minAmount;
    uint256 internal maxAmount;

    constructor (HXY _hxyToken, address payable _dividendsContract) public {
        require(address(_hxyToken) != address(0x0), "hxy token address should not be empty");
        require(address(_dividendsContract) != address(0x0), "hxy token address should not be empty");
        hxyToken = _hxyToken;
        dividendsContract = _dividendsContract;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getMinAmount() public view returns (uint256) {
        return minAmount;
    }

    function getMaxAmount() public view returns (uint256) {
        return maxAmount;
    }

    function getHxyTokenAddress() public view returns (address) {
        return address(hxyToken);
    }

    function getDividendsContractAddress() public view returns (address) {
        return address(dividendsContract);
    }

    function setMinAmount(uint256 newAmount) public onlyAdminRole {
        minAmount = SafeMath.mul(newAmount, decimals);
    }

    function setMaxAmount(uint256 newAmount) public onlyAdminRole {
        maxAmount = SafeMath.mul(newAmount, decimals);
    }

    function setHxyToken(address newHxyToken) public onlyAdminRole {
        require(newHxyToken != address(0x0), "Invalid HXY token address");
        hxyToken = HXY(newHxyToken);
    }

    function setDividendsContract(address payable newDividendsContract) public onlyAdminRole {
        require(newDividendsContract != address(0x0), "Invalid HXY token address");
        dividendsContract = newDividendsContract;
    }

    function _addToDividends(uint256 _amount) internal virtual {
    }
}
