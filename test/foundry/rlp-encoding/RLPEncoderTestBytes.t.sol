// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RLPEncoderHelper} from "./helpers/RLPEncoderHelper.sol";

contract RLPEncoderTestBytes is DSTestPlus {

    function testRLPEncoderBytesPreset() public {
        bytes memory in0 = "Hello";
        bytes memory in1 = "World";
        bytes memory in2 = "!";

        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (bytes memory out0, bytes memory out1, bytes memory out2) = abi.decode(buf, (bytes, bytes, bytes));
        assertBytesEq(out0, in0);
        assertBytesEq(out1, in1);
        assertBytesEq(out2, in2);
    }

    function testRLPEncoderTest() public {
        bytes memory in0 = hex'2a';
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        bytes memory out0 = abi.decode(buf, (bytes));
        assertBytesEq(in0, out0);
    }

    function testRLPEncoderBytes(bytes memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        bytes memory out0 = abi.decode(buf, (bytes));
        assertBytesEq(out0, in0);
    }

    function testRLPEncoderBytesBytes(bytes memory in0, bytes memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (bytes memory out0, bytes memory out1) = abi.decode(buf, (bytes, bytes));
        assertBytesEq(out0, in0);
        assertBytesEq(out1, in1);
    }

    function testRLPEncoderBytesBytesBytes(bytes memory in0, bytes memory in1, bytes memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (bytes memory out0, bytes memory out1, bytes memory out2) = abi.decode(buf, (bytes, bytes, bytes));
        assertBytesEq(out0, in0);
        assertBytesEq(out1, in1);
        assertBytesEq(out2, in2);
    }

    function testRLPEncoderBytesArray(bytes[] memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        bytes[] memory out0 = abi.decode(buf, (bytes[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) {
                assertBytesEq(out0[i], in0[i]);
            } else {
                assertBytesEq(out0[i], new bytes(0));
            }
        }
    }

    function testRLPEncoderBytesArrayBytesArray(bytes[] memory in0, bytes[] memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (bytes[] memory out0, bytes[] memory out1) = abi.decode(buf, (bytes[], bytes[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) {
                assertBytesEq(out0[i], in0[i]);
            } else {
                assertBytesEq(out0[i], new bytes(0));
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) { 
                assertBytesEq(out1[i], in1[i]);
            } else {
                assertBytesEq(out1[i], new bytes(0));
            }
        }
    }

    function testRLPEncoderBytesArrayBytesArrayBytesArray(bytes[] memory in0, bytes[] memory in1, bytes[] memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (bytes[] memory out0, bytes[] memory out1, bytes[] memory out2) = abi.decode(buf, (bytes[], bytes[], bytes[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) {
                assertBytesEq(out0[i], in0[i]);
            } else {
                assertBytesEq(out0[i], new bytes(0));
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) { 
                assertBytesEq(out1[i], in1[i]);
            } else {
                assertBytesEq(out1[i], new bytes(0));
            }
        }
        for (uint256 i = 0; i < out2.length; i++) {
            if (i < in2.length) { 
                assertBytesEq(out2[i], in2[i]);
            } else {
                assertBytesEq(out2[i], new bytes(0));
            }
        }
    }

    function testRLPEncoderBytesArrayBytesBytes(bytes[] memory in0, bytes memory in1, bytes memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (bytes[] memory out0, bytes memory out1, bytes memory out2) = abi.decode(buf, (bytes[], bytes, bytes));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) {
                assertBytesEq(out0[i], in0[i]);
            } else {
                assertBytesEq(out0[i], new bytes(0));
            }
        }
        assertBytesEq(out1, in1);
        assertBytesEq(out2, in2);
    }

    function testRLPEncoderBytesArrayBytesArrayBytes(bytes[] calldata in0, bytes[] calldata in1, bytes memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (bytes[] memory out0, bytes[] memory out1, bytes memory out2) = abi.decode(buf, (bytes[], bytes[], bytes));
        for (uint256 i = 0; i < out0.length; i++) {
            if(i < in0.length){ 
                assertBytesEq(out0[i], in0[i]);
            } else {
                assertBytesEq(out0[i], new bytes(0));
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if(i < in1.length){
                assertBytesEq(out1[i], in1[i]);
            } else {
                assertBytesEq(out1[i], new bytes(0));
            }
        }
        assertBytesEq(out2, in2);
    }
}
