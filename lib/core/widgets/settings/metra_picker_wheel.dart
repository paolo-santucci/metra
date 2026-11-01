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
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/cupertino.dart';

import '../../theme/metra_colors.dart';
import '../../theme/metra_spacing.dart';

class MetraPickerWheel extends StatefulWidget {
  const MetraPickerWheel({
    required this.initialItem,
    required this.onSelectedItemChanged,
    required this.children,
    super.key,
  });

  final int initialItem;
  final ValueChanged<int> onSelectedItemChanged;
  final List<Widget> children;

  @override
  State<MetraPickerWheel> createState() => _MetraPickerWheelState();
}

class _MetraPickerWheelState extends State<MetraPickerWheel> {
  late final _controller =
      FixedExtentScrollController(initialItem: widget.initialItem);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetraColors.of(context);
    final extent = MediaQuery.textScalerOf(context).scale(21) + 23;
    return SizedBox(
      height: extent * 5,
      child: CupertinoPicker(
        scrollController: _controller,
        itemExtent: extent,
        looping: false,
        backgroundColor: colors.bgPrimary,
        selectionOverlay: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MetraSpacing.s4),
          child: Container(
            height: extent,
            decoration: BoxDecoration(
              color: colors.textPrimary.withAlpha(0x0F),
              borderRadius: BorderRadius.circular(MetraRadius.smm),
            ),
          ),
        ),
        onSelectedItemChanged: widget.onSelectedItemChanged,
        children: widget.children,
      ),
    );
  }
}
