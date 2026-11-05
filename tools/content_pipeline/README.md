# ORT content pipeline

Offline Node 22 + TypeScript CLI that builds original ORT 2026 practice
content: topic matrix → generation → blind verification → translation
check → dedup → assembly by blueprint → timing → validation → Firestore
import → readiness registry. Full guide (Russian):
[`docs/modernization/CONTENT_PIPELINE.md`](../../docs/modernization/CONTENT_PIPELINE.md).

```bash
npm install
npm run typecheck
npm test
npm run cli -- help
```

* Paid stages (`generate`, `verify`, `translate-check --api`) never call the
  API without `--i-understand-this-costs-money`; the key comes only from the
  operator's `ANTHROPIC_API_KEY`.
* `import` is a dry run unless `--commit`; it writes in batches of ≤ 400 and
  never deletes. It never changes the status of a variant that already exists
  in Firestore, never overwrites documents edited in the admin panel
  (reported as `cms_conflicts`) or translation links changed there
  (`translation_links_kept`) unless `--overwrite`, takes back a question
  whose admin-panel edit is already in the bank (`cms_caught_up`: hash fields
  written, `edited_in_cms_at` deleted, content untouched), and stores
  `table.rows` as `[{cells: [...]}]` (Firestore cannot hold nested arrays).
* `gen_blueprints_2026.js` regenerates `assets/data/exam_blueprints.json`.
