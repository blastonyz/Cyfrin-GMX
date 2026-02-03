// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {IDataStore} from "../../src/interfaces/IDataStore.sol";
import {IRoleStore} from "../../src/interfaces/IRoleStore.sol";
import {IChainlinkDataStreamProvider} from
    "../../src/interfaces/IChainlinkDataStreamProvider.sol";
import {IOracle} from "../../src/interfaces/IOracle.sol";
import {IPriceFeed} from "../../src/interfaces/IPriceFeed.sol";
import {OracleUtils} from "../../src/types/OracleUtils.sol";
import {Price} from "../../src/types/Price.sol";
import "../../src/Constants.sol";
import "../../src/lib/Errors.sol";
import {Keys} from "../../src/lib/Keys.sol";
import {Math} from "../../src/lib/Math.sol";

contract TestHelper is Test {
    IDataStore constant dataStore = IDataStore(DATA_STORE);
    IRoleStore constant roleStore = IRoleStore(ROLE_STORE);
    IOracle constant oracle = IOracle(ORACLE);
    IChainlinkDataStreamProvider constant provider =
        IChainlinkDataStreamProvider(CHAINLINK_DATA_STREAM_PROVIDER);

    mapping(string => uint256) public vals;

    function set(string memory key, uint256 val) public {
        vals[key] = val;
    }

    function get(string memory key) public view returns (uint256) {
        return vals[key];
    }

    function getRoleMember(bytes32 key) public view returns (address) {
        address[] memory addrs = roleStore.getRoleMembers(key, 0, 1);
        return addrs[0];
    }

    function mockGlvMarkets(address glv, address[] memory markets) public {
        bytes32 key = Keys.glvSupportedMarketListKey(glv);
        uint256 count = dataStore.getAddressCount(key);

        vm.mockCall(
            address(dataStore),
            abi.encodeCall(IDataStore.getAddressCount, (key)),
            abi.encode(markets.length)
        );

        vm.mockCall(
            address(dataStore),
            abi.encodeCall(IDataStore.getAddressValuesAt, (key, 0, count)),
            abi.encode(markets)
        );
    }

    struct OracleParams {
        address chainlink;
        // Multiplier to adjust decimals for index tokens which are EOA
        uint256 multiplier;
        int256 deltaPrice;
    }

    function mockOraclePrices(
        address[] memory tokens,
        address[] memory providers,
        bytes[] memory data,
        OracleParams[] memory oracles
    ) public returns (uint256[] memory prices) {
        uint256 n = tokens.length;

        prices = new uint256[](n);
        uint256[] memory answers = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            if (oracles[i].chainlink == address(0)) {
                prices[i] = 1e12;
                continue;
            }

            (, int256 answer,,,) =
                IPriceFeed(oracles[i].chainlink).latestRoundData();

            // Multiplier to make chainlink price x token amount have 30 decimals
            uint256 d = tokens[i].code.length > 0
                ? uint256(IERC20(tokens[i]).decimals())
                : 0;
            uint256 c = uint256(IPriceFeed(oracles[i].chainlink).decimals());
            uint256 multiplier = 10 ** (30 - c - d);

            prices[i] = uint256(answer) * multiplier / oracles[i].multiplier
                * Math.add(100, oracles[i].deltaPrice) / 100;
            answers[i] =
                uint256(answer) * Math.add(100, oracles[i].deltaPrice) / 100;

            require(prices[i] > 0, "price = 0");
        }

        for (uint256 i = 0; i < n; i++) {
            vm.mockCall(
                oracles[i].chainlink,
                abi.encodeCall(IPriceFeed.latestRoundData, ()),
                abi.encode(
                    // roundId
                    0,
                    answers[i],
                    // startedAt
                    0,
                    // updatedAt
                    block.timestamp,
                    // answeredInRound
                    0
                )
            );
            vm.mockCall(
                address(provider),
                abi.encodeCall(
                    IChainlinkDataStreamProvider.getOraclePrice,
                    (tokens[i], data[i])
                ),
                abi.encode(
                    OracleUtils.ValidatedPrice({
                        token: tokens[i],
                        min: prices[i] * 999 / 1000,
                        max: prices[i] * 1001 / 1000,
                        // NOTE: oracle timestamp must be >= order updated timestamp
                        timestamp: block.timestamp,
                        provider: providers[i]
                    })
                )
            );
        }
    }
}
