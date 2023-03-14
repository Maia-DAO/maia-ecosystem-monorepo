// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RLPEncoderHelper} from "./helpers/RLPEncoderHelper.sol";

contract RLPEncoderTest is DSTestPlus {

    function testRLPEncoderEmpty() public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(), 0);

        assertBytesEq(buf, new bytes(0));
    }

    struct IntPacked {
        bytes16 first;
        bytes16 second;
    }
    function testRLPEncoderTest() public {
        bytes16 in0 = hex'ac';
        bytes16 in1 = hex'bd';
        IntPacked memory packed0 = IntPacked({first: in0, second: in1});
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(packed0), 0);

        IntPacked memory out0 = abi.decode(buf, (IntPacked));
        assertEq(out0.first, packed0.first, "Output 0 mismatch");
        assertEq(out0.second, packed0.second, "Output 0 mismatch");
    }

    function testRLPEncoderUintAddressStringBytes(uint256 in0, address in1, string memory in2, bytes memory in3) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2, in3), 0);

        (uint256 out0, address out1, string memory out2, bytes memory out3) = abi.decode(buf, (uint256, address, string, bytes));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
        assertBytesEq(out3, in3);
    }

    function testRLPEncoderUintArrayAddressStringBytes(uint256[] memory in0, address in1, string memory in2, bytes memory in3) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2, in3), 0);

        (uint256[] memory out0, address out1, string memory out2, bytes memory out3) = abi.decode(buf, (uint256[], address, string, bytes));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
        assertBytesEq(out3, in3);
    }

    function testRLPEncoderUintArrayAddressArrayStringArrayBytesArray(uint256[] memory in0, address[] memory in1, string[] memory in2, bytes[] memory in3) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2, in3), 0);

        (uint256[] memory out0, address[] memory out1, string[] memory out2, bytes[] memory out3) = abi.decode(buf, (uint256[], address[], string[], bytes[]));
        for (uint256 i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], 0, "Output 0 not zero");
            }
        }
        for (uint i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], address(0), "Output 1 not zero");
            }
        }
        for (uint256 i = 0; i < out2.length; i++) {
            if(i < in2.length){
                assertEq(out2[i], in2[i], "Output 2 mismatch");
            } else {
                assertEq(out2[i], "", "Output 2 not zero");
            }
        }
        for (uint256 i = 0; i < out3.length; i++) {
            if (i < in3.length) { 
                assertBytesEq(out3[i], in3[i]);
            } else {
                assertBytesEq(out3[i], new bytes(0));
            }
        }
    }
}
