// Copies the canonical data files the functions need at runtime from
// ../assets/data (the same files the Flutter client bundles) into lib/data:
// - exam_blueprints.json: offline fallback when exam_blueprints/{id} is
//   missing in Firestore;
// - kg_regions.json: region ids for the regional leagues and the `region`
//   audience of adminSendNotification (ARCHITECTURE §9).
// Fails loudly if a source is missing: never deploy without them.
import { copyFileSync, mkdirSync, existsSync } from 'node:fs';
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
