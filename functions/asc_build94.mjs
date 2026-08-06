import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';
const KEY_ID='4Y98QV45J3', ISSUER='a052dbae-b7ee-4e05-a3f1-4d618d17fcf4', APP='6761478534';
const chave=readFileSync('/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_4Y98QV45J3.p8','utf8');
const b64=(o)=>Buffer.from(JSON.stringify(o)).toString('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const t=Math.floor(Date.now()/1000);
const base=b64({alg:'ES256',kid:KEY_ID,typ:'JWT'})+'.'+b64({iss:ISSUER,iat:t,exp:t+900,aud:'appstoreconnect-v1'});
const sig=createSign('SHA256').update(base).sign({key:chave,dsaEncoding:'ieee-p1363'}).toString('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const JWT=base+'.'+sig;
const api=async(p)=>{const r=await fetch('https://api.appstoreconnect.apple.com'+p,{headers:{Authorization:'Bearer '+JWT}});const x=await r.text();return r.ok?JSON.parse(x):{erro:r.status,corpo:x.slice(0,200)};};
const b=await api('/v1/builds?filter[app]='+APP+'&limit=5&sort=-version');
for (const x of (b.data||[])) {
  const a=x.attributes;
  console.log('build', a.version, '| processamento=', a.processingState, '| expirado=', a.expired, '| uploaded=', a.uploadedDate);
}
