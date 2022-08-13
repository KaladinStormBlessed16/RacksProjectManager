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
    Contributor[] private contributors;
    mapping(address => bool) private walletIsContributor;
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
        uint256 reputationPointsReward_,
        uint256 reputationLevel_
    ) external onlyAdmin {
        Project newProject = new Project(
            this,
            colateralCost_,
            reputationPointsReward_,
            reputationLevel_
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

        Contributor memory newContributor = Contributor(msg.sender, 1, 0, false);
        contributors.push(newContributor);
        walletIsContributor[msg.sender] = true;
        accountToContributorData[msg.sender] = newContributor;
        emit newContributorRegistered(msg.sender);
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

    ////////////////////////
    //  Getter Functions //
    //////////////////////

    /// @notice Returns whether an address is admin or not
    function isAdmin(address account) public view override returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /// @notice Returns MRC NFT address
    function getMRCAddress() public view override returns (IMRC) {
        return mrc;
    }

    /// @notice Returns ERC20 address
    function getERC20Address() public view override returns (IERC20) {
        return erc20;
    }

    /**
     * @notice Get  projects depending on Level
     * @dev Only callable by Holders
     */
    function getProjects() public view onlyHolder returns (Project[] memory) {
        //TODO
        return projects;
    }

    /// @notice Get  Contributor by index
    function getContributor(uint256 index) public view returns (Contributor memory) {
        return contributors[index];
    }

    /// @notice Check whether an address is Contributor or not
    function isWalletContributor(address account) public view override returns (bool) {
        return walletIsContributor[account];
    }

    /// @notice Get  Contributor Data by address
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

    receive() external payable {}
}
