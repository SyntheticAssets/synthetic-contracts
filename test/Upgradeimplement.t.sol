// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import "forge-std/console.sol";
import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {Swap} from "../src/Swap.sol";
import {AssetFactory} from "../src/AssetFactory.sol";
import {AssetIssuer} from "../src/AssetIssuer.sol";
import {AssetRebalancer} from "../src/AssetRebalancer.sol";
import {AssetFeeManager} from "../src/AssetFeeManager.sol";
import {Options} from "../lib/openzeppelin-foundry-upgrades/src/Options.sol";

contract UpgradeTest is Test {
    address owner = vm.addr(0x1);
    // console.log(owner);
    address vault =
        vm.parseAddress("0xc9b6174bDF1deE9Ba42Af97855Da322b91755E63");
    string chain = "TEST_CHAIN";

    address swapImplimentation;
    address assetFactoryImplimentation;
    address assetIssuerImplimentation;
    address assetRebalancerImplimentation;
    address assetFeeManagerImplimentation;

    address swapProxy;
    address assetFactoryProxy;
    address assetIssuerProxy;
    address assetRebalancerProxy;
    address assetFeeManagerProxy;

    address swapProxyAdmin;
    address assetFactoryProxyAdmin;
    address assetIssuerProxyAdmin;
    address assetRebalancerProxyAdmin;
    address assetFeeManagerProxyAdmin;

    Swap swap;
    AssetFactory assetFactory;
    AssetIssuer assetIssuer;
    AssetRebalancer assetRebalancer;
    AssetFeeManager assetFeeManager;

    function setUp() public {
        // Deploy proxies for existing contracts
        swapProxy = Upgrades.deployTransparentProxy(
            "Swap.sol",
            owner,
            abi.encodeCall(Swap.initialize, (owner, chain))
        );
        swap = Swap(swapProxy);
        swapProxyAdmin = Upgrades.getAdminAddress(swapProxy);
        swapImplimentation = Upgrades.getImplementationAddress(swapProxy);

        assetFactoryProxy = Upgrades.deployTransparentProxy(
            "AssetFactory.sol",
            owner,
            abi.encodeCall(
                AssetFactory.initialize,
                (owner, swapProxy, vault, chain)
            )
        );
        assetFactory = AssetFactory(assetFactoryProxy);
        assetFactoryProxyAdmin = Upgrades.getAdminAddress(assetFactoryProxy);
        assetFactoryImplimentation = Upgrades.getImplementationAddress(
            assetFactoryProxy
        );

        assetIssuerProxy = Upgrades.deployTransparentProxy(
            "AssetIssuer.sol",
            owner,
            abi.encodeCall(AssetIssuer.initialize, (owner, assetFactoryProxy))
        );
        assetIssuer = AssetIssuer(assetIssuerProxy);
        assetIssuerProxyAdmin = Upgrades.getAdminAddress(assetIssuerProxy);
        assetIssuerImplimentation = Upgrades.getImplementationAddress(
            assetIssuerProxy
        );

        assetRebalancerProxy = Upgrades.deployTransparentProxy(
            "AssetRebalancer.sol",
            owner,
            abi.encodeCall(
                AssetRebalancer.initialize,
                (owner, assetFactoryProxy)
            )
        );
        assetRebalancer = AssetRebalancer(assetRebalancerProxy);
        assetRebalancerProxyAdmin = Upgrades.getAdminAddress(
            assetRebalancerProxy
        );
        assetRebalancerImplimentation = Upgrades.getImplementationAddress(
            assetRebalancerProxy
        );

        assetFeeManagerProxy = Upgrades.deployTransparentProxy(
            "AssetFeeManager.sol",
            owner,
            abi.encodeCall(
                AssetFeeManager.initialize,
                (owner, assetFactoryProxy)
            )
        );
        assetFeeManager = AssetFeeManager(assetFeeManagerProxy);
        assetFeeManagerProxyAdmin = Upgrades.getAdminAddress(
            assetFeeManagerProxy
        );
        assetFeeManagerImplimentation = Upgrades.getImplementationAddress(
            assetFeeManagerProxy
        );
    }

    function test_UpgradeContracts() public {
        vm.startPrank(owner);

        // Upgrade Swap contract logic
        Options memory swapOptions;
        // swapOptions.referenceContract = "Swap.sol";
        swapOptions.unsafeSkipStorageCheck = true;

        Upgrades.upgradeProxy(swapProxy, "Swap.sol", new bytes(0), swapOptions);
        address newSwapLogic = Upgrades.getImplementationAddress(swapProxy);
        assertEq(Upgrades.getAdminAddress(swapProxy), swapProxyAdmin);
        assertFalse(swapImplimentation == newSwapLogic);

        // Upgrade AssetFactory contract logic
        Options memory factoryOptions;
        // factoryOptions.referenceContract = "AssetFactory.sol";
        factoryOptions.unsafeSkipStorageCheck = true;

        Upgrades.upgradeProxy(
            assetFactoryProxy,
            "AssetFactory.sol",
            new bytes(0),
            factoryOptions
        );
        address newAssetFactoryLogic = Upgrades.getImplementationAddress(
            assetFactoryProxy
        );
        assertEq(assetFactory.vault(), vault);
        assertEq(
            Upgrades.getAdminAddress(assetFactoryProxy),
            assetFactoryProxyAdmin
        );
        assertFalse(assetFactoryImplimentation == newAssetFactoryLogic);

        // Upgrade AssetIssuer contract logic
        Options memory issueOptions;
        // issueOptions.referenceContract = "AssetIssuer.sol";
        issueOptions.unsafeSkipStorageCheck = true;

        Upgrades.upgradeProxy(
            assetIssuerProxy,
            "AssetIssuer.sol",
            new bytes(0),
            issueOptions
        );
        address newAssetIssuerLogic = Upgrades.getImplementationAddress(
            assetIssuerProxy
        );
        assertEq(assetIssuer.owner(), owner);
        assertEq(
            Upgrades.getAdminAddress(assetIssuerProxy),
            assetIssuerProxyAdmin
        );
        assertFalse(assetIssuerImplimentation == newAssetIssuerLogic);

        // Upgrade AssetRebalancer contract logic
        Options memory rebalancerOptions;
        // rebalancerOptions.referenceContract = "AssetRebalancer.sol";
        rebalancerOptions.unsafeSkipStorageCheck = true;

        Upgrades.upgradeProxy(
            assetRebalancerProxy,
            "AssetRebalancer.sol",
            new bytes(0),
            rebalancerOptions
        );
        address newAssetRebalancerLogic = Upgrades.getImplementationAddress(
            assetRebalancerProxy
        );
        assertEq(
            Upgrades.getAdminAddress(assetRebalancerProxy),
            assetRebalancerProxyAdmin
        );
        assertFalse(assetRebalancerImplimentation == newAssetRebalancerLogic);

        // Upgrade AssetFeeManager contract logic
        Options memory feemanagerOptions;
        // feemanagerOptions.referenceContract = "AssetFeeManager.sol";
        feemanagerOptions.unsafeSkipStorageCheck = true;

        Upgrades.upgradeProxy(
            assetFeeManagerProxy,
            "AssetFeeManager.sol",
            new bytes(0),
            feemanagerOptions
        );
        address newAssetFeeManagerLogic = Upgrades.getImplementationAddress(
            assetFeeManagerProxy
        );
        assertEq(
            Upgrades.getAdminAddress(assetFeeManagerProxy),
            assetFeeManagerProxyAdmin
        );
        assertFalse(assetFeeManagerImplimentation == newAssetFeeManagerLogic);

        vm.stopPrank();
    }
}
