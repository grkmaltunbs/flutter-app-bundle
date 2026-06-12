import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';

/// Remote (cloud) scan storage.
///
/// Contract for every implementation:
/// - **Owner scoping** — every read and delete is restricted to a single
///   `ownerId` (Firestore: `.where('ownerId', isEqualTo: …)` + `.limit`,
///   paged with cursors).
/// - **Batching** — every multi-doc write/delete runs in write batches.
/// - Errors are thrown as typed `Failure`s (`Failure.network` for
///   transport, `Failure.unexpected` otherwise).
abstract class ScanRemoteDataSource {
  /// Fetches every scan owned by [ownerId] (paged internally).
  Future<List<ScanDto>> fetchAll(String ownerId);

  /// Uploads [scans] (doc id = scan id, full overwrite), in batches.
  Future<void> uploadAll(List<ScanDto> scans);

  /// Deletes every remote scan owned by [ownerId], in batches.
  Future<void> deleteAllForOwner(String ownerId);
}
