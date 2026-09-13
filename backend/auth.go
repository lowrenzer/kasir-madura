package main

// ============================================================
//  AUTHENTIKASI (JWT)
//  Ditambahkan pada langkah 3: login + proteksi endpoint.
//  Prinsip keamanan:
//   - Password di-hash dengan bcrypt (TIDAK pernah plaintext/MD5).
//   - Token JWT ditandatangani HS256 dengan secret dari .env.
//   - Endpoint data dilindungi middleware; /api/login publik.
// ============================================================

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// ---------- Konfigurasi ----------

// jwtSecret dibaca dari environment. Wajib diset di produksi.
// Di dev, kalau kosong, pakai nilai sementara supaya tidak crash —
// TAPI jangan pernah pakai default ini di server publik.
func jwtSecret() []byte {
	s := os.Getenv("JWT_SECRET")
	if s == "" {
		s = "dev-secret-ganti-di-produksi"
	}
	return []byte(s)
}

const tokenLifetime = 12 * time.Hour

// ---------- Model ----------

type User struct {
	ID       int    `json:"id,omitempty"`
	Username string `json:"username"`
	Password string `json:"password"` // hanya dipakai saat login (plaintext dari client)
	Role     string `json:"role,omitempty"`
}

// ---------- Init tabel users ----------

func initAuthTable() {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			role TEXT NOT NULL DEFAULT 'kasir',
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		);`)
	if err != nil {
		panic(err)
	}

	// Buat admin default HANYA jika tabel masih kosong.
	// Password diambil dari env ADMIN_PASSWORD (wajib untuk produksi).
	// Kalau kosong -> pakai "admin123" agar lokal tetap jalan, tapi
	// log-nya mengingatkan supaya diganti sebelum online.
	var count int
	db.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if count == 0 {
		pwd := os.Getenv("ADMIN_PASSWORD")
		if pwd == "" {
			pwd = "admin123"
		}
		hash, _ := bcrypt.GenerateFromPassword([]byte(pwd), bcrypt.DefaultCost)
		db.Exec("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)",
			"admin", string(hash), "admin")

		if os.Getenv("ADMIN_PASSWORD") == "" {
			println("⚠️  User default dibuat: admin / admin123 — SEGERA ganti password!")
			println("⚠️  Set env ADMIN_PASSWORD sebelum deploy online!")
		} else {
			println("✅ User admin dibuat dari ADMIN_PASSWORD (env).")
		}
	}
}

// ---------- Handler login ----------

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, "Method not allowed", 405)
		return
	}

	var req User
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "Format JSON tidak valid", 400)
		return
	}

	// Validasi whitelist: username wajib, panjang wajar.
	req.Username = strings.TrimSpace(req.Username)
	if req.Username == "" || len(req.Username) > 50 || len(req.Password) > 200 {
		jsonError(w, "Username/password tidak valid", 400)
		return
	}

	var id int
	var hash, role string
	err := db.QueryRow(
		"SELECT id, password_hash, role FROM users WHERE username = ?", req.Username,
	).Scan(&id, &hash, &role)
	if err != nil {
		// Pesan sengaja sama untuk user tidak ada vs password salah,
		// supaya penyerang tidak bisa menebak username yang valid.
		jsonError(w, "Username atau password salah", 401)
		return
	}

	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
		jsonError(w, "Username atau password salah", 401)
		return
	}

	token, err := buatToken(id, req.Username, role)
	if err != nil {
		jsonError(w, "Gagal membuat token", 500)
		return
	}

	jsonOK(w, successResp("login berhasil", map[string]interface{}{
		"token": token,
		"user":  map[string]interface{}{"id": id, "username": req.Username, "role": role},
	}))
}

func buatToken(id int, username, role string) (string, error) {
	claims := jwt.MapClaims{
		"sub":  id,
		"user": username,
		"role": role,
		"exp":  time.Now().Add(tokenLifetime).Unix(),
		"iat":  time.Now().Unix(),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(jwtSecret())
}

// ---------- Middleware proteksi ----------

// authMiddleware memverifikasi header "Authorization: Bearer <token>".
func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			jsonError(w, "Butuh login (token tidak ada)", 401)
			return
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")

		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			// Tolak algoritma selain HS256 (cegah serangan "alg=none").
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, errors.New("algoritma token tidak diizinkan")
			}
			return jwtSecret(), nil
		})
		if err != nil || !token.Valid {
			jsonError(w, "Token tidak valid atau kedaluwarsa", 401)
			return
		}
		next.ServeHTTP(w, r)
	})
}
