// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "../src/interfaces/IERC20.sol";
import {IChainlinkDataStreamProvider} from
    "../src/interfaces/IChainlinkDataStreamProvider.sol";
import {OracleUtils} from "../src/types/OracleUtils.sol";
import {IDataStore} from "../src/interfaces/IDataStore.sol";
import {IReader} from "../src/interfaces/IReader.sol";
import {IGlvReader} from "../src/interfaces/IGlvReader.sol";
import "../src/Constants.sol";
import {Price} from "../src/types/Price.sol";
import {Market} from "../src/types/Market.sol";
import {MarketUtils} from "../src/types/MarketUtils.sol";
import {Price} from "../src/types/Price.sol";
import {Glv} from "../src/types/Glv.sol";
import {MarketPoolValueInfo} from "../src/types/MarketPoolValueInfo.sol";
import {Keys} from "../src/lib/Keys.sol";
import {Oracle} from "../src/lib/Oracle.sol";
import {MarketHelper} from "./lib/MarketHelper.sol";

contract Base is Test {
    IReader internal constant reader = IReader(READER);
    IGlvReader internal constant glvReader = IGlvReader(GLV_READER);
    IDataStore internal constant dataStore = IDataStore(DATA_STORE);
}

contract Key is Base {
    function getMaxPnlFactor(bytes32 pnlFactorType, address market, bool isLong)
        internal
        view
        returns (uint256)
    {
        return dataStore.getUint(
            Keys.maxPnlFactorKey(pnlFactorType, market, isLong)
        );
    }

    function test() public {
        bytes32 pnlFactorType = Keys.MAX_PNL_FACTOR_FOR_DEPOSITS;
        uint256 f = getMaxPnlFactor(pnlFactorType, GM_TOKEN_BTC_WBTC_USDC, true);
        console.log("f %e", f);
    }
}

/*
contract GlvDev is Base {
    function test() public {
        address glv = GLV_TOKEN_WETH_USDC;
        bytes32 key = Keys.glvSupportedMarketListKey(glv);

        uint256 count = dataStore.getAddressCount(key);
        address[] memory markets = new address[](2);
        markets[0] = GM_TOKEN_ETH_WETH_USDC;
        markets[1] = GM_TOKEN_DOGE_WETH_USDC;

        vm.mockCall(
            address(dataStore),
            abi.encodeCall(IDataStore.getAddressValuesAt, (key, 0, count)),
            abi.encode(markets)
        );

        address[] memory res = dataStore.getAddressValuesAt(key, 0, count);
        for (uint256 i = 0; i < res.length; i++) {
            console.log("addr", i, res[i]);
        }
    }
}
*/

/*
contract MarketDev is Base {
    MarketHelper marketHelper = new MarketHelper();

    function getMinCollateralFactor(address market)
        internal
        view
        returns (uint256)
    {
        return dataStore.getUint(Keys.minCollateralFactorKey(market));
    }

    function test_getMinCollateralFactor() public {
        vm.skip(true);
        uint256 f = getMinCollateralFactor(GM_TOKEN_ETH_WETH_USDC);
        console.log("factor %e", f);
        // 5e27 / 1e30 = 0.005 -> 0.5% of position size
    }

    function test_getFundingFactors() public {
        vm.skip(true);
        address market = GM_TOKEN_ETH_WETH_USDC;
        uint256 fundingIncreaseFactorPerSecond =
            dataStore.getUint(Keys.fundingIncreaseFactorPerSecondKey(market));
        uint256 thresholdForStableFunding =
            dataStore.getUint(Keys.thresholdForStableFundingKey(market));
        uint256 thresholdForDecreaseFunding =
            dataStore.getUint(Keys.thresholdForDecreaseFundingKey(market));
        console.log("fi %e", fundingIncreaseFactorPerSecond);
        console.log("s %e", thresholdForStableFunding);
        console.log("d %e", thresholdForDecreaseFunding);
    }

    function getOptimalUsageFactor(address market, bool isLong)
        internal
        view
        returns (uint256)
    {
        return dataStore.getUint(Keys.optimalUsageFactorKey(market, isLong));
    }

    function test_getOptimalUsageFactor() public {
        vm.skip(true);
        address market = GM_TOKEN_ETH_WETH_USDC;
        uint256 l = getOptimalUsageFactor(market, true);
        uint256 s = getOptimalUsageFactor(market, false);
        console.log("l %e", l);
        console.log("s %e", s);
    }

    function getOpenInterest(
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return dataStore.getUint(
            Keys.openInterestKey(market, collateralToken, isLong)
        ) / divisor;
    }

    function test_getOpenInterest() public {
        vm.skip(true);
        address market = GM_TOKEN_ETH_WETH_USDC;
        uint256 ll = getOpenInterest(market, WETH, true, 1);
        uint256 ls = getOpenInterest(market, USDC, true, 1);
        uint256 sl = getOpenInterest(market, WETH, false, 1);
        uint256 ss = getOpenInterest(market, USDC, false, 1);

        console.log("ll %e", ll);
        console.log("ls %e", ls);
        console.log("sl %e", sl);
        console.log("ss %e", ss);
        console.log("l %e", ll + ls);
        console.log("s %e", sl + ss);
    }

    function getVirtualInventoryForSwaps(address market)
        internal
        view
        returns (bool, uint256, uint256)
    {
        bytes32 virtualMarketId =
            dataStore.getBytes32(Keys.virtualMarketIdKey(market));
        console.logBytes32(virtualMarketId);
        if (virtualMarketId == bytes32(0)) {
            return (false, 0, 0);
        }

        return (
            true,
            dataStore.getUint(
                Keys.virtualInventoryForSwapsKey(virtualMarketId, true)
            ),
            dataStore.getUint(
                Keys.virtualInventoryForSwapsKey(virtualMarketId, false)
            )
        );
    }

    function getVirtualInventoryForPositions(address token)
        internal
        view
        returns (bool, int256)
    {
        bytes32 virtualTokenId =
            dataStore.getBytes32(Keys.virtualTokenIdKey(token));
        if (virtualTokenId == bytes32(0)) {
            return (false, 0);
        }

        return (
            true,
            dataStore.getInt(
                Keys.virtualInventoryForPositionsKey(virtualTokenId)
            )
        );
    }

    function test_getVirtualInv() public {
        {
            (, uint256 l1, uint256 s1) =
                getVirtualInventoryForSwaps(GM_TOKEN_ETH_WETH_USDC);
            (, uint256 l2, uint256 s2) =
                getVirtualInventoryForSwaps(GM_TOKEN_AAVE_WETH_USDC);

            console.log("s1 %e", s1);
            console.log("s2 %e", s2);
            console.log("l1 %e", l1);
            console.log("l2 %e", l2);
        }
    }

    function logMarket(
        address market,
        address index,
        address long,
        address short
    ) private {
        MarketHelper.Info memory info = marketHelper.get(index);
        console.log("name:", info.name);
        console.log("market:", market);
        console.log("index:", index);
        console.log("long:", long);
        console.log("short:", short);
        console.log("index = EOA?", index.code.length == 0);
        address oracle = dataStore.getAddress(Keys.priceFeedKey(index));
        console.log("GMX oracle:", oracle);
    }

    function test_glvTokens() public {
        vm.skip(true);

        IGlvReader.GlvInfo[] memory info =
            glvReader.getGlvInfoList(DATA_STORE, 0, 100);
        for (uint256 i = 0; i < info.length; i++) {
            for (uint256 j = 0; j < info[i].markets.length; j++) {
                address addr = info[i].markets[j];
                Market.Props memory market = reader.getMarket(DATA_STORE, addr);
                console.log("-------------", i, j);
                logMarket(
                    market.marketToken,
                    market.indexToken,
                    market.longToken,
                    market.shortToken
                );
            }
        }
    }

    function getMarketKeys(uint256 start, uint256 end)
        internal
        view
        returns (address[] memory)
    {
        return dataStore.getAddressValuesAt(Keys.MARKET_LIST, start, end);
    }

    function test_getMarketKeys() public {
        vm.skip(true);
        address[] memory keys = getMarketKeys(0, 100);
        for (uint256 i = 0; i < keys.length; i++) {
            console.log("key", i, keys[i]);
        }
    }
}
*/

/*
contract OracleDev is Base {
    IChainlinkDataStreamProvider constant provider =
        IChainlinkDataStreamProvider(CHAINLINK_DATA_STREAM_PROVIDER);

    function test_getMarketTokenPrice() public {
        vm.skip(true);
        (int256 p, MarketPoolValueInfo.Props memory info) = reader
            .getMarketTokenPrice({
            dataStore: DATA_STORE,
            market: Market.Props({
                marketToken: GM_TOKEN_BTC_WBTC_USDC,
                indexToken: GMX_BTC_WBTC_USDC_INDEX,
                longToken: WBTC,
                shortToken: USDC
            }),
            indexTokenPrice: Price.Props({
                min: 9.1725761563 * 1e26,
                max: 9.1725761563 * 1e26
            }),
            longTokenPrice: Price.Props({min: 9.1828 * 1e26, max: 9.1828 * 1e26}),
            shortTokenPrice: Price.Props({min: 9.9994 * 1e23, max: 9.9994 * 1e23}),
            pnlFactorType: PNL_FACTOR_TYPE_DEPOSIT,
            maximize: true
        });
        console.log("p %e", p);
    }
}
*/
