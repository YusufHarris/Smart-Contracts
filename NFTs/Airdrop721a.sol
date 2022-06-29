// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.9;


abstract contract Target721 { 
    function ownerOf(uint256 tokenId) public view virtual returns (address);
}

contract MassAirdrop is Context, ERC165, IERC721, IERC721Metadata, Ownable {

    using Address for address;
    using Strings for uint256;


    // Token name and symbol
    string public _name;
    string public _symbol;

    mapping(uint256 => address) private _owners;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(uint256 => bool) private _tokenBifurcated;

    string internal _baseTokenURI;
    string internal _contractURI;

    uint256 internal _totalSupply;
    uint256 internal MAX_TOKEN_ID; 
	
	bool internal burnAirdrop = false;

    Target721 _target;

  constructor(
      string memory _tokenName,
      string memory _tokenSymbol,
      string memory _url,
      address targetContract
  ) {
        Target721(targetContract);
        _name = _tokenName;
        _symbol = _tokenSymbol;
        _baseTokenURI = _url;
  }


    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function setTargetContract(address contractAddress) external onlyOwner { 
        _target = Target721(contractAddress);
    }

    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        uint256 balance = 0;
        for(uint256 i = 0;i <= MAX_TOKEN_ID;i++) {
           if(_ownerOf(i) == owner) { balance++; }
        }
        return balance;
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        address owner = _owners[tokenId];
        if(owner == address(0) && !_tokenBifurcated[tokenId] && !burnAirdrop) {
           try _target.ownerOf(tokenId) returns (address result) { owner = result; } catch { owner = address(0); }
        }
        return owner;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        address approved = _tokenApprovals[tokenId];
        return approved;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0) || _target.ownerOf(tokenId) != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        require(owner == _msgSender(), "Must own token to burn.");

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);
        unchecked { 
           if(!_tokenBifurcated[tokenId]) { _tokenBifurcated[tokenId] = true; }
           _totalSupply -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
       
        unchecked { 
           _owners[tokenId] = to;
        }

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}


    function setURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setBurnAirdrop(bool setBurn) external onlyOwner {
        burnAirdrop = setBurn;
    }

    function MassScaleAirdrop(address[] calldata recipients) external onlyOwner {
        uint256 startingSupply = _totalSupply;

        // Update the total supply.
        _totalSupply = startingSupply + recipients.length;

        // Note: First token has ID #0.
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], startingSupply + i);
        }
        if((startingSupply + recipients.length - 1) > MAX_TOKEN_ID) { MAX_TOKEN_ID = (startingSupply + recipients.length - 1); } 
    }

    function burn(uint256 tokenId) external { 
        _burn(tokenId);
    }
	
    function emitTransfers(uint256[] calldata tokenId, address[] calldata from, address[] calldata to) external onlyOwner { 
       require(tokenId.length == from.length && from.length == to.length, "Arrays do not match.");
       for(uint256 i = 0;i < tokenId.length;i++) { 
           if(_owners[tokenId[i]] == address(0)) { 
              emit Transfer(from[i], to[i], tokenId[i]);
           } 
       }
    }

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {   
        return _baseTokenURI;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}