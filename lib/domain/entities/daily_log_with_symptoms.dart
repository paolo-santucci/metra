// Copyright (C) 2026  Paolo Santucci
//
// This file is part of Métra.
// SPDX-License-Identifier: GPL-3.0-or-later

import 'daily_log_entity.dart';
import 'pain_symptom_data.dart';

class DailyLogWithSymptoms {
  const DailyLogWithSymptoms({required this.log, required this.symptoms});
  final DailyLogEntity log;
  final List<PainSymptomData> symptoms;
}
