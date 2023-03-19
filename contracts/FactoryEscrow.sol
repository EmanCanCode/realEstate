// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Escrow.sol";
import "./Verify.sol";

contract FactoryEscrow {
    address public nft_address;
    address payable public admin;
    uint256 public factory_fee;
    bool public paused;
    mapping(uint256 => address payable) public cache;

    struct EscrowForm {
        uint256 _nonce;
        uint256 _nftID;
        uint256 _purchase_price;
        uint256 _escrow_amount;
        address payable _seller;
        address payable _buyer;
        address _inspector;
        address _lender;
        address _appraiser;
    }

    constructor(address payable _admin, uint256 _factory_fee, address _nft_address) {
        admin = _admin;
        factory_fee = _factory_fee;
        nft_address = _nft_address;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized");
        _;
    }

    function setAdmin(address payable _admin)
        external
        onlyAdmin
        returns (bool success)
    {
        admin = _admin;
        success = true;
    }

    function concatenate(
        address _seller,
        address _buyer,
        address _inspector,
        address _lender,
        address _appraiser,
        uint256 _price, 
        uint256 _nonce, 
        uint256 _nft_id
        
    ) public pure returns (bytes memory) {
        // Concatenate the data together
        return abi.encodePacked(_seller, _buyer, _inspector, _lender, _appraiser, _price, _nonce, _nft_id);
    }

    function createEscrow(
        EscrowForm memory escrow_form, 
        VerifySignature.VerifyForm memory verify_form
    ) public payable returns (bool success) {
        // if actor is not the seller
        if (msg.sender != escrow_form._seller) {
            // or buyer
            require(msg.sender == escrow_form._buyer, "Unauthorized");
        }

        // verify that the seller of the nft actually signed this data, or this could be a bad actor
        uint256 nft_id = escrow_form._nftID;
        address nft_owner = IERC721(nft_address).ownerOf(nft_id);
        require(escrow_form._seller == nft_owner, "Owner is not the seller");
        // require signer is seller
        require(verify_form._signer == escrow_form._seller, "Signer is not the seller");
        // ensure the message is seller, purchase price and nonce concatenated in a string
        bytes memory escrow_message_bytes = concatenate(escrow_form._seller, escrow_form._buyer, escrow_form._inspector, escrow_form._lender, escrow_form._appraiser, escrow_form._purchase_price, escrow_form._nonce, escrow_form._nftID);
        require(keccak256(escrow_message_bytes) == keccak256(abi.encodePacked(verify_form._message)), "Messages do not match");
        // verify ec verify that the signer/seller signed the signature
        bool valid = VerifySignature.verify(verify_form);
        require(valid, "Signature verification failed");

        // sufficient funds
        require(msg.value >= factory_fee, "Insufficient funds");
        // if an escrow has been created for this nft id before
        if (cache[escrow_form._nftID] != payable(address(0))) {
            // ensure that the CURRENT owner is the seller in the escrow
            address current_owner = IERC721(nft_address).ownerOf(escrow_form._nftID);
            require(current_owner == escrow_form._seller, "Current owner is not the seller");
            // get instance of the contract
            Escrow _escrow = Escrow(cache[escrow_form._nftID]);
            // get the 'completed' state variable
            bool completed = _escrow.completed();
            // require escrow lifecycle to be completed
            require(completed, "Escrow not completed");
        }
        // create new escrow contract
        Escrow escrow = new Escrow(
            nft_address,
            escrow_form._nftID,
            escrow_form._purchase_price,
            escrow_form._escrow_amount,
            escrow_form._seller,
            escrow_form._buyer,
            escrow_form._inspector,
            escrow_form._lender,
            escrow_form._appraiser,
            address(this) 
        );
        // update mapping
        cache[escrow_form._nftID] = payable(address(escrow));
        success = true;
    }

    function setFactoryFee(uint256 _factory_fee) onlyAdmin external returns (bool success) {
        factory_fee = _factory_fee;
        success = true;
    }

    function withdraw() external onlyAdmin returns (bool) {
        (bool success, ) = payable(admin).call{value: factory_fee}("");
        require(success, "Failed to withdraw");
        return success;
    }

    function cancelEscrow(uint256 _nft_id) onlyAdmin public returns (bool) {
        Escrow _escrow = Escrow(cache[_nft_id]);
        bool completed = _escrow.completed();
        require(!completed, "Already completed");
        bool canceled = _escrow.cancelSale();
        require(canceled, "Error canceling");
        return canceled;
    }
}
