// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorTimelockControlUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LootTimelock is TimelockControllerUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) public override initializer {
        __TimelockController_init(minDelay, proposers, executors, admin);
    }
}

contract LootGovernor is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorTimelockControlUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    // Using immutable for the Loot contract address can save gas
    IERC721 public immutable loot;
    
    // Constants for governance parameters
    uint256 public constant QUORUM_FIXED = 155; 
    uint256 public constant PROPOSAL_THRESHOLD = 8;

    // Cache storage variables to reduce gas costs
    uint32 private _votingDelay;
    uint32 private _votingPeriod;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC721 _loot) {
        _disableInitializers();
        loot = _loot; // Set immutable variable in constructor
    }

    function initialize(
        TimelockControllerUpgradeable _timelock,
        uint32 votingDelay_,
        uint32 votingPeriod_,
        address initialOwner
    ) public initializer {
        __Governor_init("LootGovernor");
        __GovernorSettings_init(
            votingDelay_,
            votingPeriod_,
            PROPOSAL_THRESHOLD
        );
        __GovernorCountingSimple_init();
        __GovernorTimelockControl_init(_timelock);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        
        // Cache values
        _votingDelay = votingDelay_;
        _votingPeriod = votingPeriod_;
    }

    // Using blocknumber for voting periods is more gas efficient than timestamps
    function clock() public view virtual override returns (uint48) {
        return uint48(block.number);
    }

    function CLOCK_MODE() public pure virtual override returns (string memory) {
        return "mode=blocknumber";
    }

    function votingDelay()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return _votingDelay;
    }

    function votingPeriod()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return _votingPeriod;
    }

    // Using a constant return value is more gas efficient
    function quorum(uint256)
        public
        pure
        override(GovernorUpgradeable)
        returns (uint256)
    {
        return QUORUM_FIXED;
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    // Using a constant return value is more gas efficient
    function proposalThreshold()
        public
        pure
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return PROPOSAL_THRESHOLD;
    }

    // Simplified voting power calculation - 1 Loot NFT = 1 vote
    function _getVotes(
        address account,
        uint256,
        bytes memory
    ) internal view virtual override returns (uint256) {
        return loot.balanceOf(account);
    }

    // Always return true to ensure proposals go through timelock
    function proposalNeedsQueuing(uint256)
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return true;
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyOwner
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(GovernorUpgradeable)  
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}