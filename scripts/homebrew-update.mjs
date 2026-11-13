import {execFileSync} from 'node:child_process';
import {existsSync,readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {caskForDistribution} from './homebrew.mjs';
function compareVersions(a,b) {
 const left=a.split('.').map(BigInt), right=b.split('.').map(BigInt);
 for(let i=0;i<3;i++) { if(left[i]>right[i]) return 1; if(left[i]<right[i]) return -1; }
 return 0;
}
export function proposeCaskUpdate({directory='dist',repository=process.env.GITHUB_REPOSITORY,runGh=(args)=>execFileSync('gh',args,{encoding:'utf8'}).trim()}={}) {
 if(!existsSync(`${directory}/build-info.json`)) return {created:false};
 if(repository!=='mamachanko/pink') throw new Error('Unexpected tap repository');
 const info=JSON.parse(readFileSync(`${directory}/build-info.json`));
 const content=caskForDistribution(directory);
 const branch=`homebrew/v${info.version}`;
 const gh=(...args)=>runGh(args);
 const main=JSON.parse(gh('api',`repos/${repository}/git/ref/heads/main`)).object.sha;
 const current=JSON.parse(gh('api',`repos/${repository}/contents/Casks/pink.rb?ref=${main}`));
 const currentContent=Buffer.from(current.content,'base64').toString('utf8');
 if(currentContent===content) return {created:false};
 const currentVersion=currentContent.match(/^\s*version "(\d+\.\d+\.\d+)"/m)?.[1];
 if(!currentVersion) throw new Error('Malformed current Homebrew metadata');
 if(compareVersions(currentVersion,info.version)>0) return {created:false,reason:'newer-cask-already-reviewed'};
 const temporary=mkdtempSync(join(tmpdir(),'pink-homebrew-'));
 try {
  const refs=JSON.parse(gh('api',`repos/${repository}/git/matching-refs/heads/${branch}`));
  if(!refs.some(r=>r.ref===`refs/heads/${branch}`)) {
   const file=join(temporary,'branch.json');writeFileSync(file,JSON.stringify({ref:`refs/heads/${branch}`,sha:main}));
   gh('api','--method','POST',`repos/${repository}/git/refs`,'--input',file);
  }
  const old=JSON.parse(gh('api',`repos/${repository}/contents/Casks/pink.rb?ref=${branch}`));
  const oldContent=Buffer.from(old.content,'base64').toString('utf8');
  if(oldContent!==currentContent && oldContent!==content) throw new Error('Homebrew update branch changed; manual review required');
  if(oldContent!==content) {
   const file=join(temporary,'cask.json');writeFileSync(file,JSON.stringify({message:`chore(homebrew): update Pink to ${info.version}`,content:Buffer.from(content).toString('base64'),sha:old.sha,branch}));
   gh('api','--method','PUT',`repos/${repository}/contents/Casks/pink.rb`,'--input',file);
  }
  const prs=JSON.parse(gh('pr','list','--repo',repository,'--head',branch,'--state','open','--json','number'));
  if(!prs.length) {
   const body=join(temporary,'body.md');writeFileSync(body,`Updates Homebrew metadata for verified release v${info.version}. The cask pins the final DMG SHA-256. Review and merge to make brew upgrade discover this version. Application version files and release assets are unchanged.\n`);
   gh('pr','create','--repo',repository,'--base','main','--head',branch,'--title',`chore(homebrew): update Pink to ${info.version}`,'--body-file',body);
  }
  return {created:!prs.length,branch};
 } finally {rmSync(temporary,{recursive:true,force:true});}
}
if(process.argv[1]===fileURLToPath(import.meta.url)) proposeCaskUpdate();
