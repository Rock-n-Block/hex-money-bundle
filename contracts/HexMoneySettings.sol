pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./HexWhitelist.sol";

contract HexMoneySettings is AccessControl  {
    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
    uint256 public constant secondsInDay = 86400;

    address internal teamAddress;

    HexWhitelist internal whitelist;

    modifier onlyAdminRole() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        _;
    }

    modifier onlyTeamRole() {
        require(hasRole(TEAM_ROLE, _msgSender()), "Must have admin role to setup");
        _;
    }

    function getTeamAddress() public view returns (address) {
        return teamAddress;
    }

    function getWhitelistAddress() public view returns (address) {
        return address(whitelist);
    }

    function setWhitelistAddress(address newWhitelistAddress) public onlyAdminRole {
        require(newWhitelistAddress != address(0x0), "Invalid whitelist address");
        whitelist = HexWhitelist(newWhitelistAddress);
    }

}