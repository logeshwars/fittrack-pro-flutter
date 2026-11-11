import 'package:flutter/widgets.dart';

/// First-pass app chrome translations. Feature copy is still English.
class AppStrings {
  const AppStrings(this.languageCode);
  final String languageCode;

  static const supported = ['en', 'hi', 'ta', 'ar', 'es', 'de', 'ja', 'pt', 'fr'];
  static const _labels = <String, Map<String, String>>{
    'en': {'today': 'Today', 'workout': 'Workout', 'nutrition': 'Nutrition', 'cardio': 'Cardio', 'progress': 'Progress', 'account': 'Account', 'achievements': 'Achievements'},
    'hi': {'today': 'आज', 'workout': 'वर्कआउट', 'nutrition': 'पोषण', 'cardio': 'कार्डियो', 'progress': 'प्रगति', 'account': 'खाता', 'achievements': 'उपलब्धियाँ'},
    'ta': {'today': 'இன்று', 'workout': 'உடற்பயிற்சி', 'nutrition': 'ஊட்டச்சத்து', 'cardio': 'கார்டியோ', 'progress': 'முன்னேற்றம்', 'account': 'கணக்கு', 'achievements': 'சாதனைகள்'},
    'ar': {'today': 'اليوم', 'workout': 'تمرين', 'nutrition': 'التغذية', 'cardio': 'كارديو', 'progress': 'التقدم', 'account': 'الحساب', 'achievements': 'الإنجازات'},
    'es': {'today': 'Hoy', 'workout': 'Entreno', 'nutrition': 'Nutrición', 'cardio': 'Cardio', 'progress': 'Progreso', 'account': 'Cuenta', 'achievements': 'Logros'},
    'de': {'today': 'Heute', 'workout': 'Training', 'nutrition': 'Ernährung', 'cardio': 'Cardio', 'progress': 'Fortschritt', 'account': 'Konto', 'achievements': 'Erfolge'},
    'ja': {'today': '今日', 'workout': '筋トレ', 'nutrition': '栄養', 'cardio': '有酸素', 'progress': '進捗', 'account': 'アカウント', 'achievements': '実績'},
    'pt': {'today': 'Hoje', 'workout': 'Treino', 'nutrition': 'Nutrição', 'cardio': 'Cardio', 'progress': 'Progresso', 'account': 'Conta', 'achievements': 'Conquistas'},
    'fr': {'today': "Aujourd'hui", 'workout': 'Entraînement', 'nutrition': 'Nutrition', 'cardio': 'Cardio', 'progress': 'Progrès', 'account': 'Compte', 'achievements': 'Succès'},
  };

  String get(String key) => _labels[languageCode]?[key] ?? _labels['en']![key] ?? key;
  static AppStrings of(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return AppStrings(supported.contains(language) ? language : 'en');
  }
}
