// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.t.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract CreateSubscription is Script {
    // 1. subId
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            ,
            ,
            address vrfCoordinatorV2,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorV2, deployerKey);
    }

    function createSubscription(
        address vrfCoordinatorV2,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinatorV2)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

// add fund
contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function run() external {
        fundSubscriptionUsingSconfig();
    }

    function fundSubscriptionUsingSconfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            uint64 subscriptionId,
            ,
            address vrfCoordinatorV2,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinatorV2, subscriptionId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinatorV2).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            uint64 subscriptionId,
            ,
            address vrfCoordinatorV2,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(
            subscriptionId,
            mostRecentlyDeployed,
            vrfCoordinatorV2,
            deployerKey
        );
    }

    function addConsumer(
        uint64 subscriptionId,
        address contractToAddToVrf,
        address vrfCoordinatorV2,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinatorV2).addConsumer(
            subscriptionId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }
}
