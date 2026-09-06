const fs = require('fs');
const x = fs.readFileSync(process.argv[2], 'utf8');
const m = x.match(/<w:tbl>[\s\S]*?Table3[\s\S]*?<\/w:tbl>/);
if (!m) {
  console.log('no table');
  process.exit(1);
}
const tbl = m[0];
const rows = tbl.match(/<w:tr>[\s\S]*?<\/w:tr>/g) || [];
console.log('total rows', rows.length);
rows.forEach((r, idx) => {
  const ids = [...r.matchAll(/w14:paraId="([^"]+)"/g)].map((m) => m[1]);
  const texts = [...r.matchAll(/<w:t[^>]*>([^<]*)<\/w:t>/g)].map((m) => m[1]).filter(Boolean);
  console.log('--- row', idx, 'paraIds', ids.length, 'first id', ids[0], 'texts', texts.slice(0, 4));
});
