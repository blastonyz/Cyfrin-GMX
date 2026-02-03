// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "./lib/TestHelper.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IDataStore} from "../src/interfaces/IDataStore.sol";
import {Keys} from "../src/lib/Keys.sol";
import "../src/Constants.sol";
import {Role} from "../src/lib/Role.sol";
import {Oracle} from "../src/lib/Oracle.sol";
import {ClaimFundingFees} from "@exercises/ClaimFundingFees.sol";

contract ClaimFundingFeesTest is Test {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    IDataStore constant dataStore = IDataStore(DATA_STORE);

    TestHelper testHelper;
    Oracle oracle;
    ClaimFundingFees claimFundingFees;
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
        claimFundingFees = new ClaimFundingFees();

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

        vm.prank(EXCHANGE_ROUTER);
        dataStore.incrementUint(
            Keys.claimableFundingAmountKey(
                GM_TOKEN_ETH_WETH_USDC, USDC, address(claimFundingFees)
            ),
            1e6
        );

        vm.prank(EXCHANGE_ROUTER);
        dataStore.incrementUint(
            Keys.claimableFundingAmountKey(
                GM_TOKEN_ETH_WETH_USDC, WETH, address(claimFundingFees)
            ),
            2e18
        );
    }

    function testClaimFundingFees() public {
        uint256 usdcFundingFees =
            claimFundingFees.getClaimableAmount(GM_TOKEN_ETH_WETH_USDC, USDC);
        uint256 wethFundingFees =
            claimFundingFees.getClaimableAmount(GM_TOKEN_ETH_WETH_USDC, WETH);

        console.log("USDC %e", usdcFundingFees);
        console.log("WETH %e", wethFundingFees);

        assertGe(usdcFundingFees, 1e6, "USDC claimable funding fee");
        assertGe(wethFundingFees, 2e18, "WETH claimable funding fee");

        claimFundingFees.claimFundingFees();

        testHelper.set("USDC", usdc.balanceOf(address(claimFundingFees)));
        testHelper.set("WETH", weth.balanceOf(address(claimFundingFees)));

        console.log("USDC %e", testHelper.get("USDC"));
        console.log("WETH %e", testHelper.get("WETH"));

        assertGe(testHelper.get("USDC"), 1e6, "USDC");
        assertGe(testHelper.get("WETH"), 2e18, "WETH");
    }
}
