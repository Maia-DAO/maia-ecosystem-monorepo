// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RLPEncoderHelper} from "./helpers/RLPEncoderHelper.sol";

contract RLPEncoderTestUint is DSTestPlus {

    function testRLPEncoderUintPreset() public {
        uint128 in0 = 6;
        uint128 in1 = 12;
        uint128 in2 = 255;

        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (uint128 out0, uint128 out1, uint128 out2) = abi.decode(buf, (uint128, uint128, uint128));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderTest() public {
        uint128 in0 = 1e19;
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        uint128 out0 = abi.decode(buf, (uint128));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderUint(uint128 in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        uint128 out0 = abi.decode(buf, (uint128));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderUintUint(uint128 in0, uint128 in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (uint128 out0, uint128 out1) = abi.decode(buf, (uint128, uint128));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
    }

    function testRLPEncoderUintUintUint(uint128 in0, uint128 in1, uint128 in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (uint128 out0, uint128 out1, uint128 out2) = abi.decode(buf, (uint128, uint128, uint128));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderUintArray(uint128[] memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        uint128[] memory out0 = abi.decode(buf, (uint128[]));
        for (uint128 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
    }

    function testRLPEncoderUintArrayUintArray(uint128[] memory in0, uint128[] memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (uint128[] memory out0, uint128[] memory out1) = abi.decode(buf, (uint128[], uint128[]));
        for (uint128 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint128 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], 0, "Output 1 not zero");
            }
        }
    }

    function testRLPEncoderUintArrayUintArray(uint128[] memory in0, uint128[] memory in1, uint128[] memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (uint128[] memory out0, uint128[] memory out1, uint128[] memory out2) = abi.decode(buf, (uint128[], uint128[], uint128[]));
        for (uint128 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint128 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], 0, "Output 1 not zero");
            }
        }
        for (uint128 i = 0; i < out2.length; i++) {
            if (i < in2.length) {
                assertEq(out2[i], in2[i], "Output 2 mismatch");
            } else {
                assertEq(out2[i], 0, "Output 2 not zero");
            }
        }
    }

    function testRLPEncoderUintArrayUintUint(uint128[] memory in0, uint128 in1, uint128 in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (uint128[] memory out0, uint128 out1, uint128 out2) = abi.decode(buf, (uint128[], uint128, uint128));
        for (uint128 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderUintArrayUintArrayUint(uint128[] calldata in0, uint128[] calldata in1, uint128 in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (uint128[] memory out0, uint128[] memory out1, uint128 out2) = abi.decode(buf, (uint128[], uint128[], uint128));
        for (uint128 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint128 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], 0, "Output 1 not zero");
            }
        }
        assertEq(out2, in2, "Output 2 mismatch");
    }
}
