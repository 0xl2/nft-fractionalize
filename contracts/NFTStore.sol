// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTStore is Ownable {
    uint public vaultCnt;

    mapping(uint => Vault) internal vaults;
    mapping(uint => mapping(uint256 => address)) private requesters;

    struct Vault {
        address fTokenAddress;
        address nftAddress;
        IERC721 nft;
        uint256 ethBalance;
        uint256 tokenBalance;
    }

    event NewVaultAdded(uint256 indexed vaultId);
    event RequesterSet(uint256 indexed vaultId, uint256 id, address requester);

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

    function fToken(uint256 vaultId) public view returns (address) {
        return _getVault(vaultId).fTokenAddress;
    }

    function setRequester(uint256 vaultId, uint256 id, address _requester)
        external
        onlyOwner
    {
        requesters[vaultId][id] = _requester;
        
        emit RequesterSet(vaultId, id, _requester);
    }

    function addNewVault(Vault memory _vault) external onlyOwner returns (uint256) {
        vaults[vaultCnt] = _vault;

        emit NewVaultAdded(vaultCnt);

        vaultCnt++;

        return vaultCnt;
    }
}