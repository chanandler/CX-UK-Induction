# Code New Features Tracker
> Generated: 2026-04-22 | Last updated: 2026-04-25

## Feature Requests

### CSV Backup & Restore

- [x] 🔵 ~~**Automatic daily backup**~~ — Implemented 2026-03-23. `BackupScheduler` class fires daily at 06:00. Toggle in Settings. Files saved to app Documents as `visitor_backup_YYYY-MM-DD.csv`. Rolling 30-day retention with automatic pruning of older files.

- [x] 🔵 ~~**Manual backup**~~ — Implemented 2026-03-23. "Export Backup Now" button in Settings writes the CSV immediately and opens the share sheet so it can be saved or sent.

- [x] 🔵 ~~**CSV import / restore**~~ — Implemented 2026-03-23. "Import CSV…" button in Settings opens the system file picker. After parsing, an `ImportConfirmationView` sheet shows counts (imported / skipped duplicates / failed rows) before committing to SwiftData.

- [x] 🔵 ~~**Import column mapping**~~ — Implemented 2026-03-23. `VisitorStore.previewImport` maps columns by header name (not position). Accepts both the 11-column WelcomeView format and the 7-column VisitorTabs format.

- [x] 🔵 ~~**Backwards-compatible import for legacy CSV files**~~ — Implemented 2026-03-23. Header-name mapping means missing columns don't shift values. Safe defaults applied: `badgeNumber = ""`, `blockedCar = false`, `pagerNumber = nil`, `wasAutoCheckedOut = false`, `checkOut = nil`. Quote-aware CSV parser handles embedded commas/quotes/newlines. Malformed rows are counted as "failed" and never crash the import.

- [x] 🔵 ~~**Backup storage location**~~ — Implemented 2026-03-23. Backups stored in app Documents directory (visible in Files app). Settings sheet shows file count and most recent backup date. iCloud sync is handled automatically if the user has iCloud Drive enabled for the app.

**Implementation notes:**
- File import: use SwiftUI's `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` — no UIKit needed.
- Backup scheduling: add a second `AutoCheckoutScheduler`-style class (`BackupScheduler`) triggered at 06:00 daily, or extend `AutoCheckoutScheduler` to support multiple actions.
- CSV parsing: use `String.components(separatedBy:)` with quote-aware splitting to handle fields that contain commas (reverse of `escapedAsCSVField`).
- SwiftData insert: fetch existing records first and build a `Set` of `(firstName+lastName+checkIn)` keys for O(1) duplicate detection.

---

## Future Feature Ideas

The following 25 features are proposed to improve usability, security, and operational value of the app. Each is rated by potential impact.

### 1. 🌟 Pre-Registration (Expected Visitors)
Allow staff to pre-register expected visitors from the Settings screen. When a pre-registered visitor arrives, they tap their name from a list and only need to confirm their details, skipping manual data entry entirely. Reduces queue time at reception.

### 2. 🌟 Host Notification on Arrival
When a visitor signs in and specifies who they are visiting, automatically send that person an email or Microsoft Teams adaptive card ("Your visitor [Name] from [Company] has arrived at reception"). Requires a configurable SMTP/webhook URL in Settings.

### 3. 🌟 Visitor Photo Capture
After the induction flow, open the front camera and capture a visitor photo, stored with the `Visitor` record. Displayed on the visitor's detail card and in the Sign In Book for identity verification. Stored locally; never uploaded externally.

### 4. 🌟 Genuine Handwritten Digital Signature
Upgrade `InductionSignatureSheet` to use `PKCanvasView` from PencilKit so the visitor draws their actual signature with a finger or Apple Pencil. The resulting image is saved as a PNG alongside the visitor record and included in CSV exports as a base64-encoded field.

### 5. 🌟 Visitor Badge Printing
Integrate with a Bluetooth label printer (e.g. Brother QL-820NWBc via SDK) to print a badge on check-in containing visitor name, company, date, badge number, and a QR code linking to their record. Configurable badge template in Settings.

### 6. 🌟 QR Code Check-In / Check-Out
Generate a personal QR code for each visitor on sign-in. Scanning the code on a second device checks the visitor out instantly — useful for high-traffic exits. The QR payload encodes the visitor UUID.

### 7. 🌟 Returning Visitor Fast Sign-In
On tapping a name or company field, fuzzy-search previous visitor records and offer to pre-populate the form with that person's last-used details (company, "visiting", car registration). Saves time for regular contractors.

### 8. 🌟 Time-Limited Visitor Passes with Overdue Alerts
When signing in, optionally set a pass expiry duration (e.g. 2 h, 4 h, full day). A local notification fires 15 minutes before expiry and again at expiry if the visitor has not checked out, alerting reception to follow up.

### 9. 🌟 Vehicle Watch List
Maintain a configurable list of flagged car registrations (e.g. known trespassers). When a matching registration is entered at sign-in, reception sees a discreet alert before the form is submitted, prompting manual intervention.

### 10. ✅ Visitor Analytics Dashboard (Implemented 2026-04-22)
Implemented as a PIN-protected "Analytics Dashboard" opened from Settings. Includes: total visitors today / this week / this month, bar chart of visitors by hour-of-day, average visit duration, top 5 most-visited departments, and busiest day-of-week, built with Swift Charts.

### 11. 🌟 Emergency Evacuation Broadcast
A dedicated "Evacuate" button (PIN-protected) that sends a push notification to all devices currently signed in as kiosk displays and optionally triggers a configurable webhook (e.g. Teams channel alert) with the current active visitor count and list.

### 12. 🌟 Apple Watch Companion — Fire Roll Call
Expose the Fire Alarm Roll Call on a paired Apple Watch via WatchConnectivity. Security officers can tap visitor names as accounted-for during an evacuation without needing the iPad.

### 13. 🌟 Kiosk / Lock-Screen Mode
A PIN-protected toggle in Settings that hides all management UI (settings, sign-in book, export) and locks the app into self-service sign-in only. The home button is suppressed via Guided Access API. Ideal for an unattended reception kiosk.

### 14. 🌟 Biometric Authentication for Staff Features
Gate access to the Settings sheet, Sign In Book, and Roll Call behind Face ID / Touch ID using `LAContext`. Prevents visitors from accidentally (or intentionally) accessing internal data while the app is on the reception desk.

### 15. 🌟 Bulk End-of-Day Check-Out
A single-tap "End of Day — Check Out All" button in Settings (confirmation required) that calls `autoCheckoutPreviousDay` immediately for all visitors still active, regardless of check-in date. Useful at the end of a shift.

### 16. 🌟 Multi-Site / Multi-Location Support
Add a "Location" field to `Visitor` and a configurable `currentSite` setting. CSV exports and analytics are filterable by site. Enables the app to be deployed across multiple CEMEX UK offices from a single shared iCloud container.

### 17. 🌟 Scheduled Visitor Reports via Email
A configurable scheduled report (daily / weekly / monthly) that compiles a visitor summary and emails it as a CSV attachment to a configured address, triggered by a `BackupScheduler`-style timer using a SMTP library or mailto URL.

### 18. 🌟 Car Park Capacity Monitor
Add a configurable "Total Spaces" value in Settings. A live capacity indicator on the Welcome screen (e.g. "12 / 50 spaces used") is computed from the count of active visitors with a non-empty car registration. Turns amber at 80 % and red at 100 %.

### 19. 🌟 Offline Queue with iCloud Sync
When iCloud Drive is unavailable, queue new sign-ins in a local `pending` store. When connectivity is restored, merge the queue into the main `ModelContainer`. Prevents data loss when the iPad is offline during peak arrival times.

### 20. 🌟 Visitor Frequency / Trend Tracking
Record visit count per unique (firstName + lastName + company) combination and surface a "Frequent Visitors" section in the Sign In Book. Flag visitors who have signed in more than N times in the last 30 days as a configurable security review threshold.

### 21. 🌟 Custom Induction Quiz Questions
Allow admins to add multiple-choice questions to the induction flow via a JSON file in the app bundle or Documents folder. The visitor must answer all questions correctly (configurable attempts) before the "Tap here to sign" button is enabled.

### 22. 🌟 Audit Log / Change History
Persist an append-only `AuditEvent` model in SwiftData recording every create, update, and delete with a timestamp and actor (self-service / staff). Viewable in Settings as a scrollable timeline. Included in CSV backup.

### 23. 🌟 Dark Mode Optimised Theming
Currently the app relies on `Color(.systemBackground)` which can look washed out in dark mode against the CEMEX blue. Introduce a `ColorScheme`-aware theme layer (`AppTheme`) with explicit light/dark tokens for card fills, text, and form backgrounds.

### 24. 🌟 Accessibility Improvements — VoiceOver & Dynamic Type
Audit every screen for VoiceOver support: add `accessibilityLabel` to icon-only buttons, confirm all interactive elements have meaningful descriptions, and verify the form scales correctly at the largest Dynamic Type size settings (relevant for accessibility compliance).

### 25. 🌟 Duplicate Sign-In Prevention
Before calling `store.signIn()`, query SwiftData for any active visitor with the same `firstName + lastName` signed in today and show a confirmation dialog ("This person appears to be already signed in — are you sure you want to add a new record?"). Prevents accidental double sign-ins for the same person.

---

## Recently Completed Improvements (2026-04-25)

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
