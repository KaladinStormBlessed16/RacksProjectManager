// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockErc20 is ERC20 {
	constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
		_mint(msg.sender, 10000 * 1e18);
	}

	function mintMore() external {
		_mint(msg.sender, 10000 * 1e18);
	}
}
