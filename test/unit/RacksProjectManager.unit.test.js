const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
	? describe.skip
	: describe("Racks Project Manager Unit Tests", function () {
			let racksPM, mrc, erc20, deployer, user1, user2, project1, holderValidation;

			beforeEach(async () => {
				accounts = await ethers.getSigners();
				[deployer, user1, user2] = accounts;

				await deployments.fixture(["rackspm", "mocks", "proxy"]);

				const mrcContract = await ethers.getContract("MRCRYPTO");
				mrc = mrcContract.connect(deployer);

				const erc20Contract = await ethers.getContract("MockErc20");
				erc20 = erc20Contract.connect(deployer);

				const holderValContract = await ethers.getContract("HolderValidation");
				holderValidation = holderValContract.connect(deployer);

				const Proxy = await ethers.getContract("TransparentUpgradeableProxy");
				const RacksPMContract = await ethers.getContract("RacksProjectManager");
				const ProxyImplementation = RacksPMContract.attach(Proxy.address);
				racksPM = ProxyImplementation.connect(deployer);

				const tx = await racksPM.createProject(
					"Project1",
					ethers.utils.parseEther("100"),
					1,
					2
				);
				const rc = await tx.wait();
				const { newProjectAddress } = rc.events.find(
					(e) => e.event == "NewProjectCreated"
				).args;

				project1 = await ethers.getContractAt("Project", newProjectAddress);
				project1 = project1.connect(deployer);
				await project1.approveProject();
			});

			describe("Setup", () => {
				it("Should mint ERC20 and MRC", async () => {
					let balanceOf = await erc20.balanceOf(deployer.address);
					expect(balanceOf).to.be.equal(ethers.utils.parseEther("10000"));

					await erc20.connect(user1).mintMore();
					balanceOf = await erc20.balanceOf(user1.address);
					expect(balanceOf).to.be.equal(ethers.utils.parseEther("10000"));

					await mrc.connect(user1).mint(1);
					assert((await mrc.balanceOf(user1.address)) == 1);
				});
			});

			describe("Create Project", () => {
				it("Should revert with RacksProjectManager_InvalidParameterErr", async () => {
					await expect(
						racksPM.createProject("Project2", ethers.utils.parseEther("100"), 0, 2)
					).to.be.revertedWithCustomError(
						racksPM,
						"RacksProjectManager_InvalidParameterErr"
					);

					await expect(
						racksPM.createProject("Project2", ethers.utils.parseEther("100"), 1, 0)
					).to.be.revertedWithCustomError(
						racksPM,
						"RacksProjectManager_InvalidParameterErr"
					);

					await expect(
						racksPM.createProject("", ethers.utils.parseEther("100"), 1, 3)
					).to.be.revertedWithCustomError(
						racksPM,
						"RacksProjectManager_InvalidParameterErr"
					);

					await expect(
						racksPM.createProject(
							"Project to looooooooooooooooong",
							ethers.utils.parseEther("100"),
							1,
							3
						)
					).to.be.revertedWithCustomError(
						racksPM,
						"RacksProjectManager_InvalidParameterErr"
					);
				});

				it("Should create project and then deleted correctly", async () => {
					const tx = await racksPM
						.connect(user1)
						.createProject("Project2", ethers.utils.parseEther("100"), 1, 2);

					const rc = await tx.wait();
					const { newProjectAddress: project2Address } = rc.events.find(
						(e) => e.event == "NewProjectCreated"
					).args;
					const project2 = await ethers.getContractAt("Project", project2Address);
					await project2.approveProject();

					assert.lengthOf(await racksPM.getProjects(), 2);

					let projects = await racksPM.getProjects();
					expect(projects).to.have.same.members([project1.address, project2.address]);

					expect(await project2.isActive()).to.be.true;
					expect(await project2.isDeleted()).to.be.false;

					await mrc.connect(user1).mint(1);
					await erc20.connect(user1).mintMore();
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(project2.address, ethers.utils.parseEther("100"));
					await project2.connect(user1).registerProjectContributor();

					await erc20.connect(user2).mintMore();
					await erc20
						.connect(user2)
						.approve(project2.address, ethers.utils.parseEther("500"));
					const fundTx = await project2
						.connect(user2)
						.fundProject(ethers.utils.parseEther("500"));

					expect(await project2.getAccountFunds(user2.address)).to.be.equal(
						ethers.utils.parseEther("500")
					);
					expect(await project2.getTotalAmountFunded()).to.be.equal(
						ethers.utils.parseEther("500")
					);
					let balanceBefore = await erc20.balanceOf(user2.address);
					expect(balanceBefore).to.be.equal(ethers.utils.parseEther("9500"));

					await project2.removeContributor(user1.address, true);

					await fundTx.wait();

					await project2.deleteProject();

					expect(await project2.getAccountFunds(user2.address)).to.be.equal(
						ethers.utils.parseEther("0")
					);
					expect(await project2.getTotalAmountFunded()).to.be.equal(
						ethers.utils.parseEther("0")
					);
					let balanceAfter = await erc20.balanceOf(user2.address);
					expect(balanceAfter).to.be.equal(ethers.utils.parseEther("10000"));

					expect(await project2.isActive()).to.be.false;
					expect(await project2.isDeleted()).to.be.true;

					projects = await racksPM.getProjects();
					expect(projects).to.have.same.members([project1.address]);

					await racksPM.createProject("Project3", ethers.utils.parseEther("0"), 1, 2);
				});

				it("Should revert if the smart contract is paused", async () => {
					await racksPM.setIsPaused(true);

					await racksPM.addAdmin(user1.address);
					await expect(
						racksPM
							.connect(user1)
							.createProject("Project2", ethers.utils.parseEther("100"), 1, 2)
					).to.be.revertedWithCustomError(racksPM, "RacksProjectManager_IsPausedErr");
				});
			});

			describe("Register Contributor", () => {
				it("Should revert with RacksProjectManager_NotHolderErr", async () => {
					await expect(
						racksPM.connect(user1).registerContributor()
					).to.be.revertedWithCustomError(racksPM, "RacksProjectManager_NotHolderErr");
				});

				it("Should revert with RacksProjectManager_ContributorAlreadyExistsErr", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await expect(
						racksPM.connect(user1).registerContributor()
					).to.be.revertedWithCustomError(
						racksPM,
						"RacksProjectManager_ContributorAlreadyExistsErr"
					);
				});

				it("Should register Contributor", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					let contributor = await racksPM
						.connect(user1)
						.getContributorData(user1.address);
					assert(contributor.wallet == user1.address);
					assert.equal(await racksPM.getNumberOfContributors(), 1);
				});

				it("Should revert if the smart contract is paused", async () => {
					await racksPM.setIsPaused(true);

					await mrc.connect(user1).mint(1);
					await expect(
						racksPM.connect(user1).registerContributor()
					).to.be.revertedWithCustomError(racksPM, "RacksProjectManager_IsPausedErr");
				});
			});

			describe("List Projects according to Contributor Level", () => {
				it("Should revert if it is not Holder and it is not Admin", async () => {
					await expect(
						racksPM.connect(user1).getProjects()
					).to.be.revertedWithCustomError(racksPM, "RacksProjectManager_NotHolderErr");
				});

				it("Should retieve only Lv1 Projects called by a Holder", async () => {
					await racksPM.createProject("Project2", ethers.utils.parseEther("100"), 2, 2);
					await racksPM.createProject("Project3", ethers.utils.parseEther("100"), 3, 2);

					await mrc.connect(user1).mint(1);
					const projects = await racksPM.connect(user1).getProjects();
					assert.lengthOf(
						projects.filter((p) => p !== ethers.constants.AddressZero),
						1
					);
				});

				it("Should retrieve only Lv2 or less Projects called by a Contributor", async () => {
					await racksPM.createProject("Project2", ethers.utils.parseEther("100"), 2, 2);
					await racksPM.createProject("Project3", ethers.utils.parseEther("100"), 3, 2);

					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();

					// set level of contributor to lvl 2
					await racksPM.setAccountToContributorData(user1.address, [
						user1.address,
						100, // 100 points --> lvl 2
						false,
					]);

					const projects = await racksPM.connect(user1).getProjects();
					assert.lengthOf(
						projects.filter((p) => p !== ethers.constants.AddressZero),
						2
					);
				});

				it("Should retrieve all Projects called by an Admin", async () => {
					await racksPM.createProject("Project2", ethers.utils.parseEther("100"), 2, 2);
					await racksPM.createProject("Project3", ethers.utils.parseEther("100"), 3, 2);

					const projects = await racksPM.getProjects();
					assert.lengthOf(
						projects.filter((p) => p !== ethers.constants.AddressZero),
						3
					);
				});
			});

			describe("Holder Validation", () => {
				it("Add Collection Should revert with Ownable Error", async () => {
					await expect(
						holderValidation.connect(user1).addCollection(mrc.address)
					).to.be.revertedWith("Ownable: caller is not the owner");
				});

				it("Delete Collection Should revert with Ownable Error", async () => {
					await expect(
						holderValidation.connect(user1).deleteCollection(mrc.address)
					).to.be.revertedWith("Ownable: caller is not the owner");
				});

				it("Should add collection succesfully", async () => {
					await holderValidation.addCollection(user1.address);
					assert.lengthOf(await holderValidation.getAllCollections(), 2);
				});

				it("Should delete 1 collection succesfully", async () => {
					await holderValidation.deleteCollection(mrc.address);
					assert.lengthOf(await holderValidation.getAllCollections(), 0);
				});

				it("Should delete collections succesfully", async () => {
					await holderValidation.addCollection(user1.address);
					await holderValidation.deleteCollection(user1.address);
					assert.lengthOf(await holderValidation.getAllCollections(), 1);
					await holderValidation.deleteCollection(mrc.address);
					assert.lengthOf(await holderValidation.getAllCollections(), 0);
				});

				it("Should return false if User is not a holder", async () => {
					expect(await holderValidation.isHolder(user1.address)).to.be.equal(
						ethers.constants.AddressZero
					);
				});

				it("Should return true if User is a holder", async () => {
					await mrc.connect(user1).mint(1);
					expect(await holderValidation.isHolder(user1.address)).to.not.be.equal(
						ethers.constants.AddressZero
					);
				});
			});
	  });
