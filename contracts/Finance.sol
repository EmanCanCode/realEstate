// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./TypesEscrow.sol"; // escrow types
// import erc721 implementer
// this will have the nft sent to it when a buyer is financed by a lender, spawned from a factory

contract Finance is IERC721Receiver {
    bool public executing = true;  // initialized to true until the NFT is received
    // owner address
    bool public active;
    address public owner;
    address public lender; // the lender is the one who is providing the money
    address public borrower; // the borrower is the one who is receiving the money
    uint public amount; // amount of money owed to the lender
    uint public initialAmount; // initial amount of money being financed
    uint public interest; // interest rate, as a percentage
    uint public duration; // duration of the loan, in months
    uint public delinquencyLimit; // number of months before the loan is considered delinquent
    uint public delinquencyCount; // number of months the loan has been delinquent
    uint public daysLateBeforeDelinquent; // number of days late before the loan is considered delinquent
    uint public lastMonthlyPayment; // timestamp of the last payment
    address public immutable nftAddress; // address of the nft that is in escrow between the buyer and lender
    uint public nftId; // id of the nft that is in escrow between the buyer and lender
    address public escrow; // address of the escrow contract that was fulfilled to spawn this contract

    constructor(
        address _lender,
        address _borrower,
        uint _initialAmount,
        uint _interest,
        uint _duration,
        uint _delinquencyLimit,
        uint _daysLateBeforeDelinquent,
        address _nftAddress,
        address _escrow
    ) {
        owner = msg.sender;
        lender = _lender;
        borrower = _borrower;
        initialAmount = _initialAmount;
        amount = _initialAmount;
        interest = _interest;
        duration = _duration;
        delinquencyLimit = _delinquencyLimit;
        delinquencyCount = 0;
        daysLateBeforeDelinquent = _daysLateBeforeDelinquent;
        nftAddress = _nftAddress;
        escrow = _escrow;
    }

    modifier noReentrancy() {
        require(!executing, "Reentrant call");
        executing = true;
        _;
        executing = false;
    }

    modifier onlyBorrowerOrLender() {
        require(
            msg.sender == borrower || msg.sender == lender,
            "Only the borrower or lender can call this function"
        );
        _;
    }

    modifier onlyBorrower() {
        require(
            msg.sender == borrower,
            "Only the borrower can call this function"
        );
        _;
    }

    modifier onlyLender() {
        require(msg.sender == lender, "Only the lender can call this function");
        _;
    }

    modifier isActive() {
        require(active == true, "This contract is not active");
        _;
    }

    event Paid(uint amount);
    // arbitrary payment while the loan is active
    function activePay() 
        public 
        payable 
        onlyBorrower 
        isActive 
        noReentrancy
    {
        require(msg.value > 0, "Insufficient payment amount");
        require(amount > msg.value, "dev: Use PayOff function to pay off the loan");
        amount -= msg.value;
        emit Paid(msg.value);
    }

    // pay the monthly payment
    function activeMonthlyPayment() external payable isActive onlyBorrower noReentrancy {
        // calculate the monthly payment
        uint monthlyPayment = initialAmount / duration;
        // calculate the interest
        uint interestPayment = monthlyPayment * interest / 100;
        require(monthlyPayment + interestPayment >= msg.value, "Incorrect payment amount");
        // check if the payment is sufficient
        require(msg.value >= monthlyPayment, "Insufficient payment amount");
        // we dont want the borrower to pay the entire amount off with this function
        require(msg.value < amount, "dev: Use PayOff function to pay off the loan");  
        // subtract the payment from the amount
        amount -= (msg.value - interestPayment);
        // update the last payment timestamp
        lastMonthlyPayment = block.timestamp;
        emit Paid(msg.value);
    }

    event PaidOff(uint amountPaid);
    function payOff() external payable onlyBorrower isActive noReentrancy {
        require(msg.value >= amount, "Insufficient payment amount");
        amount = 0;
        active = false;
        // send nft to borrower
        IERC721(nftAddress).safeTransferFrom(address(this), borrower, nftId);
        emit PaidOff(msg.value);
    }

    event MarkedAsDelinquent(uint delinquencyCount);
    function markDelinquent() external onlyLender isActive {
        // check if the loan is delinquent
        if (block.timestamp - lastMonthlyPayment > daysLateBeforeDelinquent * 1 days) {
            delinquencyCount++;
        }
        // check if the loan is defaulted
        if (delinquencyCount >= delinquencyLimit) {
            active = false;
        }
        emit MarkedAsDelinquent(delinquencyCount);
    }
    
    modifier isDefaulted() {
        require(delinquencyCount >= delinquencyLimit && !active, "This loan is not delinquent");
        _;
    }

    event NonActivePayment(uint amount);
    function nonActivePayment() external payable onlyBorrower isDefaulted noReentrancy {
        require(msg.value > 0, "Insufficient payment amount");
        amount -= msg.value;
        emit NonActivePayment(msg.value);
    }

    // reduce the delinquency count, for example, if the borrower makes a payment or the lender forgives a delinquency over time with on time payments etc
    function reduceDelinquencies(uint _amount) external onlyLender isDefaulted {
        delinquencyCount -= _amount;
    }

    function withdraw() external onlyLender noReentrancy {
        payable(lender).transfer(address(this).balance);
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


    // not only does this ensure the asset was deposited to this contract, but it also ensures that the escrow contract is the one that deposited it
    function depositNFT(uint _nftId) external {
        require(msg.sender == escrow, "Only the escrow contract can call this function");
        require(
            IERC721(nftAddress).ownerOf(_nftId) == address(this),
            "This contract does not own the NFT"
        );
        nftId = _nftId;
        executing = false;
    }
}
