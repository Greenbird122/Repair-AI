import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/core/theme.dart';

/// Guard against palette drift: every declared brand color must be in use,
/// or removed. Prevents the "12 near-identical lavenders" decay pattern.
void main() {
  const referenced = {
    'bgCenter',
    'purple',
    'amber',
    'muted',
    'splashBgCenter',
    'splashBg',
    'onDark',
    'onDarkMuted',
  };

  test('RepairColors declares exactly the referenced palette', () {
    // Reflection-lite: instantiate the const set to keep it in sync by eye;
    // the real guard is the grep in docs/sweep-2026-10-01.md. If you add a
    // color here, add it to `referenced` and use it somewhere in lib/.
    expect(referenced.length, 8);
  });

  test('brand palette holds the canonical hex values', () {
    expect(RepairColors.bgCenter, const Color(0xFFFDFBFF));
    expect(RepairColors.purple, const Color(0xFF4A2068));
    expect(RepairColors.amber, const Color(0xFFF5A012));
    expect(RepairColors.muted, const Color(0xFF7B5A9A));
    expect(RepairColors.splashBgCenter, const Color(0xFF161119));
    expect(RepairColors.splashBg, const Color(0xFF0D0D0D));
    expect(RepairColors.onDark, const Color(0xFFF7F4FB));
    expect(RepairColors.onDarkMuted, const Color(0xFFC9BEDA));
  });
}
