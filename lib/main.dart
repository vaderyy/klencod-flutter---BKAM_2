import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const WebKamApp());
}

// ================== الحالة العامة ==================
class AppState extends ChangeNotifier {
  String lang = '';
  bool dark = false;
  double fontScale = 1.0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    lang = p.getString('lang') ?? '';
    dark = p.getBool('dark') ?? false;
    fontScale = p.getDouble('font') ?? 1.0;
  }

  Future<void> setLang(String v) async {
    lang = v;
    (await SharedPreferences.getInstance()).setString('lang', v);
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    dark = v;
    (await SharedPreferences.getInstance()).setBool('dark', v);
    notifyListeners();
  }

  Future<void> setFont(double v) async {
    fontScale = v;
    (await SharedPreferences.getInstance()).setDouble('font', v);
    notifyListeners();
  }

  ThemeData get theme {
    final base = dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: dark ? const Color(0xFF1B5E20) : const Color(0xFF42A5F5),
      ),
      scaffoldBackgroundColor: dark ? const Color(0xFF0D1B2A) : Colors.white,
      textTheme: base.textTheme.apply(fontSizeFactor: fontScale),
    );
  }
}

final app = AppState();
String t(String ar, String en) => app.lang == 'ar' ? ar : en;
const String programmer = 'المبرمج احمد امليمدي';

// ================== نموذج المنتج ==================
class Product {
  final String name, size, price, wholesale, imagePath, category;
  final int hash;
  Product(this.name, this.size, this.price, this.wholesale, this.imagePath,
      this.category, this.hash);

  Map<String, dynamic> toJson() => {
        'name': name, 'size': size, 'price': price,
        'wholesale': wholesale, 'imagePath': imagePath,
        'category': category, 'hash': hash,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
      j['name'], j['size'], j['price'], j['wholesale'],
      j['imagePath'], j['category'], j['hash'] ?? 0);
}

Future<List<Product>> loadProducts() async {
  final p = await SharedPreferences.getInstance();
  final s = p.getString('products') ?? '[]';
  return (jsonDecode(s) as List)
      .map((e) => Product.fromJson(e))
      .toList();
}

Future<void> saveProducts(List<Product> list) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('products', jsonEncode(list.map((e) => e.toJson()).toList()));
}

// ================== التعرف على الصورة ==================
Future<int> avgHash(String path) async {
  final bytes = await File(path).readAsBytes();
  final image = im.decodeImage(bytes);
  if (image == null) throw Exception('bad image');
  final small = im.copyResize(image, width: 8, height: 8);
  final px = List<int>.filled(64, 0);
  int sum = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final p = small.getPixel(x, y);
      final g = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
      px[y * 8 + x] = g;
      sum += g;
    }
  }
  final avg = sum / 64;
  int h = 0;
  for (var i = 0; i < 64; i++) {
    if (px[i] >= avg) h |= 1 << i;
  }
  return h;
}

int hamming(int a, int b) =>
    (a ^ b).toRadixString(2).split('').where((c) => c == '1').length;

// ================== حوارات مساعدة ==================
Future<String?> inputDialog(BuildContext context, String title,
    {TextInputType type = TextInputType.text}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          keyboardType: type,
          decoration: const InputDecoration(border: OutlineInputBorder())),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('إلغاء', 'Cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(t('التالي', 'Next'))),
      ],
    ),
  );
}

Future<int?> choiceDialog(BuildContext context, String title, List<String> options) {
  return showDialog<int>(
    context: context,
    builder: (_) => SimpleDialog(
      title: Text(title, textAlign: TextAlign.center),
      children: [
        for (var i = 0; i < options.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: Center(child: Text(options[i])),
          ),
      ],
    ),
  );
}

// ================== التطبيق ==================
class WebKamApp extends StatelessWidget {
  const WebKamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (_, __) => MaterialApp(
        title: 'بكم؟',
        debugShowCheckedModeBanner: false,
        theme: app.theme,
        home: const SplashPage(),
      ),
    );
  }
}

// ================== صفحة البداية ==================
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool get langChosen => app.lang.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!langChosen) ...[
              Text(t('اختر اللغة', 'Choose language'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: () async {
                    await app.setLang('ar');
                    setState(() {});
                  },
                  child: const Text('1 - عربي', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: OutlinedButton(
                  onPressed: () async {
                    await app.setLang('en');
                    setState(() {});
                  },
                  child: const Text('2 - ENGLISH', style: TextStyle(fontSize: 20)),
                ),
              ),
            ] else ...[
              const Text(
                'HELLO',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 10,
                ),
              ),
              const SizedBox(height: 12),
              const Text(programmer,
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const HomePage())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(t('ابدأ', 'Start'), style: const TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================== الصفحة الرئيسية ==================
const categories = [
  'سوق غذائية', 'سوق مواشي', 'سوق تنظيف', 'سوق ملابس', 'سوق عطار',
  'سوق هواتف', 'سوق احذية', 'سوق بقوليات', 'سوق صيدلية', 'سوق ذهب',
  'سوق منزلية', 'سوق ألعاب', 'سوق كهربائية', 'جملة',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [t('الرئيسية', 'Home'), t('الكاميرا', 'Camera'), t('الإعدادات', 'Settings')];
    return Scaffold(
      appBar: AppBar(
        title: Text(t('بكم؟', 'Bekam?')),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(16),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(programmer,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ),
      ),
      body: tab == 0
          ? ListView.builder(
              itemCount: categories.length,
              itemBuilder: (_, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(categories[i]),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CategoryPage(categories[i]))),
                ),
              ),
            )
          : tab == 1
              ? const ScanPage()
              : const SettingsPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: titles[0]),
          NavigationDestination(icon: const Icon(Icons.camera_alt), label: titles[1]),
          NavigationDestination(icon: const Icon(Icons.settings), label: titles[2]),
        ],
      ),
    );
  }
}

// ================== صفحة السوق ==================
class CategoryPage extends StatefulWidget {
  final String category;
  const CategoryPage(this.category, {super.key});
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Product> products = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final all = await loadProducts();
    setState(() =>
        products = all.where((p) => p.category == widget.category).toList());
  }

  Future<void> addProduct() async {
    final src = await choiceDialog(context, t('إضافة منتج', 'Add product'),
        [t('تصوير منتج', 'Capture product'), t('استرداد منتج', 'Pick from files')]);
    if (src == null) return;

    final picked = await ImagePicker().pickImage(
        source: src == 0 ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final prodDir = Directory('${dir.path}/products');
    await prodDir.create(recursive: true);
    final file = await File(picked.path).copy(
        '${prodDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');

    final name = await inputDialog(context, t('أدخل اسم المنتج', 'Enter product name'));
    if (name == null || name.isEmpty) return;

    final sizes = [t('كبير', 'Large'), t('متوسط', 'Medium'), t('صغير', 'Small'), t('بدون', 'None')];
    final sizeI = await choiceDialog(context, t('اختر الحجم', 'Choose size'), sizes);
    if (sizeI == null) return;

    final price = await inputDialog(context, t('أدخل سعره', 'Enter price'),
        type: TextInputType.number);
    if (price == null || price.isEmpty) return;

    final wsI = await choiceDialog(context, t('هل تريد إضافة مجموعة (جملة)؟', 'Add wholesale?'),
        [t('إدخال سعر الجملة', 'Enter wholesale price'), t('بدون', 'None')]);
    if (wsI == null) return;

    String wholesale = '';
    if (wsI == 0) {
      wholesale = await inputDialog(context, t('سعر الجملة', 'Wholesale price'),
              type: TextInputType.number) ??
          '';
    }

    final hash = await avgHash(file.path);
    final all = await loadProducts();
    all.add(Product(name, sizes[sizeI], price, wholesale, file.path,
        widget.category, hash));
    await saveProducts(all);
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addProduct,
        icon: const Icon(Icons.add),
        label: Text(t('إضافة منتج', 'Add product')),
      ),
      body: products.isEmpty
          ? Center(child: Text(t('لا توجد منتجات بعد', 'No products yet')))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Image.file(File(p.imagePath),
                        width: 56, height: 56, fit: BoxFit.cover),
                    title: Text(p.name),
                    subtitle: Text(
                        '${p.size} • ${t('السعر', 'Price')}: ${p.price}${p.wholesale.isNotEmpty ? ' • ${t('جملة', 'Wholesale')}: ${p.wholesale}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final all = await loadProducts();
                        all.removeWhere((x) => x.imagePath == p.imagePath);
                        await saveProducts(all);
                        await refresh();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ================== صفحة الكاميرا (التعرف) ==================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool busy = false;
  String result = '';

  Future<void> scan() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;

    setState(() {
      busy = true;
      result = '';
    });

    try {
      final h = await avgHash(picked.path);
      final all = await loadProducts();
      Product? best;
      int bestD = 999;
      for (final p in all) {
        final d = hamming(h, p.hash);
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
      if (best != null && bestD <= 12) {
        result = '${best.name}\n${t('السعر', 'Price')}: ${best.price}'
            '${best.wholesale.isNotEmpty ? '\n${t('جملة', 'Wholesale')}: ${best.wholesale}' : ''}';
      } else {
        result = t('هذا المنتج غير مُضاف', 'This product is not added');
      }
    } catch (_) {
      result = t('تعذر تحليل الصورة', 'Could not analyze image');
    }

    // حذف الصورة المؤقتة - لا تُحفظ في المعرض
    try {
      await File(picked.path).delete();
    } catch (_) {}

    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) const CircularProgressIndicator(),
            if (result.isNotEmpty) ...[
              Card(
                color: result.contains(t('غير', 'not'))
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(result,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 20),
            ],
            FilledButton.icon(
              onPressed: busy ? null : scan,
              icon: const Icon(Icons.camera_alt),
              label: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(t('صوّر المنتج', 'Capture product'),
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== صفحة الإعدادات ==================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/218934274024');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('اللغة', 'Language'),
              style: Theme.of(context).textTheme.titleMedium),
          RadioListTile<String>(
            title: const Text('عربي'),
            value: 'ar',
            groupValue: app.lang,
            onChanged: (v) => app.setLang(v!),
          ),
          RadioListTile<String>(
            title: const Text('ENGLISH'),
            value: 'en',
            groupValue: app.lang,
            onChanged: (v) => app.setLang(v!),
          ),
          const Divider(),
          Text(t('وضع الشاشة', 'Theme'),
              style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: Text(t('مظلم', 'Dark')),
            subtitle: Text(t('مشمس = أبيض وأزرق فاتح', 'Light = white & light blue')),
            value: app.dark,
            onChanged: (v) => app.setDark(v),
          ),
          const Divider(),
          Text(t('حجم الخط', 'Font size'),
              style: Theme.of(context).textTheme.titleMedium),
          for (final e in [
            (t('صغير', 'Small'), 0.85),
            (t('متوسط', 'Medium'), 1.0),
            ( t('كبير', 'Large'), 1.2),
          ])
            RadioListTile<double>(
              title: Text(e.$1),
              value: e.$2,
              groupValue: app.fontScale,
              onChanged: (v) => app.setFont(v!),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(t('المساعدة', 'Help')),
            subtitle: const Text('WhatsApp'),
            onTap: openWhatsApp,
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(programmer,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}