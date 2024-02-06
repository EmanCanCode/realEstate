// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./TypesEscrow.sol"; // escrow types
// import erc721 implementer
// this will have the nft sent to it when a buyer is financed by a lender

contract Finance {
    // owner address
    bool public active;
    address public owner;
    address public lender; // the lender is the one who is providing the money
    address public borrower; // the borrower is the one who is receiving the money
    uint public amount; // amount of money owed to the lender
    uint public initialAmount; // initial amount of money being financed
    uint public interest; // interest rate, as a percentage
    uint public duration; // duration of the loan, in months
    uint public deliquencyLimit; // number of months before the loan is considered delinquent
    uint public delinquencyCount; // number of months the loan has been delinquent

    constructor(
        address _lender,
        address _borrower,
        uint _initialAmount,
        uint _interest,
        uint _duration,
        uint _deliquencyLimit
    ) {
        owner = msg.sender;
        lender = _lender;
        borrower = _borrower;
        initialAmount = _initialAmount;
        amount = _initialAmount;
        interest = _interest;
        duration = _duration;
        deliquencyLimit = _deliquencyLimit;
        delinquencyCount = 0;
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

    // arbitrary payment
    function pay() public payable onlyBorrower isActive {
        require(msg.value > 0, "Insufficient payment amount");
        amount -= msg.value;
        emit Paid(msg.value);
    }

    // pay the monthly payment
    function payMonthly() external payable isActive onlyBorrower {
        // calculate the monthly payment
        uint monthlyPayment = initialAmount / duration;
        // calculate the interest
        uint interestPayment = monthlyPayment * interest / 100;
        // calculate the total payment. if the payment is greater than the amount left, then the payment is the amount
        monthlyPayment = monthlyPayment + interestPayment > amount ? amount : monthlyPayment + interestPayment;
        // check if the payment is sufficient
        require(msg.value >= monthlyPayment, "Insufficient payment amount");
        // subtract the payment from the amount
        amount -= msg.value;

        emit Paid(msg.value);
    }



}
