import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import 'ui/home_screen.dart';
import 'ui/scenes.dart';

const featureMultipleVehicles = 'multiple_vehicles';
const featureExport = 'export';

const fuelConfig = AppConfig(
  appName: 'Wrenchnote',
  tagline: 'Fuel economy, costs and service reminders',
  privacyPolicyUrl: 'https://shuklamrajat.github.io/widdle-privacy/wrenchnote/',
  seedColor: Color(0xFF3949AB),
  accentColor: Color(0xFFFF7043),
  gradientEndColor: Color(0xFF1A237E),
  paywallScene: fleetProScene,
  onboarding: [
    OnboardingPage(
      icon: Icons.local_gas_station_outlined,
      scene: fillUpScene,
      title: 'Log fill-ups in seconds',
      body: 'Odometer, amount and price. Partial fills and forgotten ones are handled so your economy stays honest.',
    ),
    OnboardingPage(
      icon: Icons.build_outlined,
      scene: serviceScene,
      title: 'Never miss a service',
      body: 'Oil, tires, inspection: get told when they are due by date or by distance, whichever comes first.',
    ),
    OnboardingPage(
      icon: Icons.lock_outline,
      scene: garagePrivacyScene,
      title: 'Your data stays on your phone',
      body: 'No account and no cloud. Export it whenever you like.',
    ),
  ],
  proFeatures: [
    ProFeature(
      id: featureMultipleVehicles,
      title: 'Every vehicle',
      description: 'Track as many cars, bikes and trucks as you own.',
    ),
    ProFeature(id: featureExport, title: 'Export', description: 'CSV and a PDF history, handy when you sell the car.'),
  ],
);

class FuelApp extends StatelessWidget {
  const FuelApp({super.key});

  @override
  Widget build(BuildContext context) => const CoreApp(home: HomeScreen());
}
