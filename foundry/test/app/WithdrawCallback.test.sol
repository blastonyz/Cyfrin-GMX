// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../lib/TestHelper.sol";
import {EventUtils} from "../../src/types/EventUtils.sol";
import {Order} from "../../src/types/Order.sol";
import {IVault} from "../../src/lib/app/IVault.sol";
import {Role} from "../../src/lib/Role.sol";
import {WithdrawCallback} from "@exercises/app/WithdrawCallback.sol";

contract MockVault {
    bytes32 public key;
    bool public ok;

    mapping(bytes32 => IVault.WithdrawOrder) public withdrawOrders;

    function set(bytes32 _key, address account, uint256 shares, uint256 weth)
        external
    {
        withdrawOrders[_key] =
            IVault.WithdrawOrder({account: account, shares: shares, weth: weth});
    }

    function getWithdrawOrder(bytes32 _key)
        external
        view
        returns (IVault.WithdrawOrder memory)
    {
        return withdrawOrders[_key];
    }

    function removeWithdrawOrder(bytes32 _key, bool _ok) external {
        key = _key;
        ok = _ok;
        delete withdrawOrders[_key];
    }
}

contract WithdrawCallbackTest is Test {
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant usdc = IERC20(USDC);
    uint256 constant EXECUTION_FEE = 0.01 * 1e18;

    TestHelper testHelper;
    WithdrawCallback cb;
    MockVault vault;
    bytes32 constant KEY = bytes32(uint256(1));
    address constant ACCOUNT = address(1);
    uint256 constant SHARES = 100;
    uint256 constant WETH_AMOUNT = 101;

    receive() external payable {}

    function setUp() public virtual {
        testHelper = new TestHelper();
        vault = new MockVault();
        cb = new WithdrawCallback(address(vault));

        // Mock hasRole for ORDER_HANDLER
        vm.mockCall(
            ROLE_STORE,
            abi.encodeWithSignature("hasRole(address,bytes32)", ORDER_HANDLER, Role.ORDER_KEEPER),
            abi.encode(true)
        );

        deal(WETH, address(this), 1000 * 1e18);

        vault.set(KEY, ACCOUNT, SHARES, WETH_AMOUNT);
    }

    function write(bytes32 key, address account) internal {
        bytes32 slot = keccak256(abi.encode(key, uint256(1)));
        vm.store(address(cb), slot, bytes32(uint256(uint160(account))));
    }

    function testRefundExecutionFee() public {
        EventUtils.EventLogData memory eventData;

        // Test auth
        vm.expectRevert();
        cb.refundExecutionFee(KEY, eventData);

        // Test empty refund account
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.refundExecutionFee(KEY, eventData);

        // Test success
        write(KEY, ACCOUNT);

        testHelper.set("ETH account before", ACCOUNT.balance);
        deal(ORDER_HANDLER, 100);
        vm.prank(ORDER_HANDLER);
        cb.refundExecutionFee{value: 100}(KEY, eventData);
        testHelper.set("ETH account after", ACCOUNT.balance);

        assertEq(cb.refunds(KEY), address(0), "refund account");

        uint256 ethDiff = testHelper.get("ETH account after")
            - testHelper.get("ETH account before");
        assertEq(ethDiff, 100, "ETH diff");
    }

    function testAfterOderExecution() public {
        EventUtils.EventLogData memory eventData;
        Order.Props memory order;

        // Test auth
        vm.expectRevert();
        cb.afterOrderExecution(KEY, order, eventData);

        // Test empty withdraw order
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.afterOrderExecution(bytes32(uint256(0)), order, eventData);

        // Test invalid order type
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.afterOrderExecution(KEY, order, eventData);

        // Test success
        order.numbers.orderType = Order.OrderType.MarketDecrease;

        weth.transfer(address(cb), 1e18);

        testHelper.set("WETH account before", weth.balanceOf(ACCOUNT));
        vm.prank(ORDER_HANDLER);
        cb.afterOrderExecution(KEY, order, eventData);
        testHelper.set("WETH account after", weth.balanceOf(ACCOUNT));

        assertEq(cb.refunds(KEY), ACCOUNT, "refund account");
        IVault.WithdrawOrder memory w = vault.getWithdrawOrder(KEY);
        assertEq(w.account, address(0), "withdraw order");
        assertEq(vault.ok(), true, "vault ok");

        uint256 wethDiff = testHelper.get("WETH account after")
            - testHelper.get("WETH account before");
        assertEq(wethDiff, WETH_AMOUNT, "WETH diff");
        assertEq(
            weth.balanceOf(address(vault)), 1e18 - WETH_AMOUNT, "WETH callback"
        );
    }

    function testAfterOderCancellation() public {
        EventUtils.EventLogData memory eventData;
        Order.Props memory order;

        // Test auth
        vm.expectRevert();
        cb.afterOrderCancellation(KEY, order, eventData);

        // Test empty withdraw order
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.afterOrderCancellation(bytes32(uint256(0)), order, eventData);

        // Test invalid order type
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.afterOrderCancellation(KEY, order, eventData);

        // Test success
        order.numbers.orderType = Order.OrderType.MarketDecrease;

        vm.prank(ORDER_HANDLER);
        cb.afterOrderCancellation(KEY, order, eventData);

        assertEq(cb.refunds(KEY), ACCOUNT, "refund account");
        IVault.WithdrawOrder memory w = vault.getWithdrawOrder(KEY);
        assertEq(w.account, address(0), "withdraw order");
        assertEq(vault.ok(), false, "vault ok");
    }

    function testAfterOderFrozen() public {
        EventUtils.EventLogData memory eventData;
        Order.Props memory order;

        // Test auth
        vm.expectRevert();
        cb.afterOrderFrozen(KEY, order, eventData);

        // Test empty withdraw order
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.afterOrderFrozen(bytes32(uint256(0)), order, eventData);

        // Test invalid order type
        vm.expectRevert();
        vm.prank(ORDER_HANDLER);
        cb.afterOrderFrozen(KEY, order, eventData);

        // Test success
        order.numbers.orderType = Order.OrderType.MarketDecrease;

        vm.prank(ORDER_HANDLER);
        cb.afterOrderFrozen(KEY, order, eventData);

        assertEq(cb.refunds(KEY), ACCOUNT, "refund account");
        IVault.WithdrawOrder memory w = vault.getWithdrawOrder(KEY);
        assertEq(w.account, address(0), "withdraw order");
        assertEq(vault.ok(), false, "vault ok");
    }
}
