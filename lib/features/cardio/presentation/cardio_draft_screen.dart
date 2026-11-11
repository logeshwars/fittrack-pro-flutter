import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/local/local_draft_store.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/cardio_draft.dart';

class CardioDraftScreen extends StatefulWidget {
  const CardioDraftScreen({this.activityType, super.key});

  final String? activityType;

  @override
  State<CardioDraftScreen> createState() => _CardioDraftScreenState();
}

class _CardioDraftScreenState extends State<CardioDraftScreen> {
  static const _key = 'fittrack_cardio_drafts_v1';
  final _minutes = TextEditingController(text: '30');
  final _distance = TextEditingController();
  late String _type;
  LocalDraftStore? _store;
  CardioDrafts _drafts = const CardioDrafts([]);
  String? _error;

  static const _types = <_CardioType>[
    _CardioType('running', 'Run', Icons.directions_run, Color(0xFFFF6B35), '+50 XP for 5km'),
    _CardioType('cycling', 'Cycle', Icons.directions_bike, Color(0xFF4FC3F7), '+30 XP base'),
    _CardioType('walking', 'Walk', Icons.directions_walk, Color(0xFF81C784), '+20 XP for 30min'),
    _CardioType('swimming', 'Swim', Icons.pool, Color(0xFF4DD0E1), '+30 XP base'),
    _CardioType('hiit', 'HIIT', Icons.local_fire_department, Colors.white, '+50 XP for 30min'),
    _CardioType('other', 'Other', Icons.bolt, Color(0xFF9B9DAC), '+30 XP base'),
  ];

  @override
  void initState() {
    super.initState();
    _type = _types.any((item) => item.id == widget.activityType)
        ? widget.activityType!
        : 'running';
    _load();
  }

  Future<void> _load() async {
    try {
      final store = LocalDraftStore(await SharedPreferences.getInstance());
      if (!mounted) return;
      setState(() {
        _store = store;
        final raw = store.read(_key);
        _drafts =
            raw == null ? const CardioDrafts([]) : CardioDrafts.decode(raw);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load local cardio drafts');
      }
    }
  }

  Future<void> _add() async {
    final draft = CardioDraft(
      type: _type,
      durationMinutes: int.tryParse(_minutes.text) ?? -1,
      distanceKm: _distance.text.trim().isEmpty
          ? null
          : double.tryParse(_distance.text) ?? double.nan,
    );

    if (!draft.isValid) {
      setState(() => _error = 'Enter valid minutes and distance');
      return;
    }

    final store = _store;
    if (store == null) return;
    final updated = _drafts.add(draft);

    try {
      await store.write(_key, updated.encode());
      if (!mounted) return;
      setState(() {
        _drafts = updated;
        _error = null;
      });
      _distance.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save cardio draft');
    }
  }

  @override
  void dispose() {
    _minutes.dispose();
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final selected = _types.firstWhere((item) => item.id == _type);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 44),
          children: [
            _Header(
              label: selected.label,
              color: selected.color,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'ACTIVITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                  letterSpacing: 2,
                ),
              ),
            ),
            SizedBox(
              height: 98,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                scrollDirection: Axis.horizontal,
                itemCount: _types.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _types[index];
                  final active = item.id == _type;
                  return InkWell(
                    onTap: () => setState(() => _type = item.id),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 86,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? item.color.withValues(alpha: .12)
                            : colors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: active ? item.color : colors.border2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 25, color: item.color),
                          const SizedBox(height: 7),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: active ? item.color : colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: selected.color.withValues(alpha: .10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      selected.icon,
                      size: 38,
                      color: selected.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selected.label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    selected.hint,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'SESSION DURATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.faint,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 112,
                        child: TextField(
                          controller: _minutes,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: colors.text,
                          ),
                          decoration: const InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Text(
                          'min',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _distance,
                      label: 'DISTANCE',
                      hint: 'Optional',
                      suffix: 'km',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Preview(
                      label: 'SAVED MINUTES',
                      value: '${_drafts.totalMinutes}',
                      color: selected.color,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.danger.withValues(alpha: .35),
                  ),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _store == null ? null : _add,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('SAVE SESSION LOCALLY'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.accentText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
            ),
            if (_drafts.items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
                child: Text(
                  'LOCAL SESSIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _drafts.items.reversed
                      .take(6)
                      .map((item) => _SavedSession(item: item))
                      .toList(),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Saved on this device only. Live timer, calorie estimation and XP awards stay disabled until account migration is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: colors.faint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.color,
    required this.onBack,
  });

  final String label;
  final Color color;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.header,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, size: 20, color: colors.text),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label Session',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track time, distance & effort',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: .28)),
            ),
            child: Text(
              'LOCAL',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: colors.faint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.faint,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: colors.faint,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedSession extends StatelessWidget {
  const _SavedSession({required this.item});
  final CardioDraft item;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.directions_run, size: 20, color: AppColors.cardio),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.type[0].toUpperCase() + item.type.substring(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Text(
            '${item.durationMinutes} min',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.subtext,
            ),
          ),
          if (item.distanceKm != null) ...[
            const SizedBox(width: 10),
            Text(
              '${item.distanceKm!.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardioType {
  const _CardioType(
    this.id,
    this.label,
    this.icon,
    this.color,
    this.hint,
  );

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String hint;
}
