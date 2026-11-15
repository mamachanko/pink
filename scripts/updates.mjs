import {createPrivateKey,createPublicKey} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {copyFileSync,mkdtempSync,rmSync,readFileSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

export function updateConfiguration(env) {
 const mode=env.PINK_UPDATE_MODE || 'manual';
 const publicKey=env.PINK_UPDATE_PUBLIC_KEY || '';
 const secret=env.PINK_UPDATE_PRIVATE_KEY || '';
 if(!['manual','sparkle'].includes(mode))throw new Error('Invalid update mode');
 if(mode==='manual') {
  if(publicKey||secret)throw new Error('Update keys require explicit sparkle mode');
  return {mode};
 }
 const decode=value=>{
  const data=Buffer.from(value,'base64');
  if(data.length!==32||data.toString('base64')!==value)throw new Error('Expected a canonical base64 32-byte update key');
  return data;
 };
 const seed=decode(secret),pub=decode(publicKey);
 const privateKey=createPrivateKey({key:Buffer.concat([Buffer.from('302e020100300506032b657004220420','hex'),seed]),format:'der',type:'pkcs8'});
 const derived=createPublicKey(privateKey).export({format:'der',type:'spki'}).subarray(-32);
 if(!derived.equals(pub))throw new Error('Update signing key does not match embedded public key');
 return {mode,publicKey};
}

function sparkleTool(name,args,secret) {
 // Never echo upstream errors: some tool validation errors include private input.
 const result=spawnSync(`.tools/sparkle/bin/${name}`,args,{input:secret+'\n',encoding:'utf8',stdio:['pipe','pipe','pipe']});
 if(result.error||result.status!==0)throw new Error(`Sparkle ${name} failed`);
 return result.stdout.trim();
}

export function prepareAppcast({directory='dist',env=process.env,runTool=sparkleTool}={}) {
 const updates=updateConfiguration(env);
 const info=JSON.parse(readFileSync(join(directory,'build-info.json')));
 if(!/^(0|[1-9]\d*)\.\d+\.\d+$/.test(info.version)||!/^\d+(\.\d+\.\d+)?$/.test(info.build)||!['adhoc','developer-id'].includes(info.signingMode))throw new Error('Invalid update release metadata');
 if(info.updates?.mode!==updates.mode||info.updates?.publicKey!==updates.publicKey)throw new Error('Update configuration differs from built application');
 const release=`https://github.com/mamachanko/pink/releases/tag/v${info.version}`;
 const feed=join(directory,'appcast.xml');
 if(updates.mode==='manual') {
  writeFileSync(feed,`<?xml version="1.0" encoding="utf-8"?>\n<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Pink</title><link>https://github.com/mamachanko/pink</link><description>Pink releases</description><item><title>Pink ${info.version}</title><link>${release}</link><sparkle:version>${info.build}</sparkle:version><sparkle:shortVersionString>${info.version}</sparkle:shortVersionString><sparkle:minimumSystemVersion>15.0.0</sparkle:minimumSystemVersion><sparkle:informationalUpdate/></item></channel></rss>\n`);
  return;
 }
 const work=mkdtempSync(join(tmpdir(),'pink-appcast-'));
 try {
  const zip=`Pink-${info.version}-${info.signingMode}.zip`;
  copyFileSync(join(directory,zip),join(work,zip));
  runTool('generate_appcast',['--ed-key-file','-','--maximum-deltas','0','--download-url-prefix',`https://github.com/mamachanko/pink/releases/download/v${info.version}/`,'-o',join(work,'appcast.xml'),work],env.PINK_UPDATE_PRIVATE_KEY);
  copyFileSync(join(work,'appcast.xml'),feed);
  // The standard generator signs the archive and, because SURequireSignedFeed is
  // embedded in the app, the feed. Verify the actual archive with Sparkle too.
  const signature=readFileSync(feed,'utf8').match(/sparkle:edSignature="([A-Za-z0-9+/=]+)"/)?.[1];
  if(!signature)throw new Error('Generated appcast has no archive signature');
  runTool('sign_update',['--ed-key-file','-','--verify',join(directory,zip),signature],env.PINK_UPDATE_PRIVATE_KEY);
  runTool('sign_update',['--ed-key-file','-','--verify',feed],env.PINK_UPDATE_PRIVATE_KEY);
 } finally {rmSync(work,{recursive:true,force:true});}
}
if(process.argv[1]===fileURLToPath(import.meta.url))prepareAppcast();
