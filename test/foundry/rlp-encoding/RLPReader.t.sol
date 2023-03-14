// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RLPReader } from "@rlp/rlp/RLPReader.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import { stdError } from "forge-std/Test.sol";

contract RLPReader_Test is DSTestPlus {
    function test_readBytes_bytestring00() external {
        assertBytesEq(RLPReader.readBytes(hex"00"), hex"00");
    }

    function test_readBytes_bytestring01() external {
        assertBytesEq(RLPReader.readBytes(hex"01"), hex"01");
    }

    function test_readBytes_bytestring7f() external {
        assertBytesEq(RLPReader.readBytes(hex"7f"), hex"7f");
    }

    function test_readBytes_revertListItem() external {
        hevm.expectRevert("RLPReader: decoded item type for bytes is not a data item");
        RLPReader.readBytes(hex"c7c0c1c0c3c0c1c0");
    }

    function test_readBytes_invalidStringLength() external {
        hevm.expectRevert(
            "RLPReader: length of content must be > than length of string length (long string)"
        );
        RLPReader.readBytes(hex"b9");
    }

    function test_readBytes_invalidListLength() external {
        hevm.expectRevert(
            "RLPReader: length of content must be > than length of list length (long list)"
        );
        RLPReader.readBytes(hex"ff");
    }

    function test_readBytes_invalidRemainder() external {
        hevm.expectRevert("RLPReader: bytes value contains an invalid remainder");
        RLPReader.readBytes(hex"800a");
    }

    function test_readBytes_invalidPrefix() external {
        hevm.expectRevert(
            "RLPReader: invalid prefix, single byte < 0x80 are not prefixed (short string)"
        );
        RLPReader.readBytes(hex"810a");
    }

    function test_readList_empty() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(hex"c0", 1);
        assertEq(list.length, 0);
    }

    function test_readList_multiList() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(hex"c6827a77c10401", 4);
        assertEq(list.length, 3);

        assertBytesEq(RLPReader.readRawBytes(list[0]), hex"827a77");
        assertBytesEq(RLPReader.readRawBytes(list[1]), hex"c104");
        assertBytesEq(RLPReader.readRawBytes(list[2]), hex"01");
    }

    function test_readList_shortListMax1() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(
            hex"f784617364668471776572847a78637684617364668471776572847a78637684617364668471776572847a78637684617364668471776572",
            12
        );

        assertEq(list.length, 11);
        assertBytesEq(RLPReader.readRawBytes(list[0]), hex"8461736466");
        assertBytesEq(RLPReader.readRawBytes(list[1]), hex"8471776572");
        assertBytesEq(RLPReader.readRawBytes(list[2]), hex"847a786376");
        assertBytesEq(RLPReader.readRawBytes(list[3]), hex"8461736466");
        assertBytesEq(RLPReader.readRawBytes(list[4]), hex"8471776572");
        assertBytesEq(RLPReader.readRawBytes(list[5]), hex"847a786376");
        assertBytesEq(RLPReader.readRawBytes(list[6]), hex"8461736466");
        assertBytesEq(RLPReader.readRawBytes(list[7]), hex"8471776572");
        assertBytesEq(RLPReader.readRawBytes(list[8]), hex"847a786376");
        assertBytesEq(RLPReader.readRawBytes(list[9]), hex"8461736466");
        assertBytesEq(RLPReader.readRawBytes(list[10]), hex"8471776572");
    }

    function test_readList_longList1() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(
            hex"f840cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376",
            5
        );

        assertEq(list.length, 4);
        assertBytesEq(RLPReader.readRawBytes(list[0]), hex"cf84617364668471776572847a786376");
        assertBytesEq(RLPReader.readRawBytes(list[1]), hex"cf84617364668471776572847a786376");
        assertBytesEq(RLPReader.readRawBytes(list[2]), hex"cf84617364668471776572847a786376");
        assertBytesEq(RLPReader.readRawBytes(list[3]), hex"cf84617364668471776572847a786376");
    }

    function test_readList_longList2() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(
            hex"f90200cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376",
            33
        );
        assertEq(list.length, 32);

        for (uint256 i = 0; i < 32; i++) {
            assertBytesEq(RLPReader.readRawBytes(list[i]), hex"cf84617364668471776572847a786376");
        }
    }

    function test_readList_listLongerThan32Elements() external {
        hevm.expectRevert(stdError.indexOOBError);
        RLPReader.readList(
            hex"e1454545454545454545454545454545454545454545454545454545454545454545",
            32
        );
    }

    function test_readList_listOfLists() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(hex"c4c2c0c0c0", 3);
        assertEq(list.length, 2);
        assertBytesEq(RLPReader.readRawBytes(list[0]), hex"c2c0c0");
        assertBytesEq(RLPReader.readRawBytes(list[1]), hex"c0");
    }

    function test_readList_listOfLists2() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(hex"c7c0c1c0c3c0c1c0", 4);
        assertEq(list.length, 3);

        assertBytesEq(RLPReader.readRawBytes(list[0]), hex"c0");
        assertBytesEq(RLPReader.readRawBytes(list[1]), hex"c1c0");
        assertBytesEq(RLPReader.readRawBytes(list[2]), hex"c3c0c1c0");
    }

    function test_readList_dictTest1() external {
        RLPReader.RLPItem[] memory list = RLPReader.readList(
            hex"ecca846b6579318476616c31ca846b6579328476616c32ca846b6579338476616c33ca846b6579348476616c34",
            5
        );
        assertEq(list.length, 4);

        assertBytesEq(RLPReader.readRawBytes(list[0]), hex"ca846b6579318476616c31");
        assertBytesEq(RLPReader.readRawBytes(list[1]), hex"ca846b6579328476616c32");
        assertBytesEq(RLPReader.readRawBytes(list[2]), hex"ca846b6579338476616c33");
        assertBytesEq(RLPReader.readRawBytes(list[3]), hex"ca846b6579348476616c34");
    }

    function test_readList_invalidShortList() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than list length (short list)"
        );
        RLPReader.readList(hex"efdebd", 32);
    }

    function test_readList_longStringLength() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than list length (short list)"
        );
        RLPReader.readList(hex"efb83600", 32);
    }

    function test_readList_notLongEnough() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than list length (short list)"
        );
        RLPReader.readList(
            hex"efdebdaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            32
        );
    }

    function test_readList_int32Overflow() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than total length (long string)"
        );
        RLPReader.readList(hex"bf0f000000000000021111", 32);
    }

    function test_readList_int32Overflow2() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than total length (long list)"
        );
        RLPReader.readList(hex"ff0f000000000000021111", 32);
    }

    function test_readList_incorrectLengthInArray() external {
        hevm.expectRevert(
            "RLPReader: length of content must not have any leading zeros (long string)"
        );
        RLPReader.readList(
            hex"b9002100dc2b275d0f74e8a53e6f4ec61b27f24278820be3f82ea2110e582081b0565df0",
            32
        );
    }

    function test_readList_leadingZerosInLongLengthArray1() external {
        hevm.expectRevert(
            "RLPReader: length of content must not have any leading zeros (long string)"
        );
        RLPReader.readList(
            hex"b90040000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            32
        );
    }

    function test_readList_leadingZerosInLongLengthArray2() external {
        hevm.expectRevert(
            "RLPReader: length of content must not have any leading zeros (long string)"
        );
        RLPReader.readList(hex"b800", 32);
    }

    function test_readList_leadingZerosInLongLengthList1() external {
        hevm.expectRevert("RLPReader: length of content must not have any leading zeros (long list)");
        RLPReader.readList(
            hex"fb00000040000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
            32
        );
    }

    function test_readList_nonOptimalLongLengthArray1() external {
        hevm.expectRevert("RLPReader: length of content must be greater than 55 bytes (long string)");
        RLPReader.readList(hex"b81000112233445566778899aabbccddeeff", 32);
    }

    function test_readList_nonOptimalLongLengthArray2() external {
        hevm.expectRevert("RLPReader: length of content must be greater than 55 bytes (long string)");
        RLPReader.readList(hex"b801ff", 32);
    }

    function test_readList_invalidValue() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than string length (short string)"
        );
        RLPReader.readList(hex"91", 32);
    }

    function test_readList_invalidRemainder() external {
        hevm.expectRevert("RLPReader: list item has an invalid data remainder");
        RLPReader.readList(hex"c000", 32);
    }

    function test_readList_notEnoughContentForString1() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than total length (long string)"
        );
        RLPReader.readList(hex"ba010000aabbccddeeff", 32);
    }

    function test_readList_notEnoughContentForString2() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than total length (long string)"
        );
        RLPReader.readList(hex"b840ffeeddccbbaa99887766554433221100", 32);
    }

    function test_readList_notEnoughContentForList1() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than total length (long list)"
        );
        RLPReader.readList(hex"f90180", 32);
    }

    function test_readList_notEnoughContentForList2() external {
        hevm.expectRevert(
            "RLPReader: length of content must be greater than total length (long list)"
        );
        RLPReader.readList(hex"ffffffffffffffffff0001020304050607", 32);
    }

    function test_readList_longStringLessThan56Bytes() external {
        hevm.expectRevert("RLPReader: length of content must be greater than 55 bytes (long string)");
        RLPReader.readList(hex"b80100", 32);
    }

    function test_readList_longListLessThan56Bytes() external {
        hevm.expectRevert("RLPReader: length of content must be greater than 55 bytes (long list)");
        RLPReader.readList(hex"f80100", 32);
    }
}