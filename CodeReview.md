# Code Review Tracker
> Generated: 2026-03-23 | Last updated: 2026-06-09

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
| BUG-047 | 🟠 HIGH | AnalyticsDashboardView.swift | Heatmap weekday mapping logic is confusing/inconsistent; counts keyed by raw weekday (Sun=1..Sat=7) but rendered in Mon..Sun order with remapped indices — risk of mislabeled rows in non-English locales | See comments in `heatmapMatrix(for:)` around `orderedWeekdays` and label index math; verify `shortWeekdaySymbols` indexing and mapping correctness |
| BUG-048 | 🟡 MEDIUM | VisitorTabs.swift + WelcomeView.swift | CSV export logic duplicated with different headers/columns; risk of divergence and inconsistent backups/exports | `VisitorTabs.ArchivedVisitorsView.exportCSV()` vs `WelcomeView.exportCSV(from:)` produce different schemas |
| BUG-049 | 🟡 MEDIUM | WelcomeView.swift | Backup scheduler time is hardcoded to 06:00 and not coupled to settings segmented control; no user-configurable time like auto-checkout | `startBackupScheduler()` uses `scheduleDailyBackup(atHour: 6, minute: 0)` while settings only toggles enable |
| BUG-050 | 🟡 MEDIUM | AdminAndUtilitiesViews.swift | Settings strings and some labels remain hardcoded and not localized | Examples: "Backup Now", "Import CSV…", "Open Analytics", section titles, etc. |
| BUG-051 | 🟢 LOW | AdminAndUtilitiesViews.swift | DateFormatter created per-row in `PreRegisteredListView` (`dateOnlyFormatter`) instead of a static cached formatter | `private var dateOnlyFormatter` creates new instance each access |
| BUG-052 | 🟢 LOW | WelcomeView.swift | Accessibility: primary actions lack explicit accessibility labels/hints and large content size adjustments | Buttons like Register/I'm Leaving/Fire Alarm shortcut rely on visible labels only; add `.accessibilityLabel`/`.accessibilityHint` and ensure min hit size |
| BUG-053 | 🟢 LOW | WelcomeView.swift | `AnalyticsDashboardView` export error alert is partially localized but strings like title/message in AnalyticsDashboard are still hardcoded | In `AnalyticsDashboardView`, alert title "Export Failed" and message are literal strings |
| BUG-054 | 🟡 MEDIUM | AnalyticsDashboardView.swift | Heatmap data emptiness check uses `matrix.allSatisfy({ $0.count == 0 })` which is incorrect because `matrix` is an array of tuples, not arrays; the condition is always false | The closure references `$0.count` on a tuple; should check aggregated counts instead (e.g., `matrix.allSatisfy { $0.count == 0 }` is invalid at compile time or misleading if compiled) |
| BUG-055 | 🟢 LOW | AdminAndUtilitiesViews.swift | `ActivityView` wrapper is compiled only under canImport(UIKit) but file also imports UIKit at top-level; on macOS builds this can warn; consider moving import inside `#if canImport(UIKit)` | Top-level `import UIKit` with `#if canImport(UIKit)` guard below |
| BUG-056 | 🟡 MEDIUM | WelcomeView.swift | Potential logic nit: `prefillFromPreRegistered` and `prefillFromReturningVisitor` set `activeAlert = .blockedCarPrompt` when a car registration is provided but also set `blockedCar = false`; may present pager prompt without marking as blocked | In both prefill methods, providing `droveCarRegistration` triggers blocked-car prompt while `blockedCar` is false |
| BUG-057 | 🟢 LOW | VisitorTabs.swift | Share temporary file removal relies on `onDismiss` but `ShareLink` may keep strong refs; ensure cleanup on all paths; also duplication of `ShareItem` type name with WelcomeView's nested `ShareItem` | Potential confusion between two `ShareItem` structs; consider centralizing share helpers |
| BUG-058 | 🟡 MEDIUM | WelcomeView.swift | `allocatedBadges(on:)` assumes `PreRegisteredVisitor.visitDate` exists; if schema differs, fallback to `createdAt` may cause false conflicts | Comment notes assumption; enforce via model or guard logic |
| BUG-059 | 🟢 LOW | AdminAndUtilitiesViews.swift | `SignInBookView` uses `id: \.self` for `ForEach(activeVisitors, id: \.self)`; rely on model identity (`.id`) instead to avoid identity instability | Use `ForEach(activeVisitors, id: \.id)` |
| BUG-060 | 🟢 LOW | WelcomeView.swift | Multiple `.tint(.cemexBlue)` and custom shadows repeated; consider extracting a small `Theme` for consistent styling | Repetition across buttons and cards |
| BUG-061 | 🟠 HIGH | WelcomeView.swift | Auto-checkout also returns all active staff pager issues without confirmation when running (performAutoCheckoutNow); may surprise operations | `performAutoCheckoutNow` loops `activeStaffPagerIssues` and returns them en masse |
| BUG-062 | 🟡 MEDIUM | AdminAndUtilitiesViews.swift | `PreRegistrationAdminView` local badge conflict check compares raw badge strings; case/whitespace not normalized | Use trimmed/lowercased normalization to match other checks |
| BUG-063 | 🟢 LOW | AnalyticsDashboardView.swift | Some summary card titles are not localized (e.g., "Car Visitors", "Blocked Car", "Same-day Checkout", etc.) | Mix of localized and hardcoded strings in `summaryGrid` |
| BUG-064 | 🟢 LOW | WelcomeView.swift | `kioskMode` confirm alert strings are hardcoded and not localized | In `.kioskConfirm` alert case, titles and buttons are literals |
| BUG-065 | 🟡 MEDIUM | AdminAndUtilitiesViews.swift | `ReturningVisitorSearchView` dedup key uses lowercased names only; company changes may merge different people with same name; consider including company | Dedup key: `first|last` only |
| BUG-066 | 🟢 LOW | VisitorTabs.swift | `VisitorDetail` destructive checkout has no confirmation prompt unlike SignIn Book; risk of accidental checkout | Button("Mark as Leaving") directly calls `checkOut` |
| BUG-067 | 🟡 MEDIUM | WelcomeView.swift | `fileImporter` allowed content types include very broad `.data` and `.text`; may surface irrelevant files | Consider restricting to CSV UTTypes only |
| BUG-068 | 🟢 LOW | AnalyticsDashboardView.swift | `ShareItem` type reused from elsewhere but not defined in this file; relies on external definition/import order; make local or centralize | `@State private var shareItem: ShareItem?` without local definition |
| BUG-069 | 🟢 LOW | AdminAndUtilitiesViews.swift | `ImportConfirmationView` UI is minimal and non-localized; lacks counts formatting and accessibility | Strings are literals; improve presentation |
| BUG-070 | 🟡 MEDIUM | WelcomeView.swift | `pendingSubmit`/`hasRoutedToInduction`/`showPagerPrompt` interplay is complex; race risk remains if alert and sheet overlap; consider unifying via a small state machine | Complex guard in `routeToInductionIfReady()` |

---

## Completed Issues

| Date | File | Issue |
|---|---|---|
| 2026-06-09 | ✅ WelcomeView.swift | BUG-045 fixed — Kiosk banner auto-hide task is now cancelled on disappear and when hidden; task handle stored and managed to prevent leaks |
| 2026-06-09 | ✅ AdminAndUtilitiesViews.swift | BUG-046 fixed — "Issue Pager" button is now always visible; tapping sets hasAttemptedSave and shows validation errors until form is valid |
| 2026-06-09 | ✅ Models.swift | BUG-044 fixed — Duplicate key now uses integer minutes-since-reference instead of Double to avoid precision issues; documented rationale |
| 2026-06-09 | ✅ VisitorTabs.swift | BUG-043 fixed — Removed UIKit ClearBackgroundView hack; rely on .scrollContentBackground(.hidden) and clear backgrounds to avoid flicker |
| 2026-06-09 | ✅ WelcomeView.swift | BUG-042 fixed — Consolidated multiple alerts into a single enum-driven router with one .alert(item:) presentation to reduce decorator chain complexity |
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

## Enhancement Ideas (New)

- Consolidate alert/sheet presentation in WelcomeView via a single enum-driven router to reduce state coupling and race conditions.
- Extract pager management into a small `PagerManager` helper (usedPagers, recentlyFreedPagers grace window, issue/return helpers) to simplify WelcomeView.
- Add accessibility labels/hints for critical buttons (Register, I'm Leaving, Fire Alarm Roll Call) and ensure minimum hit size.
- Localize remaining hardcoded strings in AdminAndUtilitiesViews.swift (e.g., "Import Preview", "Confirm", "Cancel", etc.).
- Consider adding unit tests using Swift Testing for CSV parsing edge cases and duplicate detection logic.
- Add a small `Theme` layer for light/dark tokens and reuse across VisitorTabs cards and WelcomeView cards.
- Add structured analytics export (JSON) alongside CSV for downstream processing.
- Consider using `.task(id:)` cancellation tokens for kiosk banner/checkout banner to guarantee cleanup on state change.
- Review backup retention policy (30 days) as a setting surfaced in Settings.
- Consider a small `AppStrings` centralization for common labels and reuse across flows.

---

