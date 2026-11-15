import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,createHash} from 'node:crypto';
import {mkdtempSync,writeFileSync,readFileSync,readdirSync,rmSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {updateConfiguration,prepareAppcast} from './updates.mjs';
import {prepare} from './prepare.mjs';
import {validate,expectedAssets} from './check-assets.mjs';
const keys=()=>{
 const pair=generateKeyPairSync('ed25519');
 return {PINK_UPDATE_MODE:'sparkle',PINK_UPDATE_PUBLIC_KEY:pair.publicKey.export({format:'der',type:'spki'}).subarray(-32).toString('base64'),PINK_UPDATE_PRIVATE_KEY:pair.privateKey.export({format:'der',type:'pkcs8'}).subarray(-32).toString('base64')};
};
function fixture(env={}) {
 const directory=mkdtempSync(join(tmpdir(),'pink-update-test-'));
 const info={version:'1.2.3',build:'1.2.3',signingMode:'adhoc',updates:updateConfiguration(env)};
 writeFileSync(join(directory,'build-info.json'),JSON.stringify(info));
 writeFileSync(join(directory,'Pink-1.2.3-adhoc.zip'),'zip');
 writeFileSync(join(directory,'Pink-1.2.3-adhoc.dmg'),'dmg');
 return {directory,info,clean:()=>rmSync(directory,{recursive:true,force:true})};
}
test('update credentials fail closed, match the embedded key, and never appear in the manifest',()=>{
 const env=keys();assert.deepEqual(updateConfiguration({}),{mode:'manual'});
 assert.deepEqual(updateConfiguration(env),{mode:'sparkle',publicKey:env.PINK_UPDATE_PUBLIC_KEY});
 for(const invalid of [{PINK_UPDATE_MODE:'invalid'},{PINK_UPDATE_MODE:'sparkle'},{...env,PINK_UPDATE_MODE:'manual'},{...env,PINK_UPDATE_PRIVATE_KEY:'bad'}, {...env,PINK_UPDATE_PUBLIC_KEY:keys().PINK_UPDATE_PUBLIC_KEY},{...env,PINK_UPDATE_PRIVATE_KEY:''}]) {
  assert.throws(()=>updateConfiguration(invalid));assert.throws(()=>prepare('1.2.3',invalid));
 }
 assert.ok(!JSON.stringify(updateConfiguration(env)).includes(env.PINK_UPDATE_PRIVATE_KEY));
});
test('manual builds publish an informational feed without unsigned installable archives',()=>{
 const f=fixture();try{
  prepareAppcast({directory:f.directory,env:{},runTool:()=>{throw new Error('must not call signing tools');}});
  const xml=readFileSync(join(f.directory,'appcast.xml'),'utf8');
  assert.ok(xml.includes('<sparkle:informationalUpdate/>'));assert.ok(xml.includes('releases/tag/v1.2.3'));
  assert.ok(!xml.includes('<enclosure'));assert.ok(!xml.includes('edSignature'));
 }finally{f.clean();}
});
test('secure preparation uses pinned Sparkle tools, stdin keys, correct final ZIP, and cleans work after success/failure',()=>{
 for(const fail of [false,true]) {
  const env=keys(),f=fixture(env),calls=[];let work;
  try{
   const runTool=(name,args,secret)=>{
    calls.push({name,args});assert.equal(secret,env.PINK_UPDATE_PRIVATE_KEY);assert.ok(!args.includes(secret));
    if(name==='generate_appcast') {
     work=args.at(-1);assert.equal(readFileSync(join(work,'Pink-1.2.3-adhoc.zip'),'utf8'),'zip');
     if(fail)throw new Error('Preparation failed');
     writeFileSync(join(work,'appcast.xml'),'<rss sparkle:edSignature="'+Buffer.alloc(64).toString('base64')+'"/>');
    }
    return '';
   };
   if(fail)assert.throws(()=>prepareAppcast({directory:f.directory,env,runTool}),/Preparation failed/);
   else {prepareAppcast({directory:f.directory,env,runTool});assert.equal(calls.length,3);assert.ok(calls[0].args.includes('--maximum-deltas'));assert.ok(calls[2].args.includes(join(f.directory,'appcast.xml')));}
   assert.equal(existsSync(work),false);
   assert.ok(!readdirSync(f.directory).some(n=>n.includes('key')));
  }finally{f.clean();}
 }
});
test('new release allowlist includes the feed and its final checksum while historical releases remain verifiable',()=>{
 const f=fixture();try{
  prepareAppcast({directory:f.directory,env:{}});
  const names=expectedAssets(f.info).filter(n=>n!=='SHA256SUMS');
  const sums=()=>names.map(n=>`${createHash('sha256').update(readFileSync(join(f.directory,n))).digest('hex')}  ${n}`).join('\n')+'\n';
  writeFileSync(join(f.directory,'SHA256SUMS'),sums());validate(f.directory);
  assert.equal(expectedAssets({version:'1.1.1',signingMode:'adhoc'}).length,4);
  writeFileSync(join(f.directory,'appcast.xml'),'tampered');assert.throws(()=>validate(f.directory),/Checksum mismatch/);
  writeFileSync(join(f.directory,'SHA256SUMS'),sums());validate(f.directory);
  writeFileSync(join(f.directory,'private-key'),'never ship');assert.throws(()=>validate(f.directory),/asset set/);
 }finally{f.clean();}
});
