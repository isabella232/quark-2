// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/CodeJar.sol";
import "../src/Manifest.sol";
import "./lib/Counter.sol";

contract ManifestTest is Test {
    CodeJar public codeJar;
    Manifest public manifest;

    constructor() {
        codeJar = new CodeJar();
        console.log("Code jar deployed to: %s", address(codeJar));

        manifest = new Manifest(codeJar);
        console.log("Manifest deployed to: %s", address(manifest));
    }

    function setUp() public {
        // nothing
    }

    function testManifestDeployCounter() public {
        Counter c = Counter(manifest.deploy(type(Counter).creationCode, "test", bytes32(uint256(0x112233))));

        c.setNumber(5);
    }
}
