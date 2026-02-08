
import 'package:flutter/material.dart';
//import 'features/rules_engine/presentation/pages/rules_debug_page.dart';
import 'features/campaign_manager/presentation/pages/campaign_dashboard_page.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JDR Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkFantasy,   
      home: const CampaignDashboardPage(),
    );
  }
}