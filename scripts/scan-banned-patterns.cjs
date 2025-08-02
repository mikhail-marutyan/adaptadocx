#!/usr/bin/env node
const fs   = require('node:fs');
const path = require('node:path');
const glob = require('glob');                 // standard require without destructuring

const patternsPath = path.resolve(process.cwd(), 'security', 'banned-patterns.txt');
if (!fs.existsSync(patternsPath)) {
  console.error(`banned patterns file not found → ${patternsPath}`);
  process.exit(1);
}

const patterns = fs.readFileSync(patternsPath, 'utf8')
  .split(/\r?\n/)
  .map(l => l.trim())
  .filter(l => l && !l.startsWith('#'));

const files = glob.sync('**/*.{js,ts,tsx,jsx,md}', {
  ignore: ['node_modules/**', '**/*.min.*', '**/dist/**']
});

const hits = [];
for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  for (const p of patterns) {
    if (new RegExp(p, 'u').test(src)) {
      hits.push({ file, pattern: p });
      console.log(`BANNED ${p} → ${file}`);
    }
  }
}

if (hits.length) {
  fs.mkdirSync('reports', { recursive: true });
  fs.writeFileSync(
    'reports/banned-patterns-report.txt',
    hits.map(h => `BANNED ${h.pattern} → ${h.file}`).join('\\n')
  );
  process.exit(1);
} else {
  console.log('No banned patterns found');
}
