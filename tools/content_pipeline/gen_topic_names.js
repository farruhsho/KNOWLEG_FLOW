// Exports display names of curriculum subjects/topics/subtopics for the app:
// content/curriculum/topics.json -> assets/data/topic_names.json. Run from repo root.
const fs = require('fs');
const src = JSON.parse(fs.readFileSync('content/curriculum/topics.json', 'utf8'));
const names = {};
const put = (id, title) => { if (id && title) names[id] = { ru: title.ru, ky: title.ky, en: title.en }; };
for (const s of src.subjects) {
  put(s.id, s.title);
  for (const t of s.topics || []) {
    put(t.id, t.title);
    for (const st of t.subtopics || []) put(st.id, st.title);
  }
}
fs.writeFileSync('assets/data/topic_names.json', JSON.stringify({ schema_version: 1, source: 'content/curriculum/topics.json', names }, null, 1) + '\n');
console.log(`${Object.keys(names).length} names`);
