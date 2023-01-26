//SPDX-License-Identifier: MIT
// @author KaladinStormblessed16 and Daniel Sintimbrean
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRacksProjectManager.sol";
import "./interfaces/IHolderValidation.sol";
import "./Project.sol";
import "./Contributor.sol";
import "./Err.sol";
import "./library/StructuredLinkedList.sol";

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

contract RacksProjectManager is
	IRacksProjectManager,
	Initializable,
	OwnableUpgradeable,
	AccessControlUpgradeable
{
	/// @notice interfaces
	/// @custom:oz-upgrades-unsafe-allow state-variable-immutable
	IHolderValidation private immutable holderValidation;
	IERC20 private erc20;

	/// @notice State variables
	bytes32 private constant ADMIN_ROLE = 0x00;
	address[] private contributors;
	bool private paused;
	uint256 progressiveId;

	using StructuredLinkedList for StructuredLinkedList.List;
	StructuredLinkedList.List private projectsList;
	mapping(uint256 => Project) private projectStore;

	mapping(address => bool) private accountIsBanned;
	mapping(address => uint256) private projectId;
	mapping(address => Contributor) private contributorsData;

	/// @notice Check that user is Admin
	modifier onlyAdmin() {
		if (!hasRole(ADMIN_ROLE, msg.sender)) revert adminErr();
		_;
	}

	/// @notice Check that user is Holder or Admin
	modifier onlyHolder() {
		if (holderValidation.isHolder(msg.sender) == address(0) && !hasRole(ADMIN_ROLE, msg.sender))
			revert holderErr();
		_;
	}

	/// @notice Check that the smart contract is not paused
	modifier isNotPaused() {
		if (paused) revert pausedErr();
		_;
	}

	///////////////////
	//   Constructor //
	///////////////////
	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor(IHolderValidation _holderValidation) {
		holderValidation = _holderValidation;
	}

	///////////////////
	//   Initialize  //
	///////////////////
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
		string memory _name,
		uint256 _colateralCost,
		uint256 _reputationLevel,
		uint256 _maxContributorsNumber
	) external onlyAdmin isNotPaused {
		if (
			_colateralCost < 0 ||
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
		if (isWalletContributor(msg.sender)) revert contributorAlreadyExistsErr();

		contributors.push(msg.sender);
		contributorsData[msg.sender] = Contributor(msg.sender, 0, false);
		emit newContributorRegistered(msg.sender);
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
	function setContributorStateToBanList(address _account, bool _state) external onlyAdmin {
		accountIsBanned[_account] = _state;

		if (_state == true) {
			(bool existNext, uint256 i) = projectsList.getNextNode(0);

			while (i != 0 && existNext) {
				Project project = projectStore[i];
				if (project.isActive() && project.isContributorInProject(_account)) {
					project.removeContributor(_account, false);
				}
				(existNext, i) = projectsList.getNextNode(i);
			}
		}
	}

	/// @inheritdoc IRacksProjectManager
	function setAccountToContributorData(
		address _account,
		Contributor memory _newData
	) public override onlyAdmin {
		contributorsData[_account] = _newData;
	}

	///
	/**
	 * @notice Increase Contributor's Reputation Points if
	 * @param add is true, otherwise it reduces
	 * @param grossReputationPoints is the amount of reputation points to increse or decrease
	 */
	function modifyContributorRP(
		address _account,
		uint256 grossReputationPoints,
		bool add
	) override public onlyAdmin {
		if (grossReputationPoints <= 0) revert invalidParameterErr();
		Contributor memory contributor = contributorsData[_account];

		if (add) {
			grossReputationPoints += contributor.reputationPoints;
		} else {
			grossReputationPoints = contributor.reputationPoints - grossReputationPoints;
		}

			contributor.reputationPoints = grossReputationPoints;
		contributorsData[_account] = contributor;
	}

	function setIsPaused(bool _newPausedValue) public onlyAdmin {
		paused = _newPausedValue;
	}

	function calculateLevel(uint256 totalPoints) override public pure returns (uint256){
        if (totalPoints < 100) return 1;

        uint256 points = totalPoints / 100;
        return ((sqrt(8 * points - 7) - 1) / 2) + 2;
    }

	function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

	////////////////////////
	//  Getter Functions //
	//////////////////////

	/// @inheritdoc IRacksProjectManager
	function isAdmin(address _account) public view override returns (bool) {
		return hasRole(ADMIN_ROLE, _account);
	}

	/// @notice Returns Holder Validation contract address
	function getHolderValidationInterface() external view returns (IHolderValidation) {
		return holderValidation;
	}

	/// @inheritdoc IRacksProjectManager
	function getERC20Interface() public view override returns (IERC20) {
		return erc20;
	}

	/// @inheritdoc IRacksProjectManager
	function getRacksPMOwner() public view override returns (address) {
		return owner();
	}

	/// @inheritdoc IRacksProjectManager
	function isContributorBanned(address _account) external view override returns (bool) {
		return accountIsBanned[_account];
	}

	/**
	 * @notice Get projects depending on Level
	 * @dev Only callable by Holders
	 */
	function getProjects() public view onlyHolder returns (Project[] memory) {
		if (hasRole(ADMIN_ROLE, msg.sender)) return getAllProjects();
		Project[] memory filteredProjects = new Project[](projectsList.sizeOf());

		unchecked {
			uint256 callerReputationLv = getContributorLevel(msg.sender);

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

	function getAllProjects() private view returns (Project[] memory) {
		Project[] memory allProjects = new Project[](projectsList.sizeOf());

		uint256 j = 0;
		(bool existNext, uint256 i) = projectsList.getNextNode(0);

		while (i != 0 && existNext) {
			allProjects[j] = projectStore[i];
			j++;
			(existNext, i) = projectsList.getNextNode(i);
		}

		return allProjects;
	}

	/// @inheritdoc IRacksProjectManager
	function isWalletContributor(address _account) public view override returns (bool) {
		return contributorsData[_account].wallet != address(0);
	}

	function getContributorLevel(address _account) public view returns (uint256) {

		uint256 point =  contributorsData[_account].reputationPoints;
		return calculateLevel(point);
	}

	/// @inheritdoc IRacksProjectManager
	function getContributorData(
		address _account
	) public view override returns (Contributor memory) {
		return contributorsData[_account];
	}

	/**
	 * @notice Get total number of contributors
	 * @dev Only callable by Holders
	 */
	function getNumberOfContributors() external view onlyHolder returns (uint256) {
		return contributors.length;
	}

	/// @inheritdoc IRacksProjectManager
	function isPaused() external view override returns (bool) {
		return paused;
	}

	/// @inheritdoc IRacksProjectManager
	function deleteProject() external override {
		uint256 id = projectId[msg.sender];

		require(id > 0);

		projectId[msg.sender] = 0;
		projectsList.remove(id);
	}
}
