import 'dart:isolate';

import 'package:injectable/injectable.dart';
import 'package:okey_acar_mi/features/solver/domain/engine/solver_engine.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_request.dart';
import 'package:okey_acar_mi/features/solver/domain/entities/solve_result.dart';

/// Solves a rack off the UI isolate, memoizing the last request.
///
/// The LRU(1) cache lives here on the main isolate — per-solve isolates
/// share no memory. The engine is const/stateless, so the closure is
/// isolate-sendable.
///
/// Registered as an `@injectable` factory (the repo-wide usecase
/// convention), so the LRU(1) memo is **per-instance**: resolve once per
/// screen (e.g. in the page's `BlocProvider(create:)`, Step 8 wiring) and
/// reuse that instance — re-resolving discards the cache.
@injectable
class SolveRack {
  /// Creates a [SolveRack] backed by [_engine].
  SolveRack(this._engine);

  final SolverEngine _engine;

  SolveRequest? _lastRequest;
  SolveResult? _lastResult;

  /// Executes the solve, returning the cached result on identical input.
  Future<SolveResult> call(SolveRequest request) async {
    final cached = _lastResult;
    if (cached != null && request == _lastRequest) return cached;
    final engine = _engine;
    final result = await Isolate.run(() => engine.solve(request));
    _lastRequest = request;
    _lastResult = result;
    return result;
  }
}
