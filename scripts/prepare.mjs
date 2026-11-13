import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
export function signingMode(env) {
  const mode = env.SIGNING_MODE ?? 'adhoc';
  if (!['adhoc', 'developer-id'].includes(mode)) throw new Error('Invalid signing mode');
  const keys = ['APPLE_CERTIFICATE_P12_BASE64', 'APPLE_CERTIFICATE_PASSWORD', 'APPLE_SIGNING_IDENTITY', 'APPLE_ID', 'APPLE_TEAM_ID', 'APPLE_APP_PASSWORD'];
  const present = keys.filter(k => env[k]);
  if (mode === 'developer-id' && present.length !== keys.length) throw new Error('Incomplete Developer ID credentials');
  if (mode === 'adhoc' && present.length) throw new Error('Signing credentials require explicit developer-id mode');
  return mode;
}
export function prepare(version, env = process.env) {
  if (!/^[1-9]\d*\.\d+\.\d+$/.test(version)) throw new Error('Expected stable release version');
  signingMode(env);
  const result = spawnSync('bash', ['scripts/package.sh'], {stdio: 'inherit', env: {...env, REFPASTE_VERSION: version}});
  if (result.status !== 0) throw new Error('Package preparation failed');
}
if (process.argv[1] === fileURLToPath(import.meta.url)) prepare(process.argv[2]);
