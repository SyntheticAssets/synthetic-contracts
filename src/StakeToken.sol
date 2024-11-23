// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import './Interface.sol';
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

contract StakeToken is ERC20 {
    using SafeERC20 for IERC20;

    address public token;
    uint48 public cooldown;
    uint48 public constant MAX_COOLDOWN = 30 days;

    struct StakeInfo {
        uint256 amount;
        uint256 cooldownAmount;
        uint256 cooldownEndTimestamp;
    }

    mapping(address => StakeInfo) public stakeInfos;

    constructor(
        string memory name_,
        string memory symbol_,
        address token_,
        uint48 cooldown_
    ) ERC20(name_, symbol_) {
        require(token_ != address(0), "token address is zero");
        require(cooldown_ < MAX_COOLDOWN, "cooldown exceeds MAX_COOLDOWN");
        token = token_;
        cooldown = cooldown_;
    }

    function decimals() public view override(ERC20) returns (uint8) {
        return ERC20(token).decimals();
    }

    function stake(uint256 amount) external {
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        require(IERC20(token).allowance(msg.sender, address(this)) >= amount, "not enough allowance");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        stakeInfo.amount += amount;
        _mint(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        require(amount <= stakeInfo.amount, "not enough to unstake");
        stakeInfo.amount -= amount;
        stakeInfo.cooldownAmount += amount;
        stakeInfo.cooldownEndTimestamp = block.timestamp + cooldown;
        _burn(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        StakeInfo storage stakeInfo = stakeInfos[msg.sender];
        require(stakeInfo.cooldownAmount >= amount, "not enough cooldown amount");
        require(stakeInfo.cooldownEndTimestamp <= block.timestamp, "cooldowning");
        IERC20(token).safeTransfer(msg.sender, amount);
        stakeInfo.cooldownAmount -= amount;
    }
}