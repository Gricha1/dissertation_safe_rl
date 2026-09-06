const fs = require('fs');
const paths = [
  ['orig', 'c:/Grisha/mipt/asp/disser/dissertation/diplom_final/tools/_ip_edit/_cmp_orig/word/document.xml'],
  ['fixed', 'c:/Grisha/mipt/asp/disser/dissertation/diplom_final/tools/_ip_edit/_cmp_fixed/word/document.xml'],
];
for (const [name, p] of paths) {
  const x = fs.readFileSync(p, 'utf8');
  console.log(name, 'len', x.length);
  console.log('  tables', (x.match(/<w:tbl>/g) || []).length);
  console.log('  ПАМЯТКА', x.includes('ПАМЯТКА'));
  console.log('  signatures', x.includes('Горбов'));
  console.log('  obosnovanie', x.includes('актуальность'));
  console.log('  kafedra', x.includes('фундаментальных методов'));
  console.log('  qr', x.includes('mipt.ru/aspirantura'));
  const m = x.match(/<w:tbl>[\s\S]*?Table3[\s\S]*?<\/w:tbl>/);
  if (m) {
    const rows = m[0].match(/<w:tr>/g) || [];
    console.log('  Table3 rows in chunk', rows.length);
  }
  const idx = x.indexOf('w14:paraId="000000C0"');
  if (idx > 0) {
    const start = x.lastIndexOf('<w:tr>', idx);
    const end = x.indexOf('</w:tr>', idx) + 7;
    console.log('  data row len', end - start);
  }
  const idx2 = x.indexOf('w14:paraId="DP0001"');
  console.log('  DP0001', idx2 > 0);
}
