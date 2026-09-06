const fs = require('fs');
const x = fs.readFileSync(process.argv[2], 'utf8');
const idx = x.indexOf('w14:paraId="DP0001"');
if (idx < 0) {
  console.log('DP0001 not found');
  process.exit(1);
}
const start = x.lastIndexOf('<w:tr>', idx);
const end = x.indexOf('</w:tr>', idx) + 7;
const row = x.slice(start, end);
const cells = row.match(/<w:tc>[\s\S]*?<\/w:tc>/g) || [];
const labels = ['name', 'planned', 'actual', 'note'];
cells.forEach((cell, i) => {
  const texts = [...cell.matchAll(/<w:t[^>]*>([^<]*)<\/w:t>/g)].map((m) => m[1]).filter((t) => t.trim());
  console.log('---', labels[i] || i, 'count', texts.length);
  texts.forEach((t) => console.log(t));
});
