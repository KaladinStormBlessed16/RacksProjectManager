const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Project Unit Tests", function () {
          let racksPM, mrc, erc20, projectContract, deployer, user1, user2, user3;

          beforeEach(async () => {
              accounts = await ethers.getSigners(); // could also do with getNamedAccounts
              deployer = accounts[0];
              user1 = accounts[1];
              user2 = accounts[2];
              user3 = accounts[3];
              await deployments.fixture(["rackspm", "mocks"]);
              let racksPMContract = await ethers.getContract("RacksProjectManager");
              racksPM = racksPMContract.connect(deployer);
              let mrcContract = await ethers.getContract("MRCRYPTO");
              mrc = await mrcContract.connect(deployer);
              let erc20Contract = await ethers.getContract("MockErc20");
              erc20 = await erc20Contract.connect(deployer);

              await racksPM.createProject(100, 1, 2);
              const projectAddress = await racksPM.projects(0);

              const Project = await ethers.getContractFactory("Project");
              projectContract = Project.attach(projectAddress);

              (await erc20.connect(user1).mintMore()).wait();
              (await erc20.connect(user2).mintMore()).wait();
              (await erc20.connect(user3).mintMore()).wait();
          });

          describe("Register Project Contributor", () => {
              it("Should revert with contributorErr", async () => {
                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(projectContract, "contributorErr");
              });

              it("Should revert with projectContributorAlreadyExistsErr and maxContributorsNumberExceededErr", async () => {
                  (await mrc.connect(user1).mint(1)).wait();
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  projectContract.connect(user1).registerProjectContributor();
                  await expect(
                      projectContract.connect(user1).registerProjectContributor()
                  ).to.be.revertedWithCustomError(
                      projectContract,
                      "projectContributorAlreadyExistsErr"
                  );

                  (await mrc.connect(user2).mint(1)).wait();
                  await racksPM.connect(user2).registerContributor();
                  await erc20.connect(user2).approve(projectContract.address, 100);
                  projectContract.connect(user2).registerProjectContributor();
                  (await mrc.connect(user3).mint(1)).wait();
                  await racksPM.connect(user3).registerContributor();
                  await erc20.connect(user3).approve(projectContract.address, 100);

                  await expect(
                      projectContract.connect(user3).registerProjectContributor()
                  ).to.be.revertedWithCustomError(
                      projectContract,
                      "maxContributorsNumberExceededErr"
                  );
              });

              it("Should register a new Project Contributor", async () => {
                  (await mrc.connect(user1).mint(1)).wait();
                  await racksPM.connect(user1).registerContributor();
                  await erc20.connect(user1).approve(projectContract.address, 100);
                  await projectContract.connect(user1).registerProjectContributor();
                  const projectContributor = await projectContract.projectContributors(0);
                  assert(projectContributor.wallet !== undefined);
              });
          });
      });
