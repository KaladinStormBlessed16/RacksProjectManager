const { network } = require("hardhat");

module.exports = async ({ deployments }) => {
	const { log } = deployments;
	log("----------------------------------------------------");

	const RacksPMContract = await ethers.getContract("RacksProjectManager");
	const TransparentUpgradeableProxy = await ethers.getContract("TransparentUpgradeableProxy");
	const ProxyAdmin = await ethers.getContract("ProxyAdmin");
	await ProxyAdmin.upgrade(TransparentUpgradeableProxy.address, RacksPMContract.address);

	log("----------------------------------------------------");
	log(
		`Proxy Admin: ${ProxyAdmin.address}\n on Transparent Proxy: ${TransparentUpgradeableProxy.address}\n upgraded with implementation: ${RacksPMContract.address}`
	);
};

module.exports.tags = ["upgrade"];
