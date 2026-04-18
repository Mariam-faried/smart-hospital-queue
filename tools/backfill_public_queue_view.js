let admin;
try {
  admin = require('firebase-admin');
} catch (_) {
  admin = require('../functions/node_modules/firebase-admin');
}
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

function getArgValue(name) {
  const index = args.indexOf(name);
  if (index >= 0 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}

const projectId =
  getArgValue('--project') ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_PROJECT_ID ||
  'smart-hospital-queue-ace7d';

const keyFileArg =
  getArgValue('--key-file') || process.env.GOOGLE_APPLICATION_CREDENTIALS;

let appOptions;
if (keyFileArg) {
  const resolvedKeyPath = path.resolve(keyFileArg);
  if (!fs.existsSync(resolvedKeyPath)) {
    throw new Error(`Service account key file not found: ${resolvedKeyPath}`);
  }
  const serviceAccount = JSON.parse(fs.readFileSync(resolvedKeyPath, 'utf8'));
  appOptions = {
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || projectId,
  };
} else {
  appOptions = {
    credential: admin.credential.applicationDefault(),
    projectId,
  };
}

admin.initializeApp(appOptions);

const db = admin.firestore();

function parseTicketNumber(raw) {
  if (typeof raw === 'number' && Number.isFinite(raw)) return Math.trunc(raw);
  if (typeof raw !== 'string') return 0;
  const value = raw.trim();
  if (!value) return 0;
  const direct = Number.parseInt(value, 10);
  if (Number.isFinite(direct)) return direct;
  const noPrefix = value.toUpperCase().startsWith('T-') ? value.slice(2) : value;
  const noPrefixNum = Number.parseInt(noPrefix, 10);
  if (Number.isFinite(noPrefixNum)) return noPrefixNum;
  const digits = value.replace(/[^\d]/g, '');
  const digitsNum = Number.parseInt(digits, 10);
  return Number.isFinite(digitsNum) ? digitsNum : 0;
}

function normalizePriority(raw) {
  const value = typeof raw === 'string' ? raw.trim().toLowerCase() : 'normal';
  if (value === 'emergency' || value === 'urgent') return value;
  return 'normal';
}

function toFiniteNumber(raw, fallback = 0) {
  if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
  if (typeof raw === 'string') {
    const parsed = Number.parseFloat(raw);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function queueKey(doctorId, date) {
  return `${doctorId}_${date}`;
}

async function run() {
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'WRITE'}`);
  console.log(`Project: ${projectId}`);
  console.log('Backfilling queue_public/*/entries from active appointments...');

  const activeStatuses = ['waiting', 'in-progress'];
  const snapshot = await db
    .collection('appointments')
    .where('status', 'in', activeStatuses)
    .get();

  if (snapshot.empty) {
    console.log('No active appointments found.');
    return;
  }

  let scanned = 0;
  let upserted = 0;
  let skipped = 0;
  let batch = db.batch();
  let writesInBatch = 0;

  for (const doc of snapshot.docs) {
    scanned++;
    const data = doc.data() || {};
    const doctorId = typeof data.doctorId === 'string' ? data.doctorId : '';
    const date = typeof data.date === 'string' ? data.date : '';
    const status = typeof data.status === 'string' ? data.status : '';

    if (!doctorId || !date || !activeStatuses.includes(status)) {
      skipped++;
      continue;
    }

    const patientsAheadRaw = data.patientsAhead;
    let patientsAhead = 0;
    if (typeof patientsAheadRaw === 'number' && Number.isFinite(patientsAheadRaw)) {
      patientsAhead = Math.trunc(patientsAheadRaw);
    } else if (typeof patientsAheadRaw === 'string') {
      const parsedAhead = Number.parseInt(patientsAheadRaw.trim(), 10);
      if (Number.isFinite(parsedAhead)) {
        patientsAhead = parsedAhead;
      }
    } else {
      // queuePosition is a 1-based display number.
      const queuePosition = Math.trunc(toFiniteNumber(data.queuePosition, 1));
      patientsAhead = queuePosition > 1 ? queuePosition - 1 : 0;
    }
    if (patientsAhead < 0) patientsAhead = 0;

    const timeSlot = typeof data.timeSlot === 'string' ? data.timeSlot : '';

    const payload = {
      appointmentId: doc.id,
      doctorId,
      date,
      timeSlot,
      status,
      ticketNumber: parseTicketNumber(data.ticketNumber),
      priority: normalizePriority(data.priority),
      patientsAhead,
      queuePosition: patientsAhead + 1,
      estimatedWaitTime: toFiniteNumber(data.estimatedWaitTime, 0),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!dryRun) {
      const metaRef = db.collection('queue_public').doc(queueKey(doctorId, date));
      batch.set(
        metaRef,
        {
          doctorId,
          date,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      writesInBatch++;

      const entryRef = db
        .collection('queue_public')
        .doc(queueKey(doctorId, date))
        .collection('entries')
        .doc(doc.id);
      batch.set(entryRef, payload, { merge: true });
      writesInBatch++;
      if (writesInBatch >= 380) {
        await batch.commit();
        batch = db.batch();
        writesInBatch = 0;
      }
    }

    upserted++;
  }

  if (!dryRun && writesInBatch > 0) {
    await batch.commit();
  }

  console.log(
    `Done. scanned=${scanned}, upserted=${upserted}, skipped=${skipped}, mode=${dryRun ? 'dry-run' : 'write'}`,
  );
}

run().catch((error) => {
  console.error(error);
  console.error(
    'Hint: run with --project smart-hospital-queue-ace7d and set GOOGLE_APPLICATION_CREDENTIALS if needed.',
  );
  process.exit(1);
});
