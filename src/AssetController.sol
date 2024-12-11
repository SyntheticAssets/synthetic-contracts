// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import './Interface.sol';
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract AssetController is Ownable, Pausable, IAssetController {
    address public factoryAddress;

    constructor(address owner, address factoryAddress_) Ownable(owner) {
        require(factoryAddress_ != address(0), "factory is zero address");
        factoryAddress = factoryAddress_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function checkRequestOrderInfo(Request memory request, OrderInfo memory orderInfo) internal pure {
        require(request.orderHash == orderInfo.orderHash, "order hash not match");
        require(orderInfo.orderHash == keccak256(abi.encode(orderInfo.order)), "order hash invalid");
    }

    function rollbackSwapRequest(address swap, OrderInfo memory orderInfo) external onlyOwner {
        require(swap != address(0), "zero swap address");
        ISwap(swap).rollbackSwapRequest(orderInfo);
    }

    function cancelSwapRequest(address swap, OrderInfo memory orderInfo) external onlyOwner {
        require(swap != address(0), "zero swap address");
        ISwap(swap).cancelSwapRequest(orderInfo);
    }
}