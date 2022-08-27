const networkConfig = {
    31337: {
        name: "localhost",
    },
    4: {
        name: "rinkeby",
    },
    80001: {
        name: "mumbai",
    },
    137: {
        name: "polygon",
    },
};

const developmentChains = ["hardhat", "localhost", "rinkeby"];
const VERIFICATION_BLOCK_CONFIRMATIONS = 6;
const backendContractsFile = "../Backend_RacksProjectManager/web3Constanst/networkMapping.json";
const backendAbiLocation = "../Backend_RacksProjectManager/web3Constanst/";
const frontendContractsFile = "../Frontend_RacksProjectManager/web3Constanst/networkMapping.json";
const frontendAbiLocation = "../Frontend_RacksProjectManager/web3Constanst/";

module.exports = {
    networkConfig,
    developmentChains,
    VERIFICATION_BLOCK_CONFIRMATIONS,
    backendContractsFile,
    backendAbiLocation,
    frontendContractsFile,
    frontendAbiLocation,
};
