// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "./lib/TestHelper.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IReader} from "../src/interfaces/IReader.sol";
import {IOrderHandler} from "../src/interfaces/IOrderHandler.sol";
import {OracleUtils} from "../src/types/OracleUtils.sol";
import {Order} from "../src/types/Order.sol";
import {Position} from "../src/types/Position.sol";
import "../src/Constants.sol";
import {Role} from "../src/lib/Role.sol";
import {Oracle} from "../src/lib/Oracle.sol";
import {LimitSwap} from "@exercises/LimitSwap.sol";

contract LimitSwapTest is Test {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IOrderHandler constant orderHandler = IOrderHandler(ORDER_HANDLER);
    IReader constant reader = IReader(READER);

    TestHelper testHelper;
    Oracle oracle;
    LimitSwap limit;
    address keeper;

    // Oracle params
    address[] tokens;
    address[] providers;
    bytes[] data;
    TestHelper.OracleParams[] oracles;

    function setUp() public {
        testHelper = new TestHelper();
        keeper = testHelper.getRoleMember(Role.ORDER_KEEPER);
        oracle = new Oracle();
        limit = new LimitSwap();
        deal(USDC, address(this), 1000 * 1e6);

        // Mock hasRole for critical addresses with CONTROLLER role
        // Mock for ROUTER (0x900173A66dbD345006C51fA35fA3aB760FcD843b)
        vm.mockCall(
            ROLE_STORE,
            abi.encodeWithSignature(
                "hasRole(address,bytes32)",
                0x900173A66dbD345006C51fA35fA3aB760FcD843b,
                bytes32(0x97adf037b2472f4a6a9825eff7d2dd45e37f2dc308df2a260d6a72af4189a65b)
            ),
            abi.encode(true)
        );

        // Mock for OrderBookUtils (0xe68CAAACdf6439628DFD2fe624847602991A31eB)
        vm.mockCall(
            ROLE_STORE,
            abi.encodeWithSignature(
                "hasRole(address,bytes32)",
                0xe68CAAACdf6439628DFD2fe624847602991A31eB,
                bytes32(0x97adf037b2472f4a6a9825eff7d2dd45e37f2dc308df2a260d6a72af4189a65b)
            ),
            abi.encode(true)
        );

        // Mock for EXCHANGE_ROUTER with ROUTER_PLUGIN
        vm.mockCall(
            ROLE_STORE,
            abi.encodeWithSignature(
                "hasRole(address,bytes32)",
                EXCHANGE_ROUTER,
                Role.ROUTER_PLUGIN
            ),
            abi.encode(true)
        );

        // Mock for keeper with ORDER_KEEPER role
        vm.mockCall(
            ROLE_STORE,
            abi.encodeWithSignature(
                "hasRole(address,bytes32)",
                keeper,
                Role.ORDER_KEEPER
            ),
            abi.encode(true)
        );

        tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;

        providers = new address[](2);
        providers[0] = CHAINLINK_DATA_STREAM_PROVIDER;
        providers[1] = CHAINLINK_DATA_STREAM_PROVIDER;

        // NOTE: data kept empty for mock calls
        data = new bytes[](2);

        oracles = new TestHelper.OracleParams[](2);
        oracles[0] = TestHelper.OracleParams({
            chainlink: CHAINLINK_USDC_USD,
            multiplier: 1,
            deltaPrice: 0
        });
        oracles[1] = TestHelper.OracleParams({
            chainlink: CHAINLINK_ETH_USD,
            multiplier: 1,
            deltaPrice: 0
        });
    }

    function testLimit() public {
        uint256 executionFee = 1e18;
        uint256 usdcAmount = 1000 * 1e6;
        usdc.approve(address(limit), usdcAmount);

        uint256 ethPrice = oracle.getPrice(CHAINLINK_ETH_USD);
        uint256 maxEthPrice = ethPrice * 99 / 100;

        bytes32 limitOrderKey =
            limit.createLimitOrder{value: executionFee}(usdcAmount, maxEthPrice);

        Order.Props memory limitOrder =
            reader.getOrder(DATA_STORE, limitOrderKey);
        assertEq(
            limitOrder.addresses.receiver, address(limit), "order receiver"
        );
        assertEq(
            uint256(limitOrder.numbers.orderType),
            uint256(Order.OrderType.LimitSwap),
            "order type"
        );

        // Execute limit order
        skip(1);

        oracles[0].deltaPrice = 0;
        oracles[1].deltaPrice = -10;

        testHelper.mockOraclePrices({
            tokens: tokens,
            providers: providers,
            data: data,
            oracles: oracles
        });

        testHelper.set("ETH keeper before", keeper.balance);
        testHelper.set("ETH limit before", address(limit).balance);

        vm.prank(keeper);
        orderHandler.executeOrder(
            limitOrderKey,
            OracleUtils.SetPricesParams({
                tokens: tokens,
                providers: providers,
                data: data
            })
        );

        testHelper.set("ETH keeper after", keeper.balance);
        testHelper.set("ETH limit after", address(limit).balance);
        testHelper.set("WETH limit", weth.balanceOf(address(limit)));
        testHelper.set("USDC limit", usdc.balanceOf(address(limit)));

        uint256 wethBal = testHelper.get("WETH limit");
        uint256 usdcBal = testHelper.get("USDC limit");

        console.log("WETH %e", wethBal);
        console.log("USDC %e", usdcBal);

        assertGe(
            testHelper.get("ETH keeper after"),
            testHelper.get("ETH keeper before"),
            "Keeper execution fee"
        );
        assertGe(
            testHelper.get("ETH limit after"),
            testHelper.get("ETH limit before"),
            "limit execution fee refund"
        );
        assertGt(wethBal, 0, "WETH balance = 0");
        assertEq(usdcBal, 0, "USDC balance > 0");
    }
}
