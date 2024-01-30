// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPyth} from "@pyth/IPyth.sol";
import {PythStructs} from "@pyth/PythStructs.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";
import {IEOracle} from "src/interfaces/IEOracle.sol";
import {Errors} from "src/lib/Errors.sol";
import {OracleDescription} from "src/lib/OracleDescription.sol";

contract PythOracle is IEOracle {
    uint256 internal constant MAX_CONF_WIDTH_BPS = 500; // confidence interval can be at most 5% of price

    IPyth public immutable pyth;
    address public immutable base;
    address public immutable quote;
    bytes32 public immutable feedId;
    uint256 public immutable maxStaleness;
    bool public immutable inverse;
    uint8 internal immutable baseDecimals;
    uint8 internal immutable quoteDecimals;

    constructor(address _pyth, address _base, address _quote, bytes32 _feedId, uint256 _maxStaleness, bool _inverse) {
        pyth = IPyth(_pyth);
        base = _base;
        quote = _quote;
        feedId = _feedId;
        maxStaleness = _maxStaleness;
        inverse = _inverse;
        baseDecimals = ERC20(_base).decimals();
        quoteDecimals = ERC20(_quote).decimals();
    }

    function updatePrice(bytes[] calldata updateData) external payable {
        IPyth(pyth).updatePriceFeeds{value: msg.value}(updateData);
    }

    function getQuote(uint256 inAmount, address _base, address _quote) external view returns (uint256) {
        PythStructs.Price memory priceStruct = _fetchPriceStruct(_base, _quote);
        uint64 midPrice = uint64(priceStruct.price);

        if (inverse) {
            int32 exponent = priceStruct.expo - int8(quoteDecimals) + int8(baseDecimals);
            return _calcInversePrice(inAmount, midPrice, exponent);
        } else {
            int32 exponent = priceStruct.expo + int8(quoteDecimals) - int8(baseDecimals);
            return _calcPrice(inAmount, midPrice, exponent);
        }
    }

    function getQuotes(uint256 inAmount, address _base, address _quote) external view returns (uint256, uint256) {
        PythStructs.Price memory priceStruct = _fetchPriceStruct(_base, _quote);
        uint256 bidPrice = uint256(int256(priceStruct.price) - int64(priceStruct.conf));
        uint256 askPrice = uint256(int256(priceStruct.price) + int64(priceStruct.conf));

        if (inverse) {
            int32 exponent = priceStruct.expo - int8(quoteDecimals) + int8(baseDecimals);
            return (_calcInversePrice(inAmount, askPrice, exponent), _calcInversePrice(inAmount, bidPrice, exponent));
        } else {
            int32 exponent = priceStruct.expo + int8(quoteDecimals) - int8(baseDecimals);
            return (_calcPrice(inAmount, bidPrice, exponent), _calcPrice(inAmount, askPrice, exponent));
        }
    }

    function description() external view returns (OracleDescription.Description memory) {
        return OracleDescription.PythOracle(maxStaleness);
    }

    function _fetchPriceStruct(address _base, address _quote) internal view returns (PythStructs.Price memory) {
        if (base != _base || quote != _quote) revert Errors.EOracle_NotSupported(_base, _quote);
        PythStructs.Price memory p = pyth.getPriceNoOlderThan(feedId, maxStaleness);
        if (p.price <= 0) {
            revert Errors.Pyth_InvalidPrice(p.price);
        }

        if (p.conf > uint64(p.price) * MAX_CONF_WIDTH_BPS / 10_000) {
            revert Errors.Pyth_InvalidConfidenceInterval(p.price, p.conf);
        }

        if (p.expo > 16 || p.expo < -16) {
            revert Errors.Pyth_InvalidExponent(p.expo);
        }
        return p;
    }

    function _calcInversePrice(uint256 inAmount, uint256 price, int32 exponent) internal pure returns (uint256) {
        if (exponent > 0) {
            return (inAmount / (price * 10 ** uint32(exponent)));
        } else {
            return (inAmount * 10 ** uint32(-exponent) / price);
        }
    }

    function _calcPrice(uint256 inAmount, uint256 price, int32 exponent) internal pure returns (uint256) {
        if (exponent > 0) {
            return (inAmount * price * 10 ** uint32(exponent));
        } else {
            return (inAmount * price / 10 ** uint32(-exponent));
        }
    }
}
