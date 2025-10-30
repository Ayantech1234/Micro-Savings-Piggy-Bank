// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MicroSavingsPiggyBank
 * @dev A smart contract for micro-savings with time-locked deposits and early withdrawal penalties
 */
contract MicroSavingsPiggyBank {
    
    struct PiggyBank {
        uint256 totalDeposited;
        uint256 goalDate;
        uint256 createdAt;
        bool isActive;
        bool goalReached;
        uint256 depositCount;
    }
    
    // Mapping from user address to their piggy bank
    mapping(address => PiggyBank) public piggyBanks;
    
    // Configuration constants
    uint256 public constant EARLY_WITHDRAWAL_PENALTY = 10; // 10% penalty
    uint256 public constant BONUS_REWARD_PERCENTAGE = 5; // 5% bonus for reaching goal
    uint256 public constant MIN_DEPOSIT = 0.001 ether;
    uint256 public constant MIN_LOCK_PERIOD = 7 days;
    
    // Events
    event PiggyBankCreated(address indexed user, uint256 goalDate);
    event DepositMade(address indexed user, uint256 amount, uint256 totalDeposited);
    event GoalReached(address indexed user, uint256 totalAmount, uint256 bonusReward);
    event EarlyWithdrawal(address indexed user, uint256 amount, uint256 penalty);
    event RegularWithdrawal(address indexed user, uint256 amount);
    
    /**
     * @dev Create a new piggy bank with a goal date
     * @param _daysToLock Number of days to lock the funds
     */
    function createPiggyBank(uint256 _daysToLock) external {
        require(!piggyBanks[msg.sender].isActive, "Piggy bank already exists");
        require(_daysToLock >= 7, "Minimum lock period is 7 days");
        
        uint256 goalDate = block.timestamp + (_daysToLock * 1 days);
        
        piggyBanks[msg.sender] = PiggyBank({
            totalDeposited: 0,
            goalDate: goalDate,
            createdAt: block.timestamp,
            isActive: true,
            goalReached: false,
            depositCount: 0
        });
        
        emit PiggyBankCreated(msg.sender, goalDate);
    }
    
    /**
     * @dev Deposit funds into the piggy bank
     */
    function deposit() external payable {
        require(piggyBanks[msg.sender].isActive, "No active piggy bank");
        require(msg.value >= MIN_DEPOSIT, "Deposit below minimum");
        require(block.timestamp < piggyBanks[msg.sender].goalDate, "Goal date passed");
        
        piggyBanks[msg.sender].totalDeposited += msg.value;
        piggyBanks[msg.sender].depositCount++;
        
        emit DepositMade(msg.sender, msg.value, piggyBanks[msg.sender].totalDeposited);
    }
    
    /**
     * @dev Withdraw funds after reaching goal date (with bonus)
     */
    function withdraw() external {
        PiggyBank storage bank = piggyBanks[msg.sender];
        require(bank.isActive, "No active piggy bank");
        require(bank.totalDeposited > 0, "No funds to withdraw");
        require(block.timestamp >= bank.goalDate, "Goal date not reached yet");
        
        uint256 amount = bank.totalDeposited;
        uint256 bonus = (amount * BONUS_REWARD_PERCENTAGE) / 100;
        uint256 totalPayout = amount + bonus;
        
        // Mark as goal reached and inactive
        bank.goalReached = true;
        bank.isActive = false;
        bank.totalDeposited = 0;
        
        emit GoalReached(msg.sender, amount, bonus);
        
        // Transfer funds with bonus
        payable(msg.sender).transfer(totalPayout);
        emit RegularWithdrawal(msg.sender, totalPayout);
    }
    
    /**
     * @dev Emergency withdrawal with penalty (before goal date)
     */
    function emergencyWithdraw() external {
        PiggyBank storage bank = piggyBanks[msg.sender];
        require(bank.isActive, "No active piggy bank");
        require(bank.totalDeposited > 0, "No funds to withdraw");
        require(block.timestamp < bank.goalDate, "Use regular withdraw after goal date");
        
        uint256 amount = bank.totalDeposited;
        uint256 penalty = (amount * EARLY_WITHDRAWAL_PENALTY) / 100;
        uint256 payout = amount - penalty;
        
        // Reset piggy bank
        bank.isActive = false;
        bank.totalDeposited = 0;
        
        emit EarlyWithdrawal(msg.sender, payout, penalty);
        
        // Transfer funds minus penalty
        payable(msg.sender).transfer(payout);
    }
    
    /**
     * @dev Get piggy bank details for a user
     */
    function getPiggyBankDetails(address _user) external view returns (
        uint256 totalDeposited,
        uint256 goalDate,
        uint256 daysRemaining,
        bool isActive,
        bool goalReached,
        uint256 depositCount,
        uint256 potentialBonus
    ) {
        PiggyBank memory bank = piggyBanks[_user];
        
        uint256 remaining = 0;
        if (bank.goalDate > block.timestamp) {
            remaining = (bank.goalDate - block.timestamp) / 1 days;
        }
        
        uint256 bonus = 0;
        if (block.timestamp >= bank.goalDate && bank.isActive) {
            bonus = (bank.totalDeposited * BONUS_REWARD_PERCENTAGE) / 100;
        }
        
        return (
            bank.totalDeposited,
            bank.goalDate,
            remaining,
            bank.isActive,
            bank.goalReached,
            bank.depositCount,
            bonus
        );
    }
    
    /**
     * @dev Check if goal date is reached
     */
    function isGoalDateReached(address _user) external view returns (bool) {
        return block.timestamp >= piggyBanks[_user].goalDate;
    }
    
    /**
     * @dev Calculate early withdrawal penalty
     */
    function calculateEarlyWithdrawalPenalty(address _user) external view returns (uint256 penalty, uint256 payout) {
        uint256 amount = piggyBanks[_user].totalDeposited;
        penalty = (amount * EARLY_WITHDRAWAL_PENALTY) / 100;
        payout = amount - penalty;
    }
    
    /**
     * @dev Fallback function to receive deposits
     */
    receive() external payable {
        if (piggyBanks[msg.sender].isActive) {
            this.deposit();
        } else {
            revert("Create a piggy bank first");
        }
    }
    
    /**
     * @dev Get contract balance (for funding bonuses)
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
