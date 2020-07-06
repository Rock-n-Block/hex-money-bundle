pragma solidity ^0.6.2;


import "../base/HexMoneyInternal.sol";
import "../token/HXY.sol";
import "../whitelist/HexWhitelist.sol";


contract HexMoneyReferralSender is HexMoneyInternal {
    HXY internal hxyToken;
    HexWhitelist internal whitelistContract;

    uint256 internal referralPercentage = 20;

    constructor (HXY _hxyToken, address _whitelistContract, address _adminAddress) public {
        require(address(_hxyToken) != address(0x0), "hxy token address should not be empty");
        require(address(_whitelistContract) != address(0x0), "hxy token address should not be empty");
        require(address(_adminAddress) != address(0x0), "hxy token address should not be empty");
        hxyToken = _hxyToken;
        whitelistContract = HexWhitelist(_whitelistContract);

        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(DEPLOYER_ROLE, _msgSender());
    }

    function getHxyTokenAddress() public view returns (address) {
        return address(hxyToken);
    }

    function getWhitelistontractAddress() public view returns (address) {
        return address(whitelistContract);
    }

    function mintToReferral(address referralAddress, uint256 hexAmount) public {
        bool isRegisteredCaller = HexWhitelist(whitelistContract).isRegisteredExchange(_msgSender());
        require(isRegisteredCaller, "must be called from exchange");
        _mintToReferral(referralAddress, hexAmount);
    }

    function getReferralPercentage() public view returns (uint256) {
        return referralPercentage;
    }

    // function getMinterFreezings() public view onlyAdminOrDeployerRole returns (bytes32[] memory) {
    //     return HXY(hxyToken).getUserFreezings(address(this));
    // }

    function releaseMinterFreezing(uint256 startDate) public onlyAdminOrDeployerRole {
        HXY(hxyToken).releaseFrozen(startDate);
    }

    function transferMinterFreezing(address _to, uint256 amount) public onlyAdminOrDeployerRole {
        HXY(hxyToken).transfer(address(_to), amount);
    }

    function setReferralPercentage(uint256 newPercentage) public onlyAdminOrDeployerRole {
        require(newPercentage > 0 && newPercentage < 100, "wrong referral percentage value");
        referralPercentage = newPercentage;
    }

    function _mintToReferral(address referralAddress, uint256 hexAmount) internal {
        uint256 referralAmount = SafeMath.div(hexAmount, HXY(hxyToken).getCurrentHxyRate());
        HXY(hxyToken).mintFromDappOrReferral(referralAddress, referralAmount);
        HXY(hxyToken).freezeHxy(referralAmount);
   }
}
