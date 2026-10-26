import {parseEther} from 'viem';
export default {
 slug:'streampay',vercel:'streampaybot',assets:['BOT','USDT'],name:'Streampay',repo:'streampay',contract:'Streampay',color:'#3EE0F5',eyebrow:'PAY PER SECOND',symbol:'≈',
 line:'Pay by the second.',
 app:{title:'Streams',line:'Deposit once; the recipient earns every second and withdraws any time.',layout:'board'},
 description:'Stream BOT or USDT to anyone by the second. Either side can cancel; earned funds go to the recipient, the rest returns.',
 abis:['Streampay'],
 contracts:['src/Streampay.sol'],tests:['test/Streampay.t.sol'],
 landing:{
  steps:[['Start a stream','Pick a recipient, amount, token and duration, then deposit once.'],['Earn every second','The recipient\'s balance grows each second and can be withdrawn any time.'],['Cancel fairly','Either side can stop the stream. Earned funds go to the recipient; the rest returns to the sender.']],
  features:[['Per-second pay','Salaries, retainers and grants that accrue continuously.'],['BOT and USDT','Stream native BOT or USDT on BOT Chain.'],['Fair cancellation','Settlement is exact to the second, in the same transaction.'],['No fee','Streampay takes nothing; only BOT Chain gas.']],
  faq:[['Can the sender take back earned funds?','No. Cancelling pays everything earned so far to the recipient.'],['Can a stream start later?','Yes. Set a start time up to a year ahead; nothing accrues before it.'],['Who can withdraw?','Only the recipient, at any time, for whatever has accrued.'],['What does it cost?','Only BOT Chain gas.']],
 },
 async deploy({deploy}){await deploy('Streampay');},
 async fork({write,read,parseEther:pe=parseEther}){
  const other='0x000000000000000000000000000000000000dEaD';
  await write('Streampay','create',[other,'0x0000000000000000000000000000000000000000',pe('0.001'),0n,3600n,'Fork stream'],pe('0.001'));
  const id=await read('Streampay','streamCount')-1n;await write('Streampay','cancel',[id]);
  return {flow:'create BOT stream → cancel',settled:String((await read('Streampay','getStream',[id])).settled)};
 },
};
