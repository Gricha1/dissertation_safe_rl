const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const work = __dirname;
const root = path.join(work, '..', '..');
const rows = JSON.parse(fs.readFileSync(path.join(work, 'diss_plan_rows.json'), 'utf8'));

const sourceDocx = path.join(work, 'plan_qr_moved.docx');
if (!fs.existsSync(sourceDocx)) {
  throw new Error('Missing plan_qr_moved.docx backup');
}

const unz = path.join(work, 'unzipped_restore');
if (fs.existsSync(unz)) fs.rmSync(unz, { recursive: true, force: true });
fs.mkdirSync(unz, { recursive: true });
fs.copyFileSync(sourceDocx, path.join(work, '_restore_src.zip'));
execSync(
  `powershell -NoProfile -Command "Expand-Archive -LiteralPath '${path.join(work, '_restore_src.zip')}' -DestinationPath '${unz}' -Force"`
);

const xmlPath = path.join(unz, 'word', 'document.xml');
let xml = fs.readFileSync(xmlPath, 'utf8');

const beforeLen = xml.length;
const beforeTables = (xml.match(/<w:tbl>/g) || []).length;

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function paraId(n) {
  return `DP${String(n).padStart(4, '0')}`;
}

function textParagraph(pid, text) {
  return `<w:p w:rsidR="00000000" w:rsidDel="00000000" w:rsidP="00000000" w:rsidRDefault="00000000" w:rsidRPr="00000000" w14:paraId="${pid}"><w:pPr><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:pPr><w:r w:rsidDel="00000000" w:rsidR="00000000" w:rsidRPr="00000000"><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/><w:rtl w:val="0"/></w:rPr><w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p>`;
}

function emptyParagraph(pid) {
  return `<w:p w:rsidR="00000000" w:rsidDel="00000000" w:rsidP="00000000" w:rsidRDefault="00000000" w:rsidRPr="00000000" w14:paraId="${pid}"><w:pPr><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:pPr><w:r w:rsidDel="00000000" w:rsidR="00000000" w:rsidRPr="00000000"><w:rPr><w:rtl w:val="0"/></w:rPr></w:r></w:p>`;
}

function cellParagraphs(values, startIndex) {
  return values
    .map((text, i) => (text ? textParagraph(paraId(startIndex + i), text) : emptyParagraph(paraId(startIndex + i))))
    .join('');
}

const n = rows.length;
const names = rows.map((r) => r.name);
const planned = rows.map((r) => r.planned);
const actual = rows.map((r) => r.actual);
const notes = rows.map(() => '');

const trHeight = Math.max(10616, n * 380);
const dataRow = `<w:tr><w:trPr><w:cantSplit w:val="0"/><w:trHeight w:val="${trHeight}" w:hRule="atLeast"/><w:tblHeader w:val="0"/></w:trPr><w:tc><w:tcPr/>${cellParagraphs(names, 1)}</w:tc><w:tc><w:tcPr/>${cellParagraphs(planned, 1001)}</w:tc><w:tc><w:tcPr/>${cellParagraphs(actual, 2001)}</w:tc><w:tc><w:tcPr/>${cellParagraphs(notes, 3001)}</w:tc></w:tr>`;

const marker = 'w14:paraId="000000C0"';
const idx = xml.indexOf(marker);
if (idx < 0) {
  throw new Error('Data row marker 000000C0 not found');
}
const start = xml.lastIndexOf('<w:tr>', idx);
const end = xml.indexOf('</w:tr>', idx) + 7;
if (start < 0 || end <= start) {
  throw new Error('Could not locate data row boundaries');
}

const oldRow = xml.slice(start, end);
xml = xml.slice(0, start) + dataRow + xml.slice(end);

const afterLen = xml.length;
const afterTables = (xml.match(/<w:tbl>/g) || []).length;
console.log('xml length', beforeLen, '->', afterLen, '(delta', afterLen - beforeLen, ')');
console.log('tables', beforeTables, '->', afterTables);
if (afterTables !== beforeTables) {
  throw new Error('Table count changed - aborting to avoid document damage');
}
if (!xml.includes('ПАМЯТКА') || !xml.includes('mipt.ru/aspirantura')) {
  throw new Error('Document content check failed');
}

fs.writeFileSync(xmlPath, xml, 'utf8');

const outDocx = path.join(work, 'plan_diss_table.docx');
if (fs.existsSync(outDocx)) fs.unlinkSync(outDocx);

function compressDocx(sourceDir, destFile) {
  const files = [];
  function walk(dir, base) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      const rel = path.relative(base, full).replace(/\\/g, '/');
      if (entry.isDirectory()) walk(full, base);
      else files.push({ rel, full });
    }
  }
  walk(sourceDir, sourceDir);
  const script = `
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open('${outDocx.replace(/\\/g, '\\\\')}', [System.IO.Compression.ZipArchiveMode]::Create)
try {
${files
  .map(
    (f) => `$e = $zip.CreateEntry('${f.rel}', [System.IO.Compression.CompressionLevel]::Optimal); $s = $e.Open(); try { $b = [System.IO.File]::ReadAllBytes('${f.full.replace(/\\/g, '\\\\')}'); $s.Write($b,0,$b.Length) } finally { $s.Close() }`
  )
  .join('\n')}
} finally { $zip.Dispose() }
`;
  fs.writeFileSync(path.join(work, '_zip.ps1'), script, 'utf8');
  execSync(`powershell -NoProfile -ExecutionPolicy Bypass -File "${path.join(work, '_zip.ps1')}"`, { stdio: 'inherit' });
}

compressDocx(unz, outDocx);

const loDir = 'C:\\Program Files\\LibreOffice\\program';
const outDir = path.join(work, 'lo_out_restore');
if (fs.existsSync(outDir)) fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir);
execSync(
  `"${path.join(loDir, 'soffice.exe')}" --headless --convert-to pdf --outdir "${outDir}" "${outDocx}"`,
  { cwd: loDir, stdio: 'inherit' }
);

const builtPdf = path.join(outDir, 'plan_diss_table.pdf');
const docs = path.join(root, 'Documents');
const targetDocx = fs.readFileSync(path.join(work, 'docx_path.txt'), 'utf8').trim();
const finalPdf = path.join(
  docs,
  '\u0413\u043E\u0440\u0431\u043E\u0432_\u0418\u043D\u0434\u0438\u0432\u0438\u0434\u0443\u0430\u043B\u044C\u043D\u044B\u0439_\u043F\u043B\u0430\u043D_\u0430\u0441\u043F\u0438\u0440\u0430\u043D\u0442_2026.pdf'
);

for (const [src, dst] of [
  [outDocx, targetDocx],
  [outDocx, path.join(docs, 'gorbov_individual_plan_2026.docx')],
  [builtPdf, finalPdf],
  [builtPdf, path.join(docs, 'gorbov_individual_plan_2026.pdf')],
]) {
  try {
    fs.copyFileSync(src, dst);
    console.log('copied ->', dst);
  } catch (e) {
    console.log('locked ->', dst, e.message);
  }
}
