// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {Swap} from "../src/Swap.sol";
import {AssetFactory} from "../src/AssetFactory.sol";
import {AssetIssuer} from "../src/AssetIssuer.sol";
import {AssetRebalancer} from "../src/AssetRebalancer.sol";
import {AssetFeeManager} from "../src/AssetFeeManager.sol";

contract DeployAssetController is Script {
    function setUp() public {}

    function run() public {
        address owner = vm.envAddress("OWNER");
        address vault = vm.envAddress("VAULT");
        string memory chain = vm.envString("CHAIN_CODE");
        vm.startBroadcast();
        address Swap_proxy = Upgrades.deployTransparentProxy(
            "Swap.sol",
            owner,
            abi.encodeCall(Swap.initialize, (owner, chain))
        );

        address AssetFactory_proxy = Upgrades.deployTransparentProxy(
            "AssetFactory.sol",
            owner,
            abi.encodeCall(
                AssetFactory.initialize,
                (owner, Swap_proxy, vault, chain)
            )
        );

        address AssetIssuer_proxy = Upgrades.deployTransparentProxy(
            "AssetIssuer.sol",
            owner,
            abi.encodeCall(AssetIssuer.initialize, (owner, AssetFactory_proxy))
        );

        address AssetRebalancer_proxy = Upgrades.deployTransparentProxy(
            "AssetRebalancer.sol",
            owner,
            abi.encodeCall(
                AssetRebalancer.initialize,
                (owner, AssetFactory_proxy)
            )
        );

        address AssetFeeManager_proxy = Upgrades.deployTransparentProxy(
            "AssetFeeManager.sol",
            owner,
            abi.encodeCall(
                AssetFeeManager.initialize,
                (owner, AssetFactory_proxy)
            )
        );
        vm.stopBroadcast();
        console.log(
            string.concat("Swap_proxy=", vm.toString(address(Swap_proxy)))
        );
        console.log(
            string.concat(
                "AssetFactory_proxy=",
                vm.toString(address(AssetFactory_proxy))
            )
        );

        console.log(
            string.concat(
                "AssetIssuer_proxy=",
                vm.toString(address(AssetIssuer_proxy))
            )
        );

        console.log(
            string.concat(
                "AssetRebalancer_proxy=",
                vm.toString(address(AssetRebalancer_proxy))
            )
        );

        console.log(
            string.concat(
                "AssetFeeManager_proxy=",
                vm.toString(address(AssetFeeManager_proxy))
            )
        );
    }
}
