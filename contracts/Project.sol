//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IRacksProjectManager.sol";
import "./Contributor.sol";
import "./Err.sol";

contract Project is Ownable, AccessControl {
    /// @notice Interfaces
    IRacksProjectManager private immutable racksPM;

    /// @notice State variables
    bytes32 private constant ADMIN_ROLE = 0x00;
    uint256 public colateralCost;
    uint256 public reputationLevel;
    uint256 public maxContributorsNumber;
    Contributor[] public projectContributors;
    mapping(address => bool) public walletIsProjectContributor;
    mapping(address => uint256) public contributorToParticipationWeight;
    bool public completed;

    /// @notice Check that the project has no contributors, therefore is editable
    modifier isEditable() {
        if (projectContributors.length > 0) revert projectNoEditableErr();
        _;
    }

    /// @notice Check that the project is not finished
    modifier isNotFinished() {
        if (completed) revert projectFinishedErr();
        _;
    }

    /// @notice Check that user is Admin
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert adminErr();
        _;
    }

    /// @notice Check that user is Contributor
    modifier onlyContributor() {
        if (!racksPM.isWalletContributor(msg.sender)) revert contributorErr();
        _;
    }

    /// @notice Events
    event newProjectContributorsRegistered(address newProjectContributor);

    constructor(
        IRacksProjectManager racksPM_,
        uint256 colateralCost_,
        uint256 reputationLevel_,
        uint256 maxContributorsNumber_
    ) {
        racksPM = racksPM_;
        colateralCost = colateralCost_;
        reputationLevel = reputationLevel_;
        maxContributorsNumber = maxContributorsNumber_;
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    ////////////////////////
    //  Logic Functions  //
    //////////////////////

    /**
     * @notice Add Project Contributor
     * @dev Only callable by Holders who are aldeady Contributors
     */
    function registerProjectContributor() external onlyContributor isNotFinished {
        if (walletIsProjectContributor[msg.sender]) revert projectContributorAlreadyExistsErr();
        if (projectContributors.length == maxContributorsNumber)
            revert maxContributorsNumberExceededErr();

        Contributor memory newProjectContributor = racksPM.getAccountToContributorData(msg.sender);
        if (newProjectContributor.banned) revert projectContributorIsBannedErr();

        projectContributors.push(newProjectContributor);
        walletIsProjectContributor[msg.sender] = true;
        emit newProjectContributorsRegistered(msg.sender);
        if (!racksPM.getERC20Interface().transferFrom(msg.sender, address(this), colateralCost))
            revert erc20TransferFailed();
    }

    /**
     * @notice Finish Project
     * @dev Only callable by Admins when the project isn't completed
     */
    function finishProject(
        uint256 totalReputationPointsReward,
        address[] memory contributors_,
        uint256[] memory participationWeights_
    ) external onlyAdmin isNotFinished {
        completed = true;

        for (uint256 i = 0; i < contributors_.length; i++) {
            contributorToParticipationWeight[contributors_[i]] = participationWeights_[i];
        }

        for (uint256 i = 0; i < projectContributors.length; i++) {
            if (!projectContributors[i].banned) {
                increaseContributorReputation(
                    (totalReputationPointsReward *
                        contributorToParticipationWeight[contributors_[i]]) / 100,
                    projectContributors[i]
                );
                if (
                    !racksPM.getERC20Interface().transfer(
                        projectContributors[i].wallet,
                        colateralCost
                    )
                ) revert erc20TransferFailed();
            }
        }
        if (racksPM.getERC20Interface().balanceOf(address(this)) > 0) withdrawFunds();
    }

    ////////////////////////
    //  Helper Functions //
    //////////////////////

    /**
     * @notice Used to withdraw All funds
     * @dev Only callable by Admins when completing the project
     */
    function withdrawFunds() private onlyAdmin {
        if (racksPM.getERC20Interface().balanceOf(address(this)) <= 0) revert noFundsWithdrawErr();
        if (
            !racksPM.getERC20Interface().transfer(
                owner(),
                racksPM.getERC20Interface().balanceOf(address(this))
            )
        ) revert erc20TransferFailed();
    }

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
    function removeAdmin(address account) external virtual onlyOwner {
        revokeRole(ADMIN_ROLE, account);
    }

    /**
     * @notice Increase Contributor's reputation
     * @dev Only callable by Admins internally
     */
    function increaseContributorReputation(
        uint256 reputationPointsReward,
        Contributor storage contributor
    ) private onlyAdmin {
        uint256 grossReputationPoints = contributor.reputationPoints + reputationPointsReward;
        if (grossReputationPoints >= (contributor.reputationLevel * 100)) {
            contributor.reputationPoints =
                grossReputationPoints %
                (contributor.reputationLevel * 100);
            contributor.reputationLevel++;
        } else {
            contributor.reputationPoints = grossReputationPoints;
        }
    }

    /**
     * @notice Provides information about supported interfaces (required by AccesControl)
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    ////////////////////////
    //  Setter Functions //
    //////////////////////

    /**
     * @notice Edit the Colatera lCost
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setColateralCost(uint256 colateralCost_) external onlyAdmin isEditable {
        colateralCost = colateralCost_;
    }

    /**
     * @notice Edit the Reputation Level
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setReputationLevel(uint256 reputationLevel_) external onlyAdmin isEditable {
        reputationLevel = reputationLevel_;
    }

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /// @notice Get total number of contributors
    function getContributorsNumber() external view returns (uint256) {
        return projectContributors.length;
    }
}
