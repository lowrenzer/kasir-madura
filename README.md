# Kasir Madura — Aplikasi Kasir Toko Madura

> Full-stack CRUD application: **Go + Gin REST API** (backend) dan **Flutter Web** (frontend).
> Fitur: Manajemen stok barang, pemesanan, pengurangan stok otomatis, dan login JWT.

## 🏗️ Arsitektur

```
Flutter Web (browser/HP) ──HTTP/S──> Go REST API ──> SQLite
                                           │
                                    JWT Auth (bcrypt)
```

## 📦 Fitur

- **Manajemen Stok** — Tambah, edit, hapus barang
- **Pemesanan** — Buat pesanan, kurangi stok otomatis
- **Status Pesanan** — Tandai selesai / proses
- **Laporan** — Ringkasan harian (omset, jumlah pesanan)
- **Login JWT** — Password di-hash bcrypt, token 12 jam

## 🚀 Setup Lokal

### Backend (Go)

```bash
cd backend
go mod tidy
go run .
# Server jalan di http://localhost:8080
```

### Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Login Default

```
Username: admin
Password: admin123
```

> ⚠️ Ganti password sebelum deploy ke server publik!

## 🌐 Deploy Online

Lihat [PANDUAN_DEPLOYMENT_ONLINE.md](PANDUAN_DEPLOYMENT_ONLINE.md) untuk langkah lengkap deploy ke:
- **Backend:** Render.com / Railway.app
- **Frontend:** Netlify / Vercel / GitHub Pages

## 🛡️ Keamanan

| Aspek | Implementasi |
|-------|-------------|
| Password | bcrypt (hash) |
| Token | JWT HS256, 12 jam |
| SQL | Prepared statement |
| CORS | Environment-variable configurable |
| Secrets | Via env vars (bukan hardcode) |

## 📁 Struktur Repo

```
kasir-madura/
├── backend/
│   ├── main.go        # REST API + routing + CORS
│   ├── auth.go        # JWT login + bcrypt
│   ├── go.mod
│   ├── go.sum
│   ├── seed.sql
│   ├── test_local.py  # Test suite lokal
│   └── README.md
├── frontend/
│   ├── lib/
│   │   └── main.dart  # Flutter app (Login + Stok + Pesanan + Laporan)
│   ├── web/
│   │   ├── index.html
│   │   └── ...
│   ├── pubspec.yaml
│   └── test/
├── .gitignore
└── README.md
```

## 📋 Environment Variables (Deploy)

```
PORT=10000
JWT_SECRET=<secret-32-karakter>
ADMIN_PASSWORD=<password-admin>
ALLOWED_ORIGINS=https://your-frontend.netlify.app
```

## 🧪 Test

```bash
cd backend
python test_local.py
# Hasil: 13/13 PASS
```

## 📄 License

MIT — bebas dipakai untuk portofolio & pembelajaran.
