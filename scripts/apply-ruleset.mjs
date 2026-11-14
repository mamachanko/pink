import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
function matches(actual,expected) {
 if(Array.isArray(expected)) {
  if(!Array.isArray(actual)||actual.length!==expected.length)return false;
  return expected.every(value=>actual.some(candidate=>matches(candidate,value)));
 }
 if(expected&&typeof expected==='object')return actual&&Object.entries(expected).every(([key,value])=>matches(actual[key],value));
 return actual===expected;
}
const policyKeys=['name','target','enforcement','bypass_actors','conditions','rules'];
const matchesPolicy=(actual,policy)=>policyKeys.every(key=>matches(actual[key],policy[key]));
export function applyRuleset({runGh=args=>execFileSync('gh',args,{encoding:'utf8'}),apply=false}={}) {
 const policy=JSON.parse(readFileSync('.github/rulesets/main.json','utf8'));
 const repository='mamachanko/pink';
 const gh=(...args)=>JSON.parse(runGh(args));
 const checks=gh('api',`repos/${repository}/commits/main/check-runs?per_page=100`).check_runs;
 // Activate only after the new default-branch workflow exists and has actually passed.
 if(!checks.some(c=>c.name==='Required checks'&&c.app?.id===15368&&c.conclusion==='success')) throw new Error('First merge the CI changes and obtain a passing Required checks run on main');
 const existing=gh('api',`repos/${repository}/rulesets`);
 const match=existing.find(r=>r.name===policy.name);
 if(match) {
  const actual=gh('api',`repos/${repository}/rulesets/${match.id}`);
  if(matchesPolicy(actual,policy)) return {unchanged:true,id:match.id};
  throw new Error('An existing ruleset differs; review it manually without weakening protections');
 }
 if(!apply) return {dryRun:true,policy};
 const directory=mkdtempSync(join(tmpdir(),'pink-ruleset-'));
 try {
  const input=join(directory,'ruleset.json');writeFileSync(input,JSON.stringify(policy));
  const result=gh('api','--method','POST',`repos/${repository}/rulesets`,'--input',input);
  const actual=gh('api',`repos/${repository}/rulesets/${result.id}`);
  if(!matchesPolicy(actual,policy)) throw new Error('Ruleset activation could not be verified');
  return {id:result.id,active:true};
 } finally {rmSync(directory,{recursive:true,force:true});}
}
if(process.argv[1]===fileURLToPath(import.meta.url)) console.log(JSON.stringify(applyRuleset({apply:process.argv.includes('--apply')}),null,2));
