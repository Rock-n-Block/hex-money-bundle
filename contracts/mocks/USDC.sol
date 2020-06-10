pragma solidity ^0.6.2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract USDC is ERC20 {
    constructor(address account, uint256 initialSupply) ERC20("TST-USDC", "TST-USDC") public {
        _setupDecimals(18);
        _mint(account, initialSupply);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}