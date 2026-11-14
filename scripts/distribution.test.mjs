import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync,symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {verifyLayout} from './package-layout.mjs';
import {renderCask,caskForDistribution} from './homebrew.mjs';

test('archives reject legacy, additional, renamed, or linked application bundles',()=>{
 const root=mkdtempSync(join(tmpdir(),'pink-layout-'));
 try {
  for(const name of ['RefPaste.app','RevPaste.app','Ping.app']) {
   mkdirSync(join(root,name));assert.throws(()=>verifyLayout(root));rmSync(join(root,name),{recursive:true});
  }
  mkdirSync(join(root,'Pink.app/Contents/MacOS'),{recursive:true});writeFileSync(join(root,'Pink.app/Contents/MacOS/Pink'),'binary');verifyLayout(root);
  mkdirSync(join(root,'RefPaste.app'));assert.throws(()=>verifyLayout(root));rmSync(join(root,'RefPaste.app'),{recursive:true});
  writeFileSync(join(root,'Pink.app/Contents/MacOS/RefPaste'),'old');assert.throws(()=>verifyLayout(root));
  rmSync(join(root,'Pink.app'),{recursive:true});mkdirSync(join(root,'actual'));symlinkSync(join(root,'actual'),join(root,'Pink.app'));assert.throws(()=>verifyLayout(root));
 } finally {rmSync(root,{recursive:true,force:true});}
});

test('Homebrew pins the final DMG and cannot misrepresent signing or accept unsafe metadata',()=>{
 const root=mkdtempSync(join(tmpdir(),'pink-cask-'));
 try {
  writeFileSync(join(root,'build-info.json'),JSON.stringify({version:'1.2.3',signingMode:'adhoc',notarization:'none'}));
  writeFileSync(join(root,'Pink-1.2.3-adhoc.dmg'),'final stapled or ad-hoc image');
  const digest=createHash('sha256').update('final stapled or ad-hoc image').digest('hex');
  const cask=caskForDistribution(root);assert.ok(cask.includes(`sha256 "${digest}"`));assert.ok(cask.includes('version "1.2.3"'));assert.ok(cask.includes('app "Pink.app"'));assert.ok(cask.includes('Ad-hoc signed; not Developer ID signed; not notarized.'));
  const developer=renderCask({version:'2.0.0',sha256:digest,signingMode:'developer-id',notarization:'accepted'});assert.ok(developer.includes('-developer-id.dmg'));assert.ok(developer.includes('Developer ID signed and notarized.'));
  assert.throws(()=>renderCask({version:'2.0.0',sha256:digest,signingMode:'developer-id',notarization:'none'}));
  assert.throws(()=>renderCask({version:'../../bad',sha256:digest,signingMode:'adhoc'}));
  assert.throws(()=>renderCask({version:'1.0.0',sha256:':no_check',signingMode:'adhoc'}));
 } finally {rmSync(root,{recursive:true,force:true});}
});
