// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract GiftedNFTFactory is Ownable {
    /// storage
    address[] public _monitorNFTCollections;

    /// event
    event MonitorNFTCollection(address nft);
    event UnmonitorNFTCollection(address nft);
    event ResetMonitorNFTCollections(address[] nfts);
    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() Ownable(msg.sender) {}

    function monitorNFTCollections(address[] memory nfts) external onlyOwner {
        for (uint256 i = 0; i < nfts.length; ++i) {
            address nft = nfts[i];
            _monitorNFTCollections.push(nft);
            emit MonitorNFTCollection(nft);
        }
    }

    function unmonitorNFTCollections(address[] memory nfts) external onlyOwner {
        for (uint256 i = 0; i < nfts.length; ++i) {
            address nft = nfts[i];
            for (uint256 j = 0; j < _monitorNFTCollections.length; ++j) {
                if (_monitorNFTCollections[j] == nft) {
                    _monitorNFTCollections[j] = _monitorNFTCollections[_monitorNFTCollections.length - 1];
                    _monitorNFTCollections.pop();
                    emit UnmonitorNFTCollection(nft);
                    break;
                }
            }
        }
    }

    function resetMonitorNFTCollections(address[] memory nfts) external onlyOwner {
        _monitorNFTCollections = nfts;
        emit ResetMonitorNFTCollections(nfts);
    }

    function getMonitorNFTCollections() external view returns (address[] memory) {
        return _monitorNFTCollections;
    }
}
