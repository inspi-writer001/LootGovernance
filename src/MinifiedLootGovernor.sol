// File: MockLoot.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockLoot is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 8000;

    constructor() ERC721("Mock Loot", "MLOOT") Ownable(msg.sender) {
        _tokenIdCounter = 1;
    }

    function mint(address to) external {
        require(_tokenIdCounter <= MAX_SUPPLY, "Max supply reached");
        _safeMint(to, _tokenIdCounter++);
    }

    function mintMultiple(address to, uint256 amount) external {
        require(
            _tokenIdCounter + amount - 1 <= MAX_SUPPLY,
            "Would exceed max supply"
        );
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, _tokenIdCounter++);
        }
    }
}

// File: LootTimelock.sol

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract LootTimelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}

// File: LootGovernor.sol

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract LootGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorTimelockControl
{
    IERC721 public immutable loot;
    uint256 public QUORUM_FIXED;
    uint256 public minNFTsRequired;

    constructor(
        IERC721 _loot,
        TimelockController _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum,
        uint256 _minNFTsRequired
    )
        Governor("LootGovernor")
        GovernorSettings(
            uint48(_votingDelay),
            uint32(_votingPeriod),
            _proposalThreshold
        )
        GovernorTimelockControl(_timelock)
    {
        QUORUM_FIXED = _quorum;
        loot = _loot;
        minNFTsRequired = _minNFTsRequired;
    }

    function clock() public view virtual override returns (uint48) {
        return uint48(block.number);
    }

    function CLOCK_MODE() public pure virtual override returns (string memory) {
        return "mode=blocknumber";
    }

    function quorum(uint256) public view override returns (uint256) {
        return QUORUM_FIXED;
    }

    function _getVotes(
        address account,
        uint256,
        bytes memory
    ) internal view override returns (uint256) {
        return loot.balanceOf(account);
    }

    function updateMinNFTsRequired(uint256 newMin) external onlyGovernance {
        minNFTsRequired = newMin;
    }

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            super._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
