# MediQueue Project Status

Updated: March 26, 2026

## 1) Current Production Reality

- Core app flow is stable and running.
- Queue architecture is now appointment-first with a sanitized public queue view.
- Firestore rules and indexes are deployed from this repo.
- Online card payment is intentionally paused by feature flag:
  - Active production payment path is `pay_at_hospital`.
- Online payment code is retained for future Blaze upgrade and server-side confirmation rollout.

## 2) Stack

| Area | Technology |
|---|---|
| Frontend | Flutter |
| State | Provider |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Notifications | Firebase Messaging (base integration) |

## 3) Implemented Architecture

### 3.1 Main Collections

#### `users`
- Role-based user docs (`patient`, `doctor`, `receptionist`, `admin`)
- Supports `accountStatus` gating and profile fields

#### `doctors`
- Schedule, availability, queue behavior parameters
- Fields used by queue logic: `avgConsultationTime`, `noShowRate`, `graceMinutes`, `currentState`

#### `appointments`
- Source of truth for booking, queue state, and payment state
- Core queue statuses:
  - `waiting`
  - `in-progress`
  - `completed`
  - `cancelled`
  - `no-show`
- Core payment statuses:
  - `pending`
  - `paid`
  - `pay_at_hospital`
  - `expired`
  - `failed`

#### `counters`
- Per doctor/date active ticket counters

#### `slot_locks`
- Slot reservation consistency for booking/cancel flows

### 3.2 Sanitized Public Queue View

#### `queue_public/{doctorId_date}`
Parent metadata document:
- `doctorId`
- `date`
- `updatedAt`

Subcollection:
- `queue_public/{doctorId_date}/entries/{appointmentId}`

Entry fields (sanitized):
- `appointmentId`
- `doctorId`
- `date`
- `timeSlot`
- `status` (`waiting` or `in-progress`)
- `ticketNumber`
- `priority`
- `patientsAhead` (0-based count)
- `queuePosition` (1-based display position)
- `estimatedWaitTime`
- `updatedAt`

This collection is used by patient queue timeline UI so it does not need to query other patients' private appointment docs.

## 4) App Behavior (Patient Side)

### Home Tab
- Reads upcoming appointment from `appointments`.

### Queue Tab
- Loads the signed-in patient's active appointment (`waiting` / `in-progress`).
- Loads timeline from `queue_public/{doctorId_date}/entries`.
- Applies payment gate when appointment payment is `pending` or `expired`.
- In current mode, user continues with `pay_at_hospital`.

### Appointments Tab
- Upcoming / Completed / Cancelled segmentation from `appointments`.
- Payment badges remain active.
- Online pay actions are feature-gated off in current production mode.

### Appointment Details
- Full appointment details and status stream.
- Payment card supports hospital flow now and keeps online hooks for future re-enable.

## 5) Service Status

### `QueueService`
- Maintains transitions and queue recalculation.
- Mirrors queue state into sanitized `queue_public` entries.
- Updates/removes public entries when status changes.
- Handles no-show logic and consistency updates.

### `BookingService`
- Creates appointments.
- Keeps queue ordering consistent.
- Syncs `queue_public` for new active appointments.

- Cancels expired unpaid pending appointments.
- Releases slot lock and decrements counters.
- Removes matching `queue_public` entry.
- Recomputes queue positions.

- Exists and is rate-limited.
- When enabled, verifies pending orders and keeps queue consistency on void/cancel outcomes.

- Online flow is retained for future deployment.

## 6) Firestore Rules and Indexes

- Repo-visible `firestore.rules` and `firestore.indexes.json` are now in place.
- Rules include explicit access and shape validation for:
  - `users`
  - `doctors`
  - `appointments`
  - `slot_locks`
  - `counters`
  - `queue_public` (metadata + entries)
- Default deny remains active for unspecified paths.

## 7) Operational Scripts

### Backfill sanitized queue view

```
node tools/backfill_public_queue_view.js --dry-run --project <project-id> --key-file "<service-account.json>"
node tools/backfill_public_queue_view.js --project <project-id> --key-file "<service-account.json>"
```

### Cleanup stale public queue docs

```
node tools/cleanup_stale_public_queue.js --dry-run --project <project-id> --key-file "<service-account.json>"
```

Optional flags:
- `--keep-empty-parents`
- `--no-repair-meta`

## 8) Validation Snapshot (Latest)

- Queue public consistency tests passed:
  - `test/services/queue_public_consistency_test.dart`
- Queue state consistency tests passed:
  - `test/services/queue_state_consistency_test.dart`
- Analyzer checks for touched queue/payment files passed in your recent runs.
- Manual app checks now show queue timeline loading from sanitized public view.

## 9) Known Gaps (Important)

1. Online payment production deployment is blocked on Spark plan limits.
   - Functions + Secret Manager need Blaze.

   - Before enabling online payments in production, move secret handling to server-only path.

3. Admin/staff and advanced dashboards still need hardening and completion for full hospital operations.

## 10) Recommended Next Steps

1. Keep production in `pay_at_hospital` mode until Blaze upgrade is feasible.
2. Rotate and remove client-exposed payment secrets before online enablement.
3. Deploy callable confirmation function after Blaze upgrade:
4. Add a scheduled maintenance run for stale `queue_public` cleanup.
5. Continue expanding receptionist/doctor/admin operational workflows.
