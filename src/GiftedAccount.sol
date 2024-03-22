// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/Strings.sol";
import "@openzeppelin/utils/Address.sol";
import "@openzeppelin/utils/cryptography/SignatureChecker.sol";

import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/interfaces/IERC1271.sol";
import "@openzeppelin/token/ERC1155/IERC1155.sol";
import "erc6551/interfaces/IERC6551Account.sol";
import "erc6551/lib/ERC6551AccountLib.sol";
import "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IGiftedAccountGuardian.sol";
import "./interfaces/IGiftedAccount.sol";

error UntrustedImplementation();
error NotAuthorized();

contract GiftedAccount is
    IERC165,
    IERC1271,
    IERC721Receiver,
    IERC1155Receiver,
    IERC6551Account,
    IGiftedAccount,
    Initializable
{
    using Strings for uint256;
    using Strings for address;
    /// storage
    /// @dev AccountGuardian contract address

    IGiftedAccountGuardian private _guardian;

    uint256 public _nonce;

    constructor() {}

    function initialize(address guardian) public initializer {
        _guardian = IGiftedAccountGuardian(guardian);
    }
    /// events

    event CallPermit(address indexed owner, address indexed to, uint256 nonce, uint256 deadline);

    // Event to log the transfer of an ERC1155 token with a permit
    event CallTransferERC1155Permit(
        address indexed from,
        address indexed to,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        address signer,
        address relayer
    );
    /// @notice Emitted when ETH is added to the account
    /// @param sender The address that sent the ETH
    /// @param amount The amount of ETH sent
    /// @param newBalance The new balance of the account
    event ReceivedEther(address indexed sender, uint256 amount, uint256 newBalance);

    event AccountGuardianUpgraded(address indexed previousGuardian, address indexed newGuardian);
    /// modifier

    /// @dev reverts if caller is not authorized to execute on this account
    modifier onlyAuthorized() {
        if (!isAuthorized(msg.sender)) revert NotAuthorized();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner()) revert NotAuthorized();
        _;
    }

    // ======== ERC6551 Interface ========
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value, address(this).balance);
    }

    function executeCall(address to, uint256 value, bytes calldata data)
        external
        payable
        onlyAuthorized
        returns (bytes memory result)
    {
        return call(to, value, data);
    }

    function token() public view returns (uint256, address, uint256) {
        return ERC6551AccountLib.token();
    }

    function nonce() public view returns (uint256) {
        return _nonce;
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        if (chainId != block.chainid) revert("!chainid-not-equal-block-chainid");

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    // ======== ERC165 Interface ========
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (
            interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
                || interfaceId == type(IERC6551Account).interfaceId
        );
    }

    // ======== ERC1271 Interface ========
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }
        return "";
    }

    // ============ ERC721Receiver Interface ============
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // ============ ERC1155Receiver Interface ============
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
    /// EIP 712
    /// domain separator

    function name() public pure returns (string memory) {
        return "GiftedAccount";
    }

    // Returns the domain separator, updating it if chainID changes
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /// internal
    /// @dev Returns the authorization status for a given caller
    function isAuthorized(address caller) public view returns (bool) {
        if (caller == owner()) return true;

        if (address(_guardian) != address(0) && _guardian.isExecutor(caller)) return true;

        return false;
    }

    /// @dev check if it is the token owner of the account
    function isOwner(address caller) public view returns (bool) {
        return caller == owner();
    }

    // @dev set account guardian to another address, only owner can call this function
    function setAccountGuardian(address guardian) external onlyOwner {
        emit AccountGuardianUpgraded(address(_guardian), guardian);
        _guardian = IGiftedAccountGuardian(guardian);
    }

    function getGuardian() public view returns (IGiftedAccountGuardian) {
        return _guardian;
    }

    function _incrementNonce() internal {
        _nonce++;
    }

    function call(address to, uint256 value, bytes calldata data) internal returns (bytes memory result) {
        _incrementNonce();

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert("ECDSA: invalid signature 's' value");
        }

        if (v != 27 && v != 28) {
            revert("ECDSA: invalid signature 'v' value");
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    // d83869c5bb54ba35eb2fa505a0206fde32206a3325ac92b027126dca04d8cdae
    bytes32 public constant CALL_PERMIT_TYPEHASH =
        keccak256("CallPermit(address to, uint256 value, byte data, uint256 deadline, uint256 nonce)");

    /// external

    function getTypedCallPermitHash(address to, uint256 value, bytes calldata data, uint256 deadline)
        public
        view
        returns (bytes32 callHash)
    {
        bytes32 hashStruct = keccak256(abi.encode(CALL_PERMIT_TYPEHASH, to, value, data, deadline, nonce()));
        bytes32 eip712DomainHash = domainSeparator();
        callHash = keccak256(abi.encodePacked(uint16(0x1901), eip712DomainHash, hashStruct));
    }

    function getTypedCallPermitHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 deadline,
        uint256 encodeNonce
    ) public view returns (bytes32 callHash) {
        bytes32 hashStruct = keccak256(abi.encode(CALL_PERMIT_TYPEHASH, to, value, data, deadline, encodeNonce));
        bytes32 eip712DomainHash = domainSeparator();
        callHash = keccak256(abi.encodePacked(uint16(0x1901), eip712DomainHash, hashStruct));
    }

    function executeTypedCallPermit(
        address to,
        uint256 value,
        bytes calldata data,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable returns (bytes memory result) {
        require(block.timestamp <= deadline, "!call-permit-expired");
        bytes32 callHash = getTypedCallPermitHash(to, value, data, deadline);
        address signer = _recover(callHash, v, r, s);
        require(signer == owner(), "!call-permit-invalid-signature");

        emit CallPermit(signer, to, nonce(), deadline);

        return call(to, value, data);
    }

    event CallTransferNFTPermit(
        address indexed from,
        address indexed to,
        address indexed nft,
        uint256 tokenId,
        uint256 deadline,
        uint256 nonce,
        address signer,
        address relayer
    );

    function transferToken(
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "!call-permit-expired");
        string memory message = getTransferNFTPermitMessage(tokenContract, tokenId, to, deadline);
        bytes32 signHash = toEthPersonalSignedMessageHash(bytes(message));

        address signer = _recover(signHash, v, r, s);
        require(signer == owner(), "!transfer-permit-invalid-signature");

        IERC721(tokenContract).safeTransferFrom(address(this), to, tokenId);
        emit CallTransferNFTPermit(address(this), to, tokenContract, tokenId, deadline, nonce(), signer, msg.sender);
    }

    function getTransferNFTPermitMessage(address tokenContract, uint256 tokenId, address to, uint256 deadline)
        public
        view
        returns (string memory)
    {
        return string.concat(
            "I want to transfer NFT",
            "\n From: ",
            address(this).toHexString(),
            "\n NFT: ",
            tokenContract.toHexString(),
            "\n TokenId: ",
            tokenId.toString(),
            "\n To: ",
            to.toHexString(),
            "\n Before: ",
            deadline.toString(),
            ".",
            "\n Nonce: ",
            nonce().toString(),
            "\n Chain ID: ",
            block.chainid.toString(),
            "\n BY: ",
            name(),
            "\n Version: ",
            "0.0.1"
        );
    }

    // Method to transfer ERC1155 tokens with a permit
    function transferERC1155Token(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "!call-permit-expired");
        string memory message = getTransferERC1155PermitMessage(tokenContract, tokenId, amount, to, deadline);
        bytes32 signHash = toEthPersonalSignedMessageHash(bytes(message));

        address signer = ECDSA.recover(signHash, v, r, s);
        require(signer == owner(), "!transfer-permit-invalid-signature");

        IERC1155(tokenContract).safeTransferFrom(address(this), to, tokenId, amount, "");
        emit CallTransferERC1155Permit(
            address(this), to, tokenContract, tokenId, amount, deadline, nonce(), signer, msg.sender
        );
    }

    // Method to create a message for ERC1155 token transfer with a permit
    function getTransferERC1155PermitMessage(
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline
    ) public view returns (string memory) {
        return string.concat(
            "I authorize the transfer of ERC1155 tokens",
            "\n Token Contract: ",
            Strings.toHexString(uint256(uint160(tokenContract)), 20),
            "\n Token ID: ",
            Strings.toString(tokenId),
            "\n Amount: ",
            Strings.toString(amount),
            "\n To: ",
            Strings.toHexString(uint256(uint160(to)), 20),
            "\n Deadline: ",
            Strings.toString(deadline),
            "\n Nonce: ",
            nonce().toString(),
            "\n Chain ID: ",
            block.chainid.toString(),
            "\n BY: ",
            name(),
            "\n Version: ",
            "0.0.1"
        );
    }

    function toEthPersonalSignedMessageHash(bytes memory _msg) public pure returns (bytes32 signHash) {
        signHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _msg.length.toString(), _msg));
    }
}
