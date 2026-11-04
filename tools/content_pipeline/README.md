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
  never deletes.
* `gen_blueprints_2026.js` regenerates `assets/data/exam_blueprints.json`.
