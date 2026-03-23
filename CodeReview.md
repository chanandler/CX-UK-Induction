# Code Review Tracker
> Generated: 2026-03-23 | Reviewer: Claude Code

---

## Priority Legend
- 🔴 **CRITICAL** — Bug, crash risk, or data loss
- 🟠 **HIGH** — Significant issue impacting correctness or user experience
- 🟡 **MEDIUM** — Performance or code quality issue
- 🟢 **LOW** — Minor improvement or style issue

---

## Open Issues

### AutoCheckoutManager.swift

- [ ] 🔴 **Timer added to RunLoop twice** — `Timer.scheduledTimer` already registers itself; calling `RunLoop.main.add(timer!, forMode: .common)` adds it again, causing double-firing. Remove the explicit `RunLoop.main.add` call.

- [ ] 🔴 **Recursive rescheduling creates unbounded call stack** — The timer callback calls `scheduleDailyCheckout()` on itself each time it fires. Replace with a properly calculated repeating or one-shot timer that does not recurse.

- [ ] 🟡 **Inefficient next-weekday calculation** — The loop increments one day at a time for up to 7 iterations. Replace with a direct calendar calculation that skips weekends in a single step.

---

### CX_UK_InductionApp.swift

- [ ] 🔴 **SwiftData container failure is silently swallowed** — `.modelContainer(for: Visitor.self)` has no error handling; if the container fails to initialise the app launches with a broken data layer. Use the throwing `ModelContainer(for:)` initialiser in `init()` so failures surface explicitly.

---

### Models.swift

- [ ] 🔴 **`checkoutTime` parameter is ignored in auto-checkout** — `autoCheckoutPreviousDay()` always sets checkout to 07:00 regardless of the value passed. Either use the parameter or remove it.

- [ ] 🟠 **`autoCheckoutPreviousDay` and `autoCheckoutPreviousDayReturningCount` are near-identical** — ~50 lines of duplicated logic; the only difference is the return value. Merge into one method with a discardable return.

- [ ] 🟠 **Sign-in does not validate post-trim values** — `signIn()` trims whitespace but never checks that the trimmed result is non-empty, allowing blank entries to be saved.

- [ ] 🟡 **Errors stored as plain strings with no propagation** — `lastError` gives no structured detail and is easy to miss. Consider `throws` or a proper error type so callers can react.

---

### RootView.swift

- [ ] 🟢 **ZStack contains only one child** — The `ZStack` wraps a single `WelcomeView`. Either remove it or replace with `VStack`/plain `Group`.

- [ ] 🟢 **Preview lacks required environment** — The `#Preview` block has no `.modelContainer` or `.environment(VisitorStore())`, so it will fail to render. Add the necessary environment setup.

---

### VisitorTabs.swift

- [ ] 🟠 **`filteredActive` / `filteredArchived` do full linear scans on every render** — Filtering happens in Swift rather than at the SwiftData query level. Move filtering into `@Query` predicates so the database does the work.

- [ ] 🟠 **`escapeCSV` is duplicated across VisitorTabs and WelcomeView** — Extract to a shared `extension String` or a utility file.

- [ ] 🟡 **Temp CSV files are never deleted** — Files written to the temporary directory accumulate over time. Add a cleanup call after the share sheet is dismissed, or use a memory-backed `Data` buffer instead.

- [ ] 🟡 **CSV export failure gives the user no feedback** — The export function returns `nil` silently. Show an error alert when export fails.

- [ ] 🟡 **CEMEX Blue defined with magic numbers in multiple places** — The hex value appears at least three times. Extract to a `Color` extension or asset catalogue colour.

- [ ] 🟢 **`UITableView.appearance()` modifies global UI state** — Appearance proxy changes persist globally and can affect unrelated views. Replace with SwiftUI-native list/row modifiers where possible.

---

### WelcomeView.swift

- [ ] 🔴 **`AutoCheckoutScheduler` is never cancelled when the view disappears** — The scheduler is started in `onAppear` but there is no matching `onDisappear { scheduler.cancel() }`. The timer runs indefinitely after the view is removed, leaking memory and continuing to fire.

- [ ] 🔴 **Multiple timers can be created without cancelling the previous one** — Several `onChange` handlers call `startScheduler()`. If settings are changed in quick succession, each call stacks a new timer on top of the last without cancelling existing ones. Cancel before starting: `scheduler.cancel(); scheduler = ...; scheduler.start()`.

- [ ] 🔴 **Redundant `@Query` declarations fetch the same data three times** — Three separate `@Query` properties hit the database for overlapping datasets. Keep one query and derive filtered subsets as computed properties.

- [ ] 🟠 **`RegularFormFields` and `CompactFormFields` are ~250 lines of near-identical code** — The only difference is horizontal vs vertical layout for name/company/car. Merge into a single view parameterised by layout axis.

- [ ] 🟠 **`DateFormatter` instances created at multiple call sites** — `DateFormatter` is expensive to initialise. Several locations create their own instances (including inside loops). Consolidate into one or two `static let` formatters.

- [ ] 🟠 **Badge is required in form validation but optional in the model** — `isValid` enforces a non-empty badge, but `Visitor.badgeNumber` is optional. Decide on a single source of truth and align the model, validation, and UI.

- [ ] 🟠 **Pager picker display text and stored value are inconsistent** — The picker shows `"Pager \(i)"` (string with prefix) but the stored value strips the prefix. The two representations can diverge. Store and display the same format, or make the transformation explicit and one-directional.

- [ ] 🟡 **Explosion of boolean `@State` flags** — Over a dozen separate `Bool` properties control sheet/alert presentation. This is fragile. Replace with a single `enum ActiveSheet` (or similar) and a single optional `@State var activeSheet: ActiveSheet?`.

- [ ] 🟡 **`UINotificationFeedbackGenerator` created fresh on every haptic call** — The generator should be created once (e.g. as a property) and reused, or use SwiftUI's `.sensoryFeedback` modifier (iOS 17+).

- [ ] 🟡 **`withAnimation` return value discarded with `_`** — `_ = withAnimation { ... }` is non-idiomatic. Use `withAnimation { ... }` without the assignment.

- [ ] 🟢 **Pager count hardcoded to 30** — The picker range `1...30` is a magic number. Extract to a named constant so it can be changed in one place.

- [ ] 🟢 **All user-facing strings are hardcoded English** — No `Localizable.strings` or `String(localized:)` usage. Low priority for an internal tool, but worth noting.

---

## Completed Issues

_Nothing resolved yet._

---

## Notes

- File with the most issues: **WelcomeView.swift** (1 411 lines)
- Highest-priority single fix: **add `onDisappear { scheduler.cancel() }` in WelcomeView** — prevents a timer memory leak with no functional downside.
- Two bugs interact: the recursive timer in `AutoCheckoutManager` **and** the missing cancel in `WelcomeView` both need fixing together to fully resolve the scheduler lifecycle.
