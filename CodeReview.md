# Code Review Tracker
> Generated: 2026-03-23 | Last updated: 2026-04-25

---

## Priority Legend
- 🔴 **CRITICAL** — Bug, crash risk, or data loss
- 🟠 **HIGH** — Significant issue impacting correctness or user experience
- 🟡 **MEDIUM** — Performance or code quality issue
- 🟢 **LOW** — Minor improvement or style issue

---

## Open Issues

---

### VisitorTabs.swift

### WelcomeView.swift

- [ ] 🟠 **Analytics launch from Settings is timing-dependent (`DispatchQueue.main.asyncAfter`)** — Opening Analytics from `AutoCheckoutSettingsView` currently relies on a fixed `0.2s` delay before calling `requestProtectedAccess(for: .analytics)` (`WelcomeView.swift:217`). This can race on slower devices, different animation settings, or future sheet transition changes and intermittently fail to open the gate/dashboard. Replace with deterministic sheet-state sequencing (e.g. drive from a dedicated pending action state and trigger on dismiss completion rather than a hardcoded delay).

### Models.swift

- [ ] 🟠 **CSV import breaks quoted multiline fields due pre-splitting by newline** — `previewImport` splits raw CSV using `components(separatedBy: CharacterSet.newlines)` before row parsing (`Models.swift:213`), but `parseCSVLine` only parses a single line (`Models.swift:338`). Any valid quoted field containing embedded newlines will be split into multiple pseudo-rows, producing false failures and potential data corruption. Implement a record-level parser that respects quote state across line breaks before field tokenization.

### PINSecurity.swift

- [ ] 🟡 **PIN verification has no brute-force throttling or lockout** — `PinGateSheet.submit()` allows unlimited rapid retries (`PINSecurity.swift:144`) with immediate feedback and no cooldown. Because this gate protects settings/export/sign-in-book/fire roll-call/admin analytics, add attempt throttling (e.g. exponential backoff, temporary lockout after N failures, and optional persistent fail counter) to reduce brute-force risk on unattended kiosks.

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
| 2026-04-22 | WelcomeView.swift | Validation errors now gated by `hasAttemptedSubmit` (no initial red state) |
| 2026-04-25 | RootView.swift | Preview lacks required environment — added `.modelContainer(for: Visitor.self, inMemory: true)` and `.environment(VisitorStore())` |
| 2026-04-25 | VisitorTabs.swift | `UITableView.appearance()` global UI state removed — replaced lifecycle appearance proxy mutation with local SwiftUI list/form styling only |
| 2026-04-25 | WelcomeView.swift | BUG-001 pager count magic number removed — `1...30` extracted to `availablePagerRange` constant |
| 2026-04-25 | Models.swift + PINSecurity.swift + VisitorTabs.swift + Localizable.strings | BUG-002 localization baseline added — introduced `Localizable.strings` and replaced key user-facing error/alert strings with `String(localized:)` |
| 2026-04-25 | WelcomeView.swift | BUG-003 `LeavingSearchSheet` snapshot freeze fixed — `snapshot` changed to optional and `filtered` now uses `snapshot ?? activeVisitors` |
| 2026-04-25 | WelcomeView.swift | BUG-004 `SignInBookView.onCheckedOut` dead callback fixed — added active-row checkout action that calls `store.checkOut` and `onCheckedOut(visitor.fullName)` |
| 2026-04-25 | WelcomeView.swift | BUG-005 misleading method name fixed — `showSignedOutBannerTemporarily()` renamed to `showSignedOutBanner()` |
| 2026-04-25 | WelcomeView.swift | BUG-006 badge keyboard focus chain fixed — added keyboard toolbar `Next` action to move focus from Badge Number to Car Registration |
| 2026-04-25 | WelcomeView.swift | BUG-007 signature font fallback hardened — now checks installed font availability and uses explicit fallback chain instead of silent `Font.custom` fallback |
| 2026-04-25 | WelcomeView.swift | BUG-008 empty induction content guard added — if `imageNames` is empty, flow now auto-cancels once via `onComplete(false)` |

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



- Current open issue counts: 2 🟠 HIGH, 1 🟡 MEDIUM, 0 🟢 LOW.
- The highest-priority remaining items are the CSV multiline import parsing bug (`Models.swift`) and timing-dependent analytics launch flow (`WelcomeView.swift`).
- Feature Idea 10 (Visitor Analytics Dashboard) is now implemented and marked complete.
