<!--
Verbatim copy of the "fittrack-ui" skill as written for the React Native app
(logeshwars/fittrack-pro). Kept here for reference only: its steps name RN
files (app/, src/components/, useTheme, npx tsc). The Flutter version that
this repo actually loads is .claude/skills/fittrack-ui/SKILL.md.
-->
---
name: fittrack-ui
description: Build or change any FitTrack Pro screen or component in the Night (dark) and Pearl (light) design system. Use when adding or editing a screen, card, button, input, badge, ring, tab bar or styling.
---

# FitTrack Pro UI

Source of truth: the FitTrack Pro Design System artifact (tokens, brand book, component previews) and, in the repo, `design/DESIGN_SYSTEM_V2.md` and `design/tokens.json`. Where the older `DESIGN_SYSTEM.md` disagrees on look (borders, glow, colors, sizes), the V2 system wins; the older doc still holds the rules on i18n, rounding and error boundaries.

## Steps

1. Pick the nearest existing screen in `app/` and copy its structure. Reuse components from `src/components/`; do not create a second button, badge or card.
2. Style with inline styles built from theme tokens: `useTheme()` for colors, `useDomainColor(type)` for data colors, `TYPO`, `SPACING`/`GAP`, `BORDER_RADIUS` from `src/constants/theme.ts`. No `className`, no raw hex, `fontSize`, `fontWeight` or `borderRadius` in screens.
3. Check the screen in both Night and Pearl.
4. Run `npx tsc --noEmit` and fix type errors.

## The look

- `bg` canvas, `surface` cards with a 1px `line` border, radius 12. No shadows, no glow.
- `ink` primary text, `muted` secondary (never under 12px). Numbers rounded, with units, tabular figures.
- One `accent` primary button per view with `on-accent` text. Cancel is secondary, never red. Destructive confirm uses `bad`.
- Domain colors (workout, nutrition, cardio, sleep, water, xp) appear only on data: stripes, rings, bars, icons. Pearl uses the deep values; use `text-nutrition` and `text-bad` for colored text.
- Never signal state by color alone.
- 44px minimum touch targets; icon-only buttons get an accessibility label.
- Spacing in multiples of 4, screen padding 16, 110 scroll clearance above the tab bar.
- Tab order: Today, Workout, Nutrition, Cardio, Progress.

## Always

- Strings through `t('key')`, 9 languages. Forms use react-hook-form + zod. TypeScript strict, no `any`.
- Auth id: `google_user_id` or `supabase.auth.uid()` by `auth_provider`.
- Offline-first via WatermelonDB; never gate logged history behind the paywall.
- Error boundary on every screen.

## Done means

The screen matches the Night and Pearl boards, uses only tokens, passes `npx tsc --noEmit`, and has no hardcoded color or string.
