pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./HexWhitelist.sol";

contract HexMoneySettings is AccessControl  {
    uint256 public constant secondsInDay = 86400;

    HexWhitelist internal whitelist;

    function getWhitelistAddress() public view returns (address) {
        return address(whitelist);
    }

    function setWhitelistAddress(address newWhitelistAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to setup");
        require(newWhitelistAddress != address(0x0), "Invalid whitelist address");
        whitelist = HexWhitelist(newWhitelistAddress);
    }

}