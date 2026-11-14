import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,rmSync,existsSync,copyFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {proposeCaskUpdate,updateLatest,compareVersions} from './homebrew-update.mjs';
import {renderCask,caskForDistribution} from './homebrew.mjs';
const repository='mamachanko/pink';
const sha=text=>createHash('sha256').update(text).digest('hex');
const template=readFileSync('Casks/pink.rb','utf8');
function distribution(version='1.2.3') {
 const directory=mkdtempSync(join(tmpdir(),'pink-pr-test-'));
 const info={version,signingMode:'adhoc',notarization:'none',commit:'f'.repeat(40)};
 writeFileSync(join(directory,'build-info.json'),JSON.stringify(info));
 writeFileSync(join(directory,`Pink-${version}-adhoc.dmg`),'final dmg');
 writeFileSync(join(directory,`Pink-${version}-adhoc.zip`),'final zip');
 const names=['build-info.json',`Pink-${version}-adhoc.dmg`,`Pink-${version}-adhoc.zip`];
 writeFileSync(join(directory,'SHA256SUMS'),names.map(n=>`${sha(readFileSync(join(directory,n)))}  ${n}`).join('\n')+'\n');
 return {directory,info,remove:()=>rmSync(directory,{recursive:true,force:true})};
}
function remote(options={}) {
 const current=options.current??template;
 const state={writes:[],dispatches:[],closed:[],temporary:[],mainReads:0,branch:options.branch??false,oldFile:options.oldFile??renderCask({version:'1.1.0',sha256:'b'.repeat(64),signingMode:'adhoc'}),pr:options.pr??null,behind:options.behind??1};
 const body='<!-- pink-homebrew:start -->\nprevious update\n<!-- pink-homebrew:end -->\nMaintainer note: preserve this.';
 if(state.pr===true)state.pr={number:21,title:'chore(homebrew): update Pink to 1.1.0',body};
 const main='a'.repeat(40),old='c'.repeat(40),fresh='d'.repeat(40);
 const runGh=args=>{
  if(args[0]==='workflow'){state.dispatches.push(args);if(options.dispatchFailure)throw new Error('Actions denied');return '';}
  if(args[0]==='pr') {
   if(args[1]==='close'){state.closed.push(args[2]);return '';}
   return JSON.stringify(args.includes('--head')?(state.pr?[state.pr]:[]):options.legacy??[]);
  }
  const write=args.includes('--input');const path=args[write?3:1].replace(`repos/${repository}/`,'');
  if(write) {
   const file=args[args.indexOf('--input')+1],data=JSON.parse(readFileSync(file));state.temporary.push(dirname(file));state.writes.push({method:args[2],path,data});
   if(options.failWrite)throw new Error('API denied');
   if(path==='git/trees'){state.tree=data;return '{"sha":"tree-new"}';}
   if(path==='git/commits'){state.commit=data;return JSON.stringify({sha:fresh});}
   if(path.startsWith('git/refs')){state.branch=true;state.oldFile=state.tree.tree[0].content;state.behind=0;return '{}';}
   if(path==='pulls'){state.pr={...data,number:21};return '{"number":21}';}
   if(path.startsWith('pulls/')){Object.assign(state.pr,data);return '{}';}
   throw new Error(`Unhandled write ${path}`);
  }
  if(path==='git/ref/heads/main'){state.mainReads++;return JSON.stringify({object:{sha:options.race&&state.mainReads===2?'e'.repeat(40):main}});}
  if(path===`git/commits/${main}`)return '{"tree":{"sha":"main-tree"}}';
  if(path===`git/commits/${old}`)return JSON.stringify({message:options.manual?'manual edits':`generated\nPink-Generated-Cask-SHA256: ${sha(state.oldFile)}\n`});
  if(path===`contents/Casks/pink.rb?ref=${main}`)return JSON.stringify({content:Buffer.from(current).toString('base64')});
  if(path.startsWith('contents/'))return JSON.stringify({content:Buffer.from(state.oldFile).toString('base64')});
  if(path.startsWith('git/matching-refs/'))return JSON.stringify(state.branch?[{ref:'refs/heads/homebrew/update',object:{sha:old}}]:[]);
  if(path.startsWith('compare/'))return JSON.stringify({ahead_by:1,behind_by:state.behind,files:options.unrelated?[{filename:'App/PinkApp.swift'}]:[{filename:'Casks/pink.rb'}]});
  if(path.startsWith('actions/'))return JSON.stringify({workflow_runs:options.runs??[]});
  if(path.startsWith('pulls/'))return JSON.stringify(options.legacyFiles??[{filename:'Casks/pink.rb',patch:'@@\n-  version "1.0.3"\n-  sha256 "'+ 'a'.repeat(64)+'"\n+  version "1.1.0"\n+  sha256 "'+'b'.repeat(64)+'"'}]);
  throw new Error(`Unhandled read ${path}`);
 };
 return {state,runGh};
}

test('one cask PR is based on current main, changes only generated metadata, and dispatches CI',()=>{
 const f=distribution(),r=remote({current:template+'\n# Maintainer addition\n'});
 try {
  const result=proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh});
  assert.equal(result.branch,'homebrew/update');assert.equal(result.number,21);assert.equal(result.created,true);
  assert.equal(r.state.tree.base_tree,'main-tree');assert.deepEqual(r.state.tree.tree.map(f=>f.path),['Casks/pink.rb']);
  assert.ok(r.state.tree.tree[0].content.endsWith('# Maintainer addition\n'));
  assert.deepEqual(r.state.commit.parents,['a'.repeat(40)]);
  assert.equal(r.state.writes.filter(w=>w.path==='git/refs')[0].data.ref,'refs/heads/homebrew/update');
  assert.ok(r.state.dispatches[0].includes('pull_request=21'));assert.ok(r.state.dispatches[0].includes('homebrew/update'));
  assert.ok(r.state.temporary.every(p=>!existsSync(p)));
 }finally{f.remove();}
});
test('refresh preserves branch ancestry without force pushing, PR identity and maintainer notes',()=>{
 const f=distribution(),r=remote({branch:true,pr:true});
 try {
  const result=proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh});
  assert.equal(result.created,false);assert.deepEqual(r.state.commit.parents,['a'.repeat(40),'c'.repeat(40)]);
  const update=r.state.writes.find(w=>w.path==='git/refs/heads/homebrew/update');assert.equal(update.method,'PATCH');assert.equal(update.data.force,false);
  assert.equal(r.state.pr.number,21);assert.ok(r.state.pr.body.endsWith('Maintainer note: preserve this.'));
  assert.equal(r.state.pr.title,'chore(homebrew): update Pink to 1.2.3');
 }finally{f.remove();}
});
test('same-head retries reuse successful or queued dispatches instead of repeating CI',()=>{
 const f=distribution();
 try {
  for(const runs of [[{status:'completed',conclusion:'success'}],[{status:'queued'}],[{status:'in_progress'}]]) {
   const r=remote({branch:true,pr:true,behind:0,oldFile:caskForDistribution(f.directory),runs});
   proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh});
   assert.equal(r.state.dispatches.length,0);assert.equal(r.state.writes.filter(w=>w.path.startsWith('git/')).length,0);
  }
 }finally{f.remove();}
});
test('newer reviewed versions and already-current metadata cause no writes or dispatches',()=>{
 const f=distribution();
 try {
  for(const current of [renderCask({version:'2.0.0',sha256:'a'.repeat(64),signingMode:'adhoc'}),caskForDistribution(f.directory)]) {
   const r=remote({current});const result=proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh});
   assert.equal(result.created,false);assert.equal(r.state.writes.length,0);assert.equal(r.state.dispatches.length,0);
  }
  assert.equal(compareVersions('2.10.0','2.9.0'),1);
 }finally{f.remove();}
});
test('manual and unrelated branch edits fail closed before any mutation',()=>{
 const f=distribution();
 try {
  for(const options of [{branch:true,manual:true},{branch:true,unrelated:true},{branch:true,pr:{number:21,title:'My manual title',body:'Notes'}}]) {
   const r=remote(options);assert.throws(()=>proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh}),/manual|unrelated/);
   assert.equal(r.state.writes.length,0);assert.equal(r.state.dispatches.length,0);
  }
 }finally{f.remove();}
});
test('API failures clean temporary inputs and dispatch failures cannot claim success',()=>{
 const f=distribution();
 try {
  for(const options of [{failWrite:true},{dispatchFailure:true}]) {
   const r=remote(options);assert.throws(()=>proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh}),/denied/);
   assert.ok(r.state.temporary.every(p=>!existsSync(p)));
  }
 }finally{f.remove();}
});
test('main advancing before a write retries a fresh snapshot instead of writing stale metadata',()=>{
 const f=distribution(),r=remote({race:true});
 try {proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh});assert.ok(r.state.mainReads>=4);assert.equal(r.state.writes.filter(w=>w.path==='pulls').length,1);}finally{f.remove();}
});
test('only bot-authored metadata-only legacy PRs are retired after the replacement is dispatched',()=>{
 const f=distribution();
 const legacy=[{number:7,headRefName:'homebrew/v1.1.0',title:'chore(homebrew): update Pink to 1.1.0',author:{is_bot:true,login:'app/github-actions'}}];
 try {
  const r=remote({legacy:[...legacy,{...legacy[0],number:8,author:{is_bot:false,login:'maintainer'}},{...legacy[0],number:9,headRefName:'homebrew/v9.0.0',title:'chore(homebrew): update Pink to 9.0.0'}]});
  proposeCaskUpdate({directory:f.directory,repository,runGh:r.runGh});assert.deepEqual(r.state.closed,['7']);
  const manual=remote({legacy,legacyFiles:[{filename:'Casks/pink.rb',patch:'+system "arbitrary command"'}]});
  proposeCaskUpdate({directory:f.directory,repository,runGh:manual.runGh});assert.deepEqual(manual.state.closed,[]);
 }finally{f.remove();}
});
test('latest-release maintenance verifies actual asset bytes and tag identity before proposing a PR',()=>{
 const f=distribution(),r=remote();let downloadDirectory;
 const runGh=args=>{
  if(args[0]==='release'&&args[1]==='view')return JSON.stringify({tagName:'v1.2.3',assets:['build-info.json','SHA256SUMS','Pink-1.2.3-adhoc.zip','Pink-1.2.3-adhoc.dmg'].map(name=>({name}))});
  if(args[0]==='release') {
   downloadDirectory=args[args.indexOf('--dir')+1];
   args.forEach((arg,i)=>{if(arg==='--pattern')copyFileSync(join(f.directory,args[i+1]),join(downloadDirectory,args[i+1]));});return '';
  }
  if(args[1]?.includes('git/ref/tags/'))return JSON.stringify({object:{type:'commit',sha:f.info.commit}});
  return r.runGh(args);
 };
 try {
  assert.equal(updateLatest({repository,runGh}).number,21);assert.equal(existsSync(downloadDirectory),false);
  writeFileSync(join(f.directory,'Pink-1.2.3-adhoc.dmg'),'tampered');
  assert.throws(()=>updateLatest({repository,runGh}),/Checksum mismatch/);assert.equal(existsSync(downloadDirectory),false);
 }finally{f.remove();}
});
