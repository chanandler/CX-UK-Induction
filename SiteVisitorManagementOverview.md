# CX UK Induction App - Functional Overview

## Purpose
The **CX UK Induction** app is an on-site reception and safety system for CEMEX UK HQ.  
It is designed to:
- register and induct visitors,
- manage vehicle-blocking pager workflows,
- support emergency roll call operations,
- provide controlled access to management features,
- and maintain recoverable operational records through export/backup/import.

The app is built with **SwiftUI** and **SwiftData** and runs fully on-device.

## Main Screen Layout
The main screen is the operational hub:
- **Header**: branded welcome area.
- **Visitor form**: first name, last name, company, visiting, badge number, optional car registration.
- **Primary action**: `Register`.
- **Secondary flows**:
  - `Pre-registered? Tap here`
  - `Returning Visitor?`
  - `I'm Leaving`
  - `Sign In Book`
- **Bottom controls**:
  - left: settings cog menu (+ fire shortcut and staff car-pager issue button),
  - right: dedicated pager-return button.

## Core Visitor Registration Flow
1. User enters required fields.
2. User taps `Register`.
3. If car registration is present, app asks: **Have you blocked a car in?**
4. If `Yes`, app forces pager selection from available pagers.
5. Visitor completes induction pages and signature confirmation.
6. App creates an active `Visitor` record (check-in time set, check-out empty).
7. Confirmation alert is shown.

### Validation Rules
- Required: first name, last name, company, visiting, badge number.
- If blocked-car is true, pager selection is required.
- Whitespace-only values are treated as empty.

## Pre-Registered Visitor Flow
### Admin setup
Pre-registration entries are created in the PIN-protected admin path.

### Arrival flow
1. Tap `Pre-registered? Tap here`.
2. Select name from pre-registered list.
3. Confirmation dialog appears with two paths:
   - `I have parked on site`
   - `I have not parked, continue`
4. If parked on site:
   - enter car registration,
   - continue into normal blocked-car prompt,
   - if blocked, choose pager.
5. Visitor completes induction/signature and is signed in.
6. The consumed pre-registration entry is removed.

## Returning Visitor Flow
1. Tap `Returning Visitor?`.
2. Search by first name, last name, and/or registration number.
3. No full historical list is shown before search input.
4. Select a result.
5. Same confirmation dialog and parking branching as pre-registered flow.
6. Form is prefilled from prior record.
7. Visitor completes induction/signature and is signed in.

## Check-Out and Visitor Management
### I'm Leaving
- Search active visitors and check out directly.

### Sign In Book
- Shows active and archived records.
- Supports check-out actions from active list.

### Active/Archived Tabs
- Active tab: currently signed-in visitors.
- Archived tab: signed-out visitors.
- Includes search and CSV export capability for archived data.

## Emergency Roll Call Flow
`Fire Alarm Roll Call` provides emergency accounting:
- For each person, `Confirm Out` marks them as left.
- Button then toggles to `Sign Back In` to restore active status quickly without full re-registration.

## Pager Management Flows
## Visitor pager assignment
- Triggered from visitor registration when blocked-car applies.
- Only available pagers can be selected.

## Staff car-pager issue (non-sign-in staff)
- Bottom `car` icon opens staff pager issue sheet.
- Captures: first name, last name, car registration, pager number.
- Issues are persisted as staff pager records.

## Pager return flow
- Bottom-right pager icon opens return sheet.
- Displays currently issued staff pagers.
- `Mark Returned` closes the issue and frees the pager.

## Pager Availability Logic
A pager is treated as unavailable if it is:
- assigned to an active visitor, or
- assigned to an active staff pager issue.

This prevents duplicate assignment across visitor and staff workflows.

## Security and Protected Access
PIN-protected actions include management-sensitive paths such as:
- settings,
- CSV export,
- sign-in book access,
- roll call,
- analytics,
- pre-registration administration.

A PIN session timeout is used so protected actions are re-gated after inactivity.

## Analytics
The analytics dashboard provides:
- range-based metrics (day/week/month),
- visitor totals and unique/repeat counts,
- active-now and average-visit duration,
- auto-checkout rate,
- pre-registered rate,
- trend charts and top company/host views.

## Data Persistence and Recovery
## Stored entities
- `Visitor`
- `PreRegisteredVisitor`
- `StaffPagerIssue`

## Export/Import/Backup
- CSV export for reporting and operational handoff.
- CSV import with preview (import/skipped/failed counts).
- Duplicate-aware import behavior.
- Automatic daily backups plus manual backup trigger.

## Auto-Checkout Behavior
- Scheduled auto-checkout can be enabled and timed from settings.
- At scheduled time, active visitors are checked out automatically.
- Separate catch-up behavior exists for launch scenarios.

## Summary
The app functions as a complete reception operations workflow:
- guided registration and induction,
- safety-first parking/pager handling,
- rapid pre-registered and returning-visitor intake,
- emergency accountability tools,
- protected administrative control,
- and resilient data export/backup/restore.
