//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IRacksProjectManager.sol";
import "./Contributor.sol";
import "./Err.sol";

contract Project is Ownable, AccessControl {
    /// @notice Interfaces
    IRacksProjectManager private immutable racksPM;

    /// @notice State variables
    bytes32 private constant ADMIN_ROLE = 0x00;
    string private name;
    uint256 private colateralCost;
    uint256 private reputationLevel;
    uint256 private maxContributorsNumber;
    bool private completed;
    bool private isDeleted;
    Contributor[] private projectContributors;
    mapping(address => bool) private walletIsProjectContributor;
    mapping(address => uint256) private contributorToParticipationWeight;
    IERC20 private immutable racksPM_ERC20;

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

    /// @notice Check that the smart contract is paused
    modifier isNotPaused() {
        if (racksPM.getIsPaused()) revert pausedErr();
        _;
    }

    /// @notice Check that the smart contract is paused
    modifier isNotDeleted() {
        if (isDeleted) revert deletedErr();
        _;
    }

    /// @notice Events
    event newProjectContributorsRegistered(address newProjectContributor);

    constructor(
        IRacksProjectManager _racksPM,
        string memory _name,
        uint256 _colateralCost,
        uint256 _reputationLevel,
        uint256 _maxContributorsNumber
    ) {
        if (
            _colateralCost <= 0 ||
            _reputationLevel <= 0 ||
            _maxContributorsNumber <= 0 ||
            bytes(_name).length <= 0
        ) revert projectInvalidParameterErr();
        racksPM = _racksPM;
        name = _name;
        colateralCost = _colateralCost;
        reputationLevel = _reputationLevel;
        maxContributorsNumber = _maxContributorsNumber;
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, _racksPM.getRacksPMOwner());
        racksPM_ERC20 = _racksPM.getERC20Interface();
        isDeleted = false;
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
    {
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

        bool success = racksPM_ERC20.transferFrom(msg.sender, address(this), colateralCost);
        if (!success) revert erc20TransferFailed();
    }

    /**
     * @notice Finish Project
     * @dev Only callable by Admins when the project isn't completed
     * - The contributors and participationWeights array must have the same size of the project contributors list.
     * - If there is a banned Contributor in the project, you have to pass his address and participation (should be 0) anyways.
     * - The sum of @param _participationWeights can not be more than 100
     */
    function finishProject(
        uint256 _totalReputationPointsReward,
        address[] memory _contributors,
        uint256[] memory _participationWeights
    ) external onlyAdmin isNotFinished isNotPaused isNotDeleted {
        if (
            _totalReputationPointsReward <= 0 ||
            _contributors.length != projectContributors.length ||
            _participationWeights.length != projectContributors.length
        ) revert projectInvalidParameterErr();

        completed = true;
        uint256 totalParticipationWeight = 0;
        unchecked {
            for (uint256 i = 0; i < _contributors.length; i++) {
                if (!walletIsProjectContributor[_contributors[i]]) revert contributorErr();

                uint256 participationWeight = _participationWeights[i];

                contributorToParticipationWeight[_contributors[i]] = participationWeight;
                totalParticipationWeight += participationWeight;
            }
            if (totalParticipationWeight > 100) revert projectInvalidParameterErr();
        }
        unchecked {
            for (uint256 i = 0; i < projectContributors.length; i++) {
                if (!racksPM.isContributorBanned(projectContributors[i].wallet)) {
                    increaseContributorReputation(
                        (_totalReputationPointsReward *
                            contributorToParticipationWeight[projectContributors[i].wallet]) / 100,
                        projectContributors[i]
                    );
                    racksPM.setAccountToContributorData(
                        projectContributors[i].wallet,
                        projectContributors[i]
                    );

                    bool success = racksPM_ERC20.transfer(
                        projectContributors[i].wallet,
                        colateralCost
                    );
                    if (!success) revert erc20TransferFailed();
                }
            }
        }
        if (racksPM_ERC20.balanceOf(address(this)) > 0) withdrawFunds();
    }

    /**
     * @notice Give Away extra rewards
     * @dev Only callable by Admins when the project is completed
     */
    function giveAway() external onlyAdmin isNotPaused isNotDeleted {
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
        if (racksPM_ERC20.balanceOf(address(this)) <= 0) revert noFundsWithdrawErr();

        bool success = racksPM_ERC20.transfer(owner(), racksPM_ERC20.balanceOf(address(this)));
        if (!success) revert erc20TransferFailed();
    }

    /**
     * @notice Set new Admin
     * @dev Only callable by the Admin
     */
    function addAdmin(address _newAdmin) external onlyOwner isNotDeleted {
        grantRole(ADMIN_ROLE, _newAdmin);
    }

    /**
     * @notice Remove an account from the user role
     * @dev Only callable by the Admin
     */
    function removeAdmin(address _account) external virtual onlyOwner isNotDeleted {
        revokeRole(ADMIN_ROLE, _account);
    }

    /**
     * @notice Increase Contributor's reputation
     * @dev Only callable by Admins internally
     */
    function increaseContributorReputation(
        uint256 _reputationPointsReward,
        Contributor storage _contributor
    ) private onlyAdmin isNotDeleted {
        unchecked {
            uint256 grossReputationPoints = _contributor.reputationPoints + _reputationPointsReward;

            while (grossReputationPoints >= (_contributor.reputationLevel * 100)) {
                grossReputationPoints -= (_contributor.reputationLevel * 100);
                _contributor.reputationLevel++;
            }
            _contributor.reputationPoints = grossReputationPoints;
        }
    }

    /**
     * @notice Provides information about supported interfaces (required by AccessControl)
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function deleteProject() public onlyAdmin isNotDeleted isEditable{
        isDeleted = true;
    }

    ////////////////////////
    //  Setter Functions //
    //////////////////////

    /**
     * @notice Edit the Project Name
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setName(string memory _name) external onlyAdmin isEditable isNotPaused isNotDeleted {
        if (bytes(_name).length <= 0) revert projectInvalidParameterErr();
        name = _name;
    }

    /**
     * @notice Edit the Colateral Cost
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setColateralCost(uint256 _colateralCost)
        external
        onlyAdmin
        isEditable
        isNotPaused
        isNotDeleted
    {
        if (_colateralCost <= 0) revert projectInvalidParameterErr();
        colateralCost = _colateralCost;
    }

    /**
     * @notice Edit the Reputation Level
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setReputationLevel(uint256 _reputationLevel)
        external
        onlyAdmin
        isEditable
        isNotPaused
        isNotDeleted
    {
        if (_reputationLevel <= 0) revert projectInvalidParameterErr();
        reputationLevel = _reputationLevel;
    }

    /**
     * @notice Edit the Reputation Level
     * @dev Only callable by Admins when the project has no Contributor yet.
     */
    function setMaxContributorsNumber(uint256 _maxContributorsNumber)
        external
        onlyAdmin
        isEditable
        isNotPaused
        isNotDeleted
    {
        if (_maxContributorsNumber <= 0) revert projectInvalidParameterErr();
        maxContributorsNumber = _maxContributorsNumber;
    }

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /// @notice Get the project name
    function getName() external view returns (string memory) {
        return name;
    }

    /// @notice Get the colateral cost to enter as contributor
    function getColateralCost() external view returns (uint256) {
        return colateralCost;
    }

    /// @notice Get the reputation level of the project
    function getReputationLevel() external view returns (uint256) {
        return reputationLevel;
    }

    /// @notice Get the maximum contributor that can be in the project
    function getMaxContributors() external view returns (uint256) {
        return maxContributorsNumber;
    }

    /// @notice Get total number of contributors
    function getContributorsNumber() external view returns (uint256) {
        return projectContributors.length;
    }

    /// @notice Return true is the project is completed, otherwise return false
    function isCompleted() external view returns (bool) {
        return completed;
    }

    /// @notice Return the contributor in the corresponding index
    function getProjectContributor(uint256 _index) external view returns (Contributor memory) {
        if (_index >= projectContributors.length || _index < 0) revert projectInvalidParameterErr();
        return projectContributors[_index];
    }

    /// @notice Return true if the address is a contributor in the project
    function isInProjectContributor(address _contributor) external view returns (bool) {
        return walletIsProjectContributor[_contributor];
    }

    /// @notice Get the participation weight in percent
    function getContributorParticipationWeight(address _contributor)
        external
        view
        returns (uint256)
    {
        return contributorToParticipationWeight[_contributor];
    }

    function getIsDeleted() external view returns (bool) {
        return isDeleted;
    }

    receive() external payable {}
}
