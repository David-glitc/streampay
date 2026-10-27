import {parseEther} from 'viem';
export default {
 slug:'tickpay',vercel:'tickpaybot',assets:['BOT','USDT'],name:'Tickpay',repo:'tickpay',contract:'Tickpay',color:'#3EE0F5',eyebrow:'PAYROLL BY THE SECOND',symbol:'≈',
 line:'Every second, paid.',
 app:{title:'Streams',line:'Pay one person or your whole team: deposit once, everyone earns every second and withdraws any time.',layout:'board'},
 description:'Payroll by the second in USDT or BOT. Stream to one wallet or up to 50 in one transaction; either side can cancel fairly.',
 abis:['Tickpay'],
 contracts:['src/Tickpay.sol'],tests:['test/Tickpay.t.sol'],
 landing:{
  steps:[['Start a stream or a payroll','Pick one recipient, or paste up to 50 wallets with amounts, choose USDT or BOT and a duration, then deposit once.'],['Earn every second','The recipient\'s balance grows each second and can be withdrawn any time.'],['Cancel fairly','Either side can stop the stream. Earned funds go to the recipient; the rest returns to the sender.']],
  features:[['Batch payroll','Pay a whole team in one transaction: up to 50 streams sharing one token and schedule.'],['USDT or BOT','Stream stable USDT salaries or native BOT on BOT Chain.'],['Fair cancellation','Settlement is exact to the second, in the same transaction.'],['Scheduled starts','Fund next month\'s payroll today; nothing accrues before the start time.']],
  faq:[['How does batch payroll work?','Paste up to 50 wallets with an amount each. One deposit opens one stream per person, all with the same token, start and duration.'],['Can the sender take back earned funds?','No. Cancelling pays everything earned so far to the recipient.'],['Can a stream start later?','Yes. Set a start time up to a year ahead; nothing accrues before it.'],['Who can withdraw?','Only the recipient, at any time, for whatever has accrued.'],['What does it cost?','Tickpay takes no fee. You only pay BOT Chain gas.']],
 },
 async deploy({deploy}){await deploy('Tickpay');},
 async fork({write,read,parseEther:pe=parseEther}){
  const other='0x000000000000000000000000000000000000dEaD';
  const ZERO='0x0000000000000000000000000000000000000000';
  await write('Tickpay','create',[other,ZERO,pe('0.001'),0n,3600n,'Fork stream'],pe('0.001'));
  const id=await read('Tickpay','streamCount')-1n;await write('Tickpay','cancel',[id]);
  await write('Tickpay','createBatch',[[other,'0x000000000000000000000000000000000000bEEF'],[pe('0.001'),pe('0.002')],ZERO,0n,3600n,'Fork payroll'],pe('0.003'));
  return {flow:'create BOT stream → cancel → batch payroll of 2',settled:String((await read('Tickpay','getStream',[id])).settled),streams:String(await read('Tickpay','streamCount'))};
 },
};
