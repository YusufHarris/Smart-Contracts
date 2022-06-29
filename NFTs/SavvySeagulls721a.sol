// SPDX-License-Identifier: MIT

// LazyDevs Takes no responsibility

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract SavvySeagulls is ERC721A, Ownable, ReentrancyGuard {

    using Strings for uint256;
    

    uint256 public price = 0.02 ether;
    uint256 public _maxSupply = 6969;
    uint256 public maxMintAmountPerTx = 10;
    uint256 maxMintAmountPerWallet = 10;

    string baseURL = "";
    string ExtensionURL = ".json";
    string HiddenURL;

    uint256 totalFreeSupply = 2000;


    bool paused = true;
    bool revealed = false;

    constructor(string memory _initBaseURI, string memory _initNotRevealedUri) ERC721A("Savvy Seagulls", "SVYSGLS") {
        baseURL = _initBaseURI;
        HiddenURL = _initNotRevealedUri;
    }

    

    // ================== Mint Function =======================

    modifier mintComp(uint256 _mintAmount){
        require(!paused, "The contract is paused!");
        require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "Invalid mint amount!");
        require(totalSupply() + _mintAmount <= _maxSupply, "Max supply exceeded!");
        require(balanceOf(msg.sender) < maxMintAmountPerWallet, "You have 10 Seagulls.");
        _;
    }

    function mint(uint256 _mintAmount) public payable mintComp(_mintAmount){
                require(_msgSender() == tx.origin);    
                    if(checkMintStage() == 1){
                        _safeMint(msg.sender, _mintAmount);
                    }else{
                        require(msg.value >= _mintAmount * price, "Insufficient payment.");
                        _safeMint(msg.sender, _mintAmount);
                    }       
    }

    // =================== Orange Functions (Owner Only) ===============


    function pause(bool state) public onlyOwner {
        paused = state;
    }

    function safeMint(address to, uint256 quantity) public onlyOwner {
        _safeMint(to, quantity);
    }
    
    function setHiddenURL(string memory uri) public onlyOwner {
        HiddenURL = uri;
    }
    
    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }
    
    function setbaseURL(string memory uri) public onlyOwner{
        baseURL = uri;
    }

    function setExtensionURL(string memory uri) public onlyOwner{
        ExtensionURL = uri;
    }

    function setCostPrice(uint256 _cost) public onlyOwner{
        price = _cost;
    } 

    function setSupply(uint256 supply) public onlyOwner{
        _maxSupply = supply;
    }

    function setTotalFreeSupply(uint256 supply) public onlyOwner{
        totalFreeSupply = supply;
    }
      

    // ================================ Withdraw Function ====================

    function withdraw() public onlyOwner nonReentrant{
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // =================== Blue Functions (View Only) ====================

    function tokenURI(uint256 tokenId) public view override(ERC721A) returns (string memory){

        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
        
        if (revealed == false) {
        return HiddenURL;
        }
        
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), ExtensionURL))
            : '';
    }

    function _startTokenId() internal view virtual override(ERC721A) returns (uint256){
        return 1;
    }

    function checkMintStage() public view returns (uint8){
        if(totalSupply() < totalFreeSupply)
        {
            return 1;
        }else{
            return 2;
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURL;
    }

    function maxSupply() public view returns (uint256){
        return _maxSupply;
    }
}