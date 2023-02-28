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

				await deployments.fixture(["rackspm", "mocks", "proxy"]);

				const Proxy = await ethers.getContract("TransparentUpgradeableProxy");
				const RacksPMContract = await ethers.getContract("RacksProjectManager");
				const ProxyImplementation = RacksPMContract.attach(Proxy.address);
				racksPM = ProxyImplementation.connect(deployer);

				let mrcContract = await ethers.getContract("MRCRYPTO");
				mrc = mrcContract.connect(deployer);

				let erc20Contract = await ethers.getContract("MockErc20");
				erc20 = erc20Contract.connect(deployer);

				await racksPM.createProject("Project1", ethers.utils.parseEther("100"), 1, 2);
				const projectAddress = await (await racksPM.getProjects())[0];

				projectContract = await ethers.getContractAt("Project", projectAddress);
				await projectContract.approveProject();

				await erc20.connect(user1).mintMore();
				await erc20.connect(user2).mintMore();
				await erc20.connect(user3).mintMore();
			});

			describe("Register Project Contributor", () => {
				it("Should revert with Project_IsNotContributor", async () => {
					await expect(
						projectContract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(projectContract, "Project_IsNotContributor");
				});

				it("Should revert with Project_ContributorNotInProject because can not remove a contributor that is not in the project", async () => {
					await expect(
						projectContract.removeContributor(user1.address, true)
					).to.be.revertedWithCustomError(
						projectContract,
						"Project_ContributorNotInProject"
					);
				});

				it("Should revert with Project_ContributorAlreadyExistsErr and Project_MaxContributorNumberExceededErr", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await expect(
						projectContract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(
						projectContract,
						"Project_ContributorAlreadyExistsErr"
					);

					const previosBalance = await erc20.balanceOf(user2.address);

					await mrc.connect(user2).mint(1);
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();

					assert.equal(await projectContract.getNumberOfContributors(), 2);

					await mrc.connect(user3).mint(1);
					await racksPM.connect(user3).registerContributor();
					await erc20
						.connect(user3)
						.approve(projectContract.address, ethers.utils.parseEther("100"));

					await expect(
						projectContract.connect(user3).registerProjectContributor()
					).to.be.revertedWithCustomError(
						projectContract,
						"Project_MaxContributorNumberExceededErr"
					);

					// if remove one contributor you can add another one
					await projectContract.removeContributor(user2.address, true);

					assert.equal(await projectContract.getNumberOfContributors(), 1);

					const postBalance = await erc20.balanceOf(user2.address);
					assert.equal(postBalance.toString(), previosBalance.toString());

					await projectContract.connect(user3).registerProjectContributor();

					assert.equal(await projectContract.getNumberOfContributors(), 2);
				});

				it("Should revert if Contributor is banned with Project_ContributorIsBannedErr", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await racksPM.setContributorStateToBanList(user1.address, true);
					expect(await racksPM.isContributorBanned(user1.address)).to.be.true;

					await expect(
						projectContract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(
						projectContract,
						"Project_ContributorIsBannedErr"
					);
				});

				it("Should revert if Contributor has no Reputation Level Enough with Project_ContributorHasNoReputationEnoughErr", async () => {
					await racksPM.createProject("Project2", ethers.utils.parseEther("100"), 2, 3);
					const projects = await racksPM.getProjects();
					const projectAddress2 = projects[0];

					const Project2 = await ethers.getContractFactory("Project");
					let project2Contract = Project2.attach(projectAddress2);
					await project2Contract.approveProject();

					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));

					await expect(
						project2Contract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(
						project2Contract,
						"Project_ContributorHasNoReputationEnoughErr"
					);
				});

				it("Should register a new Project Contributor", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					expect(
						await erc20.allowance(user1.address, projectContract.address)
					).to.be.equal(await projectContract.getColateralCost());
					await projectContract.connect(user1).registerProjectContributor();
					const projectContributorsAddress =
						await projectContract.getAllContributorsAddress();
					assert(projectContributorsAddress[0] === user1.address);
					assert.equal(await projectContract.getNumberOfContributors(), 1);
				});

				it("Should revert if the smart contract is paused", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));

					await racksPM.setIsPaused(true);

					await expect(
						projectContract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(projectContract, "Project_IsPausedErr");
				});

				it("Should revert if the project is deleted", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));

					await projectContract.deleteProject();

					await expect(
						projectContract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(projectContract, "Project_IsDeletedErr");
				});
			});

			describe("Modify Contributor", () => {
				it("Should modify reputation points of a Project Contributor", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					expect(
						await erc20.allowance(user1.address, projectContract.address)
					).to.be.equal(await projectContract.getColateralCost());
					await projectContract.connect(user1).registerProjectContributor();
					const projectContributorsAddress =
						await projectContract.getAllContributorsAddress();
					assert(projectContributorsAddress[0] === user1.address);
					assert.equal(await projectContract.getNumberOfContributors(), 1);

					await racksPM.modifyContributorRP(user1.address, 150, true);
					let contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 2);
					assert.equal(contr.reputationPoints.toString(), 150);

					await racksPM.modifyContributorRP(user1.address, 100, false);
					contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 1);
					assert.equal(contr.reputationPoints.toString(), 50);

					await racksPM.modifyContributorRP(user1.address, 20, false);
					contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 1);
					assert.equal(contr.reputationPoints.toString(), 30);

					await racksPM.modifyContributorRP(user1.address, 100, true);
					contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 2);
					assert.equal(contr.reputationPoints.toString(), 130);

					await racksPM.modifyContributorRP(user1.address, 100, true);
					contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 3);
					assert.equal(contr.reputationPoints.toString(), 230);

					await racksPM.modifyContributorRP(user1.address, 120, true);
					contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 3);
					assert.equal(contr.reputationPoints.toString(), 350);

					await racksPM.modifyContributorRP(user1.address, 690, true);
					contr = await racksPM.getContributorData(user1.address);
					assert.equal(await racksPM.getContributorLevel(user1.address), 5);
					assert.equal(contr.reputationPoints.toString(), 690 + 350);
				});
			});

			describe("Finish Project", () => {
				it("Should revert with Project_NotAdminErr", async () => {
					await expect(
						projectContract.connect(user1).finishProject(500, [user2.address], [20])
					).to.be.revertedWithCustomError(projectContract, "Project_NotAdminErr");
				});

				it("Should revert with Project_ContributorNotInProject", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await expect(
						projectContract.finishProject(500, [user2.address], [20])
					).to.be.revertedWithCustomError(
						projectContract,
						"Project_ContributorNotInProject"
					);
				});

				it("Should revert with Project_InvalidParameterErr", async () => {
					await mrc.connect(user2).mint(1);
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();

					await expect(
						projectContract.finishProject(500, [user2.address], [])
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");

					await expect(
						projectContract.finishProject(500, [], [20])
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");

					await expect(
						projectContract.finishProject(0, [user2.address], [20])
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");
				});

				it("Should revert because of less contributors array length than project contributors registered with Project_InvalidParameterErr", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await mrc.connect(user2).mint(1);
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();

					await expect(
						projectContract.finishProject(
							500,
							[user2.address],
							[ethers.utils.parseEther("100")]
						)
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");
				});

				it("Should revert becase de total of participation weight is greeter than 100 ", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					expect(await erc20.balanceOf(user1.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);
					await projectContract.connect(user1).registerProjectContributor();
					expect(await erc20.balanceOf(user1.address)).to.be.equal(
						ethers.utils.parseEther("9900")
					);

					(await mrc.connect(user2).mint(1)).wait();
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					expect(await erc20.balanceOf(user2.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);
					await projectContract.connect(user2).registerProjectContributor();
					expect(await erc20.balanceOf(user2.address)).to.be.equal(
						ethers.utils.parseEther("9900")
					);

					await expect(
						projectContract.finishProject(500, [user2.address, user1.address], [70, 70])
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");
				});

				it("Should revert with Project_FinishedErr", async () => {
					await mrc.connect(user2).mint(1);
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();
					await projectContract.finishProject(500, [user2.address], [100]);

					await expect(
						projectContract.finishProject(500, [user2.address], [100])
					).to.be.revertedWithCustomError(projectContract, "Project_FinishedErr");
				});

				it("Should set the Project as finished, refund colateral and grant rewards", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					expect(await erc20.balanceOf(user1.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);
					await projectContract.connect(user1).registerProjectContributor();
					expect(await erc20.balanceOf(user1.address)).to.be.equal(
						ethers.utils.parseEther("9900")
					);

					(await mrc.connect(user2).mint(1)).wait();
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					expect(await erc20.balanceOf(user2.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);
					await projectContract.connect(user2).registerProjectContributor();
					expect(await erc20.balanceOf(user2.address)).to.be.equal(
						ethers.utils.parseEther("9900")
					);

					expect(await projectContract.isFinished()).to.be.false;

					await projectContract.finishProject(
						500,
						[user2.address, user1.address],
						[70, 30]
					);

					expect(await projectContract.isFinished()).to.be.true;

					expect(await erc20.balanceOf(user1.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);
					expect(await erc20.balanceOf(user2.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);

					expect(
						await projectContract.getContributorParticipation(user1.address)
					).to.be.equal(30);
					expect(
						await projectContract.getContributorParticipation(user2.address)
					).to.be.equal(70);

					const pcUser1 = await racksPM.getContributorData(user1.address);
					const pcUser2 = await racksPM.getContributorData(user2.address);
					const lvlUser1 = await racksPM.getContributorLevel(user1.address);
					const lvlUser2 = await racksPM.getContributorLevel(user2.address);

					expect(pcUser1.wallet).to.be.equal(user1.address);
					expect(lvlUser1).to.be.equal(2);
					expect(pcUser1.reputationPoints).to.be.equal(150);
					expect(pcUser2.wallet).to.be.equal(user2.address);
					expect(lvlUser2).to.be.equal(3);
					expect(pcUser2.reputationPoints).to.be.equal(350);
				});

				it("Should finish a project, create a new project, finish that project with a banned Contributor and withdraw the banned's lost colateral", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await mrc.connect(user2).mint(1);
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();

					await projectContract.finishProject(
						500,
						[user2.address, user1.address],
						[70, 30]
					);

					await racksPM.createProject("Project2", ethers.utils.parseEther("100"), 1, 3);
					const projectAddress2 = (await racksPM.getProjects())[0];

					const Project2 = await ethers.getContractFactory("Project");
					let project2Contract = Project2.attach(projectAddress2);
					await project2Contract.approveProject();

					await mrc.connect(user3).mint(1);
					await racksPM.connect(user3).registerContributor();
					await erc20
						.connect(user3)
						.approve(project2Contract.address, ethers.utils.parseEther("100"));
					expect(await erc20.balanceOf(user3.address)).to.be.equal(
						ethers.utils.parseEther("10000")
					);
					await project2Contract.connect(user3).registerProjectContributor();
					expect(await erc20.balanceOf(user3.address)).to.be.equal(
						ethers.utils.parseEther("9900")
					);
					await racksPM.setContributorStateToBanList(user3.address, true);
					expect(await racksPM.isContributorBanned(user3.address)).to.be.equal(true);

					await erc20
						.connect(user1)
						.approve(project2Contract.address, ethers.utils.parseEther("100"));
					await project2Contract.connect(user1).registerProjectContributor();

					await erc20
						.connect(user2)
						.approve(project2Contract.address, ethers.utils.parseEther("100"));
					await project2Contract.connect(user2).registerProjectContributor();

					const pcUser22 = await racksPM.getContributorData(user2.address);
					const lvlUser22 = await racksPM.getContributorLevel(user2.address);

					expect(lvlUser22).to.be.equal(3);
					expect(pcUser22.reputationPoints).to.be.equal(350);

					await project2Contract.finishProject(
						500,
						[user2.address, user1.address],
						[65, 35]
					);

					expect(await erc20.balanceOf(user3.address)).to.be.equal(
						ethers.utils.parseEther("9900")
					);
					expect(await erc20.balanceOf(user2.address)).to.be.equal(
						ethers.utils.parseEther("10065")
					);
					expect(await erc20.balanceOf(user1.address)).to.be.equal(
						ethers.utils.parseEther("10035")
					);

					expect(
						await project2Contract.getContributorParticipation(user3.address)
					).to.be.equal(0);

					const pcUserBanned = await racksPM.getContributorData(user3.address);
					const pcUser1 = await racksPM.getContributorData(user1.address);
					const pcUser2 = await racksPM.getContributorData(user2.address);

					expect(pcUserBanned.wallet).to.be.equal(user3.address);
					expect(pcUserBanned.reputationPoints).to.be.equal(0);

					expect(pcUser1.wallet).to.be.equal(user1.address);
					expect(await racksPM.getContributorLevel(user1.address)).to.be.equal(3);
					expect(pcUser1.reputationPoints).to.be.equal(325);
					expect(pcUser2.wallet).to.be.equal(user2.address);
					expect(await racksPM.getContributorLevel(user2.address)).to.be.equal(4);
					expect(pcUser2.reputationPoints).to.be.equal(675);
				});
				it("Should revert if the smart contract is paused", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await mrc.connect(user2).mint(1);
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();

					await racksPM.setIsPaused(true);

					await expect(
						projectContract.finishProject(500, [user2.address, user1.address], [70, 30])
					).to.be.revertedWithCustomError(projectContract, "Project_IsPausedErr");

					await racksPM.setIsPaused(false);

					await expect(projectContract.deleteProject()).to.be.revertedWithCustomError(
						projectContract,
						"Project_IsNotEditableErr"
					);
				});
			});

			describe("Edit Project", () => {
				it("Should revert with Project_IsPausedErr", async () => {
					await await racksPM.setIsPaused(true);
					await expect(
						projectContract.setColateralCost(ethers.utils.parseEther("100"))
					).to.be.revertedWithCustomError(projectContract, "Project_IsPausedErr");

					await expect(
						projectContract.setName("Project Updated")
					).to.be.revertedWithCustomError(projectContract, "Project_IsPausedErr");

					await expect(
						projectContract.setReputationLevel(3)
					).to.be.revertedWithCustomError(projectContract, "Project_IsPausedErr");
					await expect(
						projectContract.setMaxContributorsNumber(3)
					).to.be.revertedWithCustomError(projectContract, "Project_IsPausedErr");
				});

				it("Should revert with Project_IsDeletedErr", async () => {
					await await projectContract.deleteProject();
					await expect(
						projectContract.setColateralCost(ethers.utils.parseEther("100"))
					).to.be.revertedWithCustomError(projectContract, "Project_IsDeletedErr");

					await expect(
						projectContract.setName("Project Updated")
					).to.be.revertedWithCustomError(projectContract, "Project_IsDeletedErr");

					await expect(
						projectContract.setReputationLevel(3)
					).to.be.revertedWithCustomError(projectContract, "Project_IsDeletedErr");
					await expect(
						projectContract.setMaxContributorsNumber(3)
					).to.be.revertedWithCustomError(projectContract, "Project_IsDeletedErr");
				});
				it("Should revert with Project_NotAdminErr", async () => {
					// Test not working because of Hardhat bug
					await expect(
						projectContract
							.connect(user1)
							.setColateralCost(ethers.utils.parseEther("100"))
					).to.be.revertedWithCustomError(projectContract, "Project_NotAdminErr");
					await expect(
						projectContract.connect(user1).setName("Project Updated")
					).to.be.revertedWithCustomError(projectContract, "Project_NotAdminErr");
					await expect(
						projectContract.connect(user1).setReputationLevel(3)
					).to.be.revertedWithCustomError(projectContract, "Project_NotAdminErr");
					await expect(
						projectContract.connect(user1).setMaxContributorsNumber(3)
					).to.be.revertedWithCustomError(projectContract, "Project_NotAdminErr");
				});

				it("Should revert with Project_InvalidParameterErr", async () => {
					await expect(projectContract.setName("")).to.be.revertedWithCustomError(
						projectContract,
						"Project_InvalidParameterErr"
					);
					await expect(
						projectContract.setReputationLevel(0)
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");
					await expect(
						projectContract.setMaxContributorsNumber(0)
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");
				});

				it("Should revert with Project_IsNotEditableErr", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await expect(
						projectContract.setName("Project Updated")
					).to.be.revertedWithCustomError(projectContract, "Project_IsNotEditableErr");
					await expect(
						projectContract.setColateralCost(200)
					).to.be.revertedWithCustomError(projectContract, "Project_IsNotEditableErr");
					await expect(
						projectContract.setReputationLevel(3)
					).to.be.revertedWithCustomError(projectContract, "Project_IsNotEditableErr");
					await expect(
						projectContract.setMaxContributorsNumber(0)
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");

					await expect(projectContract.deleteProject()).to.be.revertedWithCustomError(
						projectContract,
						"Project_IsNotEditableErr"
					);
				});

				it("Should edit Project with new Colateral Cost, Reputation Level and Max Contributors Number", async () => {
					projectContract.setName("Project Updated");
					projectContract.setReputationLevel(3);
					projectContract.setColateralCost(500);
					projectContract.setMaxContributorsNumber(5);

					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));

					await expect(
						projectContract.connect(user1).registerProjectContributor()
					).to.be.revertedWithCustomError(
						projectContract,
						"Project_ContributorHasNoReputationEnoughErr"
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
				it("Should revert with Project_NotAdminErr", async () => {
					await expect(
						projectContract.connect(user1).giveAway()
					).to.be.revertedWithCustomError(projectContract, "Project_NotAdminErr");
				});

				it("Should revert with Project_IsPausedErr", async () => {
					racksPM.setIsPaused(true);
					await expect(projectContract.giveAway()).to.be.revertedWithCustomError(
						projectContract,
						"Project_IsPausedErr"
					);
				});

				it("Should revert with Project_NotCompletedErr", async () => {
					await expect(projectContract.giveAway()).to.be.revertedWithCustomError(
						projectContract,
						"Project_NotCompletedErr"
					);
				});

				it("Should give away successfully", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					(await mrc.connect(user2).mint(1)).wait();
					await racksPM.connect(user2).registerContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user2).registerProjectContributor();

					await projectContract.finishProject(
						500,
						[user2.address, user1.address],
						[50, 50]
					);
				});
			});
			describe("Fund Project", () => {
				it("Should revert with Project_InvalidParameterErr on project with no contributors", async () => {
					await erc20.connect(user2).approve(projectContract.address, 500);
					await expect(
						projectContract.connect(user2).fundProject(500)
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");

					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await expect(
						projectContract.connect(user2).fundProject(0)
					).to.be.revertedWithCustomError(projectContract, "Project_InvalidParameterErr");
				});

				it("Should revert with ERC20: insufficient allowance", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();

					await expect(
						projectContract.connect(user2).fundProject(500)
					).to.be.revertedWith("ERC20: insufficient allowance");
				});

				it("Should fund the Project succesfully", async () => {
					await mrc.connect(user1).mint(1);
					await racksPM.connect(user1).registerContributor();
					await erc20
						.connect(user1)
						.approve(projectContract.address, ethers.utils.parseEther("100"));
					await projectContract.connect(user1).registerProjectContributor();
					await erc20
						.connect(user2)
						.approve(projectContract.address, ethers.utils.parseEther("500"));
					const tx = await projectContract
						.connect(user2)
						.fundProject(ethers.utils.parseEther("500"));
					const rc = await tx.wait();
					const event = rc.events.find((e) => e.event == "ProjectFunded").args;
					expect(event).to.exist;
					expect(await projectContract.getAccountFunds(user2.address)).to.be.equal(
						ethers.utils.parseEther("500")
					);
					expect(await projectContract.getTotalAmountFunded()).to.be.equal(
						ethers.utils.parseEther("500")
					);
				});
			});
	  });
