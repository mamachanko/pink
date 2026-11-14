import {execFileSync} from 'node:child_process';
import {existsSync,readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {caskForDistribution} from './homebrew.mjs';
import {validate} from './check-assets.mjs';
const execute=args=>execFileSync('gh',args,{encoding:'utf8'}).trim();
const branch='homebrew/update';
const digest=text=>createHash('sha256').update(text).digest('hex');
const versionOf=text=>text.match(/^\s*version "([1-9]\d*\.\d+\.\d+)"/m)?.[1];
export function compareVersions(a,b) {
 const left=a.split('.').map(BigInt),right=b.split('.').map(BigInt);
 for(let i=0;i<3;i++){if(left[i]>right[i])return 1;if(left[i]<right[i])return -1;}return 0;
}
const decode=file=>Buffer.from(file.content,'base64').toString('utf8');
function syncCaskAttempt({directory='dist',repository=process.env.GITHUB_REPOSITORY,runGh=execute}={}) {
 if(!existsSync(`${directory}/build-info.json`))return {created:false};
 if(repository!=='mamachanko/pink')throw new Error('Unexpected tap repository');
 const info=JSON.parse(readFileSync(`${directory}/build-info.json`));
 const temporary=mkdtempSync(join(tmpdir(),'pink-homebrew-'));let sequence=0;
 const gh=(...args)=>runGh(args);
 const api=path=>JSON.parse(gh('api',`repos/${repository}/${path}`));
 const write=(method,path,data)=>{
  const file=join(temporary,`${sequence++}.json`);writeFileSync(file,JSON.stringify(data));
  return JSON.parse(gh('api','--method',method,`repos/${repository}/${path}`,'--input',file)||'{}');
 };
 try {
  const main=api('git/ref/heads/main').object.sha;
  const mainCommit=api(`git/commits/${main}`);
  const current=decode(api(`contents/Casks/pink.rb?ref=${main}`));
  const content=caskForDistribution(directory,current),hash=digest(content);
  const currentVersion=versionOf(current);
  if(!currentVersion)throw new Error('Malformed current Homebrew metadata');
  if(compareVersions(currentVersion,info.version)>0)return {created:false,reason:'newer-cask-already-reviewed'};
  if(current===content)return {created:false,reason:'already-current'};
  const refs=api(`git/matching-refs/heads/${branch}`);
  const old=refs.find(r=>r.ref===`refs/heads/${branch}`)?.object.sha;
  const prs=JSON.parse(gh('pr','list','--repo',repository,'--base','main','--head',branch,'--state','open','--json','number,title,body'));
  if(prs.length>1)throw new Error('Multiple canonical Homebrew PRs');
  const pr=prs[0];
  const oldFile=old?decode(api(`contents/Casks/pink.rb?ref=${old}`)):null;
  if(old) {
   const comparison=api(`compare/${main}...${old}`);
   if(comparison.files.some(f=>f.filename!=='Casks/pink.rb'))throw new Error('Automation branch contains unrelated work');
   if(comparison.ahead_by>0) {
    const oldCommit=api(`git/commits/${old}`);
    if(!oldCommit.message.trimEnd().endsWith(`Pink-Generated-Cask-SHA256: ${digest(oldFile)}`))throw new Error('Automation branch changed manually; review required');
   }
  }
  if(oldFile&&(!versionOf(oldFile)||compareVersions(versionOf(oldFile),info.version)>0))return {created:false,reason:'newer-cask-already-proposed'};
  if(pr&&(!/^chore\(homebrew\): update Pink to [1-9]\d*\.\d+\.\d+$/.test(pr.title)||!pr.body.includes('<!-- pink-homebrew:start -->')||!pr.body.includes('<!-- pink-homebrew:end -->')))throw new Error('Automation PR changed manually; review required');
  // A main push may race this run. Leave the branch untouched and let the next
  // serialized maintenance run use a fresh snapshot, rather than publishing stale metadata.
  if(api('git/ref/heads/main').object.sha!==main)throw new Error('Main advanced; rerun maintenance');
  let head=old;
  const synchronized=old&&oldFile===content&&api(`compare/${main}...${old}`).behind_by===0;
  if(!synchronized) {
   const tree=write('POST','git/trees',{base_tree:mainCommit.tree.sha,tree:[{path:'Casks/pink.rb',mode:'100644',type:'blob',content}]});
   const commit=write('POST','git/commits',{message:`chore(homebrew): update Pink to ${info.version}\n\nPink-Generated-Cask-SHA256: ${hash}`,tree:tree.sha,parents:[...new Set([main,...(old?[old]:[])])]});
   head=commit.sha;
   if(old)write('PATCH',`git/refs/heads/${branch}`,{sha:head,force:false});
   else write('POST','git/refs',{ref:`refs/heads/${branch}`,sha:head});
  }
  const generated=`<!-- pink-homebrew:start -->\nUpdates Pink to ${info.version} from the verified published release. The final DMG SHA-256 is pinned. CI starts automatically; merge after the required checks pass.\n<!-- pink-homebrew:end -->`;
  const body=pr?pr.body.replace(/<!-- pink-homebrew:start -->[\s\S]*?<!-- pink-homebrew:end -->/,generated):generated;
  const title=`chore(homebrew): update Pink to ${info.version}`;
  const number=pr?.number??write('POST','pulls',{head:branch,base:'main',title,body}).number;
  if(pr&&(pr.title!==title||pr.body!==body))write('PATCH',`pulls/${number}`,{title,body});
  if(!number)throw new Error('Missing Homebrew PR identity');
  // workflow_dispatch is explicitly exempt from GITHUB_TOKEN event suppression
  // and token-created PR approval requirements. The dispatched CI has read-only permissions.
  const runs=api(`actions/workflows/ci.yml/runs?head_sha=${head}&event=workflow_dispatch&per_page=100`).workflow_runs;
  if(!runs.some(r=>['queued','in_progress','waiting','pending','requested'].includes(r.status)||r.conclusion==='success')) {
   gh('workflow','run','ci.yml','--repo',repository,'--ref',branch,'-f',`pull_request=${number}`);
  }
  // Retire only recognizable, bot-authored, metadata-only version PRs. Never close
  // arbitrary human PRs or delete branches/tags. This also migrates the former flow.
  const legacy=JSON.parse(gh('pr','list','--repo',repository,'--base','main','--state','open','--limit','1000','--json','number,headRefName,title,author'));
  for(const candidate of legacy) {
   const version=candidate.headRefName.match(/^homebrew\/v([1-9]\d*\.\d+\.\d+)$/)?.[1];
   if(!version||compareVersions(version,info.version)>0||!candidate.author?.is_bot||!['app/github-actions','github-actions[bot]'].includes(candidate.author.login)||candidate.title!==`chore(homebrew): update Pink to ${version}`)continue;
   const files=api(`pulls/${candidate.number}/files?per_page=100`);
   const edits=(files[0]?.patch??'').split('\n').filter(line=>/^[+-]/.test(line)&&!/^([+]{3}|[-]{3})/.test(line));
   if(files.length===1&&files[0].filename==='Casks/pink.rb'&&edits.length===4&&edits.every(line=>/^[+-]  (version "[1-9]\d*\.\d+\.\d+"|sha256 "[a-f0-9]{64}")$/.test(line)))gh('pr','close',String(candidate.number),'--repo',repository);
  }
  return {created:!pr,branch,number,head};
 } finally {rmSync(temporary,{recursive:true,force:true});}
}
export function proposeCaskUpdate(options={}) {
 for(let attempt=0;attempt<3;attempt++) {
  try {return syncCaskAttempt(options);} catch(error) {
   if(error.message!=='Main advanced; rerun maintenance'||attempt===2)throw error;
  }
 }
}
export function updateLatest({repository=process.env.GITHUB_REPOSITORY,runGh=execute}={}) {
 if(repository!=='mamachanko/pink')throw new Error('Unexpected tap repository');
 const release=JSON.parse(runGh(['release','view','--repo',repository,'--json','tagName,isDraft,isPrerelease,assets']));
 if(release.isDraft||release.isPrerelease||!/^v[1-9]\d*\.\d+\.\d+$/.test(release.tagName))throw new Error('Expected a stable published release');
 const directory=mkdtempSync(join(tmpdir(),'pink-homebrew-release-'));
 try {
  const download=names=>runGh(['release','download',release.tagName,'--repo',repository,'--dir',directory,...names.flatMap(name=>['--pattern',name])]);
  download(['build-info.json','SHA256SUMS']);
  const info=JSON.parse(readFileSync(join(directory,'build-info.json')));
  if(`v${info.version}`!==release.tagName)throw new Error('Release version mismatch');
  // Validates version/signing/notarization before constructing any artifact paths.
  const validModes=['adhoc','developer-id'];
  if(!validModes.includes(info.signingMode))throw new Error('Invalid signing mode');
  const expected=['build-info.json','SHA256SUMS',`Pink-${info.version}-${info.signingMode}.zip`,`Pink-${info.version}-${info.signingMode}.dmg`];
  if(JSON.stringify(release.assets.map(a=>a.name).sort())!==JSON.stringify([...expected].sort()))throw new Error('Unexpected published asset set');
  download(expected.slice(2));validate(directory);
  const tag=JSON.parse(runGh(['api',`repos/${repository}/git/ref/tags/${release.tagName}`]));
  if(tag.object.type!=='commit'||tag.object.sha!==info.commit)throw new Error('Published commit mismatch');
  return proposeCaskUpdate({directory,repository,runGh});
 } finally {rmSync(directory,{recursive:true,force:true});}
}
if(process.argv[1]===fileURLToPath(import.meta.url)) console.log(JSON.stringify(process.argv.includes('--latest')?updateLatest():proposeCaskUpdate()));
