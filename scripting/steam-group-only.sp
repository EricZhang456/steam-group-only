#include <sourcemod>
#include <adt>
#include <SteamWorks>

#define BASE_STR_LEN 256

public Plugin myinfo = {
    name = "Steam Group Only",
    author = "Eric Zhang",
    description = "Only allows members of a Steam group to join a server.",
    version = "1.1",
    url = "https://ericaftereric.top"
};

ArrayList steamIdWhitelist;

ConVar cvarEnable;
ConVar cvarWhitelistEnable;
ConVar cvarWhitelistPath;
ConVar cvarSteamGroup;
ConVar cvarKickMessage;

public void OnPluginStart() {
    cvarEnable = CreateConVar("sm_steam_group_only_enable", "1", "Only allows Steam group members to join the server.");
    cvarSteamGroup = FindConVar("sv_steamgroup");
    if (cvarSteamGroup == null) {
        cvarSteamGroup = CreateConVar("sm_steam_group_only_steamgroup", "", "The ID of the Steam group the server should use.", FCVAR_NOTIFY);
    }
    cvarKickMessage = CreateConVar("sm_steam_group_only_kick_msg", "", "Custom kick message when a user is not in the Steam group.");
    cvarWhitelistEnable = CreateConVar("sm_steam_group_only_whitelist_enable", "1", "Enables the whitelist feature.");
    cvarWhitelistPath = CreateConVar("sm_steam_group_only_whitelist_path", "configs/steam-group-only-whitelist.txt", "Path to the Steam ID whitelist.");

    RegAdminCmd("sm_reload_steam_group_whitelist", Cmd_WhitelistReload, ADMFLAG_CONFIG, "Reloads the Steam ID whitelist");

    AutoExecConfig();
}

public void OnConfigsExecuted() {
    LoadWhitelist();
}

public Action Cmd_WhitelistReload(int client, int args) {
    LoadWhitelist();
    return Plugin_Handled;
}

void LoadWhitelist() {
    if (steamIdWhitelist == null) {
        steamIdWhitelist = new ArrayList(ByteCountToCells(MAX_AUTHID_LENGTH));
    } else {
        steamIdWhitelist.Clear();
    }

    char whitelistPath[PLATFORM_MAX_PATH], cvarPath[PLATFORM_MAX_PATH];
    cvarWhitelistPath.GetString(cvarPath, sizeof(cvarPath));
    BuildPath(Path_SM, whitelistPath, sizeof(whitelistPath), cvarPath);
    File whitelistFile = OpenFile(whitelistPath, "r");
    if (whitelistFile == null) {
        LogMessage("Warning: Cannot open whitelist file.");
        return;
    }
    while (!whitelistFile.EndOfFile()) {
        char line[MAX_AUTHID_LENGTH];
        whitelistFile.ReadLine(line, sizeof(line));
        TrimString(line);
        LogMessage("line: %s", line);
        if (!strlen(line)) {
            continue;
        }
        if (line[0] == '#') {
            LogMessage("skipping %s", line);
            continue;
        }
        steamIdWhitelist.PushString(line);
    }
    delete whitelistFile;
}

public void OnClientPostAdminCheck(int client) {
    if (!cvarEnable.BoolValue) {
        return;
    }
    if (IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client)) {
        return;
    }
    if (cvarWhitelistEnable.BoolValue && IsClientInWhitelist(client)) {
        return;
    }

    SteamWorks_GetUserGroupStatus(client, cvarSteamGroup.IntValue);
}

public int SteamWorks_OnClientGroupStatus(int authid, int groupid, bool isMember, bool isOfficer) {
    if (!cvarEnable.BoolValue) {
        return 0;
    }
    if (groupid != cvarSteamGroup.IntValue) {
        return 0;
    }

    if (!isMember) {
        int client = GetClientFromAuthId(authid);
        if (client == -1) {
            return 0;
        }
        if (cvarWhitelistEnable.BoolValue && IsClientInWhitelist(client)) {
            return 0;
        }

        char kickMsg[BASE_STR_LEN];
        cvarKickMessage.GetString(kickMsg, sizeof(kickMsg));
        TrimString(kickMsg);
        if (!strlen(kickMsg)) {
            strcopy(kickMsg, sizeof(kickMsg), "Client not in Steam group");
        }
        KickClient(client, kickMsg);
    }

    return 0;
}

int GetClientFromAuthId(int authId) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetSteamAccountID(i) == authId) {
            return i;
        }
    }
    return -1;
}

bool IsClientInWhitelist(int client) {
    if (!IsClientInGame(client)) {
        return false;
    }
    char clientAuthId[MAX_AUTHID_LENGTH];
    GetClientAuthId(client, AuthId_Steam3, clientAuthId, sizeof(clientAuthId));
    if (StrEqual(clientAuthId, "BOT")) {
        return true;
    }
    for (int i = 0; i < steamIdWhitelist.Length; i++) {
        char whitelistEntry[MAX_AUTHID_LENGTH];
        steamIdWhitelist.GetString(i, whitelistEntry, sizeof(whitelistEntry));
        if (StrEqual(clientAuthId, whitelistEntry)) {
            return true;
        }
    }
    return false;
}
