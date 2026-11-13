import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {setTimeout} from 'node:timers/promises';

export async function mountImage(image, mount, {
 run = (args) => spawnSync('hdiutil', args, {encoding:'utf8'}),
 delay = (seconds) => setTimeout(seconds * 1000),
 log = (message) => process.stderr.write(message),
} = {}) {
 // DiskImages can report EAGAIN just after creation, even for a valid image.
 // Retry only that documented-in-logs category; verification still must mount it.
 for(let attempt = 0; attempt < 4; attempt++) {
  const result = run(['attach', image, '-mountpoint', mount, '-nobrowse', '-readonly']);
  if(!result.error && result.status === 0) return;
  if(result.stderr) log(result.stderr);
  if(result.error || !/hdiutil: attach failed - Resource temporarily unavailable/.test(result.stderr ?? '') || attempt === 3) {
   throw new Error('DMG mount failed', {cause:result.error});
  }
  log(`Retrying temporary DMG mount resource failure (${attempt + 1}/3)\n`);
  await delay(2 ** attempt);
 }
}
if(process.argv[1] === fileURLToPath(import.meta.url)) {
 if(process.argv.length !== 4) throw new Error('Expected image and unique temporary mount directory');
 await mountImage(process.argv[2], process.argv[3]);
}
