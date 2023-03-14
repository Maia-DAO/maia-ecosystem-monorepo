// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {RLPEncoder} from "@rlp/RLPEncoder.sol";
import {RLPDecoder} from "@rlp/RLPDecoder.sol";
import {console2} from "forge-std/console2.sol";

library RLPEncoderHelper {
    using RLPEncoder for bytes;
    using RLPDecoder for bytes;

    // Encodes and decodes bytes using RLPEncoder contract for testing
    function encodeAndDecode(bytes memory data, uint256 offset)
        internal
        view
        returns (bytes memory)
    {
        bytes memory encodedData = data.encodeCallData(offset);

        return encodedData.decodeCallData(1 + data.length / 32);
    }
}
