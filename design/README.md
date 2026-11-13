# FitTrack Pro

A calm, two-theme design system for a fitness app that logs workouts, food, cardio, sleep and weight, and ranks you against friends. **Night** is the dark theme and **Pearl** is the light theme. Same layout, same components, same tokens in both.

Status: this is the design direction locked in November 2026 (Night and Pearl, 30 screens each, plus the component sheets). The code in `src/constants/theme.ts` still holds the older "Luminous Dark" values until the tokens here are ported.

> Flutter note: the same applies to `lib/core/theme/app_colors.dart`, which is a port of the older Luminous Dark values. The V2 tokens in `tokens.json` are not applied to the Flutter app yet.

## Content fundamentals

- **Voice:** short, plain and factual. "Log a session", "Remove Idli?", "Your logged history always stays free to view." No hype, no exclamation marks except the PR celebration.
- **Numbers:** always rounded and with units: `128 g`, `7h 20m`, `78.4 kg`, `5:58 min/km`. Counts use thousands separators: `1,840`.
- **Case:** sentence case for titles and buttons. Uppercase only for overlines (`MY ROUTINES`) at 10px with wide tracking.
- **No emoji.** Icons carry meaning; words carry the rest.
- **Strings** come from i18next, in 9 languages. Leave room for German and Tamil to run 30% longer.

## Visual foundations

- **Flat with hairlines.** Depth is `bg` then `surface`, separated by a 1px `line` border. No shadows on cards. Sheets and dialogs sit on a 50% black scrim.
- **Color belongs to data.** Chrome (headers, buttons, tabs) is neutral. The domain colors (`workout`, `nutrition`, `cardio`, `sleep`, `water`, `xp`) appear only on data: a banner stripe, a ring, a bar, an icon. Night uses the luminous value; Pearl uses the deep value so it reads on white.
- **One accent.** `accent` is sage on Night and near-black on Pearl. It fills the primary button, the active tab marker, the selected chip and progress.
- **Status is never color alone.** Every state pairs color with an icon, a label or a shape (check, arrow, text).
- **Touch targets are 44px.** Controls are 44 high, full-width calls to action 52.
- **Contrast.** Body text 4.5:1, large text and control borders 3:1, checked in both themes. Use `text-bad` and `text-nutrition` for colored text on tinted fills.
- **Numbers use tabular figures** so counters do not jitter.

## Iconography

Line icons, 24px grid, 2px round stroke, `currentColor`. The app uses `phosphor-react-native`; the designs use equivalent paths for: home, dumbbell, fork, pulse, bars, plus, minus, check, x, arrows, search, camera, barcode, trash, star, flame, medal, trophy, bell, moon, scale, run, bike, timer, drop, gear, user, lock, share, sun, clock, info, warning, edit, target. Decorative icons are hidden from screen readers; icon-only buttons get an accessible label.

## Rules that name tokens

1. Screen background is `bg`. Cards, rows and inputs are `surface` with a `line` border and `radius-lg`.
2. Primary text is `ink`; secondary text is `muted`. Never use `muted` below 12px.
3. One primary button per view: `accent` fill, `on-accent` text. Destructive confirms use `bad` fill. Cancel is secondary, never red.
4. Inputs: `surface` fill, `line-strong` border, focus adds a 2px `accent` ring. Errors use a `bad` border and `text-bad` helper text.
5. Progress fill is `accent` for generic progress and the domain color for domain progress (protein is `nutrition`).
6. Rank badges are outlined in their `tier-*` color with a dot; Elite is `ink`, Legend is `sleep`.
7. Gaps are multiples of 4: `space-1` to `space-6`. Screen edge padding is `space-4`.
8. Never gate previously logged data behind the paywall; the Subscription screen says so.

## Components

Button, Input, Badge, Card (activity banner and stat tile), ProgressRing and TabBar have guidelines in `components/`. Live HTML previews of them are in the "FitTrack Pro Design System" artifact on claude.ai. The full inventory of 8 component sheets (buttons, inputs, badges, cards and rows, progress and charts, sheets and dialogs, navigation, tokens) lives in the "FitTrack Pro — Enterprise UI" design under the Components page.

## Domain logic worth keeping visible

- Protein goal: bodyweight x 2.2 (bulk), 2.0 (cut), 1.8 (maintain), rounded to the nearest 5 g.
- XP: workout +50, all RPE +10, PR +100, protein goal +20, post-workout protein +15, streaks 7 / 30 / 90 days +200 / +500 / +2,000.
- Rank score: consistency 30%, volume 35%, streak 20%, PRs 15%.
