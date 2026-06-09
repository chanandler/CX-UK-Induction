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
| BUG-044 | 🟢 LOW | Models.swift | `dupKey` normalizes to minute precision but uses `timeIntervalSinceReferenceDate` (Double) which still includes seconds component from constructed minute | The constructed date uses only Y-M-D-H-M, which is fine, but documenting the rationale would help; alternatively store an Int minute timestamp to avoid float comparisons. |
| BUG-045 | 🟡 MEDIUM | WelcomeView.swift | Kiosk mode banner auto-hide task not cancelled on view disappear | `.task` in `checkoutBanner` and kiosk banner hide task rely on Task cancellation by scope; ensure cancellation when view disappears or when state flips to avoid lingering async work. |
| BUG-046 | 🟢 LOW | AdminAndUtilitiesViews.swift | `StaffCarPagerSheet` has `hasAttemptedSave` dead state | `hasAttemptedSave` is set but never toggled in current code path; either remove or use to show validation error when tapping a disabled Save. |
| BUG-047 | 🟡 MEDIUM | Models.swift | `addPreRegisteredVisitor` performs two full fetches for conflict checks | Consider narrowing fetch with predicates or using a single fetch to reduce IO; or pre-index normalized badges by day. |
| BUG-048 | 🟢 LOW | AdminAndUtilitiesViews.swift | `ImportConfirmationView` uses generic "Error" handling pattern elsewhere but here has no explicit error state | If commit fails, the presenting code handles `store.lastError`; consider consistent messaging inside the view or ensure all error paths are centralized. |

---

## Completed Issues

| Date | File | Issue |
|---|---|---|
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

