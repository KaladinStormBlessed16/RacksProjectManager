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
    uint256 public reputationPointsReward;
    uint256 public reputationLevel;
    Contributor[] public projectContributors;
    mapping(address => bool) public walletIsProjectContributor;
    bool public completed;

    /// @notice Check that the project has no contributors, therefore is editable
    modifier isEditable() {
        if (projectContributors.length > 0) revert projectNoEditableErr();
        _;
    }

    /// @notice Check that the project is not finished
    modifier isNotFinished() {
        if (!completed) revert projectFinishedErr();
        _;
    }

    /// @notice Check that user is Admin
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert adminErr();
        _;
    }

    /// @notice Check that user is Holder or Admin
    modifier onlyHolder() {
        if (racksPM.getMRCAddress().balanceOf(msg.sender) < 1 && !hasRole(ADMIN_ROLE, msg.sender))
            revert holderErr();
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
        uint256 reputationPointsReward_,
        uint256 reputationLevel_
    ) {
        racksPM = racksPM_;
        colateralCost = colateralCost_;
        reputationPointsReward = reputationPointsReward_;
        reputationLevel = reputationLevel_;
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

        Contributor memory newProjectContributor = racksPM.getAccountToContributorData(msg.sender);
        projectContributors.push(newProjectContributor);
        walletIsProjectContributor[msg.sender] = true;
        emit newProjectContributorsRegistered(msg.sender);
        if (!racksPM.getERC20Address().transferFrom(msg.sender, address(this), colateralCost))
            revert usdTransferFailed();
    }

    /**
     * @notice Finish Project
     * @dev Only callable by Admins
     */
    function finishProject() external onlyAdmin {
        // TODO
    }

    ////////////////////////
    //  Helper Functions  //
    //////////////////////

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

    ////////////////////////
    //  Setter Functions //
    //////////////////////

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /**
     * @notice Get total number of contributors
     * @dev Only callable by Holders
     */
    function getContributorsNumber()
        external
        view
        returns (
            /*onlyHolder*/
            uint256
        )
    {
        return projectContributors.length;
    }
}
