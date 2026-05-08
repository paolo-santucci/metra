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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'given_domain_NotificationService_when_dartdoc_inspected_then_no_obsolete_09_00_wording',
    () async {
      final src = await File(
        'lib/domain/services/notification_service.dart',
      ).readAsString();
      expect(src, isNot(contains('09:00 local time')));
      expect(src, contains('local time encoded in'));
    },
  );
}
