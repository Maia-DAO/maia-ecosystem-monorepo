// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RLPEncoderHelper} from "./helpers/RLPEncoderHelper.sol";

contract RLPEncoderTestString is DSTestPlus {

    function testRLPEncoderStringPreset() public {
        string memory in0 = "Hello";
        string memory in1 = "World";
        string memory in2 = "!";

        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (string memory out0, string memory out1, string memory out2) = abi.decode(buf, (string, string, string));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderTest() public {
        string memory in0 = "HERMES";
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        string memory out0 = abi.decode(buf, (string));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderString(string memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        string memory out0 = abi.decode(buf, (string));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderStringString(string memory in0, string memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (string memory out0, string memory out1) = abi.decode(buf, (string, string));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
    }

    function testRLPEncoderStringStringString(string memory in0, string memory in1, string memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (string memory out0, string memory out1, string memory out2) = abi.decode(buf, (string, string, string));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderStringArray(string[] memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        string[] memory out0 = abi.decode(buf, (string[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], "", "Output 0 not zero");
            }
        }
    }

    function testRLPEncoderStringArrayStringArray(string[] memory in0, string[] memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (string[] memory out0, string[] memory out1) = abi.decode(buf, (string[], string[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], "", "Output 0 not zero");
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], "", "Output 1 not zero");
            }
        }
    }

    function testRLPEncoderStringArrayStringArrayStringArray(string[] memory in0, string[] memory in1, string[] memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (string[] memory out0, string[] memory out1, string[] memory out2) = abi.decode(buf, (string[], string[], string[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], "", "Output 0 not zero");
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], "", "Output 1 not zero");
            }
        }
        for (uint256 i = 0; i < out2.length; i++) {
            if (i < in2.length) {
                assertEq(out2[i], in2[i], "Output 2 mismatch");
            } else {
                assertEq(out2[i], "", "Output 2 not zero");
            }
        }
    }

    function testRLPEncoderStringArrayStringString(string[] memory in0, string memory in1, string memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (string[] memory out0, string memory out1, string memory out2) = abi.decode(buf, (string[], string, string));
        for (uint256 i = 0; i < out0.length; i++) {
            if(i < in0.length){ 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], "", "Output 0 not zero");
            }
        }
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderStringArrayStringArrayString(string[] calldata in0, string[] calldata in1, string memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (string[] memory out0, string[] memory out1, string memory out2) = abi.decode(buf, (string[], string[], string));
        for (uint256 i = 0; i < out0.length; i++) {
            if(i < in0.length){ 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], "", "Output 0 not zero");
            }
        }
        for (uint256 i = 0; i < out1.length; i++) {
            if(i < in1.length){
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], "", "Output 1 not zero");
            }
        }
        assertEq(out2, in2, "Output 2 mismatch");
    }
}
