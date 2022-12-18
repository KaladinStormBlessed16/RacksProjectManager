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
	let MRCAddress, Erc20Address;
	const waitBlockConfirmations = developmentChains.includes(network.name)
		? 1
		: VERIFICATION_BLOCK_CONFIRMATIONS;

	if (developmentChains.includes(network.name)) {
		const MRCRYPTO = await deployments.get("MRCRYPTO");
		MRCAddress = MRCRYPTO.address;
		const MockErc20 = await deployments.get("MockErc20");
		Erc20Address = MockErc20.address;
	} else {
		MRCAddress = "0xeF453154766505FEB9dBF0a58E6990fd6eB66969";
		Erc20Address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
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
	// PROXY
	const proxyAdmin = await deploy("ProxyAdmin", {
		from: deployer,
		log: true,
		waitConfirmations: waitBlockConfirmations,
	});
	const proxyArguments = [racksProjectManager.address, proxyAdmin.address, []];
	const transparentUpgradeableProxy = await deploy("TransparentUpgradeableProxy", {
		from: deployer,
		args: proxyArguments,
		log: true,
		waitConfirmations: waitBlockConfirmations,
	});
	const RacksPMContract = await ethers.getContract("RacksProjectManager");
	const racksPM = await RacksPMContract.attach(transparentUpgradeableProxy.address);
	await racksPM.initialize(Erc20Address);

	if (deploymentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
		log("Verifying...");
		await verify(holderValidation.address, [MRCAddress]);
		await verify(racksProjectManager.address, holderValidation.address);
		await verify(proxyAdmin.address, []);
		await verify(transparentUpgradeableProxy.address, proxyArguments);
	}
	log("----------------------------------------------------");
};

module.exports.tags = ["all", "rackspm"];
