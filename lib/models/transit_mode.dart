import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

enum TransitMode {
  walk('Walk', Icons.directions_walk, AppColors.walk, Colors.white),
  pujTraditional('Traditional PUJ', Icons.directions_bus, AppColors.pujTraditional, Colors.white),
  pujModern('Modern PUJ', Icons.electric_bolt, AppColors.pujModern, AppColors.ink),
  tricycle('Tricycle', Icons.electric_rickshaw, AppColors.tricycle, Colors.white);

  const TransitMode(this.label, this.icon, this.color, this.onColor);
  final String label;
  final IconData icon;
  final Color color;
  final Color onColor; // readable text/icon color on top of [color]
}

enum PassengerType { regular, student, senior, pwd }

extension PassengerTypeX on PassengerType {
  bool get isDiscounted => this != PassengerType.regular;
}

/// Tricycle fare basis: whole-vehicle "special" trip vs per-seat "shared" ride.
enum TricycleService { shared, special }
