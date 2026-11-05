// Creates a local super_admin on the Auth emulator for manual CMS testing.
// Credentials are emulator-only (demo-ort-e2e): admin.dev@example.test / Admin-Dev-Passw0rd
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
const app = initializeApp({ projectId: 'demo-ort-e2e' });
const email = 'admin.dev@example.test';
let user;
try { user = await getAuth(app).getUserByEmail(email); }
catch { user = await getAuth(app).createUser({ email, password: 'Admin-Dev-Passw0rd', displayName: 'Dev Admin', emailVerified: true }); }
await getAuth(app).setCustomUserClaims(user.uid, { role: 'super_admin' });
await getFirestore(app).doc(`users/${user.uid}`).set({ name: 'Dev Admin', email, admin_role: 'super_admin' }, { merge: true });
console.log('super_admin ready:', email);
