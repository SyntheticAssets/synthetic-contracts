// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import "./Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AssetToken} from "./AssetToken.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";

import {Options} from "../lib/openzeppelin-foundry-upgrades/src/Options.sol";

contract AssetFactory is Initializable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.UintSet private assetIDs;
    mapping(uint => address) public assetTokens;

    mapping(uint => address) public issuers;
    mapping(uint => address) public rebalancers;
    mapping(uint => address) public feeManagers;

    address public swap;
    address public vault;
    string public chain;

    event AssetTokenCreated(address indexed assetTokenAddress);
    event SetVault(address indexed vault);
    event SetSwap(address indexed swap);
    event UpgradeAssetToken(
        uint indexed assetID,
        address indexed newImplementation
    );

    /**
     * @dev 初始化函数，代替构造函数
     */
    function initialize(
        address owner,
        address swap_,
        address vault_,
        string memory chain_
    ) public initializer {
        __Ownable_init(msg.sender);
        require(swap_ != address(0), "Swap address is zero");
        require(vault_ != address(0), "Vault address is zero");
        swap = swap_;
        vault = vault_;
        chain = chain_;
        transferOwnership(owner);
        emit SetVault(vault);
        emit SetSwap(swap);
    }

    /**
     * @dev 设置 Swap 地址
     */
    function setSwap(address swap_) external onlyOwner {
        require(swap_ != address(0), "Swap address is zero");
        swap = swap_;
        emit SetSwap(swap);
    }

    /**
     * @dev 设置 Vault 地址
     */
    function setVault(address vault_) external onlyOwner {
        require(vault_ != address(0), "Vault address is zero");
        vault = vault_;
        emit SetVault(vault);
    }

    function createAssetToken(
        Asset memory asset,
        uint maxFee,
        address issuer,
        address rebalancer,
        address feeManager
    ) external onlyOwner returns (address) {
        require(
            issuer != address(0) &&
                rebalancer != address(0) &&
                feeManager != address(0),
            "Controllers not set"
        );
        require(!assetIDs.contains(asset.id), "Asset exists");

        Options memory options;
        options.unsafeSkipProxyAdminCheck = true;
        address assetTokenProxy = Upgrades.deployTransparentProxy(
            "AssetToken.sol",
            address(this),
            abi.encodeCall(
                AssetToken.initialize,
                (asset.id, asset.name, asset.symbol, maxFee, address(this))
            ),
            options
        );

        // 配置角色和初始状态
        AssetToken assetToken = AssetToken(assetTokenProxy);
        assetToken.grantRole(assetToken.ISSUER_ROLE(), issuer);
        assetToken.grantRole(assetToken.REBALANCER_ROLE(), rebalancer);
        assetToken.grantRole(assetToken.FEEMANAGER_ROLE(), feeManager);
        assetToken.initTokenset(asset.tokenset);

        assetTokens[asset.id] = address(assetToken);
        issuers[asset.id] = issuer;
        rebalancers[asset.id] = rebalancer;
        feeManagers[asset.id] = feeManager;
        assetIDs.add(asset.id);

        emit AssetTokenCreated(address(assetToken));
        return address(assetToken);
    }

    /**
     * @dev 检查资产 ID 是否存在
     */
    function hasAssetID(uint assetID) external view returns (bool) {
        return assetIDs.contains(assetID);
    }

    /**
     * @dev 获取所有资产 ID
     */
    function getAssetIDs() external view returns (uint[] memory) {
        return assetIDs.values();
    }

    function upgradeAssetToken(
        uint assetID,
        string memory newImpName
    )
        external
        onlyOwner
        returns (
            address oldImplementation,
            address newImplementation,
            address oldProxyAdmin,
            address newProxyAdmin
        )
    {
        address proxy = assetTokens[assetID];
        oldImplementation = Upgrades.getImplementationAddress(proxy);
        oldProxyAdmin = Upgrades.getAdminAddress(proxy);

        Options memory assettokenOptions;
        assettokenOptions.unsafeSkipStorageCheck = true;

        Upgrades.upgradeProxy(
            proxy,
            newImpName,
            new bytes(0),
            assettokenOptions
        );
        newImplementation = Upgrades.getImplementationAddress(proxy);
        newProxyAdmin = Upgrades.getAdminAddress(proxy);

        emit UpgradeAssetToken(assetID, newImplementation);
        return (
            oldImplementation,
            newImplementation,
            oldProxyAdmin,
            newProxyAdmin
        );
    }
}
