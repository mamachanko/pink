import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const subjectPattern=/^(feat|fix|perf|docs|test|chore|ci|build|refactor|style|revert)(\([^()\r\n]+\))?!?: [^\r\n]+$/;
export function checkPR(pr,{repository,sha,dispatch=false}) {
 if(!subjectPattern.test(pr.title??'')) throw new Error('Use a Conventional Commit PR title');
 if(pr.base?.ref!=='main') throw new Error('Unexpected PR base');
 if(dispatch && (pr.state!=='open'||pr.head?.sha!==sha||pr.head?.repo?.full_name!==repository)) throw new Error('Dispatch must verify the exact open same-repository PR head');
}
export function checkCommits(commits,expectedHead) {
 if(!commits.length||commits.at(-1).sha!==expectedHead)throw new Error('PR commit list changed or is incomplete');
 for(const commit of commits) {
  if((commit.parents??[]).length>1)continue;
  if(!subjectPattern.test((commit.commit?.message??'').split('\n')[0]))throw new Error('Use Conventional Commit source subjects for rebase merging');
 }
}
if(process.argv[1]===fileURLToPath(import.meta.url)) {
 const event=JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 const dispatch=process.env.GITHUB_EVENT_NAME==='workflow_dispatch';
 const number=dispatch?event.inputs?.pull_request:event.number;
 if(!/^[1-9]\d{0,9}$/.test(number??''))throw new Error('Expected a PR number');
 let pr=event.pull_request;
 if(dispatch) {
  pr=JSON.parse(execFileSync('gh',['api',`repos/${process.env.GITHUB_REPOSITORY}/pulls/${number}`],{encoding:'utf8'}));
 }
 checkPR(pr??{},{repository:process.env.GITHUB_REPOSITORY,sha:process.env.GITHUB_SHA,dispatch});
 const commits=JSON.parse(execFileSync('gh',['api','--paginate','--slurp',`repos/${process.env.GITHUB_REPOSITORY}/pulls/${number}/commits`],{encoding:'utf8'})).flat();
 checkCommits(commits,pr.head.sha);
 console.log('PASS: PR title, source commits and dispatch identity');
}
