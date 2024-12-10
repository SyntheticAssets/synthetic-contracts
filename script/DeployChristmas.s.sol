// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ChristmasAirdrop.sol";
import "../src/Utils.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract DeployScript is Script {
    function run() external {
        // 设置
        address[] memory recipients = new address[](3);
        recipients[0] = 0x1234567890123456789012345678901234567890;
        recipients[1] = 0x2345678901234567890123456789012345678901;
        recipients[2] = 0x3456789012345678901234567890123456789012;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 10**18;
        amounts[1] = 200 * 10**18;
        amounts[2] = 300 * 10**18;

        address[] memory tokens = new address[](3);
        tokens[0] = 0x2345678901234567890123456789012345678901;
        tokens[1] = 0x2345678901234567890123456789012345678901;
        tokens[2] = 0x2345678901234567890123456789012345678901;

        bytes32[] memory leaves = new bytes32[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(recipients[i], tokens[i], amounts[i]));
        }
        bytes32 merkleRoot = Utils.getMerkleRoot(leaves);
        // 保存数据
        string[] memory recipientsStr = new string[](recipients.length);
        string[] memory amountsStr = new string[](amounts.length);
        string[] memory tokensStr = new string[](tokens.length);
        string[] memory leavesStr = new string[](leaves.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            recipientsStr[i] = vm.toString(recipients[i]);
            amountsStr[i] = vm.toString(amounts[i]);
            tokensStr[i] = vm.toString(tokens[i]);
            leavesStr[i] = vm.toString(leaves[i]);
        }
        string memory jsonData = vm.serializeString("data", "recipients", recipientsStr);
        jsonData = vm.serializeString("data", "amounts", amountsStr);
        jsonData = vm.serializeString("data", "tokens", tokensStr);
        jsonData = vm.serializeString("data", "leaves", leavesStr);

        vm.writeJson(jsonData, "./output/data.json");

        // 部署
        vm.startBroadcast();
        ChristmasAirdrop airdrop = new ChristmasAirdrop(merkleRoot);
        vm.stopBroadcast();

        // 为合约提供代币
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(airdrop), amounts[i]);
            IERC20(tokens[i]).transfer(address(airdrop), amounts[i]);
        }

        console.log("ChristmasAirdrop deployed at:", address(airdrop));
    }
}