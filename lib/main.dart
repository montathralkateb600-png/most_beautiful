import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MostBeautifulApp());
}

class MostBeautifulApp extends StatelessWidget {
  const MostBeautifulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Most Beautiful',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'AE')],
      locale: const Locale('ar', 'AE'),
      theme: ThemeData(
        textTheme: GoogleFonts.almaraiTextTheme(),
        primaryColor: const Color(0xFFD81B60),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user_data');
    if (userJson != null) {
      Map<String, dynamic> user = jsonDecode(userJson);
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user['phone'])
          .get();
      if (!mounted) return;
      if (doc.exists && doc.data()?['isBanned'] == true) {
        await prefs.clear();
        _goLogin();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => MainNav(
              userRole: doc.data()?['role'] ?? 'customer',
              userPhone: user['phone'],
            ),
          ),
        );
      }
    } else {
      _goLogin();
    }
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => const RegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.pink)),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController();
  final _province = TextEditingController(),
      _city = TextEditingController(),
      _pass = TextEditingController();
  final _confirmPass = TextEditingController(),
      _otpInput = TextEditingController(),
      _adminSecret = TextEditingController();

  int _step = 1;
  bool _isAdminAttempt = false, _isReturning = false, _isForgotMode = false;
  String _generatedOtp = "";
  String _userDocId = "";

  void _checkAdmin() {
    setState(
      () => _isAdminAttempt =
          (_name.text == "montathr@alkateb" && _phone.text == "07838454455"),
    );
  }

  Future<void> _sendOtp() async {
    if (_isAdminAttempt && _adminSecret.text != "20241024") {
      _msg("كلمة السر الإدارية خطأ", Colors.red);
      return;
    }

    if (_isForgotMode) {
      var user = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _email.text)
          .get();
      if (user.docs.isEmpty) {
        _msg("هذا البريد غير مسجل لدينا", Colors.red);
        return;
      }
      _userDocId = user.docs.first.id;
    }

    _generatedOtp = (1000 + Random().nextInt(9000)).toString();
    try {
      await http.post(
        Uri.parse(
          "https://script.google.com/macros/s/AKfycbxTOjez2CNyE8-BV3aLBX9mmqYc0ABh7rtQ6rLWWstfxfRf8B5FgFueP8GOUhgFj9f1/exec",
        ),
        body: jsonEncode({
          "token": "MostBeautiful_Secret_2024",
          "email": _isAdminAttempt
              ? "montathralkateb600@gmail.com"
              : _email.text,
          "code": _generatedOtp,
        }),
      );
    } catch (e) {
      /* Error */
    }

    if (!mounted) return;
    setState(() => _step = 3);
    _msg("تم إرسال رمز التحقق ✅", Colors.green);
  }

  Future<void> _loginUser() async {
    var users = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: _email.text)
        .where('password', isEqualTo: _pass.text)
        .get();

    if (!mounted) return;
    if (users.docs.isEmpty) {
      _msg("البريد أو كلمة السر خطأ", Colors.red);
    } else {
      var userData = users.docs.first.data();
      if (userData['isBanned'] == true) {
        _msg("هذا الحساب محظور", Colors.red);
        return;
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(userData));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) =>
              MainNav(userRole: userData['role'], userPhone: userData['phone']),
        ),
      );
    }
  }

  Future<void> _finalAction() async {
    if (_otpInput.text != _generatedOtp) {
      _msg("الرمز غير صحيح", Colors.red);
      return;
    }

    if (_isForgotMode) {
      setState(() => _step = 4);
      return;
    }

    Map<String, dynamic> userData = {
      "name": _name.text,
      "phone": _phone.text,
      "email": _isAdminAttempt ? "admin@mostbeautiful.com" : _email.text,
      "address": _isAdminAttempt
          ? "الإدارة"
          : "${_province.text}-${_city.text}",
      "password": _isAdminAttempt ? "admin_pass" : _pass.text,
      "role": _isAdminAttempt ? "admin" : "customer",
      "isBanned": false,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_phone.text)
        .set(userData);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) =>
            MainNav(userRole: userData['role'], userPhone: _phone.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 60),
            FadeInDown(child: Image.asset('assets/logo.jpg', height: 100)),
            const SizedBox(height: 30),
            if (_isForgotMode) ...[
              if (_step == 1) ...[
                _in("البريد المسجل لاستعادة الحساب", Icons.email, _email),
                _btn("إرسال رمز التحقق", _sendOtp),
              ] else if (_step == 3) ...[
                _in(
                  "كود التحقق",
                  Icons.security,
                  _otpInput,
                  isPh: true,
                  limit: 4,
                ),
                _btn("تحقق", _finalAction),
              ] else if (_step == 4) ...[
                _in("كلمة السر الجديدة", Icons.lock, _pass, isPas: true),
                _in(
                  "تأكيد كلمة السر",
                  Icons.lock_outline,
                  _confirmPass,
                  isPas: true,
                ),
                _btn("تحديث", () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_userDocId)
                      .update({"password": _pass.text});
                  setState(() {
                    _isForgotMode = false;
                    _isReturning = true;
                    _step = 1;
                  });
                }),
              ],
              TextButton(
                onPressed: () => setState(() => _isForgotMode = false),
                child: const Text("رجوع"),
              ),
            ] else if (_isReturning) ...[
              _in("البريد الإلكتروني", Icons.email, _email),
              _in("كلمة السر", Icons.lock, _pass, isPas: true),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _isForgotMode = true;
                    _step = 1;
                  }),
                  child: const Text("نسيت كلمة المرور؟"),
                ),
              ),
              _btn("دخول", _loginUser),
              TextButton(
                onPressed: () => setState(() => _isReturning = false),
                child: const Text("سجل كعضو جديد"),
              ),
            ] else if (_step == 1) ...[
              _in(
                "الاسم الكامل",
                Icons.person,
                _name,
                onCh: (v) => _checkAdmin(),
              ),
              _in(
                "رقم الهاتف",
                Icons.phone,
                _phone,
                isPh: true,
                limit: 11,
                onCh: (v) => _checkAdmin(),
              ),
              if (_isAdminAttempt)
                _in(
                  "رمز الإدارة السري",
                  Icons.security,
                  _adminSecret,
                  isPas: true,
                ),
              _btn(_isAdminAttempt ? "تحقق" : "التالي", () {
                if (_isAdminAttempt) {
                  _sendOtp();
                } else if (_name.text.isNotEmpty && _phone.text.length == 11)
                  setState(() => _step = 2);
              }),
              TextButton(
                onPressed: () => setState(() => _isReturning = true),
                child: const Text("لدي حساب؟ دخول"),
              ),
            ] else if (_step == 2) ...[
              _in("البريد الإلكتروني", Icons.email, _email),
              _in("المحافظة", Icons.map, _province),
              _in("المنطقة", Icons.location_city, _city),
              _in("كلمة السر", Icons.lock, _pass, isPas: true),
              _in(
                "تأكيد كلمة السر",
                Icons.lock_outline,
                _confirmPass,
                isPas: true,
              ),
              _btn("إرسال رمز التحقق", _sendOtp),
            ] else if (_step == 3) ...[
              _in(
                "رمز التحقق",
                Icons.onetwothree,
                _otpInput,
                isPh: true,
                limit: 4,
              ),
              _btn("إنهاء التسجيل", _finalAction),
            ],
          ],
        ),
      ),
    );
  }

  Widget _in(
    String h,
    IconData i,
    TextEditingController c, {
    bool isPh = false,
    bool isPas = false,
    int? limit,
    Function(String)? onCh,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      onChanged: onCh,
      obscureText: isPas,
      maxLength: limit,
      keyboardType: isPh ? TextInputType.phone : TextInputType.text,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: h,
        suffixIcon: Icon(i, color: Colors.pink),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );

  Widget _btn(String t, VoidCallback f) => ElevatedButton(
    onPressed: f,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.pink,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    child: Text(t, style: const TextStyle(color: Colors.white)),
  );

  void _msg(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, textAlign: TextAlign.right),
        backgroundColor: c,
      ),
    );
  }
}

// ---------------------------------------------------------
// نظام التنقل والصلاحيات (المدير والمساعد)
// ---------------------------------------------------------
class MainNav extends StatefulWidget {
  final String userRole;
  final String userPhone;
  const MainNav({super.key, required this.userRole, required this.userPhone});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    bool isStaff = widget.userRole == 'admin' || widget.userRole == 'assistant';
    List<Widget> pages = [
      HomeScreen(userRole: widget.userRole),
      MyBookingsScreen(phone: widget.userPhone),
      if (isStaff) AdminDashboard(role: widget.userRole),
    ];
    return Scaffold(
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        selectedItemColor: Colors.pink,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "الرئيسية",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "حجوزاتي",
          ),
          if (isStaff)
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: "الإدارة",
            ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String userRole;
  const HomeScreen({super.key, required this.userRole});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("موست بيوتفل"), centerTitle: true),
      body: Column(
        children: [
          const AdsSlider(),
          const Padding(
            padding: EdgeInsets.all(15),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "خدماتنا المميزة",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(15),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (c, i) {
                    var d = snap.data!.docs[i];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => BranchScreen(
                            catId: d.id,
                            catName: d['name'],
                            userRole: userRole,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withValues(alpha: 0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.spa, color: Colors.pink, size: 45),
                            const SizedBox(height: 10),
                            Text(
                              d['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// لوحة الإدارة (تختلف حسب الصلاحية)
// ---------------------------------------------------------
class AdminDashboard extends StatelessWidget {
  final String role;
  const AdminDashboard({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    bool isAdmin = role == 'admin';
    return Scaffold(
      appBar: AppBar(title: Text(isAdmin ? "لوحة المدير" : "لوحة المساعد")),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        children: [
          _item(context, "الحجوزات", Icons.book, AdminAllBookings(role: role)),
          _item(context, "العملاء", Icons.people, AdminUsersList(role: role)),
          _item(
            context,
            "الإعلانات",
            Icons.campaign,
            AdminAdsManager(role: role),
          ),
          if (isAdmin)
            _item(context, "الأقسام", Icons.category, const AdminCatsPage()),
        ],
      ),
    );
  }

  Widget _item(ctx, t, i, p) => Card(
    child: InkWell(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (c) => p)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i, size: 40, color: Colors.pink),
          Text(t),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------
// إدارة الإعلانات (إضافة، تعديل، حذف، صور)
// ---------------------------------------------------------
class AdminAdsManager extends StatefulWidget {
  final String role;
  const AdminAdsManager({super.key, required this.role});
  @override
  State<AdminAdsManager> createState() => _AdminAdsManagerState();
}

class _AdminAdsManagerState extends State<AdminAdsManager> {
  final _txt = TextEditingController();
  File? _img;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة الإعلانات")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ads').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snap.data!.docs
                      .map(
                        (d) => Card(
                          child: ListTile(
                            leading: d['img'] != ""
                                ? Image.file(
                                    File(d['img']),
                                    width: 50,
                                    height: 50,
                                    errorBuilder: (c, e, s) =>
                                        const Icon(Icons.image),
                                  )
                                : const Icon(Icons.campaign),
                            title: Text(d['text']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editAd(d),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => d.reference.delete(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: ElevatedButton.icon(
              onPressed: () => _editAd(null),
              icon: const Icon(Icons.add),
              label: const Text("إضافة إعلان جديد"),
            ),
          ),
        ],
      ),
    );
  }

  void _editAd(DocumentSnapshot? d) {
    if (d != null) {
      _txt.text = d['text'];
    } else {
      _txt.clear();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _txt,
              decoration: const InputDecoration(hintText: "نص الإعلان"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final p = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (p != null) setState(() => _img = File(p.path));
              },
              child: const Text("اختيار صورة من المعرض"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (d == null) {
                  await FirebaseFirestore.instance.collection('ads').add({
                    "text": _txt.text,
                    "img": _img?.path ?? "",
                  });
                } else {
                  await d.reference.update({
                    "text": _txt.text,
                    "img": _img?.path ?? d['img'],
                  });
                }
                if (!mounted) return;
                Navigator.pop(ctx);
              },
              child: Text(d == null ? "نشر" : "تحديث"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// إدارة الحجوزات (تعديل وإلغاء للمدير والمساعد)
// ---------------------------------------------------------
class AdminAllBookings extends StatelessWidget {
  final String role;
  const AdminAllBookings({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة كافة الحجوزات")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: snap.data!.docs
                .map(
                  (b) => Card(
                    child: ListTile(
                      title: Text("${b['name']} - ${b['service']}"),
                      subtitle: Text("التاريخ: ${b['date']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.calendar_month,
                              color: Colors.blue,
                            ),
                            onPressed: () async {
                              DateTime? d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 60),
                                ),
                              );
                              if (d != null) {
                                b.reference.update({
                                  "date": "${d.year}-${d.month}-${d.day}",
                                });
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => b.reference.delete(),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// قائمة العملاء (خصوصية المساعد)
// ---------------------------------------------------------
class AdminUsersList extends StatelessWidget {
  final String role;
  const AdminUsersList({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    bool isAdmin = role == 'admin';
    return Scaffold(
      appBar: AppBar(title: const Text("بيانات العملاء")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: snap.data!.docs
                .map(
                  (u) => Card(
                    child: ListTile(
                      title: Text(u['name']),
                      subtitle: Text("رقم الهاتف: ${u['phone']}"),
                      trailing: isAdmin
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // زر ترقية لمساعد (للمدير فقط)
                                TextButton(
                                  onPressed: () => u.reference.update({
                                    "role": u['role'] == 'assistant'
                                        ? 'customer'
                                        : 'assistant',
                                  }),
                                  child: Text(
                                    u['role'] == 'assistant'
                                        ? "عزل مساعد"
                                        : "تعيين مساعد",
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                Switch(
                                  value: !(u['isBanned'] ?? false),
                                  onChanged: (v) =>
                                      u.reference.update({"isBanned": !v}),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// المكونات الأخرى المستقرة
// ---------------------------------------------------------
class AdsSlider extends StatelessWidget {
  const AdsSlider({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox(
            height: 150,
            child: Center(child: Text("انتظروا عروضنا!")),
          );
        }
        return SizedBox(
          height: 180,
          child: PageView(
            children: snap.data!.docs
                .map(
                  (d) => Container(
                    margin: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: d['img'] != ""
                          ? DecorationImage(
                              image: FileImage(File(d['img'])),
                              fit: BoxFit.cover,
                            )
                          : null,
                      gradient: const LinearGradient(
                        colors: [Colors.pink, Colors.pinkAccent],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        color: Colors.black26,
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          d['text'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class BranchScreen extends StatelessWidget {
  final String catId, catName, userRole;
  const BranchScreen({
    super.key,
    required this.catId,
    required this.catName,
    required this.userRole,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(catName),
        actions: [
          if (userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addB(context),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .doc(catId)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          List b =
              (snap.data!.data() as Map<String, dynamic>?)?['branches'] ?? [];
          return ListView.builder(
            itemCount: b.length,
            itemBuilder: (c, i) => Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text(b[i]),
                trailing: ElevatedButton(
                  onPressed: () => _book(context, b[i]),
                  child: const Text("حجز"),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addB(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("خدمة جديدة"),
        content: TextField(controller: c),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('categories')
                  .doc(catId)
                  .update({
                    "branches": FieldValue.arrayUnion([c.text]),
                  });
              Navigator.pop(ctx);
            },
            child: const Text("إضافة"),
          ),
        ],
      ),
    );
  }

  void _book(BuildContext context, String s) async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      SharedPreferences p = await SharedPreferences.getInstance();
      var u = jsonDecode(p.getString('user_data')!);
      await FirebaseFirestore.instance.collection('bookings').add({
        "service": s,
        "date": "${d.year}-${d.month}-${d.day}",
        "phone": u['phone'],
        "name": u['name'],
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم الحجز ✅")));
    }
  }
}

class AdminCatsPage extends StatelessWidget {
  const AdminCatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة الأقسام")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final c = TextEditingController();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("قسم جديد"),
              content: TextField(controller: c),
              actions: [
                TextButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('categories')
                        .add({"name": c.text, "branches": []});
                    Navigator.pop(ctx);
                  },
                  child: const Text("إضافة"),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (ctx, snap) => snap.hasData
            ? ListView(
                children: snap.data!.docs
                    .map(
                      (d) => ListTile(
                        title: Text(d['name']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => d.reference.delete(),
                        ),
                      ),
                    )
                    .toList(),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class MyBookingsScreen extends StatelessWidget {
  final String phone;
  const MyBookingsScreen({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("حجوزاتي الشخصية")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('phone', isEqualTo: phone)
            .snapshots(),
        builder: (ctx, snap) => snap.hasData
            ? ListView(
                children: snap.data!.docs
                    .map(
                      (b) => Card(
                        child: ListTile(
                          title: Text(b['service']),
                          subtitle: Text(b['date']),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => b.reference.delete(),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
