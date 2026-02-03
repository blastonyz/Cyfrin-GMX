// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVault} from "../../src/lib/app/IVault.sol";
import "./StrategyTestHelper.sol";

contract VaultAndStrategyTest is StrategyTestHelper {
    function testWithdrawFromStrategy() public {
        uint256 wethAmount = 1e18;
        weth.approve(address(vault), type(uint256).max);

        uint256 shares = vault.deposit(wethAmount);
        vault.transfer(address(strategy), wethAmount);

        inc(wethAmount);
        dec(wethAmount, address(0));

        testHelper.set("ETH before", address(this).balance);
        testHelper.set("WETH before", weth.balanceOf(address(this)));
        (uint256 wethSent,) = vault.withdraw{value: EXECUTION_FEE}(shares);
        testHelper.set("WETH after", weth.balanceOf(address(this)));
        testHelper.set("ETH after", address(this).balance);

        uint256 wethDiff =
            testHelper.get("WETH after") - testHelper.get("WETH before");
        uint256 ethDiff =
            testHelper.get("ETH after") - testHelper.get("ETH before");

        assertEq(wethDiff, wethSent, "WETH sent");
        assertGe(wethDiff, wethAmount * 99 / 100, "WETH diff");
    }

    function testWithdrawFromCallback() public {
        uint256 wethAmount = 1e18;
        weth.approve(address(vault), type(uint256).max);

        uint256 shares = vault.deposit(wethAmount);
        vault.transfer(address(strategy), wethAmount);

        inc(wethAmount);

        // Partial withdraw
        (uint256 wethSent, bytes32 withdrawOrderKey) =
            vault.withdraw{value: EXECUTION_FEE}(shares / 2);

        assertEq(wethSent, 0, "WETH sent != 0");

        IVault.WithdrawOrder memory w0 =
            vault.getWithdrawOrder(withdrawOrderKey);
        assertEq(w0.account, address(this), "withdraw order account");
        assertGt(w0.shares, 0, "withdraw order shares");
        assertGt(w0.weth, 0, "withdraw order weth");

        // Execute order
        testHelper.set("WETH before", weth.balanceOf(address(this)));

        testHelper.mockOraclePrices({
            tokens: tokens,
            providers: providers,
            data: data,
            oracles: oracles
        });

        vm.prank(keeper);
        orderHandler.executeOrder(
            withdrawOrderKey,
            OracleUtils.SetPricesParams({
                tokens: tokens,
                providers: providers,
                data: data
            })
        );

        testHelper.set("WETH after", weth.balanceOf(address(this)));

        uint256 wethDiff =
            testHelper.get("WETH after") - testHelper.get("WETH before");
        assertGt(wethDiff, 0, "WETH = 0");

        assertEq(
            vault.balanceOf(address(this)),
            shares - w0.shares,
            "shares after withdraw"
        );

        IVault.WithdrawOrder memory w1 =
            vault.getWithdrawOrder(withdrawOrderKey);
        assertEq(w1.account, address(0), "withdraw order after withdraw");

        // Full withdraw
        shares = vault.balanceOf(address(this));
        (wethSent, withdrawOrderKey) =
            vault.withdraw{value: EXECUTION_FEE}(shares);

        // Execute order
        testHelper.set("WETH before", weth.balanceOf(address(this)));
        testHelper.set("ETH before", address(this).balance);

        testHelper.mockOraclePrices({
            tokens: tokens,
            providers: providers,
            data: data,
            oracles: oracles
        });

        vm.prank(keeper);
        orderHandler.executeOrder(
            withdrawOrderKey,
            OracleUtils.SetPricesParams({
                tokens: tokens,
                providers: providers,
                data: data
            })
        );

        testHelper.set("WETH after", weth.balanceOf(address(this)));
        testHelper.set("ETH after", address(this).balance);

        wethDiff = testHelper.get("WETH after") - testHelper.get("WETH before");
        uint256 ethDiff =
            testHelper.get("ETH after") - testHelper.get("ETH before");
        assertGt(wethDiff, 0, "WETH = 0");
        assertGt(ethDiff, EXECUTION_FEE * 99 / 100, "WETH refund");

        IVault.WithdrawOrder memory w2 =
            vault.getWithdrawOrder(withdrawOrderKey);
        assertEq(w1.account, address(0), "withdraw order after withdraw failed");
        assertEq(
            vault.balanceOf(address(this)), 0, "shares after withdraw failed"
        );

        Position.Props memory position =
            reader.getPosition(DATA_STORE, positionKey);

        assertEq(position.numbers.sizeInUsd, 0, "position size != 0");
        assertEq(
            position.numbers.collateralAmount, 0, "position collateral != 0"
        );
    }
}
