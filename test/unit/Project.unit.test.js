const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Project Unit Tests", function () {
          let racksPM, mrc, erc20, projectContract, deployer, user1, user2, user3;

          beforeEach(async () => {
              accounts = await ethers.getSigners(); // could also do with getNamedAccounts
              [deployer, user1, user2, user3] = accounts;

              await deployments.fixture(["rackspm", "mocks"]);

              let racksPMContract = await ethers.getContract("RacksProjectManager");
              racksPM = racksPMContract.connect(deployer);

              let mrcContract = await ethers.getContract("MRCRYPTO");
              mrc = await mrcContract.connect(deployer);

              let erc20Contract = await ethers.getContract("MockErc20");
              erc20 = await erc20Contract.connect(deployer);

              await racksPM.createProject("Project1", 100, 1, 2);
              const projectAddress = await (await racksPM.getProjects())[0];

              const Project = await ethers.getContractFactory("Project");
              projectContract = Project.attach(projectAddress);

              await erc20.connect(user1).mintMore();
              await erc20.connect(user2).mintMore();
              await erc20.connect(user3).mintMore();
          });

          describe("Register Project Contributor", () => {
              it("Should revert with contributorErr", async () => {
                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(projectContract, "contributorErr");
              });

              it("Should revert with projectContributorAlreadyExistsErr and maxContributorsNumberExceededErr", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(
                      projectContract,
                      "projectContributorAlreadyExistsErr"
                  );

                  await mrc.connect(user2).mint(1);
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();

                  await mrc.connect(user3).mint(1);
                  await racksPM.connect(user3).registerContributor();
                  await erc20.connect(user3).approve(projectContract.address, 100);

                  await expect(
                      projectContract.connect(user3).registerProjectContributor()
                  ).to.be.revertedWithCustomError(
                      projectContract,
                      "maxContributorsNumberExceededErr"
                  );

                  // if remove one contributor you can add an other one
                  await projectContract.removeContributor(user2.address, true);
                  await projectContract.connect(user3).registerProjectContributor();
              });

              it("Should revert if Contributor is banned with projectContributorIsBannedErr", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await racksPM.setContributorStateToBanList(user1.address, true);
                  expect(await racksPM.isContributorBanned(user1.address)).to.be.true;

                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(projectContract, "projectContributorIsBannedErr");
              });

              it("Should revert if Contributor has no Reputation Level Enough with projectContributorHasNoReputationEnoughErr", async () => {
                  await racksPM.createProject("Project2", 100, 2, 3);
                  const projectAddress2 = (await racksPM.getProjects())[1];

                  const Project2 = await ethers.getContractFactory("Project");
                  let project2Contract = Project2.attach(projectAddress2);

                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);

                  await expect(
                      project2Contract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(
                      project2Contract,
                      "projectContributorHasNoReputationEnoughErr"
                  );
              });

              it("Should register a new Project Contributor", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();
                  const projectContributor = await projectContract.getProjectContributor(0);
                  assert(projectContributor.wallet === user1.address);
              });
              it("Should revert if the smart contract is paused", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);

                  await racksPM.setIsPaused(true);

                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(racksPM, "pausedErr");
              });
              it("Should revert if the project is deleted", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);

                  await projectContract.deleteProject();

                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(projectContract, "deletedErr");
              });
          });

          describe("Finish Project", () => {
              it("Should revert with adminErr", async () => {
                  await expect(
                      projectContract.connect(user1).finishProject(500, [user2.address], [20])
                  ).to.be.revertedWithCustomError(projectContract, "adminErr");
              });

              it("Should revert with contributorErr", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  await expect(
                      projectContract.finishProject(500, [user2.address], [20])
                  ).to.be.revertedWithCustomError(projectContract, "contributorErr");
              });

              it("Should revert with projectInvalidParameterErr", async () => {
                  await mrc.connect(user2).mint(1);
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();

                  await expect(
                      projectContract.finishProject(500, [user2.address], [])
                  ).to.be.revertedWithCustomError(projectContract, "projectInvalidParameterErr");

                  await expect(
                      projectContract.finishProject(500, [], [20])
                  ).to.be.revertedWithCustomError(projectContract, "projectInvalidParameterErr");

                  await expect(
                      projectContract.finishProject(0, [user2.address], [20])
                  ).to.be.revertedWithCustomError(projectContract, "projectInvalidParameterErr");
              });

              it("Should revert because of less contributors array length than project contributors registered with projectInvalidParameterErr", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  await mrc.connect(user2).mint(1);
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();

                  await expect(
                      projectContract.finishProject(500, [user2.address], [100])
                  ).to.be.revertedWithCustomError(projectContract, "projectInvalidParameterErr");
              });

              it("Should revert becase de total of participation weight is greeter than 100 ", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  expect(await erc20.balanceOf(user1.address)).to.be.equal(10000000000);
                  await projectContract.connect(user1).registerProjectContributor();
                  expect(await erc20.balanceOf(user1.address)).to.be.equal(9999999900);

                  (await mrc.connect(user2).mint(1)).wait();
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  expect(await erc20.balanceOf(user2.address)).to.be.equal(10000000000);
                  await projectContract.connect(user2).registerProjectContributor();
                  expect(await erc20.balanceOf(user2.address)).to.be.equal(9999999900);

                  await expect(
                      projectContract.finishProject(500, [user2.address, user1.address], [70, 70])
                  ).to.be.revertedWithCustomError(projectContract, "projectInvalidParameterErr");
              });

              it("Should revert with projectFinishedErr", async () => {
                  await mrc.connect(user2).mint(1);
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();
                  await projectContract.finishProject(500, [user2.address], [100]);

                  await expect(
                      projectContract.finishProject(500, [user2.address], [100])
                  ).to.be.revertedWithCustomError(projectContract, "projectFinishedErr");
              });

              it("Should set the Project as finished, refund colateral and grant rewards", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  expect(await erc20.balanceOf(user1.address)).to.be.equal(10000000000);
                  await projectContract.connect(user1).registerProjectContributor();
                  expect(await erc20.balanceOf(user1.address)).to.be.equal(9999999900);

                  (await mrc.connect(user2).mint(1)).wait();
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  expect(await erc20.balanceOf(user2.address)).to.be.equal(10000000000);
                  await projectContract.connect(user2).registerProjectContributor();
                  expect(await erc20.balanceOf(user2.address)).to.be.equal(9999999900);

                  await projectContract.finishProject(
                      500,
                      [user2.address, user1.address],
                      [70, 30]
                  );

                  expect(await erc20.balanceOf(user1.address)).to.be.equal(10000000000);
                  expect(await erc20.balanceOf(user2.address)).to.be.equal(10000000000);

                  expect(
                      await projectContract.getContributorParticipationWeight(user1.address)
                  ).to.be.equal(30);
                  expect(
                      await projectContract.getContributorParticipationWeight(user2.address)
                  ).to.be.equal(70);

                  const pcUser1 = await projectContract.getProjectContributor(0);
                  const pcUser2 = await projectContract.getProjectContributor(1);

                  expect(pcUser1.wallet).to.be.equal(user1.address);
                  expect(pcUser1.reputationLevel).to.be.equal(2);
                  expect(pcUser1.reputationPoints).to.be.equal(50);
                  expect(pcUser2.wallet).to.be.equal(user2.address);
                  expect(pcUser2.reputationLevel).to.be.equal(3);
                  expect(pcUser2.reputationPoints).to.be.equal(50);
              });

              it("Should finish a project, create a new project, finish that project with a banned Contributor and withdraw the banned's lost colateral", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  await mrc.connect(user2).mint(1);
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();

                  await projectContract.finishProject(
                      500,
                      [user2.address, user1.address],
                      [70, 30]
                  );

                  await racksPM.createProject("Project2", 100, 1, 3);
                  const projectAddress2 = (await racksPM.getProjects())[1];

                  const Project2 = await ethers.getContractFactory("Project");
                  let project2Contract = Project2.attach(projectAddress2);

                  await mrc.connect(user3).mint(1);
                  await racksPM.connect(user3).registerContributor();
                  await erc20.connect(user3).approve(project2Contract.address, 100);
                  expect(await erc20.balanceOf(user3.address)).to.be.equal(10000000000);
                  await project2Contract.connect(user3).registerProjectContributor();
                  expect(await erc20.balanceOf(user3.address)).to.be.equal(9999999900);
                  await racksPM.setContributorStateToBanList(user3.address, true);
                  expect(await racksPM.isContributorBanned(user3.address)).to.be.equal(true);

                  await erc20.connect(user1).approve(project2Contract.address, 100);
                  await project2Contract.connect(user1).registerProjectContributor();

                  await erc20.connect(user2).approve(project2Contract.address, 100);
                  await project2Contract.connect(user2).registerProjectContributor();

                  await project2Contract.finishProject(
                      500,
                      [user2.address, user1.address /*, user3.address*/],
                      [65, 35 /*, 0*/]
                  );

                  expect(await erc20.balanceOf(user3.address)).to.be.equal(9999999900);

                  expect(
                      await project2Contract.getContributorParticipationWeight(user3.address)
                  ).to.be.equal(0);

                  const pcUserBanned = await project2Contract.getProjectContributor(0);
                  const pcUser1 = await project2Contract.getProjectContributor(1);
                  const pcUser2 = await project2Contract.getProjectContributor(2);

                  expect(pcUserBanned.wallet).to.be.equal(user3.address);
                  expect(pcUserBanned.reputationLevel).to.be.equal(1);
                  expect(pcUserBanned.reputationPoints).to.be.equal(0);

                  expect(pcUser1.wallet).to.be.equal(user1.address);
                  expect(pcUser1.reputationLevel).to.be.equal(3);
                  expect(pcUser1.reputationPoints).to.be.equal(25);
                  expect(pcUser2.wallet).to.be.equal(user2.address);
                  expect(pcUser2.reputationLevel).to.be.equal(4);
                  expect(pcUser2.reputationPoints).to.be.equal(75);

                  expect(await erc20.balanceOf(racksPM.address)).to.be.equal(100);
                  await racksPM.addAdmin(user1.address);
                  await expect(
                      racksPM.connect(user1).withdrawAllFunds(deployer.address)
                  ).to.be.revertedWith("Ownable: caller is not the owner");

                  await racksPM.withdrawAllFunds(deployer.address);
                  expect(await erc20.balanceOf(deployer.address)).to.be.equal(100000000100);
              });
              it("Should revert if the smart contract is paused", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  await mrc.connect(user2).mint(1);
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();

                  await racksPM.setIsPaused(true);

                  await expect(
                      projectContract.finishProject(500, [user2.address, user1.address], [70, 30])
                  ).to.be.revertedWithCustomError(racksPM, "pausedErr");

                  await racksPM.setIsPaused(false);

                  await expect(projectContract.deleteProject()).to.be.revertedWithCustomError(
                      projectContract,
                      "projectNoEditableErr"
                  );
              });
          });

          describe("Edit Project", () => {
              it("Should revert with pausedErr", async () => {
                  await await racksPM.setIsPaused(true);
                  await expect(projectContract.setColateralCost(100)).to.be.revertedWithCustomError(
                      racksPM,
                      "pausedErr"
                  );

                  await expect(
                      projectContract.setName("Project Updated")
                  ).to.be.revertedWithCustomError(racksPM, "pausedErr");

                  await expect(projectContract.setReputationLevel(3)).to.be.revertedWithCustomError(
                      racksPM,
                      "pausedErr"
                  );
                  await expect(
                      projectContract.setMaxContributorsNumber(3)
                  ).to.be.revertedWithCustomError(racksPM, "pausedErr");
              });

              it("Should revert with deletedErr", async () => {
                  await await projectContract.deleteProject();
                  await expect(projectContract.setColateralCost(100)).to.be.revertedWithCustomError(
                      projectContract,
                      "deletedErr"
                  );

                  await expect(
                      projectContract.setName("Project Updated")
                  ).to.be.revertedWithCustomError(projectContract, "deletedErr");

                  await expect(projectContract.setReputationLevel(3)).to.be.revertedWithCustomError(
                      projectContract,
                      "deletedErr"
                  );
                  await expect(
                      projectContract.setMaxContributorsNumber(3)
                  ).to.be.revertedWithCustomError(projectContract, "deletedErr");
              });
              it("Should revert with adminErr", async () => {
                  // Test not working because of Hardhat bug
                  // await expect(
                  //     projectContract.connect(user1).setColateralCost(100)
                  // ).to.be.revertedWithCustomError(projectContract, "adminErr");
                  await expect(
                      projectContract.connect(user1).setName("Project Updated")
                  ).to.be.revertedWithCustomError(projectContract, "adminErr");
                  await expect(
                      projectContract.connect(user1).setReputationLevel(3)
                  ).to.be.revertedWithCustomError(projectContract, "adminErr");
                  await expect(
                      projectContract.connect(user1).setMaxContributorsNumber(3)
                  ).to.be.revertedWithCustomError(projectContract, "adminErr");
              });

              it("Should revert with projectInvalidParameterErr", async () => {
                  await expect(projectContract.setName("")).to.be.revertedWithCustomError(
                      projectContract,
                      "projectInvalidParameterErr"
                  );
                  await expect(projectContract.setColateralCost(0)).to.be.revertedWithCustomError(
                      projectContract,
                      "projectInvalidParameterErr"
                  );
                  await expect(projectContract.setReputationLevel(0)).to.be.revertedWithCustomError(
                      projectContract,
                      "projectInvalidParameterErr"
                  );
                  await expect(
                      projectContract.setMaxContributorsNumber(0)
                  ).to.be.revertedWithCustomError(projectContract, "projectInvalidParameterErr");
              });

              it("Should revert with projectNoEditableErr", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  await expect(
                      projectContract.setName("Project Updated")
                  ).to.be.revertedWithCustomError(projectContract, "projectNoEditableErr");
                  await expect(projectContract.setColateralCost(200)).to.be.revertedWithCustomError(
                      projectContract,
                      "projectNoEditableErr"
                  );
                  await expect(projectContract.setReputationLevel(3)).to.be.revertedWithCustomError(
                      projectContract,
                      "projectNoEditableErr"
                  );
                  await expect(
                      projectContract.setMaxContributorsNumber(0)
                  ).to.be.revertedWithCustomError(projectContract, "projectNoEditableErr");

                  await expect(projectContract.deleteProject()).to.be.revertedWithCustomError(
                      projectContract,
                      "projectNoEditableErr"
                  );
              });

              it("Should edit Project with new Colateral Cost, Reputation Level and Max Contributors Number", async () => {
                  projectContract.setName("Project Updated");
                  projectContract.setReputationLevel(3);
                  projectContract.setColateralCost(500);
                  projectContract.setMaxContributorsNumber(5);

                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);

                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(
                      projectContract,
                      "projectContributorHasNoReputationEnoughErr"
                  );

                  const name = await projectContract.getName();
                  expect(name).to.be.equal("Project Updated");
                  const reputationLv = await projectContract.getReputationLevel();
                  expect(reputationLv.toNumber()).to.be.equal(3);
                  const colateralCost = await projectContract.getColateralCost();
                  expect(colateralCost.toNumber()).to.be.equal(500);
                  const maxContributorsNumber = await projectContract.getMaxContributors();
                  expect(maxContributorsNumber.toNumber()).to.be.equal(5);
              });
          });

          describe("Give away extra rewards after Project is finished", () => {
              it("Should revert with adminErr", async () => {
                  await expect(
                      projectContract.connect(user1).giveAway()
                  ).to.be.revertedWithCustomError(projectContract, "adminErr");
              });

              it("Should revert with pausedErr", async () => {
                  racksPM.setIsPaused(true);
                  await expect(projectContract.giveAway()).to.be.revertedWithCustomError(
                      racksPM,
                      "pausedErr"
                  );
              });

              it("Should revert with notCompletedErr", async () => {
                  await expect(projectContract.giveAway()).to.be.revertedWithCustomError(
                      projectContract,
                      "notCompletedErr"
                  );
              });

              it("Should give away successfully", async () => {
                  await mrc.connect(user1).mint(1);
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();

                  (await mrc.connect(user2).mint(1)).wait();
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  await projectContract.connect(user2).registerProjectContributor();

                  await projectContract.finishProject(
                      500,
                      [user2.address, user1.address],
                      [50, 50]
                  );

                  expect(await ethers.provider.getBalance(projectContract.address)).to.be.equal(0);
                  await deployer.sendTransaction({ to: projectContract.address, value: 100 });

                  expect(await ethers.provider.getBalance(projectContract.address)).to.be.equal(
                      100
                  );

                  await projectContract.giveAway();

                  expect(await ethers.provider.getBalance(projectContract.address)).to.be.equal(0);
              });
          });
      });
