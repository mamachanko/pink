import {readdirSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
export function validate(directory) {
  const files = readdirSync(directory).sort();
  const manifest = JSON.parse(readFileSync(`${directory}/build-info.json`));
  const expected = ['SHA256SUMS','build-info.json', `Pink-${manifest.version}-${manifest.signingMode}.zip`, `Pink-${manifest.version}-${manifest.signingMode}.dmg`].sort();
  if (JSON.stringify(files) !== JSON.stringify(expected)) throw new Error('Unexpected release asset set');
  const lines = readFileSync(`${directory}/SHA256SUMS`,'utf8').trim().split('\n');
  if (lines.length !== 3) throw new Error('Incomplete checksums');
  const names = new Set();
  for (const line of lines) {
    const match = /^([a-f0-9]{64})  (.+)$/.exec(line);
    if (!match || !expected.includes(match[2]) || match[2] === 'SHA256SUMS' || names.has(match[2])) throw new Error('Invalid checksum entry');
    names.add(match[2]);
    if (createHash('sha256').update(readFileSync(`${directory}/${match[2]}`)).digest('hex') !== match[1]) throw new Error('Checksum mismatch');
  }
}
if (process.argv[1]?.endsWith('check-assets.mjs')) validate(process.argv[2] ?? 'dist');
