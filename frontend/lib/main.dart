import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
//  MODEL
// ============================================================

class Barang {
  final int? id;
  String nama, kategori, satuan;
  int harga, stok;

  Barang({
    this.id,
    required this.nama,
    required this.kategori,
    required this.satuan,
    required this.harga,
    required this.stok,
  });

  factory Barang.fromJson(Map<String, dynamic> json) => Barang(
        id: json['id'],
        nama: json['nama'] ?? '',
        kategori: json['kategori'] ?? '',
        satuan: json['satuan'] ?? '',
        harga: int.tryParse(json['harga']?.toString() ?? '0') ?? 0,
        stok: int.tryParse(json['stok']?.toString() ?? '0') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'kategori': kategori,
        'satuan': satuan,
        'harga': harga,
        'stok': stok,
      };
}

class Pesanan {
  final int? id;
  final String kode;
  final List<PesananItem> items;
  final int total;
  final String status;
  final DateTime createdAt;

  Pesanan({
    this.id,
    required this.kode,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory Pesanan.fromJson(Map<String, dynamic> json) => Pesanan(
        id: json['id'],
        kode: json['kode'] ?? '',
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => PesananItem.fromJson(e))
                .toList() ??
            [],
        total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
        status: json['status'] ?? 'proses',
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kode': kode,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'status': status,
      };
}

class PesananItem {
  String namaBarang;
  int jumlah, hargaSatuan;

  PesananItem({required this.namaBarang, required this.jumlah, required this.hargaSatuan});

  factory PesananItem.fromJson(Map<String, dynamic> json) => PesananItem(
        namaBarang: json['nama_barang'] ?? '',
        jumlah: int.tryParse(json['jumlah']?.toString() ?? '0') ?? 0,
        hargaSatuan: int.tryParse(json['harga_satuan']?.toString() ?? '0') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'nama_barang': namaBarang,
        'jumlah': jumlah,
        'harga_satuan': hargaSatuan,
      };
}

// ============================================================
//  AUTHENTICATION SERVICE
// ============================================================

class AuthService {
  static const String baseUrl = 'http://localhost:8080/api';

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['data']?['token'];
      if (token is! String || token.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('username', username);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('username');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('jwt_token') ?? '').isNotEmpty;
  }
}

// ============================================================
//  API SERVICE
// ============================================================

class ApiService {
  // Web: localhost. HP fisik: ganti dengan IP komputer, mis. 192.168.1.10.
  static const String baseUrlApi = 'http://localhost:8080/api';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  } 

  Future<List<Barang>> getBarang() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrlApi/stock'), headers: await _headers())
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['data'] as List).map((e) => Barang.fromJson(e)).toList();
      }
    } catch (_) {}
    return _dummyBarang;
  }

  Future<List<Pesanan>> getPesanan() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrlApi/orders'), headers: await _headers())
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['data'] as List).map((e) => Pesanan.fromJson(e)).toList();
      }
    } catch (_) {}
    return _dummyPesanan;
  }

  // ====== MUTASI (POST/PUT/DELETE) ======
  Future<bool> tambahBarang(Barang b) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrlApi/stock'),
            headers: await _headers(),
            body: jsonEncode(b.toJson()),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editBarang(Barang b) async {
    if (b.id == null) return false;
    try {
      final resp = await http
          .put(
            Uri.parse('$baseUrlApi/stock/${b.id}'),
            headers: await _headers(),
            body: jsonEncode(b.toJson()),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hapusBarang(int id) async {
    try {
      final resp = await http
          .delete(Uri.parse('$baseUrlApi/stock/$id'), headers: await _headers())
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> buatPesanan(Pesanan p) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrlApi/orders'),
            headers: await _headers(),
            body: jsonEncode(p.toJson()),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ubahStatusPesanan(int id, String status) async {
    try {
      final resp = await http
          .put(
            Uri.parse('$baseUrlApi/orders/$id/status'),
            headers: await _headers(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Dummy data saat API belum jalan
  static final List<Barang> _dummyBarang = [
    Barang(nama: 'Garam Cap Udang', kategori: 'Bumbu', satuan: 'pack', harga: 12000, stok: 48),
    Barang(nama: 'Kacang Tuwak', kategori: 'Jajanan', satuan: 'toples', harga: 8500, stok: 32),
    Barang(nama: 'Cabe Kering', kategori: 'Bumbu', satuan: 'kg', harga: 15000, stok: 5),
    Barang(nama: 'Terasi Bakar', kategori: 'Bumbu', satuan: 'pack', harga: 20000, stok: 21),
    Barang(nama: 'Singkong Goreng', kategori: 'Jajanan', satuan: 'kg', harga: 18000, stok: 15),
    Barang(nama: 'Rengginang', kategori: 'Jajanan', satuan: 'pack', harga: 10000, stok: 40),
  ];

  static final List<Pesanan> _dummyPesanan = [
    Pesanan(
      id: 1,
      kode: '#ORD-001',
      items: [PesananItem(namaBarang: 'Garam Cap Udang', jumlah: 2, hargaSatuan: 12000), PesananItem(namaBarang: 'Terasi Bakar', jumlah: 1, hargaSatuan: 20000)],
      total: 44000,
      status: 'proses',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Pesanan(
      id: 2,
      kode: '#ORD-002',
      items: [PesananItem(namaBarang: 'Cabe Kering', jumlah: 5, hargaSatuan: 15000), PesananItem(namaBarang: 'Kacang Tuwak', jumlah: 3, hargaSatuan: 8500)],
      total: 99500,
      status: 'proses',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    Pesanan(
      id: 3,
      kode: '#ORD-003',
      items: [PesananItem(namaBarang: 'Terasi Bakar', jumlah: 1, hargaSatuan: 20000), PesananItem(namaBarang: 'Garam Cap Udang', jumlah: 2, hargaSatuan: 12000)],
      total: 44000,
      status: 'selesai',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];
}

// ============================================================
//  THEME
// ============================================================

class MaduraTheme {
  static const Color merah = Color(0xFFC1121F);
  static const Color merahTua = Color(0xFF780000);
  static const Color emas = Color(0xFFFDF0D5);
  static const Color hijau = Color(0xFF2A9D8F);
  static const Color bg = Color(0xFFF4F1DE);
  static const Color putih = Color(0xFFFFFFFF);
  static const Color teks = Color(0xFF2B2B2B);
  static const Color abu = Color(0xFF6C757D);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: merah,
          primary: merah,
          secondary: emas,
          surface: putih,
          onPrimary: putih,
        ),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: merah,
          foregroundColor: putih,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: merah,
          foregroundColor: putih,
          elevation: 6,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: putih,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: merah, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: merah,
            foregroundColor: putih,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: merah, textStyle: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: putih,
          selectedItemColor: merah,
          unselectedItemColor: abu,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
        ),
      );
}

// ============================================================
//  UTILITY
// ============================================================

String fmtRupiah(int n) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(n);

String fmtTime(DateTime t) => DateFormat('HH:mm').format(t);

Color stockColor(int s) => s <= 5 ? Colors.red.shade100 : Colors.green.shade100;
Color stockTextColor(int s) => s <= 5 ? Colors.red.shade700 : Colors.green.shade700;

// ============================================================
//  HOME PAGE (with bottom nav)
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  final _api = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [StokTab(api: _api), PesananTab(api: _api), LaporanTab(api: _api)],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Stok'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Laporan'),
        ],
      ),
    );
  }
}

// ============================================================
//  TAB STOK
// ============================================================

class StokTab extends StatefulWidget {
  final ApiService api;
  const StokTab({super.key, required this.api});
  @override
  State<StokTab> createState() => _StokTabState();
}

class _StokTabState extends State<StokTab> {
  List<Barang> _barang = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.api.getBarang();
    setState(() { _barang = data; _loading = false; });
  }

  void _tambahBarang() => _showForm(context);
  void _editBarang(Barang b) => _showForm(context, barang: b);

  Future<void> _showForm(BuildContext ctx, {Barang? barang}) async {
    final isEdit = barang != null;
    final namaCtrl = TextEditingController(text: barang?.nama ?? '');
    final katCtrl = TextEditingController(text: barang?.kategori ?? '');
    final satCtrl = TextEditingController(text: barang?.satuan ?? '');
    final hargaCtrl = TextEditingController(text: barang?.harga.toString() ?? '');
    final stokCtrl = TextEditingController(text: barang?.stok.toString() ?? '');

    Future<void> simpan() async {
      final nama = namaCtrl.text.trim();
      if (nama.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nama barang wajib diisi')));
        return;
      }
      final b = Barang(
        id: barang?.id,
        nama: nama,
        kategori: katCtrl.text.trim(),
        satuan: satCtrl.text.trim(),
        harga: int.tryParse(hargaCtrl.text) ?? 0,
        stok: int.tryParse(stokCtrl.text) ?? 0,
      );

      // Kirim ke server dulu. UI diperbarui hanya kalau server menyimpan,
      // supaya tidak ada data "hantu" yang hilang saat refresh.
      final ok = isEdit ? await widget.api.editBarang(b) : await widget.api.tambahBarang(b);
      if (!ok) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan. Pastikan server API jalan.')),
          );
        }
        return;
      }
      if (ctx.mounted) Navigator.pop(ctx);
      await _load();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(isEdit ? 'Edit Barang' : 'Tambah Barang', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Barang')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: katCtrl, decoration: const InputDecoration(labelText: 'Kategori'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: satCtrl, decoration: const InputDecoration(labelText: 'Satuan'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: hargaCtrl, decoration: const InputDecoration(labelText: 'Harga', prefixText: 'Rp '), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: stokCtrl, decoration: const InputDecoration(labelText: 'Stok'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: simpan, child: Text(isEdit ? 'Simpan' : 'Tambah'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📦 Stok Barang'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _barang.isEmpty
              ? const Center(child: Text('Belum ada barang'))
              : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _barang.length,
                  itemBuilder: (_, i) {
                    final b = _barang[i];
                    return Dismissible(
                      key: Key('barang-${b.id ?? i}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        final id = b.id;
                        if (id != null) await widget.api.hapusBarang(id);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: MaduraTheme.emas, borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(_emoji(b.kategori), style: const TextStyle(fontSize: 24))),
                          ),
                          title: Text(b.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${b.kategori} · ${fmtRupiah(b.harga)} / ${b.satuan}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: stockColor(b.stok), borderRadius: BorderRadius.circular(12)),
                                child: Text('${b.stok} pcs', style: TextStyle(color: stockTextColor(b.stok), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(height: 4),
                              Text(fmtRupiah(b.harga), style: TextStyle(color: MaduraTheme.merahTua, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          onTap: () => _editBarang(b),
                        ),
                      ),
                    );
                  },
                )),
      floatingActionButton: FloatingActionButton(onPressed: _tambahBarang, child: const Icon(Icons.add)),
    );
  }

  String _emoji(String kat) {
    return {'Bumbu': '🧂', 'Jajanan': '🍬', 'Minuman': '🧃', 'Sembako': '🛒'}[kat] ?? '📦';
  }
}

// ============================================================
//  TAB PESANAN
// ============================================================

class PesananTab extends StatefulWidget {
  final ApiService api;
  const PesananTab({super.key, required this.api});
  @override
  State<PesananTab> createState() => _PesananTabState();
}

class _PesananTabState extends State<PesananTab> {
  List<Pesanan> _pesanan = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.api.getPesanan();
    setState(() { _pesanan = data; _loading = false; });
  }

  Future<void> _buatPesanan() async {
    final result = await Navigator.push<Pesanan>(context, MaterialPageRoute(builder: (_) => BuatPesananPage(api: widget.api)));
    if (result != null) {
      // Server sudah menyimpan pesanan dan mengurangi stok.
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final proses = _pesanan.where((p) => p.status == 'proses').toList();
    final selesai = _pesanan.where((p) => p.status == 'selesai').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('🧾 Pesanan'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pesanan.isEmpty
              ? const Center(child: Text('Belum ada pesanan'))
              : RefreshIndicator(onRefresh: _load, child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (proses.isNotEmpty) ...[
                      _sectionHeader('⏳ Dalam Proses', proses.length),
                      ...proses.map((p) => _orderCard(p)),
                    ],
                    if (selesai.isNotEmpty) ...[
                      _sectionHeader('✅ Selesai', selesai.length),
                      ...selesai.map((p) => _orderCard(p)),
                    ],
                  ],
                )),
      floatingActionButton: FloatingActionButton(onPressed: _buatPesanan, child: const Icon(Icons.add)),
    );
  }

  Widget _sectionHeader(String title, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: MaduraTheme.merah.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text('$count', style: const TextStyle(color: MaduraTheme.merah, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
      );

  Widget _orderCard(Pesanan p) {
    final isSelesai = p.status == 'selesai';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.kode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelesai ? Colors.green.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isSelesai ? 'SELESAI' : 'PROSES', style: TextStyle(color: isSelesai ? Colors.green.shade700 : Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const Divider(height: 20),
            ...p.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.jumlah}x ${item.namaBarang}', style: const TextStyle(fontSize: 13)),
                      Text(fmtRupiah(item.jumlah * item.hargaSatuan), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${fmtTime(p.createdAt)} WIB', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                Text(fmtRupiah(p.total), style: const TextStyle(color: MaduraTheme.merahTua, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            if (!isSelesai) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    if (p.id != null) {
                      final ok = await widget.api.ubahStatusPesanan(p.id!, 'selesai');
                      if (ok) await _load();
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: MaduraTheme.hijau, side: BorderSide(color: MaduraTheme.hijau)),
                  child: const Text('Tandai Selesai'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  BUAT PESANAN
// ============================================================

class BuatPesananPage extends StatefulWidget {
  final ApiService api;
  const BuatPesananPage({super.key, required this.api});
  @override
  State<BuatPesananPage> createState() => _BuatPesananPageState();
}

class _BuatPesananPageState extends State<BuatPesananPage> {
  ApiService get _api => widget.api;
  List<Barang> _barang = [];
  final Map<int, int> _keranjang = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.getBarang();
    setState(() => _barang = data);
  }

  int get _total => _barang
      .where((b) => _keranjang.containsKey(b.id))
      .fold(0, (sum, b) => sum + (_keranjang[b.id]! * b.harga));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pesanan')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _barang.length,
              itemBuilder: (_, i) {
                final b = _barang[i];
                final jml = _keranjang[b.id] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${fmtRupiah(b.harga)} / ${b.satuan}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: jml > 0
                                  ? () => setState(() {
                                        if (jml == 1) _keranjang.remove(b.id);
                                        else _keranjang[b.id!] = jml - 1;
                                      })
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                              color: MaduraTheme.merah,
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('$jml', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _keranjang[b.id!] = jml + 1),
                              icon: const Icon(Icons.add_circle_outline),
                              color: MaduraTheme.hijau,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(fmtRupiah(_total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: MaduraTheme.merahTua)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _keranjang.isEmpty || _saving
                          ? null
                          : () async {
                              final items = _barang
                                  .where((b) => _keranjang.containsKey(b.id))
                                  .map((b) => PesananItem(namaBarang: b.nama, jumlah: _keranjang[b.id]!, hargaSatuan: b.harga))
                                  .toList();
                              final pesananBaru = Pesanan(
                                kode: '',
                                items: items,
                                total: _total,
                                status: 'proses',
                                createdAt: DateTime.now(),
                              );
                              setState(() => _saving = true);
                              final ok = await _api.buatPesanan(pesananBaru);
                              if (!mounted) return;
                              if (ok) {
                                Navigator.pop(context, pesananBaru);
                              } else {
                                setState(() => _saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Gagal menyimpan. Pastikan server API jalan.')),
                                );
                              }
                            },
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Buat Pesanan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TAB LAPORAN
// ============================================================

class LaporanTab extends StatelessWidget {
  final ApiService api;
  const LaporanTab({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📊 Laporan Harian')),
      body: FutureBuilder(
        future: Future.wait([api.getBarang(), api.getPesanan()]),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final barang = snap.data![0] as List<Barang>;
          final pesanan = snap.data![1] as List<Pesanan>;
          final totalStok = barang.fold<int>(0, (s, b) => s + b.stok);
          final totalOmset = pesanan.where((p) => p.status == 'selesai').fold<int>(0, (s, p) => s + p.total);
          final today = DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(today, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _summaryCard('Total Barang', '${barang.length}', 'item', Icons.inventory_2, MaduraTheme.merah),
              _summaryCard('Total Stok', '$totalStok', 'pcs', Icons.category, MaduraTheme.hijau),
              _summaryCard('Pesanan Proses', '${pesanan.where((p) => p.status == 'proses').length}', 'order', Icons.hourglass_top, Colors.orange),
              _summaryCard('Omset Hari Ini', fmtRupiah(totalOmset), '', Icons.attach_money, Colors.blue.shade700),
              const SizedBox(height: 24),
              const Text('Barang Stok Rendah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...barang.where((b) => b.stok <= 5).map((b) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber, color: Colors.red),
                      title: Text(b.nama),
                      subtitle: Text('Stok: ${b.stok} ${b.satuan}'),
                      trailing: Text(fmtRupiah(b.harga), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
              if (barang.where((b) => b.stok <= 5).isEmpty) Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    const Text('Semua stok aman!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, String value, String unit, IconData ico, Color color) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(ico, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                  if (unit.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, bottom: 3), child: Text(unit, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

// ============================================================
//  LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  final VoidCallback onSuccess;
  const LoginPage({super.key, required this.onSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin123');
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final auth = AuthService();
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() { _loading = false; _error = 'Login gagal. Cek username/password.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [MaduraTheme.merahTua, MaduraTheme.merah],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('Toko Madura', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: MaduraTheme.merahTua)),
                      const SizedBox(height: 4),
                      const Text('Silakan masuk untuk melanjutkan', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Masuk'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  MAIN APP (dengan auth guard)
// ============================================================

class KasirMaduraApp extends StatelessWidget {
  const KasirMaduraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toko Madura',
      debugShowCheckedModeBanner: false,
      theme: MaduraTheme.theme,
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == true) {
            return const HomePage();
          }
          return LoginPage(onSuccess: () {
            // Paksa rebuild supaya masuk ke HomePage
            RestartWidget.restartApp(ctx);
          });
        },
      ),
    );
  }
}

// Helper kecil untuk restart widget tree (tanpa package ekstra)
class RestartWidget extends StatefulWidget {
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  const RestartWidget({super.key, required this.child});
  final Widget child;

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();
  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

void main() => runApp(const RestartWidget(child: KasirMaduraApp()));
