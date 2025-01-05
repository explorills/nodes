    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
    import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

    /**
     * ORIGINAL AUTHOR INFORMATION:
     * 
     * @author explorills community 2024
     * @custom:web https://explorills.com
     * @custom:contact info@explorills.com
     * @custom:security-contact info@explorills.ai
     * @custom:repository https://github.com/explorills/nodes
     * @title explorills_Nodes
     * @dev ERC721 cross-chain contract for 12,000 tokens with tiered pricing, whitelist functionality, and dual-escrow system (Nodes and cross-chain escrows) with backup address support
     * 
     * Contract redistribution or modification:
     * 
     * 1. Any names or terms related to "explorills," "EXPL_NODE," or their variations, cannot be used in any modified version's contract names, variables, or promotional materials without permission.
     * 2. The original author information (see above) must remain intact in all versions.
     * 3. In case of redistribution/modification, new author details must be added in the section below:
     * 
     * REDISTRIBUTED/MODIFIED BY:
     * 
     * /// @custom:redistributed-by <name or entity>
     * /// @custom:website <website of the redistributor>
     * /// @custom:contact <contact email or info of the redistributor>
     * 
     * Redistribution and use in source and binary forms, with or without modification, are permitted under the 3-Clause BSD License. 
     * This license allows for broad usage and modification, provided the original copyright notice and disclaimer are retained.
     * The software is provided "as-is," without any warranties, and the original authors are not liable for any issues arising from its use.
     */

    /// @author explorills community 2024
    /// @custom:web https://explorills.com
    /// @custom:contact info@explorills.com
    /// @custom:security-contact info@explorills.ai
    /// @custom:repository https://github.com/explorills/nodes
    contract explorills_Nodes is ERC721, Ownable, ReentrancyGuard {
        uint256 public constant TOTAL_SUPPLY = 12000;
        uint256 public constant MAX_PER_ADDRESS = 100;
        uint256 public constant MAX_TOKENS_PER_WALLET = 100;
        uint256 private constant MAX_PER_TRANSACTION = 100;
        
        uint256 private constant PRICE_STEP_SIZE = 100;
        uint256 private constant TIER1_END = 1000;
        uint256 private constant TIER2_END = 2800;
        uint256 private constant TIER3_END = 10800;

        uint256 private constant TIER1_START_PRICE = 1;
        uint256 private constant TIER1_STEP = 1;
        uint256 private constant TIER2_START_PRICE = 15;
        uint256 private constant TIER2_STEP = 5;
        uint256 private constant TIER3_START_PRICE = 110;
        uint256 private constant TIER3_STEP = 10;

        uint256 public a1CurrentChainTnftSupply;
        uint256 public a2OtherChainsTnftSupply;
        uint256 public a4TotalMintedCurrentChain;

        bool public nodeEscrowSet;
        bool public crossChainEscrowSet;
        address public crossChainOperator;

        bool public paused;
        bool public whitelistPaused;
        
        string public baseURI;
        string public constant baseExtension = ".json";
        uint256 private eventCounter;
        bool public pullPaused;
        bool public isWhitelistNetwork;

        uint256 public whitelistMintedCount;
        bool public whitelistInitialized; 
        uint256 public totalWhitelistAllocation;  
        address public migrationContract;

        address public nodesEscrowAddress;
        address public crossChainEscrowAddress;
        address public signerPublicKey;


        // mappings
        mapping(address => uint256) public addressMintCount;
        mapping(bytes32 => bool) private usedSignatures;
        mapping(address => MintRange[]) private minterRanges;
        mapping(address => address[2]) public backupAddresses;
        mapping(address => bool[2]) public backupAddressSlots;
        mapping(address => address) public backupToMinter;
        mapping(uint256 => bool) private _receiveEventEmitted;
        mapping(uint256 => EventDetails) private eventDetails;
        mapping(address => uint256) public whitelistAllowance;
        mapping(address => bool) public hasWhitelistMinted;   
        
        // structs
        struct EventDetails {
            address user;
            uint256[] tokenIds;
            uint256 txAmount;
        }

        struct MintRange {
            uint256 startId;
            uint256 count;
        }

        struct MintParams {
            uint256 otherChainQty; 
            uint256 mintAmount;
            uint256 timestamp;
            string randomNonce;
            bytes signature;
        }

        struct AddressInfoHelper {
            address queryAddress;
            string status;
            address[] relatedAddresses;
            string[] relatedTypes;
            uint256[] tokens;
            bool isPulled;
        }

        struct WhitelistStatus {
            bool isWhitelisted;
            bool hasMinted;
            uint256 eligibleQuantity;
        }

        // errors
        error MigrationPaused();
        error NotMigrationContract();
        error NoTokensToMigrate();

        error NodeEscrowAlreadySet();
        error CrossChainEscrowAlreadySet();

        // events
        event BackupAddressSet(address indexed minter, address indexed backupAddress, uint8 slot);
        event NodesPulled(address indexed receiver, uint256[] tokenIds);
        event MintListener(
            address indexed user,
            uint256 startId,
            uint256 endId,
            uint256 mintedAmount,
            uint256 otherChainQty
        );
        event a4ReceiveTnftFromUserToOtherChainsSupplyListener(
            address indexed user,
            uint256[] tokenIds,
            uint256 txAmount,
            uint256 eventId
        );
        event BatchBurned(address indexed burner, uint256[] tokenIds, uint256 totalAmount);
        event CrossChainTransferCompleted(
            address indexed recipient,
            uint256 startId,
            uint256 endId,
            uint256 totalAmount
        );    
        event WhitelistMinted(address indexed minter, uint256 startId, uint256 quantity);    


        constructor(
            bool _isWhitelistNetwork,
            address _signerPublicKey,
            address _crossChainOperator,
            string memory initialBaseURI
        ) ERC721("explorills Nodes", "EXPL_NODE") Ownable(msg.sender) {
            require(_signerPublicKey != address(0), "Invalid signer");
            require(_crossChainOperator != address(0), "Invalid cross chain operator");
            
            signerPublicKey = _signerPublicKey;
            crossChainOperator = _crossChainOperator;
            setBaseURI(initialBaseURI);
            isWhitelistNetwork = _isWhitelistNetwork;

            paused = true;
            whitelistPaused = true;
            pullPaused = true;

            if (!_isWhitelistNetwork) {
                uint256 reservedAmount = TOTAL_SUPPLY - TIER3_END;
                a2OtherChainsTnftSupply = reservedAmount;
            }
        }

        // functions
        function setOneTimeNodeEscrow(address _nodesEscrowAddress) external onlyOwner {
            if (nodeEscrowSet) revert NodeEscrowAlreadySet();

            nodesEscrowAddress = _nodesEscrowAddress;
            nodeEscrowSet = true;
        }

        function setOneTimeCrossChainEscrow(address _crossChainEscrowAddress) external onlyOwner {
            if (crossChainEscrowSet) revert CrossChainEscrowAlreadySet();

            crossChainEscrowAddress = _crossChainEscrowAddress;
            crossChainEscrowSet = true;
        }


        function setCrossChainOperator(address _crossChainOperator) external onlyOwner {
            crossChainOperator = _crossChainOperator;
        }

        function initializeWhitelist(
            address[] calldata addresses,
            uint256[] calldata quantities
        ) external onlyOwner {
            require(isWhitelistNetwork, "Not a whitelist network");
            require(!whitelistInitialized, "Whitelist already initialized");
            require(addresses.length == quantities.length, "Array length mismatch");
            
            uint256 batchTotal = 0;
            for (uint256 i = 0; i < addresses.length; i++) {
                require(addresses[i] != address(0), "Invalid address");
                require(quantities[i] > 0, "Invalid quantity");
                require(quantities[i] <= MAX_TOKENS_PER_WALLET, "Exceeds max per wallet");
                require(whitelistAllowance[addresses[i]] == 0, "Address already whitelisted");
                
                batchTotal += quantities[i];
                whitelistAllowance[addresses[i]] = quantities[i];
            }
            
            totalWhitelistAllocation += batchTotal;
            require(totalWhitelistAllocation <= 1200, "Exceeds reserved amount");
        }

        function finalizeWhitelistInitialization() external onlyOwner {
            require(!whitelistInitialized, "Already finalized");
            whitelistInitialized = true;
        }

        function getCurrentPriceInUSD(uint256 nodeId) public pure returns (uint256) {
            require(nodeId > 0 && nodeId <= TIER3_END, "Invalid Node ID");
            
            if (nodeId <= TIER1_END) {
                uint256 step = (nodeId - 1) / PRICE_STEP_SIZE;
                return TIER1_START_PRICE + (step * TIER1_STEP);
            } else if (nodeId <= TIER2_END) {
                uint256 step = (nodeId - TIER1_END - 1) / PRICE_STEP_SIZE;
                return TIER2_START_PRICE + (step * TIER2_STEP);
            } else {
                uint256 step = (nodeId - TIER2_END - 1) / PRICE_STEP_SIZE;
                return TIER3_START_PRICE + (step * TIER3_STEP);
            }
        }

        function getBatchPriceInUSD(uint256 startId, uint256 endId) public pure returns (uint256) {
            require(startId > 0 && endId <= TIER3_END && startId <= endId, "Invalid range");
            
            uint256 totalPrice = 0;
            for (uint256 i = startId; i <= endId; i++) {
                totalPrice += getCurrentPriceInUSD(i);
            }
            return totalPrice;
        }

        function _baseURI() internal view virtual override returns (string memory) {
            return baseURI;
        }

        function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
            string memory currentBaseURI = _baseURI();
            return bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, Strings.toString(tokenId), baseExtension))
                : "";
        }  
                
        function setBaseURI(string memory _newBaseURI) public onlyOwner {
            baseURI = _newBaseURI;
        }

        function a2SetUpBackUpAddresses(address backup1Address, address backup2Address) external {
            require(minterRanges[msg.sender].length > 0, "Only minters can set backup addresses");
            
            (uint256[] memory tokens, bool allPulled) = getEscrowTokens(msg.sender);
            require(!allPulled, "Nodes are already pulled from escrow");
            require(tokens.length > 0, "No nodes found in escrow");

            require(backup1Address != address(0) || backup2Address != address(0), 
                "At least one backup address required");
            require(backup1Address != msg.sender && backup2Address != msg.sender,
                "Cannot set self as backup");
            require(backup1Address == address(0) || backup1Address != backup2Address,
                "Cannot use same address for both slots");

            if (backup1Address != address(0)) {
                require(!backupAddressSlots[msg.sender][0], "Backup slot 1 is already set");
            }
            if (backup2Address != address(0)) {
                require(!backupAddressSlots[msg.sender][1], "Backup slot 2 is already set");
            }

            if (backup1Address != address(0)) {
                require(backupToMinter[backup1Address] == address(0), 
                    "Address is already registered as backup");
                require(minterRanges[backup1Address].length == 0,
                    "minter address can not set as backup 0.1");
            }
            if (backup2Address != address(0)) {
                require(backupToMinter[backup2Address] == address(0), 
                    "Address is already registered as backup");
                require(minterRanges[backup2Address].length == 0,
                    "minter address can not set as backup 0.2");
            }

            if (backup1Address != address(0)) {
                backupAddresses[msg.sender][0] = backup1Address;
                backupAddressSlots[msg.sender][0] = true;
                backupToMinter[backup1Address] = msg.sender;
                emit BackupAddressSet(msg.sender, backup1Address, 0);
            }
            
            if (backup2Address != address(0)) {
                backupAddresses[msg.sender][1] = backup2Address;
                backupAddressSlots[msg.sender][1] = true;
                backupToMinter[backup2Address] = msg.sender;
                emit BackupAddressSet(msg.sender, backup2Address, 1);
            }
        }

        function checkBackUpAddresses(address minter) public view returns (
            bool hasBackup1,
            bool hasBackup2,
            address backup1,
            address backup2
        ) {
            hasBackup1 = backupAddressSlots[minter][0];
            hasBackup2 = backupAddressSlots[minter][1];
            backup1 = backupAddresses[minter][0];
            backup2 = backupAddresses[minter][1];
        }

        function _update(
            address to,
            uint256 tokenId,
            address auth
        ) internal virtual override returns (address) {
            if (_ownerOf(tokenId) == address(0)) {
                return super._update(to, tokenId, auth);
            }

            if (to == nodesEscrowAddress) {
                require(
                    msg.sender == address(this),
                    "Node escrow only accepts tokens from initial MINT"
                );
                return super._update(to, tokenId, auth);
            }

            if (to == address(this)) {
                require(
                    msg.sender == owner(),
                    "Cannot transfer to contract"
                );
                return super._update(to, tokenId, auth);
            }

            if (to != address(0) && to != crossChainEscrowAddress) { 
                require(
                    balanceOf(to) < MAX_TOKENS_PER_WALLET,
                    "Recipient would exceed max token limit"
                );
            }

            return super._update(to, tokenId, auth);
        }

        function setSignerPublicKey(address newSigner) external onlyOwner {
            require(newSigner != address(0), "Invalid signer");
            signerPublicKey = newSigner;
        }

        function verifySignature(bytes32 dataHash, bytes memory signature) internal view returns (bool) {
            bytes32 messageHash = prefixed(dataHash);
            return recoverSigner(messageHash, signature) == signerPublicKey;
        }

        function prefixed(bytes32 hash) internal pure returns (bytes32) {
            return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        }

        function recoverSigner(bytes32 messageHash, bytes memory signature) internal pure returns (address) {
            (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
            return ecrecover(messageHash, v, r, s);
        }

        function splitSignature(bytes memory signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
            require(signature.length == 65, "Invalid signature length");
            assembly {
                r := mload(add(signature, 32))
                s := mload(add(signature, 64))
                v := byte(0, mload(add(signature, 96)))
            }
            return (v, r, s);
        }

        function mint(MintParams memory params) public payable nonReentrant {
            require(!paused, "Contract is paused");
            require(params.mintAmount > 0 && params.mintAmount <= MAX_PER_TRANSACTION, "Exceeds max per address 0.1");
            
            uint256 initialSupply = a3GetTotalCurrentSupply();
            if (isWhitelistNetwork) {
                require(initialSupply + params.mintAmount + params.otherChainQty - whitelistMintedCount <= TIER3_END, "Would exceed max supply 0.1");
            } else {
                require(initialSupply + params.mintAmount + params.otherChainQty <= TOTAL_SUPPLY, "Would exceed max supply 0.2");
            }            

            address minterAddress = msg.sender;
            address originalMinter = backupToMinter[msg.sender];
            if (originalMinter != address(0)) {
                minterAddress = originalMinter;
            }
            
            require(addressMintCount[minterAddress] + params.mintAmount <= MAX_PER_ADDRESS, "Exceeds max per address 0.2");
            require(block.timestamp >= params.timestamp, "Invalid timestamp");
            require(block.timestamp <= params.timestamp + 8 minutes, "Signature expired");

            bytes32 dataHash = keccak256(abi.encodePacked(
                msg.value,
                params.otherChainQty,
                params.mintAmount,
                params.timestamp,
                params.randomNonce
            ));
            
            require(verifySignature(dataHash, params.signature), "Invalid signature");
            require(!usedSignatures[dataHash], "Signature already used");
            usedSignatures[dataHash] = true;
            
            if (params.otherChainQty > 0) {
                a2OtherChainsTnftSupply += params.otherChainQty;
            }

            uint256 startId;
            if (isWhitelistNetwork) {
                startId = (a3GetTotalCurrentSupply() - whitelistMintedCount) + 1;
            } else {
                startId = (a3GetTotalCurrentSupply() - 1200) + 1;
            }
            
            unchecked {
                for (uint256 i = 0; i < params.mintAmount; i++) {
                    _mint(nodesEscrowAddress, startId + i);
                }
            }
            
            MintRange memory newRange = MintRange({
                startId: startId,
                count: params.mintAmount
            });
            minterRanges[minterAddress].push(newRange);
            
            unchecked {
                a4TotalMintedCurrentChain += params.mintAmount;
                a1CurrentChainTnftSupply += params.mintAmount;
                addressMintCount[minterAddress] += params.mintAmount;
            }

            emit MintListener(
                msg.sender,
                startId,
                startId + params.mintAmount - 1,
                params.mintAmount,
                params.otherChainQty
            );
        }

        function setPaused(bool _state) external onlyOwner nonReentrant {
            paused = _state;
        }

        function setWhitelistPaused(bool _state) external onlyOwner nonReentrant {
            whitelistPaused = _state;
        }  

        function setPullPaused(bool _state) external onlyOwner {
            pullPaused = _state;
        }

        function safeBatchTransferFrom(
            address from,
            address to,
            uint256[] calldata tokenIds
        ) external {
            require(tokenIds.length > 0, "Empty transfers not allowed");
            require(tokenIds.length <= MAX_PER_TRANSACTION, "Too many tokens");
            require(to != address(0), "Invalid recipient");
            require(to != crossChainEscrowAddress, "Use a4ReceiveTnftFromUserToOtherChainsSupply");
            
            if (to != nodesEscrowAddress) {
                require(
                    balanceOf(to) + tokenIds.length <= MAX_TOKENS_PER_WALLET,
                    "Transfer would exceed recipient max token limit"
                );
            }
            
            bool isOperatorApproved = isApprovedForAll(from, msg.sender);
            
            for (uint256 i = 0; i < tokenIds.length; i++) {
                require(
                    from == msg.sender || 
                    isOperatorApproved || 
                    getApproved(tokenIds[i]) == msg.sender,
                    "Not owner or approved"
                );
                _transfer(from, to, tokenIds[i]);
            }
        }


        function withdraw() public onlyOwner nonReentrant {
            uint256 balance = address(this).balance;
            require(balance > 0, "No funds available");
            (bool success, ) = payable(owner()).call{value: balance}('');
            require(success, "Transfer failed");
        }        

        receive() external payable {
        }

        function getReceiveEventDetails(uint256 eventId) public view returns (
            bool exists,
            address user,
            uint256[] memory tokenIds,
            uint256 txAmount
        ) {
            if (!_receiveEventEmitted[eventId]) {
                return (false, address(0), new uint256[](0), 0);
            }
            
            EventDetails storage details = eventDetails[eventId];
            return (true, details.user, details.tokenIds, details.txAmount);
        }

        function a5RemainingNodesToMINT() public view returns (uint256) {
            uint256 currentSupplyInUse = a3GetTotalCurrentSupply();
            return currentSupplyInUse >= TOTAL_SUPPLY ? 0 : TOTAL_SUPPLY - currentSupplyInUse;
        }

        function a3GetTotalCurrentSupply() public view returns (uint256) {
            return a1CurrentChainTnftSupply + a2OtherChainsTnftSupply;
        }        

        function a3PullMyNodesFromEscrow() external nonReentrant {
            if (isWhitelistNetwork) {
                require(a3GetTotalCurrentSupply() - whitelistMintedCount >= TIER3_END, "First 10800 nodes not fully minted yet");
            } else {
                require(a3GetTotalCurrentSupply() >= TOTAL_SUPPLY, "Total supply not reached");
            }
            
            require(!pullPaused, "Pulling is paused");
            require(nodesEscrowAddress != address(0), "Escrow not set");
            
            address minterToCheck = msg.sender;
            
            if (minterRanges[msg.sender].length == 0) {  
                address originalMinter = backupToMinter[msg.sender];
                require(originalMinter != address(0), "Not minter or backup");
                
                (bool hasBackup1, bool hasBackup2, address backup1, address backup2) = checkBackUpAddresses(originalMinter);
                require(
                    (hasBackup1 && backup1 == msg.sender) || 
                    (hasBackup2 && backup2 == msg.sender), 
                    "Not authorized backup"
                );
                
                minterToCheck = originalMinter;
            }
            
            MintRange[] storage ranges = minterRanges[minterToCheck];
            require(ranges.length > 0, "No tokens minted");
            
            uint256[] memory finalTokens = new uint256[](MAX_PER_TRANSACTION);
            uint256 pullCount = 0;
            
            for (uint256 i = 0; i < ranges.length && pullCount < MAX_PER_TRANSACTION; i++) {
                for (uint256 j = 0; j < ranges[i].count && pullCount < MAX_PER_TRANSACTION; j++) {
                    uint256 tokenId = ranges[i].startId + j;
                    if (_ownerOf(tokenId) == nodesEscrowAddress) {
                        _transfer(nodesEscrowAddress, msg.sender, tokenId);
                        finalTokens[pullCount++] = tokenId;
                    }
                }
            }
            
            require(pullCount > 0, "No tokens in escrow");
            
            uint256[] memory pulledTokens = new uint256[](pullCount);
            for (uint256 i = 0; i < pullCount; i++) {
                pulledTokens[i] = finalTokens[i];
            }
            
            emit NodesPulled(msg.sender, pulledTokens);
        }

        function a4ReceiveTnftFromUserToOtherChainsSupply(uint256[] memory tokenIds) external {
            require(tokenIds.length > 0, "No tokens specified");
            require(tokenIds.length <= MAX_PER_TRANSACTION, "Exceeds max batch size");
            
            for (uint256 i = 0; i < tokenIds.length; i++) {
                require(_ownerOf(tokenIds[i]) == msg.sender, "Not token owner");
                _transfer(msg.sender, crossChainEscrowAddress, tokenIds[i]);
            }

            a1CurrentChainTnftSupply -= tokenIds.length;
            a2OtherChainsTnftSupply += tokenIds.length;
            
            eventCounter++;
            eventDetails[eventCounter] = EventDetails({
                user: msg.sender,
                tokenIds: tokenIds,
                txAmount: tokenIds.length
            });
            
            _receiveEventEmitted[eventCounter] = true;
            
            emit a4ReceiveTnftFromUserToOtherChainsSupplyListener(
                msg.sender,
                tokenIds,
                tokenIds.length,
                eventCounter
            );
        }

        function a5SendTnftToUserFromOtherChainsSupply(
            address to,
            uint256[] memory tokenIds
        ) external {
            require(
                msg.sender == crossChainOperator,
                "Only crossChainOperator can call"
            );
            require(tokenIds.length <= MAX_PER_TRANSACTION, "Exceeds max batch size");
            require(to != address(0), "Invalid recipient");
            
            for (uint256 i = 0; i < tokenIds.length - 1; i++) {
                for (uint256 j = 0; j < tokenIds.length - i - 1; j++) {
                    if (tokenIds[j] > tokenIds[j + 1]) {
                        uint256 temp = tokenIds[j];
                        tokenIds[j] = tokenIds[j + 1];
                        tokenIds[j + 1] = temp;
                    }
                }
            }

            uint256 mintedCount = 0;
            
            for (uint256 i = 0; i < tokenIds.length; i++) {
                require(tokenIds[i] <= TOTAL_SUPPLY, "Invalid token ID");
                
                if (_ownerOf(tokenIds[i]) == address(0)) {
                    _mint(crossChainEscrowAddress, tokenIds[i]);
                    mintedCount++;
                } else {
                    require(
                        _ownerOf(tokenIds[i]) == crossChainEscrowAddress, 
                        "Token must be in crossChainEscrow"
                    );
                }
                
                _transfer(crossChainEscrowAddress, to, tokenIds[i]);
            }

            a1CurrentChainTnftSupply += tokenIds.length;
            a2OtherChainsTnftSupply -= tokenIds.length;

            emit CrossChainTransferCompleted(
                to,
                tokenIds[0],
                tokenIds[tokenIds.length - 1],
                tokenIds.length
            );
        }

        function getEscrowTokens(address addr) internal view returns (uint256[] memory tokens, bool allPulled) {
            address minterToCheck = addr;
            
            if (minterRanges[addr].length == 0) {
                address originalMinter = backupToMinter[addr];
                if (originalMinter != address(0)) {
                    minterToCheck = originalMinter;
                }
            }
            
            MintRange[] storage ranges = minterRanges[minterToCheck]; 
            if (ranges.length == 0) {
                return (new uint256[](0), true);
            }
            
            uint256 totalTokens = 0;
            for (uint256 i = 0; i < ranges.length; i++) {
                totalTokens += ranges[i].count;
            }
            
            tokens = new uint256[](totalTokens);
            uint256 count = 0;
            allPulled = true;
            
            for (uint256 i = 0; i < ranges.length; i++) {
                uint256 startId = ranges[i].startId;
                uint256 endId = startId + ranges[i].count;
                
                for (uint256 tokenId = startId; tokenId < endId; tokenId++) {
                    if (_ownerOf(tokenId) == nodesEscrowAddress && 
                        _ownerOf(tokenId) != crossChainEscrowAddress) { 
                        tokens[count++] = tokenId;
                        allPulled = false;
                    }
                }
            }
            
            if (count < totalTokens) {
                assembly {
                    mstore(tokens, count)
                }
            }
            
            return (tokens, allPulled);
        }


        function a6AddressEscrowHoldings(address addr) public view returns (
            address queryAddress,
            string memory queryAddressStatus,
            address relatedAddress1,
            string memory relatedAddress1Status,
            address relatedAddress2,
            string memory relatedAddress2Status,
            uint256 totalQty,
            uint256[] memory nodeIds,
            bool isPulled
        ) {
            AddressInfoHelper memory helper = _processAddressInfo(addr);
            
            relatedAddress1 = address(0);
            relatedAddress1Status = "";
            relatedAddress2 = address(0);
            relatedAddress2Status = "";
            
            if (helper.relatedAddresses.length > 0) {
                relatedAddress1 = helper.relatedAddresses[0];
                relatedAddress1Status = helper.relatedTypes[0];
            }
            if (helper.relatedAddresses.length > 1) {
                relatedAddress2 = helper.relatedAddresses[1];
                relatedAddress2Status = helper.relatedTypes[1];
            }
            
            return (
                helper.queryAddress,
                helper.status,
                relatedAddress1,
                relatedAddress1Status,
                relatedAddress2,
                relatedAddress2Status,
                helper.tokens.length > 0 ? (helper.isPulled ? helper.tokens[0] : helper.tokens.length) : 0,
                helper.isPulled ? new uint256[](0) : helper.tokens,
                helper.isPulled
            );
        }

        function _processAddressInfo(address addr) internal view returns (AddressInfoHelper memory) {
            AddressInfoHelper memory helper;
            helper.queryAddress = addr;
            
            bool isMinter = minterRanges[addr].length > 0;
            address originalMinter = backupToMinter[addr];
            bool isBackup = originalMinter != address(0);
            
            if (!isMinter && !isBackup) {
                helper.status = "Not Related to Any Minting/Backup";
                helper.relatedAddresses = new address[](0);
                helper.relatedTypes = new string[](0);
                helper.tokens = new uint256[](0);
                helper.isPulled = false;
                return helper;
            }
            
            (uint256[] memory tokens, bool allPulled) = getEscrowTokens(addr);
            helper.isPulled = allPulled;
            
            if (allPulled) {
                uint256 quantity = balanceOf(addr);
                if (quantity > 0) {
                    helper.status = "Current Node Holder";
                    helper.tokens = new uint256[](1);
                    helper.tokens[0] = quantity; 
                } else {
                    if (isMinter) {
                        helper.status = "Previously Minter";
                    } else if (isBackup) {
                        helper.status = (addr == backupAddresses[originalMinter][0]) ? 
                            "Previously Backup 1" : "Previously Backup 2";
                    }
                    helper.tokens = new uint256[](0);
                }
                helper.relatedAddresses = new address[](0);
                helper.relatedTypes = new string[](0);
                return helper;
            }
            
            address[] memory tempAddrs = new address[](2);
            string[] memory tempTypes = new string[](2);
            uint256 count = 0;
            
            if (isMinter) {
                helper.status = "Minter";
                (bool hasBackup1, bool hasBackup2, address backup1, address backup2) = checkBackUpAddresses(addr);
                
                if (hasBackup1) {
                    tempAddrs[count] = backup1;
                    tempTypes[count] = "Backup 1";
                    count++;
                }
                
                if (hasBackup2) {
                    tempAddrs[count] = backup2;
                    tempTypes[count] = "Backup 2";
                    count++;
                }
            } else {
                (bool hasBackup1, bool hasBackup2, address backup1, address backup2) = checkBackUpAddresses(originalMinter);
                helper.status = (addr == backup1) ? "Backup 1" : "Backup 2";
                
                tempAddrs[count] = originalMinter;
                tempTypes[count] = "Minter";
                count++;
                
                if (hasBackup1 && addr != backup1) {
                    tempAddrs[count] = backup1;
                    tempTypes[count] = "Backup 1";
                    count++;
                }
                if (hasBackup2 && addr != backup2) {
                    tempAddrs[count] = backup2;
                    tempTypes[count] = "Backup 2";
                    count++;
                }
            }

            helper.tokens = tokens;
            
            helper.relatedAddresses = new address[](count);
            helper.relatedTypes = new string[](count);
            for (uint256 i = 0; i < count; i++) {
                helper.relatedAddresses[i] = tempAddrs[i];
                helper.relatedTypes[i] = tempTypes[i];
            }
            
            return helper;
        }

        function setMigrationContract(address _migrationContract) external onlyOwner {
            migrationContract = _migrationContract;
        }

        function burnAllTokensForMigration(
            address user,
            uint256[] calldata tokenIds
        ) external returns (uint256 startId, uint256 endId, uint256 totalBurned) {
            if (msg.sender != migrationContract) revert NotMigrationContract();
            
            uint256 total = tokenIds.length;
            if (total == 0) revert NoTokensToMigrate();
            
            for (uint256 i = 0; i < total; i++) {
                require(_ownerOf(tokenIds[i]) == user, "Not token owner");
            }

            startId = tokenIds[0];
            endId = tokenIds[total - 1];
            totalBurned = total;
            
            for (uint256 i = 0; i < total; i++) {
                a1CurrentChainTnftSupply--;
                
                _burn(tokenIds[i]);
            }
            
            emit BatchBurned(user, tokenIds, total);
            
            return (startId, endId, totalBurned);
        }

        function whitelistMint() external nonReentrant {
            require(isWhitelistNetwork, "Not a whitelist network");
            require(whitelistAllowance[msg.sender] > 0, "Not Whitelisted");
            require(!hasWhitelistMinted[msg.sender], "Already minted");
            require(!whitelistPaused, "WhitelistMint is paused");

            uint256 mintAmount = whitelistAllowance[msg.sender];
            uint256 startId = TIER3_END + whitelistMintedCount + 1;
            
            minterRanges[msg.sender].push(MintRange({
                startId: startId,
                count: mintAmount
            }));

            for (uint256 i = 0; i < mintAmount; i++) {
                _mint(nodesEscrowAddress, startId + i);
            }
            
            hasWhitelistMinted[msg.sender] = true;
            whitelistMintedCount += mintAmount;
            a4TotalMintedCurrentChain += mintAmount;
            a1CurrentChainTnftSupply += mintAmount;
            addressMintCount[msg.sender] += mintAmount; 

            emit WhitelistMinted(msg.sender, startId, mintAmount);
        }

        function getWhitelistStatus(address user) public view returns (WhitelistStatus memory) {
            return WhitelistStatus({
                isWhitelisted: whitelistAllowance[user] > 0,
                hasMinted: hasWhitelistMinted[user],
                eligibleQuantity: whitelistAllowance[user]
            });
        }

        function totalSupply() public pure returns (uint256) {
            return TOTAL_SUPPLY;
        }          

    }
