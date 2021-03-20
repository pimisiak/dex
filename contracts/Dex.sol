pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "./Wallet.sol";

contract Dex is Wallet {

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

    function getOrderBook(bytes32 _ticker, Side _side) view public returns(Order[] memory) {
        return orderBook[_ticker][uint(_side)];
    }

    /*
    function createLimitOrder() {}

    function createMarketOrder() {}
    */
}