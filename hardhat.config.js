require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-chai-matchers");
require("hardhat-deploy");
require("solidity-coverage");
require("hardhat-contract-sizer");
// require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-solhint");
require("dotenv").config({ path: ".env" });

const RPC_URL = process.env.RPC_URL || "https://polygon-mumbai.g.alchemy.com/v2/";
const POLYGON_MAINNET_RPC_URL = "https://poligon.alchemyapi.io/v2/your-api-key";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "PRIVATE_KEY";
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "";

module.exports = {
	defaultNetwork: "hardhat",
	solidity: {
		version: "0.8.19",
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
		compilers: [
			{
				version: "0.8.19",
			},
			{
				version: "0.8.0",
			},
		],
	},
	networks: {
		hardhat: {
			chainId: 31337,
		},
		mumbai: {
			url: "https://rpc-mumbai.maticvigil.com",
			accounts: [PRIVATE_KEY],
			chainId: 80001,
			blockConfirmations: 6,
		},
		polygon: {
			url: POLYGON_MAINNET_RPC_URL,
			accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
			saveDeployments: true,
			chainId: 137,
		},
	},
	etherscan: {
		apiKey: POLYGONSCAN_API_KEY,
	},
	namedAccounts: {
		deployer: {
			default: 0,
			1: 0,
		},
		player: {
			default: 1,
		},
	},
	mocha: {
		timeout: 40000,
	},
};
