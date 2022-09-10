//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRacksProjectManager.sol";
import "./Project.sol";
import "./Contributor.sol";
import "./IMRC.sol";
import "./Err.sol";
import "./StructuredLinkedList.sol";

// for debug
import "hardhat/console.sol";

//              ▟██████████   █████    ▟███████████   █████████████
//            ▟████████████   █████  ▟█████████████   █████████████   ███████████▛
//           ▐█████████████   █████▟███████▛  █████   █████████████   ██████████▛
//            ▜██▛    █████   ███████████▛    █████       ▟██████▛    █████████▛
//              ▀     █████   █████████▛      █████     ▟██████▛
//                    █████   ███████▛      ▟█████▛   ▟██████▛
//   ▟█████████████   ██████              ▟█████▛   ▟██████▛   ▟███████████████▙
//  ▟██████████████   ▜██████▙          ▟█████▛   ▟██████▛   ▟██████████████████▙
// ▟███████████████     ▜██████▙      ▟█████▛   ▟██████▛   ▟█████████████████████▙
//                        ▜██████▙            ▟██████▛          ┌────────┐
//                          ▜██████▙        ▟██████▛            │  LABS  │
//                                                              └────────┘

contract RacksProjectManager is IRacksProjectManager, Ownable, AccessControl {
    /// @notice tokens
    IMRC private immutable mrc;
    IERC20 private erc20;

    /// @notice State variables
    bytes32 private constant ADMIN_ROLE = 0x00;
    address[] private contributors;
    bool private isPaused;
    uint256 progressiveId;

    using StructuredLinkedList for StructuredLinkedList.List;
    StructuredLinkedList.List private projectsList;
    mapping(uint256 => Project) private projectStore;
    Project[] private projectsDeleted;

    mapping(address => bool) private walletIsContributor;
    mapping(address => bool) private accountIsBanned;
    mapping(address => uint256) private projectId;
    mapping(address => Contributor) private accountToContributorData;

    /// @notice Check that user is Admin
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert adminErr();
        _;
    }

    /// @notice Check that user is Holder or Admin
    modifier onlyHolder() {
        if (mrc.balanceOf(msg.sender) < 1 && !hasRole(ADMIN_ROLE, msg.sender)) revert holderErr();
        _;
    }

    /// @notice Check that user is Contributor
    modifier onlyContributor() {
        if (!walletIsContributor[msg.sender]) revert contributorErr();
        _;
    }

    /// @notice Check that the smart contract is paused
    modifier isNotPaused() {
        if (isPaused) revert pausedErr();
        _;
    }

    ///////////////////
    //  Constructor  //
    ///////////////////
    constructor(IMRC _mrc, IERC20 _erc20) {
        erc20 = _erc20;
        mrc = _mrc;
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
        string memory _name,
        uint256 _colateralCost,
        uint256 _reputationLevel,
        uint256 _maxContributorsNumber
    ) external onlyAdmin isNotPaused {
        if (
            _colateralCost <= 0 ||
            _reputationLevel <= 0 ||
            _maxContributorsNumber <= 0 ||
            bytes(_name).length <= 0
        ) revert projectInvalidParameterErr();

        Project newProject = new Project(
            this,
            _name,
            _colateralCost,
            _reputationLevel,
            _maxContributorsNumber
        );

        progressiveId++;
        projectStore[progressiveId] = newProject;
        projectId[address(newProject)] = progressiveId;
        projectsList.pushFront(progressiveId);

        _setupRole(ADMIN_ROLE, address(newProject));
        emit newProjectCreated(_name, address(newProject));
    }

    /**
     * @notice Add Contributor
     * @dev Only callable by Holders who are not already Contributors
     */
    function registerContributor() external onlyHolder isNotPaused {
        if (walletIsContributor[msg.sender]) revert contributorAlreadyExistsErr();

        contributors.push(msg.sender);
        walletIsContributor[msg.sender] = true;
        accountToContributorData[msg.sender] = Contributor(msg.sender, 1, 0, false);
        emit newContributorRegistered(msg.sender);
    }

    /**
     * @notice Used to withdraw All funds
     * @dev Only owner is able to call this function
     */
    function withdrawAllFunds(address _wallet) external onlyOwner isNotPaused {
        if (erc20.balanceOf(address(this)) <= 0) revert noFundsWithdrawErr();
        if (!erc20.transfer(_wallet, erc20.balanceOf(address(this)))) revert erc20TransferFailed();
    }

    ////////////////////////
    //  Helper Functions  //
    ////////////////////////

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

    ///////////////////////
    //  Setter Functions //
    ///////////////////////

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
    function setContributorStateToBanList(address _account, bool _state) external onlyAdmin {
        accountIsBanned[_account] = _state;

        if (_state == true) {
            (bool existNext, uint256 i) = projectsList.getNextNode(0);

            while (i != 0 && existNext) {
                Project project = projectStore[i];

                if (project.getIsActive() && project.isContributorInProject(_account)) {
                    project.removeContributor(_account, false);
                }

                (existNext, i) = projectsList.getNextNode(i);
            }
        }
    }

    /**
     * @notice Set Contributor Data by address
     * @dev Only callable by Admins.
     */
    function setAccountToContributorData(address _account, Contributor memory _newData)
        public
        override
        onlyAdmin
    {
        accountToContributorData[_account] = _newData;
    }

    function setIsPaused(bool _newPausedValue) public onlyAdmin {
        isPaused = _newPausedValue;
    }

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /// @notice Returns whether an address is admin or not
    function isAdmin(address _account) public view override returns (bool) {
        return hasRole(ADMIN_ROLE, _account);
    }

    /// @notice Returns MRC address
    function getMRCInterface() external view returns (IMRC) {
        return mrc;
    }

    /// @notice Returns ERC20 address
    function getERC20Interface() public view override returns (IERC20) {
        return erc20;
    }

    /// @notice Returns Contract Owner
    function getRacksPMOwner() public view override returns (address) {
        return owner();
    }

    /**
     * @notice Check whether an account is banned or not
     * @dev Only callable by Admins.
     */
    function isContributorBanned(address _account) external view override returns (bool) {
        return accountIsBanned[_account];
    }

    /**
     * @notice Get projects depending on Level
     * @dev Only callable by Holders
     */
    function getProjects() public view onlyHolder returns (Project[] memory) {
        if (hasRole(ADMIN_ROLE, msg.sender)) return getAllProject();
        Project[] memory filteredProjects = new Project[](projectsList.sizeOf());

        unchecked {
            uint256 callerReputationLv = walletIsContributor[msg.sender]
                ? accountToContributorData[msg.sender].reputationLevel
                : 1;
            uint256 j = 0;
            (bool existNext, uint256 i) = projectsList.getNextNode(0);

            while (i != 0 && existNext) {
                if (projectStore[i].getReputationLevel() <= callerReputationLv) {
                    filteredProjects[j] = projectStore[i];
                    j++;
                }
                (existNext, i) = projectsList.getNextNode(i);
            }
        }

        return filteredProjects;
    }

    function getAllProject() public view returns (Project[] memory) {
        Project[] memory allProjects = new Project[](progressiveId);

        uint256 j = 0;
        (bool existNext, uint256 i) = projectsList.getNextNode(0);

        while (i != 0 && existNext) {
            allProjects[j] = projectStore[i];
            j++;
            (existNext, i) = projectsList.getNextNode(i);
        }

        for (i = 0; i < projectsDeleted.length; i++) {
            allProjects[j] = projectsDeleted[i];
        }
        return allProjects;
    }

    function getProjectsDeleted() public view returns (Project[] memory) {
        return projectsDeleted;
    }

    /// @notice Get Contributor by index
    function getContributor(uint256 _index) public view returns (Contributor memory) {
        return accountToContributorData[contributors[_index]];
    }

    /// @notice Check whether an address is Contributor or not
    function isWalletContributor(address _account) public view override returns (bool) {
        return walletIsContributor[_account];
    }

    /// @notice Get Contributor Data by address
    function getAccountToContributorData(address _account)
        public
        view
        override
        returns (Contributor memory)
    {
        return accountToContributorData[_account];
    }

    /**
     * @notice Get total number of projects
     * @dev Only callable by Holders
     */
    function getProjectsNumber() external view onlyHolder returns (uint256) {
        return projectsList.sizeOf();
    }

    /**
     * @notice Get total number of contributors
     * @dev Only callable by Holders
     */
    function getContributorsNumber() external view onlyHolder returns (uint256) {
        return contributors.length;
    }

    function getIsPaused() external view override returns (bool) {
        return isPaused;
    }

    function deleteProject() external override {
        console.log(msg.sender);
        uint256 id = projectId[msg.sender];

        projectId[msg.sender] = 0;

        projectsList.remove(id);
    }
}
