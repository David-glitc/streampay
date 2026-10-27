// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Per-second payment streams in BOT or any ERC-20, one at a time or as a batch payroll. Either side can cancel; earned funds go to the recipient, the rest back to the sender. No fee.
contract Tickpay is ReentrancyGuard {
    using SafeERC20 for IERC20;
    struct Stream {address sender; address recipient; address token; uint256 deposit; uint256 withdrawn; uint64 start; uint64 stop; bool cancelled; uint256 settled; string memo;}
    uint256 public constant MAX_BATCH = 50;
    Stream[] private streams;
    mapping(address=>uint256[]) private byAccount;
    event StreamCreated(uint256 indexed id,address indexed sender,address indexed recipient,address token,uint256 deposit,uint64 start,uint64 stop);
    event PayrollCreated(uint256 indexed firstId,address indexed sender,address token,uint256 count,uint256 total);
    event Withdrawn(uint256 indexed id,address indexed recipient,uint256 amount);
    event Cancelled(uint256 indexed id,uint256 toRecipient,uint256 toSender);

    /// @param token address(0) for native BOT (send amount as value)
    /// @param start unix time the stream starts, or 0 to start now
    function create(address recipient,address token,uint256 amount,uint64 start,uint64 durationSeconds,string calldata memo) external payable nonReentrant returns(uint256 id) {
        (start,durationSeconds)=_schedule(start,durationSeconds,memo);
        amount=_collect(token,amount);
        id=_open(recipient,token,amount,start,start+durationSeconds,memo);
    }
    /// @notice Payroll: one stream per recipient, all sharing the token, schedule and memo, funded in one transaction.
    /// @param token address(0) for native BOT (send the sum of amounts as value)
    /// @return firstId id of the first stream; the rest follow in order
    function createBatch(address[] calldata recipients,uint256[] calldata amounts,address token,uint64 start,uint64 durationSeconds,string calldata memo) external payable nonReentrant returns(uint256 firstId) {
        uint256 n=recipients.length; require(n>0&&n<=MAX_BATCH&&n==amounts.length,"1-50 recipients");
        (start,durationSeconds)=_schedule(start,durationSeconds,memo);
        uint256 total;
        for(uint256 i;i<n;i++)total+=amounts[i];
        require(_collect(token,total)==total,"token took a fee");
        firstId=streams.length; uint64 stop=start+durationSeconds;
        for(uint256 i;i<n;i++)_open(recipients[i],token,amounts[i],start,stop,memo);
        emit PayrollCreated(firstId,msg.sender,token,n,total);
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
    function _schedule(uint64 start,uint64 durationSeconds,string calldata memo) private view returns(uint64,uint64){
        if(start==0)start=uint64(block.timestamp);
        require(start>=block.timestamp&&start<=block.timestamp+365 days&&durationSeconds>0&&durationSeconds<=5*365 days,"bad schedule");
        require(bytes(memo).length<=80,"memo too long");
        return (start,durationSeconds);
    }
    /// @return received amount actually held (fee-on-transfer tokens deliver less)
    function _collect(address token,uint256 amount) private returns(uint256 received){
        if(token==address(0)){require(msg.value==amount,"send exact BOT");return amount;}
        require(msg.value==0,"no BOT with tokens");
        uint256 before=IERC20(token).balanceOf(address(this)); IERC20(token).safeTransferFrom(msg.sender,address(this),amount);
        received=IERC20(token).balanceOf(address(this))-before;
    }
    function _open(address recipient,address token,uint256 amount,uint64 start,uint64 stop,string calldata memo) private returns(uint256 id){
        require(recipient!=address(0)&&recipient!=msg.sender&&amount>0,"bad stream");
        id=streams.length; streams.push(Stream(msg.sender,recipient,token,amount,0,start,stop,false,0,memo));
        byAccount[msg.sender].push(id); byAccount[recipient].push(id);
        emit StreamCreated(id,msg.sender,recipient,token,amount,start,stop);
    }
    function _send(address token,address to,uint256 amount) private {
        if(token==address(0)){(bool ok,)=to.call{value:amount}("");require(ok,"transfer failed");}
        else IERC20(token).safeTransfer(to,amount);
    }
    function streamCount() external view returns(uint256){return streams.length;}
    function getStream(uint256 id) external view returns(Stream memory){return streams[id];}
    function streamsOf(address account) external view returns(uint256[] memory){return byAccount[account];}
}
