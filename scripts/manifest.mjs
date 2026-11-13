import {execFileSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
const command = (...args) => execFileSync(args[0], args.slice(1), {encoding:'utf8'}).trim();
writeFileSync('dist/build-info.json', JSON.stringify({
  version: process.env.REFPASTE_VERSION, build: process.env.REFPASTE_BUILD,
  commit: command('git','rev-parse','HEAD'), architectures: ['arm64','x86_64'], minimumOS:'15.0',
  toolchain: command('xcodebuild','-version') + '\n' + command('swift','--version'),
  signingMode: process.env.SIGNING_MODE ?? 'adhoc', notarization: process.env.REFPASTE_NOTARIZATION,
  ci: {repository:process.env.GITHUB_REPOSITORY ?? null, run:process.env.GITHUB_RUN_ID ?? null, attempt:process.env.GITHUB_RUN_ATTEMPT ?? null}
}, null, 2) + '\n');
