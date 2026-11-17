import 'package:flutter/material.dart';
import 'package:poseit/theme/app_theme.dart';

class InstructionStep extends StatelessWidget {
  final int stepNumber;
  final String instruction;

  const InstructionStep({
    super.key,
    required this.stepNumber,
    required this.instruction,
  });

  IconData? _getDirectionIcon(String text) {
    if (text.contains('↑') || text.toLowerCase().contains('up')) {
      return Icons.arrow_upward;
    }
    if (text.contains('↓') || text.toLowerCase().contains('down')) {
      return Icons.arrow_downward;
    }
    if (text.contains('←') || text.toLowerCase().contains('left')) {
      return Icons.arrow_back;
    }
    if (text.contains('→') || text.toLowerCase().contains('right')) {
      return Icons.arrow_forward;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final directionIcon = _getDirectionIcon(instruction);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),
          ),
          if (directionIcon != null) ...[
            const SizedBox(width: 8),
            Icon(
              directionIcon,
              size: 18,
              color: AppTheme.accentColor,
            ),
          ],
        ],
      ),
    );
  }
}
