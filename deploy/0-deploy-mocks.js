const { network } = require("hardhat");
const { developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : VERIFICATION_BLOCK_CONFIRMATIONS;

    if (developmentChains.includes(network.name)) {
        log("----------------------------------------------------");
        const MRCRYPTO = await deploy("MRCRYPTO", {
            from: deployer,
            args: ["Mr. Crypto", "MRC", "baseURI/", "notRevURI/"],
            log: true,
        });

        const MockErc20 = await deploy("MockErc20", {
            from: deployer,
            args: ["USC Coin", "USDC"],
            log: true,
        });
        log("----------------------------------------------------");
    }
};

module.exports.tags = ["all", "mocks"];
