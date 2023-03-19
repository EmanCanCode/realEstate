// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

contract LiquidityPool {
    address public admin;
    IERC20 public lpToken;
    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    event Deposit(address indexed depositor, uint256 amount, uint256 lpTokensMinted);
    event Withdrawal(address indexed withdrawer, uint256 amount, uint256 lpTokensBurned);

    constructor(IERC20 _lpToken) {
        admin = msg.sender;
        lpToken = _lpToken;
    }

    function deposit() external payable returns (uint256) {
        require(msg.value > 0, "Must deposit non-zero amount of ETH");
        uint256 lpTokensMinted = 0;
        if (totalSupply == 0) {
            // if there are no LP tokens in circulation, mint new ones equal to the amount of ETH deposited
            lpTokensMinted = msg.value;
        } else {
            // if there are LP tokens in circulation, calculate how many to mint based on the current exchange rate
            lpTokensMinted = (msg.value * totalSupply) / address(this).balance;
        }
        // mint LP tokens to depositor and update balances and totalSupply
        lpToken.transfer(msg.sender, lpTokensMinted);
        balances[msg.sender] += msg.value;
        totalSupply += lpTokensMinted;
        emit Deposit(msg.sender, msg.value, lpTokensMinted);
        return lpTokensMinted;
    }

    function withdraw(uint256 lpTokens) external returns (uint256) {
        require(lpTokens > 0, "Must withdraw non-zero amount of LP tokens");
        uint256 ethToWithdraw = (lpTokens * address(this).balance) / totalSupply;
        // burn LP tokens from withdrawer and update balances and totalSupply
        lpToken.transferFrom(msg.sender, address(0), lpTokens);
        balances[msg.sender] -= ethToWithdraw;
        totalSupply -= lpTokens;
        // transfer ETH to withdrawer
        (bool success, ) = msg.sender.call{value: ethToWithdraw}("");
        require(success, "ETH transfer failed");
        emit Withdrawal(msg.sender, ethToWithdraw, lpTokens);
        return ethToWithdraw;
    }

    function withdrawAdmin(uint256 amount) external {
        require(msg.sender == admin, "Unauthorized");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin, "Unauthorized");
        admin = _admin;
    }
}
