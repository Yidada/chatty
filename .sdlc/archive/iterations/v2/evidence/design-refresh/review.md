# Visual review scope

- Source target: existing Chatty three-tab native app, refined using Linear Mobile information hierarchy and Material 3 theming.
- Changes remain in presentation and shared core-ui module; controllers and backend contracts unchanged.
- Baseline project/settings screenshots were viewed beside current Pixel captures at 1440×3120. Confirmed reduced borders, consistent icon size, stable alignment and grouped content. Prior build had no dark theme; same-theme comparison will use the new light captures.
- Icons come from Material Outlined; icon-only actions have Chinese accessibility labels and 48dp touch targets. Appium locators now support both text and content-description so the same behavior assertions remain applicable.
- Markwon code backgrounds/text and link colors follow the chosen theme. No WebView or Multica browser exits reintroduced.
- Typography uses sp and the system font; local font changes during visual testing are restored in a finally block.
- No new business action or fake production progress was added. Design demo messages belong only to the local fixture.
- Reviewed by the implementing agent; this is a self-review, not an independent design review.

- Same-theme baseline/new settings screenshots compared at 1440×3120: grouping and hierarchy improved without clipped labels. Large-font settings remains fully usable.
- Manual keyboard review found an excessive gap above the IME despite passing presence assertions. Fixed Scaffold inset consumption; initial screenshot retained in design-visual-loop/keyboard.png and a scoped rerun verifies geometry and send/navigation behavior.

- Reconnected Pixel final review: compared the original keyboard capture with `design-keyboard-loop/keyboard.png`; the excessive blank area is gone, the composer remains fully visible directly above the IME. Scoped synthetic send and tab navigation passed.
- Final real-service APK installed and native settings/resources/Mika smoke passed. Current-process AndroidRuntime log contains no FATAL EXCEPTION. Night mode auto and font scale 1.0 restored; fixture app and reverse port removed. No real chat sends or issue writes performed.
