// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import "../libraries/LibAppStorage.sol";
import "../../shared/interfaces/IERC20.sol";
import "../../shared/libraries/LibStrings.sol";
import "../../shared/libraries/LibDiamond.sol";
import "../../shared/libraries/LibERC20.sol";

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface ERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    ///  after a `transfer`. This function MAY throw to revert and reject the
    ///  transfer. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}

contract AavegotchiFacet {
    AppStorage internal s;
    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;

    /***********************************|
   |             Events                |
   |__________________________________*/

    // event AavegotchiBatched(uint256 indexed _batchId, uint256[] tokenIds);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /***********************************|
   |             Read Functions         |
   |__________________________________*/

    function totalSupply() external view returns (uint256 totalSupply_) {
        totalSupply_ = s.totalSupply;
    }

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this.
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return balance_ The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256 balance_) {
        balance_ = s.aavegotchiBalance[_owner];
    }

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return owner_ The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address owner_) {
        owner_ = s.aavegotchis[_tokenId].owner;
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return approved_ The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address approved_) {
        require(s.aavegotchis[_tokenId].owner != address(0), "AavegotchiFacet: tokenId is invalid or is not owned");
        approved_ = s.approved[_tokenId];
    }

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return approved_ True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool approved_) {
        approved_ = s.operators[_owner][_operator];
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param _data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external {
        internalTransferFrom(_from, _to, _tokenId);
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        if (size > 0) {
            require(
                ERC721_RECEIVED == ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data),
                "ERC721: Transfer rejected/failed by _to"
            );
        }
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        internalTransferFrom(_from, _to, _tokenId);
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        if (size > 0) {
            require(
                ERC721_RECEIVED == ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, ""),
                "ERC721: Transfer rejected/failed by _to"
            );
        }
    }

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        internalTransferFrom(_from, _to, _tokenId);
    }

    // This function is used by transfer functions
    function internalTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        require(_to != address(0), "ER721: Can't transfer to 0 address");
        address owner = s.aavegotchis[_tokenId].owner;
        require(owner != address(0), "ERC721: Invalid tokenId or can't be transferred");
        require(
            msg.sender == owner || s.operators[owner][msg.sender] || s.approved[_tokenId] == msg.sender,
            "AavegotchiFacet: Not owner or approved to transfer"
        );
        require(_from == owner, "ERC721: _from is not owner, transfer failed");
        s.aavegotchis[_tokenId].owner = _to;
        s.aavegotchiBalance[_from]--;
        s.aavegotchiBalance[_to]++;
        if (s.approved[_tokenId] != address(0)) {
            delete s.approved[_tokenId];
            emit Approval(owner, address(0), _tokenId);
        }
        emit Transfer(_from, _to, _tokenId);
    }

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external {
        address owner = s.aavegotchis[_tokenId].owner;
        require(owner == msg.sender || s.operators[owner][msg.sender], "ERC721: Not owner or operator of token.");
        s.approved[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external {
        s.operators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function name() external pure returns (string memory) {
        return "Aavegotchi";
    }

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external pure returns (string memory) {
        return "GOTCHI";
    }

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external pure returns (string memory) {
        string memory uid = LibStrings.uintStr(_tokenId);
        return string(abi.encodePacked("https://aavegotchi.com/metadata/aavegotchis/", uid)); //Here is your URL!
    }
}