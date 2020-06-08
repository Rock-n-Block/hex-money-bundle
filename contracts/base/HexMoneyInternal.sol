pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../whitelist/HexWhitelist.sol";

contract HexMoneyInternal is AccessControl, ReentrancyGuard  {
    // production
    uint256 public constant SECONDS_IN_DAY = 86400;

    // dev-test
    // uint256 public constant SECONDS_IN_DAY = 120;

    HexWhitelist internal whitelist;

    modifier onlyAdminRole() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role");
        _;
    }

    function getWhitelistAddress() public view returns (address) {
        return address(whitelist);
    }

    function setWhitelistAddress(address newWhitelistAddress) public onlyAdminRole {
        require(newWhitelistAddress != address(0x0), "Invalid whitelist address");
        whitelist = HexWhitelist(newWhitelistAddress);
    }

}