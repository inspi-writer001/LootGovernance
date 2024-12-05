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
    
    // Contract instances
    LootTimelock public timelock;
    LootGovernor public governor;
    uint256 public startGas;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        startGas = gasleft();
    }

    function deployTimelock() internal returns (LootTimelock) {
        // Deploy Timelock implementation
        LootTimelock timelockImpl = new LootTimelock();
        
        // Prepare initialization data
        address[] memory initialProposers = new address[](0);
        address[] memory initialExecutors = new address[](1);
        initialExecutors[0] = address(0);
        
        bytes memory timelockInitData = abi.encodeWithSelector(
            LootTimelock.initialize.selector,
            MIN_DELAY,
            initialProposers,
            initialExecutors,
            address(this)
        );
        
        // Deploy and initialize proxy
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImpl),
            timelockInitData
        );
        
        console.log("Timelock Implementation:", address(timelockImpl));
        console.log("Timelock Proxy:", address(timelockProxy));
        
        return LootTimelock(payable(address(timelockProxy)));
    }

    function deployGovernor(LootTimelock _timelock) internal returns (LootGovernor) {
        // Deploy implementation
        LootGovernor implementation = new LootGovernor();

        bytes memory governorInitData = abi.encodeWithSelector(
            LootGovernor.initialize.selector,
            LOOT,
            _timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            address(this)
        );

        // Deploy and initialize proxy
        ERC1967Proxy governorProxy = new ERC1967Proxy(
            address(implementation),
            governorInitData
        );
        
        console.log("Governor Implementation:", address(implementation));
        console.log("Governor Proxy:", address(governorProxy));
        
        return LootGovernor(payable(address(governorProxy)));
    }

    function setupRoles(LootTimelock _timelock, LootGovernor _governor) internal {
        bytes32 proposerRole = _timelock.PROPOSER_ROLE();
        bytes32 executorRole = _timelock.EXECUTOR_ROLE();
        bytes32 adminRole = _timelock.DEFAULT_ADMIN_ROLE();

        _timelock.grantRole(proposerRole, address(_governor));
        _timelock.grantRole(executorRole, address(0));
        _timelock.revokeRole(adminRole, address(this));
    }

    function logDeploymentCosts() internal {
        uint256 gasUsed = startGas - gasleft();
        uint256 gasPrice = block.basefee;
        uint256 totalCostWei = gasUsed * gasPrice;
        uint256 totalCostEth = totalCostWei / 1e18;

        console.log("Gas Used for Deployment:", gasUsed);
        console.log("Current Gas Price (wei):", gasPrice);
        console.log("Total Cost (wei):", totalCostWei);
        console.log("Total Cost (ETH):", totalCostEth);
    }

    function testDeploymentCost() public {
        // Deploy contracts
        timelock = deployTimelock();
        governor = deployGovernor(timelock);
        
        // Setup roles
        setupRoles(timelock, governor);
        
        // Log costs
        logDeploymentCosts();

        // Verify setup
        assertEq(address(governor.loot()), LOOT);
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(address(governor.timelock()), address(timelock));
    }
}