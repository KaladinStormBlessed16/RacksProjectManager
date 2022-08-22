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
//                                                                 └────────┘

contract RacksProjectManager is IRacksProjectManager, Ownable, AccessControl {
    /// @notice tokens
    IMRC private immutable mrc;
    IERC20 private erc20;

    /// @notice State variables
    bytes32 private constant ADMIN_ROLE = 0x00;
    Project[] private projects;
    address[] private contributors;
    mapping(address => bool) private walletIsContributor;
    mapping(address => bool) private accountIsBanned;
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

    constructor(IMRC mrc_, IERC20 erc20_) {
        erc20 = erc20_;
        mrc = mrc_;
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    ////////////////////////
    //  Logic Functions  //
    //////////////////////

    /**
     * @notice Create Project
     * @dev Only callable by Admins
     */
    function createProject(
        uint256 colateralCost_,
        uint256 reputationLevel_,
        uint256 maxContributorsNumber_
    ) external onlyAdmin {
        if (colateralCost_ <= 0 || reputationLevel_ <= 0 || maxContributorsNumber_ <= 0)
            revert projectInvalidParameterErr();
        Project newProject = new Project(
            this,
            colateralCost_,
            reputationLevel_,
            maxContributorsNumber_
        );
        projects.push(newProject);
        emit newProjectCreated(address(newProject));
    }

    /**
     * @notice Add Contributor
     * @dev Only callable by Holders who are not aldeady Contributors
     */
    function registerContributor() external onlyHolder {
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
    function withdrawAllFunds(address wallet) external onlyOwner {
        if (erc20.balanceOf(address(this)) <= 0) revert noFundsWithdrawErr();
        if (!erc20.transfer(wallet, erc20.balanceOf(address(this)))) revert erc20TransferFailed();
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

    /**
     * @notice Set new ERC20 Token
     * @dev Only callable by the Admin
     */
    function setERC20Address(address erc20_) external onlyAdmin {
        erc20 = IERC20(erc20_);
    }

    /**
     * @notice Set a ban state for a Contributor
     * @dev Only callable by Admins.
     */
    function setContributorStateToBanList(address account, bool state) external onlyAdmin {
        accountIsBanned[account] = state;
    }

    /// @notice Set Contributor Data by address
    function setAccountToContributorData(address account, Contributor memory newData)
        public
        override
    {
        accountToContributorData[account] = newData;
    }

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /// @notice Returns whether an address is admin or not
    function isAdmin(address account) public view override returns (bool) {
        return hasRole(ADMIN_ROLE, account);
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
    function isContributorBanned(address account) external view override returns (bool) {
        return accountIsBanned[account];
    }

    /**
     * @notice Get  projects depending on Level
     * @dev Only callable by Holders
     */
    function getProjects() public view onlyHolder returns (Project[] memory) {
        // return projects;
        Project[] memory filteredProjects = new Project[](projects.length);
        if (hasRole(ADMIN_ROLE, msg.sender)) return projects;
        else if (walletIsContributor[msg.sender]) {
            unchecked {
                uint256 callerReputationLv = accountToContributorData[msg.sender].reputationLevel;
                uint256 j = 0;
                for (uint256 i = 0; i < projects.length; i++) {
                    if (projects[i].reputationLevel() == callerReputationLv) {
                        filteredProjects[j] = projects[i];
                        j++;
                    }
                }
            }
        } else if (mrc.balanceOf(msg.sender) >= 1) {
            unchecked {
                uint256 j = 0;
                for (uint256 i = 0; i < projects.length; i++) {
                    if (projects[i].reputationLevel() == 1) {
                        filteredProjects[j] = projects[i];
                        j++;
                    }
                }
            }
        }
        return filteredProjects;
    }

    /// @notice Get  Contributor by index
    function getContributor(uint256 index) public view returns (Contributor memory) {
        return accountToContributorData[contributors[index]];
    }

    /// @notice Check whether an address is Contributor or not
    function isWalletContributor(address account) public view override returns (bool) {
        return walletIsContributor[account];
    }

    /// @notice Get Contributor Data by address
    function getAccountToContributorData(address account)
        public
        view
        override
        returns (Contributor memory)
    {
        return accountToContributorData[account];
    }

    /**
     * @notice Get total number of projects
     * @dev Only callable by Holders
     */
    function getProjectsNumber() external view onlyHolder returns (uint256) {
        return projects.length;
    }

    /**
     * @notice Get total number of contributors
     * @dev Only callable by Holders
     */
    function getContributorsNumber() external view onlyHolder returns (uint256) {
        return contributors.length;
    }
}
