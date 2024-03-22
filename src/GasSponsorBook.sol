// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/access/AccessControl.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IGasSponsorBook.sol";

contract GasSponsorBook is AccessControl, IGasSponsorBook {
    bytes32 public constant SPONSOR_ROLE = keccak256("SPONSOR_ROLE");
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");

    /// storage layout
    IVault public _vault;
    mapping(uint256 => uint256) public _sponsorTickets;
    uint256 public _feePerSponsorTicket = 0.01 ether;

    /// events
    event SponsorUpdate(address indexed sponsor, bool isSponsor);
    event VaultUpdate(address indexed vault);
    event SponsorTicketUpdate(address indexed invoker, uint256 ticket);
    event FeePerSponsorTicketUpdate(uint256 feePerSponsorTicket);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SPONSOR_ROLE, msg.sender);
        _grantRole(CONSUMER_ROLE, msg.sender);
    }

    /// admin
    function setVault(IVault vault) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _vault = vault;
        emit VaultUpdate(address(vault));
    }

    function setFeePerSponsorTicket(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _feePerSponsorTicket = fee;
        emit FeePerSponsorTicketUpdate(fee);
    }

    /// view

    function feePerSponsorTicket() public view returns (uint256) {
        return _feePerSponsorTicket;
    }

    function sponsorTickets(uint256 ticket) public view returns (uint256) {
        return _sponsorTickets[ticket];
    }

    /// public
    function addSponsorTicket(uint256 ticket) public payable onlyRole(SPONSOR_ROLE) {
        require(msg.value >= _feePerSponsorTicket, "!fee-not-enough");
        _vault.transferIn{value: msg.value}(address(0), msg.sender, msg.value);
        _sponsorTickets[ticket] += 1;
        emit SponsorTicketUpdate(msg.sender, ticket);
    }

    function consumeSponsorTicket(uint256 ticket, address consumer) public onlyRole(SPONSOR_ROLE) {
        require(_sponsorTickets[ticket] > 0, "!ticket-not-enough");
        require(_feePerSponsorTicket <= address(_vault).balance, "!vault-balance-not-enough");
        require(hasRole(CONSUMER_ROLE, consumer), "!consumer-not-permitted");
        _sponsorTickets[ticket] -= 1;
        _vault.transferOut(address(0), consumer, _feePerSponsorTicket);
    }
}
