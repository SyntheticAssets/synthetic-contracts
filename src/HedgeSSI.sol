// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
import './Interface.sol';
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

contract HedgeSSI is Ownable, ERC20 {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    enum HedgeOrderType { NONE, MINT, REDEEM }
    enum HedgeOrderStatus { NONE, PENDING, REJECTED, CONFIRMED }

    struct HedgeOrder {
        HedgeOrderType orderType;
        uint256 assetID;
        uint256 nonce;
        uint256 inAmount;
        uint256 outAmount;
        uint256 deadline;
        address requester;
    }

    EnumerableSet.Bytes32Set orderHashs;
    mapping(bytes32 => HedgeOrder) public hedgeOrders;
    mapping(bytes32 => HedgeOrderStatus) public orderStatus;
    mapping(bytes32 => uint256) public requestTimestamps;

    EnumerableSet.UintSet supportAssetIDs;

    address public redeemToken;
    address public orderSigner;
    address public factoryAddress;

    constructor(address owner, address orderSigner_, address factoryAddress_, address redeemToken_) Ownable(owner) ERC20("Hedged SSI", "hSSI") {
        require(factoryAddress_ != address(0), "zero factory address");
        require(redeemToken_ != address(0), "zero redeem token address");
        require(orderSigner_ != address(0), "zero order signer address");
        factoryAddress = factoryAddress_;
        redeemToken = redeemToken_;
        orderSigner = orderSigner_;
    }

    function decimals() public pure override(ERC20) returns (uint8) {
        return 8;
    }

    function getSupportAssetIDs() external view returns (uint256[] memory assetIDs) {
        assetIDs = new uint256[](supportAssetIDs.length());
        for (uint i = 0; i < assetIDs.length; i++) {
            assetIDs[i] = supportAssetIDs.at(i);
        }
    }

    function addSupportAsset(uint256 assetID) external onlyOwner {
        require(IAssetFactory(factoryAddress).hasAssetID(assetID), "asset not exists");
        require(!supportAssetIDs.contains(assetID), "already contains assetID");
        supportAssetIDs.add(assetID);
    }

    function updateOrderSigner(address orderSigner_) external onlyOwner {
        require(orderSigner_ != address(0), "orderSigner is zero address");
        require(orderSigner_ != orderSigner, "orderSigner not change");
        orderSigner = orderSigner_;
    }

    function updateRedeemToken(address redeemToken_) external onlyOwner {
        require(redeemToken_ != address(0), "redeem token is zero address");
        require(redeemToken_ != redeemToken, "redeem token not change");
        redeemToken = redeemToken_;
    }

    function removeSupportAsset(uint256 assetID) external onlyOwner {
        require(IAssetFactory(factoryAddress).hasAssetID(assetID), "asset not exists");
        require(supportAssetIDs.contains(assetID), "assetID is not supported");
        supportAssetIDs.remove(assetID);
    }

    function checkHedgeOrder(HedgeOrder calldata hedgeOrder, bytes32 orderHash, bytes calldata orderSignature) public view {
        if (hedgeOrder.orderType == HedgeOrderType.MINT) {
            require(supportAssetIDs.contains(hedgeOrder.assetID), "assetID not supported");
        }
        require(block.timestamp <= hedgeOrder.deadline, "expired");
        require(!orderHashs.contains(orderHash), "order already exists");
        require(SignatureChecker.isValidSignatureNow(orderSigner, orderHash, orderSignature), "signature not valid");
    }

    function applyMint(HedgeOrder calldata hedgeOrder, bytes calldata orderSignature) external {
        require(hedgeOrder.requester == msg.sender, "msg sender is not requester");
        bytes32 orderHash = keccak256(abi.encode(hedgeOrder));
        checkHedgeOrder(hedgeOrder, orderHash, orderSignature);
        require(hedgeOrder.orderType == HedgeOrderType.MINT, "order type not match");
        IERC20 assetToken = IERC20(IAssetFactory(factoryAddress).assetTokens(hedgeOrder.assetID));
        require(assetToken.allowance(hedgeOrder.requester, address(this)) >= hedgeOrder.inAmount, "not enough allowance");
        assetToken.safeTransferFrom(hedgeOrder.requester, address(this), hedgeOrder.inAmount);
        HedgeOrder storage hedgeOrder_ = hedgeOrders[orderHash];
        hedgeOrder_.orderType = hedgeOrder.orderType;
        hedgeOrder_.assetID = hedgeOrder.assetID;
        hedgeOrder_.nonce = hedgeOrder.nonce;
        hedgeOrder_.inAmount = hedgeOrder.inAmount;
        hedgeOrder_.outAmount = hedgeOrder.outAmount;
        hedgeOrder_.deadline = hedgeOrder.deadline;
        hedgeOrder_.requester = hedgeOrder.requester;
        orderHashs.add(orderHash);
        orderStatus[orderHash] = HedgeOrderStatus.PENDING;
        requestTimestamps[orderHash] = block.timestamp;
    }

    function rejectMint(bytes32 orderHash) external onlyOwner {
        require(orderHashs.contains(orderHash), "order not exists");
        require(orderStatus[orderHash] == HedgeOrderStatus.PENDING, "order is not pending");
        HedgeOrder storage hedgeOrder = hedgeOrders[orderHash];
        IERC20 assetToken = IERC20(IAssetFactory(factoryAddress).assetTokens(hedgeOrder.assetID));
        assetToken.transfer(hedgeOrder.requester, hedgeOrder.inAmount);
        orderStatus[orderHash] = HedgeOrderStatus.REJECTED;
    }

    function confirmMint(bytes32 orderHash) external onlyOwner {
        require(orderHashs.contains(orderHash), "order not exists");
        require(orderStatus[orderHash] == HedgeOrderStatus.PENDING, "order is not pending");
        HedgeOrder storage hedgeOrder = hedgeOrders[orderHash];
        _mint(hedgeOrder.requester, hedgeOrder.outAmount);
        orderStatus[orderHash] = HedgeOrderStatus.CONFIRMED;
        IERC20 assetToken = IERC20(IAssetFactory(factoryAddress).assetTokens(hedgeOrder.assetID));
        IAssetIssuer issuer = IAssetIssuer(IAssetFactory(factoryAddress).issuers(hedgeOrder.assetID));
        if (assetToken.allowance(address(this), address(issuer)) < hedgeOrder.inAmount) {
            assetToken.approve(address(issuer), type(uint256).max);
        }
        issuer.burnFor(hedgeOrder.assetID, hedgeOrder.inAmount);
    }

    function applyRedeem(HedgeOrder calldata hedgeOrder, bytes calldata orderSignature) external {
        require(hedgeOrder.requester == msg.sender, "msg sender is not requester");
        bytes32 orderHash = keccak256(abi.encode(hedgeOrder));
        checkHedgeOrder(hedgeOrder, orderHash, orderSignature);
        require(hedgeOrder.orderType == HedgeOrderType.REDEEM, "order type not match");
        require(allowance(hedgeOrder.requester, address(this)) >= hedgeOrder.inAmount, "not enough allowance");
        IERC20(address(this)).safeTransferFrom(hedgeOrder.requester, address(this), hedgeOrder.inAmount);
        HedgeOrder storage hedgeOrder_ = hedgeOrders[orderHash];
        hedgeOrder_.orderType = hedgeOrder.orderType;
        hedgeOrder_.assetID = hedgeOrder.assetID;
        hedgeOrder_.nonce = hedgeOrder.nonce;
        hedgeOrder_.inAmount = hedgeOrder.inAmount;
        hedgeOrder_.outAmount = hedgeOrder.outAmount;
        hedgeOrder_.deadline = hedgeOrder.deadline;
        hedgeOrder_.requester = hedgeOrder.requester;
        orderHashs.add(orderHash);
        orderStatus[orderHash] = HedgeOrderStatus.PENDING;
        requestTimestamps[orderHash] = block.timestamp;
    }

    function rejectRedeem(bytes32 orderHash) external onlyOwner {
        require(orderHashs.contains(orderHash), "order not exists");
        require(orderStatus[orderHash] == HedgeOrderStatus.PENDING, "order is not pending");
        HedgeOrder storage hedgeOrder = hedgeOrders[orderHash];
        transfer(hedgeOrder.requester, hedgeOrder.inAmount);
        orderStatus[orderHash] = HedgeOrderStatus.REJECTED;
    }

    function confirmRedeem(bytes32 orderHash) external onlyOwner {
        require(orderHashs.contains(orderHash), "order not exists");
        require(orderStatus[orderHash] == HedgeOrderStatus.PENDING, "order is not pending");
        HedgeOrder storage hedgeOrder = hedgeOrders[orderHash];
        IERC20(redeemToken).safeTransfer(hedgeOrder.requester, hedgeOrder.outAmount);
        _burn(address(this), hedgeOrder.inAmount);
        orderStatus[orderHash] = HedgeOrderStatus.CONFIRMED;
    }

    function getOrderHashs() external view returns (bytes32[] memory orderHashs_) {
        orderHashs_ = new bytes32[](orderHashs.length());
        for (uint i = 0; i < orderHashs.length(); i++) {
            orderHashs_[i] = orderHashs.at(i);
        }
    }

    function getOrderHashLength() external view returns (uint256) {
        return orderHashs.length();
    }

    function getOrderHash(uint256 nonce) external view returns (bytes32) {
        return orderHashs.at(nonce);
    }
}