import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

test('pinned lint tool versions have checksums for every supported platform',()=>{
 const bootstrap=readFileSync('scripts/lint-tools.sh','utf8');
 for(const tool of ['actionlint','shellcheck']) {
  const version=bootstrap.match(new RegExp(`^${tool}_version=(\\d+\\.\\d+\\.\\d+) `,'m'))?.[1];
  assert.ok(version,`Missing ${tool} version pin`);
  const entries=new Map();
  for(const line of readFileSync(`tools/${tool}-checksums.txt`,'utf8').trim().split('\n')) {
   const entry=/^([a-f0-9]{64})  (\S+)$/.exec(line);
   assert.ok(entry,`Malformed ${tool} checksum`);
   assert.ok(!entries.has(entry[2]),`Duplicate checksum for ${entry[2]}`);
   entries.set(entry[2],entry[1]);
  }
  for(const os of ['darwin','linux']) {
   for(const arch of tool==='actionlint'?['amd64','arm64']:['x86_64','aarch64']) {
    const archive=tool==='actionlint'?`actionlint_${version}_${os}_${arch}.tar.gz`:`shellcheck-v${version}.${os}.${arch}.tar.xz`;
    assert.ok(entries.has(archive),`Missing pinned checksum for ${archive}; refresh the official checksum manifest with the version pin`);
   }
  }
 }
});
