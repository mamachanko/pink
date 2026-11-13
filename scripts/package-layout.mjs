import {readdirSync,lstatSync} from 'node:fs';
import {join} from 'node:path';
export function verifyLayout(root) {
 const apps=readdirSync(root).filter(name=>name.toLowerCase().endsWith('.app')).sort();
 if(JSON.stringify(apps)!==JSON.stringify(['Pink.app']) || !lstatSync(join(root,'Pink.app')).isDirectory()) throw new Error('Distribution must contain exactly Pink.app');
 const executables=readdirSync(join(root,'Pink.app/Contents/MacOS')).sort();
 if(JSON.stringify(executables)!==JSON.stringify(['Pink'])) throw new Error('App must contain only the Pink executable');
}
if(process.argv[1]?.endsWith('package-layout.mjs')) verifyLayout(process.argv[2]);
