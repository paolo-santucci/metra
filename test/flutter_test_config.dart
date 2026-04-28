// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
//
// Métra is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// Métra is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Métra. If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Pre-load bundled fonts so goldens render with the correct typefaces
  // instead of the system fallback on the first frame.
  final interLoader = FontLoader('Inter')
    ..addFont(rootBundle.load('test/goldens_fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('test/goldens_fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('test/goldens_fonts/Inter-SemiBold.ttf'));
  await interLoader.load();

  final displayLoader = FontLoader('DMSerifDisplay')
    ..addFont(rootBundle.load('test/goldens_fonts/DMSerifDisplay-Regular.ttf'));
  await displayLoader.load();

  await testMain();
}
