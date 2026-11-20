import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.38),
          ),
        ),
        child: child,
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  // في الـ constructor:   this.enabled = true,
  // في TextFormField:     enabled: widget.enabled,
  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: AppTheme.label.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        obscureText: _obscure,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: AppTheme.body.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ), // الشكل كله جاي من inputDecorationTheme
        decoration: InputDecoration(
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
        ),
      ),
    ],
  );
}

/// زرار رئيسي (أخضر) أو Outlined (Guest) حسب [outlined]
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = isLoading ? null : onPressed;
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    return outlined
        ? OutlinedButton(
            onPressed: onTap,
            style: AppTheme.outlined(Theme.of(context).colorScheme),
            child: child,
          )
        : ElevatedButton(onPressed: onTap, child: child);
  }
}
