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

sealed class MetraException implements Exception {
  const MetraException(this.message);
  final String message;
}

final class StorageException extends MetraException {
  const StorageException(super.message);
}

final class EncryptionException extends MetraException {
  const EncryptionException(super.message);
}

final class SyncException extends MetraException {
  const SyncException(super.message);
}

final class CryptoException extends MetraException {
  const CryptoException(super.message);
}

final class DatabaseException extends MetraException {
  const DatabaseException(super.message);
}

final class ValidationException extends MetraException {
  const ValidationException(super.message);
}
