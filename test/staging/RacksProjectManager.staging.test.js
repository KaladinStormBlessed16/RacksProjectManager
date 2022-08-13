const { assert } = require("chai")
const { network, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

developmentChains.includes(network.name)
    ? describe.skip
    : describe("Racks Project Manager Staging Tests", async function () {})
