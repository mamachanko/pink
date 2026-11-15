import {readdirSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
export function expectedAssets(manifest) {
  if (!/^(0|[1-9]\d*)\.\d+\.\d+$/.test(manifest.version) || !['adhoc','developer-id'].includes(manifest.signingMode)) throw new Error('Invalid distribution metadata');
  const expected = ['SHA256SUMS','build-info.json', `Pink-${manifest.version}-${manifest.signingMode}.zip`, `Pink-${manifest.version}-${manifest.signingMode}.dmg`];
  // Historical releases have four assets. New releases explicitly declare the update mode.
  if (manifest.updates) {
    if (!['manual','sparkle'].includes(manifest.updates.mode)) throw new Error('Invalid update manifest');
    const allowed=manifest.updates.mode==='sparkle'?['mode','publicKey']:['mode'];
    if(JSON.stringify(Object.keys(manifest.updates).sort())!==JSON.stringify(allowed.sort()))throw new Error('Unexpected update manifest fields');
    if(manifest.updates.mode==='sparkle') {
      const key=Buffer.from(manifest.updates.publicKey??'','base64');
      if(key.length!==32||key.toString('base64')!==manifest.updates.publicKey)throw new Error('Invalid public update key');
    }
    expected.push('appcast.xml');
  }
  return expected.sort();
}
export function validate(directory) {
  const files = readdirSync(directory).sort();
  const manifest = JSON.parse(readFileSync(`${directory}/build-info.json`));
  const expected = expectedAssets(manifest);
  if (JSON.stringify(files) !== JSON.stringify(expected)) throw new Error('Unexpected release asset set');
  const lines = readFileSync(`${directory}/SHA256SUMS`,'utf8').trim().split('\n');
  if (lines.length !== expected.length-1) throw new Error('Incomplete checksums');
  const names = new Set();
  for (const line of lines) {
    const match = /^([a-f0-9]{64})  (.+)$/.exec(line);
    if (!match || !expected.includes(match[2]) || match[2] === 'SHA256SUMS' || names.has(match[2])) throw new Error('Invalid checksum entry');
    names.add(match[2]);
    if (createHash('sha256').update(readFileSync(`${directory}/${match[2]}`)).digest('hex') !== match[1]) throw new Error('Checksum mismatch');
  }
}
if (process.argv[1]?.endsWith('check-assets.mjs')) validate(process.argv[2] ?? 'dist');
