---
name: fittrack-ui
description: Build or change any FitTrack Pro Flutter screen or widget in the Night (dark) and Pearl (light) design system. Use when adding or editing a screen, card, button, input, badge, ring, tab bar or styling.
---

# FitTrack Pro UI (Flutter)

Source of truth for the look: `design/README.md`, `design/tokens.json` and `design/components/*.md`. They are the V2 design (Night and Pearl, locked November 2026). Live previews are in the "FitTrack Pro Design System" artifact on claude.ai.

**Known gap:** `lib/core/theme/app_colors.dart` still holds the older "Luminous Dark" values ported from the React Native app. The V2 tokens are not applied yet. When you touch a screen, follow the V2 rules below and, where the existing token differs from `design/tokens.json`, say so in the PR rather than silently mixing the two. Porting the palette itself is a separate, deliberate change.

## Steps

1. Pick the nearest existing screen under `lib/features/*/presentation/` and copy its structure. Reuse widgets from `lib/core/widgets/fittrack_ui.dart` and `custom_icons.dart`; do not create a second button, badge or card.
2. Style from theme values only: `AppPalette.of(context)` for chrome colors, `AppColors.*` for domain colors, `fittrack_tokens.dart` for spacing, radius and type. No raw `Color(0x...)`, `fontSize` or `BorderRadius.circular(n)` literals in screens.
3. Check the screen in both Night and Pearl (dark and light theme).
4. Run `flutter analyze` and `flutter test`; fix what they report.

## The look

- `bg` canvas, `surface` cards with a 1px `line` border, radius 12. No shadows, no glow.
- `ink` primary text, `muted` secondary (never under 12px). Numbers rounded, with units, tabular figures (`FontFeature.tabularFigures()`).
- One `accent` primary button per view with `on-accent` text. Cancel is secondary, never red. Destructive confirm uses `bad`.
- Domain colors (workout, nutrition, cardio, sleep, water, xp) appear only on data: stripes, rings, bars, icons. Pearl uses the deep values; use `text-nutrition` and `text-bad` for colored text.
- Never signal state by color alone: pair it with an icon, a label or a shape.
- 44px minimum touch targets; icon-only buttons get a `Semantics`/`tooltip` label.
- Spacing in multiples of 4, screen padding 16, 110 scroll clearance above the tab bar.
- Tab order: Today, Workout, Nutrition, Cardio, Progress.
- Voice: short, plain, sentence case, no emoji. Icons carry meaning.

## Always

- Strings through `context.t('namespace:key')` (9 languages; leave room for German and Tamil running about 30% longer). Add keys to every language file under `assets/translations/`.
- Every displayed number rounded (`toStringAsFixed` or `round`).
- Forms validate before submit and show how to fix an error.
- Auth id is the Supabase `auth.uid()` text, stored in the legacy `google_user_id` column.
- Offline-first through the `DataGateway`; never gate logged history behind the paywall.
- Keep logic in pure functions under `domain/` and test it; UI stays thin.

## Done means

The screen matches the Night and Pearl designs, uses only theme tokens, passes `flutter analyze` and `flutter test`, and has no hardcoded color or user-facing string.
