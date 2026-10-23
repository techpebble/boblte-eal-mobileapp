import 'dart:io';

import 'package:eal_scanner/config/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server decides whether a build may write records by the number the app
/// sends, and the APK is stamped with the number in pubspec.yaml. If those two
/// drift apart, a current app reports itself as an old one — refused in the
/// field, with nothing in the code looking wrong. So they are pinned together.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);

  test('pubspec carries a name+build version', () {
    expect(version, isNotNull, reason: 'pubspec.yaml needs `version: x.y.z+N`');
  });

  test('AppVersion.build matches the build number the APK is stamped with', () {
    expect(AppVersion.build, int.parse(version!.group(2)!));
  });

  test('AppVersion.name matches pubspec', () {
    expect(AppVersion.name, version!.group(1));
  });

  test('every request says which build is asking', () {
    expect(AppVersion.headers['X-App-Version'], '${AppVersion.build}');
    expect(AppVersion.headers['X-Client'], 'mobile');
  });

  test('the token variant keeps the version alongside the bearer', () {
    final headers = AppVersion.headersWithToken('abc');
    expect(headers['Authorization'], 'Bearer abc');
    expect(headers['X-App-Version'], '${AppVersion.build}');
  });
}
