// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Wallet
 * @dev Implementation of the wallet with the ability to store different tokens.
 */
contract Wallet is Ownable {

    using SafeMath for uint256;

    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }

    bytes32 internal ethTicker = bytes32("ETH");
    bytes32[] public tokenList;
    mapping(bytes32 => Token) public tokenMapping;
    mapping(address => mapping(bytes32 => uint256)) public balances;

    /**
     * @dev Ensures that the token is supported by the contract. 
     */
    modifier tokenExists(bytes32 _ticker) {
        require(tokenMapping[_ticker].tokenAddress != address(0), "Token is not supported.");
        _;
    }

    /**
     * @dev Adds token to the token list that is supported by the contract.
     *
     * Requirements:
     * - can be called only by the owner of the contract.
     */
    function addToken(bytes32 _ticker, address _tokenAddress) onlyOwner() external {
        tokenMapping[_ticker] = Token(_ticker, _tokenAddress);
        tokenList.push(_ticker);
    }

    /**
     * @dev Deposits ETH to contract. 
     */
    function depositEth() external payable {
        balances[msg.sender][ethTicker] = balances[msg.sender][ethTicker].add(msg.value);
    }

    /**
     * @dev Withdraws ETH from contract. 
     */
    function withdrawEth(uint256 _amount) external {
        require(balances[msg.sender][ethTicker] >= _amount);
        balances[msg.sender][ethTicker] = balances[msg.sender][ethTicker].sub(_amount);
        msg.sender.transfer(_amount);
    }

    /**
     * @dev Deposits an amount of token with the given ticker to the wallet.
     *
     * Requirements:
     * - token with the given ticker must be supported.
     * - deposited amount must be bigger than 0.
     */
    function deposit(uint _amount, bytes32 _ticker) tokenExists(_ticker) external {
        require(_amount > 0, "Insufficient amount deposited.");
        IERC20(tokenMapping[_ticker].tokenAddress).transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender][_ticker] = balances[msg.sender][_ticker].add(_amount);
    }

    /**
     * @dev Withdraws an amount of token with the given ticker from the wallet.
     *
     * Requirements:
     * - token with the given ticker must be supported.
     * - token balance of the caller must ba at least equal to amount. 
     */
    function withdraw(uint _amount, bytes32 _ticker) tokenExists(_ticker) external {
        require(balances[msg.sender][_ticker] >= _amount, "Insufficient balance.");   
        balances[msg.sender][_ticker] = balances[msg.sender][_ticker].sub(_amount);
        IERC20(tokenMapping[_ticker].tokenAddress).transfer(msg.sender, _amount);
    }
}