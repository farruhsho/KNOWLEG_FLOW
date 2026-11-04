import { createHash } from 'node:crypto';

/** Lower-case hex SHA-256 of a UTF-8 string. */
export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}
