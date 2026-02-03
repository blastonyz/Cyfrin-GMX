// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Test.sol";
import {Order} from "../../src/types/Order.sol";
import {EventUtils} from "../../src/types/EventUtils.sol";

contract DecreaseCallback {
    enum Status {
        None,
        Executed,
        Cancelled,
        Frozen
    }

    Status public status;
    bytes32 public orderKey;
    bytes32 public refundOrderKey;
    uint256 public refundAmount;

    receive() external payable {}

    function reset() external {
        status = Status.None;
        orderKey = bytes32(uint256(0));
        refundOrderKey = bytes32(uint256(0));
        refundAmount = 0;
    }

    function refundExecutionFee(
        bytes32 key,
        EventUtils.EventLogData memory eventData
    ) external payable {
        refundOrderKey = key;
        refundAmount = msg.value;
    }

    function afterOrderExecution(
        bytes32 key,
        Order.Props memory order,
        EventUtils.EventLogData memory eventData
    ) external {
        orderKey = key;
        status = Status.Executed;
    }

    function afterOrderCancellation(
        bytes32 key,
        Order.Props memory order,
        EventUtils.EventLogData memory eventData
    ) external {
        orderKey = key;
        status = Status.Cancelled;
    }

    function afterOrderFrozen(
        bytes32 key,
        Order.Props memory order,
        EventUtils.EventLogData memory eventData
    ) external {
        orderKey = key;
        status = Status.Frozen;
    }
}
