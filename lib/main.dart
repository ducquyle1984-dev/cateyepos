import 'package:cateye_pos/screens/login_page.dart';
import 'package:cateye_pos/screens/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cateye_pos/auth/firebase_options.dart';
import 'package:cateye_pos/provider/auth_provider.dart';
import 'package:cateye_pos/provider/service_order_provider.dart';
import 'package:cateye_pos/provider/catalog_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ServiceOrderProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ],
      child: MaterialApp(
        title: 'Cateye POS',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            if (authProvider.isAuthenticated) {
              return const DashboardPage();
            } else {
              return const LoginPage();
            }
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
