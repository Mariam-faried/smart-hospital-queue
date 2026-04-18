
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
const pruneEmptyParents = !args.includes('--keep-empty-parents');
const repairParentMeta = !args.includes('--no-repair-meta');

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
const docId = admin.firestore.FieldPath.documentId();
const ACTIVE_STATUSES = new Set(['waiting', 'in-progress']);

function normalizeStatus(raw) {
  if (typeof raw !== 'string') return '';
  return raw.trim().toLowerCase().replaceAll('_', '-');
}

function parseQueueKey(key) {
  const match = key.match(/^(.*)_(\d{4}-\d{2}-\d{2})$/);
  if (!match) return null;
  return { doctorId: match[1], date: match[2] };
}
async function run() {
  console.log('Mode: ' + (dryRun ? 'DRY RUN' : 'WRITE'));
  console.log('Project: ' + projectId);
  console.log('Options: pruneEmptyParents=' + pruneEmptyParents + ', repairParentMeta=' + repairParentMeta);
  console.log('Scanning queue_public for stale entries...');

  const summary = {
    parentsScanned: 0,
    entriesScanned: 0,
    staleEntries: 0,
    validEntries: 0,
    parentMetaRepaired: 0,
    emptyParentsPruned: 0,
  };

  let batch = db.batch();
  let pendingWrites = 0;

  async function flushBatch() {
    if (!dryRun && pendingWrites > 0) {
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    }
  }

  async function enqueueDelete(ref) {
    if (!dryRun) {
      batch.delete(ref);
      pendingWrites++;
      if (pendingWrites >= 350) await flushBatch();
    }
  }

  async function enqueueSet(ref, data) {
    if (!dryRun) {
      batch.set(ref, data, { merge: true });
      pendingWrites++;
      if (pendingWrites >= 350) await flushBatch();
    }
  }

  let lastDoc = null;
  while (true) {
    let query = db.collection('queue_public').orderBy(docId).limit(120);
    if (lastDoc) query = query.startAfter(lastDoc);

    const parentSnap = await query.get();
    if (parentSnap.empty) break;

    for (const parentDoc of parentSnap.docs) {
      summary.parentsScanned++;
      const parentRef = parentDoc.ref;
      const parentData = parentDoc.data() || {};
      const parsedFromKey = parseQueueKey(parentDoc.id);
      const parentDoctor =
        typeof parentData.doctorId === 'string' && parentData.doctorId.trim()
          ? parentData.doctorId.trim()
          : parsedFromKey?.doctorId || null;
      const parentDate =
        typeof parentData.date === 'string' && parentData.date.trim()
          ? parentData.date.trim()
          : parsedFromKey?.date || null;

      if (repairParentMeta && parentDoctor && parentDate) {
        const needsRepair =
          parentData.doctorId !== parentDoctor || parentData.date !== parentDate;
        if (needsRepair) {
          summary.parentMetaRepaired++;
          await enqueueSet(parentRef, {
            doctorId: parentDoctor,
            date: parentDate,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      const entriesSnap = await parentRef.collection('entries').get();
      let validEntriesInParent = 0;

      for (const entryDoc of entriesSnap.docs) {
        summary.entriesScanned++;
        const entryData = entryDoc.data() || {};
        const appointmentId =
          typeof entryData.appointmentId === 'string' && entryData.appointmentId.trim()
            ? entryData.appointmentId.trim()
            : entryDoc.id;

        const appointmentSnap = await db
          .collection('appointments')
          .doc(appointmentId)
          .get();

        let staleReason = null;
        if (!appointmentSnap.exists) {
          staleReason = 'appointment_missing';
        } else {
          const appt = appointmentSnap.data() || {};
          const apptStatus = normalizeStatus(appt.status);
          if (!ACTIVE_STATUSES.has(apptStatus)) {
            staleReason = 'appointment_inactive';
          } else {
            const apptDoctor = typeof appt.doctorId === 'string' ? appt.doctorId : '';
            const apptDate = typeof appt.date === 'string' ? appt.date : '';
            const entryDoctor = typeof entryData.doctorId === 'string' ? entryData.doctorId : '';
            const entryDate = typeof entryData.date === 'string' ? entryData.date : '';
            const entryStatus = normalizeStatus(entryData.status);

            if (parentDoctor && apptDoctor && apptDoctor !== parentDoctor) {
              staleReason = 'doctor_mismatch';
            } else if (parentDate && apptDate && apptDate !== parentDate) {
              staleReason = 'date_mismatch';
            } else if (entryDoctor && apptDoctor && entryDoctor !== apptDoctor) {
              staleReason = 'entry_doctor_mismatch';
            } else if (entryDate && apptDate && entryDate !== apptDate) {
              staleReason = 'entry_date_mismatch';
            } else if (entryStatus && !ACTIVE_STATUSES.has(entryStatus)) {
              staleReason = 'entry_inactive';
            }
          }
        }

        if (staleReason) {
          summary.staleEntries++;
          await enqueueDelete(entryDoc.ref);
          console.log('STALE: ' + entryDoc.ref.path + ' reason=' + staleReason);
        } else {
          summary.validEntries++;
          validEntriesInParent++;
        }
      }

      if (pruneEmptyParents && validEntriesInParent == 0) {
        summary.emptyParentsPruned++;
        await enqueueDelete(parentRef);
      }
    }

    lastDoc = parentSnap.docs[parentSnap.docs.length - 1];
  }

  await flushBatch();

  console.log('Done.');
  console.log(JSON.stringify(summary, null, 2));
}

run().catch((error) => {
  console.error(error);
  console.error(
    'Hint: provide --key-file <service-account.json> or configure application default credentials.',
  );
  process.exit(1);
});
