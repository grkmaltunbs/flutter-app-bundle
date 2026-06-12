import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okey_acar_mi/core/error/failure.dart';
import 'package:okey_acar_mi/core/logging/app_logger.dart';
import 'package:okey_acar_mi/features/history/data/datasources/scan_remote_data_source.dart';
import 'package:okey_acar_mi/features/history/data/dtos/scan_dto.dart';

/// Maps a [FirebaseException] into a typed [Failure]: transport-ish codes
/// collapse into [Failure.network]; everything else surfaces the code as
/// [Failure.unexpected] (mirrors `auth_error_mapper.dart`).
Failure mapFirestoreError(FirebaseException exception) {
  return switch (exception.code) {
    'unavailable' ||
    'deadline-exceeded' ||
    'network-request-failed' => const Failure.network(),
    final code => Failure.unexpected('firestore/$code'),
  };
}

/// Production [ScanRemoteDataSource] over the top-level Firestore `scans`
/// collection (doc id = scan id).
///
/// Registered for the `prod` environment via `HistoryBindings`. Reads are
/// owner-scoped + limited and paged by document cursor; writes/deletes run
/// in [WriteBatch] chunks below Firestore's 500-op cap.
class FirestoreScanRemoteDataSource implements ScanRemoteDataSource {
  /// Creates a [FirestoreScanRemoteDataSource] over [_firestore].
  const FirestoreScanRemoteDataSource(this._firestore, this._logger);

  final FirebaseFirestore _firestore;
  final AppLogger _logger;

  static const String _collection = 'scans';
  static const int _pageSize = 200;
  static const int _batchLimit = 450;

  CollectionReference<Map<String, dynamic>> get _scans =>
      _firestore.collection(_collection);

  @override
  Future<List<ScanDto>> fetchAll(String ownerId) async {
    try {
      final all = <ScanDto>[];
      final base = _scans
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('createdAtMs', descending: true)
          .limit(_pageSize);
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        final page = cursor == null ? base : base.startAfterDocument(cursor);
        final snapshot = await page.get();
        for (final doc in snapshot.docs) {
          try {
            all.add(ScanDto.fromDocument(doc.id, doc.data()));
          } on FormatException catch (error) {
            _logger.warning('Skipping malformed scan doc ${doc.id}: $error');
          }
        }
        if (snapshot.docs.length < _pageSize) return all;
        cursor = snapshot.docs.last;
      }
    } on FirebaseException catch (exception) {
      throw mapFirestoreError(exception);
    }
  }

  @override
  Future<void> uploadAll(List<ScanDto> scans) async {
    try {
      for (var start = 0; start < scans.length; start += _batchLimit) {
        final end = start + _batchLimit < scans.length
            ? start + _batchLimit
            : scans.length;
        final batch = _firestore.batch();
        for (final dto in scans.sublist(start, end)) {
          // Full overwrite (merge: false): the local row is the complete
          // source of truth for its doc.
          batch.set(_scans.doc(dto.id), dto.toJson());
        }
        await batch.commit();
      }
    } on FirebaseException catch (exception) {
      throw mapFirestoreError(exception);
    }
  }

  @override
  Future<void> deleteAllForOwner(String ownerId) async {
    try {
      while (true) {
        final snapshot = await _scans
            .where('ownerId', isEqualTo: ownerId)
            .limit(_batchLimit)
            .get();
        if (snapshot.docs.isEmpty) return;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < _batchLimit) return;
      }
    } on FirebaseException catch (exception) {
      throw mapFirestoreError(exception);
    }
  }
}
