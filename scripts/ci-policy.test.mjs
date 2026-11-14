import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import YAML from 'yaml';
import {checkGate} from './ci-gate.mjs';
import {checkPR,checkCommits} from './check-pr.mjs';
import {applyRuleset} from './apply-ruleset.mjs';

test('required gate rejects failed, cancelled, missing and unexpectedly skipped prerequisites',()=>{
 for(const event of ['pull_request','workflow_dispatch','push']) {
  const title=event==='push'?'skipped':'success';checkGate({event,verification:'success',title});
  for(const result of ['failure','cancelled','skipped','timed_out',undefined]) assert.throws(()=>checkGate({event,verification:result,title}));
  for(const result of ['failure','cancelled',undefined,event==='push'?'success':'skipped']) assert.throws(()=>checkGate({event,verification:'success',title:result}));
 }
 assert.throws(()=>checkGate({event:'pull_request_target',verification:'success',title:'success'}));
});
test('title validation uses the same convention and dispatch cannot attest a stale or foreign head',()=>{
 const pr={title:'feat(core)!: support new input',state:'open',base:{ref:'main'},head:{sha:'exact',repo:{full_name:'mamachanko/pink'}}};
 const options={repository:'mamachanko/pink',sha:'exact',dispatch:true};checkPR(pr,options);
 for(const title of ['bad title','feat: one\nfeat: two','feat!!: invalid']) assert.throws(()=>checkPR({...pr,title},options));
 for(const head of [{...pr.head,sha:'stale'},{...pr.head,repo:{full_name:'other/pink'}}]) assert.throws(()=>checkPR({...pr,head},options));
 assert.throws(()=>checkPR({...pr,state:'closed'},options));
 checkPR({...pr,head:{repo:{full_name:'fork/pink'}}},{dispatch:false});
});
test('all PR checks flow into a unique unconditional gate and release includes native UI capture',()=>{
 const load=name=>YAML.parse(readFileSync(`.github/workflows/${name}.yml`,'utf8'));
 const ci=load('ci'),verify=load('verify'),capture=load('readme-images'),release=load('release');
 assert.equal(ci.jobs.required.name,'Required checks');assert.equal(ci.jobs.required.if,'always()');assert.deepEqual(ci.jobs.required.needs,['verify','title']);
 assert.ok(ci.on.pull_request.types.includes('edited'));assert.ok(ci.on.workflow_dispatch);
 assert.ok(ci.concurrency.group.includes('github.event_name')); // approval-waiting PR runs cannot cancel the dispatched run

 assert.deepEqual(verify.jobs.required.needs,['native','readme']);assert.equal(verify.jobs.readme.uses,'./.github/workflows/readme-images.yml');assert.ok('workflow_call' in capture.on);
 assert.equal(release.jobs.verify.uses,'./.github/workflows/verify.yml');assert.equal(release.concurrency['cancel-in-progress'],false);
 assert.equal(ci.permissions.contents,'read');assert.equal(ci.jobs.title.permissions['pull-requests'],'read');
});
test('main policy requires PRs and the observed Actions identity, without admin bypass or force pushes',()=>{
 const p=JSON.parse(readFileSync('.github/rulesets/main.json'));
 assert.equal(p.enforcement,'active');assert.deepEqual(p.bypass_actors,[]);assert.deepEqual(p.conditions.ref_name.include,['refs/heads/main']);
 for(const type of ['pull_request','required_linear_history','deletion','non_fast_forward']) assert.ok(p.rules.some(r=>r.type===type));
 const checks=p.rules.find(r=>r.type==='required_status_checks').parameters;
 assert.equal(checks.strict_required_status_checks_policy,true);assert.deepEqual(checks.required_status_checks,[{context:'Required checks',integration_id:15368}]);
 assert.deepEqual(p.rules.find(r=>r.type==='pull_request').parameters.allowed_merge_methods,['squash','rebase']);
});
test('ruleset application refuses activation before the real gate passes and avoids overwriting policies',()=>{
 assert.throws(()=>applyRuleset({apply:true,runGh:()=>'{"check_runs":[]}'}),/First merge/);
 let writes=0;
 const runGh=args=>{if(args.includes('--method'))writes++;return args[1].includes('check-runs')?JSON.stringify({check_runs:[{name:'Required checks',app:{id:15368},conclusion:'success'}]}):'[]';};
 assert.equal(applyRuleset({runGh}).dryRun,true);assert.equal(writes,0);
 assert.throws(()=>applyRuleset({apply:true,runGh:args=>args[1].includes('check-runs')?runGh(args):args[1].endsWith('/rulesets')?'[{"id":1,"name":"Protect main"}]':'{"name":"Protect main","enforcement":"disabled"}'}),/differs/);
});
test('ruleset creation reads back every requested protection and is idempotent across API ordering',()=>{
 const policy=JSON.parse(readFileSync('.github/rulesets/main.json'));
 const good={...policy,id:42,rules:[...policy.rules].reverse(),created_at:'metadata'};
 let created=false,input;
 const runGh=args=>{
  if(args.includes('--method')){created=true;input=JSON.parse(readFileSync(args[args.indexOf('--input')+1]));return '{"id":42}';}
  if(args[1].includes('check-runs'))return '{"check_runs":[{"name":"Required checks","app":{"id":15368},"conclusion":"success"}]}';
  if(args[1].endsWith('/rulesets'))return created?'[{"id":42,"name":"Protect main"}]':'[]';
  return JSON.stringify(good);
 };
 assert.equal(applyRuleset({runGh,apply:true}).active,true);assert.deepEqual(input,policy);
 assert.equal(applyRuleset({runGh,apply:true}).unchanged,true);
 const weakened=structuredClone(good);weakened.bypass_actors=[{actor_id:5,actor_type:'RepositoryRole',bypass_mode:'always'}];
 assert.throws(()=>applyRuleset({runGh:args=>args[1].endsWith('/rulesets/42')?JSON.stringify(weakened):runGh(args),apply:true}),/differs/);
});
test('privileged maintenance checks out trusted main and never consumes workflow_run artifacts or signing secrets',()=>{
 const source=readFileSync('.github/workflows/homebrew.yml','utf8'),workflow=YAML.parse(source);
 assert.deepEqual(workflow.on.push.branches,['main']);assert.equal(workflow.concurrency['cancel-in-progress'],false);
 const job=workflow.jobs.update;
 for(const guard of ['head_repository.full_name == github.repository',"head_branch == 'main'","event == 'push'","conclusion == 'success'"])assert.ok(job.if.includes(guard));
 assert.equal(job.steps[0].with.ref,'main');assert.equal(job.steps[0].with['persist-credentials'],false);
 assert.deepEqual(job.permissions,{contents:'write','pull-requests':'write',actions:'write'});
 assert.ok(!source.includes('download-artifact'));assert.ok(!source.includes('secrets.'));assert.ok(!source.includes('pull_request_target'));
});

test('source commit validation preserves the release convention for rebase merges',()=>{
 const commits=[{sha:'first',parents:[{}],commit:{message:'docs: help\n\nDetails'}},{sha:'head',parents:[{},{}],commit:{message:'Merge main'}}];
 checkCommits(commits,'head');
 assert.throws(()=>checkCommits(commits,'stale'),/changed/);
 assert.throws(()=>checkCommits([],'head'),/incomplete/);
 assert.throws(()=>checkCommits([{sha:'head',parents:[{}],commit:{message:'nonconventional'}}],'head'),/Conventional/);
 for(const subject of ['fix!: changed','docs!: changed','chore: changed\n\nBREAKING CHANGE: schema'])checkCommits([{sha:'head',parents:[{}],commit:{message:subject}}],'head');
});
