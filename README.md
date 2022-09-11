<a name="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<br />
<div align="center">
  <a href="https://github.com/racks-community/racksprojectmanager">
    <img src="https://avatars.githubusercontent.com/u/105239504?s=200&v=4" alt="Logo" width="120" height="120">
  </a>

<h3 align="center">Racks Projects Manager - Smart Contracts</h3>

  <p align="center">
    <br />
    <a href="https://github.com/racks-community/racksprojectmanager"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/racks-community/racksprojectmanager/issues">Report Bug</a>
    ·
    <a href="https://github.com/racks-community/racksprojectmanager/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#contributor">Contributors</a></li>
        <li><a href="#completed-project">Completed project</a></li>
        <li><a href="#flow-diagram">Flow diagram</a></li>
      </ul>
      <li><a href="#build-with">Build with</a></li>
      <li><a href="#getting-started">Getting Started</a></li>
      <ul>
        <li><a href="#installation">Installation</a></li>
      </ul>
      <li><a href="#usage">Usage</a></li>
      <ul>
        <li><a href="#run-tests">Run test</a></li>
      </ul>
    </li>
  </ol>
</details>

# Racks Project Manager

```

                   ▟██████████   █████    ▟███████████   █████████████
                 ▟████████████   █████  ▟█████████████   █████████████   ███████████▛
                ▐█████████████   █████▟███████▛  █████   █████████████   ██████████▛
                 ▜██▛    █████   ███████████▛    █████       ▟██████▛    █████████▛
                   ▀     █████   █████████▛      █████     ▟██████▛
                         █████   ███████▛      ▟█████▛   ▟██████▛
        ▟█████████████   ██████              ▟█████▛   ▟██████▛   ▟███████████████▙
       ▟██████████████   ▜██████▙          ▟█████▛   ▟██████▛   ▟██████████████████▙
      ▟███████████████     ▜██████▙      ▟█████▛   ▟██████▛   ▟█████████████████████▙
                             ▜██████▙            ▟██████▛          ┌────────┐
                               ▜██████▙        ▟██████▛            │  LABS  │
                                                                   └────────┘

```

## About the project

This Smart Contract allows the management of Projects in Racks Labs with the aim of organizing the Mr.Crypto developer community, looking forward to boosting productivity and channeling efforts and contributions into specific development lines required by the community itself.

Racks Project Manager administrators can create Projects by setting the cost of collateral, the required reputation level and the maximum number of contributors allowed.

A Mr.Crypto holder can use Racks Project Manager to view existing projects, but will only be able to view projects labeled as Lv1, which are projects that are not at risk of being leaked because they have already been announced. To see the projects with the highest risk, you will need to register as a Contributor and increase your reputation level by participating in projects available for your current level. Admins have access to all projects.

### Contributor

Once registered as a Contributor, you can register for one of the Projects that your reputation level allows. For this, you have to pay the cost of collateral as long as the project has not already reached the maximum number of Contributors.
At any time, a contributor may be banned by an admin for negative behavior, in which case he will lose the collateral stored in the contract, will not receive rewards from the projects in which he is enrolled and will not be able to enroll in any other project.

### Completed Project

The admins will be able to dictate the end of the project, providing the total number of reputation points that will be distributed among the Contributors, as well as two lists with the addresses of the contributors and their percentage of participation, respectively. This list must contain as many addresses as contributors are registered, and in case there is a banned contributor, their address (or any placeholder) must still be included with a participation percentage of 0.

Once the project is finished, the contributors will receive their collateral back if they have not been banned, they will receive reputation points in relation to their participation in the project, and in the future possible extra rewards depending on the project.
The participation percentages will be recorded in the project for future equity distributions.

### Flow Diagram

![image](https://user-images.githubusercontent.com/62185201/184548492-7c10d736-d8e4-4326-8fe8-e83164358723.png)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Build with

 [![Solidity][Solidity.com]][Solidity-url]

 [![Hardhat][Hardhat.com]][Hardhat-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Getting Started

### Installation

* Git clone

```sh
git clone https://github.com/racks-community/racksprojectmanager
```

* Install dependencies

```sh
npm install
```

* Recommended [`hardhat-shorthand`](https://hardhat.org/hardhat-runner/docs/guides/command-line-completion)

```sh
 npm install --global hardhat-shorthand
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage

### Run tests

```sh
npx hardhat test
```

or

```sh
hh test
```

[contributors-shield]: https://img.shields.io/github/contributors/racks-community/racksprojectmanager.svg?style=for-the-badge
[contributors-url]: https://github.com/racks-community/racksprojectmanager/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/racks-community/racksprojectmanager.svg?style=for-the-badge
[forks-url]: https://github.com/racks-community/racksprojectmanager/network/members
[stars-shield]: https://img.shields.io/github/stars/racks-community/racksprojectmanager.svg?style=for-the-badge
[stars-url]: https://github.com/racks-community/racksprojectmanager/stargazers
[issues-shield]: https://img.shields.io/github/issues/racks-community/racksprojectmanager.svg?style=for-the-badge
[issues-url]: https://github.com/racks-community/racksprojectmanager/issues
[license-shield]: https://img.shields.io/github/license/racks-community/racksprojectmanager.svg?style=for-the-badge
[license-url]: https://github.com/racks-community/racksprojectmanager/blob/master/LICENSE.txt
[Solidity.com]: https://img.shields.io/badge/Solidity-444444?style=for-the-badge&logo=solidity&logoColor=white
[Solidity-url]: https://soliditylang.org/
[Hardhat.com]: https://raw.githubusercontent.com/DanielSintimbrean/BlackJack-3.0/master/images/Hardhat-url.svg
[Hardhat-url]: https://hardhat.org/
