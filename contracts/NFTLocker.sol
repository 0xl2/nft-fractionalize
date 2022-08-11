// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import './FractionToken.sol';
import './interface/IFractionToken.sol';

contract NFTLocker {
    mapping(address => mapping(uint => bool)) isNftDeposited;
    mapping(address => mapping(uint => address)) nftOwner;
    mapping(address => mapping(uint => bool)) isNftChangingOwner;

    mapping(address => mapping(uint => bool)) isNftFractionalised;
    mapping(address => mapping(uint => address)) fractionTokenAddressFromNft;

    mapping(address => nftDepositFolder) depositFolder;
    struct nftDepositFolder {
        address[] nftAddresses;
        uint[] nftIds;
    }

    address contractDeployer;
    address auctionAddress;

    bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;

    constructor() {
        contractDeployer = msg.sender;
    }

    modifier contractDeployerOnly {
        require (msg.sender == contractDeployer, "Only contract deployer can call this function");
        _;
    }

    modifier auctionContractOnly {
        require(msg.sender == auctionAddress,"only auction can call this function");
        _;
    }
    
    function setNftOwner(address _nftAddress, uint _nftId, address newOwner) public {
        require(isNftChangingOwner[_nftAddress][_nftId] == true, "Nft is not changing owner");
        require(msg.sender == auctionAddress, "Only current owner of NFT can change NFT owner");
        
        isNftChangingOwner[_nftAddress][_nftId] = false;
        nftOwner[_nftAddress][_nftId] = newOwner;
    }

    function isNftActive(address _nftAddress, uint _nftId) public view returns(bool) {
        bool hasDeposited = isNftDeposited[_nftAddress][_nftId];
        bool hasFractionalise = isNftFractionalised[_nftAddress][_nftId];
        if (hasDeposited && hasFractionalise) {
            return true;
        } else {
            return false;
        }
    }

    function depositNft(address _nftAddress, uint256 _nftId) public {
        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _nftId);
    
        isNftDeposited[_nftAddress][_nftId] = true;
        nftOwner[_nftAddress][_nftId] = msg.sender;

        depositFolder[msg.sender].nftAddresses.push(_nftAddress);
        depositFolder[msg.sender].nftIds.push(_nftId);
    }

    function createFraction(
        address _nftAddress,
        uint256 _nftId,
        string memory _tokenName,
        string memory _tokenTicker,
        uint256 _supply,
        uint256 _royaltyPercentage

    ) public {
        require(isNftDeposited[_nftAddress][_nftId], "This NFT hasn't been deposited yet");
        require(nftOwner[_nftAddress][_nftId] == msg.sender, "You do not own this NFT");

        isNftFractionalised[_nftAddress][_nftId] = true;

        FractionToken fractionToken = new FractionToken(
            _nftAddress,
            _nftId,
            msg.sender,
            _tokenName,
            _tokenTicker,
            _supply,                                                                
            _royaltyPercentage,
            address (this)
        );

        fractionTokenAddressFromNft[_nftAddress][_nftId] = address(fractionToken);
    }

     function withdrawNft(address _nftAddress, uint256 _nftId) public {
        require(isNftDeposited[_nftAddress][_nftId] == true, "This NFT is not withdrawn");
        require(isNftFractionalised[_nftAddress][_nftId] == false/* ||
            FractionToken.balanceOf(msg.sender) == FractionToken.totalSupply()*/, 
            "NFT cannot be withdrawn, either the NFT has been withdrawn or you do not own the total supply of fraction tokens"
        );
        require(nftOwner[_nftAddress][_nftId] == msg.sender, "This address does not own this NFT");

        nftOwner[_nftAddress][_nftId] = 0x0000000000000000000000000000000000000000;

        for (uint i = 0; i < depositFolder[msg.sender].nftAddresses.length; i++) {
            if (depositFolder[msg.sender].nftAddresses[i] == _nftAddress &&
                depositFolder[msg.sender].nftIds[i] == _nftId) {
                
                delete depositFolder[msg.sender].nftAddresses[i];
                delete depositFolder[msg.sender].nftIds[i];
                break;
            }
        }

        IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _nftId);
    }
    
    function disableIsFractionalised(address _nftAddress, uint _nftID) public auctionContractOnly {
        isNftFractionalised[_nftAddress][_nftID] = false;
    }

    function setAuctionAddress(address _auctionAddress) public contractDeployerOnly {
        auctionAddress = _auctionAddress; 
    }
    
    function setNoLongerFractionTokenTrue(address _nftAddress, uint _nftId) external auctionContractOnly {
        IFractionToken(fractionTokenAddressFromNft[_nftAddress][_nftId]).setNoLongerFractionTokenTrue();
    }

    function setAuctionAddressInFraction(address _fractionAddress) public {
        IFractionToken(_fractionAddress).setAuctionContractAddress(auctionAddress);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns(bytes4) {
        return ERC721_RECEIVED;
    }
}