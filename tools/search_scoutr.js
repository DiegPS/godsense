const fs = require('fs');
const path = require('path');
const dir = 'C:/Users/dpahu/Desktop/GodSense/build/scoutr_extracted';

function search(d) {
  const list = fs.readdirSync(d);
  for (const item of list) {
    const full = path.join(d, item);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) {
      search(full);
    } else if (full.endsWith('.js') || full.endsWith('.json')) {
      const content = fs.readFileSync(full, 'utf8');
      if (/team_comp|teamComp|TeamComp|identity.*guidelines|matchup_info|gold_chart/i.test(content)) {
        console.log('Match found in:', full);
      }
    }
  }
}
search(dir);
