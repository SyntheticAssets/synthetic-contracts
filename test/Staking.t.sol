// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./MockToken.sol";
import "../src/Interface.sol";
import "../src/Swap.sol";
import "../src/AssetFactory.sol";
import "../src/AssetIssuer.sol";
import "../src/StakeFactory.sol";
import "../src/AssetStaking.sol";
import "../src/HedgeSSI.sol";


import {Test, console} from "forge-std/Test.sol";

contract FundManagerTest is Test {
    MockToken WBTC = new MockToken("Wrapped BTC", "WBTC", 8);
    MockToken WETH = new MockToken("Wrapped ETH", "WETH", 18);

    address owner = vm.addr(0x1);
    address vault = vm.addr(0x2);
    address pmm = vm.addr(0x3);
    address ap = vm.addr(0x4);
    address swap = vm.addr(0x5);
    address rebalancer = vm.addr(0x7);
    address feeManager = vm.addr(0x8);
    uint256 orderSignerPk = 0x9;
    address orderSigner = vm.addr(orderSignerPk);
    address staker = vm.addr(0x10);
    address hedger = vm.addr(0x10);

    AssetIssuer issuer;
    AssetToken assetToken;
    AssetFactory factory;
    StakeFactory stakeFactory;
    StakeToken stakeToken;
    AssetStaking assetStaking;
    HedgeSSI hedgeSSI;

    uint256 stakeAmount = 1e8;

    function getAsset() public view returns (Asset memory) {
        Token[] memory tokenset_ = new Token[](1);
        tokenset_[0] = Token({
            chain: "SETH",
            symbol: WBTC.symbol(),
            addr: vm.toString(address(WBTC)),
            decimals: WBTC.decimals(),
            amount: 10 * 10 ** WBTC.decimals() / 60000
        });
        Asset memory asset = Asset({
            id: 1,
            name: "BTC",
            symbol: "BTC",
            tokenset: tokenset_
        });
        return asset;
    }

    function setUp() public {
        vm.startPrank(owner);
        factory = new AssetFactory(owner, swap, vault, "SETH");
        issuer = new AssetIssuer(owner, address(factory));
        address assetTokenAddress = factory.createAssetToken(getAsset(), 10000, address(issuer), rebalancer, feeManager);
        assetToken = AssetToken(assetTokenAddress);
        stakeFactory = new StakeFactory(owner, address(factory));
        assetStaking = new AssetStaking(owner);
        hedgeSSI = new HedgeSSI(owner, orderSigner, address(factory), address(WBTC));
        vm.stopPrank();
        vm.startPrank(address(issuer));
        assetToken.mint(staker, stakeAmount);
        vm.stopPrank();
    }

    function testStakeAndLock() public {
        // create stake token
        vm.startPrank(owner);
        stakeToken = StakeToken(stakeFactory.createStakeToken(assetToken.id(), 3600*24*7));
        assertEq(stakeToken.token(), address(assetToken));
        vm.stopPrank();
        // stake
        vm.startPrank(staker);
        assetToken.approve(address(stakeToken), stakeAmount * 10);
        stakeToken.stake(stakeAmount);
        vm.expectRevert();
        stakeToken.stake(1);
        vm.stopPrank();
        // check balance
        assertEq(assetToken.balanceOf(staker), 0);
        assertEq(stakeToken.balanceOf(staker), stakeAmount);
        assertEq(stakeToken.totalSupply(), stakeAmount);
        assertEq(assetToken.totalSupply(), stakeAmount);
        // unstake
        vm.startPrank(staker);
        uint256 unstakeAmount = stakeAmount * 50 / 100;
        stakeToken.unstake(unstakeAmount);
        vm.stopPrank();
        (uint256 amount, uint256 cooldownAmount, uint256 cooldownEndTimestamp) = stakeToken.stakeInfos(staker);
        assertEq(amount, stakeAmount - cooldownAmount);
        assertEq(unstakeAmount, cooldownAmount);
        assertEq(cooldownEndTimestamp, block.timestamp + stakeToken.cooldown());
        // check balance
        assertEq(stakeToken.balanceOf(staker), stakeAmount - unstakeAmount);
        assertEq(stakeToken.totalSupply(), stakeAmount - unstakeAmount);
        assertEq(assetToken.totalSupply(), stakeAmount);
        // withdraw
        vm.startPrank(staker);
        vm.expectRevert();
        stakeToken.withdraw(cooldownAmount);
        vm.warp(block.timestamp + stakeToken.cooldown());
        stakeToken.withdraw(cooldownAmount);
        // check balance
        assertEq(assetToken.balanceOf(staker), unstakeAmount);
        assertEq(stakeToken.balanceOf(staker), stakeAmount - unstakeAmount);
        assertEq(stakeToken.totalSupply(), stakeAmount - unstakeAmount);
        assertEq(assetToken.totalSupply(), stakeAmount);
        vm.stopPrank();
        // lock
        uint256 lockAmount = stakeAmount - unstakeAmount;
        // can not lock
        vm.startPrank(staker);
        vm.expectRevert();
        assetStaking.stake(address(stakeToken), lockAmount);
        vm.stopPrank();
        // owner update stake config
        vm.startPrank(owner);
        assetStaking.updateStakeConfig(address(stakeToken), 0, lockAmount * 2, 7 days);
        vm.stopPrank();
        // can lock
        vm.startPrank(staker);
        stakeToken.approve(address(assetStaking), lockAmount);
        assetStaking.stake(address(stakeToken), lockAmount);
        vm.stopPrank();
        assertEq(stakeToken.balanceOf(staker), 0);
        assertEq(stakeToken.balanceOf(address(assetStaking)), lockAmount);
        (amount, cooldownAmount, cooldownEndTimestamp) = assetStaking.stakeDatas(address(stakeToken), staker);
        assertEq(amount, lockAmount);
        assertEq(cooldownAmount, 0);
        assertEq(cooldownEndTimestamp, 0);
        // unlock
        vm.startPrank(staker);
        vm.expectRevert();
        assetStaking.unstake(address(stakeToken), lockAmount + 1);
        assetStaking.unstake(address(stakeToken), lockAmount);
        vm.stopPrank();
        assertEq(stakeToken.balanceOf(staker), 0);
        assertEq(stakeToken.balanceOf(address(assetStaking)), lockAmount);
        (amount, cooldownAmount, cooldownEndTimestamp) = assetStaking.stakeDatas(address(stakeToken), staker);
        (,,uint256 cooldown,,) = assetStaking.stakeConfigs(address(stakeToken));
        assertEq(amount, 0);
        assertEq(cooldownAmount, lockAmount);
        assertEq(cooldownEndTimestamp, block.timestamp + cooldown);
        // withdraw
        vm.startPrank(staker);
        vm.expectRevert();
        assetStaking.withdraw(address(stakeToken), lockAmount);
        vm.warp(block.timestamp + cooldown);
        assetStaking.withdraw(address(stakeToken), lockAmount);
        vm.stopPrank();
        assertEq(stakeToken.balanceOf(staker), lockAmount);
        assertEq(stakeToken.balanceOf(address(assetStaking)), 0);
    }

    function testHedge() public {
        // apply mint
        HedgeSSI.HedgeOrder memory mintOrder = HedgeSSI.HedgeOrder({
            orderType: HedgeSSI.HedgeOrderType.MINT,
            assetID: 1,
            nonce: 0,
            inAmount: stakeAmount,
            outAmount: stakeAmount * 10,
            deadline: block.timestamp + 600,
            requester: hedger
        });
        vm.startPrank(hedger);
        vm.expectRevert();
        hedgeSSI.applyMint(mintOrder, new bytes(10));
        vm.stopPrank();
        vm.startPrank(owner);
        hedgeSSI.addSupportAsset(1);
        vm.stopPrank();
        bytes32 orderHash = keccak256(abi.encode(mintOrder));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(orderSignerPk, orderHash);
        bytes memory orderSign = abi.encodePacked(r, s, v);
        vm.startPrank(hedger);
        assetToken.approve(address(hedgeSSI), stakeAmount);
        hedgeSSI.applyMint(mintOrder, orderSign);
        vm.stopPrank();
        // confirm mint
        vm.startPrank(owner);
        hedgeSSI.confirmMint(orderHash);
        vm.stopPrank();
        assertEq(assetToken.balanceOf(hedger), 0);
        assertEq(hedgeSSI.balanceOf(hedger), stakeAmount * 10);
        // apply redeem
        HedgeSSI.HedgeOrder memory redeemOrder = HedgeSSI.HedgeOrder({
            orderType: HedgeSSI.HedgeOrderType.REDEEM,
            assetID: 1,
            nonce: 1,
            inAmount: stakeAmount * 10,
            outAmount: stakeAmount,
            deadline: block.timestamp + 600,
            requester: hedger
        });
        orderHash = keccak256(abi.encode(redeemOrder));
        (v, r, s) = vm.sign(orderSignerPk, orderHash);
        orderSign = abi.encodePacked(r, s, v);
        vm.startPrank(hedger);
        hedgeSSI.approve(address(hedgeSSI), stakeAmount * 10);
        hedgeSSI.applyRedeem(redeemOrder, orderSign);
        vm.stopPrank();
        // confirm redeem
        vm.startPrank(owner);
        vm.expectRevert();
        hedgeSSI.confirmRedeem(orderHash);
        WBTC.mint(owner, stakeAmount);
        WBTC.transfer(address(hedgeSSI), stakeAmount);
        hedgeSSI.confirmRedeem(orderHash);
        vm.stopPrank();
        assertEq(hedgeSSI.balanceOf(hedger), 0);
        assertEq(WBTC.balanceOf(hedger), stakeAmount);
    }
}