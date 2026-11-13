import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import 'ui/home_screen.dart';
import 'ui/logo.dart';
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
  logo: wrenchnoteLogo,
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
  tour: [
    TourStep(
      target: 'add-fill',
      icon: Icons.local_gas_station_outlined,
      title: 'Log a fill-up',
      body: 'Tap here at the pump. Two full tanks in a row and your real fuel economy appears.',
    ),
    TourStep(
      target: 'vehicle-switcher',
      icon: Icons.directions_car_outlined,
      title: 'Your vehicles',
      body: 'Switch cars here, or add another one for the family or work.',
    ),
    TourStep(
      target: 'tab-service',
      icon: Icons.build_outlined,
      title: 'Service history',
      body: 'Oil changes, tyres and repairs, with reminders before the next one is due.',
    ),
    TourStep(
      target: 'tab-costs',
      icon: Icons.payments_outlined,
      title: 'What it really costs',
      body: 'Fuel and service spending together, with exports for taxes or resale.',
    ),
    TourStep(
      target: 'open-settings',
      icon: Icons.tune,
      title: 'Settings and Pro',
      body: 'Units, currency, theme and Pro features live here. You can take this tour again from Settings any time.',
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
