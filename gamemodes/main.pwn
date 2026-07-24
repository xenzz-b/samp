#include <a_samp>
#include <a_mysql>

#undef MAX_PLAYERS
#define MAX_PLAYERS             50
#define MAX_CHARS               3

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
#define COLOR_ORANGE            0xFFA500FF

new MySQL:g_SQL;
new g_MysqlRaceCheck[MAX_PLAYERS];

enum E_ACCOUNT
{
    pID,
    pUCP[MAX_PLAYER_NAME],
    pName[MAX_PLAYER_NAME],
    pIP[16],
    pPassword[65],
    pSalt[17],
    pAdmin,
    pLevel,
    pMoney,
    pBankMoney,
    pSkin,
    pGender,
    pAge,
    Float:pHealth,
    Float:pArmor,
    Float:pPosX,
    Float:pPosY,
    Float:pPosZ,
    Float:pPosA,
    pInterior,
    pWorld,
    bool:IsLoggedIn,
    bool:pSpawned,
    bool:pUCPLogged,
    pLoginAttempts,
    pLoginTimer,
    pCharCount,
    pCharListID[MAX_CHARS],
    pCharListLevel[MAX_CHARS],
    pCharListMoney[MAX_CHARS],
    pTempGender,
    pTempAge
};
new AccountData[MAX_PLAYERS][E_ACCOUNT];
new CharListName[MAX_PLAYERS][MAX_CHARS][MAX_PLAYER_NAME];

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
    g_MysqlRaceCheck[playerid]++;
    ResetAccountData(playerid);

    GetPlayerName(playerid, AccountData[playerid][pUCP], MAX_PLAYER_NAME);
    GetPlayerIp(playerid, AccountData[playerid][pIP], 16);

    SetPlayerColor(playerid, 0xAAAAAAAA);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    g_MysqlRaceCheck[playerid]++;
    SaveCharacterData(playerid, reason);

    if(AccountData[playerid][pLoginTimer])
    {
        KillTimer(AccountData[playerid][pLoginTimer]);
        AccountData[playerid][pLoginTimer] = 0;
    }

    AccountData[playerid][IsLoggedIn] = false;
    AccountData[playerid][pSpawned] = false;
    AccountData[playerid][pUCPLogged] = false;
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    #pragma unused classid

    if(IsPlayerNPC(playerid)) return Kick(playerid);

    if(!AccountData[playerid][IsLoggedIn])
    {
        TogglePlayerSpectating(playerid, true);
        SetPlayerCameraPos(playerid, 1611.0950, -977.3692, 120.9438);
        SetPlayerCameraLookAt(playerid, 1590.8446, -2051.6296, 120.9438);
        InterpolateCameraPos(playerid, 1611.0950, -977.3692, 120.9438, 1659.8245, -2007.6086, 120.9438, 50000, CAMERA_MOVE);

        if(IsUCPAlreadyOnline(playerid))
        {
            new str[128];
            format(str, sizeof(str), "[Anti-Double Login] UCP %s sudah online!", AccountData[playerid][pUCP]);
            SendClientMessage(playerid, COLOR_LIGHTRED, str);
            DelayedKick(playerid);
            return 1;
        }

        new query[160];
        mysql_format(g_SQL, query, sizeof(query),
            "SELECT * FROM `player_ucp` WHERE `UCP` = '%e' LIMIT 1",
            AccountData[playerid][pUCP]);
        mysql_tquery(g_SQL, query, "CheckPlayerUCP", "dd", playerid, g_MysqlRaceCheck[playerid]);
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    if(!AccountData[playerid][IsLoggedIn] || !AccountData[playerid][pSpawned])
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Tombol spawn dinonaktifkan. Login UCP dulu.");
        TogglePlayerSpectating(playerid, true);
        return 0;
    }
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(!AccountData[playerid][IsLoggedIn] || !AccountData[playerid][pSpawned])
    {
        TogglePlayerSpectating(playerid, true);
        return 0;
    }

    SetPlayerSkin(playerid, AccountData[playerid][pSkin]);
    SetPlayerScore(playerid, AccountData[playerid][pLevel]);
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, AccountData[playerid][pMoney]);
    SetPlayerHealth(playerid, AccountData[playerid][pHealth]);
    SetPlayerArmour(playerid, AccountData[playerid][pArmor]);
    SetPlayerInterior(playerid, AccountData[playerid][pInterior]);
    SetPlayerVirtualWorld(playerid, AccountData[playerid][pWorld]);
    SetPlayerPos(playerid, AccountData[playerid][pPosX], AccountData[playerid][pPosY], AccountData[playerid][pPosZ]);
    SetPlayerFacingAngle(playerid, AccountData[playerid][pPosA]);
    SetCameraBehindPlayer(playerid);
    SetPlayerColor(playerid, COLOR_WHITE);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    #pragma unused killerid, reason
    if(AccountData[playerid][pSpawned])
    {
        AccountData[playerid][pHealth] = 100.0;
        AccountData[playerid][pArmor] = 0.0;
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!AccountData[playerid][IsLoggedIn] || !AccountData[playerid][pSpawned])
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Login dan pilih karakter dulu.");
        return 1;
    }

    if(!strcmp(cmdtext, "/stats", true))
    {
        new str[180];
        format(str, sizeof(str),
            "UCP: %s | Char: %s | Level: %d | Cash: $%d | Bank: $%d",
            AccountData[playerid][pUCP],
            AccountData[playerid][pName],
            AccountData[playerid][pLevel],
            AccountData[playerid][pMoney],
            AccountData[playerid][pBankMoney]);
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

        case DIALOG_REGISTER:
        {
            if(!response) return DelayedKick(playerid);

            new len = strlen(inputtext);
            if(len < 6 || len > 32)
                return ShowRegisterDialog(playerid, "Password harus 6-32 karakter.");

            for(new i = 0; i < 16; i++) AccountData[playerid][pSalt][i] = random(94) + 33;
            AccountData[playerid][pSalt][16] = EOS;

            SHA256_PassHash(inputtext, AccountData[playerid][pSalt], AccountData[playerid][pPassword], 65);

            new query[320];
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `player_ucp` (`UCP`, `IP`, `Password`, `Salt`, `Register_Date`, `Last_Login`) VALUES ('%e', '%e', '%e', '%e', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                AccountData[playerid][pUCP],
                AccountData[playerid][pIP],
                AccountData[playerid][pPassword],
                AccountData[playerid][pSalt]);
            mysql_tquery(g_SQL, query, "OnUCPRegistered", "dd", playerid, g_MysqlRaceCheck[playerid]);
            return 1;
        }

        case DIALOG_LOGIN:
        {
            if(!response) return DelayedKick(playerid);
            if(!inputtext[0]) return ShowLoginDialog(playerid, "Password tidak boleh kosong.");

            new hash[65];
            SHA256_PassHash(inputtext, AccountData[playerid][pSalt], hash, sizeof(hash));

            if(strcmp(hash, AccountData[playerid][pPassword]))
            {
                AccountData[playerid][pLoginAttempts]++;
                if(AccountData[playerid][pLoginAttempts] >= 3)
                {
                    ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "UCP - Login",
                        "Password salah 3 kali.\nAnda ditendang dari server.", "Quit", "");
                    return DelayedKick(playerid);
                }

                new str[80];
                format(str, sizeof(str), "Password salah! Sisa kesempatan: %d", 3 - AccountData[playerid][pLoginAttempts]);
                return ShowLoginDialog(playerid, str);
            }

            if(AccountData[playerid][pLoginTimer])
            {
                KillTimer(AccountData[playerid][pLoginTimer]);
                AccountData[playerid][pLoginTimer] = 0;
            }

            AccountData[playerid][pUCPLogged] = true;
            AccountData[playerid][pLoginAttempts] = 0;
            SendClientMessage(playerid, COLOR_GREEN, "Login UCP berhasil. Memuat karakter...");

            new query[160];
            mysql_format(g_SQL, query, sizeof(query),
                "UPDATE `player_ucp` SET `Last_Login` = CURRENT_TIMESTAMP, `IP` = '%e' WHERE `UCP` = '%e' LIMIT 1",
                AccountData[playerid][pIP], AccountData[playerid][pUCP]);
            mysql_tquery(g_SQL, query);

            mysql_format(g_SQL, query, sizeof(query),
                "SELECT `pID`, `Char_Name`, `Char_Level`, `Char_Money` FROM `player_characters` WHERE `Char_UCP` = '%e' LIMIT %d",
                AccountData[playerid][pUCP], MAX_CHARS);
            mysql_tquery(g_SQL, query, "LoadCharacter", "dd", playerid, g_MysqlRaceCheck[playerid]);
            return 1;
        }

        case DIALOG_CHAR_LIST:
        {
            if(!response) return DelayedKick(playerid);
            if(!AccountData[playerid][pUCPLogged]) return DelayedKick(playerid);

            if(listitem < 0) return ShowCharacterList(playerid);

            if(listitem >= AccountData[playerid][pCharCount])
            {
                if(AccountData[playerid][pCharCount] >= MAX_CHARS)
                {
                    SendClientMessage(playerid, COLOR_LIGHTRED, "Slot karakter penuh (maks 3).");
                    return ShowCharacterList(playerid);
                }
                return ShowCharNameDialog(playerid, "");
            }

            new query[180];
            mysql_format(g_SQL, query, sizeof(query),
                "SELECT * FROM `player_characters` WHERE `pID` = %d AND `Char_UCP` = '%e' LIMIT 1",
                AccountData[playerid][pCharListID][listitem],
                AccountData[playerid][pUCP]);
            mysql_tquery(g_SQL, query, "OnCharacterSelected", "dd", playerid, g_MysqlRaceCheck[playerid]);
            return 1;
        }

        case DIALOG_CHAR_NAME:
        {
            if(!response) return ShowCharacterList(playerid);
            if(!IsValidRoleplayName(inputtext))
                return ShowCharNameDialog(playerid, "Format: Nama_Belakang (contoh: John_Doe)");

            new query[128];
            mysql_format(g_SQL, query, sizeof(query),
                "SELECT `pID` FROM `player_characters` WHERE `Char_Name` = '%e' LIMIT 1", inputtext);
            mysql_tquery(g_SQL, query, "InsertPlayerName", "dds", playerid, g_MysqlRaceCheck[playerid], inputtext);
            return 1;
        }

        case DIALOG_CHAR_GENDER:
        {
            if(!response) return ShowCharNameDialog(playerid, "");
            if(listitem < 0 || listitem > 1) return ShowGenderDialog(playerid);

            AccountData[playerid][pTempGender] = listitem + 1;
            AccountData[playerid][pSkin] = (listitem == 0) ? 26 : 40;
            return ShowAgeDialog(playerid, "");
        }

        case DIALOG_CHAR_AGE:
        {
            if(!response) return ShowGenderDialog(playerid);

            new age = strval(inputtext);
            if(age < 16 || age > 80)
                return ShowAgeDialog(playerid, "Umur harus 16-80.");

            AccountData[playerid][pTempAge] = age;
            FinishCreateCharacter(playerid);
            return 1;
        }
    }
    return 0;
}

forward CheckPlayerUCP(playerid, race_check);
public CheckPlayerUCP(playerid, race_check)
{
    if(race_check != g_MysqlRaceCheck[playerid]) return Kick(playerid);
    if(!IsPlayerConnected(playerid)) return 0;

    TogglePlayerSpectating(playerid, true);

    if(cache_num_rows() > 0)
    {
        cache_get_value_name(0, "Password", AccountData[playerid][pPassword], 65);
        cache_get_value_name(0, "Salt", AccountData[playerid][pSalt], 17);
        cache_get_value_name_int(0, "Admin", AccountData[playerid][pAdmin]);
        cache_get_value_name_int(0, "ID", AccountData[playerid][pID]);

        ShowLoginDialog(playerid, "");
        AccountData[playerid][pLoginTimer] = SetTimerEx("OnPlayerNotLogin", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
    }
    else
    {
        ShowRegisterDialog(playerid, "");
    }
    return 1;
}

forward OnUCPRegistered(playerid, race_check);
public OnUCPRegistered(playerid, race_check)
{
    if(race_check != g_MysqlRaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_insert_id() <= 0)
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Gagal register UCP.");
        return ShowRegisterDialog(playerid, "Registrasi gagal, coba lagi.");
    }

    AccountData[playerid][pID] = cache_insert_id();
    SendClientMessage(playerid, COLOR_GREEN, "UCP berhasil didaftarkan. Silakan login.");
    ShowLoginDialog(playerid, "");
    AccountData[playerid][pLoginTimer] = SetTimerEx("OnPlayerNotLogin", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
    return 1;
}

forward LoadCharacter(playerid, race_check);
public LoadCharacter(playerid, race_check)
{
    if(race_check != g_MysqlRaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    AccountData[playerid][pCharCount] = 0;

    new rows = cache_num_rows();
    if(rows > MAX_CHARS) rows = MAX_CHARS;

    for(new i = 0; i < rows; i++)
    {
        cache_get_value_name_int(i, "pID", AccountData[playerid][pCharListID][i]);
        cache_get_value_name(i, "Char_Name", CharListName[playerid][i], MAX_PLAYER_NAME);
        cache_get_value_name_int(i, "Char_Level", AccountData[playerid][pCharListLevel][i]);
        cache_get_value_name_int(i, "Char_Money", AccountData[playerid][pCharListMoney][i]);
        AccountData[playerid][pCharCount]++;
    }

    ShowCharacterList(playerid);
    return 1;
}

forward InsertPlayerName(playerid, race_check, name[]);
public InsertPlayerName(playerid, race_check, name[])
{
    if(race_check != g_MysqlRaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(cache_num_rows() > 0)
        return ShowCharNameDialog(playerid, "Nama sudah digunakan!");

    format(AccountData[playerid][pName], MAX_PLAYER_NAME, "%s", name);
    ShowGenderDialog(playerid);
    return 1;
}

forward OnPlayerRegister(playerid, race_check);
public OnPlayerRegister(playerid, race_check)
{
    if(race_check != g_MysqlRaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    AccountData[playerid][pID] = cache_insert_id();
    if(AccountData[playerid][pID] <= 0)
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Gagal membuat karakter.");
        return ShowCharacterList(playerid);
    }

    AccountData[playerid][pLevel] = 1;
    AccountData[playerid][pMoney] = 5000;
    AccountData[playerid][pBankMoney] = 0;
    AccountData[playerid][pHealth] = 100.0;
    AccountData[playerid][pArmor] = 0.0;
    AccountData[playerid][pPosX] = DEFAULT_POS_X;
    AccountData[playerid][pPosY] = DEFAULT_POS_Y;
    AccountData[playerid][pPosZ] = DEFAULT_POS_Z;
    AccountData[playerid][pPosA] = DEFAULT_POS_A;
    AccountData[playerid][pInterior] = 0;
    AccountData[playerid][pWorld] = 0;
    AccountData[playerid][pGender] = AccountData[playerid][pTempGender];
    AccountData[playerid][pAge] = AccountData[playerid][pTempAge];

    SendClientMessage(playerid, COLOR_GREEN, "Karakter berhasil dibuat.");
    SpawnAsCharacter(playerid);
    return 1;
}

forward OnCharacterSelected(playerid, race_check);
public OnCharacterSelected(playerid, race_check)
{
    if(race_check != g_MysqlRaceCheck[playerid]) return 0;
    if(!IsPlayerConnected(playerid)) return 0;

    if(!cache_num_rows())
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Karakter tidak ditemukan.");
        return ShowCharacterList(playerid);
    }

    cache_get_value_name_int(0, "pID", AccountData[playerid][pID]);
    cache_get_value_name(0, "Char_Name", AccountData[playerid][pName], MAX_PLAYER_NAME);
    cache_get_value_name_int(0, "Char_Level", AccountData[playerid][pLevel]);
    cache_get_value_name_int(0, "Char_Money", AccountData[playerid][pMoney]);
    cache_get_value_name_int(0, "Char_BankMoney", AccountData[playerid][pBankMoney]);
    cache_get_value_name_int(0, "Char_Skin", AccountData[playerid][pSkin]);
    cache_get_value_name_int(0, "Char_Gender", AccountData[playerid][pGender]);
    cache_get_value_name_int(0, "Char_Age", AccountData[playerid][pAge]);
    cache_get_value_name_float(0, "Char_Health", AccountData[playerid][pHealth]);
    cache_get_value_name_float(0, "Char_Armor", AccountData[playerid][pArmor]);
    cache_get_value_name_float(0, "Char_PosX", AccountData[playerid][pPosX]);
    cache_get_value_name_float(0, "Char_PosY", AccountData[playerid][pPosY]);
    cache_get_value_name_float(0, "Char_PosZ", AccountData[playerid][pPosZ]);
    cache_get_value_name_float(0, "Char_PosA", AccountData[playerid][pPosA]);
    cache_get_value_name_int(0, "Char_IntID", AccountData[playerid][pInterior]);
    cache_get_value_name_int(0, "Char_WID", AccountData[playerid][pWorld]);

    if(AccountData[playerid][pHealth] < 10.0) AccountData[playerid][pHealth] = 100.0;

    new query[120];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `player_characters` SET `Char_LastLogin` = CURRENT_TIMESTAMP WHERE `pID` = %d LIMIT 1",
        AccountData[playerid][pID]);
    mysql_tquery(g_SQL, query);

    SpawnAsCharacter(playerid);
    return 1;
}

forward OnPlayerNotLogin(playerid);
public OnPlayerNotLogin(playerid)
{
    AccountData[playerid][pLoginTimer] = 0;
    if(!IsPlayerConnected(playerid) || AccountData[playerid][pUCPLogged]) return 0;

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

stock ResetAccountData(playerid)
{
    static const empty[E_ACCOUNT];
    AccountData[playerid] = empty;
    AccountData[playerid][pHealth] = 100.0;
    return 1;
}

stock IsUCPAlreadyOnline(playerid)
{
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(i == playerid || !IsPlayerConnected(i)) continue;
        if(!AccountData[i][pUCPLogged] && !AccountData[i][IsLoggedIn]) continue;
        if(!strcmp(AccountData[i][pUCP], AccountData[playerid][pUCP], true)) return 1;
    }
    return 0;
}

stock ShowLoginDialog(playerid, const extra[])
{
    new str[280];
    if(extra[0])
        format(str, sizeof(str),
            "{FFFFFF}Username {FFFF00}%s {FFFFFF}terdaftar.\n{FF6347}%s\n\n{FFFFFF}Masukkan password untuk login:",
            AccountData[playerid][pUCP], extra);
    else
        format(str, sizeof(str),
            "{FFFFFF}Username {FFFF00}%s {FFFFFF}terdaftar.\nSilakan masukkan password untuk login:",
            AccountData[playerid][pUCP]);

    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "UCP - Login", str, "Login", "Quit");
    return 1;
}

stock ShowRegisterDialog(playerid, const extra[])
{
    new str[280];
    if(extra[0])
        format(str, sizeof(str),
            "{FFFFFF}Selamat datang!\nUCP: {FF6347}%s\n{FF6347}%s\n\n{FFFFFF}Masukkan password untuk mendaftar:",
            AccountData[playerid][pUCP], extra);
    else
        format(str, sizeof(str),
            "{FFFFFF}Selamat datang!\nUCP: {FF6347}%s\nBelum terdaftar.\n\n{FFFFFF}Masukkan password untuk mendaftar (6-32):",
            AccountData[playerid][pUCP]);

    ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "UCP - Register", str, "Daftar", "Quit");
    return 1;
}

stock ShowCharacterList(playerid)
{
    new list[560], line[96];
    format(list, sizeof(list), "Nama\tLevel\tMoney\n");

    for(new i = 0; i < AccountData[playerid][pCharCount]; i++)
    {
        format(line, sizeof(line), "%s\tLevel %d\t$%d\n",
            CharListName[playerid][i],
            AccountData[playerid][pCharListLevel][i],
            AccountData[playerid][pCharListMoney][i]);
        strcat(list, line);
    }

    if(AccountData[playerid][pCharCount] < MAX_CHARS)
        strcat(list, "{33AA33}+ Buat Karakter Baru\n");

    ShowPlayerDialog(playerid, DIALOG_CHAR_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Pilih Karakter", list, "Pilih", "Quit");
    return 1;
}

stock ShowCharNameDialog(playerid, const extra[])
{
    new str[220];
    if(extra[0])
        format(str, sizeof(str), "{FF6347}%s\n\n{FFFFFF}Masukkan nama karakter:\nContoh: John_Doe / Udin_Ahmad", extra);
    else
        format(str, sizeof(str), "{FFFFFF}Masukkan nama karakter:\nFormat: Nama_Belakang\nContoh: John_Doe / Udin_Ahmad");

    ShowPlayerDialog(playerid, DIALOG_CHAR_NAME, DIALOG_STYLE_INPUT, "Pembuatan Karakter", str, "Lanjut", "Kembali");
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
        format(str, sizeof(str), "{FF6347}%s\n\n{FFFFFF}Masukkan umur (16-80):", extra);
    else
        format(str, sizeof(str), "{FFFFFF}Masukkan umur karakter (16-80):");

    ShowPlayerDialog(playerid, DIALOG_CHAR_AGE, DIALOG_STYLE_INPUT, "Umur Karakter", str, "Buat", "Kembali");
    return 1;
}

stock FinishCreateCharacter(playerid)
{
    new query[420];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `player_characters` (`Char_UCP`,`Char_Name`,`Char_IP`,`Char_Skin`,`Char_Gender`,`Char_Age`,`Char_Money`,`Char_PosX`,`Char_PosY`,`Char_PosZ`,`Char_PosA`,`Char_RegisterDate`,`Char_LastLogin`) VALUES ('%e','%e','%e',%d,%d,%d,5000,%f,%f,%f,%f,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",
        AccountData[playerid][pUCP],
        AccountData[playerid][pName],
        AccountData[playerid][pIP],
        AccountData[playerid][pSkin],
        AccountData[playerid][pTempGender],
        AccountData[playerid][pTempAge],
        DEFAULT_POS_X, DEFAULT_POS_Y, DEFAULT_POS_Z, DEFAULT_POS_A);
    mysql_tquery(g_SQL, query, "OnPlayerRegister", "dd", playerid, g_MysqlRaceCheck[playerid]);
    return 1;
}

stock SpawnAsCharacter(playerid)
{
    if(SetPlayerName(playerid, AccountData[playerid][pName]) == -1)
    {
        SendClientMessage(playerid, COLOR_LIGHTRED, "Gagal set nama karakter (sedang dipakai).");
        return ShowCharacterList(playerid);
    }

    AccountData[playerid][IsLoggedIn] = true;
    AccountData[playerid][pSpawned] = true;

    TogglePlayerSpectating(playerid, false);
    SetSpawnInfo(playerid, NO_TEAM, AccountData[playerid][pSkin],
        AccountData[playerid][pPosX], AccountData[playerid][pPosY], AccountData[playerid][pPosZ], AccountData[playerid][pPosA],
        0, 0, 0, 0, 0, 0);
    SpawnPlayer(playerid);

    new str[96];
    format(str, sizeof(str), "Spawn sebagai {FFFF00}%s", AccountData[playerid][pName]);
    SendClientMessage(playerid, COLOR_GREEN, str);
    return 1;
}

stock SaveCharacterData(playerid, reason)
{
    if(!AccountData[playerid][IsLoggedIn] || !AccountData[playerid][pSpawned] || AccountData[playerid][pID] <= 0) return 0;

    if(reason == 1)
    {
        GetPlayerPos(playerid, AccountData[playerid][pPosX], AccountData[playerid][pPosY], AccountData[playerid][pPosZ]);
        GetPlayerFacingAngle(playerid, AccountData[playerid][pPosA]);
        GetPlayerHealth(playerid, AccountData[playerid][pHealth]);
        GetPlayerArmour(playerid, AccountData[playerid][pArmor]);
        AccountData[playerid][pInterior] = GetPlayerInterior(playerid);
        AccountData[playerid][pWorld] = GetPlayerVirtualWorld(playerid);
        AccountData[playerid][pMoney] = GetPlayerMoney(playerid);
        AccountData[playerid][pSkin] = GetPlayerSkin(playerid);
        AccountData[playerid][pLevel] = GetPlayerScore(playerid);
    }

    new query[380];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `player_characters` SET `Char_Level`=%d,`Char_Money`=%d,`Char_BankMoney`=%d,`Char_Skin`=%d,`Char_Health`=%f,`Char_Armor`=%f,`Char_PosX`=%f,`Char_PosY`=%f,`Char_PosZ`=%f,`Char_PosA`=%f,`Char_IntID`=%d,`Char_WID`=%d WHERE `pID`=%d LIMIT 1",
        AccountData[playerid][pLevel],
        AccountData[playerid][pMoney],
        AccountData[playerid][pBankMoney],
        AccountData[playerid][pSkin],
        AccountData[playerid][pHealth],
        AccountData[playerid][pArmor],
        AccountData[playerid][pPosX],
        AccountData[playerid][pPosY],
        AccountData[playerid][pPosZ],
        AccountData[playerid][pPosA],
        AccountData[playerid][pInterior],
        AccountData[playerid][pWorld],
        AccountData[playerid][pID]);
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
