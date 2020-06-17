pragma solidity ^0.6.2;


import "../base/HexMoneyInternal.sol";
import "../HexMoneyDividends.sol";

import "../token/HXY.sol";

abstract contract HexMoneyExchangeBase is HexMoneyInternal {
    HXY internal hxyToken;
    address payable internal dividendsContract;

    uint256 internal decimals;
    uint256 internal minAmount;
    uint256 internal maxAmount;

    constructor (HXY _hxyToken, address payable _dividendsContract, address _adminAddress) public {
        require(address(_hxyToken) != address(0x0), "hxy token address should not be empty");
        require(address(_dividendsContract) != address(0x0), "hxy token address should not be empty");
        require(address(_adminAddress) != address(0x0), "hxy token address should not be empty");
        hxyToken = _hxyToken;
        dividendsContract = _dividendsContract;

        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(DEPLOYER_ROLE, _msgSender());
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

    function setMinAmount(uint256 newAmount) public onlyAdminOrDeployerRole {
        minAmount = newAmount;
    }

    function setMaxAmount(uint256 newAmount) public onlyAdminOrDeployerRole {
        maxAmount = newAmount;
    }

    function _addToDividends(uint256 _amount) internal virtual {
    }

    function _validateAmount(uint256 _amount) internal view {
        require(_amount >= minAmount, "amount is too low");
        require(_amount <= maxAmount, "amount is too high");
    }
}
