// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Tickpay} from "../src/Tickpay.sol";

contract StreamUSD is ERC20 {constructor() ERC20("USDT test fixture","USDT"){} function decimals() public pure override returns(uint8){return 6;} function mint(address a,uint256 n) external {_mint(a,n);}}

contract TickpayTest is Test {
    address client=address(0xC1);address freelancer=address(0xF1);address other=address(0x0E);
    Tickpay s;StreamUSD usd;
    function setUp() public {s=new Tickpay();usd=new StreamUSD();vm.deal(client,100 ether);usd.mint(client,1000e6);}
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
    function test_batchPayrollInBot() public {
        address[] memory to=new address[](3);to[0]=freelancer;to[1]=address(0xF2);to[2]=address(0xF3);
        uint256[] memory amt=new uint256[](3);amt[0]=1 ether;amt[1]=2 ether;amt[2]=3 ether;
        vm.prank(client);uint256 first=s.createBatch{value:6 ether}(to,amt,address(0),0,600,"October payroll");
        assertEq(first,0);assertEq(s.streamCount(),3);assertEq(address(s).balance,6 ether);
        assertEq(s.getStream(2).recipient,address(0xF3));assertEq(s.getStream(2).deposit,3 ether);assertEq(s.getStream(1).memo,"October payroll");
        assertEq(s.streamsOf(client).length,3);assertEq(s.streamsOf(address(0xF2))[0],1);
        vm.warp(block.timestamp+300);vm.prank(address(0xF2));s.withdraw(1);assertEq(address(0xF2).balance,1 ether);
        vm.prank(client);s.cancel(2);assertEq(address(0xF3).balance,1.5 ether);
    }
    function test_batchPayrollInUsdt() public {
        address[] memory to=new address[](2);to[0]=freelancer;to[1]=other;
        uint256[] memory amt=new uint256[](2);amt[0]=300e6;amt[1]=200e6;
        vm.startPrank(client);usd.approve(address(s),500e6);
        uint64 start=uint64(block.timestamp+1 days);s.createBatch(to,amt,address(usd),start,1000,"");vm.stopPrank();
        assertEq(usd.balanceOf(address(s)),500e6);assertEq(s.earned(0),0);
        vm.warp(start+500);assertEq(s.withdrawable(0),150e6);assertEq(s.withdrawable(1),100e6);
    }
    function test_batchRejectsBadInput() public {
        address[] memory to=new address[](2);to[0]=freelancer;to[1]=address(0);
        uint256[] memory amt=new uint256[](2);amt[0]=1 ether;amt[1]=1 ether;
        vm.startPrank(client);
        vm.expectRevert(bytes("bad stream"));s.createBatch{value:2 ether}(to,amt,address(0),0,100,"");
        to[1]=other;
        vm.expectRevert(bytes("send exact BOT"));s.createBatch{value:1 ether}(to,amt,address(0),0,100,"");
        uint256[] memory short=new uint256[](1);short[0]=1 ether;
        vm.expectRevert(bytes("1-50 recipients"));s.createBatch{value:1 ether}(to,short,address(0),0,100,"");
        address[] memory many=new address[](51);uint256[] memory manyAmt=new uint256[](51);
        vm.expectRevert(bytes("1-50 recipients"));s.createBatch(many,manyAmt,address(0),0,100,"");
        vm.stopPrank();assertEq(s.streamCount(),0);
    }
}
