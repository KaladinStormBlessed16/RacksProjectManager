//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Project.sol";
import "../Contributor.sol";
import "./IMRC.sol";
import "../Err.sol";

interface IRacksProjectManager {
    /// @notice Events
    event newContributorRegistered(address newContributor);
    event newProjectCreated(string name, address newProjectAddress);

    function isAdmin(address account) external view returns (bool);

    function getERC20Interface() external view returns (IERC20);

    function getRacksPMOwner() external view returns (address);

    function isWalletContributor(address account) external view returns (bool);

    function isContributorBanned(address account) external view returns (bool);

    function getContributorData(address account) external view returns (Contributor memory);

    function setAccountToContributorData(address account, Contributor memory newData) external;

    function isPaused() external view returns (bool);

    function deleteProject() external;
}
