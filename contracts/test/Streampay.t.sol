// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Streampay} from "../src/Streampay.sol";

contract StreamUSD is ERC20 {constructor() ERC20("USDT test fixture","USDT"){} function decimals() public pure override returns(uint8){return 6;} function mint(address a,uint256 n) external {_mint(a,n);}}

contract StreampayTest is Test {
    address client=address(0xC1);address freelancer=address(0xF1);address other=address(0x0E);
    Streampay s;StreamUSD usd;
    function setUp() public {s=new Streampay();usd=new StreamUSD();vm.deal(client,100 ether);usd.mint(client,1000e6);}
    function test_botStreamWithdrawAndFinish() public {
        vm.prank(client);uint256 id=s.create{value:10 ether}(freelancer,address(0),10 ether,0,1000,"Design sprint");
        vm.warp(block.timestamp+250);assertEq(s.withdrawable(id),2.5 ether);
        vm.prank(other);vm.expectRevert(bytes("not recipient"));s.withdraw(id);
        vm.prank(freelancer);s.withdraw(id);assertEq(freelancer.balance,2.5 ether);
        vm.warp(block.timestamp+5000);vm.prank(freelancer);s.withdraw(id);assertEq(freelancer.balance,10 ether);
        vm.prank(client);vm.expectRevert(bytes("finished"));s.cancel(id);
    }
    function test_cancelSettlesBothSides() public {
        vm.startPrank(client);usd.approve(address(s),100e6);uint256 id=s.create(freelancer,address(usd),100e6,0,100,"");vm.stopPrank();
        vm.warp(block.timestamp+40);vm.prank(freelancer);s.withdraw(id);
        vm.warp(block.timestamp+20);vm.prank(client);s.cancel(id);
        assertEq(usd.balanceOf(freelancer),60e6);assertEq(usd.balanceOf(client),940e6);assertEq(usd.balanceOf(address(s)),0);
        vm.warp(block.timestamp+1000);assertEq(s.withdrawable(id),0);
        vm.prank(freelancer);vm.expectRevert(bytes("finished"));s.cancel(id);
    }
    function test_futureStartEarnsNothingYet() public {
        uint64 start=uint64(block.timestamp+1 days);
        vm.prank(client);uint256 id=s.create{value:1 ether}(freelancer,address(0),1 ether,start,100,"");
        assertEq(s.earned(id),0);vm.prank(client);s.cancel(id);assertEq(client.balance,100 ether);
    }
    function test_rejectsSelfStream() public {
        vm.prank(client);vm.expectRevert(bytes("bad stream"));s.create{value:1 ether}(client,address(0),1 ether,0,100,"");
    }
}
