pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../whitelist/HexWhitelist.sol";

contract HexMoneyInternal is AccessControl, ReentrancyGuard  {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    // production
    uint256 public constant SECONDS_IN_DAY = 86400;

    HexWhitelist internal whitelist;

    modifier onlyAdminOrDeployerRole() {
        bool hasAdminRole = hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
        bool hasDeployerRole = hasRole(DEPLOYER_ROLE, _msgSender());
        require(hasAdminRole || hasDeployerRole, "Must have admin or deployer role");
        _;
    }

    function getWhitelistAddress() public view returns (address) {
        return address(whitelist);
    }

}