import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/agent_login_screen.dart';
import 'screens/agent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NNSAgentApp());
}

class NNSAgentApp extends StatelessWidget {
  const NNSAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NNS Đại Lý',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _fadeCtrl.forward();
    _init();
  }

  Future<void> _setProgress(double val) async {
    if (!mounted) return;
    setState(() => _progress = val);
  }

  Future<void> _init() async {
    await _setProgress(0.2);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('agent_token') ?? '';

    await _setProgress(0.5);
    await Future.delayed(const Duration(milliseconds: 400));

    await _setProgress(0.8);
    await Future.delayed(const Duration(milliseconds: 400));

    await _setProgress(1.0);
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    if (token.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AgentScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AgentLoginScreen()));
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            FadeTransition(
              opacity: _fadeAnim,
              child: Image.asset(
                'assets/nns_agent_logo.png',
                width: w * 0.28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1565C0),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}