// Storage security rules tests. Requires the Storage emulator (Java 21+):
//   cd tests/rules && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ort-rules',
    storage: {
      rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

const MB = 1024 * 1024;
const bytes = (n) => new Uint8Array(n);

function storage(uid, claims = {}) {
  return uid ? env.authenticatedContext(uid, claims).storage() : env.unauthenticatedContext().storage();
}

function put(st, path, size, contentType) {
  return uploadBytes(ref(st, path), bytes(size), { contentType });
}

describe('exam_media / lesson_media', () => {
  it('content roles upload images, PDFs and videos within limits', async () => {
    for (const role of ['super_admin', 'content_manager', 'methodologist']) {
      const st = storage(`u_${role}`, { role });
      await assertSucceeds(put(st, `exam_media/q1/${role}.png`, 100, 'image/png'));
      await assertSucceeds(put(st, `lesson_media/l1/${role}.pdf`, 10 * MB, 'application/pdf'));
    }
    await assertSucceeds(put(storage('cm', { role: 'content_manager' }), 'lesson_media/l1/v.mp4', 50 * MB, 'video/mp4'));
  });

  it('rejects students, other roles, oversize files and SVG', async () => {
    await assertFails(put(storage('alice'), 'exam_media/q1/a.png', 100, 'image/png'));
    await assertFails(put(storage('mod', { role: 'moderator' }), 'exam_media/q1/a.png', 100, 'image/png'));
    const cm = storage('cm', { role: 'content_manager' });
    await assertFails(put(cm, 'exam_media/q1/big.png', 6 * MB, 'image/png'));
    await assertFails(put(cm, 'exam_media/q1/big.pdf', 21 * MB, 'application/pdf'));
    await assertFails(put(cm, 'exam_media/q1/x.svg', 100, 'image/svg+xml'));
    await assertFails(put(cm, 'exam_media/q1/x.exe', 100, 'application/octet-stream'));
  });

  it('signed-in users read; anonymous users do not; content roles delete', async () => {
    const cm = storage('cm', { role: 'content_manager' });
    await assertSucceeds(put(cm, 'exam_media/q2/a.png', 100, 'image/png'));
    await assertSucceeds(getBytes(ref(storage('alice'), 'exam_media/q2/a.png')));
    await assertFails(getBytes(ref(storage(null), 'exam_media/q2/a.png')));
    await assertFails(deleteObject(ref(storage('alice'), 'exam_media/q2/a.png')));
    await assertSucceeds(deleteObject(ref(cm, 'exam_media/q2/a.png')));
  });
});

describe('user files', () => {
  it('avatars: owner uploads images <= 5 MB and may delete them', async () => {
    const a = storage('alice');
    await assertSucceeds(put(a, 'user_avatars/alice/me.jpg', 1000, 'image/jpeg'));
    await assertFails(put(a, 'user_avatars/bob/me.jpg', 1000, 'image/jpeg'));
    await assertFails(put(a, 'user_avatars/alice/big.jpg', 6 * MB, 'image/jpeg'));
    await assertSucceeds(deleteObject(ref(a, 'user_avatars/alice/me.jpg')));
  });

  it('temp_uploads accepts images only, <= 5 MB', async () => {
    const a = storage('alice');
    await assertSucceeds(put(a, 'temp_uploads/alice/x.png', 1000, 'image/png'));
    await assertFails(put(a, 'temp_uploads/alice/x.mp4', 1000, 'video/mp4'));
    await assertFails(put(a, 'temp_uploads/alice/x.png', 6 * MB, 'image/png'));
    await assertFails(getBytes(ref(storage('bob'), 'temp_uploads/alice/x.png')));
    await assertSucceeds(deleteObject(ref(a, 'temp_uploads/alice/x.png')));
  });

  it('everything else is denied', async () => {
    await assertFails(put(storage('alice'), 'random/x.png', 10, 'image/png'));
  });
});
