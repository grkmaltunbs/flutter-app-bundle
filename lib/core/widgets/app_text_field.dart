import 'package:flutter/material.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';

/// The app's standard outlined text field.
///
/// Filled surface, hairline border that sharpens to ink on focus and turns
/// bad on error, with the error text rendered below the field. Set
/// [obscurable] for password fields: a 48dp eye toggle is appended whose
/// semantics come from l10n (`textFieldShowPassword` / `textFieldHidePassword`).
/// Height grows with text scale (padding-driven, never a fixed box).
class AppTextField extends StatefulWidget {
  /// Creates an [AppTextField].
  const AppTextField({
    required this.controller,
    this.hintText,
    this.errorText,
    this.obscurable = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.visibilityToggleKey,
    super.key,
  });

  /// The text controller (owned and disposed by the caller).
  final TextEditingController controller;

  /// Placeholder shown while empty.
  final String? hintText;

  /// Inline error below the field; null hides it.
  final String? errorText;

  /// Whether the field hides its text with a 48dp eye toggle (passwords).
  final bool obscurable;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// Autofill hints (e.g. `AutofillHints.email`).
  final Iterable<String>? autofillHints;

  /// Optional focus node (owned and disposed by the caller).
  final FocusNode? focusNode;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard action button is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field accepts input.
  final bool enabled;

  /// Key for the visibility (eye) toggle, for tests.
  final Key? visibilityToggleKey;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscurable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      // Secret fields must never feed the autocorrect/suggestion engines.
      autocorrect: !widget.obscurable,
      enableSuggestions: !widget.obscurable,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: context.textTheme.bodyLarge?.copyWith(color: palette.ink),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.surface,
        hintText: widget.hintText,
        hintStyle: context.textTheme.bodyLarge?.copyWith(color: palette.faint),
        errorText: widget.errorText,
        errorStyle: context.textTheme.bodySmall?.copyWith(color: palette.bad),
        errorMaxLines: 3,
        // Min height ~52 comes from padding, NOT a fixed box, so the field
        // grows at textScale 2.0 without clipping.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        enabledBorder: border(palette.line),
        focusedBorder: border(palette.ink),
        errorBorder: border(palette.bad),
        focusedErrorBorder: border(palette.bad),
        disabledBorder: border(palette.line),
        suffixIcon: widget.obscurable
            ? IconButton(
                key: widget.visibilityToggleKey,
                tooltip: _obscured
                    ? l10n.textFieldShowPassword
                    : l10n.textFieldHidePassword,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: palette.muted,
                ),
              )
            : null,
      ),
    );
  }
}
