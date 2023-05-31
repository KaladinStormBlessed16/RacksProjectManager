//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

error Project_IsNotEditableErr();
error Project_FinishedErr();
error Project_NotAdminErr();
error Project_IsPausedErr();
error Project_IsPendingErr();
error Project_IsDeletedErr();
error Project_MaxContributorNumberExceededErr();
error Project_ContributorAlreadyExistsErr();
error Project_ContributorIsBannedErr();
error Project_ContributorHasNoReputationEnoughErr();
error Project_InvalidParameterErr();
error Project_NotCompletedErr();
error Project_NoFundsWithdrawErr();
error Project_NoFundsGiveAwayErr();
error Project_TransferGiveAwayFailedErr();
error Project_Erc20TransferFailed();
error Project_IsNotHolderErr();
error Project_ContributorNotInProject();
error Project_IsNotContributor();

error RacksProjectManager_NotAdminErr();
error RacksProjectManager_NotHolderErr();
error RacksProjectManager_ContributorAlreadyExistsErr();
error RacksProjectManager_IsPausedErr();
error RacksProjectManager_InvalidParameterErr();

error HolderValidation_InvalidCollection();
