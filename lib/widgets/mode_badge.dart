import 'package:flutter/material.dart';
import '../models/transit_mode.dart';

class ModeBadge extends StatelessWidget {
  const ModeBadge(this.mode, {super.key});
  final TransitMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: mode.color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(mode.icon, size: 16, color: mode.onColor),
        const SizedBox(width: 6),
        Text(mode.label,
            style: TextStyle(color: mode.onColor, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}
