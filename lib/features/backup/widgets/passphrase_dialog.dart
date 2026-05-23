// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../../../core/theme/metra_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Two purposes of [PassphraseDialog]:
///
/// * [setNew] — collect a brand-new passphrase before the first backup.
///   Two fields (passphrase + confirmation) and a min-8 length rule.
/// * [unlock] — prompt for the existing passphrase before a restore.
///   Single field, no confirmation, no min-length check (an incorrect
///   passphrase is reported by the AES-GCM tag downstream).
enum PassphraseDialogMode { setNew, unlock }

class PassphraseDialog extends StatefulWidget {
  const PassphraseDialog({
    super.key,
    required this.onConfirmed,
    this.mode = PassphraseDialogMode.setNew,
  });

  final void Function(String passphrase) onConfirmed;
  final PassphraseDialogMode mode;

  @override
  State<PassphraseDialog> createState() => _PassphraseDialogState();

  static Future<void> show(
    BuildContext context, {
    required void Function(String) onConfirmed,
    PassphraseDialogMode mode = PassphraseDialogMode.setNew,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => PassphraseDialog(
          onConfirmed: onConfirmed,
          mode: mode,
        ),
      );
}

class _PassphraseDialogState extends State<PassphraseDialog> {
  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _isValid = false;

  bool get _isUnlockMode => widget.mode == PassphraseDialogMode.unlock;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final l10n = AppLocalizations.of(context)!;
    final p = _passphraseCtrl.text;

    if (_isUnlockMode) {
      // Unlock mode: any non-empty passphrase is acceptable; the AES-GCM
      // tag will fail downstream if it's wrong.
      setState(() {
        _error = null;
        _isValid = p.isNotEmpty;
      });
      return;
    }

    final c = _confirmCtrl.text;
    String? err;
    if (p.length < 8) {
      err = l10n.backup_passphrase_too_short;
    } else if (p != c) {
      err = l10n.backup_passphrase_mismatch;
    }
    setState(() {
      _error = err;
      _isValid = err == null && p.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isUnlockMode
        ? l10n.backup_passphrase_unlock_title
        : l10n.backup_passphrase_title;
    final body = _isUnlockMode
        ? l10n.backup_passphrase_unlock_body
        : l10n.backup_passphrase_body;
    final confirmLabel = _isUnlockMode
        ? l10n.backup_passphrase_unlock_button
        : l10n.backup_passphrase_confirm_button;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(body),
          const SizedBox(height: 16),
          TextField(
            controller: _passphraseCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.backup_passphrase_input_label,
            ),
            onChanged: (_) => _validate(),
          ),
          if (!_isUnlockMode) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.backup_passphrase_confirm_label,
              ),
              onChanged: (_) => _validate(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(
                  color: MetraColors.of(context).accentFlowStrong,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        TextButton(
          onPressed: _isValid
              ? () {
                  final pass = _passphraseCtrl.text;
                  Navigator.of(context).pop();
                  widget.onConfirmed(pass);
                }
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
