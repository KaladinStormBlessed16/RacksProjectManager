//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IHolderValidation {
	/////////////////
	///   Events  ///
	/////////////////

	/**
	 * @notice Event emitted when a new collection is authorized in RacksProjectManager
	 */
	event newCollectionAdded(IERC721 newCollection);

	/////////////////////////////
	///   Abstract functions  ///
	/////////////////////////////

	/**
	 * @notice Returns true if @param _account is admin in RacksProjectsManager otherwise returns false
	 */
	function isHolder(address _account) external view returns (address);
}
