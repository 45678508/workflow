import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workflow/views/authentication_screens/login_screen.dart';
import 'package:workflow/views/screens/home/home_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(
    initialPage: isLoggedIn ? const HomePage() : const LoginScreen(),
  ));
}

class MyApp extends StatelessWidget {
  final Widget initialPage;

  const MyApp({
    super.key,
    required this.initialPage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 企业微信主题色：#0088FF
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0088FF)),
        useMaterial3: true,
        fontFamily: 'PingFang SC, SimHei', // 匹配企业微信字体
        primaryColor: const Color(0xFF0088FF),
      ),
      home: initialPage,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
      },

      //  防止通过返回键回到主界面
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        );
      },
    );
  }
}