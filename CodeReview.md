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
| BUG-061 | 🟠 HIGH | WelcomeView.swift | Auto-checkout also returns all active staff pager issues without confirmation when running (performAutoCheckoutNow); may surprise operations | `performAutoCheckoutNow` loops `activeStaffPagerIssues` and returns them en masse |
| BUG-047 | 🟠 HIGH | AnalyticsDashboardView.swift | Heatmap weekday mapping logic is confusing/inconsistent; counts keyed by raw weekday (Sun=1..Sat=7) but rendered in Mon..Sun order with remapped indices — risk of mislabeled rows in non-English locales | See comments in `heatmapMatrix(for:)` around `orderedWeekdays` and label index math; verify `shortWeekdaySymbols` indexing and mapping correctness |
| BUG-054 | 🟡 MEDIUM | AnalyticsDashboardView.swift | Heatmap data emptiness check uses `matrix.allSatisfy({ $0.count == 0 })` which is incorrect because `matrix` is an array of tuples, not arrays; the condition is always false | The closure references `$0.count` on a tuple; should check aggregated counts instead (e.g., `matrix.allSatisfy { $0.count == 0 }` is invalid at compile time or misleading if compiled) |
| BUG-048 | 🟡 MEDIUM | VisitorTabs.swift + WelcomeView.swift | CSV export logic duplicated with different headers/columns; risk of divergence and inconsistent backups/exports | `VisitorTabs.ArchivedVisitorsView.exportCSV()` vs `WelcomeView.exportCSV(from:)` produce different schemas |
| BUG-049 | 🟡 MEDIUM | WelcomeView.swift | Backup scheduler time is hardcoded to 06:00 and not coupled to settings segmented control; no user-configurable time like auto-checkout | `startBackupScheduler()` uses `scheduleDailyBackup(atHour: 6, minute: 0)` while settings only toggles enable |
| BUG-058 | 🟡 MEDIUM | WelcomeView.swift | `allocatedBadges(on:)` assumes `PreRegisteredVisitor.visitDate` exists; if schema differs, fallback to `createdAt` may cause false conflicts | Comment notes assumption; enforce via model or guard logic |
| BUG-062 | 🟡 MEDIUM | AdminAndUtilitiesViews.swift | `PreRegistrationAdminView` local badge conflict check compares raw badge strings; case/whitespace not normalized | Use trimmed/lowercased normalization to match other checks |
| BUG-065 | 🟡 MEDIUM | AdminAndUtilitiesViews.swift | `ReturningVisitorSearchView` dedup key uses lowercased names only; company changes may merge different people with same name; consider including company | Dedup key: `first|last` only |
| BUG-067 | 🟡 MEDIUM | WelcomeView.swift | `fileImporter` allowed content types include very broad `.data` and `.text`; may surface irrelevant files | Consider restricting to CSV UTTypes only |
| BUG-070 | 🟡 MEDIUM | WelcomeView.swift | `pendingSubmit`/`hasRoutedToInduction`/`showPagerPrompt` interplay is complex; race risk remains if alert and sheet overlap; consider unifying via a small state machine | Complex guard in `routeToInductionIfReady()` |
| BUG-050 | 🟡 MEDIUM | AdminAndUtilitiesViews.swift | Settings strings and some labels remain hardcoded and not localized | Examples: "Backup Now", "Import CSV…", "Open Analytics", section titles, etc. |
| BUG-051 | 🟢 LOW | AdminAndUtilitiesViews.swift | DateFormatter created per-row in `PreRegisteredListView` (`dateOnlyFormatter`) instead of a static cached formatter | `private var dateOnlyFormatter` creates new instance each access |
| BUG-052 | 🟢 LOW | WelcomeView.swift | Accessibility: primary actions lack explicit accessibility labels/hints and large content size adjustments | Buttons like Register/I'm Leaving/Fire Alarm shortcut rely on visible labels only; add `.accessibilityLabel`/`.accessibilityHint` and ensure min hit size |
| BUG-053 | 🟢 LOW | WelcomeView.swift | `AnalyticsDashboardView` export error alert is partially localized but strings like title/message in AnalyticsDashboard are still hardcoded | In `AnalyticsDashboardView`, alert title "Export Failed" and message are literal strings |
| BUG-055 | 🟢 LOW | AdminAndUtilitiesViews.swift | `ActivityView` wrapper is compiled only under canImport(UIKit) but file also imports UIKit at top-level; on macOS builds this can warn; consider moving import inside `#if canImport(UIKit)` | Top-level `import UIKit` with `#if canImport(UIKit)` guard below |
| BUG-057 | 🟢 LOW | VisitorTabs.swift | Share temporary file removal relies on `onDismiss` but `ShareLink` may keep strong refs; ensure cleanup on all paths; also duplication of `ShareItem` type name with WelcomeView's nested `ShareItem` | Potential confusion between two `ShareItem` structs; consider centralizing share helpers |
| BUG-059 | 🟢 LOW | AdminAndUtilitiesViews.swift | `SignInBookView` uses `id: \.self` for `ForEach(activeVisitors, id: \.self)`; rely on model identity (`.id`) instead to avoid identity instability | Use `ForEach(activeVisitors, id: \.id)` |
| BUG-060 | 🟢 LOW | WelcomeView.swift | Multiple `.tint(.cemexBlue)` and custom shadows repeated; consider extracting a small `Theme` for consistent styling | Repetition across buttons and cards |
| BUG-063 | 🟢 LOW | AnalyticsDashboardView.swift | Some summary card titles are not localized (e.g., "Car Visitors", "Blocked Car", "Same-day Checkout", etc.) | Mix of localized and hardcoded strings in `summaryGrid` |
| BUG-064 | 🟢 LOW | WelcomeView.swift | `kioskMode` confirm alert strings are hardcoded and not localized | In `.kioskConfirm` alert case, titles and buttons are literals |
| BUG-066 | 🟢 LOW | VisitorTabs.swift | `VisitorDetail` destructive checkout has no confirmation prompt unlike SignIn Book; risk of accidental checkout | Button("Mark as Leaving") directly calls `checkOut` |
| BUG-068 | 🟢 LOW | AnalyticsDashboardView.swift | `ShareItem` type reused from elsewhere but not defined in this file; relies on external definition/import order; make local or centralize | `@State private var shareItem: ShareItem?` without local definition |
| BUG-069 | 🟢 LOW | AdminAndUtilitiesViews.swift | `ImportConfirmationView` UI is minimal and non-localized; lacks counts formatting and accessibility | Strings are literals; improve presentation |
