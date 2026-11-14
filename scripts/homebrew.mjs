import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
function validateRelease({version,signingMode,notarization}) {
 if(!/^[1-9]\d*\.\d+\.\d+$/.test(version) || !['adhoc','developer-id'].includes(signingMode)) throw new Error('Invalid cask release metadata');
 if(signingMode==='developer-id' && notarization!=='accepted') throw new Error('Developer ID cask requires accepted notarization');
}
export function renderCask({version,sha256,signingMode,notarization}, template=readFileSync('Casks/pink.rb','utf8')) {
 validateRelease({version,signingMode,notarization});
 if(!/^[1-9]\d*\.\d+\.\d+$/.test(version) || !/^[a-f0-9]{64}$/.test(sha256) || !['adhoc','developer-id'].includes(signingMode)) throw new Error('Invalid cask release metadata');
 return template
  .replace(/version "[^"]+"/,`version "${version}"`)
  .replace(/sha256 "[^"]+"/,`sha256 "${sha256}"`)
  .replace(/-(?:adhoc|developer-id)\.dmg/,`-${signingMode}.dmg`)
  .replace(/Ad-hoc signed; not Developer ID signed; not notarized\.|Developer ID signed and notarized\./,signingMode==='adhoc'?'Ad-hoc signed; not Developer ID signed; not notarized.':'Developer ID signed and notarized.');
}
export function caskForDistribution(directory='dist',template) {
 const info=JSON.parse(readFileSync(`${directory}/build-info.json`));
 validateRelease(info);
 const name=`Pink-${info.version}-${info.signingMode}.dmg`;
 return renderCask({...info,sha256:createHash('sha256').update(readFileSync(`${directory}/${name}`)).digest('hex')},template);
}
