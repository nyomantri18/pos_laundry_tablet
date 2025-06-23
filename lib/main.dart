// Ini adalah baris pertama, yang memberi tahu Flutter untuk menggunakan 'Material Design'
import 'package:flutter/material.dart';
import 'pos_page.dart';

// Ini adalah fungsi utama, titik awal dari semua aplikasi Flutter
void main() {
  // Perintah ini akan menjalankan aplikasi kita
  runApp(const MyApp());
}

// Ini adalah 'widget' utama dari aplikasi kita.
// Anggap ini sebagai kerangka dasar seluruh aplikasi.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Kita beri judul untuk aplikasi kita secara keseluruhan
      title: 'POS Laundry',
      // Kita matikan banner "DEBUG" yang ada di pojok kanan atas
      debugShowCheckedModeBanner: false,
      // Kita tentukan tema dasar, misalnya warna utama aplikasi
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // 'home' adalah layar pertama yang akan dilihat pengguna
      home: LoginPage(),
    );
  }
}

// Ini adalah halaman login kita. Untuk sekarang masih kosong.
// Ini adalah halaman login kita, sekarang sebagai StatefulWidget.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// Ini adalah "State" atau "Buku Catatan" untuk LoginPage kita.
class _LoginPageState extends State<LoginPage> {
  // === BAGIAN BARU 1: Membuat "Pengait" untuk setiap kolom input ===
  // Kita buat satu controller untuk username
  final _usernameController = TextEditingController();
  // Kita buat satu controller untuk password
  final _passwordController = TextEditingController();

  // Ini adalah fungsi yang akan kita panggil saat tombol login ditekan
  void _login() {
    // === BAGIAN BARU 2: Mengambil teks dari controller ===
    final String username = _usernameController.text;
    final String password = _passwordController.text;

    print('Mencoba login dengan Username: $username, Password: $password');

    // === BAGIAN BARU 3: Logika Pengecekan Sederhana ===
    // Untuk sekarang, kita tentukan username dan password yang benar di sini.
    // Nanti, ini akan diganti dengan pengecekan ke database/server.
    if (username == 'admin' && password == 'password123') {
      // Jika login BERHASIL
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PosPage()),
      );
      // NANTI: Di sini kita akan pindah ke halaman kasir utama.
    } else {
      // Jika login GAGAL
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Login Gagal! Username atau Password salah.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text('Login Kasir', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                // === BAGIAN BARU 4: Memasang "Pengait" ke kolom input ===
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Masukkan username Anda',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                // === BAGIAN BARU 4: Memasang "Pengait" ke kolom input ===
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Masukkan password Anda',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                // === BAGIAN BARU 5: Memanggil fungsi _login saat tombol ditekan ===
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('LOGIN', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
