// Copyright (C) 2024 Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class PassphraseDialog extends StatefulWidget {
  const PassphraseDialog({
    super.key,
    required this.onConfirmed,
  });

  final void Function(String passphrase) onConfirmed;

  @override
  State<PassphraseDialog> createState() => _PassphraseDialogState();

  static Future<void> show(
    BuildContext context, {
    required void Function(String) onConfirmed,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => PassphraseDialog(onConfirmed: onConfirmed),
      );
}

class _PassphraseDialogState extends State<PassphraseDialog> {
  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _isValid = false;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final l10n = AppLocalizations.of(context)!;
    final p = _passphraseCtrl.text;
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
    return AlertDialog(
      title: Text(l10n.backup_passphrase_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.backup_passphrase_body),
          const SizedBox(height: 16),
          TextField(
            controller: _passphraseCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.backup_passphrase_input_label,
            ),
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.backup_passphrase_confirm_label,
            ),
            onChanged: (_) => _validate(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
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
          child: Text(l10n.backup_passphrase_confirm_button),
        ),
      ],
    );
  }
}
