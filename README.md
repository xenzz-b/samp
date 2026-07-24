# VXRP SA-MP Server

Gamemode Roleplay dengan sistem UCP + Character (alur diadaptasi dari referensi Nexston/projek-nsa).

## Fitur

- Register / Login **UCP** via dialog (nama SA-MP = nama UCP)
- Pilih / buat **Character** (nama roleplay `Firstname_Lastname`)
- Maksimal 3 karakter per UCP
- Anti double-login UCP
- Auth dipicu di `OnPlayerRequestClass` (tidak stuck class select)
- Database MySQL: `database/vxrp.sql`
- Password SHA256 + salt
- Auto-save karakter saat disconnect
- Command `/stats`

## Alur

1. Connect
2. `OnPlayerRequestClass` -> spectate + kamera + cek `player_ucp`
3. Dialog Register / Login UCP
4. Load `player_characters` by `Char_UCP`
5. Pilih karakter / buat baru
6. Spawn

## Setup

### 1. Database

Kalau struktur lama beda, drop dulu:

```sql
DROP DATABASE IF EXISTS vxrp;
```

Lalu import `database/vxrp.sql` lewat phpMyAdmin / MySQL.

### 2. Kredensial

Edit di `gamemodes/main.pwn`:

```pawn
#define MYSQL_HOST      "127.0.0.1"
#define MYSQL_USER      "root"
#define MYSQL_PASSWORD  ""
#define MYSQL_DATABASE  "vxrp"
```

### 3. Plugin MySQL (WAJIB)

Struktur file yang benar:

```
folder server/
  samp-server.exe
  libmariadb.dll      <-- root (WAJIB)
  log-core.dll        <-- root (disarankan)
  plugins/
    mysql.dll         <-- plugins (WAJIB)
  gamemodes/
    main.amx
  server.cfg          <-- plugins mysql
```

File ini sudah ada di repo. Kalau masih `Loading plugin: mysql / Failed`:

1. Pastikan `libmariadb.dll` **bukan** di dalam `plugins/`
2. Install [VC++ Redistributable x86](https://aka.ms/vs/17/release/vc_redist.x86.exe)
3. Restart PC, jalankan `samp-server.exe` lagi

Log sukses:

```
Loading plugin: mysql
  >> plugin.mysql: Rxx successfully loaded.
 Loaded 1 plugins.
```

### 4. Compile

Buka **hanya** `gamemodes/main.pwn` di Pawno, tekan F5.
Jangan compile file `.sql`.

### 5. Jalankan

```
[MySQL] Koneksi berhasil (database: vxrp).
```

## Error umum

| Log | Arti | Perbaikan |
|-----|------|-----------|
| `Loading plugin: mysql` `Failed` | Plugin/DLL dependency hilang | Cek `libmariadb.dll` + VC++ x86 |
| `Run time error 19` | Native MySQL tidak ada | Karena plugin gagal load |
| `cannot read from file: "a_mysql"` | Include hilang | Pastikan `pawno/include/a_mysql.inc` |
| Compile `vxrp.sql` error | Salah buka file | Compile `main.pwn`, bukan `.sql` |

## Tabel

| Tabel | Isi |
|-------|-----|
| `player_ucp` | Akun UCP |
| `player_characters` | Karakter roleplay |
