//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHolderValidation.sol";
import "./library/StructuredLinkedList.sol";
import "./Err.sol";

contract HolderValidation is IHolderValidation, Ownable {
	/// @notice State variables
	uint256 progressiveId;

	using StructuredLinkedList for StructuredLinkedList.List;
	StructuredLinkedList.List private collectionsList;
	mapping(uint256 => IERC721) private collectionStore;
	mapping(address => uint256) private collectionId;

	///////////////////
	//  Constructor  //
	///////////////////
	constructor(IERC721 _erc721) {
		addCollection(_erc721);
	}

	///////////////////////
	//  Logic Functions  //
	///////////////////////

	/**
	 * @notice Get whether a wallet is holder of at least one authorized collection
	 */
	function isHolder(
		address _wallet
	) external view override returns (address) {
		uint256 j = 0;
		(bool existNext, uint256 i) = collectionsList.getNextNode(0);

		while (i != 0 && existNext) {
			if (collectionStore[i].balanceOf(_wallet) > 0)
				return address(collectionStore[i]);
			j++;
			(existNext, i) = collectionsList.getNextNode(i);
		}

		return address(0);
	}

	/**
	 * @notice Add ERC721 Collection
	 * @dev Only callable by Admins
	 */
	function addCollection(IERC721 _newCollection) public onlyOwner {
		progressiveId++;
		collectionStore[progressiveId] = IERC721(_newCollection);
		collectionId[address(_newCollection)] = progressiveId;
		collectionsList.pushFront(progressiveId);

		emit newCollectionAdded(_newCollection);
	}

	/**
	 * @notice Delete ERC721 Collection
	 * @dev Only callable by Admins
	 */
	function deleteCollection(address _deleteCollection) external onlyOwner {
		uint256 id = collectionId[_deleteCollection];

		require(id != 0);

		collectionId[msg.sender] = 0;
		collectionsList.remove(id);
	}

	/**
	 * @notice Get all authorized collections
	 */
	function getAllCollections() external view returns (IERC721[] memory) {
		IERC721[] memory allCollections = new IERC721[](
			collectionsList.sizeOf()
		);

		uint256 j = 0;
		(bool existNext, uint256 i) = collectionsList.getNextNode(0);

		while (i != 0 && existNext) {
			allCollections[j] = collectionStore[i];
			j++;
			(existNext, i) = collectionsList.getNextNode(i);
		}

		return allCollections;
	}
}
