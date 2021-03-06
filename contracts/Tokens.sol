// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Dummy token contract used in tests.
 */
contract DummyLink is ERC20 {
    constructor() ERC20("ChainLink", "LINK") {
        _mint(msg.sender, 1000);
    }
}