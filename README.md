# SA-MP Server

Gamemode dasar dengan sistem register/login berbasis MySQL.

## Fitur

- Register & login (dialog password)
- Database MySQL (plugin BlueG R41-4)
- Password di-hash SHA256 + salt
- Auto-save posisi, money, score, skin saat disconnect
- Kick jika password salah 3x / timeout login 60 detik
- Command `/stats`

## Setup

### 1. Database

```bash
mysql -u root -p < database.sql
```

Sesuaikan kredensial di `gamemodes/main.pwn`:

```pawn
#define MYSQL_HOST      "127.0.0.1"
#define MYSQL_USER      "root"
#define MYSQL_PASSWORD  ""
#define MYSQL_DATABASE  "samp"
```

### 2. Plugin MySQL

Download **MySQL plugin R41-4** dari:
https://github.com/pBlueG/SA-MP-MySQL/releases/tag/R41-4

Ambil file **`mysql-R41-4-win32.zip`** (Windows).

**Penting:** ekstrak **seluruh isi** zip ke folder server, jangan cuma `mysql.dll`.

Struktur yang benar:

```
samp-server.exe
libmariadb.dll          <-- WAJIB di root server (selevel samp-server.exe)
plugins/
  mysql.dll             <-- di dalam folder plugins
pawno/include/
  a_mysql.inc           <-- sudah ada di repo ini
```

| File | Lokasi |
|------|--------|
| `mysql.dll` | `plugins/mysql.dll` |
| `libmariadb.dll` | root server (satu folder dengan `samp-server.exe`) |

Kalau log masih `Loading plugin: mysql` → `Failed.`:

1. Pastikan `libmariadb.dll` ada di root (bukan di `plugins/`)
2. Install **Visual C++ Redistributable x86 (32-bit)**:
   - [VC++ 2015-2022 x86](https://aka.ms/vs/17/release/vc_redist.x86.exe)
   - [VC++ 2010 x86](https://www.microsoft.com/en-us/download/details.aspx?id=26999)
3. Jangan pakai `mysql.so` di Windows
4. Restart PC setelah install redistributable, lalu jalankan `samp-server.exe` lagi

Log sukses harus mirip:

```
Loading plugin: mysql
  >> plugin.mysql: R41-4 successfully loaded.
  Loaded 1 plugins.
```
### 3. Compile gamemode

Buka `gamemodes/main.pwn` di Pawno lalu tekan F5, atau:

```bash
pawno/pawncc.exe gamemodes/main.pwn -Dgamemodes
```

Hasil compile: `gamemodes/main.amx`

### 4. Jalankan server

Pastikan MySQL service aktif, lalu jalankan `samp-server.exe` (Windows) / `samp03svr` (Linux).

Cek `server_log.txt` — harus ada baris:

```
[MySQL] Koneksi berhasil.
```

## Struktur

```
gamemodes/main.pwn   - gamemode utama
database.sql         - skema database
mysql.ini            - opsi koneksi (opsional)
plugins/             - taruh mysql.dll / mysql.so di sini
pawno/include/a_mysql.inc
server.cfg
```
