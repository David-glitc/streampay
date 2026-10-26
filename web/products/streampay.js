import {$,config,state,esc,fmt,link,button,field,form,address,amount,read,tx,approve,mine,chainTime,asset,start} from '../core.js';
const trim=(v,d=4)=>{const [a,b='']=v.split('.');return b?`${a}.${b.slice(0,d).replace(/0+$/,'')||'0'}`.replace(/\.0$/,''):a;};
const USDT=config.infrastructure.USDT,ZERO='0x0000000000000000000000000000000000000000';
const tally={live:0,bot:0n,usdt:0n};let ticking=[],timer=null;
function controls(){
 $('list-title').textContent='Streams';
 $('controls').innerHTML='<h2>Start a stream</h2><p>Deposit once. The recipient earns every second and can withdraw any time.</p>'
  +form('stream',field('to','Recipient wallet','','text','placeholder="0x…"')
   +'<div class="seg" role="radiogroup" aria-label="Token"><input type="radio" name="token" id="tok-bot" value="BOT" checked><label for="tok-bot">BOT</label><input type="radio" name="token" id="tok-usdt" value="USDT"><label for="tok-usdt">USDT</label></div>'
   +`<div class="two"><div>${field('amt','Total amount','1','text','inputmode="decimal"')}</div><div>${field('days','Duration (days)','30','text','inputmode="decimal"')}</div></div>`
   +field('memo','Memo','','text','maxlength="80" placeholder="October retainer"').replace(' required ',' '),
   'Start stream',async f=>{
    const to=address(f.to.trim()),secs=Math.round(Number(f.days)*86400);if(!(secs>=60))throw Error('Use a duration of at least one minute.');
    if(f.token==='USDT'){const n=amount(f.amt,6);await approve(USDT,config.contracts.Streampay,n);await tx('Streampay','create',[to,USDT,n,0n,BigInt(secs),f.memo||'']);}
    else{const n=amount(f.amt);await tx('Streampay','create',[to,ZERO,n,0n,BigInt(secs),f.memo||''],n);}
   });
 $('rules').innerHTML='<ul><li>Streams start the moment they are created and accrue every second.</li><li>Only the recipient can withdraw, at any time.</li><li>Either side can cancel: everything earned goes to the recipient, the rest returns to the sender.</li><li>No fee.</li></ul>';
}
function row(id,s,now){
 const usd=s.token!==ZERO,dec=usd?6:18,sym=usd?'USDT':'BOT',dur=Number(s.stop-s.start);
 const live=!s.cancelled&&now<Number(s.stop);if(live){tally.live++;if(usd)tally.usdt+=s.deposit;else tally.bot+=s.deposit;}
 const earnedAt=t=>s.cancelled?s.settled:t<=Number(s.start)?0n:t>=Number(s.stop)?s.deposit:s.deposit*BigInt(Math.floor(t-Number(s.start)))/BigInt(dur);
 if(live)ticking.push({id,earnedAt,dec,withdrawn:s.withdrawn,offset:now-Date.now()/1000,deposit:s.deposit});
 const e=earnedAt(now),pct=s.deposit>0n?Number(e*10000n/s.deposit)/100:0;
 const acts=[];
 if(mine(s.recipient)&&e>s.withdrawn)acts.push(button('Withdraw',()=>tx('Streampay','withdraw',[BigInt(id)]),true));
 if(live&&(mine(s.sender)||mine(s.recipient)))acts.push(button('Cancel',()=>tx('Streampay','cancel',[BigInt(id)])));
 return `<tr><td><strong>${esc(s.memo)||`Stream #${id}`}</strong><br><span class="tiny">${link(s.sender)} → ${link(s.recipient)}</span></td><td class="num">${trim(fmt(s.deposit,dec))} ${asset(sym)}</td><td class="num"><span id="earned-${id}">${trim(fmt(e,dec),6)}</span><div class="meter" aria-hidden="true"><i id="bar-${id}" style="width:${pct}%"></i></div></td><td><span class="badge${live?' live':''}">${s.cancelled?'Cancelled':live?(now<Number(s.start)?'Scheduled':'Streaming'):'Finished'}</span></td><td class="num">${acts.join(' ')}</td></tr>`;
}
async function render(){
 const count=Number(await read('Streampay','streamCount')),now=await chainTime();Object.assign(tally,{live:0,bot:0n,usdt:0n});ticking=[];
 const ids=new Set();if(state.account)for(const id of await read('Streampay','streamsOf',[state.account]))ids.add(Number(id));
 for(let id=count-1;id>=Math.max(0,count-30);id--)ids.add(id);
 const list=await Promise.all([...ids].sort((a,b)=>b-a).map(async id=>[id,await read('Streampay','getStream',[BigInt(id)])]));
 if(!list.length)return '<p class="empty">No streams yet. Start the first one.</p>';
 return `<div class="table-wrap"><table class="board stack"><thead><tr><th scope="col">Stream</th><th scope="col" class="num">Deposit</th><th scope="col" class="num">Earned</th><th scope="col">Status</th><th scope="col" class="num"><span class="sr-only">Actions</span></th></tr></thead><tbody>${list.map(([id,s])=>row(id,s,now)).join('')}</tbody></table></div>`;
}
// Earned amounts tick up between refreshes using chain time; reduced-motion users get one update per refresh.
function after(){
 clearInterval(timer);if(!ticking.length||matchMedia('(prefers-reduced-motion: reduce)').matches)return;
 timer=setInterval(()=>{for(const t of ticking){const at=Date.now()/1000+t.offset,e=t.earnedAt(at),el=$(`earned-${t.id}`),bar=$(`bar-${t.id}`);if(el)el.textContent=trim(fmt(e,t.dec),6);if(bar)bar.style.width=`${Number(e*10000n/t.deposit)/100}%`;}},1000);
}
function stats(empty){return [['Live streams',empty?'—':String(tally.live)],['BOT streaming',empty?'—':trim(fmt(tally.bot))],['USDT streaming',empty?'—':trim(fmt(tally.usdt,6))]];}
start({controls,render,stats,after});
