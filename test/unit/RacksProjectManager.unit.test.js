const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Racks Project Manager Unit Tests", function () {
          let racksPM, mrc, erc20, deployer, user1;

          beforeEach(async () => {
              accounts = await ethers.getSigners(); // could also do with getNamedAccounts
              deployer = accounts[0];
              user1 = accounts[1];
              user2 = accounts[2];
              await deployments.fixture(["rackspm", "mocks"]);
              let racksPMContract = await ethers.getContract("RacksProjectManager");
              racksPM = racksPMContract.connect(deployer);
              let mrcContract = await ethers.getContract("MRCRYPTO");
              mrc = await mrcContract.connect(deployer);
              let erc20Contract = await ethers.getContract("MockErc20");
              erc20 = await erc20Contract.connect(deployer);

              await racksPM.createProject(100, 1, 2);
          });

          describe("Setup", () => {
              it("Should mint ERC20 and MRC", async () => {
                  let balanceOf = await erc20.balanceOf(deployer.address);
                  assert(
                      balanceOf == 100000000000,
                      `Balance is ${balanceOf} and should be 100000000000`
                  );
                  (await erc20.connect(user1).mintMore()).wait();
                  balanceOf = await erc20.balanceOf(user1.address);
                  assert(balanceOf == 10000000000, `Balance is ${balanceOf} and should be 10000`);
                  (await erc20.connect(user1).mintMore()).wait();
                  (await mrc.connect(user1).mint(1)).wait();
                  assert((await mrc.balanceOf(user1.address)) == 1);
              });
          });

          describe("Create Project", () => {
              it("Should revert with adminErr", async () => {
                  await expect(
                      racksPM.connect(user1).createProject(100, 1, 2)
                  ).to.be.revertedWithCustomError(racksPM, "adminErr");
              });

              it("Should revert with projectInvalidParameterErr", async () => {
                  await expect(racksPM.createProject(0, 1, 2)).to.be.revertedWithCustomError(
                      racksPM,
                      "projectInvalidParameterErr"
                  );
                  await expect(racksPM.createProject(100, 0, 2)).to.be.revertedWithCustomError(
                      racksPM,
                      "projectInvalidParameterErr"
                  );
                  await expect(racksPM.createProject(100, 1, 0)).to.be.revertedWithCustomError(
                      racksPM,
                      "projectInvalidParameterErr"
                  );
              });

              it("Should create project", async () => {
                  await racksPM.addAdmin(user1.address);
                  assert((await racksPM.isAdmin(user1.address)) == true);
                  await racksPM.connect(user1).createProject(100, 1, 2);
                  const project2Address = await racksPM.projects(1);
                  assert(project2Address !== undefined);
                  await racksPM.removeAdmin(user1.address);
                  await expect(
                      racksPM.connect(user1).createProject(100, 1, 2)
                  ).to.be.revertedWithCustomError(racksPM, "adminErr");
              });
          });

          describe("Register Contributor", () => {
              it("Should revert with holderErr", async () => {
                  await expect(
                      racksPM.connect(user1).registerContributor()
                  ).to.be.revertedWithCustomError(racksPM, "holderErr");
              });

              it("Should revert with projectInvalidParameterErr", async () => {
                  (await mrc.connect(user1).mint(1)).wait();
                  await racksPM.connect(user1).registerContributor();
                  await expect(
                      racksPM.connect(user1).registerContributor()
                  ).to.be.revertedWithCustomError(racksPM, "contributorAlreadyExistsErr");
              });

              it("Should register Contributor", async () => {
                  (await mrc.connect(user1).mint(1)).wait();
                  await racksPM.connect(user1).registerContributor();
                  let contributor = await racksPM.connect(user1).getContributor(0);
                  assert(contributor.wallet == user1.address);
              });
          });
      });
