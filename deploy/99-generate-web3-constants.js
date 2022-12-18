const {
	backendContractsFile,
	backendAbiLocation,
	frontendContractsFile,
	frontendAbiLocation,
	networkConfig,
} = require("../helper-hardhat-config");
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { network } = require("hardhat");

module.exports = async () => {
	const chainId = network.config.chainId.toString();
	if (chainId === "31337") {
		console.log("Local Deployment...");
		return;
	}
	console.log("Exporting addresses and abi...");
	await updateContractAddresses();
	await updateAbi();
	console.log("Json written!");
};

async function updateAbi() {
	const chainId = network.config.chainId.toString();

	const racksProjectManager = await ethers.getContract("RacksProjectManager");
	fs.writeFileSync(
		`${backendAbiLocation}${networkConfig[chainId].name}/RacksProjectManager.json`,
		racksProjectManager.interface.format(ethers.utils.FormatTypes.json)
	);
	fs.writeFileSync(
		`${frontendAbiLocation}${networkConfig[chainId].name}/RacksProjectManager.json`,
		racksProjectManager.interface.format(ethers.utils.FormatTypes.json)
	);

	const mrCrypto = await ethers.getContract("MRCRYPTO");
	fs.writeFileSync(
		`${backendAbiLocation}${networkConfig[chainId].name}/MRCRYPTO.json`,
		mrCrypto.interface.format(ethers.utils.FormatTypes.json)
	);
	fs.writeFileSync(
		`${frontendAbiLocation}${networkConfig[chainId].name}/MRCRYPTO.json`,
		mrCrypto.interface.format(ethers.utils.FormatTypes.json)
	);

	const mockErc20 = await ethers.getContract("MockErc20");
	fs.writeFileSync(
		`${backendAbiLocation}${networkConfig[chainId].name}/MockErc20.json`,
		mockErc20.interface.format(ethers.utils.FormatTypes.json)
	);
	fs.writeFileSync(
		`${frontendAbiLocation}${networkConfig[chainId].name}/MockErc20.json`,
		mockErc20.interface.format(ethers.utils.FormatTypes.json)
	);

	const project = await ethers.getContractFactory("Project");
	fs.writeFileSync(
		`${backendAbiLocation}${networkConfig[chainId].name}/Project.json`,
		project.interface.format(ethers.utils.FormatTypes.json)
	);
	fs.writeFileSync(
		`${frontendAbiLocation}${networkConfig[chainId].name}/Project.json`,
		project.interface.format(ethers.utils.FormatTypes.json)
	);
}

async function updateContractAddresses() {
	const chainId = network.config.chainId.toString();
	const racksProjectManager = await ethers.getContract("RacksProjectManager");
	const MRCAddress = (await ethers.getContract("MRCRYPTO")).address;
	const MockErc20Address = (await ethers.getContract("MockErc20")).address;
	const contractAddresses = JSON.parse(fs.readFileSync(backendContractsFile, "utf8"));

	contractAddresses[chainId] = {
		RacksProjectManager: racksProjectManager.address,
		MRCRYPTO: MRCAddress,
		MockErc20: MockErc20Address,
	};

	fs.writeFileSync(backendContractsFile, JSON.stringify(contractAddresses));
	fs.writeFileSync(frontendContractsFile, JSON.stringify(contractAddresses));
}
module.exports.tags = ["all", "json"];
