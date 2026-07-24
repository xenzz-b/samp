#include <a_samp>
#include <a_mysql>

#undef MAX_PLAYERS
#define MAX_PLAYERS 50

#define MYSQL_HOST      "127.0.0.1"
#define MYSQL_USER      "root"
#define MYSQL_PASSWORD  ""
#define MYSQL_DATABASE  "samp"

#define SECONDS_TO_LOGIN 60

#define DEFAULT_POS_X   1958.3783
#define DEFAULT_POS_Y   1343.1572
#define DEFAULT_POS_Z   15.3746
#define DEFAULT_POS_A   270.1425

#define COLOR_LIGHTRED  0xFF6347FF
#define COLOR_YELLOW    0xFFFF00FF
#define COLOR_GREEN     0x33AA33FF

new MySQL:g_SQL;
new g_MysqlRaceCheck[MAX_PLAYERS];

enum E_PLAYER
{
    pID,
    pName[MAX_PLAYER_NAME],
    pPassword[65],
    pSalt[17],
    pScore,
    pMoney,
    pSkin,
    pKills,
    pDeaths,
    Float:pPosX,
    Float:pPosY,
    Float:pPosZ,
    Float:pPosA,
    pInterior,
    pWorld,
    Cache:pCache,
    bool:pLogged,
    pLoginTries,
    pLoginTimer
};
new Player[MAX_PLAYERS][E_PLAYER];

enum
{
    DIALOG_UNUSED,
    DIALOG_LOGIN,
    DIALOG_REGISTER
};

main()
{
    print("----------------------------------");
    print(" Gamemode loaded");
    print("----------------------------------");
}

public OnGameModeInit()
{
    SetGameModeText("RP v1.0");
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
    ShowNameTags(1);
    SetNameTagDrawDistance(20.0);
    EnableStuntBonusForAll(0);
    DisableInteriorEnterExits();
    UsePlayerPedAnims();

    new MySQLOpt:opts = mysql_init_options();
    mysql_set_option(opts, AUTO_RECONNECT, true);

    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, opts);
    if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
    {
        print("[MySQL] Koneksi gagal. Server dimatikan.");
        SendRconCommand("exit");
        return 1;
    }

    print("[MySQL] Koneksi berhasil.");
    mysql_set_charset("utf8mb4", g_SQL);
    SetupPlayerTable();

    AddPlayerClass(0, DEFAULT_POS_X, DEFAULT_POS_Y, DEFAULT_POS_Z, DEFAULT_POS_A, 0, 0, 0, 0, 0, 0);
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
    g_MysqlRaceCheck[playerid]++;

    static const empty[E_PLAYER];
    Player[playerid] = empty;

    GetPlayerName(playerid, Player[playerid][pName], MAX_PLAYER_NAME);
    TogglePlayerSpectating(playerid, true);

    new query[128];
    mysql_format(g_SQL, query, sizeof(query),
        "SELECT * FROM `players` WHERE `username` = '%e' LIMIT 1",
        Player[playerid][pName]);
    mysql_tquery(g_SQL, query, "OnPlayerDataLoaded", "dd", playerid, g_MysqlRaceCheck[playerid]);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    g_MysqlRaceCheck[playerid]++;
    SavePlayerData(playerid, reason);

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
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    if(!Player[playerid][pLogged])
    {
        TogglePlayerSpectating(playerid, true);
        return 0;
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    if(!Player[playerid][pLogged]) return 0;
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(!Player[playerid][pLogged])
    {
        TogglePlayerSpectating(playerid, true);
        return 0;
    }

    SetPlayerSkin(playerid, Player[playerid][pSkin]);
    SetPlayerScore(playerid, Player[playerid][pScore]);
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, Player[playerid][pMoney]);

    SetPlayerInterior(playerid, Player[playerid][pInterior]);
    SetPlayerVirtualWorld(playerid, Player[playerid][pWorld]);
    SetPlayerPos(playerid, Player[playerid][pPosX], Player[playerid][pPosY], Player[playerid][pPosZ]);
    SetPlayerFacingAngle(playerid, Player[playerid][pPosA]);
    SetCameraBehindPlayer(playerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    if(Player[playerid][pLogged])
    {
        Player[playerid][pDeaths]++;
        new query[96];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `players` SET `deaths` = %d WHERE `id` = %d LIMIT 1",
            Player[playerid][pDeaths], Player[playerid][pID]);
        mysql_tquery(g_SQL, query);
    }

    if(killerid != INVALID_PLAYER_ID && Player[killerid][pLogged])
    {
        Player[killerid][pKills]++;
        new query[96];
        mysql_format(g_SQL, query, sizeof(query),
            "UPDATE `players` SET `kills` = %d WHERE `id` = %d LIMIT 1",
            Player[killerid][pKills], Player[killerid][pID]);
        mysql_tquery(g_SQL, query);
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!Player[playerid][pLogged])
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Kamu harus login terlebih dahulu.");
        return 1;
    }

    if(!strcmp(cmdtext, "/stats", true))
    {
        new str[144];
        format(str, sizeof(str),
            "Nama: %s | Score: %d | Money: $%d | Kills: %d | Deaths: %d",
            Player[playerid][pName],
            Player[playerid][pScore],
            Player[playerid][pMoney],
            Player[playerid][pKills],
            Player[playerid][pDeaths]);
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

            if(!strlen(inputtext))
                return ShowLoginDialog(playerid, "Password tidak boleh kosong.");

            new hash[65];
            SHA256_PassHash(inputtext, Player[playerid][pSalt], hash, sizeof(hash));

            if(!strcmp(hash, Player[playerid][pPassword]))
            {
                cache_set_active(Player[playerid][pCache]);
                AssignPlayerData(playerid);
                cache_delete(Player[playerid][pCache]);
                Player[playerid][pCache] = MYSQL_INVALID_CACHE;

                if(Player[playerid][pLoginTimer])
                {
                    KillTimer(Player[playerid][pLoginTimer]);
                    Player[playerid][pLoginTimer] = 0;
                }

                Player[playerid][pLogged] = true;
                SendClientMessage(playerid, COLOR_GREEN, "Login berhasil. Selamat datang kembali!");

                new query[128];
                mysql_format(g_SQL, query, sizeof(query),
                    "UPDATE `players` SET `last_login` = CURRENT_TIMESTAMP WHERE `id` = %d LIMIT 1",
                    Player[playerid][pID]);
                mysql_tquery(g_SQL, query);

                SpawnPlayerAccount(playerid);
            }
            else
            {
                Player[playerid][pLoginTries]++;
                if(Player[playerid][pLoginTries] >= 3)
                {
                    SendClientMessage(playerid, COLOR_LIGHTRED, "Terlalu banyak percobaan login gagal.");
                    DelayedKick(playerid);
                }
                else
                {
                    new str[96];
                    format(str, sizeof(str), "Password salah. Kesempatan tersisa: %d", 3 - Player[playerid][pLoginTries]);
                    ShowLoginDialog(playerid, str);
                }
            }
            return 1;
        }

        case DIALOG_REGISTER:
        {
            if(!response) return DelayedKick(playerid);

            new len = strlen(inputtext);
            if(len < 6 || len > 32)
                return ShowRegisterDialog(playerid, "Password harus 6-32 karakter.");

            for(new i = 0; i < 16; i++)
                Player[playerid][pSalt][i] = random(94) + 33;
            Player[playerid][pSalt][16] = EOS;

            SHA256_PassHash(inputtext, Player[playerid][pSalt], Player[playerid][pPassword], 65);

            new query[256], ip[16];
            GetPlayerIp(playerid, ip, sizeof(ip));
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `players` (`username`, `password`, `salt`, `ip`) VALUES ('%e', '%e', '%e', '%e')",
                Player[playerid][pName],
                Player[playerid][pPassword],
                Player[playerid][pSalt],
                ip);
            mysql_tquery(g_SQL, query, "OnPlayerRegister", "d", playerid);
            return 1;
        }
    }
    return 0;
}

forward OnPlayerDataLoaded(playerid, race_check);
public OnPlayerDataLoaded(playerid, race_check)
{
    if(race_check != g_MysqlRaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows())
    {
        cache_get_value_name(0, "password", Player[playerid][pPassword], 65);
        cache_get_value_name(0, "salt", Player[playerid][pSalt], 17);
        Player[playerid][pCache] = cache_save();

        ShowLoginDialog(playerid, "");
        Player[playerid][pLoginTimer] = SetTimerEx("OnLoginTimeout", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
    }
    else
    {
        ShowRegisterDialog(playerid, "");
    }
    return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;

    Player[playerid][pID] = cache_insert_id();
    Player[playerid][pLogged] = true;
    Player[playerid][pScore] = 0;
    Player[playerid][pMoney] = 5000;
    Player[playerid][pSkin] = 26;
    Player[playerid][pPosX] = DEFAULT_POS_X;
    Player[playerid][pPosY] = DEFAULT_POS_Y;
    Player[playerid][pPosZ] = DEFAULT_POS_Z;
    Player[playerid][pPosA] = DEFAULT_POS_A;
    Player[playerid][pInterior] = 0;
    Player[playerid][pWorld] = 0;

    SendClientMessage(playerid, COLOR_GREEN, "Registrasi berhasil. Akun otomatis login.");
    SpawnPlayerAccount(playerid);
    return 1;
}

forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
    Player[playerid][pLoginTimer] = 0;
    if(!IsPlayerConnected(playerid) || Player[playerid][pLogged]) return 0;

    SendClientMessage(playerid, COLOR_LIGHTRED, "Kamu di-kick karena terlalu lama login.");
    DelayedKick(playerid);
    return 1;
}

forward KickPlayerDelayed(playerid);
public KickPlayerDelayed(playerid)
{
    Kick(playerid);
    return 1;
}

stock ShowLoginDialog(playerid, const extra[])
{
    new str[256];
    if(extra[0])
        format(str, sizeof(str), "{FFFFFF}Akun: {FFFF00}%s\n{FF6347}%s\n\n{FFFFFF}Masukkan password:", Player[playerid][pName], extra);
    else
        format(str, sizeof(str), "{FFFFFF}Akun: {FFFF00}%s\n{FFFFFF}Akun ini sudah terdaftar.\nMasukkan password:", Player[playerid][pName]);

    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", str, "Masuk", "Keluar");
    return 1;
}

stock ShowRegisterDialog(playerid, const extra[])
{
    new str[256];
    if(extra[0])
        format(str, sizeof(str), "{FFFFFF}Selamat datang, {FFFF00}%s\n{FF6347}%s\n\n{FFFFFF}Buat password (6-32 karakter):", Player[playerid][pName], extra);
    else
        format(str, sizeof(str), "{FFFFFF}Selamat datang, {FFFF00}%s\n{FFFFFF}Akun belum terdaftar.\nBuat password (6-32 karakter):", Player[playerid][pName]);

    ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", str, "Daftar", "Keluar");
    return 1;
}

stock AssignPlayerData(playerid)
{
    cache_get_value_name_int(0, "id", Player[playerid][pID]);
    cache_get_value_name_int(0, "score", Player[playerid][pScore]);
    cache_get_value_name_int(0, "money", Player[playerid][pMoney]);
    cache_get_value_name_int(0, "skin", Player[playerid][pSkin]);
    cache_get_value_name_int(0, "kills", Player[playerid][pKills]);
    cache_get_value_name_int(0, "deaths", Player[playerid][pDeaths]);
    cache_get_value_name_float(0, "pos_x", Player[playerid][pPosX]);
    cache_get_value_name_float(0, "pos_y", Player[playerid][pPosY]);
    cache_get_value_name_float(0, "pos_z", Player[playerid][pPosZ]);
    cache_get_value_name_float(0, "pos_a", Player[playerid][pPosA]);
    cache_get_value_name_int(0, "interior", Player[playerid][pInterior]);
    cache_get_value_name_int(0, "world", Player[playerid][pWorld]);

    if(Player[playerid][pPosX] == 0.0 && Player[playerid][pPosY] == 0.0)
    {
        Player[playerid][pPosX] = DEFAULT_POS_X;
        Player[playerid][pPosY] = DEFAULT_POS_Y;
        Player[playerid][pPosZ] = DEFAULT_POS_Z;
        Player[playerid][pPosA] = DEFAULT_POS_A;
    }
    return 1;
}

stock SpawnPlayerAccount(playerid)
{
    TogglePlayerSpectating(playerid, false);
    SetSpawnInfo(playerid, NO_TEAM, Player[playerid][pSkin],
        Player[playerid][pPosX], Player[playerid][pPosY], Player[playerid][pPosZ], Player[playerid][pPosA],
        0, 0, 0, 0, 0, 0);
    SpawnPlayer(playerid);
    return 1;
}

stock DelayedKick(playerid, time = 500)
{
    SetTimerEx("KickPlayerDelayed", time, false, "d", playerid);
    return 1;
}

stock SetupPlayerTable()
{
    mysql_tquery(g_SQL,
        "CREATE TABLE IF NOT EXISTS `players` (\
            `id` INT(11) NOT NULL AUTO_INCREMENT,\
            `username` VARCHAR(24) NOT NULL,\
            `password` CHAR(64) NOT NULL,\
            `salt` CHAR(16) NOT NULL,\
            `ip` VARCHAR(16) NOT NULL DEFAULT '',\
            `score` INT(11) NOT NULL DEFAULT 0,\
            `money` INT(11) NOT NULL DEFAULT 5000,\
            `skin` INT(11) NOT NULL DEFAULT 26,\
            `kills` INT(11) NOT NULL DEFAULT 0,\
            `deaths` INT(11) NOT NULL DEFAULT 0,\
            `pos_x` FLOAT NOT NULL DEFAULT 0,\
            `pos_y` FLOAT NOT NULL DEFAULT 0,\
            `pos_z` FLOAT NOT NULL DEFAULT 0,\
            `pos_a` FLOAT NOT NULL DEFAULT 0,\
            `interior` INT(11) NOT NULL DEFAULT 0,\
            `world` INT(11) NOT NULL DEFAULT 0,\
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,\
            `last_login` TIMESTAMP NULL DEFAULT NULL,\
            PRIMARY KEY (`id`),\
            UNIQUE KEY `username` (`username`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    return 1;
}

stock SavePlayerData(playerid, reason)
{
    if(!Player[playerid][pLogged]) return 0;

    if(reason == 1)
    {
        GetPlayerPos(playerid, Player[playerid][pPosX], Player[playerid][pPosY], Player[playerid][pPosZ]);
        GetPlayerFacingAngle(playerid, Player[playerid][pPosA]);
        Player[playerid][pInterior] = GetPlayerInterior(playerid);
        Player[playerid][pWorld] = GetPlayerVirtualWorld(playerid);
        Player[playerid][pMoney] = GetPlayerMoney(playerid);
        Player[playerid][pScore] = GetPlayerScore(playerid);
        Player[playerid][pSkin] = GetPlayerSkin(playerid);
    }

    new query[320];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET \
            `score` = %d, `money` = %d, `skin` = %d, \
            `pos_x` = %f, `pos_y` = %f, `pos_z` = %f, `pos_a` = %f, \
            `interior` = %d, `world` = %d \
         WHERE `id` = %d LIMIT 1",
        Player[playerid][pScore],
        Player[playerid][pMoney],
        Player[playerid][pSkin],
        Player[playerid][pPosX],
        Player[playerid][pPosY],
        Player[playerid][pPosZ],
        Player[playerid][pPosA],
        Player[playerid][pInterior],
        Player[playerid][pWorld],
        Player[playerid][pID]);
    mysql_tquery(g_SQL, query);
    return 1;
}
