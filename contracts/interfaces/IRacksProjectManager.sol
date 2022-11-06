//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IHolderValidation.sol";
import "../Project.sol";
import "../Contributor.sol";
import "../Err.sol";

interface IRacksProjectManager {
    /////////////////
    ///   Events  ///
    /////////////////

    /**
     * @notice Event emitted when a new contributor is registered in RacksProjectManager
     */
    event newContributorRegistered(address newContributor);

    /**
     * @notice Event emitted when a new project is created in RacksProjectsManager
     */
    event newProjectCreated(string name, address newProjectAddress);

    /////////////////////////////
    ///   Abstract functions  ///
    /////////////////////////////

    /**
     * @notice Returns true if @param _account is admin in RacksProjectsManager otherwise returns false
     */
    function isAdmin(address _account) external view returns (bool);

    /**
     * @notice Get the address of the ERC20 used in RacksProjectsManger for colateral in projects
     */
    function getERC20Interface() external view returns (IERC20);

    /**
     * @notice Get the address of the owner of the contract
     */
    function getRacksPMOwner() external view returns (address);

    /**
     * @notice Returns true if @pram _account is registered as contributors otherwise return false
     */
    function isWalletContributor(address _account) external view returns (bool);

    /**
     * @notice Returns true if @pram _account is banned otherwise return false
     */
    function isContributorBanned(address _account) external view returns (bool);

    /**
     * @notice Returns all the data associated with @param _account contributor
     */
    function getContributorData(address _account) external view returns (Contributor memory);

    /**
     * @notice Update contributor data associated with @param _account contributor
     */
    function setAccountToContributorData(address _account, Contributor memory _newData) external;

    /**
     * @notice Return true if the RacksProjectsManager is paused, otherwise false
     */
    function isPaused() external view returns (bool);

    /**
     * @notice Deletes the project associated with the address of msg.sender Delete the project
     * @dev This function is called from Projects contracts when is deleted
     */
    function deleteProject() external;
}
