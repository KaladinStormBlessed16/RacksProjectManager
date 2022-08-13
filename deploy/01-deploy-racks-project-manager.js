const { network } = require("hardhat")
const { developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : VERIFICATION_BLOCK_CONFIRMATIONS

    if (chainId == 31337) {
        const MRCRYPTO = await deployments.get("MRCRYPTO")
        MRCAddress = MRCRYPTO.address
        const MockErc20 = await deployments.get("MockErc20")
        MockErc20Address = MockErc20.address
    } else {
        MRCAddress = networkConfig[chainId]["MRCAddress"]
        MockErc20Address = networkConfig[chainId]["Erc20TokenAddress"]
    }

    log("----------------------------------------------------")
    const arguments = [MRCAddress, MockErc20Address]
    const racksProjectManager = await deploy("RacksProjectManager", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: waitBlockConfirmations,
    })

    // Verify the deployment
    // if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    //     log("Verifying...")
    //     await verify(nftMarketplace.address, arguments)
    // }
    log("----------------------------------------------------")
}

module.exports.tags = ["all", "rackspm"]
