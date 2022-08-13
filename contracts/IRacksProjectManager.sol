//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Project.sol";
import "./Contributor.sol";
import "./IMRC.sol";
import "./Err.sol";

interface IRacksProjectManager {
    /// @notice Events
    event newContributorRegistered(address newContributor);
    event newProjectCreated(address newProjectAddress);

    function isAdmin(address account) external view returns (bool);

    function getMRCAddress() external view returns (IMRC);

    function getERC20Address() external view returns (IERC20);

    function isWalletContributor(address account) external view returns (bool);

    function getAccountToContributorData(address account)
        external
        view
        returns (Contributor memory);
}
