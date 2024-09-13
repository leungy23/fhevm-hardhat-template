// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract EncryptedFunds is Ownable2Step {
    event Transfer(address indexed from, address indexed to);
    event Approval(address indexed owner, address indexed spender);
    event Mint(address indexed to, euint64 encryptedTokenID, uint64 amount);

    // Event to track the total supply for each token
    event TotalSupplyUpdated(euint64 tokenID, uint64 totalSupply);
    event TokenAccessed(euint64 tokenID);
    event BalanceBeforeTransfer(euint64 tokenID, euint64 balance, euint64 allowance);
    event TransferValue(euint64 tokenID, euint64 transferValue);
    event BalanceAfterTransfer(euint64 tokenID, euint64 newBalanceTo, euint64 newBalanceFrom, euint64 updatedAllowance);

    // Struct to store metadata (name, symbol) for each token
    struct TokenMetadata {
        string name;
        string symbol;
    }

    // A mapping from address to encrypted balances of tokens (stored as encrypted)
    mapping(address => mapping(euint64 => euint64)) internal balances;

    // A mapping for allowances, works like balances but for allowances
    mapping(address => mapping(address => mapping(euint64 => euint64))) internal allowances;

    // A mapping for encrypted token IDs to their metadata (name and symbol)
    mapping(euint64 => TokenMetadata) private tokenMetadata;

    // A mapping for total supply per encrypted token ID; can be hidden in prodcution
    mapping(euint64 => euint64) private totalSupplyPerToken;

    // Encrypted token IDs mapping (e.g., Token A = 1, Token B = 2, etc.)
    mapping(uint256 => euint64) private encryptedTokenIDs;

    constructor() payable Ownable(msg.sender) {
        // Initialize metadata for each token and assign encrypted token IDs
        euint64 tokenAID = TFHE.asEuint64(1);
        euint64 tokenBID = TFHE.asEuint64(2);
        euint64 tokenCID = TFHE.asEuint64(3);

        // Store encrypted token IDs
        encryptedTokenIDs[0] = tokenAID;
        encryptedTokenIDs[1] = tokenBID;
        encryptedTokenIDs[2] = tokenCID;

        // Set the metadata for each token
        tokenMetadata[tokenAID] = TokenMetadata("Token A", "TKA");
        tokenMetadata[tokenBID] = TokenMetadata("Token B", "TKB");
        tokenMetadata[tokenCID] = TokenMetadata("Token C", "TKC");
    }

    // Get the total supply of a specific token by its encrypted ID
    function totalSupply(euint64 encryptedTokenID) public view returns (euint64) {
        return totalSupplyPerToken[encryptedTokenID];
    }

    // Getter function to retrieve encrypted token IDs by index
    function getEncryptedTokenID(uint256 index) public view returns (euint64) {
        return encryptedTokenIDs[index];
    }

    // Get the name of a specific token using its encrypted token ID
    function getTokenName(euint64 tokenID) public view returns (string memory) {
        return tokenMetadata[tokenID].name;
    }

    // Get the symbol of a specific token using its encrypted token ID
    function getTokenSymbol(euint64 tokenID) public view returns (string memory) {
        return tokenMetadata[tokenID].symbol;
    }

    function mint(euint64 encryptedTokenID, uint64 mintedAmount) public virtual onlyOwner {
        balances[owner()][encryptedTokenID] = TFHE.add(balances[owner()][encryptedTokenID], mintedAmount);
        TFHE.allow(balances[owner()][encryptedTokenID], address(this));
        TFHE.allow(balances[owner()][encryptedTokenID], owner());
        // Update the total supply for the specific token
        totalSupplyPerToken[encryptedTokenID] = TFHE.add(totalSupplyPerToken[encryptedTokenID], mintedAmount);
        emit Mint(owner(), encryptedTokenID, mintedAmount);
    }

    //used for testing
    function burn(euint64 encryptedTokenID, uint64 mintedAmount) public virtual onlyOwner {
        balances[owner()][encryptedTokenID] = TFHE.sub(balances[owner()][encryptedTokenID], mintedAmount);
        TFHE.allow(balances[owner()][encryptedTokenID], address(this));
        TFHE.allow(balances[owner()][encryptedTokenID], owner());
        totalSupplyPerToken[encryptedTokenID] = TFHE.sub(totalSupplyPerToken[encryptedTokenID], mintedAmount);
        emit Mint(owner(), encryptedTokenID, mintedAmount);
    }

    function approve(address spender, euint64 encryptedTokenID, euint64 amount) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, encryptedTokenID, amount);
        emit Approval(owner, spender);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        euint64 encryptedTokenID,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public virtual returns (bool) {
        euint64 amount = TFHE.asEuint64(encryptedAmount, inputProof);
        address spender = msg.sender;
        _transferHidden(from, to, spender, encryptedTokenID, amount);
        return true;
    }

    function _approve(address owner, address spender, euint64 encryptedTokenID, euint64 amount) internal virtual {
        for (uint256 i = 0; i < _getNumberOfTokens(); i++) {
            euint64 currentTokenID = encryptedTokenIDs[i];
            ebool isCorrectToken = TFHE.eq(encryptedTokenID, currentTokenID);
            euint64 currentAllowance = allowances[owner][spender][currentTokenID];
            euint64 newAllowance = TFHE.select(isCorrectToken, amount, currentAllowance);
            allowances[owner][spender][currentTokenID] = newAllowance;
            TFHE.allow(newAllowance, address(this));
            TFHE.allow(newAllowance, owner);
            TFHE.allow(newAllowance, spender);
        }
    }

    function _allowance(
        address owner,
        address spender,
        euint64 encryptedTokenID
    ) internal view virtual returns (euint64) {
        return allowances[owner][spender][encryptedTokenID];
    }

    function _transferHidden(
        address from,
        address to,
        address spender,
        euint64 encryptedTokenID,
        euint64 amount
    ) internal virtual {
        for (uint256 i = 0; i < _getNumberOfTokens(); i++) {
            euint64 currentTokenID = encryptedTokenIDs[i];
            emit TokenAccessed(currentTokenID);
            _checkAndTransferBalances(from, to, spender, currentTokenID, encryptedTokenID, amount);
        }
        emit Transfer(from, to);
    }

    function _checkAndTransferBalances(
        address from,
        address to,
        address spender,
        euint64 currentTokenID,
        euint64 encryptedTokenID,
        euint64 amount
    ) internal {
        ebool isCorrectToken = TFHE.eq(encryptedTokenID, currentTokenID);
        euint64 currentBalance = balances[from][currentTokenID];
        euint64 currentAllowance = _allowance(from, spender, currentTokenID);
        emit BalanceBeforeTransfer(currentTokenID, currentBalance, currentAllowance);

        ebool allowedTransfer = TFHE.le(amount, currentAllowance);
        ebool canTransfer = TFHE.le(amount, currentBalance);
        ebool isTransferable = TFHE.and(canTransfer, allowedTransfer);

        euint64 updatedAllowance = TFHE.select(isTransferable, TFHE.sub(currentAllowance, amount), currentAllowance);
        allowances[from][spender][currentTokenID] = updatedAllowance;

        euint64 transferAmount = TFHE.select(isCorrectToken, amount, TFHE.asEuint64(0));
        euint64 transferValue = TFHE.select(isTransferable, transferAmount, TFHE.asEuint64(0));

        emit TransferValue(currentTokenID, transferValue);

        _updateBalances(from, to, currentTokenID, transferValue);
    }

    // Helper function to update the balances
    function _updateBalances(address from, address to, euint64 currentTokenID, euint64 transferValue) internal {
        euint64 newBalanceTo = TFHE.add(balances[to][currentTokenID], transferValue);
        balances[to][currentTokenID] = newBalanceTo;

        TFHE.allow(newBalanceTo, address(this));
        TFHE.allow(newBalanceTo, to);

        euint64 newBalanceFrom = TFHE.sub(balances[from][currentTokenID], transferValue);
        balances[from][currentTokenID] = newBalanceFrom;

        TFHE.allow(newBalanceFrom, address(this));
        TFHE.allow(newBalanceFrom, from);

        emit BalanceAfterTransfer(
            currentTokenID,
            newBalanceTo,
            newBalanceFrom,
            allowances[from][msg.sender][currentTokenID]
        );
    }

    function _getNumberOfTokens() internal pure returns (uint256) {
        return 3; // Example with 3 tokens (extendable if needed)
    }

    function balanceOf(address account, euint64 encryptedTokenID) public view virtual returns (euint64) {
        // Return the balance of the specified account for the specified encrypted token ID
        return balances[account][encryptedTokenID];
    }
}
