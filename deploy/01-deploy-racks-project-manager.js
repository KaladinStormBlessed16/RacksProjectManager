const { network } = require("hardhat");
const {
	developmentChains,
	deploymentChains,
	VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
	const { deploy, log } = deployments;
	const { deployer } = await getNamedAccounts();
	let MRCAddress;
	const waitBlockConfirmations = developmentChains.includes(network.name)
		? 1
		: VERIFICATION_BLOCK_CONFIRMATIONS;

	if (developmentChains.includes(network.name)) {
		const MRCRYPTO = await deployments.get("MRCRYPTO");
		MRCAddress = MRCRYPTO.address;
	} else {
		MRCAddress = "0xeF453154766505FEB9dBF0a58E6990fd6eB66969";
	}
	log("----------------------------------------------------");
	const holderValidation = await deploy("HolderValidation", {
		from: deployer,
		args: [MRCAddress],
		log: true,
		waitConfirmations: waitBlockConfirmations,
	});
	const racksProjectManager = await deploy("RacksProjectManager", {
		from: deployer,
		args: [holderValidation.address],
		log: true,
		waitConfirmations: waitBlockConfirmations,
	});

	if (deploymentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
		log("Verifying...");
		await verify(holderValidation.address, [MRCAddress]);
		await verify(racksProjectManager.address, [holderValidation.address]);
	}
	log("----------------------------------------------------");
};

module.exports.tags = ["all", "rackspm"];
