// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {LootGovernor, LootTimelock} from "../src/LootGovernor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLootGovernance is Script {
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week
    address public constant LOOT = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        LootTimelock timelock = new LootTimelock();
        timelock.initialize(
            MIN_DELAY,
            proposers,
            executors,
            deployer
        );

        // Deploy Implementation
        LootGovernor implementation = new LootGovernor();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            LootGovernor.initialize.selector,
            LOOT,
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            deployer
        );

        // Deploy Proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        LootGovernor governor = LootGovernor(payable(address(proxy)));

        // Setup roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();  

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, deployer);

        console2.log("Timelock deployed to:", address(timelock));
        console2.log("Governor Implementation deployed to:", address(implementation));
        console2.log("Governor Proxy deployed to:", address(proxy));

        vm.stopBroadcast();
    }
}