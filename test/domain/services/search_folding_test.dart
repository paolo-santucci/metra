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

import 'package:flutter_test/flutter_test.dart';
import 'package:metra/domain/services/search_folding.dart';

void main() {
  group('foldForSearch contract vectors', () {
    test(
      'given_paddedMixedCaseDiacritics_when_folded_then_trimmedLowercasedAndFolded',
      () {
        expect(foldForSearch('  PéRCHÉ '), 'perche');
      },
    );

    test(
      'given_uppercaseAscii_when_folded_then_lowercasedWithoutSubstitution',
      () {
        expect(foldForSearch('PERCHE'), 'perche');
      },
    );

    test('given_whitespaceOnly_when_folded_then_empty', () {
      expect(foldForSearch('   '), '');
    });

    test(
      'given_acuteAndGraveAccents_when_folded_then_bothResolveToSameBase',
      () {
        expect(foldForSearch('perché'), 'perche');
        expect(foldForSearch('perchè'), 'perche');
      },
    );

    test('given_uppercaseVowelsWithDiacritics_when_folded_then_baseVowels', () {
      expect(foldForSearch('ÀÉÎÕÜ'), 'aeiou');
    });

    test('given_lowercaseVowelsWithDiacritics_when_folded_then_baseVowels', () {
      expect(foldForSearch('àéîõü'), 'aeiou');
    });
  });

  group('foldForSearch boundary and input safety', () {
    test('given_cyrillicE_when_folded_then_unchangedNoCrossScriptFold', () {
      expect(foldForSearch('е'), 'е');
    });

    test('given_cjkAndEmoji_when_folded_then_passThroughUnchanged', () {
      expect(foldForSearch('月🔥'), '月🔥');
    });

    test('given_latin1LettersWithoutAsciiBase_when_folded_then_notSubstituted',
        () {
      expect(foldForSearch('ß'), 'ß');
      expect(foldForSearch('Æ'), 'æ');
      expect(foldForSearch('Ø'), 'ø');
    });

    test('given_controlCharacters_when_folded_then_passThroughLiterally', () {
      expect(foldForSearch('\u0000a\nb\tc'), '\u0000a\nb\tc');
    });

    test(
      'given_regexMetacharacters_when_folded_then_passThroughLiterally',
      () {
        expect(foldForSearch('.*[]()'), '.*[]()');
      },
    );

    test('given_tenThousandCharacterInput_when_folded_then_totalAndStable', () {
      final input = List<String>.filled(10000, 'é').join();
      final expected = List<String>.filled(10000, 'e').join();

      expect(foldForSearch(input), expected);
    });

    test('given_emptyString_when_folded_then_empty', () {
      expect(foldForSearch(''), '');
    });
  });
}
