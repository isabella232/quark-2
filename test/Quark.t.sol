// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./lib/YulHelper.sol";
import "./lib/Counter.sol";

import "../src/Relayer.sol";

contract QuarkTest is Test {
    event Ping(uint256 value);

    Relayer public relayer;
    Counter public counter;

    constructor() {
        relayer = new Relayer();
        console.log("Relayer deployed to: %s", address(relayer));

        counter = new Counter();
        counter.setNumber(0);
        console.log("Counter deployed to: %s", address(counter));
    }

    function setUp() public {
        // nothing
    }

    // function testPing() public {
    //     bytes memory ping = new YulHelper().get("Ping.yul/Logger.json");
    //     console.logBytes(ping);

    //     // TODO: Check who emitted.
    //     vm.expectEmit(false, false, false, true);
    //     emit Ping(55);

    //     (bool success, bytes memory data) = address(relayer).call(ping);
    //     assertEq(success, true);
    //     assertEq(data, abi.encode());
    // }

    function testIncrementer() public {
        bytes memory incrementer = new YulHelper().get("Incrementer.yul/Incrementer.json");
        console.logBytes(incrementer);

        // assertEq(incrementer, QuarkInterface(quark).virtualCode81());
        // assertEq(address(0x6c022704D948c71930B35B6F6bb725bc8d687E7F), QuarkInterface(quark).quarkAddress25(address(1)));

        assertEq(counter.number(), 0);

        vm.prank(address(0xaa));
        (bool success0, bytes memory data0) = address(relayer).call(incrementer);
        assertEq(success0, true);
        assertEq(data0, abi.encode());
        assertEq(counter.number(), 3);
    }
}
