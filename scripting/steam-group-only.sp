#include <sourcemod>
#include <SteamWorks>

#define BASE_STR_LEN 256

public Plugin myinfo = {
    name = "Steam Group Only",
    author = "Eric Zhang",
    description = "Only allows members of a Steam group to join a server.",
    version = "1.0",
    url = "https://ericaftereric.top"
};

ConVar cvarEnable;
ConVar cvarSteamGroup;
ConVar cvarKickMessage;

public void OnPluginStart() {
    cvarEnable = CreateConVar("sm_steam_group_only_enable", "1", "Only allows Steam group members to join the server.");
    cvarSteamGroup = FindConVar("sv_steamgroup");
    if (cvarSteamGroup == null) {
        cvarSteamGroup = CreateConVar("sm_steam_group_only_steamgroup", "", "The ID of the Steam group the server should use.");
    }
    cvarKickMessage = CreateConVar("sm_steam_group_only_kick_msg", "", "Custom kick message when a user is not in the Steam group.");

    AutoExecConfig();
}


public void OnClientPostAdminCheck(int client) {
    if (!cvarEnable.BoolValue) {
        return;
    }
    if (IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client)) {
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
        char kickMsg[BASE_STR_LEN];
        cvarKickMessage.GetString(kickMsg, sizeof(kickMsg));
        TrimString(kickMsg);
        if (!strlen(kickMsg)) {
            strcopy(kickMsg, sizeof(kickMsg), "Client not in Steam group.");
        }
        KickClient(client, kickMsg);
    }

    return 0;
}

int GetClientFromAuthId(int authId) {
    char targetAuthIdStr[MAX_AUTHID_LENGTH];
    IntToString(authId, targetAuthIdStr, sizeof(targetAuthIdStr));
    for (int i = 1; i <= MaxClients; i++) {
        char authStr[MAX_AUTHID_LENGTH];
        if (IsClientInGame(i) && GetClientAuthId(i, AuthId_Steam3, authStr, sizeof(authStr))) {
            if (StrContains(authStr, targetAuthIdStr) != -1) {
                return i;
            }
        }
    }
    return -1;
}
