/// Static badge catalogue entry (port of `src/constants/badges.ts`).
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.xpReward,
    required this.requirementType,
    required this.requirementValue,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final int xpReward;
  final String requirementType;
  final num requirementValue;
}
