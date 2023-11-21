// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibPRNG} from "@solady/utils/LibPRNG.sol";
import {MinAggregatorHarness} from "test/utils/MinAggregatorHarness.sol";
import {PackedUint32Array} from "src/lib/PackedUint32Array.sol";

contract MinAggregatorTest is Test {
    uint256 private constant SHUFFLE_ITERATIONS = 100;
    MinAggregatorHarness immutable harness;

    constructor() {
        address[] memory oracles = new address[](1);
        oracles[0] = makeAddr("oracle");
        harness = new MinAggregatorHarness(oracles, 1);
    }

    function test_AggregateQuotes(LibPRNG.PRNG memory prng, uint256[] memory quotes, PackedUint32Array mask) public {
        vm.assume(quotes.length > 0 && quotes.length <= 8);

        uint256 min = type(uint256).max;
        for (uint256 i = 0; i < quotes.length; ++i) {
            if (quotes[i] < min) min = quotes[i];
        }

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = harness.aggregateQuotes(quotes, mask);
            assertEq(result, min);
        }
    }

    function test_AggregateQuotes_Concrete(LibPRNG.PRNG memory prng, PackedUint32Array mask) public {
        uint256[] memory quotes = new uint256[](3);
        quotes[0] = 0;
        quotes[1] = 1;
        quotes[2] = 2;

        for (uint256 i = 0; i < SHUFFLE_ITERATIONS; ++i) {
            LibPRNG.shuffle(prng, quotes);
            uint256 result = harness.aggregateQuotes(quotes, mask);
            assertEq(result, 0);
        }
    }
}