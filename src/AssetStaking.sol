// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import './Interface.sol';
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "forge-std/console.sol";

contract AssetStaking is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    constructor(address owner) Ownable(owner) {

    }

    uint48 public constant MAX_COOLDOWN = 90 days;

    struct StakeConfig {
        uint8 epoch;
        uint256 stakeLimit;
        uint48 cooldown;
        uint256 totalStaked;
        uint256 totalCooldown;
    }

    struct StakeData {
        uint256 amount;
        uint256 cooldownAmount;
        uint256 cooldownEndTimestamp;
    }

    EnumerableSet.AddressSet tokens_;
    mapping(address => uint8) public activeEpochs;
    mapping(address => StakeConfig) public stakeConfigs;
    mapping(address => mapping (address => StakeData)) public stakeDatas;

    function setEpoch(address token, uint8 newEpoch) external onlyOwner {
        require(newEpoch != activeEpochs[token], "epoch not change");
        activeEpochs[token] = newEpoch;
    }

    function updateStakeConfig(address token, uint8 epoch, uint256 stakeLimit, uint48 cooldown) external onlyOwner {
        if (!tokens_.contains(token)) {
            tokens_.add(token);
        }
        require(cooldown <= MAX_COOLDOWN, "cooldown exceeds MAX_COOLDOWN");
        StakeConfig storage stakeConfig = stakeConfigs[token];
        stakeConfig.epoch = epoch;
        stakeConfig.stakeLimit = stakeLimit;
        stakeConfig.cooldown = cooldown;
    }

    function getActiveTokens() external view returns (address[] memory tokens)  {
        address[] memory tmp = new address[](tokens_.length());
        uint j = 0;
        for (uint i = 0; i < tokens_.length(); i++) {
            address token = tokens_.at(i);
            if (stakeConfigs[token].epoch == activeEpochs[token]) {
                tmp[j] = token;
                j += 1;
            }
        }
        tokens = new address[](j);
        for (uint i = 0; i < j; i++) {
            tokens[i] = tmp[i];
        }
    }

    function stake(address token, uint256 amount) external {
        require(tokens_.contains(token), "token not supported");
        require(stakeConfigs[token].epoch == activeEpochs[token], "token cannot stake now");
        StakeData storage stakeData = stakeDatas[token][msg.sender];
        StakeConfig storage stakeConfig = stakeConfigs[token];
        require(stakeConfig.totalStaked + amount <= stakeConfig.stakeLimit, "total stake amount exceeds stake limit");
        require(IERC20(token).allowance(msg.sender, address(this)) >= amount, "not enough allowance");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        stakeData.amount += amount;
        stakeConfig.totalStaked += amount;
    }

    function unstake(address token, uint256 amount) external {
        StakeData storage stakeData = stakeDatas[token][msg.sender];
        StakeConfig storage stakeConfig = stakeConfigs[token];
        require(stakeData.amount >= amount, "not enough balance to unstake");
        stakeData.amount -= amount;
        stakeData.cooldownAmount += amount;
        stakeData.cooldownEndTimestamp = block.timestamp + stakeConfig.cooldown;
        stakeConfig.totalStaked -= amount;
        stakeConfig.totalCooldown += amount;
    }

    function withdraw(address token, uint256 amount) external {
        StakeData storage stakeData = stakeDatas[token][msg.sender];
        require(stakeData.cooldownAmount > 0, "nothing to withdraw");
        require(stakeData.cooldownEndTimestamp <= block.timestamp, "coolingdown");
        require(stakeData.amount <= stakeData.cooldownAmount, "no enough balance to withdraw");
        IERC20(token).safeTransfer(msg.sender, amount);
        stakeData.cooldownAmount -= amount;
        StakeConfig storage stakeConfig = stakeConfigs[token];
        stakeConfig.totalCooldown -= amount;
    }
}