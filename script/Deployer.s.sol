// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Swap} from "../src/Swap.sol";
import {AssetFactory} from "../src/AssetFactory.sol";
import {AssetIssuer} from "../src/AssetIssuer.sol";
import {AssetRebalancer} from "../src/AssetRebalancer.sol";
import {AssetFeeManager} from "../src/AssetFeeManager.sol";
import {StakeFactory} from "../src/StakeFactory.sol";
import {AssetStaking} from "../src/AssetStaking.sol";
import {HedgeSSI} from "../src/HedgeSSI.sol";

contract DeployerScript is Script {
    function setUp() public {}

    function run() public {
        address owner = vm.envAddress("OWNER");
        address vault = vm.envAddress("VAULT");
        address orderSigner = vm.envAddress("ORDER_SIGNER");
        address redeemToken = vm.envAddress("REDEEM_TOKEN");
        string memory chain = vm.envString("CHAIN_CODE");
        vm.startBroadcast();
        Swap swap = new Swap(owner, chain);
        AssetFactory factory = new AssetFactory(owner, address(swap), vault, chain);
        AssetIssuer issuer = new AssetIssuer(owner, address(factory));
        AssetRebalancer rebalancer = new AssetRebalancer(owner, address(factory));
        AssetFeeManager feeManager = new AssetFeeManager(owner, address(factory));
        StakeFactory stakeFactory = new StakeFactory(owner, address(factory));
        AssetStaking assetStaking = new AssetStaking(owner);
        HedgeSSI hedgeSSI = new HedgeSSI(owner, orderSigner, address(factory), redeemToken);
        vm.stopBroadcast();
        console.log(string.concat("swap=", vm.toString(address(swap))));
        console.log(string.concat("factory=", vm.toString(address(factory))));
        console.log(string.concat("issuer=", vm.toString(address(issuer))));
        console.log(string.concat("rebalancer=", vm.toString(address(rebalancer))));
        console.log(string.concat("feeManager=", vm.toString(address(feeManager))));
        console.log(string.concat("stakeFactory=", vm.toString(address(stakeFactory))));
        console.log(string.concat("assetStaking=", vm.toString(address(assetStaking))));
        console.log(string.concat("hedgeSSI=", vm.toString(address(hedgeSSI))));
    }
}
