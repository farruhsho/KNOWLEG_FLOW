// Copies the canonical ORT blueprints (assets/data/exam_blueprints.json, the
// same file the Flutter client bundles) into lib/data so the deployed
// functions have an offline fallback when exam_blueprints/{id} is missing in
// Firestore. Fails loudly if the source is missing: never deploy without it.
import { copyFileSync, mkdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = path.resolve(here, '..', '..', 'assets', 'data', 'exam_blueprints.json');
const dstDir = path.resolve(here, '..', 'lib', 'data');
if (!existsSync(src)) {
  console.error(`copy-assets: missing ${src}`);
  process.exit(1);
}
mkdirSync(dstDir, { recursive: true });
copyFileSync(src, path.join(dstDir, 'exam_blueprints.json'));
console.log('copy-assets: exam_blueprints.json -> lib/data/');
