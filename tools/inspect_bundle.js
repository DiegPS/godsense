const fs = require('fs');
const code = fs.readFileSync('C:/Users/dpahu/AppData/Local/Programs/@frontendshell/resources/backend/_internal/frontend/desktop/dist/assets/index-BdrAHTOb.js', 'utf8');

// Find occurrences of team_comp, TeamComp, or panel definitions
const matches = [];
const regex = /team_comp|teamComp|TeamComp|identity|guidelines/g;
let match;
while ((match = regex.exec(code)) !== null) {
  const start = Math.max(0, match.index - 200);
  const end = Math.min(code.length, match.index + 300);
  matches.push(code.substring(start, end));
  if (matches.length > 10) break;
}

console.log('Total matches found:', matches.length);
for (let i = 0; i < matches.length; i++) {
  console.log(`--- MATCH ${i+1} ---`);
  console.log(matches[i]);
}
