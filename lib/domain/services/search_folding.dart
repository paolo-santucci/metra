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

/// Latin-1 Supplement letters that have a single base ASCII letter, keyed by
/// their (already lowercased) code point.
///
/// Deliberately absent: `ß` (U+00DF), `æ` (U+00E6), `ø` (U+00F8) — lowercased
/// but not substituted, as specified; and `þ` (U+00FE), which has no single
/// ASCII base letter and therefore also passes through unchanged.
const Map<int, String> _baseLetterByCodeUnit = <int, String>{
  0xE0: 'a', // à
  0xE1: 'a', // á
  0xE2: 'a', // â
  0xE3: 'a', // ã
  0xE4: 'a', // ä
  0xE5: 'a', // å
  0xE7: 'c', // ç
  0xF0: 'd', // ð
  0xE8: 'e', // è
  0xE9: 'e', // é
  0xEA: 'e', // ê
  0xEB: 'e', // ë
  0xEC: 'i', // ì
  0xED: 'i', // í
  0xEE: 'i', // î
  0xEF: 'i', // ï
  0xF1: 'n', // ñ
  0xF2: 'o', // ò
  0xF3: 'o', // ó
  0xF4: 'o', // ô
  0xF5: 'o', // õ
  0xF6: 'o', // ö
  0xF9: 'u', // ù
  0xFA: 'u', // ú
  0xFB: 'u', // û
  0xFC: 'u', // ü
  0xFD: 'y', // ý
  0xFF: 'y', // ÿ
};

/// Trims [input], lowercases it, then folds Latin-1 Supplement diacritics to
/// their base ASCII letter (both cases: à–ÿ and À–ÿ, so `'perché'` and
/// `'perchè'` both fold to `'perche'`).
///
/// Characters outside the Latin-1 Supplement pass through unchanged, so no
/// cross-script folding happens (Cyrillic `'е'` never equals Latin `'e'`).
/// `ß`, `æ` and `ø` are lowercased but not substituted.
///
/// Pure and total: any input returns a string without throwing.
String foldForSearch(String input) {
  final normalized = input.trim().toLowerCase();
  final buffer = StringBuffer();

  for (final codeUnit in normalized.codeUnits) {
    final baseLetter = _baseLetterByCodeUnit[codeUnit];
    if (baseLetter == null) {
      buffer.writeCharCode(codeUnit);
    } else {
      buffer.write(baseLetter);
    }
  }

  return buffer.toString();
}
