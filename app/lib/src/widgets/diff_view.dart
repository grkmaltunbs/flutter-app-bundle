import 'package:flutter/material.dart' hide Step, StepState;

import '../theme.dart';

/// A unified diff as the phone reads it: added lines green, removed red,
/// hunk headers dim, in the mono face — scrolling sideways inside its own
/// box, so the page never does.
class DiffView extends StatelessWidget {
  const DiffView(this.diff, {super.key, this.compact = false});
  final String diff;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lines = diff.split('\n');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Container(
                color: _tint(l, t),
                child: Text(l.isEmpty ? ' ' : l, softWrap: false, style: t.mono(compact ? 11 : 12, color: _ink(l, t), height: 1.45)),
              ),
          ],
        ),
      ),
    );
  }

  static bool _header(String l) => l.startsWith('--- ') || l.startsWith('+++ ');

  static Color _ink(String l, KitTokens t) {
    if (_header(l) || l.startsWith('@@') || l.startsWith('…')) return t.muted;
    if (l.startsWith('(')) return t.warn;
    if (l.startsWith('+')) return t.good;
    if (l.startsWith('-')) return t.critical;
    return t.ink2;
  }

  static Color? _tint(String l, KitTokens t) {
    if (_header(l)) return null;
    if (l.startsWith('+')) return t.good.withValues(alpha: 0.10);
    if (l.startsWith('-')) return t.critical.withValues(alpha: 0.10);
    return null;
  }
}

/// A tool row's diff, in a sheet: the path on top (a tap opens the file),
/// the diff under it, Revert file at the bottom when the host can.
Future<void> showDiffSheet(BuildContext context, {required String diff, String? path, VoidCallback? onOpen, Future<void> Function()? onRevert}) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.96,
      builder: (context, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: onOpen == null
                    ? null
                    : () {
                        Navigator.of(sheet).pop();
                        onOpen();
                      },
                child: Text(path ?? 'diff', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.mono(12.5, color: onOpen == null ? t.ink2 : t.accent)),
              ),
            ),
            if (onRevert != null)
              TextButton(
                onPressed: () async {
                  final ok = await confirmRevert(context, path ?? 'this file');
                  if (!ok) return;
                  await onRevert();
                  if (sheet.mounted) Navigator.of(sheet).pop();
                },
                child: const Text('REVERT FILE'),
              ),
          ]),
          const SizedBox(height: 8),
          DiffView(diff),
        ],
      ),
    ),
  );
}

/// The confirm before `git checkout -- <path>`: the file goes back to the
/// last commit, and what was not committed is gone.
Future<bool> confirmRevert(BuildContext context, String path) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Revert this file?'),
      content: Text('$path goes back to the last commit. Changes that were not committed are gone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('KEEP')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('REVERT')),
      ],
    ),
  );
  return ok ?? false;
}
