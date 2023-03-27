// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {console2} from "forge-std/console2.sol";

import {
    RootBridgeAgent,
    DepositParams,
    DepositMultipleParams,
    Settlement,
    SettlementParams,
    SettlementMultipleParams
} from "@omni/RootBridgeAgent.sol";
import {IRootRouter} from "@omni/interfaces/IRootRouter.sol";
import {IRootPort as IPort} from "@omni/interfaces/IRootPort.sol";
import {ERC20hTokenRoot as ERC20hToken} from "@omni/token/ERC20hTokenRoot.sol";
import {INonfungiblePositionManager} from "@omni/interfaces/INonfungiblePositionManager.sol";
import {Path} from "@omni/interfaces/Path.sol";
import {WETH9} from "@omni/interfaces/IWETH9.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title ERC20 hToken Contract for deployment in Branch Chains of Hermes Omnichain Incentives System
 * @author MaiaDAO
 * @dev Base Root Router for Anycall cross-chain messaging.
 *
 *   CROSS-CHAIN MESSAGING FUNCIDs
 *   -----------------------------
 *   FUNC ID      | FUNC NAME
 *   -------------|---------------
 *   1            | depositToPort
 *   2            | withdrawFromPort
 *   3            | bridgeTo
 *   4            | clearSettlement
 *
 */
contract MockRootBridgeAgent is RootBridgeAgent {
    constructor(
        WETH9 _wrappedNativeToken,
        uint24 _localChainId,
        address _daoAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localPortAddress,
        address _localRouterAddress
    )
        RootBridgeAgent(
            _wrappedNativeToken,
            _localChainId,
            _daoAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localPortAddress,
            _localRouterAddress
        )
    {}

    /*///////////////////////////////////////////////////////////////
                TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function bridgeInMultiple(address _recipient, bytes calldata _dParams, uint24 _fromChain) public returns (DepositMultipleParams memory) {
        // Parse Parameters
        uint8 numOfAssets = uint8(bytes1(_dParams[0]));
        uint32 nonce = uint32(bytes4(_dParams[PARAMS_START:5]));
        uint24 toChain = uint24(bytes3(_dParams[_dParams.length - 3:_dParams.length]));

        address[] memory hTokens = new address[](numOfAssets);
        address[] memory tokens = new address[](numOfAssets);
        uint256[] memory amounts = new uint256[](numOfAssets);
        uint256[] memory deposits = new uint256[](numOfAssets);

        for (uint256 i = 0; i < uint256(uint8(numOfAssets));) {
            console2.log("start clear token round");
            console2.log("1");
            console2.log(PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * i) + 12);
            console2.log(PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i)));
            //Parse Params
            hTokens[i] = address(
                uint160(
                    bytes20(
                        bytes32(
                            _dParams[PARAMS_TKN_START +
                                (PARAMS_ENTRY_SIZE * i) +
                                12:PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i))]
                        )
                    )
                )
            );

            console2.log(hTokens[i]);

            console2.log("2");
            console2.log(PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(i + numOfAssets) + 12);

            console2.log(
                PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i + numOfAssets)
            );

            tokens[i] = address(
                uint160(
                    bytes20(
                        _dParams[PARAMS_TKN_START +
                            PARAMS_ENTRY_SIZE *
                            uint16(i + numOfAssets) +
                            12:PARAMS_TKN_START +
                            PARAMS_ENTRY_SIZE *
                            uint16(PARAMS_START + i + numOfAssets)]
                    )
                )
            );

            console2.log(tokens[i]);
            console2.log("3");

            console2.log(
                PARAMS_TKN_START +
                    PARAMS_AMT_OFFSET *
                    uint16(numOfAssets) +
                    (PARAMS_ENTRY_SIZE * uint16(i))
            );

            console2.log(
                PARAMS_TKN_START +
                    PARAMS_AMT_OFFSET *
                    uint16(numOfAssets) +
                    (PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i))
            );

            amounts[i] = uint256(
                bytes32(
                    _dParams[PARAMS_TKN_START +
                        PARAMS_AMT_OFFSET *
                        uint16(numOfAssets) +
                        (PARAMS_ENTRY_SIZE * uint16(i)):PARAMS_TKN_START +
                        PARAMS_AMT_OFFSET *
                        uint16(numOfAssets) +
                        PARAMS_ENTRY_SIZE *
                        uint16(PARAMS_START + i)]
                )
            );

            console2.log(amounts[i]);
            console2.log("4");

            console2.log(
                PARAMS_TKN_START +
                    PARAMS_DEPOSIT_OFFSET *
                    uint16(numOfAssets) +
                    (PARAMS_ENTRY_SIZE * uint16(i))
            );

            console2.log(
                PARAMS_TKN_START +
                    PARAMS_DEPOSIT_OFFSET *
                    uint16(numOfAssets) +
                    PARAMS_ENTRY_SIZE *
                    uint16(PARAMS_START + i)
            );

            deposits[i] = uint256(
                bytes32(
                    _dParams[PARAMS_TKN_START +
                        PARAMS_DEPOSIT_OFFSET *
                        uint16(numOfAssets) +
                        (PARAMS_ENTRY_SIZE * uint16(i)):PARAMS_TKN_START +
                        PARAMS_DEPOSIT_OFFSET *
                        uint16(numOfAssets) +
                        PARAMS_ENTRY_SIZE *
                        uint16(PARAMS_START + i)]
                )
            );

            console2.log("numOfAssets", numOfAssets);
            console2.log("nonce", nonce);
            console2.log("hTokens[i]", hTokens[i]);
            console2.log("tokens[i]", tokens[i]);
            console2.log("amounts[i]", amounts[i]);
            console2.log("deposits[i]", deposits[i]);
            console2.log("toChain", toChain);

            unchecked {
                ++i;
            }
        }
        return (
            DepositMultipleParams({
                numberOfAssets: numOfAssets,
                depositNonce: nonce,
                hTokens: hTokens,
                tokens: tokens,
                amounts: amounts,
                deposits: deposits,
                toChain: toChain
            })
        );
    }
    
}
