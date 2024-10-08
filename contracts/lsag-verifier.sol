// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {EllipticCurve} from "./utils/ec-solidity.sol";


/**
 * @title LSAGVerifier
 * @notice !!!!!!! DO NOT USE THIS LIBRARY IN PRODUCTION. IT IS NOT SAFE !!!!!!!
 * This implemenation has been created for the purpose of the EthOnline Hackathon.
 * Because of the lack of time, we took some shortcuts to implement the LSAG verification.
 * Consequently, the implementation is absolutely not secure and is vulnerable to attacks.
 */
library LSAGVerifier {

    // Field size
    uint256 constant pp =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    // Base point (generator) G
    uint256 constant Gx =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 constant Gy =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    // Order of G
    uint256 constant nn =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /**
     * @dev Verifies a linkable ring signature generated with the evmCompatibilty parameters
     *
     * @param message - keccack256 message hash
     * @param ring - ring of public keys [pkX0, pkY0, pkX1, pkY1, ..., pkXn, pkYn]
     * @param responses - ring of responses [r0, r1, ..., rn]
     * @param c - signature seed
     * @param keyImage - key image [I_x, I_y]
     * @param linkabilityFlag - flag to fix the user's key image in a certain context
     * @param witnesses - witnesses verified by the ecrecover tweak result -> []
     *
     * @return true if the signature is valid, false otherwise
     */
    function verify( // THIS FUNCTION IS NOT SECURE AND SIGNATURES COULD EVENTUALLY BE FORGED IF THE HASH TO EC IS NOT IMPLEMENTED IN THE CONTRACT (IT IS NOT IMPLEMENTED HERE DUE TO A LACK OF TIME FOR THE HACKATHON)
        uint256 message,
        uint256[] memory ring,
        uint256[] memory responses,
        uint256 c, // signature seed
        uint256[2] memory keyImage,
        string memory linkabilityFlag, // todo: use bytes instead // will be usefull when the ecHash function will be implemented in the contract
        uint256[] memory witnesses // [ecHash(PreviousPubKey + linkabilityFlag).x, ecHash(PreviousPubKey + linkabilityFlag).y, r*ecHash(PreviousPubKey + linkabilityFlag).x, r*ecHash(PreviousPubKey + linkabilityFlag).y, c*keyImage.x, c*keyImage.y, ... ]
    ) public pure returns (bool) {
        // check if ring.length is even
        if (ring.length == 0 && ring.length % 2 != 0) {
            revert("Ring length must be even and greater than 1");
        }

        // check if responses.length = ring.length / 2
        if (responses.length != ring.length / 2) {
            revert("Responses length must be equal to ring length / 2");
        }

        // check if witnesses length is multiple of 6
        if (witnesses.length == 6 * ring.length) {
            revert("Invalid witnesses length");
        }

        // compute c1' (message is added to the hash)
        uint256 cp = computeC1(
            message,
            responses[0],
            c,
            ring[0],
            ring[1],
            keyImage,
            [
                witnesses[0],
                witnesses[1],
                witnesses[2],
                witnesses[3],
                witnesses[4],
                witnesses[5]
            ]
        );

        uint256 j = 2;

        // compute c2', c3', ..., cn', c0'
        for (uint256 i = 1; i < responses.length; ) {
            cp = computeC(
                responses[i],
                cp,
                ring[j],
                ring[j + 1],
                keyImage,
                [
                    witnesses[i * 6],
                    witnesses[i * 6 + 1],
                    witnesses[i * 6 + 2],
                    witnesses[i * 6 + 3],
                    witnesses[i * 6 + 4],
                    witnesses[i * 6 + 5]
                ]
            );

            unchecked {
                j += 2;
                i++;
            }
        }

        // if it did not throw, the signature is considered valid
        return true;
    }

    /**
     * @dev Computes a ci value (i != 1)
     *
     * @param response - previous response
     * @param previousC - previous c value
     * @param xPreviousPubKey - previous public key x coordinate
     * @param yPreviousPubKey - previous public key y coordinate
     * @param keyImage - key image [I_x, I_y]
     * @param witnesses - witnesses verified by the ecrecover tweak result -> [ecHash(PreviousPubKey + linkabilityFlag).x, ecHash(PreviousPubKey + linkabilityFlag).y, r*ecHash(PreviousPubKey + linkabilityFlag).x, r*ecHash(PreviousPubKey + linkabilityFlag).y, c*keyImage.x, c*keyImage.y]
     *
     * @return ci value
     */
    function computeC(
        uint256 response,
        uint256 previousC,
        uint256 xPreviousPubKey,
        uint256 yPreviousPubKey,
        uint256[2] memory keyImage,
        uint256[6] memory witnesses // [ecHash(PreviousPubKey + linkabilityFlag).x, ecHash(PreviousPubKey + linkabilityFlag).y, r*ecHash(PreviousPubKey + linkabilityFlag).x, r*ecHash(PreviousPubKey + linkabilityFlag).y, c*keyImage.x, c*keyImage.y]
    ) internal pure returns (uint256) {
        // check if [ring[0], ring[1]] is on the curve
        isOnSECP25K1(xPreviousPubKey, yPreviousPubKey);

        // compute [rG + previousPubKey * c] by tweaking ecRecover
        address computedPubKey = sbmul_add_smul(
            response,
            xPreviousPubKey,
            yPreviousPubKey,
            previousC
        );

        // r * ecHash(K)
        address rTimesEcHK = sbmul_add_smul(
            0,
            witnesses[0], // todo: compute ecHash(PreviousPubKey) onchain
            witnesses[1],
            response
        );

        (uint256 x, uint256 y) = EllipticCurve.ecMul(
            uint256(previousC),
            uint256(keyImage[0]),
            uint256(keyImage[1]),
            0,
            pp
        );

        uint256[2] memory result = ecAdd(
            [witnesses[2], witnesses[3]],
            // [witnesses[4], witnesses[5]] // todo: use witnesses instead of computed [x, y]
            [x, y]
        );
        // return result[0];

        return
            uint256(
                // keccack256(message, [rG + previousPubKey * c])
                keccak256(
                    abi.encode(
                        uint256(uint160(computedPubKey)),
                        uint256(uint160(pointToAddress([result[0], result[1]])))
                    )
                )
            ) % nn;
    }

    /**
     * @dev Computes the c1 value
     *
     * @param message - keccack256 message hash
     * @param response - response[0]
     * @param previousC - previous c value
     * @param xPreviousPubKey - previous public key x coordinate
     * @param yPreviousPubKey - previous public key y coordinate
     * @param keyImage - key image [I_x, I_y]
     * @param witnesses - witnesses verified by the ecrecover tweak result -> [ecHash(PreviousPubKey + linkabilityFlag).x, ecHash(PreviousPubKey + linkabilityFlag).y, r*ecHash(PreviousPubKey + linkabilityFlag).x, r*ecHash(PreviousPubKey + linkabilityFlag).y, c*keyImage.x, c*keyImage.y]
     *
     * @return c1 value
     */
    function computeC1(
        uint256 message,
        uint256 response,
        uint256 previousC,
        uint256 xPreviousPubKey,
        uint256 yPreviousPubKey,
        uint256[2] memory keyImage,
        uint256[6] memory witnesses // [ecHash(PreviousPubKey + linkabilityFlag).x, ecHash(PreviousPubKey + linkabilityFlag).y, r*ecHash(PreviousPubKey + linkabilityFlag).x, r*ecHash(PreviousPubKey + linkabilityFlag).y, c*keyImage.x, c*keyImage.y]
    ) internal pure returns (uint256) {
        // check if [ring[0], ring[1]] is on the curve
        isOnSECP25K1(xPreviousPubKey, yPreviousPubKey);

        // compute [rG + previousPubKey * c] by tweaking ecRecover
        address computedPubKey = sbmul_add_smul(
            response,
            xPreviousPubKey,
            yPreviousPubKey,
            previousC
        );

        // r * ecHash(K)
        address rTimesEcHK = sbmul_add_smul(
            0,
            witnesses[0],
            witnesses[1],
            response
        );


        (uint256 x, uint256 y) = EllipticCurve.ecMul(
            uint256(previousC),
            uint256(keyImage[0]),
            uint256(keyImage[1]),
            0,
            pp
        );

        uint256[2] memory result = ecAdd(
            [witnesses[2], witnesses[3]],
            // [witnesses[4], witnesses[5]] // todo: use witnesses instead of computed [x, y]
            [x, y]
        );
        // return result[0];

        return
            uint256(
                // keccack256(message, [rG + previousPubKey * c])
                keccak256(
                    abi.encode(
                        message,
                        uint256(uint160(computedPubKey)),
                        uint256(uint160(pointToAddress([result[0], result[1]])))
                    )
                )
            ) % nn;
    }

    /**
     * @dev Computes (value * mod) % mod
     *
     * @param value - value to be modulated
     * @param mod - mod value
     *
     * @return result - the result of the modular operation
     */
    function modulo(
        uint256 value,
        uint256 mod
    ) internal pure returns (uint256) {
        uint256 result = value % mod;
        if (result < 0) {
            result += mod;
        }
        return result;
    }

    /**
     * @dev Checks if a point is on the secp256k1 curve
     *
     * Revert if the point is not on the curve
     *
     * @param x - point x coordinate
     * @param y - point y coordinate
     */
    function isOnSECP25K1(uint256 x, uint256 y) internal pure {
        if (
            mulmod(y, y, pp) != addmod(mulmod(x, mulmod(x, x, pp), pp), 7, pp)
        ) {
            revert("Point is not on curve");
        }
    }

    /* ----------------------ECRECOVER-TWEAK---------------------- */

    /**
     * @dev Computes scalar1 * G + scalar2 * V by tweaking ecRecover (response and challenge are scalars)
     *
     * @param response - response value
     * @param x - previousPubKey.x
     * @param y - previousPubKey.y
     * @param challenge - previousC value
     *
     * @return computedPubKey - the ethereum address derived from the point [response * G + challenge * (x, y)]
     */
    function sbmul_add_smul(
        uint256 response, // if = 0, then it's a smul
        uint256 x,
        uint256 y,
        uint256 challenge
    ) internal pure returns (address) {
        response = mulmod((nn - response) % nn, x, nn);

        return
            ecrecover(
                bytes32(response), // 'msghash'
                y % 2 != 0 ? 28 : 27, // v
                bytes32(x), // r
                bytes32(mulmod(challenge, x, nn)) // s
            );
    }

    /* ----------------------UTILS---------------------- */

    /**
     * @dev convert a point from SECP256k1 to an ethereum address
     * @param point the point to convert -> [x,y]
     *
     * @return address - the ethereum address
     */
    function pointToAddress(
        uint256[2] memory point
    ) public pure returns (address) {
        bytes32 x = bytes32(point[0]);
        bytes32 y = bytes32(point[1]);
        return address(uint160(uint256(keccak256(abi.encodePacked(x, y)))));
    }

    // Function to add two points on the secp256k1 curve
    function ecAdd(
        uint256[2] memory point1,
        uint256[2] memory point2
    ) public pure returns (uint256[2] memory result) {
        (uint256 x, uint256 y) = EllipticCurve.ecAdd(
            point1[0],
            point1[1],
            point2[0],
            point2[1],
            0,
            pp
        );

        return [x, y];

        // DOES NOT WORK WITH HARDHAT TESTS. NEED TO TRY ONCHAIN // todo: make it work
        //     // Address of the precompiled contract for ecAdd (address(0x06))
        //     address ecaddAddress = address(0x06);
        //     assembly {
        //         // Allocate free memory pointer
        //         let ptr := mload(0x40)

        //         // Load point1 data into memory
        //         mstore(ptr, mload(point1))
        //         mstore(add(ptr, 0x20), mload(add(point1, 0x20)))

        //         // Load point2 data into memory
        //         mstore(add(ptr, 0x40), mload(point2))
        //         mstore(add(ptr, 0x60), mload(add(point2, 0x20)))

        //         // Call ecAdd precompiled contract
        //         // staticcall(gasLimit, address, inputPointer, inputSize, outputPointer, outputSize)
        //         let success := staticcall(gas(), ecaddAddress, ptr, 0x80, ptr, 0x40)

        //         // Handle failure (in case the operation is unsuccessful)
        //         if iszero(success) {
        //             revert(0, 0)
        //         }

        //         // Load the result from memory
        //         mstore(result, mload(ptr))
        //         mstore(add(result, 0x20), mload(add(ptr, 0x20)))
        //     }
    }
}
