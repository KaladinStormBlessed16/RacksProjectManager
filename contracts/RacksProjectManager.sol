//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRacksProjectManager.sol";
import "./interfaces/IHolderValidation.sol";
import "./Project.sol";
import "./Err.sol";
import "./library/StructuredLinkedList.sol";
import "./library/Math.sol";

/**
 * 
 *               ▟██████████   █████    ▟███████████   █████████████
 *             ▟████████████   █████  ▟█████████████   █████████████   ███████████▛
 *            ▐█████████████   █████▟███████▛  █████   █████████████   ██████████▛
 *             ▜██▛    █████   ███████████▛    █████       ▟██████▛    █████████▛
 *               ▀     █████   █████████▛      █████     ▟██████▛
 *                     █████   ███████▛      ▟█████▛   ▟██████▛
 *    ▟█████████████   ██████              ▟█████▛   ▟██████▛   ▟███████████████▙
 *   ▟██████████████   ▜██████▙          ▟█████▛   ▟██████▛   ▟██████████████████▙
 *  ▟███████████████     ▜██████▙      ▟█████▛   ▟██████▛   ▟█████████████████████▙
 *                         ▜██████▙            ▟██████▛          ┌────────┐
 *                           ▜██████▙        ▟██████▛            │  LABS  │
 *                                                               └────────┘
 */

/**
 * @title RacksProjectManager
 * @author KaladinStormblessed16 and Daniel Sintimbrean
 * 
 * Powered by RacksLabs
 */
contract RacksProjectManager is
	IRacksProjectManager,
	Initializable,
	OwnableUpgradeable,
	AccessControlUpgradeable
{
	/// interfaces
	/// @custom:oz-upgrades-unsafe-allow state-variable-immutable
	IHolderValidation private immutable holderValidation;
	IERC20 private erc20;

	/// State variables
	bytes32 private constant ADMIN_ROLE = 0x00;
	address[] private contributors;
	bool private paused;
	uint256 private progressiveId;

	using StructuredLinkedList for StructuredLinkedList.List;
	StructuredLinkedList.List private projectsList;
	mapping(uint256 => Project) private projectStore;

	mapping(address => bool) private accountIsBanned;
	mapping(address => uint256) private projectId;
	mapping(address => Contributor) private contributorsData;
	mapping(string => bool) private projectNameExists;

	/**
	 * @dev Only callable by Admins
	 */
	modifier onlyAdmin() {
		if (!hasRole(ADMIN_ROLE, msg.sender)) revert RacksProjectManager_NotAdminErr();
		_;
	}

	/**
	 * @dev Only callable by Holders or Admins
	 */
	modifier onlyHolder() {
		if (
			!isHolder(msg.sender) &&
			!hasRole(ADMIN_ROLE, msg.sender)
		) revert RacksProjectManager_NotHolderErr();
		_;
	}

	/**
	 * @dev Only callable when contract is not paused
	 */
	modifier isNotPaused() {
		if (paused) revert RacksProjectManager_IsPausedErr();
		_;
	}

	///////////////////
	//   Constructor //
	///////////////////

	/// @custom:oz-upgrades-unsafe-allow constructor
	/**
	 * @param _holderValidation Address of the contract that validates the holders
	 */
	constructor(IHolderValidation _holderValidation) {
		holderValidation = _holderValidation;
	}

	///////////////////
	//   Initialize  //
	///////////////////
	/**
	 * @param _erc20 Address of the ERC20 token
	 */
	function initialize(IERC20 _erc20) external initializer {
		erc20 = _erc20;
		__Ownable_init();
		__AccessControl_init();
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	///////////////////////
	//  Logic Functions  //
	///////////////////////

	/**
	 * @notice Create Project
	 * @dev Only callable by Admins
	 */
	function createProject(
		string calldata _name,
		uint256 _colateralCost,
		uint256 _reputationLevel,
		uint256 _maxContributorsNumber
	) external isNotPaused {
		if (
			_colateralCost < 0 ||
			_reputationLevel <= 0 ||
			_maxContributorsNumber <= 0 ||
			bytes(_name).length <= 0 ||
			bytes(_name).length > 30
		) revert RacksProjectManager_InvalidParameterErr();

		Project newProject = new Project(
			this,
			_name,
			_colateralCost,
			_reputationLevel,
			_maxContributorsNumber
		);

		unchecked{
			++progressiveId;
		}
		projectStore[progressiveId] = newProject;
		projectId[address(newProject)] = progressiveId;
		projectsList.pushFront(progressiveId);

		_setupRole(ADMIN_ROLE, address(newProject)); 

		projectNameExists[_name] = true;
		emit NewProjectCreated(_name, address(newProject));
	}

	/**
	 * @notice Add Contributor
	 * @dev Only callable by Holders who are not already Contributors
	 */
	function registerContributor() external onlyHolder isNotPaused {
		if (isWalletContributor(msg.sender))
			revert RacksProjectManager_ContributorAlreadyExistsErr();

		contributors.push(msg.sender);
		contributorsData[msg.sender] = Contributor(msg.sender, 0, false);
		emit NewContributorRegistered(msg.sender);
	}

	///////////////////////
	//  Setter Functions //
	///////////////////////

	/**
	 * @notice Set new Admin
	 * @dev Only callable by the Admin
	 */
	function addAdmin(address _newAdmin) external onlyOwner {
		grantRole(ADMIN_ROLE, _newAdmin);
	}

	/**
	 * @notice Remove an account from the user role
	 * @dev Only callable by the Admin
	 */
	function removeAdmin(address _account) external virtual onlyOwner {
		revokeRole(ADMIN_ROLE, _account);
	}

	/**
	 * @notice Set new ERC20 Token
	 * @dev Only callable by the Admin
	 */
	function setERC20Address(address _erc20) external onlyAdmin {
		erc20 = IERC20(_erc20);
	}

	/**
	 * @notice Set a ban state for a Contributor
	 * @dev Only callable by Admins.
	 */
	function setContributorStateToBanList(
		address _account,
		bool _state
	) external onlyAdmin {
		accountIsBanned[_account] = _state;

		if (_state == true) {
			(bool existNext, uint256 i) = projectsList.getNextNode(0);

			while (i != 0 && existNext) {
				Project project = projectStore[i];
				if (
					project.isActive() &&
					project.isContributorInProject(_account)
				) {
					project.removeContributor(_account, false);
				}
				(existNext, i) = projectsList.getNextNode(i);
			}
		}
	}

	/**
	 * @inheritdoc IRacksProjectManager
	 */
	function setAccountToContributorData(
		address _account,
		Contributor memory _newData
	) public override onlyAdmin {
		contributorsData[_account] = _newData;
	}

	/**
	 * @notice Increase Contributor's Reputation Points if
	 * @param _grossReputationPoints is the amount of reputation points to increase or decrease
	 * @param _add is true, otherwise it reduces
	 */
	function modifyContributorRP(
		address _account,
		uint256 _grossReputationPoints,
		bool _add
	) public override onlyAdmin {
		if (_grossReputationPoints <= 0) revert RacksProjectManager_InvalidParameterErr();

		Contributor memory contributor = contributorsData[_account];

		if (_add) {
			contributor.reputationPoints += _grossReputationPoints;
		} else {
			contributor.reputationPoints -= _grossReputationPoints;
		}

		contributorsData[_account] = contributor;
	}

	/**
	 * @notice Set new paused state
	 * @param _newPausedValue New paused state
	 */
	function setIsPaused(bool _newPausedValue) public onlyAdmin {
		paused = _newPausedValue;
	}

	/**
	 * @notice Return the the level of a Contributor based on the total reputation points
	 * @dev The level is calculated based on the lazy caterer's sequence
	 * @dev Example :
	 *  0    points -> level 1
	 * 	100  points -> level 2
	 * 	200  points -> level 3
	 * 	400  points -> level 4
	 * 	700  points -> level 5
	 * 	1100 points -> level 6
	 * 	1600 points -> level 7
	 * 	2200 points -> level 8
	 * 	2900 points -> level 9
	 * 	3700 points -> level 10
	 * @param totalPoints Total Reputation Points of a Contributor
	 */
	function calculateLevel(
		uint256 totalPoints
	) public pure override returns (uint256) {
		if (totalPoints < 100) return 1;

		uint256 points = totalPoints / 100;
		return ((MathLib.sqrt(8 * points - 7) - 1) / 2) + 2;
	}

	////////////////////////
	//  Getter Functions //
	//////////////////////

	/// @inheritdoc IRacksProjectManager
	function isAdmin(address _account) public view override returns (bool) {
		return hasRole(ADMIN_ROLE, _account);
	}

	/** 
	 * @notice Returns Holder Validation contract address
	 */
	function getHolderValidationInterface()
		external
		view
		returns (IHolderValidation)
	{
		return holderValidation;
	}

	/** 
	 * @inheritdoc IRacksProjectManager
	 */ 
	function getERC20Interface() public view override returns (IERC20) {
		return erc20;
	}

	/**
	 * @inheritdoc IRacksProjectManager
	 */
	function getRacksPMOwner() public view override returns (address) {
		return owner();
	}

	/** 
	 * @inheritdoc IRacksProjectManager
	 */
	function isContributorBanned(
		address _account
	) external view override returns (bool) {
		return accountIsBanned[_account];
	}

	/**
	 * @notice Get projects depending on Level
	 * @dev Only callable by Holders
	 */
	function getProjects() public view onlyHolder returns (Project[] memory) {
		if (hasRole(ADMIN_ROLE, msg.sender)) return getAllProjects();
		Project[] memory filteredProjects = new Project[](
			projectsList.sizeOf()
		);

		unchecked {
			uint256 callerReputationLv = getContributorLevel(msg.sender);

			uint256 j = 0;
			(bool existNext, uint256 i) = projectsList.getNextNode(0);

			while (i != 0 && existNext) {
				if (
					projectStore[i].getReputationLevel() <= callerReputationLv
				) {
					filteredProjects[j] = projectStore[i];
					++j;
				}
				(existNext, i) = projectsList.getNextNode(i);
			}
		}

		return filteredProjects;
	}

	/** 
	 * @notice Returns true if _account is have at least one NFT of the collections 
	 * authorized otherwise returns false
	 * 
	 * @param _account Address of the account to check
	 */
	function isHolder(address _account) public view returns (bool) {
		return holderValidation.isHolder(_account) != address(0);
	}

	function getAllProjects() private view returns (Project[] memory) {
		Project[] memory allProjects = new Project[](projectsList.sizeOf());

		uint256 j = 0;
		(bool existNext, uint256 i) = projectsList.getNextNode(0);

		unchecked{
			while (i != 0 && existNext) {
				allProjects[j] = projectStore[i];
				++j;
				(existNext, i) = projectsList.getNextNode(i);
			}
		}

		return allProjects;
	}

	/** 
	 * @inheritdoc IRacksProjectManager
	 */ 
	function isWalletContributor(
		address _account
	) public view override returns (bool) {
		return contributorsData[_account].wallet != address(0);
	}

	/**
	 * @notice Get the level of a Contributor
	 * @param _account Address of the Contributor
	 */
	function getContributorLevel(
		address _account
	) public view returns (uint256) {
		uint256 point = contributorsData[_account].reputationPoints;
		return calculateLevel(point);
	}

	/** 
	 * @inheritdoc IRacksProjectManager
	 */
	function getContributorData(
		address _account
	) public view override returns (Contributor memory) {
		return contributorsData[_account];
	}

	/**
	 * @notice Get total number of contributors
	 * @dev Only callable by Holders
	 */
	function getNumberOfContributors()
		external
		view
		onlyHolder
		returns (uint256)
	{
		return contributors.length;
	}

	/**
	 * @inheritdoc IRacksProjectManager
	 */ 
	function isPaused() external view override returns (bool) {
		return paused;
	}

	/**
	 * @inheritdoc IRacksProjectManager
	 */ 
	function deleteProject() external override {
		uint256 id = projectId[msg.sender];

		if (id == 0) revert RacksProjectManager_InvalidParameterErr();

		projectNameExists[projectStore[id].getName()] = false;

		projectId[msg.sender] = 0;
		projectsList.remove(id);
	}
}
