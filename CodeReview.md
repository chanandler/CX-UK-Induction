# Code Review Tracker
> Generated: 2026-03-23 | Last updated: 2026-04-22

---

## Priority Legend
- 🔴 **CRITICAL** — Bug, crash risk, or data loss
- 🟠 **HIGH** — Significant issue impacting correctness or user experience
- 🟡 **MEDIUM** — Performance or code quality issue
- 🟢 **LOW** — Minor improvement or style issue

---

## Open Issues

---

### RootView.swift

- [ ] 🟢 **Preview lacks required environment** — The `#Preview` block in `RootView.swift` has no `.modelContainer` or `.environment(VisitorStore())`, so it will fail to render in Xcode canvas. Note: `WelcomeView.swift`'s `#Preview` correctly wraps `RootView()` with the required environment. Fix: apply the same setup to `RootView.swift`'s own preview.

---

### VisitorTabs.swift

- [ ] 🟢 **`UITableView.appearance()` modifies global UI state** — Appearance proxy changes persist globally and can affect unrelated views. Replace with SwiftUI-native list/row modifiers where possible.

---

### WelcomeView.swift

- [ ] 🟢 **Pager count hardcoded to 30** — The picker range `1...30` is a magic number. Extract to a named constant so it can be changed in one place.

- [ ] 🟢 **All user-facing strings are hardcoded English** — No `Localizable.strings` or `String(localized:)` usage. Low priority for an internal tool, but worth noting.

---

### VisitorTabs.swift (Round 2 — 2026-03-24)

- [x] 🟠 ~~**`exportCSV()` silently produces an empty/missing file via optional-chain write**~~ — Fixed 2026-04-22.

---

### WelcomeView.swift (Round 2 — 2026-03-24)

- [x] 🟠 ~~**`submit()` stores empty string `""` as `pagerNumber` instead of `nil`**~~ — Fixed 2026-04-22.

- [ ] 🟡 **Form shows validation errors on initial empty state** — Every `*Invalid` computed property (`firstNameInvalid`, `lastNameInvalid`, etc.) returns `true` when its field is empty. As a result, all required fields display red borders and "... is required" captions the moment the form first loads, before the user has typed a single character. The standard UX pattern is to only show errors after the first submission attempt or after the user has interacted with a field (`@State private var hasAttemptedSubmit`). Fix: gate error display on a `hasAttemptedSubmit` flag that is set to `true` when the Register button is tapped.

- [ ] 🟡 **`LeavingSearchSheet.filtered` snapshot freeze fails when the initial visitor list is empty** — `let source = snapshot.isEmpty ? activeVisitors : snapshot` is used as a guard to freeze the list when the sheet opens. However, when the sheet opens with zero active visitors, `onAppear` sets `snapshot = []` (empty), so `snapshot.isEmpty` remains `true` forever. Any visitor who signs in while the sheet is open will immediately appear in the list, defeating the freeze intent. Fix: use an `Optional<[Visitor]>` (`var snapshot: [Visitor]? = nil`) and set it to `activeVisitors` (even `[]`) in `onAppear`; use `snapshot ?? activeVisitors` in `filtered`.

- [ ] 🟡 **`SignInBookView.onCheckedOut` callback is dead code** — The `onCheckedOut: (String) -> Void` parameter is accepted by `SignInBookView` but is never called anywhere within the view. The active-visitor list rows contain no checkout action. Either the callback should be removed from the API surface or a checkout button should be wired to it, otherwise callers set up a closure that can never fire.

- [ ] 🟢 **`showSignedOutBannerTemporarily()` name is misleading** — The method name implies a transient, self-dismissing banner, but there is no auto-dismiss timer; the banner persists until the user manually taps "Done". Rename the method to `showSignedOutBanner()` to accurately reflect its behaviour, or add a `DispatchQueue.main.asyncAfter` auto-dismiss (e.g. after 8 seconds) to match the implied semantics.

---

### WelcomeView.swift (Round 3 — 2026-03-24)

- [ ] 🟡 **`badgeField` uses `.keyboardType(.numberPad)` which voids the keyboard focus chain** — The badge number field has `.submitLabel(.next)` and `.onSubmit { focusedField.wrappedValue = .carReg }` applied, but the number pad keyboard on iOS shows no return key, so `onSubmit` is dead code for this field. Users cannot advance keyboard focus from the badge field to the car registration field and must tap it manually. Fix: keep `.keyboardType(.numberPad)` and add a keyboard toolbar "Next" button via `ToolbarItemGroup(placement: .keyboard) { Button("Next") { focusedField = .carReg } }`, or switch to `.keyboardType(.default)` which preserves the return key.

- [ ] 🟡 **`InductionSignatureSheet` relies on a custom font name that may silently fall back to system default** — `Text("\(firstName) \(lastName)").font(.custom("BradleyHandITCTT-Bold", size: 58))` calls `Font.custom(_:size:)`, which silently falls back to the default system font if the named font is not present on the device. If that happens the "signature" looks like regular body text rather than a handwritten name, which defeats the visual purpose of the sheet. Fix: either bundle the font file in the app target and register it under `UIAppFonts` in `Info.plist` to guarantee availability, or replace it with a `PKCanvasView`-based real handwritten signature capture.

- [ ] 🟢 **`InductionFlowView` does not guard against an empty `imageNames` array** — `if index < imageNames.count - 1` evaluates to `0 < -1` (false) when `imageNames` is empty, immediately showing the "Tap here to sign" button with zero induction pages displayed. The visitor would be able to complete the induction flow without seeing any induction content. Fix: add a guard at the top of the view body: `if imageNames.isEmpty { onComplete(false); return }`.

---

## Completed Issues

| Date | File | Issue |
|---|---|---|
| 2026-03-23 | AutoCheckoutManager.swift | Timer added to RunLoop twice |
| 2026-03-23 | AutoCheckoutManager.swift | Recursive rescheduling |
| 2026-03-23 | CX_UK_InductionApp.swift | SwiftData container failure silent |
| 2026-03-23 | Models.swift | `checkoutTime` parameter ignored |
| 2026-03-23 | WelcomeView.swift | Scheduler not cancelled on disappear |
| 2026-03-23 | WelcomeView.swift | Multiple timers stacking |
| 2026-03-23 | WelcomeView.swift | Unused `archivedVisitors` @Query |
| 2026-03-23 | Models.swift | Duplicate auto-checkout methods merged |
| 2026-03-23 | Models.swift | `signIn()` missing post-trim validation |
| 2026-03-23 | VisitorTabs.swift + WelcomeView.swift | `escapeCSV` duplication extracted to `String.escapedAsCSVField` |
| 2026-03-23 | VisitorTabs.swift + WelcomeView.swift | `DateFormatter` instances consolidated to shared `static let` extensions |
| 2026-03-23 | Models.swift + WelcomeView.swift + VisitorTabs.swift | `badgeNumber` optionality aligned (now non-optional `String`) |
| 2026-03-23 | WelcomeView.swift | Pager picker normalization dead code removed |
| 2026-03-23 | WelcomeView.swift | Pager availability icons (🔴/🟢) not visible — replaced hidden `.menu` picker with always-visible `LazyVGrid` of buttons |
| 2026-03-23 | WelcomeView.swift + Models.swift | `WelcomeView.body` type-checker complexity — split into four `@ViewBuilder` properties; `StoreError` made `Equatable` |
| 2026-03-23 | WelcomeView.swift | `withAnimation` unused result warning — suppressed with `_ =` |
| 2026-03-23 | VisitorTabs.swift + WelcomeView.swift | Temp CSV files not deleted — fixed `onDismiss` URL capture bug in both views |
| 2026-03-23 | AutoCheckoutManager.swift | Weekday calculation already efficient — verified, no change needed |
| 2026-03-23 | Models.swift | Structured error type already in place — verified `StoreError` enum, no change needed |
| 2026-03-23 | VisitorTabs.swift | CSV export error alert already implemented — verified, no change needed |
| 2026-03-23 | VisitorTabs.swift | CEMEX Blue already extracted to `Color.cemexBlue` — verified, no change needed |
| 2026-03-23 | WelcomeView.swift | Haptic generator already a stored property — verified, no change needed |
| 2026-03-24 | RootView.swift | ZStack single-child — now has two children (`Color.cemexBlue` bg + `WelcomeView`) |
| 2026-03-24 | WelcomeView.swift | `RegularFormFields` / `CompactFormFields` duplication — merged into `VisitorFormFields` with `useColumns` param |
| 2026-04-22 | Models.swift | CSV import duplicate detection within imported file — now skipped via in-pass `seenKeys` |
| 2026-04-22 | Models.swift | Windows `\r\n` CSV line endings — import splitting now uses `CharacterSet.newlines` |
| 2026-04-22 | WelcomeView.swift | Cold-launch auto-checkout catch-up added on `onAppear` |
| 2026-04-22 | WelcomeView.swift | Sheet-state boolean explosion reduced via enum-driven `activeSheet` modal routing |
| 2026-04-22 | VisitorTabs.swift + WelcomeView.swift | CSV export write path switched to `String.write` (removed optional-chain write risk) |
| 2026-04-22 | WelcomeView.swift | `submit()` now stores `pagerNumber` as `nil` when blank |

---

## Completed UI Improvements (2026-03-24)

| Date | Area | Change |
|---|---|---|
| 2026-03-24 | `WelcomeView` — `BrandHeader` | Logo now displayed on a white rounded-rect backing with shadow so it is clearly visible against the dark CEMEX blue gradient |
| 2026-03-24 | `WelcomeView` — `BrandHeader` | Added a light blue-grey accent strip (`#DCE6F8` → system grouped background) below the blue band to provide visual contrast and a smoother transition into the form card |
| 2026-03-24 | `WelcomeView` — `InductionFlowView` | Replaced the tick-box acknowledgement with a **"Tap here to sign"** button that opens a full-height signature sheet |
| 2026-03-24 | `WelcomeView` — `InductionSignatureSheet` (new) | New sheet presents a clear "Confirm Understanding" heading, body text, and the visitor's first + last name rendered in `BradleyHandITCTT-Bold` (closest built-in iOS equivalent to Kalam) at 58pt with a spring-in animation |
| 2026-03-24 | `WelcomeView` — `InductionSignatureSheet` | "I Agree" button triggers `onComplete(true)` directly — the registration confirmation alert fires immediately without any intermediate screen |
| 2026-03-24 | `WelcomeView` — `InductionFlowView` | Removed intermediate "Signed by / Confirm and Continue" step; `isSigned` state deleted; flow is now: slides → sign sheet → confirmation alert |

---

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

## Notes

- All 🔴 CRITICAL issues resolved as of 2026-03-23.
- Round 2 (2026-03-24, first pass) deep-dive found: 3 🟠 HIGH in `Models.swift`, 1 🟠 HIGH in `VisitorTabs.swift`, 2 🟠 HIGH + 2 🟡 MEDIUM + 1 🟢 LOW in `WelcomeView.swift`.
- Round 3 (2026-03-24, after UI update) deep-dive found: 2 🟡 MEDIUM + 1 🟢 LOW in `WelcomeView.swift` (`badgeField` focus chain, `BradleyHandITCTT-Bold` font risk, empty induction image guard).
- Items fixed since Round 2: `RegularFormFields`/`CompactFormFields` merged into `VisitorFormFields`; `RootView` `ZStack` now has two children; CSV in-file duplicate detection; Windows `\r\n` CSV handling; cold-launch auto-checkout catch-up; enum-driven sheet state in `WelcomeView`.
- Remaining open HIGH priority items: none.
- Next recommended pass: address the remaining 🟡 MEDIUM issues in `WelcomeView.swift`.
- CSV backup & restore feature fully implemented 2026-03-23 (see Feature Requests section above — all items completed).

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
- Tracker audit updated on 2026-04-22 after fixes to previously-open HIGH and MEDIUM issues.
- Issues closed in this pass: duplicate detection within imported CSV, Windows `\r\n` CSV parsing, cold-launch auto-checkout catch-up, and enum-driven sheet state consolidation in `WelcomeView`.
- Current open issue counts: 2 🟠 HIGH, 5 🟡 MEDIUM, 6 🟢 LOW.
- The highest-priority remaining items are the CSV optional-chain write path (`VisitorTabs.swift` / `WelcomeView.swift`) and pager empty-string vs `nil` semantics (`WelcomeView.swift`).
- Feature Idea 10 (Visitor Analytics Dashboard) is now implemented and marked complete.
