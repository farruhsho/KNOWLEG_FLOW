// Copies the canonical data files the functions need at runtime into lib/data:
// - ../assets/data/exam_blueprints.json (the same file the Flutter client
//   bundles): offline fallback when exam_blueprints/{id} is missing in Firestore;
// - ../assets/data/kg_regions.json: region ids for the regional leagues and the
//   `region` audience of adminSendNotification (ARCHITECTURE §9);
// - ../content/matrix/*.json -> lib/data/matrix/: the topic matrices the fresh
//   variant assembly needs (ARCHITECTURE §10.1, examStart mode 'fresh').
// Fails loudly if a source is missing: never deploy without them.
import { copyFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const srcDir = path.resolve(here, '..', '..', 'assets', 'data');
const dstDir = path.resolve(here, '..', 'lib', 'data');
mkdirSync(dstDir, { recursive: true });
for (const name of ['exam_blueprints.json', 'kg_regions.json']) {
  const src = path.join(srcDir, name);
  if (!existsSync(src)) {
    console.error(`copy-assets: missing ${src}`);
    process.exit(1);
  }
  copyFileSync(src, path.join(dstDir, name));
  console.log(`copy-assets: ${name} -> lib/data/`);
}

const matrixSrc = path.resolve(here, '..', '..', 'content', 'matrix');
const matrixDst = path.join(dstDir, 'matrix');
const matrices = existsSync(matrixSrc) ? readdirSync(matrixSrc).filter((f) => f.endsWith('.json')) : [];
if (matrices.length === 0) {
  console.error(`copy-assets: no topic matrices in ${matrixSrc}`);
  process.exit(1);
}
mkdirSync(matrixDst, { recursive: true });
for (const name of matrices) copyFileSync(path.join(matrixSrc, name), path.join(matrixDst, name));
console.log(`copy-assets: ${matrices.length} topic matrices -> lib/data/matrix/`);
