import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primary
              : (isDark ? AppTheme.darkBorder : const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value
                ? AppTheme.primary
                : (isDark ? AppTheme.darkBorder : const Color(0xFFD1D5DB)),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: 2,
              left: value ? 22 : 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? Colors.white : (isDark ? AppTheme.darkTextSecondary : Colors.white),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
