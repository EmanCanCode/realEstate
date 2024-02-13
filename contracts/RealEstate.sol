// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// import erc721 uri storage
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract RealEstate is ERC721URIStorage {
    uint256 public _tokenIds;

    constructor() ERC721("Real Estate", "REAL") {
        mint("https://ipfs.io/ipfs/QmTudSYeM7mz3PkYEWXWqPjomRPHogcMFSq7XAvsvsgAPS");
    }

    function mint(string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds++;
        _mint(msg.sender, _tokenIds);
        _setTokenURI(_tokenIds, tokenURI);

        return _tokenIds;
    }
}