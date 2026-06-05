# Code New Features Tracker
> Generated: 2026-04-22 | Last updated: 2026-05-29

## Feature Requests

**Implementation notes:**
- File import: use SwiftUI's `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` — no UIKit needed.
- Backup scheduling: add a second `AutoCheckoutScheduler`-style class (`BackupScheduler`) triggered at 06:00 daily, or extend `AutoCheckoutScheduler` to support multiple actions.
- CSV parsing: use `String.components(separatedBy:)` with quote-aware splitting to handle fields that contain commas (reverse of `escapedAsCSVField`).
- SwiftData insert: fetch existing records first and build a `Set` of `(firstName+lastName+checkIn)` keys for O(1) duplicate detection.

---

## Future Feature Ideas

The following 20 features are proposed to improve usability, security, and operational value of the app. Each is rated by potential impact.


### 4. 🌟 Visitor Purpose Categories (Complexity: Low)
Add a required visit-purpose selector (e.g. Contractor, Delivery, Meeting, Interview, Audit). Enables better operational reporting and downstream filtering.

### 7. 🌟 Bulk End-of-Day Check-Out (Complexity: Low)
A single-tap "End of Day — Check Out All" button in Settings (confirmation required) that calls `autoCheckoutPreviousDay` immediately for all visitors still active, regardless of check-in date. Useful at the end of a shift.

### 9. 🌟 Offline Queue with iCloud Sync (Complexity: High)
When iCloud Drive is unavailable, queue new sign-ins in a local `pending` store. When connectivity is restored, merge the queue into the main `ModelContainer`. Prevents data loss when the iPad is offline during peak arrival times.

### 10. 🌟 Visitor Frequency / Trend Tracking (Complexity: Medium)
Record visit count per unique (firstName + lastName + company) combination and surface a "Frequent Visitors" section in the Sign In Book. Flag visitors who have signed in more than N times in the last 30 days as a configurable security review threshold.

### 11. 🌟 Data Retention Controls (Complexity: Medium)
Add configurable retention windows (e.g. 30/60/90 days) for archived visitor records with optional monthly cleanup prompts.

### 12. 🌟 Audit Log / Change History (Complexity: Medium)
Persist an append-only `AuditEvent` model in SwiftData recording every create, update, and delete with a timestamp and actor (self-service / staff). Viewable in Settings as a scrollable timeline. Included in CSV backup.

### 13. 🌟 Dark Mode Optimised Theming (Complexity: Low)
Currently the app relies on `Color(.systemBackground)` which can look washed out in dark mode against the CEMEX blue. Introduce a `ColorScheme`-aware theme layer (`AppTheme`) with explicit light/dark tokens for card fills, text, and form backgrounds.

### 16. 🌟 Guided Reception Checklist (Complexity: Low)
Add optional per-visitor checklist prompts (ID seen, PPE given, NDA confirmed, host notified) before final sign-in completion.

### 17. 🌟 Analytics: Peak Arrival Heatmap (Complexity: Medium)
Add a heatmap visualization to the Analytics Dashboard showing arrivals by hour and weekday to quickly spot staffing pinch points.

### 18. 🌟 Analytics: Conversion Funnel for Pre-Registered Visitors (Complexity: Medium)
Track the stages (found → confirmed → signed in) and surface drop-off rates to identify friction in the pre-registration flow.

### 19. 🌟 UI: Large Touch Targets & Spacing Presets (Complexity: Low)
Introduce a size preset in Settings (Compact/Comfort/Large) that scales button hit areas and vertical spacing for kiosk ergonomics.

### 20. 🌟 Theme: Branded Accent & Contrast Tokens (Complexity: Low)
Extend `AppTheme` with explicit accent, warning, success, and subtle background tokens with WCAG-checked contrast for light/dark.

### 21. 🌟 UI: Form Section Headers & Inline Hints (Complexity: Low)
Group related fields with clear section headers and optional inline hint text to reduce cognitive load during sign-in.

### 22. 🌟 Optimization: SwiftData Query Caching (Complexity: Medium)
Cache common Sign In Book queries (today active, this week) and invalidate on writes to reduce recomputation and improve scrolling.

### 23. 🌟 Analytics: Repeat Visitor Cohorts (Complexity: Medium)
Add cohort charts for 7/30/90-day windows to show how many visitors return and how frequently, segmented by company.

### 24. 🌟 UI: Empty States with Actions (Complexity: Low)
Design friendly empty states (no results, no backups yet) with a short explanation and a primary action to guide the next step.

### 25. 🌟 Theme: High-Contrast Mode Overrides (Complexity: Low)
Add a high-contrast toggle that intensifies text and control colors and adds borders to cards for accessibility and low-light kiosks.

### 26. 🌟 Optimization: Image & Signature Memory Budget (Complexity: Medium)
Downscale oversized induction images on import and limit signature bitmap size, with async decoding to reduce memory spikes.

### 27. 🌟 Analytics: Dwell Time Estimates (Complexity: Medium)
Compute and graph median dwell time (check-in to check-out) per purpose category to inform security and reception planning.

### 28. 🌟 UI: Settings Search (Complexity: Medium)
Add a search field at the top of Settings to quickly locate toggles like Kiosk Mode, Backup, and Localization options.

---

## Recently Completed Improvements (2026-05-29)

- ✅ **Pre-Registration (Expected Visitors)** — Implemented 2026-05-26. Added PIN-protected admin management, visitor-facing pre-registered lookup flow, confirmation path, and induction/sign-in routing with pre-registration tracking.
- ✅ **Returning Visitor Fast Sign-In** — Implemented 2026-05-26. Added search-only returning visitor flow (first name, last name, registration), confirmation step, parked-on-site branch, and form prefill for fast re-entry.
- ✅ **Visitor Analytics Dashboard** — Implemented 2026-04-22; enriched 2026-05-29. Added deeper KPI set (including car/blocked-car/same-day/median/peak-hour metrics) and export options for CSV plus printable report.
- ✅ **Kiosk / Lock-Screen Mode** — Implemented 2026-05-29. Added PIN-protected kiosk mode toggle with key icon control on the main screen and kiosk-mode visibility rules for reception/self-service controls.
- ✅ **Duplicate Sign-In Prevention** — Implemented 2026-05-29. Added duplicate active-sign-in warning for same first+last name signed in today, with confirm/cancel before record creation.
- ✅ **PIN-protected flow hardening** — Fixed first-open blank PIN prompt race by carrying protected action state directly into the PIN sheet path.
- ✅ **PIN session UX update** — Added 5-minute PIN session timeout handling already in app flow and stabilized sheet transitions for protected areas.
- ✅ **Form keyboard and focus improvements** — Badge field now has a keyboard `Next` toolbar action to reliably move focus to Car Registration.
- ✅ **Input behavior improvements** — Added robust capitalization handling for name/company/visiting fields and refined keyboard traits per field.
- ✅ **Sign In Book action wiring** — Added active-row checkout action so `onCheckedOut` callback is live and banner feedback triggers correctly.
- ✅ **Induction flow safety** — Added guard for empty induction image sets; flow now safely auto-cancels instead of allowing sign completion with no content.
- ✅ **Signature font fallback hardening** — Replaced silent `Font.custom` fallback behavior with explicit installed-font checks and deterministic fallback chain.
- ✅ **Localization baseline introduced** — Added `Localizable.strings` and migrated key user-facing error/alert text to `String(localized:)`.
- ✅ **VisitorTabs UI isolation** — Removed global `UITableView.appearance()` mutations; styling now stays local to affected views.
- ✅ **Preview reliability** — Fixed missing preview environment wiring for `RootView` (`.modelContainer` + `.environment(VisitorStore())`).
- ✅ **Checkout banner UX update** — Removed manual Done button, added visible 5-second countdown, and auto-dismiss back to registration view.
- ✅ **Emergency shortcut on registration screen** — Added a small fire icon button beside the Settings cog as a direct shortcut to Fire Alarm Roll Call, routed through the same PIN-gated access flow.

- Tracker audit updated on 2026-04-25 after closure of BUG-001 through BUG-008 low/medium items from `CodeReview.md`.

---

### CSV Backup & Restore

- [x] 🔵 ~~**Automatic daily backup**~~ — Implemented 2026-03-23. `BackupScheduler` class fires daily at 06:00. Toggle in Settings. Files saved to app Documents as `visitor_backup_YYYY-MM-DD.csv`. Rolling 30-day retention with automatic pruning of older files.

- [x] 🔵 ~~**Manual backup**~~ — Implemented 2026-03-23. "Export Backup Now" button in Settings writes the CSV immediately and opens the share sheet so it can be saved or sent.

- [x] 🔵 ~~**CSV import / restore**~~ — Implemented 2026-03-23. "Import CSV…" button in Settings opens the system file picker. After parsing, an `ImportConfirmationView` sheet shows counts (imported / skipped duplicates / failed rows) before committing to SwiftData.

- [x] 🔵 ~~**Import column mapping**~~ — Implemented 2026-03-23. `VisitorStore.previewImport` maps columns by header name (not position). Accepts both the 11-column WelcomeView format and the 7-column VisitorTabs format.

- [x] 🔵 ~~**Backwards-compatible import for legacy CSV files**~~ — Implemented 2026-03-23. Header-name mapping means missing columns don't shift values. Safe defaults applied: `badgeNumber = ""`, `blockedCar = false`, `pagerNumber = nil`, `wasAutoCheckedOut = false`, `checkOut = nil`. Quote-aware CSV parser handles embedded commas/quotes/newlines. Malformed rows are counted as "failed" and never crash the import.

- [x] 🔵 ~~**Backup storage location**~~ — Implemented 2026-03-23. Backups stored in app Documents directory (visible in Files app). Settings sheet shows file count and most recent backup date. iCloud sync is handled automatically if the user has iCloud Drive enabled for the app.

---
