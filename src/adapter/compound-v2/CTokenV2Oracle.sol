// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseOracle} from "src/BaseOracle.sol";
import {ICTokenV2} from "src/adapter/compound-v2/ICTokenV2.sol";
import {Errors} from "src/lib/Errors.sol";
import {OracleDescription} from "src/lib/OracleDescription.sol";

contract CTokenV2Oracle is BaseOracle {
    address public immutable cToken;
    address public immutable underlying;

    constructor(address _cToken) {
        cToken = _cToken;
        underlying = ICTokenV2(_cToken).underlying();
    }

    function getQuote(uint256 inAmount, address base, address quote) external view returns (uint256) {
        return _getQuote(inAmount, base, quote);
    }

    function getQuotes(uint256 inAmount, address base, address quote) external view returns (uint256, uint256) {
        uint256 outAmount = _getQuote(inAmount, base, quote);
        return (outAmount, outAmount);
    }

    function description() external pure returns (OracleDescription.Description memory) {
        return OracleDescription.CTokenV2Oracle();
    }

    function _getQuote(uint256 inAmount, address base, address quote) private view returns (uint256) {
        if (base != cToken || quote != underlying) revert Errors.EOracle_NotSupported(base, quote);

        uint256 rate = ICTokenV2(cToken).exchangeRateStored();
        return inAmount * rate / 1e18;
    }
}
