const { assert } = require("chai")
const { network, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

developmentChains.includes(network.name)
    ? describe.skip
    : describe("Naruto Panels NFT Staging Tests", async function () {
          let narutoPanelsNft, vrfCoordinatorV2Mock

          beforeEach(async () => {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              narutoPanelsNft = await ethers.getContract("NarutoPanels", deployer)
          })

          describe("fulfillRandomWords", () => {
              it("mints NFT after random number returned", async function () {
                  await new Promise(async (resolve, reject) => {
                      narutoPanelsNft.once("NftMinted", async () => {
                          console.log("NftMinted event fired!")
                          try {
                              const tokenUri = await narutoPanelsNft.tokenURI(0)
                              const tokenCounter = await narutoPanelsNft.getCurrentTokenIdCounter()
                              assert.equal(tokenUri.toString().includes("ipfs://"), true)
                              assert.equal(tokenCounter.toString(), "1")
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      try {
                          const tx = await narutoPanelsNft.requestNft()
                          await tx.wait(1)
                          console.log("Ok, time to wait...")
                      } catch (e) {
                          console.log(e)
                          reject(e)
                      }
                  })
              })
          })
      })
