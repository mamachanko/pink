import test from 'node:test';
import assert from 'node:assert/strict';
import {mountImage} from './mount-image.mjs';
const temporary = {status:1, stderr:'hdiutil: attach failed - Resource temporarily unavailable\n'};

test('DMG mounting retries resource failures and keeps every read-only mount argument', async()=>{
 const calls=[], delays=[], messages=[];
 await mountImage('dist/Pink-test.dmg','/unique-temporary/mount',{
  run:args=>{calls.push(args);return calls.length<3?temporary:{status:0};},
  delay:async seconds=>{delays.push(seconds);},log:message=>messages.push(message),
 });
 assert.equal(calls.length,3);
 for(const call of calls) assert.deepEqual(call,['attach','dist/Pink-test.dmg','-mountpoint','/unique-temporary/mount','-nobrowse','-readonly']);
 assert.deepEqual(delays,[1,2]);
 assert.equal(messages.filter(x=>x.includes('attach failed')).length,2);
});
test('a corrupt or otherwise invalid DMG fails immediately without retry',async()=>{
 let attempts=0;
 await assert.rejects(mountImage('image','mount',{
  run:()=>{attempts++;return {status:1,stderr:'hdiutil: attach failed - no mountable file systems'};},
  delay:()=>assert.fail('Permanent errors must not retry'),log:()=>{},
 }),/DMG mount failed/);
 assert.equal(attempts,1);
});
test('repeated resource failures exhaust the bound and prevent packaging success',async()=>{
 let attempts=0;const delays=[];
 await assert.rejects(mountImage('image','mount',{
  run:()=>{attempts++;return temporary;},delay:async seconds=>{delays.push(seconds);},log:()=>{},
 }),/DMG mount failed/);
 assert.equal(attempts,4);assert.deepEqual(delays,[1,2,4]);
});
test('an unavailable mount command fails immediately',async()=>{
 const error=new Error('ENOENT');
 await assert.rejects(mountImage('image','mount',{
  run:()=>({status:null,error}),delay:()=>assert.fail('Missing commands must not retry'),log:()=>{},
 }),failure=>failure.cause===error);
});
