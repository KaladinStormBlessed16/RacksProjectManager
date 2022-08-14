# Racks Project Manager

This Smart Contract allows the management of Projects in Racks Labs with the aim of organizing the Mr.Crypto developer community, looking forward to boosting productivity and channeling efforts and contributions into specific development lines required by the community itself.

Racks Project Manager administrators can create Projects by setting the cost of collateral, the required reputation level and the maximum number of contributors allowed.

A Mr.Crypto holder can use Racks Project Manager to view existing projects, but will only be able to view projects labeled as Lv1, which are projects that are not at risk of being leaked because they have already been announced. To see the projects with the highest risk, you will need to register as a Contributor and increase your reputation level by participating in projects available for your current level. Admins have access to all projects.

## Contributor

Once registered as a Contributor, you can register for one of the Projects that your reputation level allows. For this, you have to pay the cost of collateral as long as the project has not already reached the maximum number of Contributors.
At any time, a contributor may be banned by an admin for negative behavior, in which case he will lose the collateral stored in the contract, will not receive rewards from the projects in which he is enrolled and will not be able to enroll in any other project.

## Completed Project

The admins will be able to dictate the end of the project, providing the total number of reputation points that will be distributed among the Contributors, as well as two lists with the addresses of the contributors and their percentage of participation, respectively. This list must contain as many addresses as contributors are registered, and in case there is a banned contributor, their address (or any placeholder) must still be included with a participation percentage of 0.

Once the project is finished, the contributors will receive their collateral back if they have not been banned, they will receive reputation points in relation to their participation in the project, and in the future possible extra rewards depending on the project.
The participation percentages will be recorded in the project for future equity distributions.

# Flow Diagram

![image](https://user-images.githubusercontent.com/62185201/184548492-7c10d736-d8e4-4326-8fe8-e83164358723.png)
