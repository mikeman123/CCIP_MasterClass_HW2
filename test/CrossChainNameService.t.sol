// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {CCIPLocalSimulator} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {CrossChainNameServiceRegister} from "src/CrossChainNameServiceRegister.sol";
import {CrossChainNameServiceReceiver} from "src/CrossChainNameServiceReceiver.sol";
import {CrossChainNameServiceLookup} from "src/CrossChainNameServiceLookup.sol";

contract CrossChainNameServiceTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    CrossChainNameServiceRegister public register;
    CrossChainNameServiceReceiver public receiver;
    CrossChainNameServiceLookup public lookupSource;
    CrossChainNameServiceLookup public lookupReceiver;

    address public aliceEOA = address(0x1234567890123456789012345678901234567890);

    function setUp() public {
        // Create the CCIPLocalSimulator instance
        ccipLocalSimulator = new CCIPLocalSimulator();

        // Get the configuration from the simulator
        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            WETH9 wrappedNative,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        // Use the router address for the CrossChainNameService contracts
        address routerAddress = address(sourceRouter);

        // Instantiate the CrossChainNameService contracts
        register = new CrossChainNameServiceRegister(routerAddress, address(linkToken));
        receiver = new CrossChainNameServiceReceiver(routerAddress, address(linkToken), chainSelector);
        lookupSource = new CrossChainNameServiceLookup();
        lookupReceiver = new CrossChainNameServiceLookup();

        // Increase the gas limit
        uint256 gasLimit = 500_000; // Set a higher gas limit (adjust as necessary)

        // Enable the chain on the register instance only
        register.enableChain(chainSelector, address(receiver), gasLimit);

        // Set the CrossChainNameService addresses
        lookupSource.setCrossChainNameServiceAddress(address(register));
        lookupReceiver.setCrossChainNameServiceAddress(address(receiver));

        // Fund the register and receiver contracts with LINK tokens
        uint256 linkForFees = 10 ether; // Adjust the amount as necessary
        ccipLocalSimulator.requestLinkFromFaucet(address(register), linkForFees);
        ccipLocalSimulator.requestLinkFromFaucet(address(receiver), linkForFees);
    }

    function testRegisterAndLookup() public {
        // Log initial balances or any relevant state
        console.log("Initial balance of register:", address(register).balance);

        // Attempt to register a name with Alice's address
        try register.register("alice.ccns") {
            console.log("Register call succeeded");
        } catch Error(string memory reason) {
            console.log("Register call failed with reason:", reason);
        }

        // Log after registration attempt
        console.log("Balance of register after register call:", address(register).balance);

        // Lookup the address associated with the name
        address resolvedAddress = lookupSource.lookup("alice.ccns");

        // Log the resolved address
        console.log("Resolved address for alice.ccns:", resolvedAddress);

        // Assert that the resolved address matches Alice's address
        assertEq(resolvedAddress, aliceEOA);
    }
}
