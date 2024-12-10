// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/console.sol";



contract ChristmasAirdrop is Ownable, ReentrancyGuard {

    bytes32 public merkleRoot;
    mapping(address => mapping(address => bool)) public hasClaimed;

    event AirdropClaimed(address indexed claimant, address indexed token, uint256 amount);
    event MerkleRootUpdated(bytes32 indexed newMerkleRoot);
    event TokensWithdrawn(address indexed token, uint256 amount);

    constructor(bytes32 _merkleRoot) Ownable(msg.sender) {
        merkleRoot = _merkleRoot;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    function claimAirdrop(address token, uint256 amount, bytes32[] calldata proof) external nonReentrant {
        require(!hasClaimed[msg.sender][token], "Airdrop already claimed for this token");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, token, amount));
        // 验证 Merkle 证明
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Merkle Proof");
        hasClaimed[msg.sender][token] = true;
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed");
        emit AirdropClaimed(msg.sender, token, amount);
    }

    function batchAirdrop(
        address[] calldata recipients,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external onlyOwner nonReentrant {
        require(
            recipients.length == tokens.length &&
            recipients.length == amounts.length &&
            recipients.length == proofs.length,
            "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            address token = tokens[i];
            uint256 amount = amounts[i];
            bytes32[] calldata proof = proofs[i];

            if (!hasClaimed[recipient][token]) {
                bytes32 leaf = keccak256(abi.encodePacked(recipient, token, amount));
                if (MerkleProof.verify(proof, merkleRoot, leaf)) {
                    hasClaimed[recipient][token] = true;
                    require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
                    emit AirdropClaimed(recipient, token, amount);
                }
            }
        }
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(amount <= balance, "Insufficient token balance");
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed");
        emit TokensWithdrawn(token, amount);
    }
    
}