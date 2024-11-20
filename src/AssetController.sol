// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract AssetController is
    Initializable,
    OwnableUpgradeable,
    IAssetController,
    AccessControlUpgradeable
{
    address public factoryAddress;

    /// @dev 替代构造函数的初始化函数
    function _initialize(address owner, address factoryAddress_) internal {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        transferOwnership(owner);
        factoryAddress = factoryAddress_;
    }

    function checkRequestOrderInfo(
        Request memory request,
        OrderInfo memory orderInfo
    ) internal pure {
        require(
            request.orderHash == orderInfo.orderHash,
            "order hash not match"
        );
        require(
            orderInfo.orderHash == keccak256(abi.encode(orderInfo.order)),
            "order hash invalid"
        );
    }

    function rollbackSwapRequest(
        OrderInfo memory orderInfo
    ) external onlyOwner {
        ISwap(IAssetFactory(factoryAddress).swap()).rollbackSwapRequest(
            orderInfo
        );
    }
}
