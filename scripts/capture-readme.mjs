import {spawn, spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
const output = resolve(process.argv[2] ?? 'build/readme-captures');
mkdirSync(output, {recursive:true});
function command(program,args) {
 const result=spawnSync(program,args,{stdio:'inherit'});
 if(result.error || result.status!==0) throw new Error(`Capture command failed: ${program}`);
}
command('.tools/xcodegen',['generate']);
command('xcodebuild',['-project','Pink.xcodeproj','-scheme','PinkReadmeCapture','-configuration','Release','-derivedDataPath','build/ReadmeDerivedData','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','CODE_SIGN_IDENTITY=-','build']);
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
 await waitFor('settings.png');
 await waitFor('capture.txt');
} finally { if(!exited) app.kill('SIGTERM'); }
