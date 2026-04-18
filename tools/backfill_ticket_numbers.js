const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();
const docId = admin.firestore.FieldPath.documentId();

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const collections = args.filter((a) => a !== '--dry-run');
const targets = collections.length ? collections : ['appointments', 'queue_entries'];

function parseTicketNumber(raw) {
  if (typeof raw === 'number' && Number.isFinite(raw)) return Math.trunc(raw);
  if (typeof raw !== 'string') return null;

  const v = raw.trim();
  if (!v) return null;

  if (/^\d+$/.test(v)) return parseInt(v, 10);

  const noPrefix = v.toUpperCase().startsWith('T-') ? v.slice(2) : v;
  if (/^\d+$/.test(noPrefix)) return parseInt(noPrefix, 10);

  const digits = v.replace(/[^\d]/g, '');
  if (!digits) return null;
  return parseInt(digits, 10);
}

async function migrateCollection(name) {
  let scanned = 0;
  let toUpdate = 0;
  let skipped = 0;
  let lastDoc = null;

  while (true) {
    let q = db.collection(name).orderBy(docId).limit(400);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    let writes = 0;

    for (const d of snap.docs) {
      scanned++;
      const raw = d.get('ticketNumber');

      if (typeof raw === 'number' && Number.isFinite(raw)) continue;

      const parsed = parseTicketNumber(raw);
      if (parsed === null) {
        skipped++;
        continue;
      }

      toUpdate++;
      if (!dryRun) {
        batch.update(d.ref, { ticketNumber: parsed });
        writes++;
      }
    }

    if (!dryRun && writes > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  return { scanned, toUpdate, skipped };
}

(async () => {
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'WRITE'}`);
  console.log(`Collections: ${targets.join(', ')}`);

  for (const c of targets) {
    const r = await migrateCollection(c);
    console.log(`[${c}] scanned=${r.scanned}, toUpdate=${r.toUpdate}, skipped=${r.skipped}`);
  }

  console.log('Done.');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
