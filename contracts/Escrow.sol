//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Escrow {
    // todo finish sending the 721 back to seller
    address public nft_address;      // address of the nft in the escrow
    uint256 public nft_id;           // id of the nft in the escrow
    uint8 public fee = 10;           // 10% from the seller
    uint256 public purchase_price;   // purchase price for the house
    uint256 public appraisal_amount; // appraiser amount for the house
    uint256 public earnest_amount;   // earnest amount
    address payable public seller;   // seller of the nft
    address payable public buyer;    // buyer of the nft
    address public appraiser;        // appraiser of the nft
    address public inspector;        // inspector of the nft
    address public lender;           // lending institution, if no lender, make lender same address as buyer
    bool public completed;           // completion state
    address public factory;          // factory address
    mapping(address => uint256) public deposit_balance; // tracks user deposit balances

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

    mapping(address => bool) public approval;

    constructor(
        address _nft_address,
        uint256 _nft_id,
        uint256 _purchase_price,
        uint256 _earnest_amount,
        address payable _seller,
        address payable _buyer,
        address _inspector,
        address _lender,
        address _appraiser,
        address _factory
    ) {
        nft_address = _nft_address;
        nft_id = _nft_id;
        purchase_price = _purchase_price;
        earnest_amount = _earnest_amount;
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

    event CanceledSale(
        address indexed actor,
        uint256 total_returned
    );

    // buyer deposits earnest
    function depositEarnest() public payable onlyBuyer notCompleted {
        require(msg.value >= earnest_amount);
        deposit_balance[msg.sender] += msg.value;
    }

    function updateAppraisalValue(uint256 _value)
        public
        onlyAppraiser
        notCompleted
    {
        appraisal_amount = _value;
    }

    // Approve Sale
    function approveSale() public notCompleted {
        approval[msg.sender] = true;
    }

    function finalizeSale() public notCompleted returns (bool) {
        require(approval[inspector], "Inspection not passed");
        require(approval[seller], "Sell did not approve");
        require(approval[buyer], "Buyer did not approve");
        require(approval[lender], "Lender did not approve");
        require(approval[appraiser], "Appraiser did not approve");
        require(
            appraisal_amount >= purchase_price,
            "Price higher than appraisal"
        );
        // verify contract balance is at least the purchase price
        require(address(this).balance >= purchase_price);
        // send seller assets, take fees
        (bool success, ) = payable(seller).call{value: purchase_price - fee}("");
        require(success, "Failed to send seller ETH");
        // todo ETHER: have a secondary way to transfer the NFT if the fee is failed but seller got their money
        (success, ) = payable(factory).call{value: fee}("");
        require(success, "Failed to send factory fees");
        completed = true;
        // send to finance contract
        // todo transfer to the lender
        IERC721(nft_address).transferFrom(address(this), buyer, nft_id);
        emit FinalizedSale(nft_id, purchase_price, seller, buyer);
        return true;
    }


    function deposit()
        external
        payable
        notCompleted
    {
        // if actor is not the buyer
        if(msg.sender != buyer) {
            // or the lender, what are you doing???
            require(msg.sender == lender, "Unauthorized");
        }
        deposit_balance[msg.sender] += msg.value;
    }

    // Cancel Sale (handle earnest deposit)
    // -> if inspection status is not approved, then refund, otherwise send to seller
    function cancelSale() public notCompleted returns (bool) {
        // if actor is not the seller
        if(msg.sender != seller) {
            // or buyer
            if(msg.sender != buyer) {
                // or the factory
                if(msg.sender != factory) { // placed just in case of emergency, break glass 
                    // or the lender, what are you doing???
                    require(msg.sender != lender, "Unauthorized");
                }
            }
        } 
        // TODO: Get more info on how to handle cancellation
        (bool success, uint256 amount_a) = _cancelSale(buyer);
        require(success, "Failed to cancel");
        // if buyer was financed
        if(buyer != lender) {
            (bool _success, uint256 amount_b) = _cancelSale(lender);
            require(_success, "Failed to cancel");
            amount_a += amount_b;
        }

        completed = true;
        // this should be buyer, seller or lender only
        emit CanceledSale(msg.sender, amount_a);
        return true;
    }

    // !! last
    function _cancelSale(address recipient) internal returns (bool, uint256) {
        // gets deposit amount
        uint256 amount = deposit_balance[recipient];
        // resets balance
        deposit_balance[recipient] = 0;
        // if recipient has any amount of ETH deposited
        if(amount > 0) {
            (bool success, ) = payable(recipient).call{value: amount}("");
            require(success, "Failed to send ether");
        }
        // returned to the seller
        IERC721(nft_address).transferFrom(address(this), seller, nft_id);
        return (true, amount);
    }

    // send money back to depositer: 
    // function refund()

    receive() external payable {}

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() public returns (bool) {
        require(msg.sender == factory, "Unauthorized");
        uint256 amount = address(this).balance;
        (bool success, ) = factory.call{value: amount}("");
        require(success, "Failed to send ether");
        return success;
    }
}