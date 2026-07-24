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

Lalu import:

```bash
mysql -u root -p < database/vxrp.sql
```

Atau import `database/vxrp.sql` lewat phpMyAdmin.

### 2. Kredensial

Edit di `gamemodes/main.pwn`:

```pawn
#define MYSQL_HOST      "127.0.0.1"
#define MYSQL_USER      "root"
#define MYSQL_PASSWORD  ""
#define MYSQL_DATABASE  "vxrp"
```

### 3. Plugin MySQL

Download R41-4: https://github.com/pBlueG/SA-MP-MySQL/releases/tag/R41-4

Ekstrak `mysql-R41-4-win32.zip`:

```
samp-server.exe
libmariadb.dll
plugins/mysql.dll
```

### 4. Compile

Buka **hanya** `gamemodes/main.pwn` di Pawno, tekan F5.
Jangan compile file `.sql`.

### 5. Jalankan

Log sukses:

```
[MySQL] Koneksi berhasil (database: vxrp).
```

## Tabel

| Tabel | Isi |
|-------|-----|
| `player_ucp` | Akun UCP |
| `player_characters` | Karakter roleplay |

## Catatan

- Nama client SA-MP = nama UCP
- Nama karakter diganti otomatis setelah pilih/buat char
