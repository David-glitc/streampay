// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Per-second payment streams in BOT or any ERC-20. Either side can cancel; earned funds go to the recipient, the rest back to the sender. No fee.
contract Streampay is ReentrancyGuard {
    using SafeERC20 for IERC20;
    struct Stream {address sender; address recipient; address token; uint256 deposit; uint256 withdrawn; uint64 start; uint64 stop; bool cancelled; uint256 settled; string memo;}
    Stream[] private streams;
    mapping(address=>uint256[]) private byAccount;
    event StreamCreated(uint256 indexed id,address indexed sender,address indexed recipient,address token,uint256 deposit,uint64 start,uint64 stop);
    event Withdrawn(uint256 indexed id,address indexed recipient,uint256 amount);
    event Cancelled(uint256 indexed id,uint256 toRecipient,uint256 toSender);

    /// @param token address(0) for native BOT (send amount as value)
    /// @param start unix time the stream starts, or 0 to start now
    function create(address recipient,address token,uint256 amount,uint64 start,uint64 durationSeconds,string calldata memo) external payable nonReentrant returns(uint256 id) {
        require(recipient!=address(0)&&recipient!=msg.sender&&amount>0,"bad stream");
        if(start==0)start=uint64(block.timestamp);
        require(start>=block.timestamp&&start<=block.timestamp+365 days&&durationSeconds>0&&durationSeconds<=5*365 days,"bad schedule");
        uint64 stop=start+durationSeconds;
        require(bytes(memo).length<=80,"memo too long");
        if(token==address(0))require(msg.value==amount,"send exact BOT");
        else {
            require(msg.value==0,"no BOT with tokens");
            uint256 before=IERC20(token).balanceOf(address(this)); IERC20(token).safeTransferFrom(msg.sender,address(this),amount);
            amount=IERC20(token).balanceOf(address(this))-before;
        }
        id=streams.length; streams.push(Stream(msg.sender,recipient,token,amount,0,start,stop,false,0,memo));
        byAccount[msg.sender].push(id); byAccount[recipient].push(id);
        emit StreamCreated(id,msg.sender,recipient,token,amount,start,stop);
    }
    /// @notice Total earned by the recipient so far (fixed once cancelled).
    function earned(uint256 id) public view returns(uint256){
        Stream storage s=streams[id];
        if(s.cancelled)return s.settled;
        if(block.timestamp<=s.start)return 0;
        if(block.timestamp>=s.stop)return s.deposit;
        return s.deposit*(block.timestamp-s.start)/(s.stop-s.start);
    }
    function withdrawable(uint256 id) public view returns(uint256){return earned(id)-streams[id].withdrawn;}
    function withdraw(uint256 id) external nonReentrant {
        Stream storage s=streams[id]; require(msg.sender==s.recipient,"not recipient");
        uint256 amount=withdrawable(id); require(amount>0,"nothing earned"); s.withdrawn+=amount;
        _send(s.token,s.recipient,amount); emit Withdrawn(id,s.recipient,amount);
    }
    function cancel(uint256 id) external nonReentrant {
        Stream storage s=streams[id]; require(msg.sender==s.sender||msg.sender==s.recipient,"not a party");
        require(!s.cancelled&&block.timestamp<s.stop,"finished");
        uint256 e=earned(id); s.cancelled=true; s.settled=e;
        uint256 toRecipient=e-s.withdrawn; uint256 toSender=s.deposit-e; s.withdrawn=e;
        if(toRecipient>0)_send(s.token,s.recipient,toRecipient);
        if(toSender>0)_send(s.token,s.sender,toSender);
        emit Cancelled(id,toRecipient,toSender);
    }
    function _send(address token,address to,uint256 amount) private {
        if(token==address(0)){(bool ok,)=to.call{value:amount}("");require(ok,"transfer failed");}
        else IERC20(token).safeTransfer(to,amount);
    }
    function streamCount() external view returns(uint256){return streams.length;}
    function getStream(uint256 id) external view returns(Stream memory){return streams[id];}
    function streamsOf(address account) external view returns(uint256[] memory){return byAccount[account];}
}
