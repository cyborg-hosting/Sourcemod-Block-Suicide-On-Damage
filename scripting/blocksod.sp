#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
    name        = "Block suicide on damage",
    author      = "Ignobel",
    description = "Keep players from abusing suicide system.",
    version     = "1.0.0",
    url         = "https://discord.gg/foolishserver"
};

bool g_bLateLoad = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = true;
}

ConVar suicideTimerSec = null;
int suicideTimerSecInt = 5;

int damageTimestamp[MAXPLAYERS + 1] = { 0 };
bool inRespawnroom[MAXPLAYERS + 1] = { false };

public void OnPluginStart()
{
    LoadTranslations("blocksod.phrases.txt");
    suicideTimerSec = CreateConVar("sm_blocksuicide_timer", "5", "Time (in seconds) which blocker activates for.", 0, true, 1.0);
    HookConVarChange(suicideTimerSec, suicideTimerSecChange);
    
    HookEvent("player_changeclass", eventSuicide, EventHookMode_Pre);
    HookEvent("player_spawn", eventSpawn, EventHookMode_Post);
    
    AddCommandListener(commandSuicide, "kill");
    AddCommandListener(commandSuicide, "explode");
    AddCommandListener(commandSuicide, "jointeam");
    AddCommandListener(commandSuicide, "join_class");
    AddCommandListener(commandSuicide, "joinclass");
    AddCommandListener(commandSuicide, "changeclass");

    int spawnroomEntity = -1;

    while((spawnroomEntity = FindEntityByClassname(spawnroomEntity, "func_respawnroom")) != -1)
    {
        SDKHook(spawnroomEntity, SDKHook_StartTouchPost, OnRespawnroomStartTouch);
        SDKHook(spawnroomEntity, SDKHook_EndTouchPost, OnRespawnroomEndTouch);
    }
    
    if(g_bLateLoad)
    {
        for(int i = 1; i <= MaxClients; i++)
        {
            if(isValidClient(i))
            {
                SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamageHook);
            }
        }
    }
}

public void suicideTimerSecChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    suicideTimerSecInt = StringToInt(newValue);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamageHook);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamageHook);
}

public void OnTakeDamageHook(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    damageTimestamp[victim] = GetTime();
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrEqual(classname, "func_respawnroom", false))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnRespawnroomStartTouch);
		SDKHook(entity, SDKHook_EndTouchPost, OnRespawnroomEndTouch);
	}
}

public Action commandSuicide(int client, const char[] command, int argc)
{
    if(!isValidClient(client))
    {
        return Plugin_Continue;
    }

    if(inRespawnroom[client])
        return Plugin_Continue;
    
    if(!IsPlayerAlive(client))
        return Plugin_Continue;
    
    if(GetTime() - damageTimestamp[client] > suicideTimerSecInt)
        return Plugin_Continue;
        
    
    PrintCenterText(client, "%t", "BlockAlert");
    return Plugin_Handled;
}

public Action eventSuicide(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid", -1);
    
    if(userid == -1)
        return Plugin_Continue;
    
    int client = GetClientOfUserId(userid);
    
    if(!isValidClient(client))
    {
        return Plugin_Continue;
    }

    if(inRespawnroom[client])
        return Plugin_Continue;
    
    if(!IsPlayerAlive(client))
        return Plugin_Continue;
    
    if(GetTime() - damageTimestamp[client] > suicideTimerSecInt)
        return Plugin_Continue;
        
    
    PrintCenterText(client, "%t", "BlockAlert");
    return Plugin_Handled;
}

public void eventSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid", -1);
    
    if(userid == -1)
        return;
    
    int client = GetClientOfUserId(userid);
    
    damageTimestamp[client] = 0;
}

public void OnRespawnroomStartTouch(int entity, int other)
{
    if(isValidClient(other))
    {
        inRespawnroom[other] = true;
    }
}

public void OnRespawnroomEndTouch(int entity, int other)
{
    if(isValidClient(other))
    {
        inRespawnroom[other] = false;
    }
}

stock bool isValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client);
}