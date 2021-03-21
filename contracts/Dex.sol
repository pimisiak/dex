pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "./Wallet.sol";

contract Dex is Wallet {

    using SafeMath for uint256;

    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint id;
        address trader;
        bool buyOrder;
        Side side;
        bytes32 ticker;
        uint amount;
        uint price;
    }

    mapping(bytes32 => mapping(uint => Order[])) orderBook;

    function getOrderBook(bytes32 _ticker, Side _side) public view returns(Order[] memory) {
        return orderBook[_ticker][uint(_side)];
    }

    function createLimitOrder(Side _side, bytes32 _ticker, uint256 _amount, uint256 _price) public {
        if (_side == Side.BUY) {
            require(balances[msg.sender][ethTicker] >= _amount.mul(_price));
        }
    }

    function createMarketOrder(Side _side, bytes32 _ticker, uint256 _amount, uint256 _price) public {
        //TODO
    }
}