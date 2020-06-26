pragma solidity ^0.6.2;

import "./HexMoneyReferralSender.sol";
import "../base/HexMoneyInternal.sol";
import "../HexMoneyDividends.sol";

import "../token/HXY.sol";

abstract contract HexMoneyExchangeBase is HexMoneyInternal {
    HXY internal hxyToken;
    address payable internal dividendsContract;
    HexMoneyReferralSender internal referralSender;

    uint256 internal decimals;
    uint256 internal minAmount;
    uint256 internal maxAmount;
    uint256 internal referralPercentage = 20;

    constructor (HXY _hxyToken, address payable _dividendsContract, address _referralSender, address _adminAddress) public {
        require(address(_hxyToken) != address(0x0), "hxy token address should not be empty");
        require(address(_dividendsContract) != address(0x0), "dividends contract address should not be empty");
        require(address(_referralSender) != address(0x0), "referral sender address should not be empty");
        require(address(_adminAddress) != address(0x0), "admin address should not be empty");
        hxyToken = _hxyToken;
        dividendsContract = _dividendsContract;
        referralSender = HexMoneyReferralSender(_referralSender);

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

    function setReferralSenderContract(address _referralSender) public onlyAdminOrDeployerRole {
        require(address(_referralSender) != address(0x0), "referral sender address should not be empty");
        referralSender = HexMoneyReferralSender(_referralSender);
    }

    function disableReferralSenderContract() public onlyAdminOrDeployerRole {
        referralSender = HexMoneyReferralSender(0x0);
    }

    function _addToDividends(uint256 _amount) internal virtual {
    }

    function _validateAmount(uint256 _amount) internal view {
        require(_amount >= minAmount, "amount is too low");
        require(_amount <= maxAmount, "amount is too high");
    }

    function _mintToReferral(address referralAddress, uint256 hexAmount) internal {
        HXY(hxyToken).mintFromExchange(address(referralSender), hexAmount);
        HexMoneyReferralSender(referralSender).mintToReferral(referralAddress, hexAmount);
   }
}
