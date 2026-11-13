# FitTrack Pro (Flutter)

## Design

The UI follows the **Night (dark) / Pearl (light)** design system.

- Rules and the component list: `design/README.md` (the Flutter equivalent of
  `DESIGN_SYSTEM_V2.md`)
- Tokens, both themes: `design/tokens.json`
- Per-component specs: `design/components/*.md`
- Skill: `.claude/skills/fittrack-ui/SKILL.md`

Where `design/` and any older design note disagree on look (borders, glow,
colors, sizes), `design/` wins. The older rules on i18n, rounding, error
boundaries and offline-first still hold.

In code:

- Colors: `AppPalette.of(context)`; spacing, radii and type from
  `lib/core/theme/fittrack_tokens.dart`. No raw hex, `fontSize` or
  `BorderRadius` in screens.
- Shared widgets: `lib/core/widgets/fittrack_components.dart` (Button, Input,
  Badge, Card, LogBanner, TabBar, sheet, confirm dialog) and
  `lib/core/widgets/fittrack_ui.dart` (rings, headers, segmented tabs). Reuse
  them; do not build a second button, badge or card.
- Flat surfaces: `surface` with a 1px `line` border, radius 12. No shadow, no
  glow.
- Strings through `context.t('ns:key')`. Numbers rounded, with units.
- Check both themes, then run `flutter analyze` and `flutter test`.
