#include <a_samp>
#include <a_mysql>

#undef MAX_PLAYERS
#define MAX_PLAYERS             50
#define MAX_CHARACTERS          3

#define MYSQL_HOST              "127.0.0.1"
#define MYSQL_USER              "root"
#define MYSQL_PASSWORD          ""
#define MYSQL_DATABASE          "vxrp"

#define SECONDS_TO_LOGIN        90

#define DEFAULT_POS_X           1958.3783
#define DEFAULT_POS_Y           1343.1572
#define DEFAULT_POS_Z           15.3746
#define DEFAULT_POS_A           270.1425

#define COLOR_WHITE             0xFFFFFFFF
#define COLOR_LIGHTRED          0xFF6347FF
#define COLOR_YELLOW            0xFFFF00FF
#define COLOR_GREEN             0x33AA33FF
#define COLOR_GREY              0xAFAFAFFF

new MySQL:g_SQL;
new g_RaceCheck[MAX_PLAYERS];

enum E_PLAYER
{
    pUcpID,
    pCharID,
    pUcpName[MAX_PLAYER_NAME],
    pCharName[MAX_PLAYER_NAME],
    pPassword[65],
    pSalt[17],
    pAdmin,
    pLevel,
    pMoney,
    pBank,
    pSkin,
    pGender,
    pAge,
    Float:pHealth,
    Float:pArmour,
    Float:pPosX,
    Float:pPosY,
    Float:pPosZ,
    Float:pPosA,
    pInterior,
    pWorld,
    Cache:pCache,
    bool:pLogged,
    bool:pSpawned,
    pLoginTries,
    pLoginTimer,
    pCharCount,
    pCharListID[MAX_CHARACTERS],
    pCharListLevel[MAX_CHARACTERS],
    pCharListSkin[MAX_CHARACTERS],
    pSelectedSlot,
    pTempGender
};
new Player[MAX_PLAYERS][E_PLAYER];
new CharListName[MAX_PLAYERS][MAX_CHARACTERS][MAX_PLAYER_NAME];

enum
{
    DIALOG_UNUSED = 0,
    DIALOG_LOGIN,
    DIALOG_REGISTER,
    DIALOG_CHAR_LIST,
    DIALOG_CHAR_NAME,
    DIALOG_CHAR_GENDER,
    DIALOG_CHAR_AGE
};

main()
{
    print("----------------------------------");
    print(" VXRP Gamemode");
    print("----------------------------------");
}

stock Database_Connect()
{
    new MySQLOpt:opts = mysql_init_options();
    mysql_set_option(opts, AUTO_RECONNECT, true);

    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, opts);
    if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
    {
        print("[MySQL] Koneksi gagal. Import database/vxrp.sql dulu.");
        SendRconCommand("exit");
        return 0;
    }

    mysql_set_charset("utf8mb4", g_SQL);
    print("[MySQL] Koneksi berhasil (database: vxrp).");
    return 1;
}

public OnGameModeInit()
{
    SetGameModeText("VXRP v1.0");
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
    ShowNameTags(1);
    SetNameTagDrawDistance(20.0);
    EnableStuntBonusForAll(0);
    DisableInteriorEnterExits();
    UsePlayerPedAnims();
    ManualVehicleEngineAndLights();

    if(!Database_Connect()) return 1;

    AddPlayerClass(26, DEFAULT_POS_X, DEFAULT_POS_Y, DEFAULT_POS_Z, DEFAULT_POS_A, 0, 0, 0, 0, 0, 0);
    return 1;
}

public OnGameModeExit()
{
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i)) OnPlayerDisconnect(i, 1);
    }
    mysql_close(g_SQL);
    return 1;
}

public OnPlayerConnect(playerid)
{
    g_RaceCheck[playerid]++;
    ResetPlayerVars(playerid);

    GetPlayerName(playerid, Player[playerid][pUcpName], MAX_PLAYER_NAME);

    SetPlayerColor(playerid, 0xAAAAAAAA);
    TogglePlayerSpectating(playerid, true);
    SetPlayerVirtualWorld(playerid, playerid + 1000);

    new query[160];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`, `password`, `salt`, `admin` FROM `ucp` WHERE `username` = '%e' LIMIT 1",
        Player[playerid][pUcpName]);
    mysql_tquery(g_SQL, query, "OnUcpCheck", "dd", playerid, g_RaceCheck[playerid]);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    g_RaceCheck[playerid]++;
    SaveCharacterData(playerid, reason);

    if(cache_is_valid(Player[playerid][pCache]))
    {
        cache_delete(Player[playerid][pCache]);
        Player[playerid][pCache] = MYSQL_INVALID_CACHE;
    }

    if(Player[playerid][pLoginTimer])
    {
        KillTimer(Player[playerid][pLoginTimer]);
        Player[playerid][pLoginTimer] = 0;
    }

    Player[playerid][pLogged] = false;
    Player[playerid][pSpawned] = false;
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    if(!Player[playerid][pSpawned])
    {
        TogglePlayerSpectating(playerid, true);
        return 0;
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    if(!Player[playerid][pSpawned]) return 0;
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(!Player[playerid][pSpawned])
    {
        TogglePlayerSpectating(playerid, true);
        return 0;
    }

    SetPlayerSkin(playerid, Player[playerid][pSkin]);
    SetPlayerScore(playerid, Player[playerid][pLevel]);
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, Player[playerid][pMoney]);
    SetPlayerHealth(playerid, Player[playerid][pHealth]);
    SetPlayerArmour(playerid, Player[playerid][pArmour]);
    SetPlayerInterior(playerid, Player[playerid][pInterior]);
    SetPlayerVirtualWorld(playerid, Player[playerid][pWorld]);
    SetPlayerPos(playerid, Player[playerid][pPosX], Player[playerid][pPosY], Player[playerid][pPosZ]);
    SetPlayerFacingAngle(playerid, Player[playerid][pPosA]);
    SetCameraBehindPlayer(playerid);
    SetPlayerColor(playerid, COLOR_WHITE);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    #pragma unused killerid, reason
    if(Player[playerid][pSpawned])
    {
        Player[playerid][pHealth] = 100.0;
        Player[playerid][pArmour] = 0.0;
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!Player[playerid][pSpawned])
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Kamu harus masuk ke karakter dulu.");
        return 1;
    }

    if(!strcmp(cmdtext, "/stats", true))
    {
        new str[180];
        format(str, sizeof(str),
            "UCP: %s | Char: %s | Level: %d | Cash: $%d | Bank: $%d",
            Player[playerid][pUcpName],
            Player[playerid][pCharName],
            Player[playerid][pLevel],
            Player[playerid][pMoney],
            Player[playerid][pBank]);
        SendClientMessage(playerid, COLOR_YELLOW, str);
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_UNUSED: return 1;

        case DIALOG_LOGIN:
        {
            if(!response) return DelayedKick(playerid);
            if(!inputtext[0]) return ShowLoginDialog(playerid, "Password tidak boleh kosong.");

            new hash[65];
            SHA256_PassHash(inputtext, Player[playerid][pSalt], hash, sizeof(hash));

            if(strcmp(hash, Player[playerid][pPassword]))
            {
                Player[playerid][pLoginTries]++;
                if(Player[playerid][pLoginTries] >= 3)
                {
                    SendClientMessage(playerid, COLOR_LIGHTRED, "Terlalu banyak percobaan gagal.");
                    return DelayedKick(playerid);
                }

                new str[80];
                format(str, sizeof(str), "Password salah. Sisa kesempatan: %d", 3 - Player[playerid][pLoginTries]);
                return ShowLoginDialog(playerid, str);
            }

            if(cache_is_valid(Player[playerid][pCache]))
            {
                cache_delete(Player[playerid][pCache]);
                Player[playerid][pCache] = MYSQL_INVALID_CACHE;
            }

            if(Player[playerid][pLoginTimer])
            {
                KillTimer(Player[playerid][pLoginTimer]);
                Player[playerid][pLoginTimer] = 0;
            }

            Player[playerid][pLogged] = true;
            SendClientMessage(playerid, COLOR_GREEN, "Login UCP berhasil.");

            new query[128], ip[16];
            GetPlayerIp(playerid, ip, sizeof(ip));
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `ucp` SET `last_login` = CURRENT_TIMESTAMP, `ip` = '%e' WHERE `id` = %d LIMIT 1",
                ip, Player[playerid][pUcpID]);
            mysql_tquery(g_SQL, query);

            LoadCharacterList(playerid);
            return 1;
        }

        case DIALOG_REGISTER:
        {
            if(!response) return DelayedKick(playerid);

            new len = strlen(inputtext);
            if(len < 6 || len > 32)
                return ShowRegisterDialog(playerid, "Password harus 6-32 karakter.");

            for(new i = 0; i < 16; i++) Player[playerid][pSalt][i] = random(94) + 33;
            Player[playerid][pSalt][16] = EOS;
            SHA256_PassHash(inputtext, Player[playerid][pSalt], Player[playerid][pPassword], 65);

            new query[280], ip[16];
            GetPlayerIp(playerid, ip, sizeof(ip));
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `ucp` (`username`, `password`, `salt`, `ip`) VALUES ('%e', '%e', '%e', '%e')",
                Player[playerid][pUcpName],
                Player[playerid][pPassword],
                Player[playerid][pSalt],
                ip);
            mysql_tquery(g_SQL, query, "OnUcpRegistered", "dd", playerid, g_RaceCheck[playerid]);
            return 1;
        }

        case DIALOG_CHAR_LIST:
        {
            if(!response) return DelayedKick(playerid);

            if(listitem < 0 || listitem > Player[playerid][pCharCount]) return ShowCharacterList(playerid);

            if(listitem == Player[playerid][pCharCount])
            {
                if(Player[playerid][pCharCount] >= MAX_CHARACTERS)
                {
                    SendClientMessage(playerid, COLOR_LIGHTRED, "Slot karakter sudah penuh.");
                    return ShowCharacterList(playerid);
                }
                return ShowCharNameDialog(playerid, "");
            }

            Player[playerid][pSelectedSlot] = listitem;
            SelectCharacter(playerid, Player[playerid][pCharListID][listitem]);
            return 1;
        }

        case DIALOG_CHAR_NAME:
        {
            if(!response) return ShowCharacterList(playerid);
            if(!IsValidRoleplayName(inputtext))
                return ShowCharNameDialog(playerid, "Format: Firstname_Lastname (contoh: John_Doe)");

            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "SELECT `id` FROM `characters` WHERE `name` = '%e' LIMIT 1", inputtext);
            mysql_tquery(g_SQL, query, "OnCharNameCheck", "dds", playerid, g_RaceCheck[playerid], inputtext);
            return 1;
        }

        case DIALOG_CHAR_GENDER:
        {
            if(!response) return ShowCharNameDialog(playerid, "");
            if(listitem < 0 || listitem > 1) return ShowGenderDialog(playerid);

            Player[playerid][pTempGender] = listitem;
            Player[playerid][pSkin] = listitem ? 40 : 26;
            return ShowAgeDialog(playerid, "");
        }

        case DIALOG_CHAR_AGE:
        {
            if(!response) return ShowGenderDialog(playerid);

            new age = strval(inputtext);
            if(age < 16 || age > 80)
                return ShowAgeDialog(playerid, "Umur harus 16-80 tahun.");

            CreateCharacter(playerid, age);
            return 1;
        }
    }
    return 0;
}

forward OnUcpCheck(playerid, race_check);
public OnUcpCheck(playerid, race_check)
{
    if(race_check != g_RaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows())
    {
        cache_get_value_name_int(0, "id", Player[playerid][pUcpID]);
        cache_get_value_name(0, "password", Player[playerid][pPassword], 65);
        cache_get_value_name(0, "salt", Player[playerid][pSalt], 17);
        cache_get_value_name_int(0, "admin", Player[playerid][pAdmin]);
        Player[playerid][pCache] = cache_save();

        SetTimerEx("ShowAuthDialog", 200, false, "dd", playerid, 1);
        Player[playerid][pLoginTimer] = SetTimerEx("OnLoginTimeout", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
    }
    else
    {
        SetTimerEx("ShowAuthDialog", 200, false, "dd", playerid, 0);
    }
    return 1;
}

forward ShowAuthDialog(playerid, is_login);
public ShowAuthDialog(playerid, is_login)
{
    if(!IsPlayerConnected(playerid)) return 0;
    if(Player[playerid][pLogged] || Player[playerid][pSpawned]) return 0;

    TogglePlayerSpectating(playerid, true);
    if(is_login) ShowLoginDialog(playerid, "");
    else ShowRegisterDialog(playerid, "");
    return 1;
}

forward OnUcpRegistered(playerid, race_check);
public OnUcpRegistered(playerid, race_check)
{
    if(race_check != g_RaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_insert_id() <= 0)
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Gagal membuat UCP. Coba lagi.");
        return ShowRegisterDialog(playerid, "Registrasi gagal, gunakan nama lain / coba lagi.");
    }

    Player[playerid][pUcpID] = cache_insert_id();
    Player[playerid][pLogged] = true;
    Player[playerid][pAdmin] = 0;

    SendClientMessage(playerid, COLOR_GREEN, "Registrasi UCP berhasil.");
    LoadCharacterList(playerid);
    return 1;
}

forward OnCharactersLoaded(playerid, race_check);
public OnCharactersLoaded(playerid, race_check)
{
    if(race_check != g_RaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    Player[playerid][pCharCount] = 0;

    new rows = cache_num_rows();
    if(rows > MAX_CHARACTERS) rows = MAX_CHARACTERS;

    for(new i = 0; i < rows; i++)
    {
        cache_get_value_name_int(i, "id", Player[playerid][pCharListID][i]);
        cache_get_value_name(i, "name", CharListName[playerid][i], MAX_PLAYER_NAME);
        cache_get_value_name_int(i, "level", Player[playerid][pCharListLevel][i]);
        cache_get_value_name_int(i, "skin", Player[playerid][pCharListSkin][i]);
        Player[playerid][pCharCount]++;
    }

    SetTimerEx("ShowCharListDelayed", 150, false, "d", playerid);
    return 1;
}

forward ShowCharListDelayed(playerid);
public ShowCharListDelayed(playerid)
{
    if(!IsPlayerConnected(playerid) || !Player[playerid][pLogged]) return 0;
    ShowCharacterList(playerid);
    return 1;
}

forward OnCharNameCheck(playerid, race_check, name[]);
public OnCharNameCheck(playerid, race_check, name[])
{
    if(race_check != g_RaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows())
        return ShowCharNameDialog(playerid, "Nama karakter sudah digunakan.");

    format(Player[playerid][pCharName], MAX_PLAYER_NAME, "%s", name);
    ShowGenderDialog(playerid);
    return 1;
}

forward OnCharacterCreated(playerid, race_check);
public OnCharacterCreated(playerid, race_check)
{
    if(race_check != g_RaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    Player[playerid][pCharID] = cache_insert_id();
    if(Player[playerid][pCharID] <= 0)
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Gagal membuat karakter.");
        return ShowCharacterList(playerid);
    }

    Player[playerid][pLevel] = 1;
    Player[playerid][pMoney] = 5000;
    Player[playerid][pBank] = 0;
    Player[playerid][pHealth] = 100.0;
    Player[playerid][pArmour] = 0.0;
    Player[playerid][pPosX] = DEFAULT_POS_X;
    Player[playerid][pPosY] = DEFAULT_POS_Y;
    Player[playerid][pPosZ] = DEFAULT_POS_Z;
    Player[playerid][pPosA] = DEFAULT_POS_A;
    Player[playerid][pInterior] = 0;
    Player[playerid][pWorld] = 0;
    Player[playerid][pGender] = Player[playerid][pTempGender];

    SendClientMessage(playerid, COLOR_GREEN, "Karakter berhasil dibuat.");
    SpawnSelectedCharacter(playerid);
    return 1;
}

forward OnCharacterSelected(playerid, race_check);
public OnCharacterSelected(playerid, race_check)
{
    if(race_check != g_RaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(!cache_num_rows())
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Karakter tidak ditemukan.");
        return LoadCharacterList(playerid);
    }

    cache_get_value_name_int(0, "id", Player[playerid][pCharID]);
    cache_get_value_name(0, "name", Player[playerid][pCharName], MAX_PLAYER_NAME);
    cache_get_value_name_int(0, "level", Player[playerid][pLevel]);
    cache_get_value_name_int(0, "money", Player[playerid][pMoney]);
    cache_get_value_name_int(0, "bank", Player[playerid][pBank]);
    cache_get_value_name_int(0, "skin", Player[playerid][pSkin]);
    cache_get_value_name_int(0, "gender", Player[playerid][pGender]);
    cache_get_value_name_int(0, "age", Player[playerid][pAge]);
    cache_get_value_name_float(0, "health", Player[playerid][pHealth]);
    cache_get_value_name_float(0, "armour", Player[playerid][pArmour]);
    cache_get_value_name_float(0, "pos_x", Player[playerid][pPosX]);
    cache_get_value_name_float(0, "pos_y", Player[playerid][pPosY]);
    cache_get_value_name_float(0, "pos_z", Player[playerid][pPosZ]);
    cache_get_value_name_float(0, "pos_a", Player[playerid][pPosA]);
    cache_get_value_name_int(0, "interior", Player[playerid][pInterior]);
    cache_get_value_name_int(0, "world", Player[playerid][pWorld]);

    if(Player[playerid][pHealth] < 10.0) Player[playerid][pHealth] = 100.0;

    new query[96];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `characters` SET `last_login` = CURRENT_TIMESTAMP WHERE `id` = %d LIMIT 1",
        Player[playerid][pCharID]);
    mysql_tquery(g_SQL, query);

    SpawnSelectedCharacter(playerid);
    return 1;
}

forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
    Player[playerid][pLoginTimer] = 0;
    if(!IsPlayerConnected(playerid) || Player[playerid][pLogged]) return 0;

    SendClientMessage(playerid, COLOR_LIGHTRED, "Timeout login UCP.");
    DelayedKick(playerid);
    return 1;
}

forward KickPlayerDelayed(playerid);
public KickPlayerDelayed(playerid)
{
    Kick(playerid);
    return 1;
}

stock ResetPlayerVars(playerid)
{
    static const empty[E_PLAYER];
    Player[playerid] = empty;
    Player[playerid][pCache] = MYSQL_INVALID_CACHE;
    Player[playerid][pHealth] = 100.0;
    return 1;
}

stock ShowLoginDialog(playerid, const extra[])
{
    new str[256];
    if(extra[0])
        format(str, sizeof(str), "{FFFFFF}UCP: {FFFF00}%s\n{FF6347}%s\n\n{FFFFFF}Masukkan password UCP:", Player[playerid][pUcpName], extra);
    else
        format(str, sizeof(str), "{FFFFFF}UCP: {FFFF00}%s\n{FFFFFF}Akun UCP ditemukan.\nMasukkan password:", Player[playerid][pUcpName]);

    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login UCP", str, "Login", "Keluar");
    return 1;
}

stock ShowRegisterDialog(playerid, const extra[])
{
    new str[256];
    if(extra[0])
        format(str, sizeof(str), "{FFFFFF}UCP: {FFFF00}%s\n{FF6347}%s\n\n{FFFFFF}Buat password (6-32):", Player[playerid][pUcpName], extra);
    else
        format(str, sizeof(str), "{FFFFFF}UCP: {FFFF00}%s\n{FFFFFF}Belum terdaftar.\nBuat password UCP (6-32):", Player[playerid][pUcpName]);

    ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register UCP", str, "Daftar", "Keluar");
    return 1;
}

stock LoadCharacterList(playerid)
{
    new query[160];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT `id`, `name`, `level`, `skin` FROM `characters` WHERE `ucp_id` = %d ORDER BY `id` ASC LIMIT %d",
        Player[playerid][pUcpID], MAX_CHARACTERS);
    mysql_tquery(g_SQL, query, "OnCharactersLoaded", "dd", playerid, g_RaceCheck[playerid]);
    return 1;
}

stock ShowCharacterList(playerid)
{
    new list[512], line[80];
    list[0] = EOS;

    for(new i = 0; i < Player[playerid][pCharCount]; i++)
    {
        format(line, sizeof(line), "%s\tLevel %d\n", CharListName[playerid][i], Player[playerid][pCharListLevel][i]);
        strcat(list, line);
    }

    if(Player[playerid][pCharCount] < MAX_CHARACTERS)
        strcat(list, "{33AA33}+ Buat Karakter Baru\n");

    if(!list[0]) strcat(list, "{33AA33}+ Buat Karakter Baru\n");

    ShowPlayerDialog(playerid, DIALOG_CHAR_LIST, DIALOG_STYLE_TABLIST, "Pilih Karakter", list, "Pilih", "Keluar");
    return 1;
}

stock ShowCharNameDialog(playerid, const extra[])
{
    new str[220];
    if(extra[0])
        format(str, sizeof(str), "{FF6347}%s\n\n{FFFFFF}Masukkan nama karakter:\nContoh: John_Doe", extra);
    else
        format(str, sizeof(str), "{FFFFFF}Masukkan nama karakter:\nFormat: Firstname_Lastname\nContoh: John_Doe");

    ShowPlayerDialog(playerid, DIALOG_CHAR_NAME, DIALOG_STYLE_INPUT, "Buat Karakter", str, "Lanjut", "Kembali");
    return 1;
}

stock ShowGenderDialog(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_CHAR_GENDER, DIALOG_STYLE_LIST, "Pilih Gender", "Laki-laki\nPerempuan", "Pilih", "Kembali");
    return 1;
}

stock ShowAgeDialog(playerid, const extra[])
{
    new str[160];
    if(extra[0])
        format(str, sizeof(str), "{FF6347}%s\n\n{FFFFFF}Masukkan umur karakter (16-80):", extra);
    else
        format(str, sizeof(str), "{FFFFFF}Masukkan umur karakter (16-80):");

    ShowPlayerDialog(playerid, DIALOG_CHAR_AGE, DIALOG_STYLE_INPUT, "Umur Karakter", str, "Buat", "Kembali");
    return 1;
}

stock SelectCharacter(playerid, charid)
{
    new query[160];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT * FROM `characters` WHERE `id` = %d AND `ucp_id` = %d LIMIT 1",
        charid, Player[playerid][pUcpID]);
    mysql_tquery(g_SQL, query, "OnCharacterSelected", "dd", playerid, g_RaceCheck[playerid]);
    return 1;
}

stock CreateCharacter(playerid, age)
{
    Player[playerid][pAge] = age;

    new query[360];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `characters` (`ucp_id`,`name`,`skin`,`gender`,`age`,`money`,`pos_x`,`pos_y`,`pos_z`,`pos_a`) VALUES (%d,'%e',%d,%d,%d,5000,%f,%f,%f,%f)",
        Player[playerid][pUcpID],
        Player[playerid][pCharName],
        Player[playerid][pSkin],
        Player[playerid][pTempGender],
        age,
        DEFAULT_POS_X, DEFAULT_POS_Y, DEFAULT_POS_Z, DEFAULT_POS_A);
    mysql_tquery(g_SQL, query, "OnCharacterCreated", "dd", playerid, g_RaceCheck[playerid]);
    return 1;
}

stock SpawnSelectedCharacter(playerid)
{
    if(SetPlayerName(playerid, Player[playerid][pCharName]) == -1)
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Gagal set nama karakter (nama dipakai player lain).");
        return LoadCharacterList(playerid);
    }

    Player[playerid][pSpawned] = true;
    TogglePlayerSpectating(playerid, false);
    SetSpawnInfo(playerid, NO_TEAM, Player[playerid][pSkin],
        Player[playerid][pPosX], Player[playerid][pPosY], Player[playerid][pPosZ], Player[playerid][pPosA],
        0, 0, 0, 0, 0, 0);
    SpawnPlayer(playerid);

    new str[96];
    format(str, sizeof(str), "Masuk sebagai {FFFF00}%s", Player[playerid][pCharName]);
    SendClientMessage(playerid, COLOR_GREEN, str);
    return 1;
}

stock SaveCharacterData(playerid, reason)
{
    if(!Player[playerid][pSpawned] || Player[playerid][pCharID] <= 0) return 0;

    if(reason == 1)
    {
        GetPlayerPos(playerid, Player[playerid][pPosX], Player[playerid][pPosY], Player[playerid][pPosZ]);
        GetPlayerFacingAngle(playerid, Player[playerid][pPosA]);
        GetPlayerHealth(playerid, Player[playerid][pHealth]);
        GetPlayerArmour(playerid, Player[playerid][pArmour]);
        Player[playerid][pInterior] = GetPlayerInterior(playerid);
        Player[playerid][pWorld] = GetPlayerVirtualWorld(playerid);
        Player[playerid][pMoney] = GetPlayerMoney(playerid);
        Player[playerid][pSkin] = GetPlayerSkin(playerid);
        Player[playerid][pLevel] = GetPlayerScore(playerid);
    }

    new query[360];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `characters` SET `level`=%d,`money`=%d,`bank`=%d,`skin`=%d,`health`=%f,`armour`=%f,`pos_x`=%f,`pos_y`=%f,`pos_z`=%f,`pos_a`=%f,`interior`=%d,`world`=%d WHERE `id`=%d LIMIT 1",
        Player[playerid][pLevel],
        Player[playerid][pMoney],
        Player[playerid][pBank],
        Player[playerid][pSkin],
        Player[playerid][pHealth],
        Player[playerid][pArmour],
        Player[playerid][pPosX],
        Player[playerid][pPosY],
        Player[playerid][pPosZ],
        Player[playerid][pPosA],
        Player[playerid][pInterior],
        Player[playerid][pWorld],
        Player[playerid][pCharID]);
    mysql_tquery(g_SQL, query);
    return 1;
}

stock IsValidRoleplayName(const name[])
{
    new len = strlen(name);
    if(len < 3 || len > 20) return 0;

    new underscore = 0;
    for(new i = 0; i < len; i++)
    {
        if(name[i] == '_')
        {
            underscore++;
            if(i == 0 || i == len - 1) return 0;
            if(i + 1 < len && (name[i + 1] < 'A' || name[i + 1] > 'Z')) return 0;
            continue;
        }
        if(!((name[i] >= 'A' && name[i] <= 'Z') || (name[i] >= 'a' && name[i] <= 'z'))) return 0;
    }

    if(underscore != 1) return 0;
    if(name[0] < 'A' || name[0] > 'Z') return 0;
    return 1;
}

stock DelayedKick(playerid, time = 500)
{
    SetTimerEx("KickPlayerDelayed", time, false, "d", playerid);
    return 1;
}
