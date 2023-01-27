//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IRacksProjectManager.sol";
import "./Contributor.sol";
import "./Err.sol";
import "./library/StructuredLinkedList.sol";

contract Project is Ownable, AccessControl {
	/// Events
	event NewProjectContributorsRegistered(
		address projectAddress,
		address newProjectContributor
	);
	event ProjectFunded(
		address projectAddress,
		address funderWallet,
		uint256 amount
	);

	/// Enumerations
	enum ProjectState {
		Pending,
		Active,
		Finished,
		Deleted
	}

	/// Constants
	ProjectState private constant PENDING = ProjectState.Pending;
	ProjectState private constant ACTIVE = ProjectState.Active;
	ProjectState private constant FINISHED = ProjectState.Finished;
	ProjectState private constant DELETED = ProjectState.Deleted;
	bytes32 private constant ADMIN_ROLE = 0x00;

	/// Interfaces
	IRacksProjectManager private immutable racksPM;

	/// Contributors List
	using StructuredLinkedList for StructuredLinkedList.List;
	StructuredLinkedList.List private contributorList;

	uint256 private progressiveId = 0;
	mapping(uint256 => Contributor) private projectContributors;
	mapping(address => uint256) private contributorId;
	mapping(address => uint256) private participationOfContributors;
	mapping(address => uint256) private projectFunds;

	/// State variables
	string private name;
	uint256 private colateralCost;
	uint256 private reputationLevel;
	uint256 private maxContributorsNumber;
	uint256 private totalAmountFunded;
	address[] public funders;
	ProjectState private projectState;
	IERC20 private immutable erc20racksPM;

	/**
	 *  @notice Check that the project has no contributors, therefore is editable
	 */
	modifier isEditable() {
		if (contributorList.sizeOf() > 0) revert Project_IsNotEditableErr();
		_;
	}

	/**
	 *  @notice Check that the project is not finished
	 */
	modifier isNotFinished() {
		if (projectState == FINISHED) revert Project_FinishedErr();
		_;
	}

	/**
	 * @notice Check that sender is Admin
	 */ 
	modifier onlyAdmin() {
		if (!hasRole(ADMIN_ROLE, msg.sender)) revert Project_NotAdminErr();
		_;
	}

	/**
	 * @notice Check that sender is Contributor
	 */
	modifier onlyContributor() {
		if (!racksPM.isWalletContributor(msg.sender)) revert Project_IsNotContributor();
		_;
	}

	/**
	 * @notice Check that the smart contract is not Paused
	 */ 
	modifier isNotPaused() {
		if (racksPM.isPaused()) revert Project_IsPausedErr();
		_;
	}

	/** 
	 * @notice Check that the smart contract is not Pending
	 */ 
	modifier isNotPending() {
		if (projectState == PENDING) revert Project_IsPendingErr();
		_;
	}

	/**
	 * @notice Check that the smart contract is not Deleted
	 */ 
	modifier isNotDeleted() {
		if (projectState == DELETED) revert Project_IsDeletedErr();
		_;
	}

	/**
	 * @notice Constructor
	 * @param _racksPM RacksProjectManager address
	 * @param _name Project name
	 * @param _colateralCost Colateral cost to register as Contributor
	 * @param _reputationLevel Reputation level to register as Contributor
	 * @param _maxContributorsNumber Max number of Contributors
	 */
	constructor(
		IRacksProjectManager _racksPM,
		string memory _name,
		uint256 _colateralCost,
		uint256 _reputationLevel,
		uint256 _maxContributorsNumber
	) {
		racksPM = _racksPM;
		name = _name;
		colateralCost = _colateralCost;
		reputationLevel = _reputationLevel;
		maxContributorsNumber = _maxContributorsNumber;
		_setupRole(ADMIN_ROLE, msg.sender);
		_setupRole(ADMIN_ROLE, _racksPM.getRacksPMOwner());
		erc20racksPM = _racksPM.getERC20Interface();
		projectState = PENDING;
	}

	////////////////////////
	//  Logic Functions  //
	//////////////////////

	/**
	 * @notice Add Project Contributor
	 * @dev Only callable by Holders who are already Contributors
	 */
	function registerProjectContributor()
		external
		onlyContributor
		isNotFinished
		isNotPaused
		isNotDeleted
		isNotPending
	{
		if (isContributorInProject(msg.sender))
			revert Project_ContributorAlreadyExistsErr();
		if (contributorList.sizeOf() == maxContributorsNumber)
			revert Project_MaxContributorNumberExceededErr();

		Contributor memory contributor = racksPM.getContributorData(msg.sender);

		if (racksPM.isContributorBanned(contributor.wallet))
			revert Project_ContributorIsBannedErr();

		if (
			racksPM.calculateLevel(contributor.reputationPoints) <
			reputationLevel
		) revert Project_ContributorHasNoReputationEnoughErr();

		progressiveId++;
		projectContributors[progressiveId] = contributor;
		contributorList.pushFront(progressiveId);
		contributorId[contributor.wallet] = progressiveId;

		emit NewProjectContributorsRegistered(address(this), msg.sender);
		if (colateralCost > 0) {
			bool success = erc20racksPM.transferFrom(
				msg.sender,
				address(this),
				colateralCost
			);
			if (!success) revert Project_Erc20TransferFailed();
		}
	}

	/**
	 * @notice Finish Project
	 * @dev Only callable by Admins when the project isn't completed
	 * - The contributors and participationWeights array must have the same size of the project contributors list.
	 * - If there is a banned Contributor in the project, you have to pass his address and participation (should be 0) anyways.
	 * - The sum of @param _participationWeights can not be more than 100
	 * @param _totalReputationPointsReward Total reputation points to distribute
	 * @param _contributors Array of contributors addresses
	 * @param _participationWeights Array of participation weights of each contributor (in percentage)
	 */
	function finishProject(
		uint256 _totalReputationPointsReward,
		address[] memory _contributors,
		uint256[] memory _participationWeights
	) external onlyAdmin isNotFinished isNotPaused isNotDeleted isNotPending {
		if (
			_totalReputationPointsReward <= 0 ||
			_contributors.length != contributorList.sizeOf() ||
			_participationWeights.length != contributorList.sizeOf()
		) revert Project_InvalidParameterErr();

		projectState = FINISHED;
		uint256 totalParticipationWeight = 0;
		unchecked {
			for (uint256 i = 0; i < _contributors.length; i++) {
				if (!isContributorInProject(_contributors[i]))
					revert Project_ContributorNotInProject();

				uint256 participationWeight = _participationWeights[i];

				participationOfContributors[
					_contributors[i]
				] = participationWeight;
				totalParticipationWeight += participationWeight;
			}
			if (totalParticipationWeight > 100)
				revert Project_InvalidParameterErr();
		}
		unchecked {
			(bool existNext, uint256 i) = contributorList.getNextNode(0);

			while (i != 0 && existNext) {
				address contrAddress = projectContributors[i].wallet;

				uint256 reputationToIncrease = (_totalReputationPointsReward *
					participationOfContributors[contrAddress]) / 100;

				racksPM.modifyContributorRP(
					contrAddress,
					reputationToIncrease,
					true
				);

				if (colateralCost > 0) {
					bool success = erc20racksPM.transfer(
						contrAddress,
						colateralCost
					);
					if (!success) revert Project_Erc20TransferFailed();
				}

				(existNext, i) = contributorList.getNextNode(i);
			}
		}
		if (erc20racksPM.balanceOf(address(this)) > 0) shareProfits();
	}

	/**
	 * @notice Fund the project with ERC20
	 * @dev This serves as a reward to contributors
	 * @param _amount Amount of the ERC20 to fund the project
	 */
	function fundProject(
		uint256 _amount
	) external isNotPaused isNotDeleted isNotPending {
		if (_amount <= 0 || contributorList.sizeOf() < 1)
			revert Project_InvalidParameterErr();

		totalAmountFunded += _amount;
		projectFunds[msg.sender] += _amount;
		funders.push(msg.sender);
		emit ProjectFunded(address(this), msg.sender, _amount);
		bool success = erc20racksPM.transferFrom(
			msg.sender,
			address(this),
			_amount
		);
		if (!success) revert Project_Erc20TransferFailed();
	}

	/**
	 * @notice Give Away extra rewards
	 * @dev Only callable by Admins when the project is completed
	 */
	function giveAway()
		external
		onlyAdmin
		isNotPaused
		isNotDeleted
		isNotPending
	{
		if (projectState != ProjectState.Finished) revert Project_NotCompletedErr();

		if (
			address(this).balance <= 0 &&
			erc20racksPM.balanceOf(address(this)) <= 0
		) revert Project_NoFundsGiveAwayErr();

		shareProfits();
	}

	////////////////////////
	//  Helper Functions //
	//////////////////////

	/**
	 * @notice Used to give away profits
	 * @dev Only callable by Admins when project completed
	 */
	function shareProfits() private onlyAdmin {
		if (projectState != ProjectState.Finished) revert Project_NotCompletedErr();

		unchecked {
			uint256 projectBalanceERC20 = erc20racksPM.balanceOf(
				address(this)
			);
			uint256 projectBalanceEther = address(this).balance;
			(bool existNext, uint256 i) = contributorList.getNextNode(0);

			while (i != 0 && existNext) {
				address contrAddress = projectContributors[i].wallet;
				if (erc20racksPM.balanceOf(address(this)) > 0) {
					bool successTransfer = erc20racksPM.transfer(
						contrAddress,
						(projectBalanceERC20 *
							participationOfContributors[contrAddress]) / 100
					);
					if (!successTransfer) revert Project_Erc20TransferFailed();
				}

				if (address(this).balance > 0) {
					(bool success, ) = contrAddress.call{
						value: (projectBalanceEther *
							participationOfContributors[contrAddress]) / 100
					}("");
					if (!success) revert Project_TransferGiveAwayFailedErr();
				}
				(existNext, i) = contributorList.getNextNode(i);
			}
		}
	}

	/**
	 * @notice Provides information about supported interfaces (required by AccessControl)
	 */
	function supportsInterface(
		bytes4 _interfaceId
	) public view virtual override returns (bool) {
		return super.supportsInterface(_interfaceId);
	}

	/**
	 * @notice Delete the project and return funds to funders. Only callable by Admins
	 * and only when there are no contributors
	 */
	function deleteProject() public onlyAdmin isNotDeleted isEditable {
		projectState = DELETED;

		racksPM.deleteProject();

		if (erc20racksPM.balanceOf(address(this)) > 0) {
			unchecked {
				// Return funds to funders
				for (uint256 i = 0; i < funders.length; i++) {
					address funder = funders[i];
					uint256 amount = projectFunds[funder];

					if (amount > 0) {
						projectFunds[funder] = 0;
						totalAmountFunded -= amount;
						bool successTransfer = erc20racksPM.transfer(
							funder,
							amount
						);
						if (!successTransfer) revert Project_Erc20TransferFailed();
					}
				}
			}
		}
	}

	/**
	 * @notice Remove a contributor from the project
	 * @param _contributor Address of the contributor to remove
	 * @param _returnColateral If true, the colateral cost will be returned to the contributor
	 */
	function removeContributor(
		address _contributor,
		bool _returnColateral
	) public onlyAdmin isNotDeleted {
		if (!isContributorInProject(_contributor)) revert Project_ContributorNotInProject();

		uint256 id = contributorId[_contributor];
		contributorId[_contributor] = 0;
		contributorList.remove(id);

		if (_returnColateral && colateralCost > 0) {
			bool success = erc20racksPM.transfer(_contributor, colateralCost);
			if (!success) revert Project_Erc20TransferFailed();
		}
	}

	////////////////////////
	//  Setter Functions //
	//////////////////////

	/**
	 * @notice  the Project State
	 * @dev Only callable by Admins when the project has no Contributor yet and is pending.
	 */
	function approveProject() external onlyAdmin isNotPaused isNotDeleted {
		if (projectState == PENDING) projectState = ACTIVE;
	}

	/**
	 * @notice  the Project Name
	 * @dev Only callable by Admins when the project has no Contributor yet.
	 */
	function setName(
		string memory _name
	) external onlyAdmin isEditable isNotPaused isNotDeleted {
		if (bytes(_name).length <= 0) revert Project_InvalidParameterErr();
		name = _name;
	}

	/**
	 * @notice Edit the Colateral Cost
	 * @dev Only callable by Admins when the project has no Contributor yet.
	 */
	function setColateralCost(
		uint256 _colateralCost
	) external onlyAdmin isEditable isNotPaused isNotDeleted {
		if (_colateralCost < 0) revert Project_InvalidParameterErr();
		colateralCost = _colateralCost;
	}

	/**
	 * @notice Edit the Reputation Level
	 * @dev Only callable by Admins when the project has no Contributor yet.
	 */
	function setReputationLevel(
		uint256 _reputationLevel
	) external onlyAdmin isEditable isNotPaused isNotDeleted {
		if (_reputationLevel <= 0) revert Project_InvalidParameterErr();
		reputationLevel = _reputationLevel;
	}

	/**
	 * @notice Edit the Reputation Level
	 * @dev Only callable by Admins when the project has no Contributor yet.
	 */
	function setMaxContributorsNumber(
		uint256 _maxContributorsNumber
	) external onlyAdmin isNotPaused isNotDeleted {
		if (
			_maxContributorsNumber <= 0 ||
			_maxContributorsNumber < contributorList.sizeOf()
		) revert Project_InvalidParameterErr();
		maxContributorsNumber = _maxContributorsNumber;
	}

	////////////////////////
	//  Getter Functions //
	//////////////////////

	/**
	 * @notice Get the project name
	 */
	function getName() external view returns (string memory) {
		return name;
	}

	/**
	 * @notice Get the colateral cost to enter as contributor
	 */
	function getColateralCost() external view returns (uint256) {
		return colateralCost;
	}

	/**
	 * @notice Get the reputation level of the project
	 */ 
	function getReputationLevel() external view returns (uint256) {
		return reputationLevel;
	}

	/** 
	 * @notice Get the maximum contributor that can be in the project
	 */
	function getMaxContributors() external view returns (uint256) {
		return maxContributorsNumber;
	}

	/**
	 * @notice Get total number of contributors
	 */ 
	function getNumberOfContributors() external view returns (uint256) {
		return contributorList.sizeOf();
	}

	/**
	 * @notice Get all contributor addresses
	 */
	function getAllContributorsAddress()
		external
		view
		returns (address[] memory)
	{
		address[] memory allContributors = new address[](
			contributorList.sizeOf()
		);

		uint256 j = 0;
		(bool existNext, uint256 i) = contributorList.getNextNode(0);

		while (i != 0 && existNext) {
			allContributors[j] = projectContributors[i].wallet;
			j++;
			(existNext, i) = contributorList.getNextNode(i);
		}

		return allContributors;
	}

	/**
	 * @notice Get contributor by address
	 */ 
	function getContributorByAddress(
		address _account
	) external view onlyAdmin returns (Contributor memory) {
		uint256 id = contributorId[_account];
		return projectContributors[id];
	}

	/**
	 * @notice Return true if the address is a contributor in the project
	 */
	function isContributorInProject(
		address _contributor
	) public view returns (bool) {
		return contributorId[_contributor] != 0;
	}

	/**
	 * @notice Get the participation weight in percent
	 */ 
	function getContributorParticipation(
		address _contributor
	) external view returns (uint256) {
		if (projectState != ProjectState.Finished) revert Project_NotCompletedErr();
		return participationOfContributors[_contributor];
	}

	/**
	 *  @notice Get the balance of funds given by an address
	 */ 
	function getAccountFunds(address _account) external view returns (uint256) {
		return projectFunds[_account];
	}

	/**
	 * @notice Get total amount of funds a Project got since creation
	 */ 
	function getTotalAmountFunded() external view returns (uint256) {
		return totalAmountFunded;
	}

	/**
	 * @notice Returns whether the project is pending or not
	 */ 
	function isPending() external view returns (bool) {
		return projectState == PENDING;
	}

	/**
	 * @notice Returns whether the project is active or not
	 */
	function isActive() external view returns (bool) {
		return projectState == ACTIVE;
	}

	/**
	 *  @notice Return true is the project is completed, otherwise return false
	 */ 
	function isFinished() external view returns (bool) {
		return projectState == FINISHED;
	}

	/**
	 *  @notice Returns whether the project is deleted or not
	 */ 
	function isDeleted() external view returns (bool) {
		return projectState == DELETED;
	}
}
