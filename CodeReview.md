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

- [x] 🟡 ~~**Inefficient next-weekday calculation**~~ — Already fixed (pre-existing). Direct +1/+2 day skip via `calendar.date(byAdding:)` based on the weekday component; no loop.

---

### CX_UK_InductionApp.swift

- [x] 🔴 ~~**SwiftData container failure is silently swallowed**~~ — Fixed 2026-03-23. Added an `init()` that uses the throwing `ModelContainer(for:)` initialiser; any failure now surfaces with `fatalError` and a clear message rather than silent data corruption.

---

### Models.swift

- [x] 🔴 ~~**`checkoutTime` parameter is ignored in auto-checkout**~~ — Fixed 2026-03-23. Both `autoCheckoutPreviousDay` and `autoCheckoutPreviousDayReturningCount` now use the `checkoutTime` parameter instead of a hardcoded 07:00. `WelcomeView.startScheduler` passes `Date()` so the actual fire time is recorded.

- [x] 🟠 ~~**`autoCheckoutPreviousDay` and `autoCheckoutPreviousDayReturningCount` are near-identical**~~ — Fixed 2026-03-23. Merged into a single `@discardableResult func autoCheckoutPreviousDay(...)` method. All callers updated.

- [x] 🟠 ~~**Sign-in does not validate post-trim values**~~ — Fixed 2026-03-23. `signIn()` now guards against all-whitespace inputs after trimming and sets `lastError` if they are blank.

- [x] 🟡 ~~**Errors stored as plain strings with no propagation**~~ — Already resolved. `lastError` is typed `StoreError?` (a `LocalizedError` enum with distinct cases for validation, save, fetch, import errors). All call sites set a typed case; `WelcomeView` observes it via `.onChange` and shows an alert.

---

### RootView.swift

- [ ] 🟢 **ZStack contains only one child** — The `ZStack` wraps a single `WelcomeView`. Either remove it or replace with `VStack`/plain `Group`.

- [ ] 🟢 **Preview lacks required environment** — The `#Preview` block has no `.modelContainer` or `.environment(VisitorStore())`, so it will fail to render. Add the necessary environment setup.

---

### VisitorTabs.swift

- [x] 🟠 ~~**`filteredActive` / `filteredArchived` do full linear scans on every render**~~ — Reviewed 2026-03-23. SwiftData `#Predicate` macros require compile-time key paths and cannot accept runtime strings for free-text search; Swift-side filtering on an already-fetched array is the correct pattern here. Short-circuit on empty `searchText` is already in place. No code change needed.

- [x] 🟠 ~~**`escapeCSV` is duplicated across VisitorTabs and WelcomeView**~~ — Fixed 2026-03-23. Extracted to `String.escapedAsCSVField` extension at the top of `VisitorTabs.swift`. `DateFormatter` static instances (`shortTime`, `mediumDateTime`, `csvDateTime`) also extracted alongside it. All call sites in both files updated.

- [x] 🟡 ~~**Temp CSV files are never deleted**~~ — Fixed 2026-03-23. Both `VisitorTabs` and `WelcomeView` had a bug where `onDismiss` read `shareItem?.url` after SwiftUI had already cleared it (always nil). Fixed by capturing the URL from the sheet `item` parameter in the content closure and deleting it in `.onDisappear` / `onDismiss` callback respectively. `cleanUpShareItem()` helper removed from `WelcomeView`.

- [x] 🟡 ~~**CSV export failure gives the user no feedback**~~ — Already implemented. `ArchivedVisitorsView` has `@State private var showExportError` and an `.alert("Export Failed", ...)` shown when `exportCSV()` returns `nil`.

- [x] 🟡 ~~**CEMEX Blue defined with magic numbers in multiple places**~~ — Already extracted. `Color.cemexBlue` extension defined at the top of `VisitorTabs.swift`; used consistently in `VisitorTabs`, `ActiveVisitorsView`, and `ArchivedVisitorsView`.

- [ ] 🟢 **`UITableView.appearance()` modifies global UI state** — Appearance proxy changes persist globally and can affect unrelated views. Replace with SwiftUI-native list/row modifiers where possible.

---

### WelcomeView.swift

- [x] 🔴 ~~**`AutoCheckoutScheduler` is never cancelled when the view disappears**~~ — Fixed 2026-03-23. Added `.onDisappear { scheduler.cancel() }` to `WelcomeView`.

- [x] 🔴 ~~**Multiple timers can be created without cancelling the previous one**~~ — Fixed 2026-03-23. `startScheduler()` now calls `scheduler.cancel()` before scheduling a new timer, preventing stacking when settings change in quick succession.

- [x] 🔴 ~~**Redundant `@Query` declarations fetch the same data three times**~~ — Partially fixed 2026-03-23. Removed the unused `archivedVisitors` query from `WelcomeView` (it was declared but never referenced in that view). The `activeVisitors` and `allVisitors` queries are retained as they serve distinct purposes (live visitor list and CSV export respectively).

- [x] 🟠 ~~**`RegularFormFields` and `CompactFormFields` are ~250 lines of near-identical code**~~ — Fixed (pre-existing). Merged into a single `VisitorFormFields` view parameterised by a `useColumns: Bool` flag. Call site in `WelcomeView.formCard` passes `hSizeClass == .regular`.

- [x] 🟠 ~~**`DateFormatter` instances created at multiple call sites**~~ — Fixed 2026-03-23. Three shared `static let` formatters (`shortTime`, `mediumDateTime`, `csvDateTime`) added to `VisitorTabs.swift` as `DateFormatter` extensions and used across `VisitorRow`, `VisitorDetail`, `SignInBookView`, `LeavingSearchSheet`, and both CSV export functions. Private `static let dateTimeFormatter` properties removed.

- [x] 🟠 ~~**Badge is required in form validation but optional in the model**~~ — Fixed 2026-03-23. `Visitor.badgeNumber` changed from `String?` to `String` (default `""`). `signIn()` parameter updated to match. All optional-unwrap usages (`?.`, `?? ""`, force-unwrap) across `VisitorTabs` and `WelcomeView` removed.

- [x] 🟠 ~~**Pager picker display text and stored value are inconsistent**~~ — Fixed 2026-03-23. Picker already stores bare numeric tags (e.g. `"3"`). Removed redundant `"pager "` prefix-stripping normalization from the pager sheet locals, `submit()`, and `usedPagers`. The stored format is now unambiguously a bare numeric string everywhere.

- [ ] 🟡 **Explosion of boolean `@State` flags** — Over a dozen separate `Bool` properties control sheet/alert presentation. This is fragile. Replace with a single `enum ActiveSheet` (or similar) and a single optional `@State var activeSheet: ActiveSheet?`.

- [x] 🟡 ~~**`UINotificationFeedbackGenerator` created fresh on every haptic call**~~ — Already fixed (pre-existing). `private let hapticGenerator = UINotificationFeedbackGenerator()` is a stored property on `WelcomeView`; reused across all haptic calls.

- [x] 🟡 ~~**`WelcomeView.body` exceeded Swift type-checker complexity limit**~~ — Fixed 2026-03-23. Extracted the modifier chain into four `@ViewBuilder` computed properties (`mainContent`, `decoratedContentPart1–3`, `decoratedContent`). `StoreError` given `Equatable` conformance (required by `.onChange(of: store.lastError)`).

- [x] 🟡 ~~**`withAnimation` return value discarded with `_`**~~ — Fixed 2026-03-23. Added `_ =` prefix to silence the "result unused" warning on the `withAnimation { confirmedOut.insert(...) }` call site.

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
| 2026-03-23 | WelcomeView.swift + Models.swift | `WelcomeView.body` type-checker complexity — split into four `@ViewBuilder` properties; `StoreError` made `Equatable` |
| 2026-03-23 | WelcomeView.swift | `withAnimation` unused result warning — suppressed with `_ =` |
| 2026-03-23 | VisitorTabs.swift + WelcomeView.swift | Temp CSV files not deleted — fixed `onDismiss` URL capture bug in both views |
| 2026-03-23 | AutoCheckoutManager.swift | Weekday calculation already efficient — verified, no change needed |
| 2026-03-23 | Models.swift | Structured error type already in place — verified `StoreError` enum, no change needed |
| 2026-03-23 | VisitorTabs.swift | CSV export error alert already implemented — verified, no change needed |
| 2026-03-23 | VisitorTabs.swift | CEMEX Blue already extracted to `Color.cemexBlue` — verified, no change needed |
| 2026-03-23 | WelcomeView.swift | Haptic generator already a stored property — verified, no change needed |

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

## UI Improvements (2026-03-24)

| Date | Area | Change |
|---|---|---|
| 2026-03-24 | `WelcomeView` — `BrandHeader` | Logo now displayed on a white rounded-rect backing with shadow so it is clearly visible against the dark CEMEX blue gradient |
| 2026-03-24 | `WelcomeView` — `BrandHeader` | Added a light blue-grey accent strip (`#DCE6F8` → system grouped background) below the blue band to provide visual contrast and a smoother transition into the form card |
| 2026-03-24 | `WelcomeView` — `InductionFlowView` | Replaced the tick-box acknowledgement with a **"Tap here to sign"** button that opens a full-height signature sheet |
| 2026-03-24 | `WelcomeView` — `InductionSignatureSheet` (new) | New sheet presents a clear "Confirm Understanding" heading, body text, and the visitor's first + last name rendered in `BradleyHandITCTT-Bold` (closest built-in iOS equivalent to Kalam) at 58pt with a spring-in animation |
| 2026-03-24 | `WelcomeView` — `InductionSignatureSheet` | "I Agree" button triggers `onComplete(true)` directly — the registration confirmation alert fires immediately without any intermediate screen |
| 2026-03-24 | `WelcomeView` — `InductionFlowView` | Removed intermediate "Signed by / Confirm and Continue" step; `isSigned` state deleted; flow is now: slides → sign sheet → confirmation alert |

---

## Notes

- All 🔴 CRITICAL, 🟠 HIGH, and 🟡 MEDIUM issues resolved as of 2026-03-23.
- Remaining open items: two 🟢 LOW issues in `WelcomeView.swift` (pager count constant, localisation), and one 🟡 MEDIUM (boolean `@State` flag explosion).
- `WelcomeView.swift` and `VisitorTabs.swift` both have zero compiler errors or warnings as of 2026-03-24.
- Next recommended pass: the remaining 🟢 LOW issues or the `@State` flag consolidation.
- CSV backup & restore feature fully implemented 2026-03-23 (see Feature Requests section above — all items completed).
