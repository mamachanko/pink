import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {Writable} from 'node:stream';
const sink=()=>new Writable({write(c,e,cb){cb();}});
const config=createRequire(import.meta.url)('../release.config.cjs');

if(process.argv[2]==='versions') {

 const {default: semanticRelease} = await import('semantic-release');
 for (const [message, tag, expected] of [['fix: initial',null,'1.0.0'], ['fix: patch','v1.2.3','1.2.4'], ['feat: minor','v1.2.3','1.3.0'], ['ci!: breaking','v1.2.3','2.0.0'], ['docs: none','v1.2.3',null]]) {
  const cwd = mkdtempSync(join(tmpdir(),'refpaste-engine-'));
  try {
   const git=(...a)=>execFileSync('git',a,{cwd,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
   git('init','-b','main');git('config','user.name','Test');git('config','user.email','test@example.invalid');git('commit','--allow-empty','-m','chore: base');
   if(tag) git('tag',tag);
   git('commit','--allow-empty','-m',message);
   const result=await semanticRelease({...config, repositoryUrl:`file://${cwd}`, dryRun:true, ci:false, plugins:config.plugins.slice(0,2)}, {cwd,env:{...process.env,GITHUB_ACTIONS:'',GITHUB_TOKEN:'',GH_TOKEN:''},stdout:sink(),stderr:sink()});
   assert.equal(result ? result.nextRelease.version : null,expected);
  } finally {rmSync(cwd,{recursive:true,force:true});}
 }

} else {

 const {default:semanticRelease}=await import('semantic-release');
 const cwd=mkdtempSync(join(tmpdir(),'refpaste-failure-'));
 try {
  const git=(...a)=>execFileSync('git',a,{cwd,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
  git('init','-b','main');git('config','user.name','Test');git('config','user.email','test@example.invalid');git('commit','--allow-empty','-m','feat: package');
  const publishPlugin=join(cwd,'publish.cjs');
  writeFileSync(publishPlugin,`exports.publish=()=>{require('fs').writeFileSync(${JSON.stringify(join(cwd,'published'))},'unexpected')}`);
  await assert.rejects(semanticRelease({...config,repositoryUrl:`file://${cwd}`,ci:false,dryRun:false,
   plugins:[config.plugins[0],['@semantic-release/exec',{prepareCmd:`node ${JSON.stringify(join(process.cwd(),'scripts/prepare.mjs'))} \${nextRelease.version}`}],publishPlugin]
  },{cwd,env:{...process.env,GITHUB_ACTIONS:'',GITHUB_TOKEN:'',GH_TOKEN:'',SIGNING_MODE:'developer-id',APPLE_ID:''},stdout:sink(),stderr:sink()}));
  assert.equal(git('tag'),'');
  const {existsSync}=await import('node:fs');assert.equal(existsSync(join(cwd,'published')),false);
 } finally {rmSync(cwd,{recursive:true,force:true});}

}
