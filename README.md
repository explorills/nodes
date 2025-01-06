# explorills_Nodes Contract

ERC721 cross-chain contract with whitelist functionality, dual-escrow system and backup address support

## General Functionality

1. Mints 12,000 unique ERC721 tokens
2. Features dual-escrow system (Nodes and cross-chain escrows)
3. Supports backup address functionality for enhanced security
4. Includes whitelist functionality for reserved minting
5. Enables cross-chain transfers and balance management
6. The Node Escrow automatically activates the pulling window once 1-10,800 Nodes have been minted

## Main Functions

* `mint`: Create new Nodes in the Node escrow
* `whitelistMint`: Reserved minting for whitelisted addresses
* `a2SetUpBackUpAddresses`: Assign additional owner addresses to the Nodes in Escrow
* `a3PullMyNodesFromEscrow`: Release Nodes from escrow to owner (minter or backup address)
* `a4ReceiveTnftFromUserToOtherChainsSupply`: Transfer Nodes to cross-chain escrow
* `a5SendTnftToUserFromOtherChainsSupply`: Receive Nodes on opposite network 

## Supply and Tiers

### Total Supply: 12,000 Nodes

* Maximum per address: 100 Nodes

* **Tier 1 (1-1,000)**
  - Starting Price: 1 USD
  - Price Step: +1 USD per 100 Nodes
* **Tier 2 (1,001-2,800)**
  - Starting Price: 15 USD
  - Price Step: +5 USD per 100 Nodes
* **Tier 3 (2,801-10,800)**
  - Starting Price: 110 USD
  - Price Step: +10 USD per 100 Nodes
* **Whitelist Reserve (10,801-12,000)**
  - 1,200 nodes reserved
  - Exclusive whitelist allocation

## Build and Deployment Settings
* Contract Name: explorills_Nodes
* Compiler Version: v0.8.24
* EVM Version: London
* Optimization: Enabled (200 runs)
* Networks: [Ethereum](https://ethereum.org/en/); [Flare](https://flare.network/)

## Contract Architecture
```
explorills_Nodes
├── Main Functions
│   ├── Minting Operations
│   │   ├── mint
│   │   ├── whitelistMint
│   │   └── safeBatchTransferFrom
│   ├── Backup System
│   │   ├── setUpBackUpAddresses
│   │   └── checkBackUpAddresses
│   ├── Pulling Operations
│   │   ├── pullMyNodesFromEscrow
│   │   └── setPullPaused
│   ├── Cross-chain Operations
│   │   ├── receiveTnftFromUserToOtherChainsSupply
│   │   └── sendTnftToUserFromOtherChainsSupply
│   └── Administrative
│       ├── setOneTimeNodeEscrow
│       ├── setOneTimeCrossChainEscrow
│       └── setCrossChainOperator
├── View Functions
│   ├── Price Information
│   │   ├── getCurrentPriceInUSD
│   │   └── getBatchPriceInUSD
│   ├── Escrow Status
│   │   ├── addressEscrowHoldings
│   │   ├── getEscrowTokens
│   │   └── remainingNodesToMint
│   ├── Supply Management
│   │   ├── getTotalCurrentSupply
│   │   └── totalSupply
│   └── Whitelist Information
│       ├── getWhitelistStatus
│       └── whitelistMintAllowance
└── Storage
    ├── Token Management
    │   ├── currentChainTnftSupply
    │   ├── otherChainsTnftSupply
    │   └── totalMintedCurrentChain
    ├── Escrow System
    │   ├── nodesEscrowAddress
    │   └── crossChainEscrowAddress
    └── Whitelist Management
        ├── whitelistAllowance
        └── hasWhitelistMinted
```

## License

BSD-3-Clause License

## Contact

- main: [explorills.com](https://explorills.com)
- mint: [mint.explorills.com](https://mint.explorills.com)
- contact: info@explorills.com
- security contact: info@explorills.ai

## Contract Address
### explorills_Nodes 
- 0x468F1F91fc674e0161533363B13c2ccBE3769981
### find at
- [Etherscan.io](https://etherscan.io/address/0x468F1F91fc674e0161533363B13c2ccBE3769981#code)
- [Flare-explorer](https://flare-explorer.flare.network/address/0x468F1F91fc674e0161533363B13c2ccBE3769981?tab=contract)

### explorills_NodesEscrow
- 0x9eAEc5DB08E0D243d07A82b8DD54Cc70E745f8b4
- Github: [explorills/node-escrow](https://github.com/explorills/node-escrow/tree/main)

### explorills_CrossChainEscrow
- 0x129D9dce2326492d073D147762230e60c01e0f97
- Github: [explorills/node-bridge-escrow](https://github.com/explorills/node-bridge-escrow/tree/main)
---

- explorills community 2024
