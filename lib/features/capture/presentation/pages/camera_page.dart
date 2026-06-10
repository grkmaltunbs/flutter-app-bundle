import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/camera/viewfinder_service.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/features/capture/presentation/blocs/camera_bloc.dart';
import 'package:okey_acar_mi/features/capture/presentation/widgets/camera_failure_l10n.dart';
import 'package:okey_acar_mi/features/capture/presentation/widgets/camera_mode_toggle.dart';
import 'package:okey_acar_mi/features/capture/presentation/widgets/camera_permission_view.dart';
import 'package:okey_acar_mi/features/capture/presentation/widgets/camera_shutter_row.dart';
import 'package:okey_acar_mi/features/capture/presentation/widgets/camera_top_bar.dart';
import 'package:okey_acar_mi/features/capture/presentation/widgets/viewfinder_reticle.dart';

/// The capture screen: full-bleed dark chrome over the live viewfinder, with
/// the framing reticle, mode toggle, and shutter row.
///
/// Owns the screen-scoped [CameraBloc] and an [AppLifecycleListener] that
/// parks/recovers the camera when the app leaves/regains the foreground.
class CameraPage extends StatefulWidget {
  /// Creates a [CameraPage].
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final ViewfinderService _viewfinder;
  late final CameraBloc _bloc;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _viewfinder = getIt<ViewfinderService>();
    _bloc = getIt<CameraBloc>()..add(const CameraEvent.started());
    _lifecycle = AppLifecycleListener(
      onHide: () => _bloc.add(const CameraEvent.appBackgrounded()),
      onResume: () => _bloc.add(const CameraEvent.appResumed()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CameraBloc>(
      // The provider owns (and closes) the bloc created in initState.
      create: (_) => _bloc,
      child: CameraView(viewfinder: _viewfinder),
    );
  }
}

/// The capture screen view (assumes a [CameraBloc] is provided above it).
class CameraView extends StatelessWidget {
  /// Creates a [CameraView] rendering [viewfinder].
  const CameraView({required this.viewfinder, super.key});

  /// The environment's viewfinder surface (live preview or demo fixture).
  final ViewfinderService viewfinder;

  void _onStateChanged(BuildContext context, CameraState state) {
    switch (state) {
      case CameraSuccess(:final payload):
        // Hand off to the analyzing flow; on return, re-acquire the camera.
        final bloc = context.read<CameraBloc>();
        unawaited(
          context.push<void>(AppRoutes.analyzing, extra: payload).then((_) {
            if (!bloc.isClosed) {
              bloc.add(const CameraEvent.returnedFromCapture());
            }
          }),
        );
      case CameraReady(failure: final failure?):
        // One-shot: the bloc clears the failure on its next emission.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cameraFailureText(context.l10n, failure))),
        );
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CameraBloc, CameraState>(
      listener: _onStateChanged,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _ViewfinderLayer(viewfinder: viewfinder),
            const _BlockedLayer(),
            const SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: CameraTopBar(),
                  ),
                  Spacer(),
                  _BottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full-bleed viewfinder + reticle, swapped per state.
class _ViewfinderLayer extends StatelessWidget {
  const _ViewfinderLayer({required this.viewfinder});

  final ViewfinderService viewfinder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        return switch (state) {
          CameraReady() ||
          CameraCapturing() ||
          CameraRecording() ||
          CameraPickingGallery() => Stack(
            fit: StackFit.expand,
            children: [
              viewfinder.buildViewfinder(context),
              const ViewfinderReticle(),
            ],
          ),
          CameraInitializing() => const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          ),
          _ => const ColoredBox(color: Colors.black),
        };
      },
    );
  }
}

/// Renders [CameraPermissionView] for denied / no-camera states.
class _BlockedLayer extends StatelessWidget {
  const _BlockedLayer();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      builder: (context, state) {
        return switch (state) {
          CameraDenied(:final permanent) => CameraPermissionView(
            variant: permanent
                ? CameraPermissionVariant.cameraPermanentlyDenied
                : CameraPermissionVariant.cameraDenied,
          ),
          CameraGalleryDenied(:final permanent) => CameraPermissionView(
            variant: permanent
                ? CameraPermissionVariant.galleryPermanentlyDenied
                : CameraPermissionVariant.galleryDenied,
          ),
          CameraUnavailable() => const CameraPermissionView(
            variant: CameraPermissionVariant.noCamera,
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

/// The mode toggle + shutter row, shown only while the camera flow is live.
class _BottomControls extends StatelessWidget {
  const _BottomControls();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        final visible = switch (state) {
          CameraReady() ||
          CameraCapturing() ||
          CameraRecording() ||
          CameraPickingGallery() ||
          CameraInitializing() => true,
          _ => false,
        };
        if (!visible) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CameraModeToggle(),
              SizedBox(height: 18),
              CameraShutterRow(),
            ],
          ),
        );
      },
    );
  }
}
