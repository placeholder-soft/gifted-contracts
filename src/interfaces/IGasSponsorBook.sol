// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./IVault.sol";

interface IGasSponsorBook {
    function setVault(IVault vault) external;
    function setFeePerSponsorTicket(uint256 feePerSponsorTicket) external;
    function addSponsorTicket(uint256 ticket) external payable;
    function consumeSponsorTicket(uint256 ticket, address sponsor) external;
    function feePerSponsorTicket() external view returns (uint256);
    function sponsorTickets(uint256 ticket) external view returns (uint256);
}
