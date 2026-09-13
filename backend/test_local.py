#!/usr/bin/env python3
"""Checklist pengujian LOKAL untuk Kasir Madura API.

Menjalankan seluruh alur: login -> CRUD stok -> pesanan -> status -> auth -> CORS.
Hasilnya PASS/FAIL per langkah agar mudah dilaporkan ke user.
"""
import json
import urllib.error
import urllib.request

BASE = "http://localhost:8080/api"
results = []


def request(method, path, body=None, token=None, timeout=10):
    """Kirim HTTP request ke API dan kembalikan (status, body_dict, headers)."""
    data = None
    headers = {"Content-Type": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    if token:
        headers["Authorization"] = "Bearer " + token

    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            parsed = json.loads(raw) if raw else {}
            return resp.status, parsed, dict(resp.headers)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"raw": raw}
        return e.code, parsed, dict(e.headers)
    except Exception as e:
        return 0, {"error": str(e)}, {}


def check(name, condition, detail=""):
    """Catat hasil satu langkah pengujian."""
    status = "PASS" if condition else "FAIL"
    results.append((status, name, detail))
    print(f"[{status}] {name}" + (f" -> {detail}" if detail else ""))
    return condition


def main():
    # 2. Login
    st, body, _ = request("POST", "/login", {"username": "admin", "password": "admin123"})
    token = (body.get("data") or {}).get("token") if st == 200 else None
    if not check("2. Login sukses (dapat JWT)", st == 200 and bool(token), f"HTTP {st}"):
        print("\nLogin gagal, pengujian dihentikan.")
        return 1

    # 3. GET stock dengan token
    st, body, _ = request("GET", "/stock", token=token)
    barang = (body.get("data") or []) if st == 200 else []
    check("3. GET /stock dengan token", st == 200, f"HTTP {st}, {len(barang)} barang")

    # 4. Tambah barang
    nama_baru = "Gula Pasir 1kg"
    st, body, _ = request("POST", "/stock", {
        "nama": nama_baru, "kategori": "Sembako",
        "satuan": "kg", "harga": 15000, "stok": 20,
    }, token=token)
    new_id = (body.get("data") or {}).get("id") if st == 200 else None
    check("4. Tambah barang tersimpan", st == 200 and new_id is not None, f"HTTP {st}, id={new_id}")

    # Verifikasi barang benar-benar ada di server (bukan cuma respon sukses)
    _, body2, _ = request("GET", "/stock", token=token)
    ada = any(b.get("nama") == nama_baru for b in (body2.get("data") or []))
    check("4b. Barang baru terbaca dari server", ada, nama_baru)

    # 5. Edit barang
    if new_id:
        st, _, _ = request("PUT", f"/stock/{new_id}", {
            "nama": nama_baru, "kategori": "Sembako",
            "satuan": "kg", "harga": 16000, "stok": 18,
        }, token=token)
        _, body3, _ = request("GET", "/stock", token=token)
        edited = next((b for b in (body3.get("data") or []) if b.get("id") == new_id), {})
        ok = st == 200 and edited.get("harga") == 16000 and edited.get("stok") == 18
        check("5. Edit barang tersimpan", ok, f"HTTP {st}, harga={edited.get('harga')}, stok={edited.get('stok')}")

    # 7. Buat pesanan (pakai barang baru stok 18, pesan 5)
    st, body, _ = request("POST", "/orders", {
        "items": [{"nama_barang": nama_baru, "jumlah": 5, "harga_satuan": 16000}],
        "total": 80000,
    }, token=token)
    order_id = (body.get("data") or {}).get("id") if st == 200 else None
    kode = (body.get("data") or {}).get("kode")
    check("7. Buat pesanan", st == 200 and order_id is not None, f"HTTP {st}, {kode}")

    # 8. Stok otomatis berkurang (18 -> 13)
    _, body4, _ = request("GET", "/stock", token=token)
    stok_now = next((b.get("stok") for b in (body4.get("data") or []) if b.get("id") == new_id), None)
    check("8. Stok otomatis berkurang", stok_now == 13, f"18 -> {stok_now} (harus 13)")

    # 9. Tandai pesanan selesai
    if order_id:
        st, _, _ = request("PUT", f"/orders/{order_id}/status", {"status": "selesai"}, token=token)
        check("9. Tandai pesanan selesai", st == 200, f"HTTP {st}")

    # 10. Refresh: GET pesanan, pesanan masih ada + status selesai
    _, body5, _ = request("GET", "/orders", token=token)
    order = next((o for o in (body5.get("data") or []) if o.get("id") == order_id), None)
    ok_refresh = order is not None and order.get("status") == "selesai"
    check("10. Refresh pesanan tetap ada", ok_refresh,
          f"status={order.get('status') if order else 'HILANG'}")

    # 6. Hapus barang (ditaruh belakang agar tidak mengganggu tes pesanan)
    if new_id:
        st, _, _ = request("DELETE", f"/stock/{new_id}", token=token)
        _, body6, _ = request("GET", "/stock", token=token)
        masih_ada = any(b.get("id") == new_id for b in (body6.get("data") or []))
        check("6. Hapus barang", st == 200 and not masih_ada, f"HTTP {st}, masih_ada={masih_ada}")

    # 11. Request tanpa token harus 401
    st, body, _ = request("GET", "/stock")
    check("11. Tanpa token ditolak (401)", st == 401, f"HTTP {st}")

    # 11b. Token palsu harus ditolak
    st, _, _ = request("GET", "/stock", token="token.palsu.abc")
    check("11b. Token palsu ditolak", st == 401, f"HTTP {st}")

    # 12. CORS header
    st, _, hdrs = request("GET", "/stock", token=token)
    acao = hdrs.get("Access-Control-Allow-Origin") or hdrs.get("access-control-allow-origin")
    check("12. Header CORS ada", bool(acao), f"Access-Control-Allow-Origin: {acao}")

    # Ringkasan
    passed = sum(1 for r in results if r[0] == "PASS")
    total = len(results)
    print("\n" + "=" * 46)
    print(f"HASIL: {passed}/{total} PASS")
    print("=" * 46)
    for status, name, detail in results:
        if status == "FAIL":
            print(f"  FAIL -> {name} ({detail})")
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
