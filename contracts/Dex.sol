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
        Side side;
        bytes32 ticker;
        uint amount;
        uint price;
    }

    uint public nextOrderId = 0;
    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    function getOrderBook(bytes32 _ticker, Side _side) public view returns(Order[] memory) {
        return orderBook[_ticker][uint(_side)];
    }

    function createLimitOrder(Side _side, bytes32 _ticker, uint256 _amount, uint256 _price) public {
        if (_side == Side.BUY) {
            require(balances[msg.sender][ethTicker] >= _amount.mul(_price));
        }
        if (_side == Side.SELL) {
            require(balances[msg.sender][_ticker] >= _amount);
        }
        Order[] storage orders = orderBook[_ticker][uint(_side)];
        orders.push(Order(nextOrderId, msg.sender, _side, _ticker, _amount, _price));
        nextOrderId = nextOrderId.add(1);
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

    function createMarketOrder(Side _side, bytes32 _ticker, uint256 _amount, uint256 _price) public {
        //TODO
    }
}