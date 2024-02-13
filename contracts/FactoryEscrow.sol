// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Escrow.sol"; // escrow contract
import "./TypesEscrow.sol"; // escrow types
import "./Verify.sol"; // verify library

contract FactoryEscrow {
    // owner address
    address public owner;
    // escrow contract address
    uint public escrowCount = 0;
    // escrow fee
    uint public fee;
    mapping(address => mapping(uint => address)) public escrows; // tracks escrow contracts. give it the token address and the token id, get the escrow contract address

    event EscrowCreated(
        address indexed _nft_address,
        uint indexed _nft_id,
        address indexed _escrow_address
    );


    constructor(
        uint _fee
    ) {
        owner = msg.sender;
        fee = _fee;
    }

    function createEscrow(
        TypesEscrow.EscrowForm memory _form,
        bytes[3] memory _signatures
    ) external payable {
        // ensure that the escrow does not already exist, if it does, ensure that it is completed
        address escrow_address = escrows[_form.nft_address][_form.nft_id];
        if (escrow_address != address(0)) {
            Escrow _escrow = Escrow(payable(escrow_address));
            require(_escrow.completed(), "Escrow already exists");
        }
        // ensure the fee is paid
        require(msg.value > fee, "Insufficient funds to create escrow");
        // ensure that the buyer, seller and lender all signed the message / all in accordance with the escrow form and selling of the nft
        bytes32 signature_digest = Verify.getEthSignedMessageHash(
            Verify.getMessageHash(_form)
        );
        for (uint8 i = 0; i < 3; i++) {
            address signer = Verify.recoverSigner(
                signature_digest,
                _signatures[i]
            );
            if (i == 0) {
                require(signer == _form.buyer, "Buyer signature invalid");
            } else if (i == 1) {
                require(signer == _form.seller, "Seller signature invalid");
            } else {
                require(signer == _form.lender, "Lender signature invalid");
            }
        }

        // create the escrow contract
        Escrow escrow = new Escrow(
            _form.nft_address,
            _form.nft_id,
            _form.purchase_price,
            _form.earnest_amount,
            payable(_form.seller),
            payable(_form.buyer),
            _form.inspector,
            _form.lender,
            _form.appraiser
        );

        // transfer the nft from the seller to the escrow contract
        IERC721(_form.nft_address).transferFrom(
            _form.seller,
            address(escrow),
            _form.nft_id
        );

        // track the escrow contract
        escrows[_form.nft_address][_form.nft_id] = address(escrow);

        // emit the event
        emit EscrowCreated(_form.nft_address, _form.nft_id, address(escrow));
    }


    function withdrawFee() external {
        require(msg.sender == owner, "Unauthorized");
        payable(owner).transfer(address(this).balance);
    }
}