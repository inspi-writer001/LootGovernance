# LootGovernor - Governance System for Loot NFT Holders

LootGovernor is a governance system that enables Loot NFT holders to participate in decentralized decision-making. The system uses a timelock mechanism for security and is upgradeable using the UUPS (Universal Upgradeable Proxy Standard) pattern.

## Overview

The governance system consists of three main components:

1. **LootGovernor**: The main governance contract that handles proposals and voting
2. **LootTimelock**: A timelock controller that enforces a delay before executing approved proposals
3. **Proxy**: An ERC1967 proxy that enables upgradeability

## Key Features

- **Voting Power**: Based on Loot NFT holdings (1 NFT = 1 vote)
- **Proposal Threshold**: 8 Loot NFTs required to create proposals
- **Quorum**: 155 votes required for proposal to pass
- **Timelock**: 1 hour delay before execution
- **Voting Period**: 1 week
- **Voting Delay**: 1 day after proposal creation before voting starts

## Deployment Instructions

1. Create a `.env` file with your private key:
```env
PRIVATE_KEY=your_private_key_here
RPC_URL=your_ethereum_rpc_url
```

2. Deploy using Foundry:
```bash
forge script script/DeployLootGovernance.s.sol:DeployLootGovernance \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

3. Save the deployed addresses that are output in the console:
- Timelock address
- Governor Implementation address
- Governor Proxy address

## Creating Proposals

Holders of at least 8 Loot NFTs can create proposals:

```solidity
governor.propose(
    targets,     // Array of target addresses
    values,      // Array of ETH values
    calldatas,   // Array of function calls
    description  // Proposal description
);
```

## Voting Process

1. After proposal creation, there's a 1-day delay before voting starts
2. Voting period lasts 1 week
3. Quorum of 155 votes needed
4. Each Loot NFT counts as 1 vote
5. Voting options: For (1), Against (0), or Abstain (2)

## Timelock Execution

If a proposal passes:
1. It must be queued in the timelock
2. After 1 hour delay, anyone can execute the proposal

## Contract Upgradeability

The system is upgradeable using the UUPS pattern. Only the contract owner can perform upgrades.

### How to Upgrade

1. Deploy new implementation:
```solidity
LootGovernor newImplementation = new LootGovernor();
```

2. Call upgrade on the proxy:
```solidity
// Through the proxy
governor.upgradeToAndCall(
    address(newImplementation),
    ""  // No initialization data needed
);
```

### Security Considerations

- Upgrades can only be performed by the owner
- The owner should be a secure multisig or DAO
- All upgrades should be thoroughly tested
- Consider using a timelock for upgrades

## Contract Verification

After deployment, verify your contracts on Etherscan:
```bash
forge verify-contract \
    --chain-id 1 \
    --compiler-version v0.8.19 \
    CONTRACT_ADDRESS \
    src/LootGovernor.sol:LootGovernor \
    YOUR_ETHERSCAN_API_KEY
```

## Important Notes

- Keep track of the proxy address - this is the main address to interact with
- The implementation contract should not receive any funds
- All interactions should be through the proxy
- Test thoroughly before upgrading
- Consider using a multisig as the owner for added security

## Roles

- **Owner**: Can upgrade the contract
- **Proposers**: Loot holders with ≥ 8 NFTs
- **Voters**: Any Loot holder
- **Executors**: Anyone can execute passed proposals
- **Timelock Admin**: Renounced after setup

## Technical Specifications

- Solidity Version: ^0.8.19
- Framework: Foundry
- Dependencies: OpenZeppelin Contracts Upgradeable 4.8.0
- Network: Ethereum Mainnet
- Loot Contract: 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7

## Security

- All functions are protected against reentrancy
- Timelock adds security by delaying execution
- Upgrades are restricted to owner only
- Critical functions are protected by access control