import {readdirSync,readFileSync} from 'node:fs';
import YAML from 'yaml';
for (const file of readdirSync('.github/workflows')) {
  const content = readFileSync(`.github/workflows/${file}`, 'utf8');
  YAML.parse(content);
  if (content.includes('pull_request_target:')) throw new Error('Unsafe trigger');
  for (const match of content.matchAll(/uses:\s*([^\s]+)/g)) {
    if (!match[1].startsWith('./') && !/@[a-f0-9]{40}$/.test(match[1])) throw new Error('Unpinned action');
  }
}
YAML.parse(readFileSync('project.yml','utf8'));
const sparkle=JSON.parse(readFileSync('tools/sparkle.json'));
if(!/^\d+\.\d+\.\d+$/.test(sparkle.version)||!/[a-f0-9]{40}/.test(sparkle.commit)||!/^[a-f0-9]{64}$/.test(sparkle.sha256)||sparkle.url!==`https://github.com/sparkle-project/Sparkle/releases/download/${sparkle.version}/Sparkle-${sparkle.version}.tar.xz`)throw new Error('Inconsistent Sparkle pin; verify upstream commit and archive checksum');
