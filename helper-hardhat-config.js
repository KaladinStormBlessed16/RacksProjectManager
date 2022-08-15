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
}

const developmentChains = ["hardhat", "localhost"]
const VERIFICATION_BLOCK_CONFIRMATIONS = 6
const frontEndContractsFile = "../"
const frontEndAbiLocation = "../"

module.exports = {
    networkConfig,
    developmentChains,
    VERIFICATION_BLOCK_CONFIRMATIONS,
    frontEndContractsFile,
    frontEndAbiLocation,
}
