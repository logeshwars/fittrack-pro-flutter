import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The one icon set for FitTrack Pro: Phosphor, regular weight.
///
/// Screens use these names, never `Icons.*` or a letter in a box, so the
/// whole app can change set or weight here. Add an icon here before using it.
abstract final class FitIcons {
  // Navigation and actions
  static const IconData back = PhosphorIconsBold.caretLeft;
  static const IconData forward = PhosphorIconsRegular.arrowRight;
  static const IconData chevronRight = PhosphorIconsBold.caretRight;
  static const IconData chevronLeft = PhosphorIconsBold.caretLeft;
  static const IconData chevronDown = PhosphorIconsBold.caretDown;
  static const IconData chevronUp = PhosphorIconsBold.caretUp;
  static const IconData close = PhosphorIconsBold.x;
  static const IconData add = PhosphorIconsBold.plus;
  static const IconData remove = PhosphorIconsBold.minus;
  static const IconData check = PhosphorIconsBold.check;
  static const IconData checkCircle = PhosphorIconsRegular.checkCircle;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData edit = PhosphorIconsRegular.pencilSimple;
  static const IconData more = PhosphorIconsRegular.dotsThreeVertical;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData refresh = PhosphorIconsRegular.arrowClockwise;
  static const IconData swap = PhosphorIconsRegular.swap;
  static const IconData play = PhosphorIconsFill.play;
  static const IconData pause = PhosphorIconsFill.pause;
  static const IconData save = PhosphorIconsRegular.bookmarkSimple;
  static const IconData star = PhosphorIconsRegular.star;
  static const IconData starFilled = PhosphorIconsFill.star;
  static const IconData dot = PhosphorIconsFill.circle;
  static const IconData signIn = PhosphorIconsRegular.signIn;
  static const IconData signOut = PhosphorIconsRegular.signOut;
  static const IconData google = PhosphorIconsBold.googleLogo;

  // Status
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData warning = PhosphorIconsRegular.warning;
  static const IconData error = PhosphorIconsRegular.warningCircle;
  static const IconData lock = PhosphorIconsRegular.lock;
  static const IconData secure = PhosphorIconsRegular.shieldCheck;
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData eyeOff = PhosphorIconsRegular.eyeSlash;
  static const IconData placeholder = PhosphorIconsRegular.wrench;

  // Tabs
  static const IconData today = PhosphorIconsRegular.squaresFour;
  static const IconData workout = PhosphorIconsRegular.barbell;
  static const IconData nutrition = PhosphorIconsRegular.forkKnife;
  static const IconData cardio = PhosphorIconsRegular.pulse;
  static const IconData progress = PhosphorIconsRegular.chartBar;

  // Cardio activities
  static const IconData run = PhosphorIconsRegular.personSimpleRun;
  static const IconData cycle = PhosphorIconsRegular.personSimpleBike;
  static const IconData walk = PhosphorIconsRegular.personSimpleWalk;
  static const IconData swim = PhosphorIconsRegular.personSimpleSwim;
  static const IconData hiit = PhosphorIconsRegular.lightning;
  static const IconData otherActivity = PhosphorIconsRegular.heartbeat;

  // Domains and data
  static const IconData sleep = PhosphorIconsRegular.moon;
  static const IconData sleepStars = PhosphorIconsRegular.moonStars;
  static const IconData water = PhosphorIconsRegular.drop;
  static const IconData weight = PhosphorIconsRegular.gauge;
  static const IconData steps = PhosphorIconsRegular.footprints;
  static const IconData xp = PhosphorIconsFill.lightning;
  static const IconData streak = PhosphorIconsRegular.fire;
  static const IconData streakFilled = PhosphorIconsFill.fire;
  static const IconData streakBold = PhosphorIconsBold.fire;
  static const IconData calories = PhosphorIconsRegular.fire;
  static const IconData trophy = PhosphorIconsRegular.trophy;
  static const IconData medal = PhosphorIconsRegular.medal;
  static const IconData leaderboard = PhosphorIconsRegular.ranking;
  static const IconData goal = PhosphorIconsRegular.target;
  static const IconData flag = PhosphorIconsRegular.flag;
  static const IconData health = PhosphorIconsRegular.heartbeat;
  static const IconData timer = PhosphorIconsRegular.timer;
  static const IconData clock = PhosphorIconsRegular.clock;
  static const IconData calendar = PhosphorIconsRegular.calendarBlank;
  static const IconData trendUp = PhosphorIconsRegular.trendUp;
  static const IconData trendDown = PhosphorIconsRegular.trendDown;
  static const IconData route = PhosphorIconsRegular.path;
  static const IconData pin = PhosphorIconsRegular.mapPin;

  // Nutrition
  static const IconData breakfast = PhosphorIconsRegular.coffee;
  static const IconData lunch = PhosphorIconsRegular.bowlFood;
  static const IconData dinner = PhosphorIconsRegular.forkKnife;
  static const IconData snack = PhosphorIconsRegular.cookie;
  static const IconData supplement = PhosphorIconsRegular.pill;
  static const IconData barcode = PhosphorIconsRegular.barcode;
  static const IconData camera = PhosphorIconsRegular.camera;
  static const IconData gallery = PhosphorIconsRegular.images;
  static const IconData manualEntry = PhosphorIconsRegular.notePencil;
  static const IconData flashOn = PhosphorIconsFill.lightning;
  static const IconData flashOff = PhosphorIconsRegular.lightningSlash;
  static const IconData protein = PhosphorIconsRegular.egg;
  static const IconData carbs = PhosphorIconsRegular.grains;
  static const IconData fat = PhosphorIconsRegular.dropHalf;
  static const IconData fiber = PhosphorIconsRegular.leaf;

  // Settings and profile
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData user = PhosphorIconsRegular.user;
  static const IconData bell = PhosphorIconsRegular.bell;
  static const IconData palette = PhosphorIconsRegular.palette;
  static const IconData language = PhosphorIconsRegular.translate;
  static const IconData units = PhosphorIconsRegular.ruler;
  static const IconData subscription = PhosphorIconsRegular.crown;
  static const IconData document = PhosphorIconsRegular.fileText;
  static const IconData help = PhosphorIconsRegular.question;
  static const IconData sun = PhosphorIconsRegular.sun;
  static const IconData sunrise = PhosphorIconsRegular.sunHorizon;
  static const IconData system = PhosphorIconsRegular.deviceMobile;
  static const IconData sparkle = PhosphorIconsRegular.sparkle;
}
