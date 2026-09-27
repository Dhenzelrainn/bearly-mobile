import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../models/account_role.dart';

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AccountRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : BearlyColors.brown950;

    return Material(
      color: selected ? BearlyColors.brown900 : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? BearlyColors.brown900 : BearlyColors.lineSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: .12)
                          : BearlyColors.cream100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(role.icon, color: foreground, size: 23),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? BearlyColors.gold : Colors.transparent,
                      border: Border.all(
                        color: selected ? BearlyColors.gold : BearlyColors.line,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                role.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                role.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: .78)
                          : BearlyColors.muted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
