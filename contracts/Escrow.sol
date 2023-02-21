//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;
}

contract Escrow {
    address public nftAddress;
    uint256 public nftID;
    uint256 public purchasePrice;
    uint256 public appraisalAmount;
    uint256 public escrowAmount;
    address payable public seller;
    address payable public buyer;
    address public appraiser;
    address public inspector;
    address public lender;
    bool public completed;
    address public factory;
    mapping(address => uint256) public deposit_balance;

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this method");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this method");
        _;
    }

    modifier onlyInspector() {
        require(msg.sender == inspector, "Only inspector can call this method");
        _;
    }

    modifier onlyLender() {
        require(msg.sender == lender, "Unauthorized");
        _;
    }

    modifier onlyAppraiser() {
        require(msg.sender == appraiser, "Unauthorized");
        _;
    }

    modifier notCompleted() {
        require(!completed, "Escrow closed");
        _;
    }

    modifier notInspected() {
        require(inspectionPasssed, "Inspection not passed");
        _;
    }

    bool public inspectionPasssed = false;
    mapping(address => bool) public approval;

    constructor(
        address _nftAddress,
        uint256 _nftID,
        uint256 _purchasePrice,
        uint256 _escrowAmount,
        address payable _seller,
        address payable _buyer,
        address _inspector,
        address _lender,
        address _appraiser,
        address _factory
    ) {
        nftAddress = _nftAddress;
        nftID = _nftID;
        purchasePrice = _purchasePrice;
        escrowAmount = _escrowAmount;
        seller = _seller;
        buyer = _buyer;
        inspector = _inspector;
        lender = _lender;
        factory = _factory;
        appraiser = _appraiser;
    }

    event FinalizedSale(
        uint256 nft_id,
        uint256 purchase_price,
        address indexed seller,
        address indexed buyer
    );

    // Put Under Contract (only buyer - payable escrow)
    function depositEarnest() public payable onlyBuyer notCompleted {
        require(msg.value >= escrowAmount);
        deposit_balance[msg.sender] += msg.value;
    }

    // Update Inspection Status (only inspector)
    function updateInspectionStatus(bool _passed)
        public
        onlyInspector
        notCompleted
    {
        inspectionPasssed = _passed;
    }

    function updateAppraisalValue(uint256 _value)
        public
        onlyAppraiser
        notCompleted
    {
        appraisalAmount = _value;
    }

    // Approve Sale
    function approveSale() public notCompleted {
        approval[msg.sender] = true;
    }

    function finalizeSale() public notCompleted notInspected {
        require(approval[buyer], "Buyer did not approve");
        require(approval[seller], "Sell did not approve");
        require(approval[lender], "Lender did not approve");
        require(approval[appraiser], "Appraiser did not approve");
        require(
            appraisalAmount >= purchasePrice,
            "Price higher than appraisal"
        );
        // verify contract balance is at least the purchase price
        require(address(this).balance >= purchasePrice);
        // send seller assets, take fees
        uint256 fees = purchasePrice / 10;
        (bool success, ) = payable(seller).call{value: purchasePrice - fees}(
            ""
        );
        require(success, "Failed to send seller ETH");
        completed = true;
        // send to finance contract
        IERC721(nftAddress).transferFrom(address(this), buyer, nftID);
    }

    function lenderDeposit()
        external
        payable
        onlyLender
        notCompleted
        notInspected
    {
        deposit_balance[msg.sender] += msg.value;
    }

    function buyerDeposit()
        external
        payable
        onlyBuyer
        notCompleted
        notInspected
    {
        deposit_balance[msg.sender] += msg.value;
    }

    // Cancel Sale (handle earnest deposit)
    // -> if inspection status is not approved, then refund, otherwise send to seller
    function cancelSale() public notCompleted onlySeller {
        // TODO: Get more info on how to handle cancellation
        _cancelSale(buyer);
        _cancelSale(lender);
        completed = true;
    }

    function _cancelSale(address recipient) internal {
        uint256 amount = deposit_balance[recipient];
        // buyer who initiated the earnest lost that
        if (recipient == buyer) {
            amount -= escrowAmount;
        }
        (bool success, ) = factory.call{value: amount}("");
        require(success, "Failed to send ether");
    }

    receive() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external returns (bool) {
        require(msg.sender == factory, "Unauthorized");
        uint256 amount = address(this).balance;
        (bool success, ) = factory.call{value: amount}("");
        require(success, "Failed to send ether");
        return success;
    }

    // TODO:
    // Add more robust 'cancel transaction'
    // Add more items like appraisal, ensure appraisal price is at least purchase price
    // Deploy to test network
    // Create a user interface
}
