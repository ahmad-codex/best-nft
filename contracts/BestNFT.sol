// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NFTLibraries.sol";
import "./ERC721BlackList.sol";

contract BestNFT is ERC721, ContextMixin, NativeMetaTransaction, ReentrancyGuard, Ownable, ERC721BlackList {
    using Strings for uint256;
    using Counters for Counters.Counter;
   
    Counters.Counter private currentTokenId;
    uint256 private tokensMinted;
    uint256 MAX_SUPPLY;
    string contractURI_;
    string baseURI_;

    //Reserved Tokens Variables and Types
    struct ReservedTokenId
    {
        uint256 TokenId;
        bool minted;
        bool isDeleted;
    }
    
    ReservedTokenId[] ReservedTokensIds;

    uint reservedNFTsCount = 0;
    uint reservedNFTsMintedCount = 0;
    
    //Events
    event NFTMinting(address indexed by, address indexed recipient, uint256 tokenId);
    event RegisterReservedTokenId(address indexed by, uint256 tokenId);
    event UnRegisterReservedTokenId(address indexed by, uint256 tokenId);
    event ChangeBaseURI(address indexed by, string oldBaseURI, string newBaseURI);
    event ChangeContractURI(address indexed by, string oldContractURI, string newContractURI);

    constructor(string memory name_, string memory symbol_, address multisigWalletOwner, uint maxSupply) ERC721(name_, symbol_) 
    {
        transferOwnership(multisigWalletOwner);
        MAX_SUPPLY = maxSupply;
        tokensMinted = 0;
        contractURI_ = "https://gateway.pinata.cloud/ipfs/QmXvcZCPKFA39pJ5XFf2Vz2S6iosJEGJkk44GHJ8WgGEg6/";
        baseURI_ = "https://gateway.pinata.cloud/ipfs/QmXvcZCPKFA39pJ5XFf2Vz2S6iosJEGJkk44GHJ8WgGEg6/";
    }

    function mintTo(address recipient) public onlyOwner returns (uint256)
    {
        require(!getBlackListStatus(recipient), "recipient is blacklisted");
        require(tokensMinted < MAX_SUPPLY, "Already at max supply.");
        bool tokenMinted = false;
        uint256 newItemId;
        do
        {
            currentTokenId.increment();
            newItemId = currentTokenId.current();
            if (!isTokenIdReserved(newItemId))
            {
                _safeMint(recipient, newItemId);
                tokensMinted++;
                tokenMinted = true;
            }
        } while (!tokenMinted);
        emit NFTMinting(msg.sender, recipient, newItemId);
        return newItemId;
    }

    function mintTo(address recipient, uint mintingSupply) public onlyOwner returns (uint256)
    {
        require(!getBlackListStatus(recipient), "recipient is blacklisted");
        require(tokensMinted < MAX_SUPPLY, "Already at max supply.");
        require((tokensMinted + mintingSupply) <= MAX_SUPPLY, "Minting supply exceeds max supply including the minted tokens");
        bool tokenMinted = false;
        uint256 newItemId;
        uint256 tokensMintedCount = 0;
        do
        {
            do 
            {
                currentTokenId.increment();
                newItemId = currentTokenId.current();
                if (!isTokenIdReserved(newItemId))
                {
                    _safeMint(recipient, newItemId);
                    tokensMinted++;
                    tokenMinted = true;
                    emit NFTMinting(msg.sender, recipient, newItemId);
                } 
            } while (!tokenMinted);
            tokensMintedCount++;
        } while (tokensMintedCount != mintingSupply);

        return tokensMintedCount;
    }

    function totalSupply() external view returns (uint256) {
        return tokensMinted;
    }

    function contractURI() public view returns (string memory) 
    {
        return contractURI_;
    }

    function _baseURI() internal view override returns (string memory) 
    {
        return baseURI_;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner
    {
        emit ChangeBaseURI(msg.sender, baseURI_, newBaseURI);
        baseURI_ = newBaseURI;
    }

    function setContractURI(string memory newContractURI) public onlyOwner
    {
        emit ChangeContractURI(msg.sender, contractURI_, newContractURI);
        contractURI_ = newContractURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns(string memory)
    {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : "";
    }

    //Reserved Tokens Custom Functions 
    function isTokenIdReserved(uint256 tokenId) public view returns(bool)
    {
        //require(!_exists(tokenId), "Token is already minted");
        if (_exists(tokenId)) { return true; } 
        for (uint i = 0; i < ReservedTokensIds.length; i++)
        {
            ReservedTokenId storage rid = ReservedTokensIds[i];
            if (rid.TokenId == tokenId) 
            {
                if (!rid.isDeleted)
                {
                    return true;
                }
                else
                {
                    return false;
                }
            }
        } 
        return false;
    }
     
    function getReservedTokensCount() external view returns(uint) 
    {
        return reservedNFTsCount;
    }

    function getReservedTokensMintedCount() external view returns(uint256)
    {
        require(ReservedTokensIds.length != 0, "There is no reserved tokens registered.");
        return reservedNFTsMintedCount;
    } 

    function getReservedTokensUnMintedCount() external view onlyOwner returns(uint256)
    {
        require(ReservedTokensIds.length != 0 , "There is no reserved tokens registered.");
        return (reservedNFTsCount - reservedNFTsMintedCount);
    } 

    function getMintedReservedTokens() external view onlyOwner returns(uint256[] memory)
    {
        require(ReservedTokensIds.length != 0 , "There is no reserved tokens registered.");
        uint256[] memory rmts = new uint256[](reservedNFTsMintedCount);
        uint intCounter = 0;
        uint intMintedTokens = 0;
        for (intCounter; intCounter < ReservedTokensIds.length; intCounter++)
        {
            ReservedTokenId memory rid = ReservedTokensIds[intCounter];
            if (rid.minted && !rid.isDeleted)
            {
                rmts[intMintedTokens] = rid.TokenId;
                intMintedTokens++;
            }
        }
        return rmts;
    }

    function getUnMintedReservedTokens() public view onlyOwner returns(uint256[] memory)
    {
        require(ReservedTokensIds.length != 0 , "There is no reserved tokens registered.");
        uint unmintedReservedTokens = reservedNFTsCount - reservedNFTsMintedCount;
        uint256[] memory rmts = new uint256[](unmintedReservedTokens);
        uint intCounter = 0;
        uint intUnMintedTokens = 0;
        for (intCounter; intCounter < ReservedTokensIds.length; intCounter++)
        {
            ReservedTokenId memory rid = ReservedTokensIds[intCounter];
            if (!rid.minted && !rid.isDeleted)
            {
                rmts[intUnMintedTokens] = rid.TokenId;
                intUnMintedTokens++;
            }
        }
        return rmts;
    }

    function getAllReservedTokens() public view onlyOwner returns(uint256[] memory)
    {
        require(ReservedTokensIds.length != 0 , "There is no reserved tokens registered.");
        uint256[] memory rmts = new uint256[](reservedNFTsCount);
        uint intCounter = 0;
        uint intReservedTokens = 0;
        for(intCounter; intCounter < ReservedTokensIds.length; intCounter++)
        {
            ReservedTokenId memory rid = ReservedTokensIds[intCounter];
            if (!rid.isDeleted)
            {
                rmts[intReservedTokens] = rid.TokenId;
                intReservedTokens++;
            }
        }
        return rmts;
    }

    function registerReservedTokenId(uint256 tokenId) public onlyOwner
    {
        require((!isTokenIdReserved(tokenId)), "This Token Id is Already Reserved" );
        ReservedTokensIds.push(ReservedTokenId(tokenId, false, false));
        reservedNFTsCount++;
        emit RegisterReservedTokenId(msg.sender, tokenId);
    }
    
    function registerReservedTokenIds(uint256[] memory tokenIds) public onlyOwner
    {
        for(uint intCounter; intCounter < tokenIds.length; intCounter++)
        {
            registerReservedTokenId(tokenIds[intCounter]);
        }
    }

    function unRegisterReservedTokenId(uint256 tokenId) public onlyOwner
    {
        require(isTokenIdReserved(tokenId), "This Token Id is Not Reserved" );
        uint index = 0;
        ReservedTokenId storage rid;

        for (uint intCounter = 0; intCounter < ReservedTokensIds.length; intCounter++)
        {
            rid = ReservedTokensIds[intCounter];
            if (rid.TokenId == tokenId) 
            {
                index = intCounter;
                break;
            }
        }
        ReservedTokensIds[index].isDeleted = true;
        reservedNFTsCount--;
        emit UnRegisterReservedTokenId(msg.sender, tokenId);
    }
    
    function mintReservedToken(address recipient, uint256 tokenId) public onlyOwner returns(uint256)
    {
        require(!getBlackListStatus(recipient), "recipient is blacklisted");
        require(tokensMinted < MAX_SUPPLY, "Already at max supply");
        require(!_exists(tokenId), "Token Already Minted");
        require(isTokenIdReserved(tokenId), "Token is Not Reserved");
        
        //Minting the token
        _safeMint(recipient, tokenId);
        emit NFTMinting(msg.sender, recipient, tokenId);
        
        //Updating the reserved token attribute
        uint intCounter = 0;
        uint index = 0;
        ReservedTokenId storage rid;

        for (intCounter; intCounter < ReservedTokensIds.length; intCounter++)
        {
            rid = ReservedTokensIds[intCounter];
            if (rid.TokenId == tokenId) 
            {
                index = intCounter;
                break;
            }
        }
        ReservedTokensIds[index].minted = true;
        reservedNFTsMintedCount++;
        tokensMinted++;
        return tokenId;
    }

    function mintReservedToken(address recipient, uint256[] memory tokenIds) public onlyOwner
    {
        require(!getBlackListStatus(recipient), "recipient is blacklisted");
        require(tokensMinted < MAX_SUPPLY, "Already at max supply");
        require((tokensMinted + tokenIds.length) <= MAX_SUPPLY, "Supplied reserved token exceeds max supply");
        
        //1- This function will not validate if all token Ids are reserved firsthand before minting
        //but it will mint only the reserved tokens after validating if it's a reserved token id.
        //2- This function will mint the reserved tokens and increase the counters

        for (uint intCounter = 0; intCounter < tokenIds.length; intCounter++)
        {
            if (!_exists(tokenIds[intCounter]) && isTokenIdReserved(tokenIds[intCounter]))
            {
                _safeMint(recipient, tokenIds[intCounter]);
                emit NFTMinting(msg.sender, recipient, tokenIds[intCounter]);
                reservedNFTsMintedCount++;
                tokensMinted++;
                
                //Update the reserved token attribute to become minted
                uint intCounter2 = 0;
                uint index = 0;
                ReservedTokenId storage rid;

                for (intCounter2; intCounter2 < ReservedTokensIds.length; intCounter2++)
                {
                    rid = ReservedTokensIds[intCounter];
                    if (rid.TokenId == tokenIds[intCounter] && !rid.isDeleted)
                    {
                        index = intCounter2;
                        break;
                    }
                }
                ReservedTokensIds[index].minted = true;
            }
        }       
    }

    //Custom Multi Transfer NFTs to a single address
    function transferMultiNFT(address recipient, uint256[] memory tokenIDs) public
    {
        require(!getBlackListStatus(recipient), "recipient is blacklisted");
        require(tokenIDs.length > 0 , "No token IDs are supplied");
        require(recipient != address(0) , "Recipient should not be address zero");

        for (uint intCounter = 0; intCounter < tokenIDs.length; intCounter++)
        {
            transferFrom(msg.sender, recipient, tokenIDs[intCounter]);
        }
    }

    // OpenSea Polygon Compatability Requirement (Copied from OpenSea Docs Site)

    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    /**
    * As another option for supporting trading without requiring meta transactions, override isApprovedForAll to whitelist OpenSea proxy accounts on Matic
    */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        
        return ERC721.isApprovedForAll(_owner, _operator);
    }
}