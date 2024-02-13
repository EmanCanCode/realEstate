//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Verify.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


interface IERC721 {
    function transferFrom(address _from, address _to, uint256 _id) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

interface IFinance {
    function depositNFT(uint _nftId) external;
}

contract Escrow  is IERC721Receiver {
    // todo: add reentrancy protections
    address public immutable nft_address; // nft's address
    uint256 public immutable nft_id; // nft's id
    uint8 public fee = 1;
    uint256 public purchase_price; // purchase price for the house
    uint256 public appraisal_amount; // appraiser amount for the house
    uint256 public immutable earnest_amount; // earnest amount
    address payable public immutable seller; // seller's address
    address payable public buyer; // buyer's address
    address public appraiser; // appraiser's address
    address public inspector; // inspector of the nft
    address public lender; // lending institution's address. if the same as the buyer, then the buyer is paying in cash and not taking out a loan
    address public financeContract; // address of the finance contract. nft is sent here if the buyer is financed by a lender. it will act as the escrow contract for the nft after the sale is finalized and the buyer is financed. (between buyer and lender)
    bool public completed = true; // completion state
    address public immutable factory; // factory address
    mapping(address => uint256) public deposit_balance; // tracks user deposit balances. give it an address, get that address's deposit balance
    mapping(address => bool) public approval; // tracks approval status of each party. give it an address, get that address's approval status

    constructor(
        address _nft_address,
        uint256 _nft_id,
        uint256 _purchase_price,
        uint256 _earnest_amount,
        address payable _seller,
        address payable _buyer,
        address _inspector,
        address _lender,
        address _appraiser
    ) {
        factory = msg.sender;
        nft_address = _nft_address;
        nft_id = _nft_id;
        purchase_price = _purchase_price;
        earnest_amount = _earnest_amount;
        seller = _seller;
        buyer = _buyer;
        inspector = _inspector;
        lender = _lender;
        appraiser = _appraiser;
    }

    receive() external payable {
        revert("Do not send ETH directly to this contract");
    }

    fallback() external payable {
        revert("Do not send ETH directly to this contract");
    }

    // ensures that the sale is not completed when this modifier is invoked
    modifier notCompleted() {
        require(purchase_price > 0, "Sale was cancelled"); // ensure sale is not cancelled
        require(!completed, "Escrow completed");
        _;
    }

    modifier onlyAuthorized() {
        // ensure only the authorized parties can call this method
        require(
            msg.sender == buyer ||
                msg.sender == seller ||
                msg.sender == inspector || 
                msg.sender == appraiser ||
                msg.sender == lender,
            "Unauthorized"
        );
        _;
    }

    // emit this event when the sale is finalized, allows for off-chain processing of the sale. (e.g. minting a new nft, API calls, etc.)
    event FinalizedSale(
        uint256 nft_id,
        uint256 purchase_price,
        address indexed seller,
        address indexed buyer
    );
    // emit this event when the sale is canceled, allows for off-chain processing of the sale. (e.g. minting a new nft, API calls, etc.)
    event CanceledSale(address indexed actor, uint256 total_returned);
    // emit this event when a deposit is made
    event Deposit(address indexed actor, uint256 amount);
    // emit this event when the appraiser initializes the appraisal value
    event AppraisalInitialized(uint256 indexed nft_id, uint256 appraisal_value, address indexed appraiser);
    // emit this event when the sale is approved
    event SaleApproved(address indexed approver, uint256 indexed nft_id);
    // emit this event when a payment is processed
    event PaymentProcessed(address indexed payee, uint256 amount);
    // emit this event when earnest is deposited
    event EarnestDepositReceived(address indexed depositor, uint256 amount);

    // buyer deposits earnest
    function depositEarnest() public payable {
        require(purchase_price > 0, "Sale was cancelled"); // ensure sale is not cancelled
        require(completed, "Sale not completed"); // ensure sale is not completed ()
        require(msg.sender == buyer, "Unauthorized");
        require(msg.value >= earnest_amount);
        deposit_balance[msg.sender] += msg.value;
        completed = false; // set completed to false to prevent sale from being finalized until earnest is deposited

        emit EarnestDepositReceived(msg.sender, msg.value);
    }

    function setFinanceContract(
        address _financeContract, // address of the finance contract that will act as the escrow contract for the nft after the sale is finalized and the buyer is financed. (between buyer and lender)
        bytes memory _buyerSignature, // buyer's signature of the location of the escrow after sale is finalized
        bytes memory _lenderSignature // lender's signature of the location of the escrow after sale is finalized
    ) external {
        bytes32 messageDigest = keccak256(
            abi.encodePacked(
                'I, buyer at address: ',
                buyer,
                ' being financed by lender at address: ',
                lender,
                ' agree to hold the asset at address: ',
                _financeContract,
                ' after the sale is finalized'
            )
        );
        require(
            Verify.recoverSigner(
                messageDigest,
                _buyerSignature
            ) == buyer,
            "Invalid buyer signature"
        );
        require(
            Verify.recoverSigner(
                messageDigest,
                _lenderSignature
            ) == lender,
            "Invalid lender signature"
        );
        financeContract = _financeContract;
    }

    // how the appraiser can initiate the nft evaluation
    function initializeAppraisalValue(uint256 _value) external notCompleted {
        require(msg.sender == appraiser, "Unauthorized");
        appraisal_amount = _value;

        emit AppraisalInitialized(nft_id, _value, appraiser);
    }

    // Approve Sale
    function approveSale() external notCompleted onlyAuthorized {
        approval[msg.sender] = true;
        emit SaleApproved(msg.sender, nft_id);
    }

    function finalizeSale() public notCompleted onlyAuthorized {
        // Checks
        require(_checkApprovals(), "Not all parties have approved");
        require(
            appraisal_amount >= purchase_price,
            "Price higher than appraisal"
        );
        require(_checkDepositBalances(), "Not enough funds in escrow");
        if (lender != buyer) {
            require(
                financeContract != address(0),
                "Finance contract not set"
            );
        }

        // Effects
        completed = true; // Mark the sale as completed
        uint256 _purchase_price = purchase_price; // Store purchase price in a local variable
        purchase_price = 0; // Reset purchase price to prevent reinitialization

        // Reset deposit balances
        deposit_balance[buyer] = 0;
        deposit_balance[lender] = 0;

        // Interactions
        // Transfer NFT to lender. if lender == buyer, then the buyer is paying in cash and not taking out a loan;
        IERC721(nft_address).safeTransferFrom(
            address(this), 
            lender == buyer ? buyer : financeContract,  // if lender == buyer, then the buyer is paying in cash and not taking out a loan
            nft_id, 
            ""
        );
        IFinance(financeContract).depositNFT(nft_id); // deposit nft into finance contract if the buyer is financed by a lender

        // Handle payments
        _handlePayments(_purchase_price);

        // Emit event
        emit FinalizedSale(nft_id, _purchase_price, seller, buyer);
    }

    // Internal function to handle payments
    function _handlePayments(uint256 _purchase_price) internal {
        // Calculate the seller's amount after fee deduction
        uint256 seller_amount = (_purchase_price * (100 - fee)) / 100;

        // Send the calculated amount to the seller
        (bool success, ) = payable(seller).call{value: seller_amount}("");
        require(success, "Failed to send seller ETH");

        // Send the remaining amount to the factory
        (success, ) = payable(factory).call{value: address(this).balance}("");

        emit PaymentProcessed(seller, seller_amount);
    }

    function deposit() external payable notCompleted {
        // if actor is not the buyer
        if (msg.sender != buyer) {
            // or the lender, what are you doing???
            require(msg.sender == lender, "Unauthorized");
        }
        deposit_balance[msg.sender] += msg.value;

        // emit event
        emit Deposit(msg.sender, msg.value);
    }

    // Cancel Sale
    function cancelSale() public notCompleted {
        completed = true; // set completed to true to prevent sale from being finalized again (reentrancy attack)
        purchase_price = 0; // set purchase price to 0 to prevent sale from being reinitialized again
        // return nft to seller
        IERC721(nft_address).transferFrom(address(this), seller, nft_id);

        // reset deposit balances
        uint buyer_deposit = deposit_balance[buyer];
        uint lender_deposit = deposit_balance[lender];
        deposit_balance[buyer] = 0;
        deposit_balance[lender] = 0;

        // return all assets to buyer and lender
        _refund(buyer_deposit, lender_deposit);

        // emit event
        emit CanceledSale(
            msg.sender,
            deposit_balance[buyer] + deposit_balance[lender]
        );
    }

    // public helpers

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() public returns (bool) {
        require(msg.sender == factory, "Unauthorized");
        uint256 amount = address(this).balance;
        (bool success, ) = factory.call{value: amount}("");
        require(success, "Failed to send ether");
        return success;
    }

    // internal

    function _checkApprovals() internal view returns (bool) {
        return
            approval[inspector] &&
            approval[seller] &&
            approval[buyer] &&
            approval[lender] &&
            approval[appraiser];
    }

    function _checkDepositBalances() internal view returns (bool) {
        return
            deposit_balance[buyer] + deposit_balance[lender] ==
            purchase_price &&
            getBalance() >= purchase_price;
    }

    function _refund(uint _buyer_deposit, uint _lender_deposit) internal {
        (bool success, ) = payable(buyer).call{value: _buyer_deposit}("");
        require(success, "Failed to send buyer ETH");
        (success, ) = payable(lender).call{value: _lender_deposit}("");
        require(success, "Failed to send lender ETH");
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Return the function selector
        return this.onERC721Received.selector;
    }

}
