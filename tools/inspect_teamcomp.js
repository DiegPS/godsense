const fs = require('fs');
const code = fs.readFileSync('C:/Users/dpahu/AppData/Local/Programs/@frontendshell/resources/backend/_internal/frontend/desktop/dist/assets/index-BdrAHTOb.js', 'utf8');

// Find function or JSX where teamComp or guidelines are rendered
const idx = code.indexOf('teamComp.guidelines');
if (idx !== -1) {
  console.log('--- COMPONENT NEAR teamComp.guidelines ---');
  console.log(code.substring(Math.max(0, idx - 800), Math.min(code.length, idx + 1500)));
}

const idx2 = code.indexOf('"team_comp"');
if (idx2 !== -1) {
  console.log('--- OCCURRENCE OF "team_comp" ---');
  console.log(code.substring(Math.max(0, idx2 - 500), Math.min(code.length, idx2 + 1000)));
}
