# UI Guidelines

## Purpose
This document captures the current UI and UX standards for MediQueue so new screens and edits stay visually and behaviorally consistent.

## Core Principles
- Prefer clarity over decoration.
- Use semantic colors for meaning, not random accents.
- Keep interaction copy short, calm, and user-friendly.
- Use consistent action hierarchy in dialogs and buttons.
- Preserve accessible tap targets and readable text sizes.

## Color System
Use `AppColors` as the single source of truth.

- Brand
  - `primary` (`#00674F`) for primary actions and app headers.
  - `primaryDark` for stronger surfaces (for example snackbar background).
  - `primaryLight` for subtle branded backgrounds.
- Semantic
  - `success` for successful states and confirmed actions.
  - `warning` for waiting, caution, or time-sensitive states.
  - `error` for destructive actions and failures.
  - `info` for informational status (for example in-progress).
- Neutrals
  - `textPrimary`, `textSecondary`, `background`, `cardBackground`, `divider`.
- Status and payment maps
  - Queue: waiting -> warning, in-progress -> info, completed -> success, cancelled -> error, no-show -> `statusNoShow`.
  - Payment: paid -> success, pending -> warning, expired -> error, pay_at_hospital -> info.

For badges/chips, use `AppColors.statusSurface(color)` and `AppColors.statusBorder(color)` instead of hardcoded alpha values.

## Theme Usage
Use `AppTheme.light` from `lib/utils/app_theme.dart` through `MaterialApp.theme`.

Theme defaults already cover:
- `AppBarTheme`
- `DialogTheme`
- `SnackBarTheme`
- `ElevatedButtonTheme`
- `OutlinedButtonTheme`
- `TextButtonTheme`
- `ChipTheme`
- `InputDecorationTheme`
- `DividerTheme`

Avoid redefining these styles unless the screen has a strong reason to differ.

## Interaction Patterns

### Dialog Action Hierarchy
- Non-destructive secondary action: `OutlinedButton` (usually `Cancel` or `Keep ...`).
- Destructive primary action: `ElevatedButton` with `AppColors.error` and `AppColors.onError`.
- Confirmation question format:
  - `Are you sure you want to ...?`

### Snackbar Tone
- Success: short and direct.
  - Example: `Appointment cancelled.`
- Error: no technical details for users.
  - Example: `Could not update doctor. Please try again.`
- Avoid raw backend text and stack/error dumps.

### Status Labels
Use normalized labels in UI text:
- `No Show`
- `In Progress`
- `Checked In`
- `Not Checked In`
- `Pay at Hospital`
- `Cancelled`

Avoid mixed variants such as `No-Show`, `no-show`, `Not arrived`, or `Canceled`.

## Typography and Spacing
- Keep body copy in sentence case.
- Prefer readable small text at `11` or above where possible.
- Maintain touch targets:
  - Main buttons >= `44dp` height.
  - Chips/filter controls >= `40dp` height.

## Copywriting Rules
- Use plain language.
- Keep punctuation consistent (end short statements with a period).
- Do not use emojis in system copy.
- Avoid shouting or excessive urgency unless safety-critical.

Recommended patterns:
- Success: `<Action> completed.`
- Error: `Could not <action>. Please try again.`
- Empty state: `No <items> found` or `Could not load <items>`.

## Quick Review Checklist
Before merging a UI change, verify:
- Colors come from `AppColors`.
- Generic component styles rely on `AppTheme.light`.
- Dialog action order and hierarchy are consistent.
- Snackbars follow success/error tone patterns.
- Status wording matches standard labels.
- No raw error strings are exposed to users.
- Tap targets and small labels remain readable.
