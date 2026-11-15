import {execFileSync} from 'node:child_process';
import {readFileSync,mkdtempSync,rmSync,existsSync,mkdirSync,writeFileSync,renameSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
const pin=JSON.parse(readFileSync('tools/sparkle.json'));
const destination='.tools/sparkle';
if(!existsSync(`${destination}/verified.json`) || readFileSync(`${destination}/verified.json`,'utf8')!==JSON.stringify(pin)) {
 mkdirSync('.tools',{recursive:true});
 const work=mkdtempSync('.tools/sparkle-download-');
 try {
  const archive=join(work,'sparkle.tar.xz');
  execFileSync('curl',['--fail','--location','--proto','=https','--proto-redir','=https','--tlsv1.2','--retry','3','--output',archive,pin.url],{stdio:'inherit'});
  if(createHash('sha256').update(readFileSync(archive)).digest('hex')!==pin.sha256)throw new Error('Sparkle checksum mismatch');
  const unpack=join(work,'unpack');mkdirSync(unpack);
  execFileSync('tar',['-xf',archive,'-C',unpack,'./Sparkle.framework','./bin','./LICENSE']);
  writeFileSync(join(unpack,'verified.json'),JSON.stringify(pin));
  rmSync(destination,{recursive:true,force:true});renameSync(unpack,destination);
 } finally {rmSync(work,{recursive:true,force:true});}
}
