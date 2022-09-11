const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Racks Project Manager Unit Tests", function () {
          let racksPM, mrc, erc20, deployer, user1, user2, project1;

          beforeEach(async () => {
              accounts = await ethers.getSigners(); // could also do with getNamedAccounts
              [deployer, user1, user2] = accounts;

              await deployments.fixture(["rackspm", "mocks"]);

              const racksPMContract = await ethers.getContract("RacksProjectManager");
              racksPM = racksPMContract.connect(deployer);

              const mrcContract = await ethers.getContract("MRCRYPTO");
              mrc = await mrcContract.connect(deployer);

              const erc20Contract = await ethers.getContract("MockErc20");
              erc20 = await erc20Contract.connect(deployer);

              const tx = await racksPM.createProject("Project1", 100, 1, 2);
              const rc = await tx.wait();
              const { newProjectAddress } = rc.events.find(
                  (e) => e.event == "newProjectCreated"
              ).args;

              project1 = await ethers.getContractAt("Project", newProjectAddress);
              project1 = await project1.connect(deployer);
          });

          describe("Setup", () => {
              it("Should mint ERC20 and MRC", async () => {
                  let balanceOf = await erc20.balanceOf(deployer.address);
                  assert(
                      balanceOf == 100000000000,
                      `Balance is ${balanceOf} and should be 100000000000`
                  );

                  await erc20.connect(user1).mintMore();
                  balanceOf = await erc20.balanceOf(user1.address);
                  assert(
                      balanceOf == 10000000000,
                      `Balance is ${balanceOf} and should be 10000000000`
                  );

                  await mrc.connect(user1).mint(1);
                  assert((await mrc.balanceOf(user1.address)) == 1);
              });
          });

          describe("Create Project", () => {
              it("Should revert with adminErr", async () => {
                  await expect(
                      racksPM.connect(user1).createProject("Project2", 100, 1, 2)
                  ).to.be.revertedWithCustomError(racksPM, "adminErr");
              });

              it("Should revert with projectInvalidParameterErr", async () => {
                  await expect(
                      racksPM.createProject("Project2", 0, 1, 2)
                  ).to.be.revertedWithCustomError(racksPM, "projectInvalidParameterErr");

                  await expect(
                      racksPM.createProject("Project2", 100, 0, 2)
                  ).to.be.revertedWithCustomError(racksPM, "projectInvalidParameterErr");

                  await expect(
                      racksPM.createProject("Project2", 100, 1, 0)
                  ).to.be.revertedWithCustomError(racksPM, "projectInvalidParameterErr");

                  await expect(racksPM.createProject("", 100, 1, 3)).to.be.revertedWithCustomError(
                      racksPM,
                      "projectInvalidParameterErr"
                  );
              });

              it("Should create project", async () => {
                  await racksPM.addAdmin(user1.address);
                  expect(await racksPM.isAdmin(user1.address)).to.be.true;
                  expect(await racksPM.isAdmin(user2.address)).to.be.false;

                  await racksPM.connect(user1).createProject("Project2", 100, 1, 2);
                  assert.lengthOf(await racksPM.getProjects(), 2);

                  await racksPM.removeAdmin(user1.address);
                  await expect(
                      racksPM.connect(user1).createProject("Project3", 100, 1, 2)
                  ).to.be.revertedWithCustomError(racksPM, "adminErr");

                  const projects = await racksPM.getAllProjects();
                  assert.equal(projects[1], project1.address);
              });

              it("Should revert if the smart contract is paused", async () => {
                  await racksPM.setIsPaused(true);

                  await racksPM.addAdmin(user1.address);
                  await expect(
                      racksPM.connect(user1).createProject("Project2", 100, 1, 2)
                  ).to.be.revertedWithCustomError(racksPM, "pausedErr");
              });
          });

          describe("Register Contributor", () => {
              it("Should revert with holderErr", async () => {
                  await expect(
                      racksPM.connect(user1).registerContributor()
                  ).to.be.revertedWithCustomError(racksPM, "holderErr");
              });

              it("Should revert with projectInvalidParameterErr", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await expect(
                      racksPM.connect(user1).registerContributor()
                  ).to.be.revertedWithCustomError(racksPM, "contributorAlreadyExistsErr");
              });

              it("Should register Contributor", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  let contributor = await racksPM.connect(user1).getContributor(0);
                  assert(contributor.wallet == user1.address);
              });

              it("Should revert if the smart contract is paused", async () => {
                  await racksPM.setIsPaused(true);

                  await mrc.connect(user1).mint(1);
                  await expect(
                      racksPM.connect(user1).registerContributor()
                  ).to.be.revertedWithCustomError(racksPM, "pausedErr");
              });
          });

          describe("List Projects according to Contributor Level", () => {
              it("Should revert if it is not Holder and it is not Admin", async () => {
                  await expect(racksPM.connect(user1).getProjects()).to.be.revertedWithCustomError(
                      racksPM,
                      "holderErr"
                  );
              });

              it("Should retieve only Lv1 Projects called by a Holder", async () => {
                  await racksPM.createProject("Project2", 100, 1, 2);
                  await racksPM.createProject("Project3", 100, 3, 2);

                  await mrc.connect(user1).mint(1);
                  const projects = await racksPM.connect(user1).getProjects();
                  assert.lengthOf(
                      projects.filter((p) => p !== ethers.constants.AddressZero),
                      2
                  );
              });

              it("Should retrieve only Lv1 Projects called by a Contributor", async () => {
                  await racksPM.createProject("Project2", 100, 1, 2);
                  await racksPM.createProject("Project3", 100, 3, 2);

                  (await mrc.connect(user1).mint(1)).wait();
                  await racksPM.connect(user1).registerContributor();
                  const projects = await racksPM.connect(user1).getProjects();
                  assert.lengthOf(
                      projects.filter((p) => p !== ethers.constants.AddressZero),
                      2
                  );
              });

              it("Should retrieve all Projects called by an Admin", async () => {
                  await racksPM.createProject("Project2", 100, 1, 2);
                  await racksPM.createProject("Project3", 100, 3, 2);

                  const projects = await racksPM.getProjects();
                  assert.lengthOf(
                      projects.filter((p) => p !== ethers.constants.AddressZero),
                      3
                  );
              });
          });
      });
