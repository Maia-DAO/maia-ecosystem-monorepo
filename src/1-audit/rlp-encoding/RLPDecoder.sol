// SPDX-License-Identifier: MIT
// RLP logic inspired by Optimism's Contracts (optimism/packages/contracts-bedrock/contracts/libraries/rlp)
pragma solidity ^0.8.0;

import { DynamicBufferLib } from "solady/utils/DynamicBufferLib.sol";

import { RLPReader } from "./rlp/RLPReader.sol";

/**
 * @title RLPDecoder
 * @notice This contract handles standard RLP decoding.
 * @author Maia DAO (https://github.com/Maia-DAO)
 */
library RLPDecoder {
    using DynamicBufferLib for DynamicBufferLib.DynamicBuffer;

    /**
     * @notice Decode provided RLP encoded data into calldata. Provides cheaper external calls in L2 networks.
     *
     * @param data RLP encoded calladata to decode.
     *
     * @dev data is comprised of the calldata parameters without padding.
     *
     * @return bytes standard abi encoded tx calldata.
     **/
    function decodeCallData(bytes memory data, uint256 maxListLength)
        internal
        pure
        returns (bytes memory)
    {
        // Get RLP item list from data
        RLPReader.RLPItem[] memory items = RLPReader.readList(data, maxListLength);

        uint256 length = items.length;

        DynamicBufferLib.DynamicBuffer memory buffer;

        for (uint256 i = 0; i < length; ) {
            bytes memory slot = RLPReader.readBytes(items[i]);

            // Right-shift signifcant bytes to restore padding
            bytes32 val = bytes32(slot) >> (256 - slot.length * 8);

            // Add extracted 32 bytes buffer
            buffer.append(abi.encodePacked(val));

            unchecked {
                i++;
            }
        }
        return buffer.data;
    }
}
