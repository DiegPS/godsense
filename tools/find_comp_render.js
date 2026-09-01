const fs = require('fs');
const code = fs.readFileSync('C:/Users/dpahu/AppData/Local/Programs/@frontendshell/resources/backend/_internal/frontend/desktop/dist/assets/index-BdrAHTOb.js', 'utf8');

// Search for teamComp in the code
let pos = 0;
while (true) {
  const i = code.indexOf('guidelines', pos);
  if (i === -1) break;
  if (!code.substring(i-50, i+50).includes('teamComp.guidelines')) {
    console.log('--- USAGE OF guidelines ---');
    console.log(code.substring(Math.max(0, i - 300), Math.min(code.length, i + 500)));
  }
  pos = i + 1;
}
