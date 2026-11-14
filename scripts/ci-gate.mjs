import {fileURLToPath} from 'node:url';
export function checkGate({event, verification, title}) {
 if(!['pull_request','workflow_dispatch','push'].includes(event)) throw new Error('Unexpected CI event');
 if(verification !== 'success') throw new Error('Required verification did not succeed');
 if(title !== (event === 'push' ? 'skipped' : 'success')) throw new Error('PR title validation did not succeed');
}
if(process.argv[1]===fileURLToPath(import.meta.url)) {
 checkGate({event:process.env.CI_EVENT,verification:process.env.VERIFICATION_RESULT,title:process.env.TITLE_RESULT});
}
