package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/mux"
	_ "modernc.org/sqlite"
)

// ============================================================
//  DATABASE & CONFIG (untuk demo, pakai SQLite dengan go-sqlite3)
// ============================================================

var db *sql.DB

func initDB() {
	var err error
	// Untuk demo: SQLite file-based. WAL mode + busy_timeout:
	// - WAL = reader tidak memblok writer (konkurensi aman untuk kasir)
	// - busy_timeout = tunggu maksimal 5s kalau ada lock sesaat
	db, err = sql.Open("sqlite", "file:./kasir_madura.db?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)&_pragma=synchronous(NORMAL)")
	if err != nil {
		panic("sql.Open failed: " + err.Error())
	}
	if err := db.Ping(); err != nil {
		panic("db.Ping failed: " + err.Error())
	}
	// Tetap 1 koneksi: modernc/sqlite menulis serial; WAL menangani pembaca.
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS barang (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			nama TEXT NOT NULL,
			kategori TEXT,
			satuan TEXT,
			harga INTEGER NOT NULL,
			stok INTEGER NOT NULL DEFAULT 0
		);`)
	if err != nil {
		panic(err)
	}

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS pesanan (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			kode TEXT UNIQUE NOT NULL,
			total INTEGER NOT NULL,
			status TEXT NOT NULL,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		);`)
	if err != nil {
		panic(err)
	}

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS pesanan_item (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			pesanan_id INTEGER,
			nama_barang TEXT NOT NULL,
			jumlah INTEGER NOT NULL,
			harga_satuan INTEGER NOT NULL,
			FOREIGN KEY (pesanan_id) REFERENCES pesanan(id)
		);`)
	if err != nil {
		panic(err)
	}
}

// ============================================================
//  MODEL
// ============================================================

type Barang struct {
	ID       int    `json:"id,omitempty"`
	Nama     string `json:"nama"`
	Kategori string `json:"kategori"`
	Satuan   string `json:"satuan"`
	Harga    int    `json:"harga"`
	Stok     int    `json:"stok"`
}

type Pesanan struct {
	ID        int       `json:"id,omitempty"`
	Kode      string    `json:"kode"`
	Items     []PesananItem `json:"items"`
	Total     int       `json:"total"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

type PesananItem struct {
	NamaBarang string `json:"nama_barang"`
	Jumlah     int    `json:"jumlah"`
	HargaSatuan int   `json:"harga_satuan"`
}

type Response struct {
	Status  string      `json:"status"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// ============================================================
//  HELPER
// ============================================================

func successResp(msg string, data interface{}) Response {
	return Response{Status: "success", Message: msg, Data: data}
}

func errorResp(msg string) Response {
	return Response{Status: "error", Message: "", Error: msg}
}

func jsonOK(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func jsonError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(errorResp(msg))
}

// ============================================================
//  BARANG HANDLERS
// ============================================================

func getBarangHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, nama, kategori, satuan, harga, stok FROM barang ORDER BY nama")
	if err != nil {
		jsonError(w, err.Error(), 500)
		return
	}
	defer rows.Close()

	var barang []Barang
	for rows.Next() {
		var b Barang
		err := rows.Scan(&b.ID, &b.Nama, &b.Kategori, &b.Satuan, &b.Harga, &b.Stok)
		if err != nil {
			jsonError(w, err.Error(), 500)
			return
		}
		barang = append(barang, b)
	}
	jsonOK(w, successResp("barangs retrieved", barang))
}

func tambahBarangHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, "Method not allowed", 405)
		return
	}

	var b Barang
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		jsonError(w, "Invalid JSON", 400)
		return
	}

	if b.Nama == "" || b.Harga < 0 {
		jsonError(w, "Nama required dan harga harus >= 0", 400)
		return
	}

	result, err := db.Exec("INSERT INTO barang (nama, kategori, satuan, harga, stok) VALUES (?, ?, ?, ?, ?)",
		b.Nama, b.Kategori, b.Satuan, b.Harga, b.Stok)
	if err != nil {
		jsonError(w, err.Error(), 500)
		return
	}

	id, _ := result.LastInsertId()
	b.ID = int(id)
	jsonOK(w, successResp("barang added", b))
}

func editBarangHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		jsonError(w, "Method not allowed", 405)
		return
	}

	vars := mux.Vars(r)
	idStr := vars["id"]
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonError(w, "ID invalid", 400)
		return
	}

	var b Barang
	if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
		jsonError(w, "Invalid JSON", 400)
		return
	}

	_, err = db.Exec("UPDATE barang SET nama=?, kategori=?, satuan=?, harga=?, stok=? WHERE id=?",
		b.Nama, b.Kategori, b.Satuan, b.Harga, b.Stok, id)
	if err != nil {
		jsonError(w, err.Error(), 500)
		return
	}

	b.ID = id
	jsonOK(w, successResp("barang updated", b))
}

func hapusBarangHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		jsonError(w, "Method not allowed", 405)
		return
	}

	vars := mux.Vars(r)
	idStr := vars["id"]
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonError(w, "ID invalid", 400)
		return
	}

	_, err = db.Exec("DELETE FROM barang WHERE id=?", id)
	if err != nil {
		jsonError(w, err.Error(), 500)
		return
	}

	jsonOK(w, successResp("barang deleted", nil))
}

// ============================================================
//  PESANAN HANDLERS
// ============================================================

func getPesananHandler(w http.ResponseWriter, r *http.Request) {
	// Ambil semua pesanan sekaligus diakhiri sebelum query item,
	// karena pool koneksi = 1 (nested db.Query saat rows aktif akan deadlock).
	type pesananRow struct {
		id        int
		kode      string
		total     int
		status    string
		createdAt string
	}
	rows, err := db.Query("SELECT id, kode, total, status, created_at FROM pesanan ORDER BY created_at DESC")
	if err != nil {
		jsonError(w, err.Error(), 500)
		return
	}
	var orderRows []pesananRow
	for rows.Next() {
		var o pesananRow
		if err := rows.Scan(&o.id, &o.kode, &o.total, &o.status, &o.createdAt); err != nil {
			rows.Close()
			jsonError(w, err.Error(), 500)
			return
		}
		orderRows = append(orderRows, o)
	}
	rows.Close() // WAJIB close sebelum query berikutnya (pool = 1)

	var list []Pesanan
	for _, o := range orderRows {
		var p Pesanan
		p.ID, p.Kode, p.Total, p.Status = o.id, o.kode, o.total, o.status
		p.CreatedAt, _ = time.Parse("2006-01-02 15:04:05", o.createdAt)

		itemRows, err := db.Query("SELECT nama_barang, jumlah, harga_satuan FROM pesanan_item WHERE pesanan_id=?", o.id)
		if err != nil {
			jsonError(w, err.Error(), 500)
			return
		}
		var items []PesananItem
		for itemRows.Next() {
			var it PesananItem
			itemRows.Scan(&it.NamaBarang, &it.Jumlah, &it.HargaSatuan)
			items = append(items, it)
		}
		itemRows.Close()
		p.Items = items
		list = append(list, p)
	}

	jsonOK(w, successResp("pesanan retrieved", list))
}

func buatPesananHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, "Method not allowed", 405)
		return
	}

	var p Pesanan
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		jsonError(w, "Invalid JSON", 400)
		return
	}

	if len(p.Items) == 0 {
		jsonError(w, "Items tidak boleh kosong", 400)
		return
	}

	tx, err := db.Begin()
	if err != nil {
		jsonError(w, "Database error", 500)
		return
	}

	// Insert pesanan
	code := "#ORD-" + strconv.FormatInt(time.Now().Unix()%10000, 10)
	res, err := tx.Exec("INSERT INTO pesanan (kode, total, status, created_at) VALUES (?, ?, 'proses', datetime('now'))",
		code, p.Total)
	if err != nil {
		tx.Rollback()
		jsonError(w, err.Error(), 500)
		return
	}

	pesananID, _ := res.LastInsertId()
	p.ID = int(pesananID)
	p.Kode = code
	p.Status = "proses"

	// Insert item dan kurangi stok
	for _, it := range p.Items {
		// Insert pesanan_item
		_, err = tx.Exec("INSERT INTO pesanan_item (pesanan_id, nama_barang, jumlah, harga_satuan) VALUES (?, ?, ?, ?)",
			pesananID, it.NamaBarang, it.Jumlah, it.HargaSatuan)
		if err != nil {
			tx.Rollback()
			jsonError(w, err.Error(), 500)
			return
		}

		// Kurangi stok barang.
		// PENTING: pakai tx (bukan db) — transaksi masih terbuka, dan pool
		// hanya 1 koneksi. Memakai db.* di sini akan deadlock selamanya.
		var stok int
		row := tx.QueryRow("SELECT stok FROM barang WHERE nama=? LIMIT 1", it.NamaBarang)
		if err := row.Scan(&stok); err != nil || stok < it.Jumlah {
			tx.Rollback()
			jsonError(w, "Stok tidak cukup untuk "+it.NamaBarang, 400)
			return
		}
		if _, err := tx.Exec("UPDATE barang SET stok = stok - ? WHERE nama = ?", it.Jumlah, it.NamaBarang); err != nil {
			tx.Rollback()
			jsonError(w, err.Error(), 500)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		jsonError(w, "Gagal menyimpan pesanan: "+err.Error(), 500)
		return
	}
	jsonOK(w, successResp("pesanan created", p))
}

func updateStatusHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		jsonError(w, "Method not allowed", 405)
		return
	}

	vars := mux.Vars(r)
	idStr := vars["id"]
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonError(w, "ID invalid", 400)
		return
	}

	var req map[string]string
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, "Invalid JSON", 400)
		return
	}

	status := req["status"]
	if status != "selesai" && status != "proses" {
		jsonError(w, "Status hanya 'selesai' atau 'proses'", 400)
		return
	}

	_, err = db.Exec("UPDATE pesanan SET status=? WHERE id=?", status, id)
	if err != nil {
		jsonError(w, err.Error(), 500)
		return
	}

	jsonOK(w, successResp("status updated", map[string]interface{}{"id": id, "status": status}))
}

// ============================================================
//  MIDDLEWARE CORS
//  Wajib untuk Flutter Web: browser memblokir request lintas origin
//  tanpa header Access-Control-Allow-Origin.
// ============================================================

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Produksi: batasi origin ke domain frontend (env ALLOWED_ORIGINS,
		// dipisah koma). Kalau env kosong -> "*" (mode lokal/development).
		origin := r.Header.Get("Origin")
		allowed := strings.TrimSpace(os.Getenv("ALLOWED_ORIGINS"))
		if allowed == "" || allowed == "*" {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else {
			for _, o := range strings.Split(allowed, ",") {
				if strings.TrimSpace(o) == origin {
					w.Header().Set("Access-Control-Allow-Origin", origin)
					w.Header().Set("Vary", "Origin")
					break
				}
			}
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		// Preflight request harus dijawab 204 tanpa body
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ============================================================
//  MAIN
// ============================================================

func main() {
	initDB()
	initAuthTable()
	r := mux.NewRouter()

	// Health check publik untuk Render/Railway (tidak perlu login).
	r.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok","service":"kasir-madura-api"}`))
	}).Methods("GET")

	// ===== Publik =====
	r.HandleFunc("/api/login", loginHandler).Methods("POST")

	// ===== Terlindungi (butuh token JWT) =====
	api := r.PathPrefix("/api").Subrouter()
	api.Use(authMiddleware)

	// CRUD Barang
	api.HandleFunc("/stock", getBarangHandler).Methods("GET")
	api.HandleFunc("/stock", tambahBarangHandler).Methods("POST")
	api.HandleFunc("/stock/{id}", editBarangHandler).Methods("PUT")
	api.HandleFunc("/stock/{id}", hapusBarangHandler).Methods("DELETE")

	// Pesanan
	api.HandleFunc("/orders", getPesananHandler).Methods("GET")
	api.HandleFunc("/orders", buatPesananHandler).Methods("POST")
	api.HandleFunc("/orders/{id}/status", updateStatusHandler).Methods("PUT")

	// Port dari environment (Render/Railway memberi PORT otomatis).
	// Lokal tetap 8080.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	println("🚀 Kasir Madura API ready at :" + port)
	if os.Getenv("JWT_SECRET") == "" {
		println("⚠️  JWT_SECRET belum diset — pakai default. WAJIB diset di production!")
	}
	if os.Getenv("ALLOWED_ORIGINS") == "" {
		println("🌐 CORS terbuka (*) — mode lokal. Di produksi set ALLOWED_ORIGINS.")
	}
	if err := http.ListenAndServe(":"+port, corsMiddleware(r)); err != nil {
		panic(err)
	}
}
