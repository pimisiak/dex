pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "./Wallet.sol";
import "../node_modules/@openzeppelin/contracts/math/Math.sol";

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

    function getOrderBook(bytes32 _ticker, Side _side) public view returns(Order[] memory) {
        return orderBook[_ticker][uint(_side)];
    }

    function createLimitOrder(Side _side, bytes32 _ticker, uint256 _amount, uint256 _price) public {
        if (_side == Side.BUY) {
            require(balances[msg.sender][ethTicker] >= _amount.mul(_price), "Insufficient ETH balance");
        }

        if (_side == Side.SELL) {
            require(balances[msg.sender][_ticker] >= _amount, "Insufficient token balance");
        }

        Order[] storage orders = orderBook[_ticker][uint(_side)];
        orders.push(Order(nextOrderId, _amount, _price, 0, msg.sender, _ticker, _side));
        nextOrderId = nextOrderId.add(1);

        //sort orders in order book, for buy side in increasing order, for sell side in decreasing order
        sort(orders, _side);
    }

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

    function swap(Order[] storage _orders, uint _i, uint _j) private {
        Order memory temp = _orders[_i];
        _orders[_i] = _orders[_j];
        _orders[_j] = temp;
    }

    function createMarketOrder(Side _side, bytes32 _ticker, uint256 _amount) public {
        if (_side == Side.SELL) {
            require(balances[msg.sender][_ticker] >= _amount, "Insufficient token balance");
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

            //shift balances
            shiftBalances(orders[i], msg.sender);
        }

        // delete orders that have been filled
        deleteFilledOrders(orders);
    }

    function shiftBalances(Order storage _order, address _sender) private {
        uint cost = _order.filled.mul(_order.price);
        if (_order.side == Side.SELL) {
            // for market buyer we need to check if his eth balance is enough to fill this order
            require(balances[_sender][ethTicker] >= cost, "Insufficient eth balance to complete market order");
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