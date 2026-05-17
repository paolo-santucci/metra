// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026  Paolo Santucci

/// A sentinel wrapper that lets callers distinguish "omit this nullable field"
/// from "explicitly set this field to null" in [AppSettingsData.copyWith].
///
/// Usage in copyWith:
/// ```dart
/// T? field = Nullable<T>? param // signature
/// param != null ? param.value : this.field // body
/// ```
class Nullable<T> {
  const Nullable(this.value);

  final T? value;
}
