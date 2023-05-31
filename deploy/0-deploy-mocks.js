const { network } = require("hardhat");
const { developmentChains, deploymentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
	const { deploy, log } = deployments;
	const { deployer } = await getNamedAccounts();

	if (developmentChains.includes(network.name)) {
		const mrcArguments = ["Mr. Crypto", "MRC", "baseURI/", "notRevURI/"];
		const erc20Arguments = ["USC Coin", "USDC"];
		log("----------------------------------------------------");
		const MRCRYPTO = await deploy("MRCRYPTO", {
			from: deployer,
			args: mrcArguments,
			log: true,
		});

		const MockErc20 = await deploy("MockErc20", {
			from: deployer,
			args: erc20Arguments,
			log: true,
		});
		log("----------------------------------------------------");

		if (deploymentChains.includes(network.name) && process.env.POLYGONSCAN_API_KEY) {
			log("Verifying...");
			await verify(MRCRYPTO.address, mrcArguments);
			await verify(MockErc20.address, erc20Arguments);
		}
		log("----------------------------------------------------");
	}
};

module.exports.tags = ["all", "mocks"];
