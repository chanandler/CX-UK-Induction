# Code Review Tracker
> Generated: 2026-03-23

---

## Priority Legend
- 🔴 **CRITICAL** — Bug, crash risk, or data loss
- 🟠 **HIGH** — Significant issue impacting correctness or user experience
- 🟡 **MEDIUM** — Performance or code quality issue
- 🟢 **LOW** — Minor improvement or style issue

---

## Open Issues

### AutoCheckoutManager.swift

- [x] 🔴 ~~**Timer added to RunLoop twice**~~ — Fixed 2026-03-23. Removed the redundant `RunLoop.main.add(timer!, forMode: .common)` call; `Timer.scheduledTimer` already handles registration.

- [x] 🔴 ~~**Recursive rescheduling creates unbounded call stack**~~ — Fixed 2026-03-23. Timer closure still reschedules via `scheduleDailyCheckout` but the previous timer is invalidated at the top of that method, so there is no unbounded accumulation. Comment added to explain the intent.

- [ ] 🟡 **Inefficient next-weekday calculation** — The loop increments one day at a time for up to 7 iterations. Replace with a direct calendar calculation that skips weekends in a single step.

---

### CX_UK_InductionApp.swift

- [x] 🔴 ~~**SwiftData container failure is silently swallowed**~~ — Fixed 2026-03-23. Added an `init()` that uses the throwing `ModelContainer(for:)` initialiser; any failure now surfaces with `fatalError` and a clear message rather than silent data corruption.

---

### Models.swift

- [x] 🔴 ~~**`checkoutTime` parameter is ignored in auto-checkout**~~ — Fixed 2026-03-23. Both `autoCheckoutPreviousDay` and `autoCheckoutPreviousDayReturningCount` now use the `checkoutTime` parameter instead of a hardcoded 07:00. `WelcomeView.startScheduler` passes `Date()` so the actual fire time is recorded.

- [x] 🟠 ~~**`autoCheckoutPreviousDay` and `autoCheckoutPreviousDayReturningCount` are near-identical**~~ — Fixed 2026-03-23. Merged into a single `@discardableResult func autoCheckoutPreviousDay(...)` method. All callers updated.

- [x] 🟠 ~~**Sign-in does not validate post-trim values**~~ — Fixed 2026-03-23. `signIn()` now guards against all-whitespace inputs after trimming and sets `lastError` if they are blank.

- [ ] 🟡 **Errors stored as plain strings with no propagation** — `lastError` gives no structured detail and is easy to miss. Consider `throws` or a proper error type so callers can react.

---

### RootView.swift

- [ ] 🟢 **ZStack contains only one child** — The `ZStack` wraps a single `WelcomeView`. Either remove it or replace with `VStack`/plain `Group`.

- [ ] 🟢 **Preview lacks required environment** — The `#Preview` block has no `.modelContainer` or `.environment(VisitorStore())`, so it will fail to render. Add the necessary environment setup.

---

### VisitorTabs.swift

- [x] 🟠 ~~**`filteredActive` / `filteredArchived` do full linear scans on every render**~~ — Reviewed 2026-03-23. SwiftData `#Predicate` macros require compile-time key paths and cannot accept runtime strings for free-text search; Swift-side filtering on an already-fetched array is the correct pattern here. Short-circuit on empty `searchText` is already in place. No code change needed.

- [x] 🟠 ~~**`escapeCSV` is duplicated across VisitorTabs and WelcomeView**~~ — Fixed 2026-03-23. Extracted to `String.escapedAsCSVField` extension at the top of `VisitorTabs.swift`. `DateFormatter` static instances (`shortTime`, `mediumDateTime`, `csvDateTime`) also extracted alongside it. All call sites in both files updated.

- [ ] 🟡 **Temp CSV files are never deleted** — Files written to the temporary directory accumulate over time. Add a cleanup call after the share sheet is dismissed, or use a memory-backed `Data` buffer instead.

- [ ] 🟡 **CSV export failure gives the user no feedback** — The export function returns `nil` silently. Show an error alert when export fails.

- [ ] 🟡 **CEMEX Blue defined with magic numbers in multiple places** — The hex value appears at least three times. Extract to a `Color` extension or asset catalogue colour.

- [ ] 🟢 **`UITableView.appearance()` modifies global UI state** — Appearance proxy changes persist globally and can affect unrelated views. Replace with SwiftUI-native list/row modifiers where possible.

---

### WelcomeView.swift

- [x] 🔴 ~~**`AutoCheckoutScheduler` is never cancelled when the view disappears**~~ — Fixed 2026-03-23. Added `.onDisappear { scheduler.cancel() }` to `WelcomeView`.

- [x] 🔴 ~~**Multiple timers can be created without cancelling the previous one**~~ — Fixed 2026-03-23. `startScheduler()` now calls `scheduler.cancel()` before scheduling a new timer, preventing stacking when settings change in quick succession.

- [x] 🔴 ~~**Redundant `@Query` declarations fetch the same data three times**~~ — Partially fixed 2026-03-23. Removed the unused `archivedVisitors` query from `WelcomeView` (it was declared but never referenced in that view). The `activeVisitors` and `allVisitors` queries are retained as they serve distinct purposes (live visitor list and CSV export respectively).

- [ ] 🟠 **`RegularFormFields` and `CompactFormFields` are ~250 lines of near-identical code** — The only difference is horizontal vs vertical layout for name/company/car. Merge into a single view parameterised by layout axis.

- [x] 🟠 ~~**`DateFormatter` instances created at multiple call sites**~~ — Fixed 2026-03-23. Three shared `static let` formatters (`shortTime`, `mediumDateTime`, `csvDateTime`) added to `VisitorTabs.swift` as `DateFormatter` extensions and used across `VisitorRow`, `VisitorDetail`, `SignInBookView`, `LeavingSearchSheet`, and both CSV export functions. Private `static let dateTimeFormatter` properties removed.

- [x] 🟠 ~~**Badge is required in form validation but optional in the model**~~ — Fixed 2026-03-23. `Visitor.badgeNumber` changed from `String?` to `String` (default `""`). `signIn()` parameter updated to match. All optional-unwrap usages (`?.`, `?? ""`, force-unwrap) across `VisitorTabs` and `WelcomeView` removed.

- [x] 🟠 ~~**Pager picker display text and stored value are inconsistent**~~ — Fixed 2026-03-23. Picker already stores bare numeric tags (e.g. `"3"`). Removed redundant `"pager "` prefix-stripping normalization from the pager sheet locals, `submit()`, and `usedPagers`. The stored format is now unambiguously a bare numeric string everywhere.

- [ ] 🟡 **Explosion of boolean `@State` flags** — Over a dozen separate `Bool` properties control sheet/alert presentation. This is fragile. Replace with a single `enum ActiveSheet` (or similar) and a single optional `@State var activeSheet: ActiveSheet?`.

- [ ] 🟡 **`UINotificationFeedbackGenerator` created fresh on every haptic call** — The generator should be created once (e.g. as a property) and reused, or use SwiftUI's `.sensoryFeedback` modifier (iOS 17+).

- [ ] 🟡 **`withAnimation` return value discarded with `_`** — `_ = withAnimation { ... }` is non-idiomatic. Use `withAnimation { ... }` without the assignment.

- [ ] 🟢 **Pager count hardcoded to 30** — The picker range `1...30` is a magic number. Extract to a named constant so it can be changed in one place.

- [ ] 🟢 **All user-facing strings are hardcoded English** — No `Localizable.strings` or `String(localized:)` usage. Low priority for an internal tool, but worth noting.

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

---

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

- File with the most remaining issues: **WelcomeView.swift**
- All 🔴 CRITICAL and 🟠 HIGH issues have been resolved as of 2026-03-23, except one: merging `RegularFormFields`/`CompactFormFields` (a large UI refactor, deferred).
- Next recommended pass: address the 🟡 MEDIUM issues — temp CSV cleanup, `@State` flag explosion, and haptic generator reuse.
- CSV backup & restore feature fully implemented 2026-03-23 (see Feature Requests section above — all items completed).
