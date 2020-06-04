pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract HexMoneyTeam is AccessControl  {
    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");

    address payable internal teamAddress;

    modifier onlyTeamRole() {
        require(hasRole(TEAM_ROLE, _msgSender()), "Must have admin role to setup");
        _;
    }

    function getTeamAddress() public view returns (address) {
        return teamAddress;
    }
}