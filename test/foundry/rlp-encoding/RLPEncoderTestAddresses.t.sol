// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {RLPEncoderHelper} from "./helpers/RLPEncoderHelper.sol";

contract RLPEncoderTestAddresses is DSTestPlus {

    function testRLPEncoderAddressPreset() public {
        address in0 = 0x420000000000000000000000000000000000000A;
        address in1 = 0x420000000000000000000000000000000000000A;
        address in2 = 0x420000000000000000000000000000000000000A;

        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (address out0, address out1, address out2) = abi.decode(buf, (address, address, address));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderTest() public {
        address in0 = address(DEAD_ADDRESS);
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        address out0 = abi.decode(buf, (address));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderAddress(address in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        address out0 = abi.decode(buf, (address));
        assertEq(out0, in0, "Output 0 mismatch");
    }

    function testRLPEncoderAddressAddress(address in0, address in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (address out0, address out1) = abi.decode(buf, (address, address));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
    }

    function testRLPEncoderAddressAddressAddress(address in0, address in1, address in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (address out0, address out1, address out2) = abi.decode(buf, (address, address, address));
        assertEq(out0, in0, "Output 0 mismatch");
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderAddressArray(address[] memory in0) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0), 0);

        address[] memory out0 = abi.decode(buf, (address[]));
        for (uint i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], address(0), "Output 0 not zero");
            }
        }
    }

    function testRLPEncoderAddressArrayAddressArray(address[] memory in0, address[] memory in1) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1), 0);

        (address[] memory out0, address[] memory out1) = abi.decode(buf, (address[], address[]));
        for (uint i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], address(0), "Output 0 not zero");
            }
        }
        for (uint i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], address(0), "Output 1 not zero");
            }
        }
    }

    function testRLPEncoderAddressArrayAddressArray(address[] memory in0, address[] memory in1, address[] memory in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (address[] memory out0, address[] memory out1, address[] memory out2) = abi.decode(buf, (address[], address[], address[]));
        for (uint i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], address(0), "Output 0 not zero");
            }
        }
        for (uint i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], address(0), "Output 1 not zero");
            }
        }
        for (uint i = 0; i < out2.length; i++) {
            if (i < in2.length) {
                assertEq(out2[i], in2[i], "Output 2 mismatch");
            } else {
                assertEq(out2[i], address(0), "Output 2 not zero");
            }
        }
    }

    function testRLPEncoderAddressArrayAddressAddress(address[] memory in0, address in1, address in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (address[] memory out0, address out1, address out2) = abi.decode(buf, (address[], address, address));
        for (uint i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], address(0), "Output 0 not zero");
            }
        }
        assertEq(out1, in1, "Output 1 mismatch");
        assertEq(out2, in2, "Output 2 mismatch");
    }

    function testRLPEncoderAddressArrayAddressArrayAddress(address[] calldata in0, address[] calldata in1, address in2) public {
        bytes memory buf = RLPEncoderHelper.encodeAndDecode(abi.encode(in0, in1, in2), 0);

        (address[] memory out0, address[] memory out1, address out2) = abi.decode(buf, (address[], address[], address));
        for (uint i = 0; i < out0.length; i++) {
            if (i < in0.length) { 
                assertEq(out0[i], in0[i], "Output 0 mismatch");
            } else {
                assertEq(out0[i], address(0), "Output 0 not zero");
            }
        }
        for (uint i = 0; i < out1.length; i++) {
            if (i < in1.length) {
                assertEq(out1[i], in1[i], "Output 1 mismatch");
            } else {
                assertEq(out1[i], address(0), "Output 1 not zero");
            }
        }
        assertEq(out2, in2, "Output 2 mismatch");
    }
}
