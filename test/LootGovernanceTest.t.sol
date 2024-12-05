// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/interfaces/IERC721.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LootGovernor, LootTimelock} from "../src/LootGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LootGovernanceTest is Test {
    LootGovernor public governor;
    LootTimelock public timelock;
    address public constant LOOT = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
    
    uint256 public constant MIN_DELAY = 3600; 
    uint256 public constant VOTING_DELAY = 7200; 
    uint256 public constant VOTING_PERIOD = 50400; 

    address public constant WHALE = 0x450638DaF0CAeDBdd9F8cb4A41Fa1b24788b123e;
    
    function setUp() public {        
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        
        
        LootTimelock timelockImpl = new LootTimelock();
        
        
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
        
        
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImpl),
            timelockInitData
        );
        
        
        timelock = LootTimelock(payable(address(timelockProxy)));
        
        
        LootGovernor implementation = new LootGovernor();

        
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
        governor = LootGovernor(payable(address(governorProxy)));
        
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
    }

    function testInitialization() public view {
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(address(governor.timelock()), address(timelock));
        assertEq(address(governor.loot()), LOOT); 
    }

    function testInitialSetup() public view {
        assertEq(governor.name(), "LootGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), 8);
        assertEq(governor.quorum(0), 155);
    }

    function testProposalThreshold() public view {
        assertEq(governor.proposalThreshold(), 8);
    }

    function testQuorum() public view {
        assertEq(governor.quorum(0), 155);
        assertEq(governor.quorum(100), 155); 
    }

    function testCreateProposal() public {
        // Mint some Loot NFTs to WHALE for testing
        vm.startPrank(WHALE);
        
        // We need to ensure WHALE has at least 1 Loot NFT to create proposal
        uint256 whaleBalance = IERC721(LOOT).balanceOf(WHALE);
        if(whaleBalance == 0) {
            // If WHALE doesn't have any Loot, we'll mint one
            // Note: This assumes there are unclaimed Loot tokens available
            uint256 tokenId = 1;
            while(tokenId < 7778) {
                try IERC721(LOOT).ownerOf(tokenId) {
                    tokenId++;
                    continue;
                } catch {
                    // Found an unclaimed token
                    (bool success,) = LOOT.call(
                        abi.encodeWithSignature("claim(uint256)", tokenId)
                    );
                    require(success, "Failed to claim Loot");
                    break;
                }
            }
        }
        
        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = LOOT;
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
        
        // Cast to proxy and upgrade
        (bool success,) = address(governor).call(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)", 
                address(newImplementation),
                ""
            )
        );
        require(success, "Upgrade failed");
        
        // Check implementation
        // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
        bytes32 implSlot = vm.load(
            address(governor),
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        );
        address currentImpl = address(uint160(uint256(implSlot)));
        assertEq(currentImpl, address(newImplementation));
    }

    function testFullProposalWorkflow() public {        
        vm.startPrank(WHALE);
                
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
                
        targets[0] = address(timelock);
        values[0] = 1 ether;
        calldatas[0] = ""; 
        
        string memory description = "Send 1 ETH to treasury";
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );
        
        
        uint256 votes = governor.getVotes(WHALE, block.number - 1);
        console.log("Whale voting power:", votes);
        
        
        vm.roll(block.number + governor.votingDelay() + 1);
        
        
        governor.castVote(proposalId, 1); 
        
        
        vm.roll(block.number + governor.votingPeriod() + 1);
        
        
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        
        vm.deal(address(timelock), 2 ether);
        
        
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        vm.stopPrank();
        
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }
}