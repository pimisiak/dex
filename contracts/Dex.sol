// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "./Wallet.sol";
import "../node_modules/@openzeppelin/contracts/math/Math.sol";

/**
 * @title Dex
 * @dev Implementation of the Decentralized Exchange. 
 *
 * This Dex allows to create limit orders and market orders.
 * Tokens can be bought with and sold for ETH.
 *
 * It is a simple version of decentralized exchange which stores
 * information of the orders in the contract storage. 
 */
contract Dex is Wallet {

    using SafeMath for uint256;
    using Math for uint256;

    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint id;
        uint amount;
        uint price;
        uint filled;
        address trader;
        bytes32 ticker;
        Side side;
    }

    uint public nextOrderId = 0;
    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    /**
     * @dev Returns the order book for the given ticker and order side.
     *
     * Requirements:
     * - token with the given ticker must be supported.
     */
    function getOrderBook(bytes32 _ticker, Side _side) public view tokenExists(_ticker) returns(Order[] memory) {
        return orderBook[_ticker][uint(_side)];
    }

    /**
     * @dev Creates a limit order for a given order side, token ticker, token amount and ETH price.
     */
    function createLimitOrder(Side _side, bytes32 _ticker, uint256 _amount, uint256 _price) public tokenExists(_ticker) {
        if (_side == Side.BUY) {
            require(balances[msg.sender][ethTicker] >= _amount.mul(_price), "Insufficient ETH balance.");
        }

        if (_side == Side.SELL) {
            require(balances[msg.sender][_ticker] >= _amount, "Insufficient token balance.");
        }

        Order[] storage orders = orderBook[_ticker][uint(_side)];
        orders.push(Order(nextOrderId, _amount, _price, 0, msg.sender, _ticker, _side));
        nextOrderId = nextOrderId.add(1);
        sort(orders, _side);
    }

    /**
     * @dev Sorts orders in the order book using simplified bubble sort.
     *
     * Because new order is always added at the end of the sorted order book
     * sorting comes down to finding the right place in the order book for 
     * a new order. It is done by swapping orders in the order book until
     * price condition is met.
     *
     * Sell side of the order book is sorted in decreasing order,
     * buy side is sorted in increasing order.
     */
    function sort(Order[] storage _orders, Side _side) private {
        for (uint i = _orders.length - 1; i > 0; i--) {
            if (Side.BUY == _side && _orders[i].price < _orders[i - 1].price 
            || Side.SELL == _side && _orders[i].price > _orders[i - 1].price) {
                swap(_orders, i, i - 1);
            } else {
                break;
            }
        }
    }

    /**
     * @dev Performs a simple swap of two orders in the order book.
     */
    function swap(Order[] storage _orders, uint _i, uint _j) private {
        Order memory temp = _orders[_i];
        _orders[_i] = _orders[_j];
        _orders[_j] = temp;
    }

    /**
     * @dev Creates a market order for a given order side, token ticker and token amount.
     *
     * Requirements:
     * - token with the given ticker must be supported.
     * - token balance of the caller must ba at least equal to amount. 
     */
    function createMarketOrder(Side _side, bytes32 _ticker, uint256 _amount) public tokenExists(_ticker) {
        if (_side == Side.SELL) {
            require(balances[msg.sender][_ticker] >= _amount, "Insufficient token balance.");
        }

        // get correct order book (sell for market buyer, buy for market seller)
        Order[] storage orders = orderBook[_ticker][_side == Side.BUY ? 1 : 0];

        // if there's no orders in orderbook then market order should have no effects
        if (orders.length < 1) return;

        // fill the orders
        uint leftToFill = _amount;
        uint i = orders.length;
        while (i > 0 && leftToFill > 0) {
            i = i.sub(1);
            uint availableToFill = orders[i].amount.sub(orders[i].filled);
            orders[i].filled = leftToFill >= availableToFill ? orders[i].amount : orders[i].filled.add(leftToFill);
            leftToFill = leftToFill >= availableToFill ? leftToFill.sub(availableToFill) : 0;
            shiftBalances(orders[i], msg.sender);
        }

        deleteFilledOrders(orders);
    }

    /**
     * @dev Shifts balances of the seller/buyer participating in the order.
     *
     * Requirements:
     * - for market buyer his eth balance must be enough to fill the order
     */
    function shiftBalances(Order storage _order, address _sender) private {
        uint cost = _order.filled.mul(_order.price);
        if (_order.side == Side.SELL) {
            require(balances[_sender][ethTicker] >= cost, "Insufficient ETH balance to complete market order.");
            balances[_sender][_order.ticker] = balances[_sender][_order.ticker].add(_order.filled);
            balances[_sender][ethTicker] = balances[_sender][ethTicker].sub(cost);
            balances[_order.trader][_order.ticker] = balances[_order.trader][_order.ticker].sub(_order.filled);
            balances[_order.trader][ethTicker] = balances[_order.trader][ethTicker].add(cost);
        } else {
            balances[_sender][_order.ticker] = balances[_sender][_order.ticker].sub(_order.filled);
            balances[_sender][ethTicker] = balances[_sender][ethTicker].add(cost);
            balances[_order.trader][_order.ticker] = balances[_order.trader][_order.ticker].add(_order.filled);    
            balances[_order.trader][ethTicker] = balances[_order.trader][ethTicker].sub(cost);
        }
    }

    /**
     * @dev Removes orders from the order book that have been filled.
     */
    function deleteFilledOrders(Order[] storage orders) private {
        while (orders.length > 0) {
            if (orders[orders.length - 1].filled == orders[orders.length - 1].amount) {
                orders.pop();
            } else {
                return;
            }
        }
    }
}