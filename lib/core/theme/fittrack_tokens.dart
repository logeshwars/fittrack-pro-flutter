import 'package:flutter/material.dart';

abstract final class FitTrackSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  static const section = 16.0;
  static const row = 12.0;
  static const card = 20.0;
}

abstract final class FitTrackRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const full = 9999.0;
}

abstract final class FitTrackText {
  static const micro = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
  static const overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );
  static const caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);
  static const title = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  static const titleLg = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );
  static const screenTitle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
  );
  static const stat = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );
  static const statLg = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
  );
  static const hero = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    letterSpacing: -1,
  );
}
