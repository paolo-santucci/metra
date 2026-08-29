// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/services.dart';

import '../../../core/errors/metra_exception.dart';
import 'backup_state.dart';

const String noBrowserMessage =
    'No web browser app is available. Enable or install a browser, '
    'then try again.';

bool isNoBrowserError(Object error) {
  if (error is PlatformException) {
    final message = error.message ?? '';
    final details = error.details?.toString() ?? '';
    return message.contains('No Activity found to handle Intent') ||
        details.contains('ActivityNotFoundException');
  }
  return false;
}

BackupErrorState backupErrorFromException(Object error) {
  if (isNoBrowserError(error)) {
    return const BackupErrorState(
      noBrowserMessage,
      kind: BackupErrorKind.noBrowser,
    );
  }
  return BackupErrorState(
    error is MetraException
        ? error.message
        : 'Something went wrong. Please try again.',
  );
}
