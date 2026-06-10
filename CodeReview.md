# Code Review Tracker
> Generated: 2026-03-23 | Last updated: 2026-06-10

---

## Priority Legend
- 🔴 **CRITICAL** — Bug, crash risk, or data loss
- 🟠 **HIGH** — Significant issue impacting correctness or user experience
- 🟡 **MEDIUM** — Performance or code quality issue
- 🟢 **LOW** — Minor improvement or style issue

---

## Open Issues

| ID | Priority | File | Issue | Evidence |
|---|---|---|---|---|
| BUG-079 | 🟡 MEDIUM | WelcomeView.swift | Several visitor/admin-facing strings remain hard-coded and bypass localization, causing mixed-language UI and inconsistent copy in kiosk/sign-in contexts. | Examples at `WelcomeView.swift:618-627`, `WelcomeView.swift:1146-1179`, `WelcomeView.swift:1244-1248` |
| BUG-080 | 🟡 MEDIUM | AnalyticsDashboardView.swift | Heatmap chart uses non-unique identity (`id: \.hour`) for 7 rows per hour, which can produce unstable diffing/rendering in SwiftUI Chart updates. | `Chart(matrix, id: \.hour)` in `AnalyticsDashboardView.swift:112` while matrix contains repeated `hour` values across weekdays |
| OPT-001 | 🟡 MEDIUM | AnalyticsDashboardView.swift | Analytics metrics are recomputed from scratch on every render, with multiple full-array passes and formatter creation in hot UI paths; this can stutter as history grows. | `metrics` computed property (`AnalyticsDashboardView.swift:51-59`) and heavy metric init loops (`AnalyticsDashboardView.swift:553-698`) |
| QOL-001 | 🟢 LOW | AdminAndUtilitiesViews.swift | Backup list in Settings only shows filenames; adding formatted date/time, size, and a quick share/open action would reduce admin friction when restoring or auditing backups. | Current list shows only `url.lastPathComponent` in `AdminAndUtilitiesViews.swift:73-75` |
| QOL-002 | 🟢 LOW | WelcomeView.swift | Main sign-in journey would be faster with automatic focus reset to first name after successful registration and after returning from sheets. | Field focus is wired (`WelcomeView.swift:103-106`) but no post-submit autofocus is set in reset flow (`WelcomeView.swift:854-863`) |

---

## Completed Issues

| Date | Status | Description |
|---|---|---|
| 2026-06-10 | ✅ Models.swift + VisitorTabs.swift | BUG-077 fixed — import duplicate detection now supports second-precision timestamps while retaining minute-precision fallback for legacy CSV files; added second-aware CSV parsers and precision-aware duplicate key handling |
| 2026-06-10 | ✅ AnalyticsDashboardView.swift | BUG-076 fixed — corrected Monday-first heatmap weekday label mapping so displayed day labels align with bucketed counts |
| 2026-06-10 | ✅ CX_UK_InductionApp.swift | BUG-078 fixed — replaced startup `fatalError` with resilient launch flow: primary persistent ModelContainer, automatic in-memory fallback with visible warning banner, and a non-crashing startup error screen if both stores fail |
| 2026-06-09 | ✅ AnalyticsDashboardView.swift + Localizable.strings | BUG-068 fixed — removed hidden dependency on cross-file share helper by introducing Analytics-local export share item/sheet (`AnalyticsExportShareItem` / `AnalyticsExportShareSheet`) |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift + Localizable.strings | BUG-069 fixed — redesigned `ImportConfirmationView` with localized labels, structured count cards, improved action buttons, and combined accessibility summary |
| 2026-06-09 | ✅ AnalyticsDashboardView.swift + Localizable.strings | BUG-063 fixed — localized remaining analytics summary card titles (`Car Visitors`, `Blocked Car`, `Same-day Checkout`, `Median Visit`, `Avg Visits / Day`, `Peak Hour`) |
| 2026-06-09 | ✅ WelcomeView.swift + Localizable.strings | BUG-064 fixed — localized kiosk-mode confirmation alert titles/messages/actions and kiosk-mode banner text |
| 2026-06-09 | ✅ VisitorTabs.swift + Localizable.strings | BUG-066 fixed — added confirmation alert to `VisitorDetail` destructive checkout action before mutating visitor state |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-059 fixed — switched visitor list identity from `id: \.self` to stable `id: \.id` in Leaving/Search, Sign In Book, and Fire Roll Call views |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-060 fixed — extracted repeated CEMEX button styling into reusable `View` helpers (`welcomePrimaryActionStyle`, `welcomeProminentActionStyle`, `welcomeSecondaryActionStyle`) and applied them across primary action buttons |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-055 fixed — moved `UIKit` import under `#if canImport(UIKit)` to match the guarded `ActivityView` wrapper |
| 2026-06-09 | ✅ VisitorTabs.swift + AnalyticsDashboardView.swift | BUG-057 fixed — share export cleanup now runs on interactive sheet dismiss via `onDisappear`, and share helper naming was clarified (`ExportShareItem` / `ExportShareSheet`) to reduce confusion with other `ShareItem` types |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-052 fixed — added explicit accessibility labels/hints to key primary/icon actions and increased utility icon touch target height to 52pt |
| 2026-06-09 | ✅ AnalyticsDashboardView.swift + Localizable.strings | BUG-053 fixed — localized analytics export error alert title/message using `String(localized:)` keys |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift + Localizable.strings | BUG-050 fixed — localized settings/admin section titles, toggles, and actions (including backup/import/analytics/pre-registration/admin lock labels) via `String(localized:)` keys |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-051 fixed — `PreRegisteredListView` date formatter is now a cached static formatter instead of being recreated per access |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-067 fixed — CSV file importer now accepts `.commaSeparatedText` only (removed broad `.text`/`.data` content types) |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-070 fixed — replaced `pendingSubmit`/`hasRoutedToInduction` flow with explicit `registrationFlow` state (`idle`/`waitingBlockedCarDecision`/`waitingPagerSelection`/`waitingForInduction`) to de-risk alert/sheet overlap races |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-062 fixed — local pre-registration badge conflict check now compares normalized badge values (trimmed/lowercased) |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-065 fixed — returning-visitor dedup key now includes company (`first|last|company`) to avoid merging distinct same-name people |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-075 fixed — pre-registration add failures now show the actual store error and only enable badge-conflict UI when the error is genuinely a badge conflict |
| 2026-06-09 | ✅ Models.swift | BUG-074 fixed — pre-registration badge conflict now checks only records with explicit `visitDate`; no fallback to `createdAt` |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-071 fixed — removed hidden header tap gesture that reset admin PIN without authentication |
| 2026-06-09 | ✅ CSVExport.swift | BUG-072 fixed — CSV export now writes empty values (not `"N/A"`) for optional fields so import round-trip preserves semantics |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-073 fixed — duplicate active sign-in guard now checks all active visitors, not only records signed in today |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-058 fixed — Badge conflict allocation now only considers pre-registered records with an explicit visitDate; fallback to createdAt removed to avoid false conflicts |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-049 fixed — Backup scheduler now uses the settings-controlled time (hour/minute) instead of a hardcoded 06:00 |
| 2026-06-09 | ✅ CSVExport.swift + WelcomeView.swift + VisitorTabs.swift | BUG-048 fixed — Centralized CSV export into CSVExporter with a single unified schema; both exports now use the same code |
| 2026-06-09 | ✅ AnalyticsDashboardView.swift | BUG-047 fixed — Heatmap now uses a consistent Monday-first mapping with locale-safe labels; counts and labels aligned |
| 2026-06-09 | ✅ AnalyticsDashboardView.swift | BUG-054 fixed — Corrected heatmap empty-state check to sum counts instead of using an invalid tuple count test |
| 2026-06-09 | ✅ WelcomeView.swift + AdminAndUtilitiesViews.swift | BUG-061 fixed — Added settings-controlled toggle (autoReturnPagersOnAutoCheckout) and gated auto-return of staff pagers during auto-checkout; default off to avoid surprises |
| 2026-06-09 | AdminAndUtilitiesViews.swift | BUG-041 fixed — Clarified date sort vs. label in PreRegisteredListView; code and comment aligned |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-040 fixed — Removed redundant "Export Backup Now" button; "Backup Now" retains local CSV backup behavior |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-039 fixed — Centralized induction routing via routeToInductionIfReady() to prevent double-presentation race |
| 2026-06-04 | ✅ WelcomeView.swift | BUG-038 fixed — Prepared haptics before presenting critical alerts (blocked-car prompt, badge conflict, duplicate sign-in) for snappier feedback |
| 2026-06-04 | ✅ Models.swift | BUG-037 fixed — Updated backup CSV comment to reflect 12 columns (includes Pre-Registered) to match export header |
| 2026-06-04 | ✅ PlaceholderViews.swift | BUG-036 fixed — Returning visitor search now deduplicates by (first,last) keeping the most recent visit, so company changes are handled sensibly |
| 2026-06-04 | ✅ WelcomeView.swift | BUG-035 fixed — Consolidated pager prompt/induction continuation into a single helper to prevent double-present and stale pending state |
| 2026-06-04 | ✅ WelcomeView.swift | BUG-033 fixed — Pager availability now excludes pagers freed by immediate checkout/return using a short grace window to avoid transient blocking |
| 2026-06-04 | ✅ Models.swift | BUG-034 fixed — Pre-registration badge conflict now checks active visitors on the same day as well as other pre-registrations |
| 2026-06-04 | ✅ PlaceholderViews.swift | BUG-032 fixed — Local badge conflict check now correctly unwraps visit date before comparing to same-day |
| 2026-06-04 | ✅ WelcomeView.swift | BUG-031 fixed — Duplicate sign-in guard now checks for any active record with the same name, not only those signed in today |
| 2026-06-04 | ✅ WelcomeView.swift | BUG-029 fixed — Duplicate detection key uses `timeIntervalSinceReferenceDate` which encodes seconds |
| 2026-06-04 | ✅ WelcomeView.swift | BUG-030 fixed — Kiosk Mode now requires explicit confirmation and shows a temporary banner after toggling |
| 2026-03-23 | ✅ AutoCheckoutManager.swift | Timer added to RunLoop twice |
| 2026-03-23 | ✅ AutoCheckoutManager.swift | Recursive rescheduling |
| 2026-03-23 | ✅ CX_UK_InductionApp.swift | SwiftData container failure silent |
| 2026-03-23 | ✅ Models.swift | `checkoutTime` parameter ignored |
| 2026-03-23 | ✅ WelcomeView.swift | Scheduler not cancelled on disappear |
| 2026-03-23 | ✅ WelcomeView.swift | Multiple timers stacking |
| 2026-03-23 | ✅ WelcomeView.swift | Unused `archivedVisitors` @Query |
| 2026-03-23 | ✅ Models.swift | Duplicate auto-checkout methods merged |
| 2026-03-23 | ✅ Models.swift | `signIn()` missing post-trim validation |
| 2026-03-23 | ✅ VisitorTabs.swift + WelcomeView.swift | `escapeCSV` duplication extracted to `String.escapedAsCSVField` |
| 2026-03-23 | ✅ VisitorTabs.swift + WelcomeView.swift | `DateFormatter` instances consolidated to shared `static let` extensions |
| 2026-03-23 | ✅ Models.swift + WelcomeView.swift + VisitorTabs.swift | `badgeNumber` optionality aligned (now non-optional `String`) |
| 2026-03-23 | ✅ WelcomeView.swift | Pager picker normalization dead code removed |
| 2026-03-23 | ✅ WelcomeView.swift | Pager availability icons (🔴/🟢) not visible — replaced hidden `.menu` picker with always-visible `LazyVGrid` of buttons |
| 2026-03-23 | ✅ WelcomeView.swift + Models.swift | `WelcomeView.body` type-checker complexity — split into four `@ViewBuilder` properties; `StoreError` made `Equatable` |
| 2026-03-23 | ✅ WelcomeView.swift | `withAnimation` unused result warning — suppressed with `_ =` |
| 2026-03-23 | ✅ VisitorTabs.swift + WelcomeView.swift | Temp CSV files not deleted — fixed `onDismiss` URL capture bug in both views |
| 2026-03-23 | ✅ AutoCheckoutManager.swift | Weekday calculation already efficient — verified, no change needed |
| 2026-03-23 | ✅ Models.swift | Structured error type already in place — verified `StoreError` enum, no change needed |
| 2026-03-23 | ✅ VisitorTabs.swift | CSV export error alert already implemented — verified, no change needed |
| 2026-03-23 | ✅ VisitorTabs.swift | CEMEX Blue already extracted to `Color.cemexBlue` — verified, no change needed |
| 2026-03-23 | ✅ WelcomeView.swift | Haptic generator already a stored property — verified, no change needed |
| 2026-03-24 | ✅ RootView.swift | ZStack single-child — now has two children (`Color.cemexBlue` bg + `WelcomeView`) |
| 2026-03-24 | ✅ WelcomeView.swift | `RegularFormFields` / `CompactFormFields` duplication — merged into `VisitorFormFields` with `useColumns` param |
| 2026-04-22 | ✅ Models.swift | CSV import duplicate detection within imported file — now skipped via in-pass `seenKeys` |
| 2026-04-22 | ✅ Models.swift | Windows `\r\n` CSV line endings — import splitting now uses `CharacterSet.newlines` |
| 2026-04-22 | ✅ WelcomeView.swift | Cold-launch auto-checkout catch-up added on `onAppear` |
| 2026-04-22 | ✅ WelcomeView.swift | Sheet-state boolean explosion reduced via enum-driven `activeSheet` modal routing |
| 2026-04-22 | ✅ VisitorTabs.swift + WelcomeView.swift | CSV export write path switched to `String.write` (removed optional-chain write risk) |
| 2026-04-22 | ✅ WelcomeView.swift | `submit()` now stores `pagerNumber` as `nil` when blank |
| 2026-04-22 | ✅ WelcomeView.swift | Validation errors now gated by `hasAttemptedSubmit` (no initial red state) |
| 2026-04-25 | ✅ RootView.swift | Preview lacks required environment — added `.modelContainer(for: Visitor.self, inMemory: true)` and `.environment(VisitorStore())` |
| 2026-04-25 | ✅ VisitorTabs.swift | `UITableView.appearance()` global UI state removed — replaced lifecycle appearance proxy mutation with local SwiftUI list/form styling only |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-001 pager count magic number removed — `1...30` extracted to `availablePagerRange` constant |
| 2026-04-25 | ✅ Models.swift + PINSecurity.swift + VisitorTabs.swift + Localizable.strings | BUG-002 localization baseline added — introduced `Localizable.strings` and replaced key user-facing error/alert strings with `String(localized:)` |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-003 `LeavingSearchSheet` snapshot freeze fixed — `snapshot` changed to optional and `filtered` now uses `snapshot ?? activeVisitors` |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-004 `SignInBookView.onCheckedOut` dead callback fixed — added active-row checkout action that calls `store.checkOut` and `onCheckedOut(visitor.fullName)` |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-005 misleading method name fixed — `showSignedOutBannerTemporarily()` renamed to `showSignedOutBanner()` |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-006 badge keyboard focus chain fixed — added keyboard toolbar `Next` action to move focus from Badge Number to Car Registration |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-007 signature font fallback hardened — now checks installed font availability and uses explicit fallback chain instead of silent `Font.custom` fallback |
| 2026-04-25 | ✅ WelcomeView.swift | BUG-008 empty induction content guard added — if `imageNames` is empty, flow now auto-cancels once via `onComplete(false)` |
| 2026-04-25 | ✅ WelcomeView.swift | Analytics launch flow from Settings de-raced — removed fixed `DispatchQueue.main.asyncAfter` delay and replaced with deterministic post-sheet-dismiss protected-action queue |
| 2026-04-25 | ✅ Models.swift | CSV import multiline quote handling fixed — replaced newline pre-split with quote-aware record parsing before field tokenization |
| 2026-04-25 | ✅ PINSecurity.swift + Localizable.strings | PIN gate brute-force protection added — 5 failed attempts lock for 5 minutes, next 5 lock for 10 minutes, next 5 lock for 30 minutes (capped), with localized countdown messaging; reset on successful unlock |
| 2026-04-26 | ✅ WelcomeView.swift | Sign In Book checkout is now confirmation-gated — active-row “Check out” stages a visitor and requires explicit confirmation before `store.checkOut` is called |
| 2026-04-26 | ✅ CX UK Induction.xcodeproj/project.pbxproj | Removed internal markdown docs (`CodeReview.md`, `CodeNewFeatures.md`, `SiteVisitorManagementOverview.md`) from `PBXResourcesBuildPhase`; only app resources (including `Localizable.strings`) remain bundled |
| 2026-05-14 | ✅ BackupScheduler.swift | BUG-012 fixed — backup filenames now include time (`visitor_backup_YYYY-MM-DD_HHmmss.csv`) to prevent same-day overwrite; prune logic updated to handle both legacy and new filename formats |
| 2026-05-14 | ✅ WelcomeView.swift + AnalyticsDashboardView.swift + Localizable.strings | BUG-009 fixed — localized core registration/settings/sign-in-book/roll-call/induction/about flows and analytics dashboard labels/messages via `String(localized:)` with new localization keys |
| 2026-05-14 | ✅ WelcomeView.swift | BUG-010 fixed — removed dual-dismiss path in `SignInBookView`; Done now uses single parent-driven closure (`onDone`) |
| 2026-05-14 | ✅ Models.swift | BUG-011 fixed — CSV import header parsing now strips UTF-8 BOM from first header cell before required-column matching |
| 2026-05-26 | ✅ WelcomeView.swift | BUG-014 fixed — on sign-in failure, pre-registration session flags are now reset to prevent state leakage into subsequent manual registrations |
| 2026-05-26 | ✅ AutoCheckoutManager.swift | BUG-015 fixed — added schedule-token guard around one-shot timer handler so stale callbacks cannot reschedule after cancel/disable |
| 2026-05-26 | ✅ WelcomeView.swift + AnalyticsDashboardView.swift + Localizable.strings | BUG-016 fixed — localized pre-registration and related analytics strings via `String(localized:)` and added new localization keys |
| 2026-05-26 | ✅ Models.swift | BUG-013 fixed — added explicit schema default (`var wasPreRegistered: Bool = false`) to support lightweight migration for existing records |
| 2026-06-02 | ✅ WelcomeView.swift + PlaceholderViews.swift + Models.swift | BUG-017 fixed — staff car pager issue/return flows now persist `StaffPagerIssue` records and mark active issues returned instead of showing placeholder-only screens |
| 2026-06-02 | ✅ WelcomeView.swift | BUG-018 fixed — CSV import preview failures now show the stored error and do not open a misleading zero-row confirmation sheet |
| 2026-06-02 | ✅ PlaceholderViews.swift | BUG-019 fixed — Sign In Book checkout confirmation restored before mutating visitor checkout state |
| 2026-06-02 | ✅ PlaceholderViews.swift | BUG-020 fixed — Fire Alarm Roll Call now shows a live active-visitor emergency list with badges, cars and pagers instead of a placeholder screen |
| 2026-06-02 | ✅ PlaceholderViews.swift + WelcomeView.swift + Models.swift | BUG-021 fixed — Pre-Registration Admin now adds and deletes persisted pre-registered visitors instead of showing placeholder text |
| 2026-06-02 | ✅ PlaceholderViews.swift | BUG-022 fixed — Pre-Registered and Returning Visitor sheets now support search plus sign-in with or without car registration |
| 2026-06-02 | ✅ PlaceholderViews.swift | BUG-023 fixed — Induction flow now displays induction image assets in a paged flow with next/confirm actions instead of only showing a slide count |
| 2026-06-02 | ✅ Models.swift + WelcomeView.swift | BUG-024 fixed — SwiftData save failures now roll back pending context changes so failed inserts/edits/deletes cannot leak into later successful saves |
| 2026-06-02 | ✅ PlaceholderViews.swift + WelcomeView.swift | BUG-025 fixed — Pre-Registration Admin add form now only clears after a confirmed successful save, preserving entered data when persistence fails |
| 2026-06-02 | ✅ PlaceholderViews.swift | BUG-026 fixed — induction registration now opens the pre-filled handwritten signature sheet again before completing the sign-in flow |
| 2026-06-02 | ✅ PlaceholderViews.swift + WelcomeView.swift | BUG-027 fixed — settings admin action renamed from misleading "Sign Out Now" to "Lock Admin Session" because it only invalidates the PIN session |
| 2026-06-02 | ✅ Models.swift | BUG-028 fixed — removed unused `VisitorStore.signBackIn` helper that had no reachable UI/action path |

---

## Completed UI Improvements (2026-03-24)

| Date | Area | Change |
|---|---|---|
| 2026-03-24 | ✅ 'WelcomeView` — `BrandHeader` | Logo now displayed on a white rounded-rect backing with shadow so it is clearly visible against the dark CEMEX blue gradient |
| 2026-03-24 | ✅ 'WelcomeView` — `BrandHeader` | Added a light blue-grey accent strip (`#DCE6F8` → system grouped background) below the blue band to provide visual contrast and a smoother transition into the form card |
| 2026-03-24 | ✅ 'WelcomeView` — `InductionFlowView` | Replaced the tick-box acknowledgement with a **"Tap here to sign"** button that opens a full-height signature sheet |
| 2026-03-24 | ✅ 'WelcomeView` — `InductionSignatureSheet` (new) | New sheet presents a clear "Confirm Understanding" heading, body text, and the visitor's first + last name rendered in `BradleyHandITCTT-Bold` (closest built-in iOS equivalent to Kalam) at 58pt with a spring-in animation |
| 2026-03-24 | ✅ 'WelcomeView` — `InductionSignatureSheet` | "I Agree" button triggers `onComplete(true)` directly — the registration confirmation alert fires immediately without any intermediate screen |
| 2026-03-24 | ✅ `WelcomeView` — `InductionFlowView` | Removed intermediate "Signed by / Confirm and Continue" step; `isSigned` state deleted; flow is now: slides → sign sheet → confirmation alert |

---
