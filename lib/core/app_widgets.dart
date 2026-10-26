import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
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
      Text(widget.label, style: AppTheme.label),
      const SizedBox(height: 8),
      TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: AppTheme.body,
        // الشكل كله جاي من inputDecorationTheme
        decoration: InputDecoration(
          suffixIcon: widget.isPassword
              ? IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textDark,
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
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);

    return outlined
        ? OutlinedButton(onPressed: onTap, style: AppTheme.outlinedStyle, child: child)
        : ElevatedButton(onPressed: onTap, child: child);
  }
}