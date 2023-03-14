// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RLPEncoderHelper} from "./helpers/RLPEncoderHelper.sol";

contract RLPEncoderTestInt is DSTestPlus {

    function testRLPEncoderIntPreset() public {
        int256 in0 = 6;
        int256 in1 = 12;
        int256 in2 = 255;

        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (int256 out0, int256 out1, int256 out2) = abi.decode(buf, (int256, int256, int256));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderTest() public {
        int256 in0 = -5000;
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        int256 out0 = abi.decode(buf, (int256));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderInt(int256 in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        int256 out0 = abi.decode(buf, (int256));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderIntInt(int256 in0, int256 in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (int256 out0, int256 out1) = abi.decode(buf, (int256, int256));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
    }

    function testRLPEncoderIntIntInt(int256 in0, int256 in1, int256 in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (int256 out0, int256 out1, int256 out2) = abi.decode(buf, (int256, int256, int256));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderIntArray(int256[] memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        int256[] memory out0 = abi.decode(buf, (int256[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
    }

    function testRLPEncoderIntArrayIntArray(int256[] memory in0, int256[] memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (int256[] memory out0, int256[] memory out1) = abi.decode(buf, (int256[], int256[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], 0, "Output 1 not zero");
            }
        }
    }

    function testRLPEncoderIntArrayIntArray(int256[] memory in0, int256[] memory in1, int256[] memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (int256[] memory out0, int256[] memory out1, int256[] memory out2) = abi.decode(buf, (int256[], int256[], int256[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], 0, "Output 1 not zero");
            }
        }
        for (uint256 i = 0; i < out2.length; i++) {
            if (i < in2.length) {
                assertEq(out2[i], in2[i], "Output 2 mismatch");
            } else {
                assertEq(out2[i], 0, "Output 2 not zero");
            }
        }
    }

    function testRLPEncoderIntArrayIntInt(int256[] memory in0, int256 in1, int256 in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (int256[] memory out0, int256 out1, int256 out2) = abi.decode(buf, (int256[], int256, int256));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderIntArrayIntArrayInt(int256[] calldata in0, int256[] calldata in1, int256 in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (int256[] memory out0, int256[] memory out1, int256 out2) = abi.decode(buf, (int256[], int256[], int256));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], 0, "Output 1 not zero");
            }
        }
        assertEq(out2, in2, "Output 2 mismatch");
    }
}
