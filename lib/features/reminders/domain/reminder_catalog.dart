/// Groups of reminders, each with its own Android notification channel.
enum ReminderCategory {
  morning,
  nutrition,
  hydration,
  fitness,
  sleep,
  supplement
}

extension ReminderCategoryMeta on ReminderCategory {
  String get label => switch (this) {
        ReminderCategory.morning => 'Morning Routine',
        ReminderCategory.nutrition => 'Nutrition Logs',
        ReminderCategory.hydration => 'Hydration',
        ReminderCategory.fitness => 'Fitness',
        ReminderCategory.sleep => 'Sleep',
        ReminderCategory.supplement => 'Supplements',
      };

  /// Android channel id (matches the React Native app).
  String get channelId => name;
}

/// A reminder the user can switch on and move to a time of day.
class ReminderDef {
  const ReminderDef({
    required this.id,
    required this.notificationId,
    required this.category,
    required this.label,
    required this.body,
    required this.defaultTime,
  });

  final String id;

  /// Stable OS notification id; never reuse or renumber a shipped value.
  final int notificationId;
  final ReminderCategory category;
  final String label;
  final String body;

  /// "HH:MM", 24 hour.
  final String defaultTime;
}

ReminderDef _r(int n, ReminderCategory c, String id, String label, String time,
        String body) =>
    ReminderDef(
        id: id,
        notificationId: n,
        category: c,
        label: label,
        body: body,
        defaultTime: time);

ReminderDef _supp(int n, String id, String name, String time) => ReminderDef(
      id: 'supp_$id',
      notificationId: 100 + n,
      category: ReminderCategory.supplement,
      label: name,
      body: 'Time to take your $name.',
      defaultTime: time,
    );

/// Port of `remindersStore.ts` and `supplementsStore.ts` defaults.
final List<ReminderDef> reminderCatalog = [
  _r(1, ReminderCategory.morning, 'morning_checkin', 'Morning Check-in',
      '07:30', 'Rise & grind! Open FitTrack to set your goals for the day.'),
  _r(2, ReminderCategory.morning, 'morning_preworkout', 'Pre-Workout Fuel',
      '06:30', 'Eat your pre-workout meal 60–90 min before training.'),
  _r(3, ReminderCategory.nutrition, 'log_breakfast', 'Log Breakfast', '08:00',
      'Breakfast time! Track your morning meal to stay on top of macros.'),
  _r(4, ReminderCategory.nutrition, 'log_lunch', 'Log Lunch', '12:30',
      "Lunchtime! Don't forget to log your midday meal."),
  _r(5, ReminderCategory.nutrition, 'log_snack', 'Log Afternoon Snack', '15:30',
      'Snack time? Keep your nutrition on track.'),
  _r(6, ReminderCategory.nutrition, 'log_dinner', 'Log Dinner', '19:00',
      'Dinner time! Log your evening meal before you forget.'),
  _r(7, ReminderCategory.hydration, 'water_morning', 'Morning Water', '08:30',
      'Start hydrated! Drink a glass of water to kick off your day.'),
  _r(8, ReminderCategory.hydration, 'water_midmorning', 'Mid-Morning Water',
      '10:30', 'Stay on top of your hydration — time for water!'),
  _r(9, ReminderCategory.hydration, 'water_lunch', 'Lunch Water', '13:00',
      'Have a glass of water with your lunch.'),
  _r(10, ReminderCategory.hydration, 'water_afternoon', 'Afternoon Water',
      '15:00', 'Afternoon slump? Water helps — drink up!'),
  _r(11, ReminderCategory.hydration, 'water_evening', 'Evening Water', '17:30',
      'Evening hydration check — one more glass!'),
  _r(12, ReminderCategory.hydration, 'water_night', 'Night Water', '19:30',
      'Last water reminder of the day. Stay hydrated!'),
  _r(13, ReminderCategory.fitness, 'workout_reminder', 'Workout Reminder',
      '18:00', "Time to train! Your body is ready. Let's get it done."),
  _r(14, ReminderCategory.fitness, 'cardio_session', 'Cardio Session', '07:00',
      'Morning cardio time! Get your heart pumping.'),
  _r(15, ReminderCategory.sleep, 'sleep_winddown', 'Wind Down', '21:30',
      'Start winding down — put the screen away and relax.'),
  _r(16, ReminderCategory.sleep, 'sleep_bedtime', 'Bedtime Reminder', '22:30',
      'Time for bed! Aim for 7–9 hours of quality sleep.'),
  _r(17, ReminderCategory.sleep, 'sleep_log', "Log Last Night's Sleep", '08:00',
      "Good morning! Don't forget to log how you slept."),
  _supp(1, 'creatine', 'Creatine', '08:00'),
  _supp(2, 'fish_oil', 'Fish Oil', '08:00'),
  _supp(3, 'magnesium', 'Magnesium', '21:00'),
  _supp(4, 'vitamin_d', 'Vitamin D', '09:00'),
  _supp(5, 'zinc', 'Zinc', '09:00'),
  _supp(6, 'omega3', 'Omega-3', '13:00'),
  _supp(7, 'vitamin_c', 'Vitamin C', '08:00'),
  _supp(8, 'multivit', 'Multivitamin', '08:00'),
];
