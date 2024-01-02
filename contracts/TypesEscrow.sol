// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TypesEscrow {

    struct EscrowForm{
        address nft_address;
        uint256 nft_id;
        uint256 purchase_price;
        uint256 earnest_amount;
        address seller;
        address buyer;
        address inspector;
        address lender;
        address appraiser;
    }
}