import {existsSync,readFileSync,mkdtempSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {validate} from './check-assets.mjs';
if (existsSync('dist/build-info.json')) {
 const info=JSON.parse(readFileSync('dist/build-info.json'));
 const tag=`v${info.version}`;
 const commit=execFileSync('git',['rev-list','-n','1',tag],{encoding:'utf8'}).trim();
 if(commit!==info.commit) throw new Error('Release commit mismatch');
 const dir=mkdtempSync(join(tmpdir(),'refpaste-published-'));
 try {
  execFileSync('gh',['release','download',tag,'--dir',dir],{stdio:'inherit'});
  validate(dir);
  if(readFileSync(join(dir,'build-info.json'),'utf8')!==readFileSync('dist/build-info.json','utf8')) throw new Error('Published manifest mismatch');
 } finally {rmSync(dir,{recursive:true,force:true});}
}
