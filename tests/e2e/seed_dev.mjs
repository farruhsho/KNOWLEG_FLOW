// Seeds the running Firebase emulators (project demo-ort-e2e) for local
// development and manual UI testing:
//   firebase emulators:start --project demo-ort-e2e   (Java 21)
//   node seed_dev.mjs
//   flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=BILLING_MODE=external
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { blueprints, seedExamBase, seedLearning, seedVariant } from './seed_lib.mjs';

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

const db = getFirestore(initializeApp({ projectId: 'demo-ort-e2e' }));
const bp = (id) => blueprints.find((b) => b.id === id);

await seedExamBase(db);
await seedVariant(db, bp('ort_main_2026'), 'dev_main_ru_1', 'ru', 1);
await seedVariant(db, bp('ort_main_2026'), 'dev_main_ky_1', 'ky', 1);
await seedVariant(db, bp('ort_subject_chemistry_2026'), 'dev_chem_ru_1', 'ru', 1);
await seedVariant(db, bp('ort_state_language_2026'), 'dev_state_ky_1', 'ky', 1);
await seedLearning(db);
console.log('seeded: blueprints, 4 published variants, pricing, subjects, a lesson, practice questions');
