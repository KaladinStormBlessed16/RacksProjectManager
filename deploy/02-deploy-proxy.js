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
	let Erc20Address;
	const waitBlockConfirmations = developmentChains.includes(network.name)
		? 1
		: VERIFICATION_BLOCK_CONFIRMATIONS;

	if (developmentChains.includes(network.name)) {
		const MockErc20 = await deployments.get("MockErc20");
		Erc20Address = MockErc20.address;
	} else {
		Erc20Address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
	}
	log("----------------------------------------------------");

	const proxyAdmin = await deploy("ProxyAdmin", {
		from: deployer,
		log: true,
		waitConfirmations: waitBlockConfirmations,
	});
	const RacksPMContract = await ethers.getContract("RacksProjectManager");
	const proxyArguments = [RacksPMContract.address, proxyAdmin.address, []];
	const transparentUpgradeableProxy = await deploy("TransparentUpgradeableProxy", {
		from: deployer,
		args: proxyArguments,
		log: true,
		waitConfirmations: waitBlockConfirmations,
	});
	const racksPM = await RacksPMContract.attach(transparentUpgradeableProxy.address);
	const owner = await racksPM.getRacksPMOwner();
	if (owner == ethers.constants.AddressZero) await racksPM.initialize(Erc20Address);

	if (deploymentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
		log("Verifying...");
		await verify(proxyAdmin.address, []);
		await verify(transparentUpgradeableProxy.address, proxyArguments);
	}
	log("----------------------------------------------------");
};

module.exports.tags = ["proxy"];
