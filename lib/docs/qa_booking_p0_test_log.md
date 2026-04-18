# Booking P0 QA Test Log

## Test Run Info
- Date:
- Tester:
- App build/version:
- Firebase project/environment:
- Device(s):
- Doctor ID used:
- Date used (`yyyy-MM-dd`):
- Time slot used:

## Firestore Keys Used
- Counter doc: `counters/tickets_{doctorId}_{date}`
- Slot lock doc: `slot_locks/{doctorId}_{date}_{sanitized_timeSlot}`

## Scenario Results
| ID | Scenario | Steps (short) | Expected Result | Actual Result | Status (PASS/FAIL) | Evidence (doc IDs/screenshots) |
|---|---|---|---|---|---|---|
| S1 | Concurrent same-slot booking | Two users submit same slot at once | Exactly one success, one blocked; one active appointment for slot; one slot lock; `activeCount` +1 once |  |  |  |
| S2 | Payment abandoned/failed | Create paid booking, close/fail payment | Appointment deleted; slot lock deleted; `activeCount` -1; `lastTicket` unchanged (monotonic) |  |  |  |
| S3 | Patient cancel | Cancel from appointment details/actions | Appointment `status=cancelled`; lock removed; `activeCount` -1; queue reindexed |  |  |  |
| S4 | Reschedule flow | Book new slot with `appointmentIdToCancel` path | Old appointment cancelled + old lock removed; new appointment active + new lock exists; counter consistent |  |  |  |
| S5 | Auto-cancel unpaid timeout | Let pending payment expire | `status=cancelled`, `paymentStatus=expired`; lock removed; `activeCount` -1; queue recalculated |  |  |  |
| S6 | Verification voided | Simulate/trigger voided verification | Same as timeout cancel path; no orphan lock/counter drift |  |  |  |
| S7 | Confirmed status occupancy | Move appointment to `confirmed`, retry same slot | New booking is blocked for that slot |  |  |  |
| S8 | No-show path | Auto/manual no-show transition | Lock removed; `activeCount` decremented; queue recalculated |  |  |  |
| S9 | Completed path | Move waiting/in-progress to completed | Lock removed; `activeCount` decremented; queue recalculated |  |  |  |

## Quick Firestore Verification
### A) `appointments`
- Active statuses checked: `waiting`, `confirmed`, `in-progress`
- Count of active docs for doctor/date:
- Any duplicate active docs on same slot? (Yes/No):

### B) `slot_locks`
- Expected active lock doc exists for active appointment? (Yes/No):
- Any orphan lock docs after cancel/expire/complete/no-show? (Yes/No):

### C) `counters/tickets_{doctorId}_{date}`
- `lastTicket` value:
- `activeCount` value:
- Active appointment count equals `activeCount`? (Yes/No):

## Defects / Notes
| Defect ID | Severity | Scenario ID | Description | Reproducible? | Owner | Status |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

## Final Sign-off
- P0 booking race fix validated: Yes / No
- Slot lock lifecycle validated: Yes / No
- Counter consistency validated: Yes / No
- Ready for merge/release: Yes / No
