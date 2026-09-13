# 🚀 Panduan Deployment Online - Kasir Madura

## 📋 Daftar Isi
1. [Persiapan Kode](#1-persiapan-kode)
2. [Setup GitHub Repository](#2-setup-github-repository)
3. [Deploy Backend (Go API)](#3-deploy-backend-go-api)
4. [Deploy Frontend (Flutter Web)](#4-deploy-frontend-flutter-web)
5. [Konfigurasi Domain & HTTPS](#5-konfigurasi-domain--https)
6. [Testing & Monitoring](#6-testing--monitoring)

---

## 1. Persiapan Kode

### 1.1 Update Konfigurasi API URL

**File:** `D:/ObsidianVault/frontend/lib/main.dart`

Ganti URL localhost dengan URL backend yang akan di-deploy:

```dart
// SEBELUM (lokal)
static const String baseUrlApi = 'http://localhost:8080/api';

// SESUDAH (online) - ganti dengan URL backend kamu
static const String baseUrlApi = 'https://kasir-madura-api.onrender.com/api';
```

### 1.2 Update Backend untuk Production

**File:** `D:/ObsidianVault/backend/main.go`

#### a. Port dari Environment Variable

```go
func main() {
    initDB()
    initAuthTable()
    
    r := mux.NewRouter()
    
    // ... routes setup ...
    
    // Gunakan port dari environment variable (untuk hosting)
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    
    println("🚀 Kasir Madura API ready at port " + port)
    http.ListenAndServe(":"+port, corsMiddleware(r))
}
```

#### b. JWT Secret dari Environment Variable

**File:** `D:/ObsidianVault/backend/auth.go`

```go
var jwtSecret = []byte(os.Getenv("JWT_SECRET"))

func init() {
    if len(jwtSecret) == 0 {
        // Fallback untuk development (JANGAN untuk production!)
        jwtSecret = []byte("dev-secret-change-me-in-production")
        println("⚠️  WARNING: Using default JWT secret. Set JWT_SECRET env var for production!")
    }
}
```

#### c. CORS untuk Domain Tertentu

```go
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Untuk production: batasi origin
        allowedOrigins := []string{
            "https://kasir-madura.netlify.app",
            "https://www.kasir-madura.com",
        }
        
        origin := r.Header.Get("Origin")
        for _, allowed := range allowedOrigins {
            if origin == allowed {
                w.Header().Set("Access-Control-Allow-Origin", origin)
                break
            }
        }
        
        // Fallback untuk development
        if origin == "" {
            w.Header().Set("Access-Control-Allow-Origin", "*")
        }
        
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        if r.Method == http.MethodOptions {
            w.WriteHeader(http.StatusNoContent)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

#### d. Ganti Password Default

**File:** `D:/ObsidianVault/backend/auth.go`

```go
func initAuthTable() {
    // Buat tabel users
    db.Exec(`CREATE TABLE IF NOT EXISTS users (...)`)
    
    // Cek apakah admin sudah ada
    var count int
    db.QueryRow("SELECT COUNT(*) FROM users WHERE username = ?", "admin").Scan(&count)
    
    if count == 0 {
        // Ganti password default dengan yang lebih kuat
        // Atau baca dari environment variable
        defaultPassword := os.Getenv("ADMIN_PASSWORD")
        if defaultPassword == "" {
            defaultPassword = "Admin@2026!" // Password kuat
        }
        
        hash, _ := bcrypt.GenerateFromPassword([]byte(defaultPassword), bcrypt.DefaultCost)
        db.Exec("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)",
            "admin", string(hash), "admin")
        
        println("✅ Default admin user created")
    }
}
```

### 1.3 Buat File .gitignore

**File:** `D:/ObsidianVault/.gitignore`

```gitignore
# Database SQLite (JANGAN commit data lokal)
*.db
*.db-shm
*.db-wal
*.db-journal

# Flutter
.dart_tool/
.packages
.buildlog/
.metadata
build/
flutter_*.png
linked_*.ds
unlinked.ds
unlinked_spec.ds

# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
vendor/

# Environment & Secrets
.env
.env.local
.env.production
config.json
*.pem
*.key

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
desktop.ini

# Logs
*.log
logs/

# Temporary files
*.tmp
*.temp
```

### 1.4 Buat Environment Variables Template

**File:** `D:/ObsidianVault/backend/.env.example`

```env
# Server
PORT=8080

# Database
DATABASE_URL=file:./kasir_madura.db

# JWT
JWT_SECRET=your-super-secret-key-here-min-32-chars

# Admin
ADMIN_PASSWORD=YourStrongPassword@2026

# CORS
ALLOWED_ORIGINS=https://kasir-madura.netlify.app,https://www.kasir-madura.com
```

---

## 2. Setup GitHub Repository

### 2.1 Inisialisasi Git

```bash
cd D:/ObsidianVault
git init
git add .
git commit -m "Initial commit: Kasir Madura app"
```

### 2.2 Buat Repository di GitHub

**Opsi A: Via GitHub CLI (jika sudah install)**
```bash
gh repo create kasir-madura --public --source=. --push
```

**Opsi B: Manual via GitHub Web**
1. Buka https://github.com/new
2. Repository name: `kasir-madura`
3. Description: `Aplikasi kasir toko madura dengan Go backend & Flutter frontend`
4. Visibility: **Public** (untuk portofolio)
5. **JANGAN** centang "Add README", "Add .gitignore", "Add license" (kita sudah punya)
6. Klik **Create repository**
7. Jalankan perintah yang diberikan GitHub:

```bash
git remote add origin https://github.com/YOUR_USERNAME/kasir-madura.git
git branch -M main
git push -u origin main
```

### 2.3 Verifikasi Repository

```bash
git status
git log --oneline
```

Pastikan file-file berikut **TIDAK** ter-commit:
- ❌ `kasir_madura.db` (database lokal)
- ❌ `.env` (credentials)
- ❌ `build/` (hasil build Flutter)

---

## 3. Deploy Backend (Go API)

### 3.1 Opsi 1: Render.com (Recommended - Free Tier)

#### a. Buat Akun Render
1. Buka https://render.com
2. Sign up dengan GitHub
3. Verify email

#### b. Deploy Web Service
1. Klik **New +** → **Web Service**
2. Connect GitHub repository: `kasir-madura`
3. Konfigurasi:
   - **Name:** `kasir-madura-api`
   - **Region:** Singapore (atau closest)
   - **Branch:** `main`
   - **Root Directory:** `backend`
   - **Runtime:** `Go`
   - **Build Command:** `go build -o main .`
   - **Start Command:** `./main`
   - **Instance Type:** `Free`

#### c. Environment Variables
Di Render dashboard → **Environment** → tambahkan:

```
PORT=10000
JWT_SECRET=generate-random-32-char-string-here
ADMIN_PASSWORD=YourStrongPassword@2026
DATABASE_URL=file:./kasir_madura.db
```

**Generate JWT Secret:**
```bash
# Di terminal
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

#### d. Deploy
1. Klik **Create Web Service**
2. Tunggu build selesai (5-10 menit)
3. Catat URL: `https://kasir-madura-api.onrender.com`

#### e. Test Endpoint
```bash
curl https://kasir-madura-api.onrender.com/api/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"YourStrongPassword@2026"}'
```

### 3.2 Opsi 2: Railway.app (Alternative)

1. Buka https://railway.app
2. Sign up dengan GitHub
3. **New Project** → **Deploy from GitHub repo**
4. Pilih repository `kasir-madura`
5. Root directory: `backend`
6. Add variables:
   - `PORT=8080`
   - `JWT_SECRET=...`
   - `ADMIN_PASSWORD=...`
7. Deploy

### 3.3 Opsi 3: Fly.io (Advanced)

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Init
cd D:/ObsidianVault/backend
fly launch

# Set secrets
fly secrets set JWT_SECRET=your-secret
fly secrets set ADMIN_PASSWORD=your-password

# Deploy
fly deploy
```

---

## 4. Deploy Frontend (Flutter Web)

### 4.1 Update API URL

**File:** `D:/ObsidianVault/frontend/lib/main.dart`

```dart
static const String baseUrlApi = 'https://kasir-madura-api.onrender.com/api';
```

### 4.2 Build untuk Production

```bash
cd D:/ObsidianVault/frontend
flutter pub get
flutter build web --release
```

Hasil build ada di: `D:/ObsidianVault/frontend/build/web/`

### 4.3 Opsi 1: Netlify (Recommended - Free)

#### a. Deploy Manual (Drag & Drop)
1. Buka https://app.netlify.com
2. Sign up dengan GitHub/Email
3. Drag folder `build/web/` ke Netlify dashboard
4. Tunggu upload selesai
5. Dapat URL: `https://random-name-123.netlify.app`

#### b. Deploy via GitHub (Auto-deploy on push)
1. Di Netlify: **Add new site** → **Import an existing project**
2. Pilih GitHub → `kasir-madura`
3. Konfigurasi:
   - **Branch:** `main`
   - **Base directory:** `frontend`
   - **Build command:** `flutter build web --release`
   - **Publish directory:** `frontend/build/web`
4. **Deploy site**

#### c. Custom Domain (Opsional)
1. Di Netlify: **Domain settings** → **Add custom domain**
2. Ikuti instruksi DNS

### 4.4 Opsi 2: Vercel

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd D:/ObsidianVault/frontend/build/web
vercel

# Follow prompts
```

### 4.5 Opsi 3: GitHub Pages

1. Enable GitHub Pages di repository settings
2. Upload folder `build/web/` ke branch `gh-pages`
3. URL: `https://yourusername.github.io/kasir-madura/`

---

## 5. Konfigurasi Domain & HTTPS

### 5.1 Custom Domain (Opsional)

Beli domain di:
- Namecheap (~$10/year)
- Google Domains (~$12/year)
- Niagahoster (ID) (~Rp 150k/year)

Konfigurasi DNS:
```
A Record:    @       → IP Netlify/Vercel
CNAME:       www     → your-site.netlify.app
```

### 5.2 HTTPS

✅ **Otomatis** untuk:
- Netlify (Let's Encrypt)
- Vercel (Let's Encrypt)
- Render (Let's Encrypt)

Tidak perlu konfigurasi manual.

---

## 6. Testing & Monitoring

### 6.1 Checklist Testing Online

Setelah deploy, test semua fitur:

```bash
# 1. Test login
curl https://kasir-madura-api.onrender.com/api/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"YourPassword"}'

# 2. Test dengan token
TOKEN="..." # dari response login
curl https://kasir-madura-api.onrender.com/api/stock \
  -H "Authorization: Bearer $TOKEN"
```

### 6.2 Checklist UI Testing

Buka `https://kasir-madura.netlify.app` dan test:

- [ ] Halaman login muncul
- [ ] Login berhasil
- [ ] Dashboard stok tampil
- [ ] Tambah barang → tersimpan
- [ ] Edit barang → terupdate
- [ ] Hapus barang → terhapus
- [ ] Buat pesanan → tercatat
- [ ] Stok berkurang otomatis
- [ ] Tandai selesai → status update
- [ ] Refresh → data masih ada
- [ ] Logout → kembali ke login
- [ ] Mobile responsive

### 6.3 Monitoring

**Render Dashboard:**
- Logs: real-time application logs
- Metrics: CPU, memory, request count
- Alerts: downtime notification

**Netlify Dashboard:**
- Deploys: build history
- Analytics: visitor stats
- Forms: (jika ada form kontak)

---

## 📝 Ringkasan URL

Setelah deploy, kamu akan punya:

```
Backend API:  https://kasir-madura-api.onrender.com
Frontend:     https://kasir-madura.netlify.app
GitHub:       https://github.com/yourusername/kasir-madura
```

---

## 🔒 Security Checklist untuk Production

- [ ] JWT secret minimal 32 karakter
- [ ] Password admin kuat (mix huruf, angka, simbol)
- [ ] CORS dibatasi ke domain frontend
- [ ] HTTPS aktif (otomatis di Netlify/Render)
- [ ] Database credentials tidak di-commit
- [ ] `.env` di `.gitignore`
- [ ] Error messages tidak expose stack trace
- [ ] Rate limiting (opsional, untuk production serius)

---

## 💰 Estimasi Biaya

**Free Tier (Cukup untuk portofolio):**
- Render: 750 hours/bulan (cukup untuk 1 service)
- Netlify: 100 GB bandwidth/bulan
- GitHub: Unlimited public repos

**Total: $0/bulan** ✅

**Jika traffic tinggi:**
- Render Starter: $7/bulan
- Netlify Pro: $19/bulan
- Domain: ~$10-15/tahun

---

## 🎯 Langkah Selanjutnya

1. ✅ Siapkan kode (update URL, env vars, CORS)
2. ✅ Buat GitHub repository
3. ✅ Deploy backend ke Render
4. ✅ Deploy frontend ke Netlify
5. ✅ Test semua fitur
6. ✅ Share ke portofolio/LinkedIn

---

## 📞 Troubleshooting

**Backend tidak bisa connect:**
- Cek Render logs
- Pastikan environment variables sudah di-set
- Test endpoint manual dengan curl

**Frontend tidak tampil:**
- Cek Netlify build logs
- Pastikan `flutter build web` sukses lokal dulu
- Cek console browser untuk error

**CORS error:**
- Update `allowedOrigins` di backend
- Pastikan domain frontend sudah ditambahkan
- Clear browser cache

**Database hilang setelah restart:**
- Render free tier: database ephemeral (reset saat sleep)
- Solusi: gunakan PostgreSQL managed database (Railway/Supabase)

---

**Good luck, mas! 🚀**
