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

### VisitorTabs.swift

- [ ] 🟢 **`UITableView.appearance()` modifies global UI state** — Appearance proxy changes persist globally and can affect unrelated views. Replace with SwiftUI-native list/row modifiers where possible.

---

### WelcomeView.swift

- [ ] 🟢 **BUG-001: Pager count hardcoded to 30** — The picker range `1...30` is a magic number. Extract to a named constant so it can be changed in one place.

- [ ] 🟢 **BUG-002: All user-facing strings are hardcoded English** — No `Localizable.strings` or `String(localized:)` usage. Low priority for an internal tool, but worth noting.

- [ ] 🟡 **BUG-003: `LeavingSearchSheet.filtered` snapshot freeze fails when the initial visitor list is empty** — `let source = snapshot.isEmpty ? activeVisitors : snapshot` is used as a guard to freeze the list when the sheet opens. However, when the sheet opens with zero active visitors, `onAppear` sets `snapshot = []` (empty), so `snapshot.isEmpty` remains `true` forever. Any visitor who signs in while the sheet is open will immediately appear in the list, defeating the freeze intent. Fix: use an `Optional<[Visitor]>` (`var snapshot: [Visitor]? = nil`) and set it to `activeVisitors` (even `[]`) in `onAppear`; use `snapshot ?? activeVisitors` in `filtered`.

- [ ] 🟡 **BUG-004: `SignInBookView.onCheckedOut` callback is dead code** — The `onCheckedOut: (String) -> Void` parameter is accepted by `SignInBookView` but is never called anywhere within the view. The active-visitor list rows contain no checkout action. Either the callback should be removed from the API surface or a checkout button should be wired to it, otherwise callers set up a closure that can never fire.

- [ ] 🟢 **BUG-005: `showSignedOutBannerTemporarily()` name is misleading** — The method name implies a transient, self-dismissing banner, but there is no auto-dismiss timer; the banner persists until the user manually taps "Done". Rename the method to `showSignedOutBanner()` to accurately reflect its behaviour, or add a `DispatchQueue.main.asyncAfter` auto-dismiss (e.g. after 8 seconds) to match the implied semantics.

- [ ] 🟡 **BUG-006: `badgeField` uses `.keyboardType(.numberPad)` which voids the keyboard focus chain** — The badge number field has `.submitLabel(.next)` and `.onSubmit { focusedField.wrappedValue = .carReg }` applied, but the number pad keyboard on iOS shows no return key, so `onSubmit` is dead code for this field. Users cannot advance keyboard focus from the badge field to the car registration field and must tap it manually. Fix: keep `.keyboardType(.numberPad)` and add a keyboard toolbar "Next" button via `ToolbarItemGroup(placement: .keyboard) { Button("Next") { focusedField = .carReg } }`, or switch to `.keyboardType(.default)` which preserves the return key.

- [ ] 🟡 **BUG-007: `InductionSignatureSheet` relies on a custom font name that may silently fall back to system default** — `Text("\(firstName) \(lastName)").font(.custom("BradleyHandITCTT-Bold", size: 58))` calls `Font.custom(_:size:)`, which silently falls back to the default system font if the named font is not present on the device. If that happens the "signature" looks like regular body text rather than a handwritten name, which defeats the visual purpose of the sheet. Fix: either bundle the font file in the app target and register it under `UIAppFonts` in `Info.plist` to guarantee availability, or replace it with a `PKCanvasView`-based real handwritten signature capture.

- [ ] 🟢 **BUG-008: `InductionFlowView` does not guard against an empty `imageNames` array** — `if index < imageNames.count - 1` evaluates to `0 < -1` (false) when `imageNames` is empty, immediately showing the "Tap here to sign" button with zero induction pages displayed. The visitor would be able to complete the induction flow without seeing any induction content. Fix: add a guard at the top of the view body: `if imageNames.isEmpty { onComplete(false); return }`.

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



- Current open issue counts: 2 🟠 HIGH, 5 🟡 MEDIUM, 5 🟢 LOW.
- The highest-priority remaining items are the CSV optional-chain write path (`VisitorTabs.swift` / `WelcomeView.swift`) and pager empty-string vs `nil` semantics (`WelcomeView.swift`).
- Feature Idea 10 (Visitor Analytics Dashboard) is now implemented and marked complete.
