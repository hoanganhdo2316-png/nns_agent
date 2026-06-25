import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'agent_screen.dart';

const Color kBlue = Color(0xFF1565C0);

class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key});

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _isLoading  = false;
  bool _obscure    = true;
  String? _error;

  Future<void> _login() async {
    HapticFeedback.mediumImpact();
    if (_phoneCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập đầy đủ thông tin');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('https://api.nns.id.vn/auth/agent-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone':    _phoneCtrl.text.trim(),
          'password': _passCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('agent_token', data['token']);
        await prefs.setString('agentId', data['id'] ?? '');

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AgentScreen()),
          (route) => false,
        );
      } else {
        setState(() => _error = data['detail'] ?? 'Sai mã đại lý hoặc mật khẩu');
      }
    } catch (e) {
      setState(() => _error = 'Lỗi kết nối mạng, vui lòng kiểm tra lại Wifi/3G/4G');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Logo
                Image.asset(
                  'assets/nns_agent_logo.png',
                  width: w * 0.28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text('NNS Đại Lý',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: kBlue, letterSpacing: 2)),
                const Text('Dành cho đại lý thu mua',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 36),

                // Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08),
                          blurRadius: 20, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Đăng nhập',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),

                      // SĐT
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại',
                          prefixIcon: const Icon(Icons.phone, color: kBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mật khẩu
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock, color: kBlue),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBlue, width: 2),
                          ),
                        ),
                      ),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Nút đăng nhập
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Đăng nhập',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nút đăng ký
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () async {
                            final uri = Uri.parse('https://nns.id.vn/dangky.html');
                            if (await canLaunchUrl(uri)) {
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kBlue,
                            side: const BorderSide(color: kBlue),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Đăng ký đại lý mới',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}