import 'package:flutter/material.dart';
import '../../Common/Config/Theme/app_colors.dart';

class ActionButtonWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final double? width; // Added to allow customizable width

  const ActionButtonWidget({
    Key? key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor = AppColors.accent,
    this.width, // Optional width parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width ?? screenWidth * 0.8, // Use provided width or default to 0.8
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        )
            : Icon(icon, color: Colors.black, size: 24),
        label: Text(
          label,
          style: const TextStyle(color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}