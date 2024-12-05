// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LootGovernor, LootTimelock} from "../src/LootGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract LootGovernanceTest is Test {
    LootGovernor public governor;
    LootTimelock public timelock;
    address public constant LOOT = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
    
    address[] public proposers;
    address[] public executors;
    
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // 1 day
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    address public constant WHALE = 0x450638DaF0CAeDBdd9F8cb4A41Fa1b24788b123e;
    
    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        
        // Deploy timelock
        timelock = new LootTimelock(
            MIN_DELAY,
            proposers,
            executors,
            address(this)
        );
        
        // Deploy implementation
        LootGovernor implementation = new LootGovernor();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            LootGovernor.initialize.selector,
            LOOT,
            address(timelock),
            VOTING_DELAY,
            VOTING_PERIOD,
            address(this)
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        governor = LootGovernor(address(proxy));
        
        // Setup roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, address(this));
    }

    function testInitialSetup() public {
        assertEq(governor.name(), "LootGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), 8);
        assertEq(governor.quorum(0), 155);
    }

    function testProposalThreshold() public {
        assertEq(governor.proposalThreshold(), 8);
    }

    function testQuorum() public {
        assertEq(governor.quorum(0), 155);
        assertEq(governor.quorum(100), 155); // Should be constant regardless of block number
    }

    function testCreateProposal() public {
        // Impersonate a whale account
        vm.startPrank(WHALE);
        
        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(LOOT);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transferOwnership(address)", address(this));
        
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Transfer ownership of Loot"
        );
        
        vm.stopPrank();
        
        assertGt(proposalId, 0);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function testUpgradeability() public {
        // Only owner can upgrade
        assertTrue(governor.owner() == address(this));
        
        // Deploy new implementation
        LootGovernor newImplementation = new LootGovernor();
        
        // Upgrade
        governor.upgradeTo(address(newImplementation));
        
        // Check implementation
        address currentImpl = vm.load(
            address(governor),
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        );
        assertEq(currentImpl, address(newImplementation));
    }

    function testFullProposalWorkflow() public {
        // Impersonate a whale account
        vm.startPrank(WHALE);
        
        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(LOOT);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transferOwnership(address)", address(this));
        
        string memory description = "Transfer ownership of Loot";
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );
        
        // Advance to voting period
        vm.roll(block.number + governor.votingDelay() + 1);
        
        // Cast vote
        governor.castVote(proposalId, 1); // Vote in favor
        
        // Advance to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);
        
        // Queue
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        // Advance time
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        
        // Execute
        governor.execute(targets, values, calldatas, descriptionHash);
        
        vm.stopPrank();
        
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }
}