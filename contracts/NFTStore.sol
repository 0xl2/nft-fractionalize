// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTStore is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    uint public vaultCnt;

    address public nftFraction;

    mapping(uint => Vault) private vaults;
    mapping(uint => EnumerableSet.UintSet) private holdings;
    mapping(uint => mapping(uint256 => address)) private requesters;

    struct Vault {
        address fTokenAddress;
        address nftAddress;
        IERC721 nft;
        uint256 tokenBalance;
    }

    event NewVaultAdded(uint256 indexed vaultId);
    event RequesterSet(uint256 indexed vaultId, uint256 id, address requester);
    event HoldingsAdded(uint256 indexed vaultId, uint256 id);
    event HoldingsRemoved(uint256 indexed vaultId, uint256 id);

    function setFraction(address _fraction) external onlyOwner {
        require(nftFraction != _fraction, "Invalid address");

        nftFraction = _fraction;
    }

    function _getVault(uint256 vaultId) private view returns (Vault storage) {
        require(vaults[vaultId].nftAddress != address(0), "Invalid vaultId");
        return vaults[vaultId];
    }

    function nft(uint256 vaultId) external view returns (IERC721) {
        return _getVault(vaultId).nft;
    }

    function requester(uint256 vaultId, uint256 id) external view returns(address) {
        return requesters[vaultId][id];
    }

    function fToken(uint256 vaultId) external view returns (address) {
        return _getVault(vaultId).fTokenAddress;
    }

    function holdingsContains(uint256 vaultId, uint256 elem) external view returns (bool) {
        return holdings[vaultId].contains(elem);
    }

    function setRequester(uint256 vaultId, uint256 id, address _requester)
        external
    {
        require(msg.sender == nftFraction, "Not fraction contract");

        requesters[vaultId][id] = _requester;
        
        emit RequesterSet(vaultId, id, _requester);
    }

    function addNewVault(
        address _fToken,
        address _nft,
        uint256 _balance
    ) external onlyOwner returns (uint256) {
        require(_fToken != address(0), "Invalid fraction token");
        require(_nft != address(0), "Invalid NFT");
        require(_balance > 0, "Invalid balance");

        vaultCnt++;

        vaults[vaultCnt] = Vault(
            _fToken,
            _nft,
            IERC721(_nft),
            _balance
        );

        emit NewVaultAdded(vaultCnt);

        return vaultCnt;
    }

    function holdingsAdd(uint256 vaultId, uint256 elem) public onlyOwner {
        holdings[vaultId].add(elem);
        emit HoldingsAdded(vaultId, elem);
    }

    function holdingsRemove(uint256 vaultId, uint256 elem) public onlyOwner {
        holdings[vaultId].remove(elem);
        emit HoldingsRemoved(vaultId, elem);
    }
}