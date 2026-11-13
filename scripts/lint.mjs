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
