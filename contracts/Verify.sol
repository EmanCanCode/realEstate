// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./TypesEscrow.sol"; // escrow types

library Verify {
    function getMessageHash(
       TypesEscrow.EscrowForm memory _form
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _form.nft_address,
            _form.nft_id,
            _form.purchase_price,
            _form.earnest_amount,
            _form.seller,
            _form.buyer,
            _form.inspector,
            _form.lender,
            _form.appraiser
        ));
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }


    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}