const networkConfig = {
    31337: {
        name: "localhost",
    },
    4: {
        name: "rinkeby",
        MRCAddress: "0xef453154766505feb9dbf0a58e6990fd6eb66969",
        Erc20TokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    },
    80001: {
        name: "mumbai",
    },
}

const developmentChains = ["hardhat", "localhost"]
const VERIFICATION_BLOCK_CONFIRMATIONS = 6
const frontEndContractsFile = "../NFT-Marketplace-Front/constants/networkMapping.json"
const frontEndAbiLocation = "../NFT-Marketplace-Front/constants/"

module.exports = {
    networkConfig,
    developmentChains,
    VERIFICATION_BLOCK_CONFIRMATIONS,
    frontEndContractsFile,
    frontEndAbiLocation,
}
