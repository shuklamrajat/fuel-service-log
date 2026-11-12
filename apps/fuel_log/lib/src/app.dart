import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

const featureMultipleVehicles = 'multiple_vehicles';
const featureExport = 'export';

const fuelConfig = AppConfig(
  appName: 'Fuel & Service Log',
  tagline: 'Fuel economy, costs and service reminders',
  seedColor: Color(0xFF3949AB),
  onboarding: [
    OnboardingPage(
      icon: Icons.local_gas_station_outlined,
      title: 'Log fill-ups in seconds',
      body: 'Odometer, amount and price. Partial fills and forgotten ones are handled so your economy stays honest.',
    ),
    OnboardingPage(
      icon: Icons.build_outlined,
      title: 'Never miss a service',
      body: 'Oil, tires, inspection: get told when they are due by date or by distance, whichever comes first.',
    ),
    OnboardingPage(
      icon: Icons.lock_outline,
      title: 'Your data stays on your phone',
      body: 'No account and no cloud. Export it whenever you like.',
    ),
  ],
  proFeatures: [
    ProFeature(id: featureMultipleVehicles, title: 'Every vehicle', description: 'Track as many cars, bikes and trucks as you own.'),
    ProFeature(id: featureExport, title: 'Export', description: 'CSV and a PDF history, handy when you sell the car.'),
  ],
);

class FuelApp extends StatelessWidget {
  const FuelApp({super.key});

  @override
  Widget build(BuildContext context) => const CoreApp(home: HomeScreen());
}
