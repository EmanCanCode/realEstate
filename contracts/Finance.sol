// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./RealEstate.sol";

// this is the contract when one uses a loan
contract Finance {
    uint256 public late_fee = 1000000000000000000 / 4; // 0.25 eth
    address public admin;
    RealEstate public realEstate;
    // applicant, token_id
    mapping(address => mapping(uint256 => LienForm)) public lienForm;
    // applicant, token_id
    mapping(address => mapping(uint256 => Application)) public application;

    struct Application {
        uint256 token_id; // NFT token ID
        address applicant;
        address lender;
        uint256 loan_amount; // asking amount
        uint256 offered_amount; // offered amount
        uint256 preferred_rate; // asking rate  100 is 1%
        uint256 offered_rate; // offered rate
        uint256 preferred_monthly; // asking monthly
        uint256 offered_monthly; // offered monthly
        uint256 timestamp; // timestamp
        bool approved;
        bool completed;
    }

    struct LienForm {
        uint256 token_id;
        address borrower;
        address lender;
        uint256 amount_lended;
        uint256 amount_owed;
        uint8 errors_allowed;
        uint8 errors;
        uint256 rate;
        uint256 payment_due;
        uint256 term_length;
        bool active;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized");
        _;
    }

    modifier initialized() {
        require(address(realEstate) != address(0), "Real Estate not set");
        _;
    }

    event Applied(
        address indexed applicant,
        address indexed lender,
        uint256 amount,
        uint256 timestamp
    );

    event PaidLender(
        address indexed applicant,
        address indexed lender,
        uint256 amount,
        uint256 remaining_balance
    );

    event LenderFinalize(
        address indexed lender,
        address indexed applicant,
        bool approved
    );

    event Canceled(
        address indexed applicant,
        uint256 token_id,
        uint256 timestamp
    );

    event Completed(
        address indexed applicant,
        uint256 token_id,
        uint256 timestamp,
        bool approved
    );

    event LienInitiated(
        address indexed borrower,
        address indexed lender,
        uint256 borrowed_amount
    );


    // forelcosed events
    constructor(address _admin) {
        admin = _admin;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setRealEstate(address _realEstate) external onlyAdmin {
        realEstate = RealEstate(_realEstate);
    }

    /*
        Allows a borrower to apply for a loan by setting an application for a specific NFT they own. 
        The borrower can set the loan amount, preferred interest rate, and preferred monthly payment.
    */
    // applies/sets application
    function applyForLending(
        uint256 token_id,
        address lender,
        uint256 loan_amount,
        uint256 preferred_rate,
        uint256 preferred_monthly
    ) public initialized returns (bool) {
        // get owner of token and verify owner == msg.sender
        address token_owner = realEstate.ownerOf(token_id);
        require(msg.sender == token_owner, "Unauthorized");
        // get application from struct
        Application memory app = application[msg.sender][token_id];
        // if lending has been initiated
        if (app.token_id == token_id) {
            // require it to be completed before applying again
            require(app.completed, "Previous Application pending");
        }
        // create application
        Application memory _application = Application({
            token_id: token_id,
            applicant: msg.sender,
            lender: lender,
            loan_amount: loan_amount,
            offered_amount: 0,
            preferred_rate: preferred_rate,
            offered_rate: 0,
            preferred_monthly: preferred_monthly,
            offered_monthly: 0,
            timestamp: block.timestamp,
            approved: false,
            completed: false
        });

        application[msg.sender][token_id] = _application;
        emit Applied(msg.sender, lender, loan_amount, block.timestamp);
        return true;
    }

    /*
        Allows a lender to finalize a loan application by approving or rejecting the loan offer. 
        If approved, the lender can set the loan amount, interest rate, and monthly payment.
    */
    // lender finalizes app
    function lenderFinalizeApp(
        uint256 token_id,
        address applicant,
        uint256 offered_amount,
        bool approved,
        uint256 offered_rate
    ) public returns (bool) {
        // gets application and verifies lender of app is msg.sender
        Application memory app = application[applicant][token_id];
        require(msg.sender == app.lender, "Unauthorized");
        // set app object
        app.offered_amount = offered_amount;
        app.offered_rate = offered_rate;
        app.approved = approved;
        // if not approved
        if (!approved) {
            // complete the application
            app.completed = true;
            emit Completed(applicant, token_id, block.timestamp, approved);
        }
        // set application mapping
        application[applicant][token_id] = app;
        emit LenderFinalize(msg.sender, app.applicant, approved);
        return true;
    }

    /*
        Allows the borrower to cancel their loan application before it is approved or rejected.
    */
    // applicant cancels application
    function cancelApplication(uint256 token_id) external returns (bool) {
        // get application and verify that msg.sender is the applicant
        Application memory app = application[msg.sender][token_id];
        require(msg.sender == app.applicant, "Unauthorized");
        // ensure that the application isnt completed by this point
        require(!app.completed, "Already Completed");
        // completes app
        app.completed = true;
        // update mapping
        application[msg.sender][token_id] = app;
        emit Canceled(msg.sender, token_id, block.timestamp);
        return true;
    }

    /*
        Allows the borrower to complete their loan application after it is approved and the lien form is initiated.
    */
    // applicant can complete application after everything is completed
    function completeApplication(uint256 token_id) external returns (bool) {
        // retrieve application
        Application memory app = application[msg.sender][token_id];
        // ensures that applicant is msg.sender
        require(msg.sender == app.applicant, "Unauthorized");
        // require the app to not be completed already
        require(!app.completed, "Already completed");
        // completes the application
        app.completed = true;
        // sets the mapping
        application[msg.sender][token_id] = app;
        return true;
    }

    /*
        Allows the lender to initiate a lien form after the loan application is approved. 
        The lien form sets the terms of the loan, including the amount lended, amount owed, interest rate, payment due date, and term length.
    */
    // lender creates lien form after applicant is approved
    function lenderInitiateForm(
        address applicant,
        uint256 token_id,
        uint8 errors_allowed,
        uint256 term_length
    ) external returns (bool) {
        // gets application
        Application memory app = application[applicant][token_id];
        // ensures that lender is msg.sender
        require(msg.sender == app.lender, "Unauthorized");
        // ensures the application was approved
        require(app.approved, "Not approved");
        // ensures that the application is completed
        require(app.completed, "App not completed");
        // create a new lien form
        LienForm memory form = LienForm({
            token_id: token_id,
            borrower: applicant,
            lender: msg.sender,
            amount_lended: app.offered_amount,
            amount_owed: app.offered_amount,
            errors_allowed: errors_allowed,
            errors: 0,
            rate: app.offered_rate,
            payment_due: block.timestamp + 30 days,
            term_length: term_length,
            active: true
        });
        // updates mapping
        lienForm[app.applicant][token_id] = form;
        emit LienInitiated(applicant, msg.sender, app.offered_amount);
        return true;
    }

    /*
        Checks for delinquencies in loan payments and adds late fees if necessary. If there are too many delinquencies, the loan becomes inactive.
    */
    // borrower/lender checks for errors
    function checkForErrors(
        address borrower,
        uint256 token_id
    ) public returns (uint256) {
        // TODO ⚠️DO THE MATH FOR RATE / TIME PASSED RATIO, ⚠️
        // retrieve form
        LienForm memory form = lienForm[borrower][token_id];
        // ensure that msg.sender is only the borrower or lender
        if (msg.sender != form.borrower) {
            require(msg.sender == form.lender, "Unauthorized");
        }
        // ensure its an active loan
        require(form.active, "Not active");
        // if right now is greater than the payment due date
        if (block.timestamp > form.payment_due) {
            // add to errors
            form.errors++;
            // due date goes a month from missed due date
            form.payment_due = form.payment_due + 30 days;
            // add them fees since they are late
            form.amount_owed += late_fee;
        }
        // if they made too many mistakes
        if (form.errors_allowed == form.errors) {
            // make this form inactive
            form.active = false;
            // todo: When Escrow contract finalizes, send to 'this' contract
            // todo: Send the lender the house NFT, handle forclosure etc...
        }
        // update form
        lienForm[borrower][token_id] = form;
        // return error count
        return form.errors;
    }

    /*
        Allows the borrower to make payments towards the loan, which is sent to the lender. 
        The function checks for delinquencies before accepting the payment and updates the amount owed and payment due date.
    */
    function payLender(
        address payable lender,
        uint256 token_id
    ) public payable returns (bool) {
        // get the finance/lien form
        LienForm memory form = lienForm[msg.sender][token_id];
        // require the caller is the borrower
        require(msg.sender == form.borrower, "Unauthorized");
        // checks for errors
        uint256 errors = checkForErrors(msg.sender, token_id);
        // require that this hasn't had too many errors (foreclosed?)
        require(errors < form.errors_allowed, "Too many deliquencies");
        // gets minimum payment
        uint256 minimum_payment = form.amount_lended / form.term_length;
        // assert that the amount sent to the contract is at least the minimum payment
        require(msg.value >= minimum_payment, "Insufficient value");
        // someone is getting paaaaaaaid (lender)
        (bool success, ) = payable(lender).call{value: msg.value}("");
        // assert it was sent
        require(success, "Failed to pay Lender");
        // subtract the amount that was sent
        uint256 interest_rate = form.rate / 12;
        form.amount_owed -= msg.value;
        form.amount_owed += ((form.amount_owed * interest_rate) / 100);
        // make the next payment a month out from this payment
        form.payment_due = block.timestamp + 30 days;
        // sets the form
        lienForm[msg.sender][token_id] = form;
        // emits event that someone got paid
        emit PaidLender(msg.sender, lender, msg.value, form.amount_owed);
        // returns success
        return success;
    }
}
