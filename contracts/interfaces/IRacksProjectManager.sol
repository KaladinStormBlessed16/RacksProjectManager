//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Contributor.sol";

interface IRacksProjectManager {
	/////////////////
	///   Events  ///
	/////////////////

	/**
	 * @notice Event emitted when a new contributor is registered in RacksProjectManager
	 */
	event NewContributorRegistered(address newContributor);

	/**
	 * @notice Event emitted when a new project is created in RacksProjectsManager
	 */
	event NewProjectCreated(
		bytes32 indexed indexedName,
		string name,
		address newProjectAddress
	);

	/**
	 * @notice Event emitted when a project is deleted in RacksProjectsManager
	 */
	event ProjectDeleted(address indexed deletedProjectAddress);

	/**
	 * @notice Event emitted when a project is finished in RacksProjectsManager
	 */
	event ProjectFinished(address indexed finishedProjectAddress);

	/**
	 * @notice
	 */
	event ProjectApproved(address indexed provedProjectAddress);

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
	function getContributorData(
		address _account
	) external view returns (Contributor memory);

	/**
	 * @notice Update contributor data associated with @param _account contributor
	 */
	function setAccountToContributorData(
		address _account,
		Contributor memory _newData
	) external;

	/**
	 * @notice Return true if the RacksProjectsManager is paused, otherwise false
	 */
	function isPaused() external view returns (bool);

	/**
	 * @notice Deletes the project associated with the address of msg.sender
	 * @dev This function is called from Projects contracts when is deleted
	 */
	function deleteProject() external;

	/**
	 * @notice Finish the project associated with the address of msg.sender
	 * @dev This function is called from Projects contracts when is deleted
	 */
	function finishProject() external;

	/**
	 * @notice Approve the project associated with the address of msg.sender
	 * @dev This function is called from Projects contracts when is deleted
	 */
	function approveProject() external;

	function calculateLevel(uint256 totalPoints) external returns (uint256);

	function modifyContributorRP(
		address _account,
		uint256 grossReputationPoints,
		bool add
	) external;
}
