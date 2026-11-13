import {Writable} from "node:stream";
const sink = () => new Writable({write(chunk, encoding, callback) { callback(); }});
import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {analyzeCommits} from '@semantic-release/commit-analyzer';
import {generateNotes} from '@semantic-release/release-notes-generator';
import {signingMode, prepare} from './prepare.mjs';
import {validate} from './check-assets.mjs';
import {createHash} from 'node:crypto';
const config = createRequire(import.meta.url)('../release.config.cjs');
const options = config.plugins[0][1];
const logger = {log(){}, error(){}, success(){}};
const cases = [['fix: repair','patch'], ['perf: faster','patch'], ['feat: add','minor'], ['feat!: changed','major'], ['docs!: changed','major'], ['chore: changed\n\nBREAKING CHANGE: schema changed','major'], ['docs: help',null], ['test: tests',null], ['ci: checks',null], ['chore: upkeep',null]];
for (const [message, expected] of cases) test(`actual analyzer: ${message}`, async () => {
  const cwd = mkdtempSync(join(tmpdir(), 'pink-git-'));
  try {
    const git = (...a) => execFileSync('git', a, {cwd,encoding:'utf8'}).trim();
    git('init','-b','main'); git('config','user.name','Test'); git('config','user.email','test@example.invalid');
    git('commit','--allow-empty','-m',message);
    const commits = [{hash:git('rev-parse','HEAD'),message:git('log','-1','--format=%B')}];
    assert.equal(await analyzeCommits(options, {cwd, commits, logger}), expected);
    const notes = await generateNotes(config.plugins[1][1], {cwd, commits, logger, options:{repositoryUrl:'https://github.com/mamachanko/pink'}, lastRelease:{}, nextRelease:{version:'1.0.0',gitTag:'v1.0.0'}});
    assert.equal(typeof notes,'string');
  } finally { rmSync(cwd,{recursive:true,force:true}); }
});
test('actual semantic-release engine versions', () => runEngine('versions'));
test('signing fails closed and prepare rejects bad versions', () => {
 assert.equal(signingMode({}),'adhoc');
 assert.throws(()=>signingMode({SIGNING_MODE:'developer-id'}));
 assert.throws(()=>signingMode({APPLE_ID:'partial'}));
 assert.throws(()=>prepare('1.0.0; echo unsafe'));
 assert.throws(()=>prepare('1.0.0',{SIGNING_MODE:'developer-id'}));
});
test('asset allowlist and checksums enforce completeness', () => {
 const cwd=mkdtempSync(join(tmpdir(),'pink-assets-'));
 try {
  const values={'build-info.json': JSON.stringify({version:'1.2.3',signingMode:'adhoc'}),'Pink-1.2.3-adhoc.zip':'zip','Pink-1.2.3-adhoc.dmg':'dmg'};
  for(const [name,value] of Object.entries(values)) writeFileSync(join(cwd,name),value);
  writeFileSync(join(cwd,'SHA256SUMS'),Object.entries(values).map(([n,v])=>`${createHash('sha256').update(v).digest('hex')}  ${n}`).join('\n')+'\n');
  validate(cwd);rmSync(join(cwd,'Pink-1.2.3-adhoc.zip'));assert.throws(()=>validate(cwd));writeFileSync(join(cwd,'Pink-1.2.3-adhoc.zip'),'corrupt');assert.throws(()=>validate(cwd));
 } finally {rmSync(cwd,{recursive:true,force:true});}
});
test('actual exec preparation failure blocks publication', () => runEngine('failure'));
function runEngine(mode) {
 const env={...process.env}; delete env.NODE_TEST_CONTEXT;
 execFileSync(process.execPath,['scripts/engine-fixture.mjs',mode],{env,stdio:'pipe'});
}
