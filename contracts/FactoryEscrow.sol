// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Escrow.sol";

contract FactoryEscrow {
    address public nft_address;
    address payable public admin;
    uint256 public factory_fee;
    bool public paused;
    mapping(uint256 => address payable) public cache;

    struct EscrowForm {
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

    function createEscrow(EscrowForm memory escrowForm) public payable returns (bool success) {
        // sufficient funds
        require(msg.value >= factory_fee, "Insufficient funds");
        // if an escrow has been created for this nft id before
        if (cache[escrowForm._nftID] != payable(address(0))) {
            // get instance of the contract
            Escrow _escrow = Escrow(cache[escrowForm._nftID]);
            // get the 'compoeted' state variable
            bool completed = _escrow.completed();
            // require escrow lifecycle to be completed
            require(completed, "Escrow not completed");
        }
        // create new escrow contract
        Escrow escrow = new Escrow(
            nft_address,
            escrowForm._nftID,
            escrowForm._purchase_price,
            escrowForm._escrow_amount,
            escrowForm._seller,
            escrowForm._buyer,
            escrowForm._inspector,
            escrowForm._lender,
            escrowForm._appraiser,
            address(this) 
        );
        // update mapping
        cache[escrowForm._nftID] = payable(address(escrow));
        success = true;
    }

    function setFactoryFee(uint256 _factory_fee) onlyAdmin external returns (bool success) {
        factory_fee = _factory_fee;
        success = true;
    }
}
