// Removes the compiled output so stale files never ship.
import { rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
rmSync(path.join(here, '..', 'lib'), { recursive: true, force: true });
