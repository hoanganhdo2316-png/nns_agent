import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'agent_login_screen.dart';
import 'agent_profile_screen.dart';

const Color kBlue      = Color(0xFF1565C0);
const Color kBlueDark  = Color(0xFF0D47A1);
const Color kBlueLight = Color(0xFFE3F2FD);
const Color kGreenA      = Color(0xFF2E7D32);
const Color kGreenLightA = Color(0xFFE8F5E9);
const Color kRedA      = Color(0xFFC62828);
const Color kRedLightA = Color(0xFFFFEBEE);
const Color kYellowA      = Color(0xFFE65100);
const Color kYellowLightA = Color(0xFFFFF3E0);
const Color kBgA   = Color(0xFFF0F2F5);
const Color kSurfA = Colors.white;
const Color kBdrA  = Color(0xFFDDE3F0);
const Color kTxtA  = Color(0xFF1A1A3E);
const Color kTxt2A = Color(0xFF4A5580);
const Color kTxt3A = Color(0xFF9AA0C0);

String fmtA(num? n) {
  if (n == null) return '—';
  return n.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
}

class AnimatedBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const AnimatedBtn({super.key, required this.child, required this.onTap});
  @override
  State<AnimatedBtn> createState() => _AnimatedBtnState();
}

class _AnimatedBtnState extends State<AnimatedBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── Agent Vote Row ────────────────────────────────────────────────────────────
class _AgentVoteRow extends StatefulWidget {
  final int likes;
  final int comments;
  const _AgentVoteRow({required this.likes, required this.comments});
  @override
  State<_AgentVoteRow> createState() => _AgentVoteRowState();
}

class _AgentVoteRowState extends State<_AgentVoteRow> {
  int _vote = 0; // 0=none, 1=up, -1=down

  @override
  Widget build(BuildContext context) {
    final score  = widget.likes + (_vote == 1 ? 1 : _vote == -1 ? -1 : 0);
    final isUp   = _vote == 1;
    final isDown = _vote == -1;

    return Row(children: [
      // Pill upvote / score / downvote
      Container(
        height: 34,
        decoration: BoxDecoration(
          color: isUp ? kGreenLightA : isDown ? kRedLightA : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUp ? kGreenA : isDown ? kRedA : const Color(0xFFDDDDDD),
            width: 1.4,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Upvote
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); setState(() => _vote = isUp ? 0 : 1); },
            child: Container(
              width: 36, height: 34,
              decoration: BoxDecoration(
                color: isUp ? kGreenA : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              ),
              child: Icon(Icons.arrow_upward_rounded, size: 17,
                  color: isUp ? Colors.white : kTxt3A),
            ),
          ),
          // Score
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$score', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: isUp ? kGreenA : isDown ? kRedA : kTxt2A,
              letterSpacing: -0.3,
            )),
          ),
          // Downvote
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); setState(() => _vote = isDown ? 0 : -1); },
            child: Container(
              width: 36, height: 34,
              decoration: BoxDecoration(
                color: isDown ? kRedA : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
              ),
              child: Icon(Icons.arrow_downward_rounded, size: 17,
                  color: isDown ? Colors.white : kTxt3A),
            ),
          ),
        ]),
      ),

      const SizedBox(width: 10),

      // Pill comment
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDDDDD), width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: kTxt3A),
          const SizedBox(width: 5),
          Text('${widget.comments}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTxt2A)),
          const SizedBox(width: 4),
          const Text('bình luận', style: TextStyle(fontSize: 12, color: kTxt3A)),
        ]),
      ),
    ]);
  }
}

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});
  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  Map<String, dynamic>? _agent;
  List<dynamic> _allAgents = [];
  bool _loading = true;
  String _screen = 'home';
  String _token  = '';
  String _saved  = '';
  String _error  = '';

  int _currentPrice  = 0;
  int _originalPrice = 0;
  Map<String, String> _profileForm = {};
  List<Map<String, dynamic>> _priceTable = [];
  List<dynamic> _catalog = [];

  // Customers
  List<dynamic> _followers = [];
  List<dynamic> _viewers   = [];
  bool _customersLoading   = false;
  int _customerTab         = 0;

  // Posts
  List<dynamic> _agentPosts   = [];
  bool _postsLoading          = false;
  final _postCtrl = TextEditingController();

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('agent_token') ?? '';
    setState(() => _token = token);
    if (token.isNotEmpty) {
      await _fetchMe();
      await _fetchAllAgents();
      await _fetchPosts();
    }
    setState(() => _loading = false);
  }

  Future<void> _fetchMe() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.nns.id.vn/agent/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _agent = d;
          _currentPrice  = (d['price'] as num?)?.toInt() ?? 0;
          _originalPrice = _currentPrice;
          _profileForm = {
            'name': d['name'] ?? '', 'address': d['address'] ?? '',
            'phone': d['phone'] ?? '', 'phone2': d['phone2'] ?? '',
            'zalo': d['zalo'] ?? '', 'email': d['email'] ?? '',
          };
          _priceTable = List<Map<String, dynamic>>.from(
              (d['price_table'] as List? ?? []).map((e) => {
                'name': e['name']?.toString() ?? '',
                'price': e['price']?.toString() ?? '',
              }));
        });
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        await _logout();
      }
    } catch (e) { debugPrint('fetchMe error: $e'); }
  }

  Future<void> _fetchAllAgents() async {
    try {
      final res = await http.get(Uri.parse('https://api.nns.id.vn/agents'));
      if (res.statusCode == 200) setState(() => _allAgents = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await http.get(Uri.parse('https://api.nns.id.vn/catalog'));
      if (res.statusCode == 200) setState(() => _catalog = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> _fetchCustomers() async {
    setState(() => _customersLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://api.nns.id.vn/agent/customers'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _followers = d['followers'] ?? [];
          _viewers   = d['viewers']   ?? [];
        });
      }
    } catch (_) {}
    setState(() => _customersLoading = false);
  }

  Future<void> _fetchPosts() async {
    if (_agent == null) return;
    setState(() => _postsLoading = true);
    try {
      final agentId = _agent!['_id']?.toString() ?? '';
      final res = await http.get(
        Uri.parse('https://api.nns.id.vn/agent/$agentId/posts'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        setState(() => _agentPosts = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (_) {}
    setState(() => _postsLoading = false);
  }

  Future<void> _createPost(String content) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.nns.id.vn/agent/posts'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'content': content}),
      );
      if (res.statusCode == 200) await _fetchPosts();
    } catch (_) {}
  }

  Future<void> _deletePost(String postId) async {
    try {
      await http.delete(
        Uri.parse('https://api.nns.id.vn/agent/posts/$postId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      await _fetchPosts();
    } catch (_) {}
  }

  void _showPostDialog() {
    _postCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Viết gì đó cho khách hàng'),
        content: TextField(
          controller: _postCtrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập nội dung...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBlue, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final content = _postCtrl.text.trim();
              if (content.isEmpty) return;
              Navigator.pop(ctx);
              await _createPost(content);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white),
            child: const Text('Đăng', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('agent_token');
    await prefs.remove('agentId');
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
          (route) => false);
    }
  }

  Future<void> _updatePrice() async {
    try {
      final res = await http.put(
        Uri.parse('https://api.nns.id.vn/agent/price'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'price': _currentPrice, 'note': ''}),
      );
      if (res.statusCode == 200) {
        setState(() { _saved = '✅ Đã cập nhật giá!'; _originalPrice = _currentPrice; });
        await _fetchMe();
      }
    } catch (_) { setState(() => _error = 'Lỗi kết nối server'); }
  }

  Future<void> _savePriceTable() async {
    final items = _priceTable
        .where((i) => i['name'].toString().isNotEmpty)
        .map((i) => {'name': i['name'], 'price': int.tryParse(i['price'].toString()) ?? 0})
        .toList();
    try {
      final res = await http.put(
        Uri.parse('https://api.nns.id.vn/agent/price-table'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode({'items': items}),
      );
      if (res.statusCode == 200) setState(() => _saved = '✅ Đã lưu bảng giá!');
    } catch (_) {}
  }

  Future<void> _updateProfile() async {
    try {
      final res = await http.put(
        Uri.parse('https://api.nns.id.vn/agent/profile'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode(_profileForm),
      );
      if (res.statusCode == 200) { setState(() => _saved = '✅ Đã lưu thông tin!'); await _fetchMe(); }
    } catch (_) {}
  }

  Future<void> _addFromCatalog(String id) async {
    try {
      final res = await http.post(Uri.parse('https://api.nns.id.vn/agent/catalog/$id/add'),
          headers: {'Authorization': 'Bearer $_token'});
      if (res.statusCode == 200) { setState(() => _saved = '✅ Đã thêm sản phẩm!'); await _fetchMe(); }
    } catch (_) {}
  }

  Future<void> _removeProduct(String id) async {
    try {
      await http.delete(Uri.parse('https://api.nns.id.vn/agent/catalog/$id/remove'),
          headers: {'Authorization': 'Bearer $_token'});
      setState(() => _saved = '✅ Đã xóa sản phẩm!');
      await _fetchMe();
    } catch (_) {}
  }

  double get _avgPrice {
    final valid = _allAgents.where((a) => (a['price'] ?? 0) > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.fold<double>(0, (s, a) => s + (a['price'] as num)) / valid.length;
  }

  bool get _updatedToday {
    final updatedAt = _agent?['updated_at'];
    if (updatedAt == null) return false;
    DateTime dt;
    if (updatedAt is String) {
      dt = DateTime.parse(updatedAt).toLocal();
    } else { return false; }
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBgA,
        body: Center(child: CircularProgressIndicator(color: kBlue)),
      );
    }
    return Scaffold(
      backgroundColor: kBgA,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: RefreshIndicator(
          color: kBlue,
          onRefresh: () async { await _fetchMe(); await _fetchAllAgents(); await _fetchPosts(); },
          child: _buildBody(),
        )),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: kBlueDark),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            if (_screen != 'home')
              GestureDetector(
                onTap: () => setState(() { _screen = 'home'; _saved = ''; _error = ''; }),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('N', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NNS Đại lý',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              if (_agent?['name'] != null)
                Text(_agent!['name'],
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () { HapticFeedback.mediumImpact(); _logout(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Đăng xuất',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screen) {
      case 'price':     return _buildPriceScreen();
      case 'shop':      return _buildShopScreen();
      case 'info':      return _buildInfoScreen();
      case 'customers': return _buildCustomersScreen();
      default:          return _buildHomeScreen();
    }
  }

  // ── HOME ──────────────────────────────────────────────────────────────────

  Widget _buildHomeScreen() {
    final agent = _agent;
    if (agent == null) return const Center(child: Text('Không có dữ liệu'));

    final name      = (agent['name'] ?? '') as String;
    final initials  = name.trim().split(' ').where((w) => w.isNotEmpty).take(2)
        .map((w) => w[0].toUpperCase()).join();
    final avatarUrl = agent['avatar_url'] as String?;

    final today    = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    final closingHistory = (agent['closing_price_history'] as List? ?? []);
    final yesterdayEntry = closingHistory.lastWhere(
      (e) => (e['date'] ?? '') != todayStr, orElse: () => null);
    final yesterdayPrice = yesterdayEntry != null
        ? (yesterdayEntry['price'] as num?)?.toInt() : null;

    final avg = _avgPrice;

    return ListView(
      padding: EdgeInsets.zero,
      children: [

        // ── 1. CARD GIÁ HÔM QUA ─────────────────────────────────────────
        if (yesterdayPrice != null && yesterdayPrice > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: kSurfA,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBdrA),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.history_rounded, color: kBlue, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('GIÁ THU MUA HÔM QUA', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: kTxt3A, letterSpacing: 0.5,
                )),
                const SizedBox(height: 4),
                Text('${fmtA(yesterdayPrice)} đ/kg',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                        color: kTxtA, fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(name, style: const TextStyle(fontSize: 12, color: kTxt2A)),
              ])),
            ]),
          ),

        const SizedBox(height: 8),

        // ── 2. KHUNG CẬP NHẬT GIÁ ────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: kSurfA,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _updatedToday ? kGreenA : kBlue, width: 1.5),
            boxShadow: [BoxShadow(color: (_updatedToday ? kGreenA : kBlue).withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: _updatedToday
                      ? [const Color(0xFF1B5E20), kGreenA]
                      : [kBlueDark, kBlue],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                _avatar(avatarUrl, initials, 48),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _updatedToday ? 'Giá hôm nay của bạn' : 'Chưa cập nhật hôm nay',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _updatedToday && _originalPrice > 0 ? '${fmtA(_originalPrice)} đ/kg' : '— đ/kg',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                        color: Colors.white, fontFamily: 'monospace', letterSpacing: -0.5),
                  ),
                ])),
                if (_updatedToday)
                  Builder(builder: (_) {
                    final change = (_agent?['change'] as num?)?.toInt() ?? 0;
                    if (change == 0) return const SizedBox.shrink();
                    final isUp = change > 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${isUp ? '▲ +' : '▼ '}${fmtA(change.abs())}đ',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                              color: Colors.white, fontFamily: 'monospace')),
                    );
                  }),
              ]),
            ),

            if (!_updatedToday) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('Hôm nay ${name.split(' ').last} mua cà phê giá bao nhiêu?',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTxtA)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(children: [
                  if (avg > 0)
                    _quickPriceBtn('📊 Theo TB thị trường  •  ${fmtA(avg.round())}đ/kg',
                        kBlueLight, kBlue,
                        () { setState(() => _currentPrice = avg.round()); _updatePrice(); }),
                  const SizedBox(height: 8),
                  if (_originalPrice > 0)
                    _quickPriceBtn('🔄 Giữ giá cũ  •  ${fmtA(_originalPrice)}đ/kg',
                        kGreenLightA, kGreenA,
                        () { setState(() => _currentPrice = _originalPrice); _updatePrice(); }),
                  const SizedBox(height: 8),
                  if (_allAgents.isNotEmpty)
                    Builder(builder: (_) {
                      final others = _allAgents.where((a) =>
                          (a['price'] ?? 0) > 0 && a['_id'] != agent['_id']).toList();
                      if (others.isEmpty) return const SizedBox.shrink();
                      others.shuffle();
                      final ref = others.first;
                      return _quickPriceBtn(
                        '👥 Theo ${ref['name']?.toString().split(' ').last ?? 'đại lý khác'}  •  ${fmtA((ref['price'] as num?)?.toInt())}đ/kg',
                        kYellowLightA, kYellowA,
                        () { setState(() => _currentPrice = (ref['price'] as num).toInt()); _updatePrice(); },
                      );
                    }),
                  const SizedBox(height: 4),
                ]),
              ),
            ],

            const Divider(height: 1, color: kBdrA),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: AnimatedBtn(
                onTap: () => setState(() { _screen = 'price'; _saved = ''; _error = ''; }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [kBlueDark, kBlue],
                        begin: Alignment.centerLeft, end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: kBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.edit, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(_updatedToday ? 'Cập nhật lại giá' : 'Nhập giá hôm nay',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 8),

        // ── 3. 3 NÚT CHỨC NĂNG ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: kSurfA,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            _funcBtn(Icons.storefront_outlined, 'Cửa hàng', kGreenA, kGreenLightA, () {
              setState(() { _screen = 'shop'; _saved = ''; _error = ''; });
              _fetchCatalog();
            }),
            _funcBtn(Icons.people_outlined, 'Tệp KH', kBlue, kBlueLight, () {
              setState(() { _screen = 'customers'; _saved = ''; _error = ''; });
              _fetchCustomers();
            }),
            _funcBtn(Icons.person_outlined, 'Trang cá nhân', const Color(0xFF6A1B9A), const Color(0xFFF3E5F5), () {
              if (_agent != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AgentProfileScreen(agent: _agent!, token: _token),
                ));
              }
            }),
          ]),
        ),

        const SizedBox(height: 8),

        // ── 4. BOX VIẾT STATUS ────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kSurfA,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Row(children: [
              _avatar(avatarUrl, initials, 38),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _showPostDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: kBgA,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBdrA),
                    ),
                    child: const Text('Viết gì đó cho khách hàng...',
                        style: TextStyle(fontSize: 14, color: kTxt3A)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: kBdrA),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _postActionBtn(Icons.photo_library_outlined, 'Ảnh/Video', kGreenA),
              _postActionBtn(Icons.price_change_outlined, 'Cập nhật giá', kBlue),
              _postActionBtn(Icons.local_offer_outlined, 'Khuyến mãi', kYellowA),
            ]),
          ]),
        ),

        const SizedBox(height: 8),

        // ── 5. FEED POSTS ────────────────────────────────────────────────
        if (_postsLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: kBlue)),
          ),
        ..._agentPosts.map((post) => _buildPostCard(post, avatarUrl, initials, name)),

        if (!_postsLoading && _agentPosts.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSurfA,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBdrA),
            ),
            child: const Center(
              child: Text('Chưa có bài viết nào.\nHãy chia sẻ gì đó với khách hàng!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: kTxt3A, height: 1.5)),
            ),
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  // ── CUSTOMERS SCREEN ──────────────────────────────────────────────────────

  Widget _buildCustomersScreen() {
    final list = _customerTab == 0 ? _followers : _viewers;

    return Column(children: [
      Container(
        color: kSurfA,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(children: [
          _custTab(0, Icons.star_rounded, 'Theo dõi', _followers.length),
          const SizedBox(width: 8),
          _custTab(1, Icons.visibility_rounded, 'Đã xem', _viewers.length),
          const Spacer(),
          GestureDetector(
            onTap: _fetchCustomers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.refresh, size: 14, color: kBlue),
                SizedBox(width: 4),
                Text('Làm mới', style: TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: kBdrA),

      Expanded(
        child: _customersLoading
            ? const Center(child: CircularProgressIndicator(color: kBlue))
            : list.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_customerTab == 0 ? Icons.star_border_rounded : Icons.visibility_off_outlined,
                        size: 56, color: kTxt3A),
                    const SizedBox(height: 12),
                    Text(_customerTab == 0 ? 'Chưa có ai theo dõi bạn' : 'Chưa có ai xem profile',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTxt2A)),
                    const SizedBox(height: 6),
                    Text(
                      _customerTab == 0
                          ? 'Khi nông dân nhấn ⭐ vào đại lý của bạn\ntrên app NNS, họ sẽ xuất hiện ở đây'
                          : 'Khi nông dân vào xem profile của bạn\ntrên app NNS, họ sẽ xuất hiện ở đây',
                      style: const TextStyle(fontSize: 13, color: kTxt3A, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = list[_customerTab == 0 ? i : list.length - 1 - i];
                      final phone   = item['phone']?.toString() ?? '';
                      final initial = phone.isNotEmpty ? phone[phone.length > 4 ? phone.length - 4 : 0] : '?';
                      final timeStr = _customerTab == 1
                          ? _formatCustomerTime(item['at']?.toString() ?? '')
                          : _formatCustomerTime(item['joined_at']?.toString() ?? '');

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kSurfA,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBdrA),
                        ),
                        child: Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _customerTab == 0 ? const Color(0xFFFFF8E1) : kBlueLight,
                              border: Border.all(
                                color: _customerTab == 0 ? const Color(0xFFFFB300) : kBlue,
                                width: 1.5,
                              ),
                            ),
                            child: Center(child: Text(initial.toUpperCase(),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                                    color: _customerTab == 0 ? const Color(0xFFFFB300) : kBlue))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(phone.isNotEmpty ? _maskPhone(phone) : 'Ẩn danh',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTxtA)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _customerTab == 0 ? const Color(0xFFFFF8E1) : kBlueLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_customerTab == 0 ? '⭐ Theo dõi' : '👁 Đã xem',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                        color: _customerTab == 0 ? const Color(0xFFFFB300) : kBlue)),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Text(timeStr, style: const TextStyle(fontSize: 12, color: kTxt3A)),
                          ])),
                          if (phone.isNotEmpty)
                            GestureDetector(
                              onTap: () { HapticFeedback.mediumImpact(); },
                              child: Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kGreenLightA,
                                  border: Border.all(color: kGreenA.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.phone_outlined, color: kGreenA, size: 18),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  Widget _custTab(int idx, IconData icon, String label, int count) {
    final on = _customerTab == idx;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _customerTab = idx); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? kBlue : kBgA,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: on ? Colors.white : kTxt3A),
          const SizedBox(width: 5),
          Text('$label ($count)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: on ? Colors.white : kTxt2A)),
        ]),
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}';
  }

  String _formatCustomerTime(String s) {
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z').toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24)   return '${diff.inHours} giờ trước';
      if (diff.inDays < 7)     return '${diff.inDays} ngày trước';
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return s; }
  }

  // ── PRICE SCREEN ──────────────────────────────────────────────────────────

  Widget _buildPriceScreen() {
    final diff   = _currentPrice - _originalPrice;
    final isUp   = diff > 0;
    final isFlat = diff == 0;
    final clr    = isFlat ? kYellowA : isUp ? kGreenA : kRedA;
    final avg    = _avgPrice;

    return ListView(padding: const EdgeInsets.all(12), children: [
      if (_saved.isNotEmpty) _msgBox(_saved, kGreenLightA, kGreenA),
      if (_error.isNotEmpty) _msgBox(_error, kRedLightA, kRedA),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('💰 Giá mua chính', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlue)),
          if (diff != 0) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: isUp ? kGreenLightA : kRedLightA, borderRadius: BorderRadius.circular(8)),
            child: Text('${isUp ? '▲ +' : '▼ '}${fmtA(diff.abs())}đ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: clr, fontFamily: 'monospace')),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _circleBtn('−', clr, () => setState(() => _currentPrice = (_currentPrice - 100).clamp(0, 999999999))),
          Expanded(child: Column(children: [
            Text(fmtA(_currentPrice),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: clr, fontFamily: 'monospace'),
                textAlign: TextAlign.center),
            const Text('đ/kg', style: TextStyle(fontSize: 11, color: kTxt3A)),
          ])),
          _circleBtn('+', clr, () => setState(() => _currentPrice += 100)),
        ]),
        const SizedBox(height: 12),
        Center(child: AnimatedBtn(
          onTap: _showManualInput,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: kBdrA), borderRadius: BorderRadius.circular(8)),
            child: const Text('✏️ Nhập tay', style: TextStyle(fontSize: 12, color: kTxt2A)),
          ),
        )),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kYellowLightA, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [Text('🔐 '), Text('Nhấn nút bên dưới để cập nhật giá', style: TextStyle(fontSize: 12, color: kYellowA))]),
        ),
        const SizedBox(height: 12),
        _bigBtn(diff != 0 ? '💰 Cập nhật giá' : '✅ Giữ giá hiện tại', kBlue, Colors.white, _updatePrice),
        if (avg > 0) ...[
          const SizedBox(height: 8),
          _bigBtn('Cập nhật theo TB thị trường (${fmtA(avg.round())}đ)',
              const Color(0xFF00695C), Colors.white,
              () { setState(() => _currentPrice = avg.round()); _updatePrice(); }),
        ],
      ])),
      const SizedBox(height: 12),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('📋 Bảng giá', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlue)),
          AnimatedBtn(
            onTap: () => setState(() => _priceTable.add({'name': '', 'price': ''})),
            child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('+', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)))),
          ),
        ]),
        const SizedBox(height: 12),
        if (_priceTable.isEmpty)
          const Center(child: Text('Chưa có phân loại. Nhấn + để thêm.', style: TextStyle(fontSize: 13, color: kTxt3A))),
        ..._priceTable.asMap().entries.map((e) {
          final i = e.key;
          return Row(children: [
            Expanded(flex: 2, child: TextField(
              controller: TextEditingController(text: _priceTable[i]['name']),
              onChanged: (v) => _priceTable[i]['name'] = v,
              decoration: _inp('Tên phân loại'),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: TextEditingController(text: _priceTable[i]['price'].toString()),
              onChanged: (v) => _priceTable[i]['price'] = v,
              keyboardType: TextInputType.number,
              decoration: _inp('Giá'),
            )),
            const SizedBox(width: 8),
            AnimatedBtn(
              onTap: () => setState(() => _priceTable.removeAt(i)),
              child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: kRedLightA, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('🗑', style: TextStyle(fontSize: 14)))),
            ),
          ]);
        }),
        if (_priceTable.isNotEmpty) ...[
          const SizedBox(height: 12),
          _bigBtn('💾 Lưu bảng giá', kGreenA, Colors.white, _savePriceTable),
        ],
      ])),
    ]);
  }

  // ── SHOP SCREEN ───────────────────────────────────────────────────────────

  Widget _buildShopScreen() {
    final products = (_agent?['products'] as List? ?? []).cast<Map<String, dynamic>>();
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (_saved.isNotEmpty) _msgBox(_saved, kGreenLightA, kGreenA),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏪 Sản phẩm đang bán (${products.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlue)),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const Center(child: Text('Chưa có sản phẩm nào', style: TextStyle(fontSize: 13, color: kTxt3A))),
        ...products.map((p) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBdrA))),
          child: Row(children: [
            Container(width: 48, height: 48,
                decoration: BoxDecoration(color: kBgA, borderRadius: BorderRadius.circular(10)),
                child: p['image_url'] != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p['image_url'], fit: BoxFit.cover))
                    : const Center(child: Text('📦', style: TextStyle(fontSize: 20)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${fmtA(p['price'] as num?)}đ/${p['unit'] ?? 'kg'}',
                  style: const TextStyle(fontSize: 11, color: kBlue)),
            ])),
            AnimatedBtn(
              onTap: () => _removeProduct(p['id'].toString()),
              child: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kRedLightA, borderRadius: BorderRadius.circular(8)),
                  child: const Text('🗑', style: TextStyle(fontSize: 16))),
            ),
          ]),
        )),
      ])),
      const SizedBox(height: 12),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('📦 Danh mục sản phẩm',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kGreenA)),
          AnimatedBtn(
            onTap: _fetchCatalog,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kGreenLightA, borderRadius: BorderRadius.circular(8)),
                child: const Text('↻ Tải lại',
                    style: TextStyle(fontSize: 12, color: kGreenA, fontWeight: FontWeight.w700))),
          ),
        ]),
        const SizedBox(height: 12),
        if (_catalog.isEmpty)
          const Center(child: Text('Chưa có sản phẩm trong danh mục',
              style: TextStyle(fontSize: 13, color: kTxt3A))),
        ..._catalog.map((p) {
          final added = products.any((ap) => ap['id'].toString() == p['id'].toString());
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBdrA))),
            child: Row(children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: kBgA, borderRadius: BorderRadius.circular(10)),
                  child: p['image_url'] != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p['image_url'], fit: BoxFit.cover))
                      : const Center(child: Text('📦', style: TextStyle(fontSize: 20)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${fmtA(p['price'] as num?)}đ/${p['unit'] ?? 'kg'}',
                    style: const TextStyle(fontSize: 11, color: kBlue)),
              ])),
              added
                  ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: kGreenLightA, borderRadius: BorderRadius.circular(8)),
                      child: const Text('✓ Đang bán',
                          style: TextStyle(fontSize: 11, color: kGreenA, fontWeight: FontWeight.w700)))
                  : AnimatedBtn(
                      onTap: () => _addFromCatalog(p['id'].toString()),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(10)),
                          child: const Text('+ Thêm',
                              style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)))),
            ]),
          );
        }),
      ])),
    ]);
  }

  // ── INFO SCREEN ───────────────────────────────────────────────────────────

  Widget _buildInfoScreen() {
    final fields = [
      ['name', 'Tên đại lý'], ['address', 'Địa chỉ'], ['phone', 'SĐT chính'],
      ['phone2', 'SĐT phụ'], ['zalo', 'Zalo'], ['email', 'Email'],
    ];
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (_saved.isNotEmpty) _msgBox(_saved, kGreenLightA, kGreenA),
      _card(child: Column(children: [
        ...fields.map((f) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f[1], style: const TextStyle(fontSize: 12, color: kTxt3A)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: _profileForm[f[0]] ?? ''),
            onChanged: (v) => _profileForm[f[0]] = v,
            decoration: _inp(f[1]),
          ),
          const SizedBox(height: 10),
        ])),
        _bigBtn('💾 Lưu thông tin', kBlue, Colors.white, _updateProfile),
      ])),
    ]);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _avatar(String? url, String initials, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: kBlueLight,
        border: Border.all(color: kBdrA, width: 1.5),
        image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
      ),
      child: url == null
          ? Center(child: Text(initials,
              style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.w800, color: kBlue)))
          : null,
    );
  }

  Widget _quickPriceBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return AnimatedBtn(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }

  Widget _funcBtn(IconData icon, String label, Color color, Color bg, VoidCallback onTap) {
    return Expanded(
      child: AnimatedBtn(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTxtA),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _postActionBtn(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {},
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _buildPostCard(dynamic post, String? avatarUrl, String initials, String name) {
    final postId   = post['_id']?.toString() ?? '';
    final content  = post['content']?.toString() ?? '';
    final timeStr  = _formatCustomerTime(post['created_at']?.toString() ?? '');
    final likes    = post['likes_count'] ?? (post['likes'] as List?)?.length ?? 0;
    final comments = post['comments_count'] ?? (post['comments'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: kSurfA,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBdrA),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            _avatar(avatarUrl, initials, 40),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTxtA)),
              Text(timeStr, style: const TextStyle(fontSize: 11, color: kTxt3A)),
            ])),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Xóa bài viết?'),
                  content: const Text('Bài viết sẽ bị xóa vĩnh viễn.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _deletePost(postId); },
                      child: const Text('Xóa', style: TextStyle(color: kRedA)),
                    ),
                  ],
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kRedLightA, borderRadius: BorderRadius.circular(8)),
                child: const Text('Xóa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedA)),
              ),
            ),
          ]),
        ),
        // Nội dung
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Text(content, style: const TextStyle(fontSize: 14, color: kTxtA, height: 1.5)),
        ),
        const Divider(height: 1, color: kBdrA),
        // Vote row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: _AgentVoteRow(likes: likes, comments: comments),
        ),
      ]),
    );
  }

  void _showManualInput() {
    final ctrl = TextEditingController(text: _currentPrice > 0 ? _currentPrice.toString() : '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Nhập giá'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập giá đ/kg', suffix: Text('đ/kg'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        TextButton(onPressed: () {
          final v = int.tryParse(ctrl.text);
          if (v != null) setState(() => _currentPrice = v);
          Navigator.pop(ctx);
        }, child: const Text('OK')),
      ],
    ));
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: kSurfA, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Widget _msgBox(String msg, Color bg, Color fg) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(msg, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600)),
  );

  Widget _bigBtn(String label, Color bg, Color fg, VoidCallback onTap) => AnimatedBtn(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
    ),
  );

  Widget _circleBtn(String label, Color clr, VoidCallback onTap) => AnimatedBtn(
    onTap: onTap,
    child: Container(width: 48, height: 48,
      decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: clr, width: 2), color: kBgA),
      child: Center(child: Text(label,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: clr))),
    ),
  );

  InputDecoration _inp(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: kTxt3A, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBdrA)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBdrA)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBlue)),
    filled: true, fillColor: const Color(0xFFF8FAFF),
  );
}