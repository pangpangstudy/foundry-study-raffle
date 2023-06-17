// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaaffle.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    // Events
    event RaffleEnter(address indexed player);
    // Args
    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;

    // initalstate
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        (
            entranceFee,
            interval,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            vrfCoordinatorV2,
            ,

        ) = helperConfig.activeNetworkConfig();
    }

    // test raffle state
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // test enterraffle
    function testRaffleRevertsWHenYouDontPayEnought() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecord = raffle.getPlayer(0);
        assert(playerRecord == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle)); //因为一个事件中最多三个indexed 所以前三个bool是索引时间筛选，第四个是非索引 第五个为发出事件者emitter
        emit RaffleEnter(PLAYER); //事件所期望的结果  即 发出的事件为 索引 PLAYER地址
        raffle.enterRaffle{value: entranceFee}();
    }

    //  结算中 需要timestamp  作弊码  wrap 设置blocktimestamp  roll设置block number
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // test
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    // checkupkeep
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // *************************************注意*****************************
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // ****************************************注意***********************
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    // performUpkeep
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // **********************************************注意**********************************
        // 这里的Error函数是有参数的，所以要加上参数abi编码测试
        // ********************************************************************************

        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        // It doesnt revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
        // 否则  **0x584327aa 函签
        /**  0x584327aa000000000000000000000000000000000000000000000000002386f26fc1000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000 != 0x584327aa */
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        // 注意执行的顺序 先vm作弊码 然后执行函数 发出事件 然后Vm.log[] memory entires = vm.getRecordedLogs();获取全部事件   具体顺序 事件索引 可以-vvvv查看具体问题
        vm.recordLogs(); //记录emit 事件
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        bytes32 requestId = entries[1].topics[0];
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1);
    }

    // fulfillRandomWords //
    modifier skipTest() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // 这是mock测试 所以 在 sepolia是不成功的
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 requestId
    ) public raffleEntered skipTest {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    // Big Test
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
        skipTest
    {
        // 假定参与人数
        // 1. enterRaffle  第一步
        uint256 additionalEntrances = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            // or address player = makeAddr("player")
            address player = address(uint160(i));
            hoax(player, 1 ether); //vm.deal 是没有prank的 只是转账功能  hoax是设置一个prank然后再转账== deal + prank

            raffle.enterRaffle{value: entranceFee}();
        }
        // 2. 执行performUpkeep mock 获取随机数
        // 先 requestId
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entires = vm.getRecordedLogs();
        bytes32 requestId = entires[1].topics[1];
        uint256 previousTimestamp = raffle.getLastTimeStamp();
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        uint256 price = entranceFee * (additionalEntrances + 1);
        // winner test
        assert(raffle.getRecentWinner() != address(0));
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getPlayerLength() == 0);
        assert(raffle.getLastTimeStamp() > previousTimestamp);

        assert(
            raffle.getRecentWinner().balance == price + 1 ether - entranceFee
        );
    }
}
