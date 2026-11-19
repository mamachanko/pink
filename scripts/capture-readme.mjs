import {createHash} from 'node:crypto';
import {spawn, spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
const output = resolve(process.argv[2] ?? 'build/readme-captures');
mkdirSync(output, {recursive:true});
// Retake owned outputs rather than accidentally accepting stale screenshots or handshakes.
for (const name of ['menu-region.json','menu-captured','settings-window.json','settings-captured','general-window.json','general-captured','formats-window.json','formats-captured','menu-bar.png','settings.png','general.png','link-formats.png','capture.txt','failure.txt']) rmSync(`${output}/${name}`,{force:true});
function command(program,args) {
 const result=spawnSync(program,args,{stdio:'inherit'});
 if(result.error || result.status!==0) throw new Error(`Capture command failed: ${program}`);
}
const architecture = {arm64:'arm64',x64:'x86_64'}[process.arch];
if (!architecture) throw new Error('Unsupported native capture architecture');
command('.tools/xcodegen',['generate']);
command('xcodebuild',['-project','Pink.xcodeproj','-scheme','PinkReadmeCapture','-configuration','Release','-derivedDataPath','build/ReadmeDerivedData',`ARCHS=${architecture}`,'ONLY_ACTIVE_ARCH=YES','CODE_SIGN_IDENTITY=-','build']);
const app=spawn('build/ReadmeDerivedData/Build/Products/Release/PinkReadmeCapture.app/Contents/MacOS/PinkReadmeCapture',[output],{stdio:'inherit'});
let exited=false;
app.on('exit',()=>{exited=true;});
async function waitFor(name) {
 const deadline=Date.now()+60000;
 while(!existsSync(`${output}/${name}`)) {
  if(exited || existsSync(`${output}/failure.txt`) || Date.now()>deadline) throw new Error(`Capture did not produce ${name}`);
  await new Promise(r=>setTimeout(r,100));
 }
}
try {
 await waitFor('menu-region.json');
 const b=JSON.parse(readFileSync(`${output}/menu-region.json`));
 // Native region capture; no image generation, compositing, or permission changes.
 command('/usr/sbin/screencapture',['-x','-R',`${b.x},${b.y},${b.width},${b.height}`,`${output}/menu-bar.png`]);
 writeFileSync(`${output}/menu-captured`,'');
 for (const [metadata,image,marker] of [
  ['settings-window.json','settings.png','settings-captured'],
  ['general-window.json','general.png','general-captured'],
  ['formats-window.json','link-formats.png','formats-captured']
 ]) {
  await waitFor(metadata);
  const {number}=JSON.parse(readFileSync(`${output}/${metadata}`));
  if(!Number.isSafeInteger(number)||number<=0)throw new Error('Invalid capture window number');
  command('/usr/sbin/screencapture',['-x','-l',String(number),'-o',`${output}/${image}`]);
  writeFileSync(`${output}/${marker}`,'');
 }
 await waitFor('capture.txt');
} finally { if(!exited) app.kill('SIGTERM'); }

// Fixed synthetic demo outputs can be reviewed through connectors without artifact downloads.
if (process.env.PINK_CAPTURE_TEXT_EXPORT === '1') {
 for (const name of ['menu-bar.png','settings.png','general.png','link-formats.png','capture.txt']) {
  const bytes = readFileSync(`${output}/${name}`);
  if (bytes.length > 1024 * 1024) throw new Error('Capture is too large for inline review');
  const encoded = bytes.toString('base64');
  console.log(`PINK_CAPTURE_BEGIN ${name} ${createHash('sha256').update(bytes).digest('hex')}`);
  for (let offset=0; offset<encoded.length; offset+=4096) console.log(`PINK_CAPTURE_DATA ${encoded.slice(offset,offset+4096)}`);
  console.log(`PINK_CAPTURE_END ${name}`);
 }
}
