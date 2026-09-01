const fs = require('fs');
const path = require('path');

const asarPath = 'C:/Users/dpahu/AppData/Local/Programs/@frontendshell/resources/app.asar';
if (!fs.existsSync(asarPath)) {
  console.error('app.asar not found at', asarPath);
  process.exit(1);
}

const fd = fs.openSync(asarPath, 'r');
const buf = Buffer.alloc(16);
fs.readSync(fd, buf, 0, 16, 0);

const headerJsonSize = buf.readUInt32LE(12);

const jsonBuf = Buffer.alloc(headerJsonSize);
fs.readSync(fd, jsonBuf, 0, headerJsonSize, 16);
const header = JSON.parse(jsonBuf.toString('utf8'));

const outDir = 'C:/Users/dpahu/Desktop/GodSense/build/scoutr_extracted';
fs.mkdirSync(outDir, {recursive: true});

const files = [];
function walk(obj, curPath='') {
  if (obj.files) {
    for (const [k, v] of Object.entries(obj.files)) {
      walk(v, curPath ? curPath + '/' + k : k);
    }
  } else {
    files.push({path: curPath, size: obj.size, offset: obj.offset});
  }
}
walk(header);
console.log('Total files found in asar:', files.length);

const baseOffset = 16n + BigInt(headerJsonSize);
for (const file of files) {
  if (file.path.endsWith('.js') || file.path.endsWith('.json') || file.path.endsWith('.html') || file.path.endsWith('.css')) {
    const target = path.join(outDir, file.path);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    const fileBuf = Buffer.alloc(file.size);
    fs.readSync(fd, fileBuf, 0, file.size, Number(baseOffset + BigInt(file.offset)));
    fs.writeFileSync(target, fileBuf);
  }
}
console.log('Finished extracting text/code files to', outDir);
