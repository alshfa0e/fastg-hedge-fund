// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract FASTGToken is ERC20, ERC20Burnable, Pausable, AccessControl, ERC20Permit {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    uint256 public constant TOTAL_SUPPLY = 21000 * 10**18; // 21,000 tokens with 18 decimals
    uint256 public constant OPERATIONS_ALLOCATION = (TOTAL_SUPPLY * 70) / 100; // 70% for operations
    uint256 public constant RESERVE_ALLOCATION = TOTAL_SUPPLY - OPERATIONS_ALLOCATION; // 30% for reserves
    
    // Staking related variables
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;
    uint256 public totalStaked;
    uint256 public rewardRate = 5; // 5% annual reward rate
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    
    constructor() ERC20("FASTG Hedge Fund Token", "FASTG") ERC20Permit("FASTG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        // Mint initial supply
        _mint(msg.sender, TOTAL_SUPPLY);
    }
    
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function stake(uint256 amount) public whenNotPaused {
        require(amount > 0, "Cannot stake 0 tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Calculate and pay any outstanding rewards before updating stake
        _payReward(msg.sender);
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        stakedBalance[msg.sender] += amount;
        stakingTimestamp[msg.sender] = block.timestamp;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake(uint256 amount) public whenNotPaused {
        require(amount > 0, "Cannot unstake 0 tokens");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        // Calculate and pay any outstanding rewards
        _payReward(msg.sender);
        
        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function calculateReward(address account) public view returns (uint256) {
        if (stakedBalance[account] == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - stakingTimestamp[account];
        return (stakedBalance[account] * rewardRate * timeElapsed) / (365 days * 100);
    }
    
    function _payReward(address account) internal {
        uint256 reward = calculateReward(account);
        if (reward > 0) {
            stakingTimestamp[account] = block.timestamp;
            _mint(account, reward);
            emit RewardPaid(account, reward);
        }
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    // Governance support functions
    function getVotingPower(address account) public view returns (uint256) {
        return balanceOf(account) + stakedBalance[account];
    }
    
    // Update reward rate (only admin)
    function setRewardRate(uint256 newRate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRate <= 100, "Rate cannot exceed 100%");
        rewardRate = newRate;
    }
}