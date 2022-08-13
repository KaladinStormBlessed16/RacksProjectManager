//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/// @notice struct Contributor when a holder has been registered
struct Contributor {
    address wallet;
    uint256 reputationLevel;
    uint256 reputationPoints;
    bool banned;
}
