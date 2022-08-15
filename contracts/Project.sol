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
    bool public completed;
    Contributor[] public projectContributors;
    mapping(address => bool) public walletIsProjectContributor;
    mapping(address => uint256) public contributorToParticipationWeight;

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
        if (colateralCost_ <= 0 || reputationLevel_ <= 0 || maxContributorsNumber_ <= 0)
            revert projectInvalidParameterErr();
        racksPM = racksPM_;
        colateralCost = colateralCost_;
        reputationLevel = reputationLevel_;
        maxContributorsNumber = maxContributorsNumber_;
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, racksPM_.getRacksPMOwner());
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
        if (racksPM.isContributorBanned(newProjectContributor.wallet))
            revert projectContributorIsBannedErr();
        if (newProjectContributor.reputationLevel < reputationLevel)
            revert projectContributorHasNoReputationEnoughErr();

        projectContributors.push(newProjectContributor);
        walletIsProjectContributor[msg.sender] = true;
        emit newProjectContributorsRegistered(msg.sender);
        if (!racksPM.getERC20Interface().transferFrom(msg.sender, address(this), colateralCost))
            revert erc20TransferFailed();
    }

    /**
     * @notice Finish Project
     * @dev Only callable by Admins when the project isn't completed
     * - The contributors and participationWeights array must have the same size of the project contributors list.
     * - If there is a banned Contributor in the project, you have to pass his address and participation (should be 0) anyways.
     */
    function finishProject(
        uint256 totalReputationPointsReward,
        address[] memory contributors_,
        uint256[] memory participationWeights_
    ) external onlyAdmin isNotFinished {
        if (
            totalReputationPointsReward <= 0 ||
            contributors_.length < projectContributors.length ||
            participationWeights_.length < projectContributors.length
        ) revert projectInvalidParameterErr();

        completed = true;
        unchecked {
            for (uint256 i = 0; i < contributors_.length; i++) {
                if (!walletIsProjectContributor[contributors_[i]]) revert contributorErr();
                contributorToParticipationWeight[contributors_[i]] = participationWeights_[i];
            }
        }
        unchecked {
            for (uint256 i = 0; i < projectContributors.length; i++) {
                if (!racksPM.isContributorBanned(projectContributors[i].wallet)) {
                    increaseContributorReputation(
                        (totalReputationPointsReward *
                            contributorToParticipationWeight[projectContributors[i].wallet]) / 100,
                        projectContributors[i]
                    );
                    racksPM.setAccountToContributorData(
                        projectContributors[i].wallet,
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
        }
        if (racksPM.getERC20Interface().balanceOf(address(this)) > 0) withdrawFunds();
    }

    function giveAway() external onlyAdmin {
        if (!completed) revert notCompletedErr();

        if (address(this).balance <= 0) revert noFundsGiveAwayErr();
        unchecked {
            uint256 projectBalance = address(this).balance;
            for (uint256 i = 0; i < projectContributors.length; i++) {
                address contrAddress = projectContributors[i].wallet;
                if (!racksPM.isContributorBanned(contrAddress)) {
                    (bool success, ) = contrAddress.call{
                        value: (projectBalance * contributorToParticipationWeight[contrAddress]) /
                            100
                    }("");
                    if (!success) revert transferGiveAwayFailed();
                }
            }
        }
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
        unchecked {
            uint256 grossReputationPoints = contributor.reputationPoints + reputationPointsReward;

            while (grossReputationPoints >= (contributor.reputationLevel * 100)) {
                grossReputationPoints -= (contributor.reputationLevel * 100);
                contributor.reputationLevel++;
            }
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

    /**
     * @notice Edit the Reputation Level
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setMaxContributorsNumber(uint256 maxContributorsNumber_)
        external
        onlyAdmin
        isEditable
    {
        maxContributorsNumber = maxContributorsNumber_;
    }

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /// @notice Get total number of contributors
    function getContributorsNumber() external view returns (uint256) {
        return projectContributors.length;
    }

    receive() external payable {}
}
