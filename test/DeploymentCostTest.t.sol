// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {LootGovernor, LootTimelock} from "../src/LootGovernor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

contract DeploymentCostTest is Test {
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week
    address public constant LOOT = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function testDeploymentCost() public {
        // Start tracking gas
        uint256 startGas = gasleft();

        // Deploy Timelock implementation
        LootTimelock timelockImpl = new LootTimelock();
        
        // Prepare timelock initialization data
        address[] memory initialProposers = new address[](0);
        address[] memory initialExecutors = new address[](1);
        initialExecutors[0] = address(0); // Allow anyone to execute
        
        bytes memory timelockInitData = abi.encodeWithSelector(
            LootTimelock.initialize.selector,
            MIN_DELAY,
            initialProposers,
            initialExecutors,
            address(this)
        );
        
        // Deploy timelock proxy
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImpl),
            timelockInitData
        );
        
        // Cast proxy to timelock
        LootTimelock timelock = LootTimelock(payable(address(timelockProxy)));
        
        // Deploy governor implementation
        LootGovernor implementation = new LootGovernor();

        // Prepare governor initialization data
        bytes memory governorInitData = abi.encodeWithSelector(
            LootGovernor.initialize.selector,
            LOOT,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            address(this)
        );

        // Deploy governor proxy
        ERC1967Proxy governorProxy = new ERC1967Proxy(
            address(implementation),
            governorInitData
        );
        
        // Cast proxy to governor
        LootGovernor governor = LootGovernor(payable(address(governorProxy)));
        
        // Setup roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // Grant governor the proposer role
        timelock.grantRole(proposerRole, address(governor));
        // Grant everyone executor role
        timelock.grantRole(executorRole, address(0));
        // Renounce admin role
        timelock.revokeRole(adminRole, address(this));

        // Calculate total gas used
        uint256 gasUsed = startGas - gasleft();

        // Get current gas price from mainnet fork
        uint256 gasPrice = block.basefee;
        
        // Calculate total cost in ETH
        uint256 totalCostWei = gasUsed * gasPrice;
        uint256 totalCostEth = totalCostWei / 1e18;

        console.log("Gas Used for Deployment:", gasUsed);
        console.log("Current Gas Price (wei):", gasPrice);
        console.log("Total Cost (wei):", totalCostWei);
        console.log("Total Cost (ETH):", totalCostEth);
        
        // Log contract addresses
        console.log("\nDeployed Contracts:");
        console.log("Timelock Implementation:", address(timelockImpl));
        console.log("Timelock Proxy:", address(timelockProxy));
        console.log("Governor Implementation:", address(implementation));
        console.log("Governor Proxy:", address(governorProxy));

        // Test basic governor setup
        assertEq(address(governor.loot()), LOOT);
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(address(governor.timelock()), address(timelock));
    }
}