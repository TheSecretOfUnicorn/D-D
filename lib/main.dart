
import 'package:flutter/material.dart';
//import 'features/rules_engine/presentation/pages/rules_debug_page.dart';
import 'features/campaign_manager/presentation/pages/campaign_dashboard_page.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/auth/data/repositories/auth_repository.dart';


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
      home: FutureBuilder<bool>(
  future: AuthRepository().checkSession(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Si connecté -> Dashboard, sinon -> AuthPage
    if (snapshot.data == true) {
      return const CampaignDashboardPage();
    } else {
      return const AuthPage();
    }
  },
),
    );
  }
}