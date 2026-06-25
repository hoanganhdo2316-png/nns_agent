import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

const Color kBlue      = Color(0xFF1565C0);
const Color kBlueDark  = Color(0xFF0D47A1);
const Color kBlueLight = Color(0xFFE3F2FD);
const Color kGreenA      = Color(0xFF2E7D32);
const Color kGreenLightA = Color(0xFFE8F5E9);
const Color kBgA   = Color(0xFFF0F2F5);
const Color kSurfA = Colors.white;
const Color kBdrA  = Color(0xFFDDE3F0);
const Color kTxtA  = Color(0xFF1A1A3E);
const Color kTxt2A = Color(0xFF4A5580);
const Color kTxt3A = Color(0xFF9AA0C0);
const Color kRedA  = Color(0xFFC62828);

String _fmtA(num? n) {
  if (n == null) return '—';
  return n.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class AgentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> agent;
  final String token;
  const AgentProfileScreen({super.key, required this.agent, required this.token});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  late Map<String, dynamic> _agent;
  bool _uploading = false;
  String _uploadMsg = '';
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _agent = Map<String, dynamic>.from(widget.agent);
  }

  Future<void> _pickAndUpload(String type) async {
    HapticFeedback.mediumImpact();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: kBlue),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: kBlue),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;

    final picked = await _picker.pickImage(source: src, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;

    setState(() { _uploading = true; _uploadMsg = ''; });

    try {
      final uri = Uri.parse(
        type == 'avatar'
            ? 'https://api.nns.id.vn/agent/upload-avatar'
            : 'https://api.nns.id.vn/agent/upload-cover',
      );
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));
      final streamed = await req.send();
      final res      = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final url = jsonDecode(res.body)['url'] as String;
        setState(() {
          if (type == 'avatar') {
            _agent['avatar_url'] = url;
          } else {
            _agent['cover_url'] = url;
          }
          _uploadMsg = '✅ Đã cập nhật ảnh!';
        });
      } else {
        setState(() => _uploadMsg = '❌ Lỗi: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _uploadMsg = '❌ Không kết nối được server');
    }
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final name      = (_agent['name'] ?? '') as String;
    final initials  = name.trim().split(' ').where((w) => w.isNotEmpty).take(2)
        .map((w) => w[0].toUpperCase()).join();
    final avatarUrl = _agent['avatar_url'] as String?;
    final coverUrl  = _agent['cover_url']  as String?;
    final price     = (_agent['price'] as num?)?.toDouble() ?? 0;
    final change    = (_agent['change'] as num?)?.toDouble() ?? 0;
    final isUp      = change > 0;
    final isFlat    = change == 0;
    final chgClr    = isFlat ? const Color(0xFFE65100) : isUp ? kGreenA : kRedA;
    final products  = (_agent['products'] as List? ?? []);
    final views     = _agent['views'] ?? 0;

    return Scaffold(
      backgroundColor: kBgA,
      body: CustomScrollView(
        slivers: [
          // ── APP BAR với ảnh bìa ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: kBlueDark,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => _pickAndUpload('cover'),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Đổi ảnh bìa', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                // Ảnh bìa
                coverUrl != null
                    ? Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kBlueDark, kBlue],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                          ),
                        ))
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kBlueDark, kBlue],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Text('Nhấn "Đổi ảnh bìa" để thêm ảnh',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ),
                      ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── NỘI DUNG ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(children: [
              // ── Avatar + tên + stats ──
              Container(
                color: kSurfA,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Avatar + nút đổi ảnh bìa cùng hàng
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Stack(children: [
                      Container(
                        width: 86, height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kBlueLight,
                          border: Border.all(color: kSurfA, width: 4),
                          image: avatarUrl != null
                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: avatarUrl == null
                            ? Center(child: Text(initials,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kBlue)))
                            : null,
                      ),
                      Positioned(
                        bottom: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => _pickAndUpload('avatar'),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: kBlue, shape: BoxShape.circle,
                              border: Border.all(color: kSurfA, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTxtA)),
                      if (_agent['address'] != null)
                        Text('📍 ${_agent['address']}',
                            style: const TextStyle(fontSize: 12, color: kTxt3A),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                  const SizedBox(height: 10),

                  // Upload message
                  if (_uploading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kBlue)),
                        SizedBox(width: 8),
                        Text('Đang tải ảnh lên...', style: TextStyle(fontSize: 12, color: kTxt2A)),
                      ]),
                    ),
                  if (_uploadMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_uploadMsg, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _uploadMsg.startsWith('✅') ? kGreenA : kRedA)),
                    ),

                  // Stats row
                  Row(children: [
                    _statItem('$views', 'Lượt xem', Icons.visibility_outlined, kBlue),
                    const SizedBox(width: 8),
                    _statItem('${products.length}', 'Sản phẩm', Icons.inventory_2_outlined, kGreenA),
                    const SizedBox(width: 8),
                    _statItem(
                      price > 0 ? '${_fmtA(price)}đ' : '—',
                      'Giá hôm nay', Icons.price_change_outlined, chgClr,
                    ),
                  ]),
                ]),
              ),

              const SizedBox(height: 8),

              // ── Giá + biến động ──
              if (price > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSurfA, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBdrA),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('GIÁ THU MUA HIỆN TẠI', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: kTxt3A, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('${_fmtA(price)} đ/kg', style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: chgClr, fontFamily: 'monospace')),
                    ])),
                    if (change != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isUp ? kGreenLightA : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${isUp ? '▲ +' : '▼ '}${_fmtA(change.abs())}đ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                              color: chgClr, fontFamily: 'monospace'),
                        ),
                      ),
                  ]),
                ),

              const SizedBox(height: 8),

              // ── Thông tin liên hệ ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: kSurfA, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBdrA),
                ),
                child: Column(children: [
                  _infoTile(Icons.phone, 'SĐT chính', _agent['phone']?.toString() ?? '—'),
                  if (_agent['phone2'] != null)
                    _infoTile(Icons.phone_android, 'SĐT phụ', _agent['phone2'].toString()),
                  if (_agent['zalo'] != null)
                    _infoTile(Icons.chat, 'Zalo', _agent['zalo'].toString()),
                  if (_agent['address'] != null)
                    _infoTile(Icons.location_on, 'Địa chỉ', _agent['address'].toString(), isLast: true),
                ]),
              ),

              const SizedBox(height: 8),

              // ── Sản phẩm ──
              if (products.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kSurfA, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBdrA),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🛒 Sản phẩm đang bán',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTxtA)),
                    const SizedBox(height: 10),
                    ...products.cast<Map<String, dynamic>>().map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: kBgA, borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('📦', style: TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p['name'] ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${_fmtA(p['price'] as num?)}đ',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: kGreenA, fontFamily: 'monospace')),
                      ]),
                    )),
                  ]),
                ),
              ],

              const SizedBox(height: 80),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: kBgA, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBdrA),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 3),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: color, fontFamily: 'monospace'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(fontSize: 9, color: kTxt3A),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String val, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : kBdrA)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: kTxt3A),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(
              fontSize: 10, color: kTxt3A, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTxtA)),
        ])),
      ]),
    );
  }
}