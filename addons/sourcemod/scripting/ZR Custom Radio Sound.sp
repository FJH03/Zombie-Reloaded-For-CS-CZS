#include <sourcemod>
#include <sdktools>
#include <cstrike>


bool DEBUGGING = false;

// csgo/scripts/game_sound_...
// ctmap_ and tmap_ are map positions for bots
char g_radioSounds[][] = {
	"affirmative",
	"agree",
	"blinded",
	"bombexploding",
	"bombsiteclear",
	"bombtickingdown",
	"clearedarea",
	"commanderdown",
	"coveringfriend",
	"coverme",
	"decoy",
	"defendingbombsitea",
	"defendingbombsiteb",
	"defusingbomb",
	"disagree",
	"endclean",
	"endclose",
	"endsolid",
	"enemydown",
	"enemyspotted",
	"fallback",
	"flashbang",
	"followingfriend",
	"followme",
	"friendlyfire",
	"goingtodefendbombsite",
	"goingtoguardhostageescapezone",
	"goingtoguardloosebomb",
	"goingtoplantbomb",
	"goingtoplantbomba",
	"goingtoplantbombb",
	"grenade",
	"guardingloosebomb",
	"heardnoise",
	"help",
	"incombat",
	"inposition",
	"killedfriend",
	"lastmanstanding",
	"letsgo",
	"locknload",
	"lostenemy",
	"molotov",
	"needbackup",
	"negative",
	"niceshot",
	"noenemiesleft",
	"noenemiesleftbomb",
	"onarollbrag",
	"oneenemyleft",
	"onmyway",
	"peptalk",
	"pinneddown",
	"plantingbomb",
	"query",
	"regroup",
	"reportingin",
	"requestreport",
	"scaredemote",
	"smoke",
	"sniperkilled",
	"sniperwarning",
	"spottedbomber",
	"spottedloosebomb",
	"takingfire",
	"thanks",
	"theypickedupthebomb",
	"threeenemiesleft",
	"time",
	"twoenemiesleft",
	"waitingforhumantodefusebomb",
	"waitinghere",
	"whereisthebomb",
	"gameafkbombdrop",
	"needdrop",
	"goa",
	"gob",
	"sorry",
	"go",
	"getinpos",
	"stormfront",
	"report",
	"takepoint",
	"holdpos",
	"sticktog",
	"roger",
	"enemyspot",
	"sectorclear",
	"getout",
	"hold",
	"clear",
	"moveout",
	"fireinthehole",
}

#define MAXMODEL 200
char g_radioFiles[MAXMODEL][sizeof(g_radioSounds)][PLATFORM_MAX_PATH];
char g_model[MAXMODEL][512];
int modelcount;
int g_RoundGeneration;

public Plugin myinfo =
{
	name = "[ZR] Custom Radio Sound",
	author = "Kento & [CNSR] FJH_03",
	version = "1.22.1",
	description = "Custom Radio Sound.",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart() 
{	
	// For disable default radio sound.
	AddNormalSoundHook(Event_SoundPlayed);
	
	// Grenades
	HookUserMessage(GetUserMessageId("RadioText"), RadioText, true);
	HookUserMessage(GetUserMessageId("SendAudio"), SendAudioNew, true);
	HookEvent("round_end", RoundEnd_Radio, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Radio, EventHookMode_PostNoCopy);

	if(DEBUGGING)	RegAdminCmd("sm_radiomodels", Command_Model, ADMFLAG_ROOT);
}

void FindSampleByCmd(const char[] command, char[] sample, int maxlen)
{
	if(StrContains(command, "requestmove") != -1)						strcopy(sample, maxlen, "letsgo");
	else if(StrContains(command, "roundstart") != -1)						strcopy(sample, maxlen, "locknload");
	// else if(StrContains(command, "sticktog") != -1)					strcopy(sample, maxlen, "regroup");	
	else if(StrContains(command, "sticktogetherteam") != -1)			strcopy(sample, maxlen, "sticktog");	
	else if(StrContains(command, "sticktogether") != -1)				strcopy(sample, maxlen, "regroup");	
	// else if(StrContains(command, "holdpos") != -1)					strcopy(sample, maxlen, "hold");	
	//else if(StrContains(command, "affirmation") != -1)					strcopy(sample, maxlen, "affirmative");	
	// else if(StrContains(command, "roger") != -1)						strcopy(sample, maxlen, "affirmative");	
	else if(StrContains(command, "cheer") != -1)						strcopy(sample, maxlen, "onarollbrag");	
	else if(StrContains(command, "compliment") != -1)				strcopy(sample, maxlen, "onarollbrag");	
	// else if(StrContains(command, "enemyspot") != -1)					strcopy(sample, maxlen, "enemyspotted");	
	else if(StrContains(command, "seesenemy") != -1)					strcopy(sample, maxlen, "enemyspotted");	
	// else if(StrContains(command, "takepoint") != -1)					strcopy(sample, maxlen, "followingfriend");
	// else if(StrContains(command, "sectorclear") != -1)				strcopy(sample, maxlen, "clear");
	// else if(StrContains(command, "getout") != -1)					strcopy(sample, maxlen, "bombtickingdown");
	// else if(StrContains(command, "getoutofthere") != -1)				strcopy(sample, maxlen, "bombtickingdown");
	//else if(StrContains(command, "fireinthehole") != -1)				strcopy(sample, maxlen, "grenade");
	else if(StrContains(command, "molotovinthehole") != -1)			strcopy(sample, maxlen, "molotov");
	else if(StrContains(command, "flashbanginthehole") != -1)		strcopy(sample, maxlen, "flashbang");
	else if(StrContains(command, "smokeinthehole") != -1)			strcopy(sample, maxlen, "smoke");
	else if(StrContains(command, "decoyinthehole") != -1)			strcopy(sample, maxlen, "decoy");
	else if(StrContains(command, "negativeno") != -1)				strcopy(sample, maxlen, "negative");
	else if(StrContains(command, "requestweapon") != -1)				strcopy(sample, maxlen, "needdrop");
	else if(StrContains(command, "gotoa") != -1)							strcopy(sample, maxlen, "goa");
	else if(StrContains(command, "gotob") != -1)							strcopy(sample, maxlen, "gob");
	else if(StrContains(command, "goa") != -1)							strcopy(sample, maxlen, "goa");
	else if(StrContains(command, "gob") != -1)							strcopy(sample, maxlen, "gob");
	// else if(StrContains(command, "go") != -1)							strcopy(sample, maxlen, "letsgo");
	else if(StrContains(command, "holdthisposition") != -1)							strcopy(sample, maxlen, "holdpos");
	else if(StrContains(command, "gogogo") != -1)							strcopy(sample, maxlen, "go");
	//else if(StrContains(command, "letsgo") != -1)							strcopy(sample, maxlen, "go");
	else if(StrContains(command, "enemyspotted") != -1)					strcopy(sample, maxlen, "enemyspot");
	else if(StrContains(command, "clear") != -1)				strcopy(sample, maxlen, "sectorclear");
	else if(StrContains(command, "youtakethepoint") != -1)				strcopy(sample, maxlen, "takepoint");
	else if(StrContains(command, "stormthefront") != -1)				strcopy(sample, maxlen, "stormfront");
	else if(StrContains(command, "hold") != -1)					strcopy(sample, maxlen, "holdpos");
	else if(StrContains(command, "getinpositionandwait") != -1)					strcopy(sample, maxlen, "getinpos");
	else if(StrContains(command, "affirmative") != -1)					strcopy(sample, maxlen, "roger");
	else if(StrContains(command, "affirmation") != -1)					strcopy(sample, maxlen, "roger");	
	else if(StrContains(command, "rogerthat") != -1)					strcopy(sample, maxlen, "roger");
	else strcopy(sample, maxlen, command);
}

// grenades, planting, defusing and bot chats are radio text
public Action RadioText(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	/*
	https://github.com/alliedmodders/hl2sdk/blob/csgo/public/game/shared/csgo/protobuf/cstrike15_usermessages.proto#L268
	------------------------------------
	optional int32 msg_dst = 1;
	optional int32 client = 2;
	optional string msg_name = 3;
	repeated string params = 4;
	
	params strings cs_bloodstrike
	------------------------------------
	0 - #ENTNAME[2]Tim
	1 - #Cstrike_TitlesTXT_Sector_clear

	params strings de_inferno
	------------------------------------
	0 - #ENTNAME[8]Tom
	1 - Middle
	2 - #SFUI_TitlesTXT_Smoke_in_the_hole
	3 - auto
	
	csgo/resource/csgo_...
	------------------------------------
	"[english]SFUI_TitlesTXT_Fire_in_the_hole"	"Fire in the hole!"
	"[english]SFUI_TitlesTXT_Molotov_in_the_hole"	"FireBomb on the way!"
	"[english]SFUI_TitlesTXT_Flashbang_in_the_hole"	"Flashbang Out!"
	"[english]SFUI_TitlesTXT_Smoke_in_the_hole"	"Smoke Out!"
	"[english]SFUI_TitlesTXT_Decoy_in_the_hole"	"Decoy Out!"
	*/
	
	if(DEBUGGING)	PrintToServer("RadioText");
	
	char sBuffer[128];
	char buffer[64], sample[64];
	BfReadByte(msg);
	
	int client = BfReadByte(msg);
	if (!IsValidClient(client))
		return Plugin_Continue;

	char model[512];
	GetClientModel(client, model, sizeof(model));
	int mid = FindModelIDByName(model);
		
	BfReadString(msg, sBuffer, sizeof(sBuffer));
	if(strcmp(sBuffer, "#Game_radio_location", false) == 0)
	{
		BfReadString(msg, sBuffer, sizeof(sBuffer));
	}
	BfReadString(msg, sBuffer, sizeof(sBuffer));
	
	// for maps have zones
	//PbReadString(msg, "params", buffer, sizeof(buffer), 1);
	BfReadString(msg, buffer, sizeof(buffer));
	// for maps doesn't have zones
	// if( StrContains(buffer,"#Cstrike_TitlesTXT_") == -1 && StrContains(buffer,"#SFUI_TitlesTXT_") == -1)
		// PbReadString(msg, "params", buffer, sizeof(buffer), 2);

	if(DEBUGGING)	PrintToServer("params %s", buffer);
	ReplaceString(buffer, sizeof(buffer), "#Cstrike_TitlesTXT_", "", false);
	ReplaceString(buffer, sizeof(buffer), "#SFUI_TitlesTXT_", "", false);
	ReplaceString(buffer, sizeof(buffer), "_", "", false);

	for(int i = 0; i <= strlen(buffer); ++i) 
	{ 
		buffer[i] = CharToLower(buffer[i]); 
	} 

	FindSampleByCmd(buffer, sample, sizeof(sample));
	int rid = FindRadioBySample(sample);

	if(DEBUGGING)	PrintToServer("buf: %s, sample: %s, mid %d, rid %d, playersNum: %d, model - %s", buffer, sample, mid, rid, playersNum, model);
	
	if(mid > -1 && rid > -1)
	{
		char sound[PLATFORM_MAX_PATH];
		strcopy(sound, sizeof(sound), g_radioFiles[mid][rid]);
		if (sound[0] != '\0' && !StrEqual(sound, "*/"))
		{
			DataPack pack;
			if (CreateDataTimer(0.0, SendAudio, pack, TIMER_FLAG_NO_MAPCHANGE) != null)
			{
				pack.WriteCell(g_RoundGeneration);
				pack.WriteCell(GetClientSerial(client));
				pack.WriteString(sound);
				pack.WriteCell(playersNum);
				for (int i = 0; i < playersNum; i++)
					pack.WriteCell(IsValidClient(players[i]) ? GetClientSerial(players[i]) : 0);

				int filename = FindCharInString(sound, '/', true) + 1;
				char defaultSound[PLATFORM_MAX_PATH];
				Format(defaultSound, sizeof(defaultSound), "radio/%s", sound[filename]);
				if (DEBUGGING) PrintToServer("阻止: %s", defaultSound);
				StopSound(client, SNDCHAN_VOICE, defaultSound);
			}
			else
				delete pack;
		}

		if(StrEqual(sample, "roger"))
			StopSound(client, SNDCHAN_VOICE, "radio/ct_affirm.wav");
	}
	
	return Plugin_Continue;
}

public void SendAudio(Handle timer, DataPack pack)
{
	pack.Reset();
	if (pack.ReadCell() != g_RoundGeneration || !IsValidClient(GetClientFromSerial(pack.ReadCell())))
		return;

	char sound[PLATFORM_MAX_PATH];
	pack.ReadString(sound, sizeof(sound));
	int playersNum = pack.ReadCell();
	for (int i = 0; i < playersNum; i++)
	{
		int client = GetClientFromSerial(pack.ReadCell());
		if (IsValidClient(client) && !IsFakeClient(client))
		{
			if (DEBUGGING) PrintToServer("客户端: %d,%s", client, sound);
			EmitSoundToClient(client, sound, client, SNDCHAN_VOICE);
		}
	}
}

public void OnMapStart() 
{
	LoadRadio();
}

// For disable default radio sound.
public Action Event_SoundPlayed(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	// +playervophoenixclear02.wav
	// csgo/scripts/game_sound...
	
	// Is player voice
	// PrintToChatAll("%s", sample);
	// +player\vo\leet\threeenemiesleft03.wav
	
	if(DEBUGGING)	PrintToServer("实体索引:%d", entity);
	//if(StrContains(sample, "player") != -1 && IsValidEntity(entity) && entity > 0 && entity <= MaxClients)
	if(IsValidEntity(entity) && entity > 0 && entity <= MaxClients)
	{
		ReplaceString(sample, sizeof(sample), ".wav", "", false);
		ReplaceString(sample, sizeof(sample), "_", "", false);

		char model[512];
		GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
		int mid = FindModelIDByName(model);

		// Has found model id.
		if (mid > -1)
		{
			int rid = -1;
		
			// player/death1.wav
			if(StrContains(sample, "death") != -1)
			{
				rid = FindRadioBySample("death");
				if(DEBUGGING)	PrintToServer("hook sample: death, mid %d, rid %d, model - %s", mid, rid, model);

				// Has found radio id
				if (rid > -1)
				{
					// Re-use "sample" buffer
					Format(sample, sizeof(sample), "*/%s", g_radioFiles[mid][rid]);
					// Get the position of the entity that emitted the sound on the map
					float position[3];
					GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
					if (ArrayDeleteItem(clients, numClients, entity))
					{
						// The entity is found in the "clients" array and has been removed successfully.
						// Another emit especially for the entity since it's their own voice.
						// So "updatePos" = true for the entity.
						// EmitSoundToClient(entity, sample, entity, channel, level, (volume == SNDVOL_NORMAL) ? SND_NOFLAGS : SND_CHANGEVOL, volume);

						// Since the entity within "clients" array is removed from the array.
						// Correct the size of the array.
						numClients = numClients - 1;
					}

					// Can use the "clients" array since the game engine already take care of which clients should be able to hear the sound.
					// Hence, no need to check team for radio emit. And death groan can be heard by everyone (including enemies).
					// param "updatePos" = false means the sound will not change its position to follow the entities hearing the sound.
					// EmitSound(clients, numClients, sample, entity, channel, level, (volume == SNDVOL_NORMAL) ? SND_NOFLAGS : SND_CHANGEVOL, volume, SNDPITCH_NORMAL, -1, position, NULL_VECTOR, false);
					return Plugin_Stop;
				}
			}
			else
			{
				char radio[4][64];
				ExplodeString(sample, "\\", radio, sizeof(radio), sizeof(radio[]));	
				FindSampleByCmd(radio[3], radio[3], sizeof(radio[]));
				rid = FindRadioBySample(radio[3]);
				if(DEBUGGING)	PrintToServer("hook sample: %s, mid %d, rid %d, model - %s", radio[3], mid, rid, model);

				if (rid > -1)
				{
					Format(sample, sizeof(sample), "*/%s", g_radioFiles[mid][rid]);
					// updatePos = true will make the sound update its position follow to the hearing entity
					// Since this is radio sound, all clients (that should be able to hear) should hear the sound as if it's next to their ears.
					// EmitSound(clients, numClients, sample, entity, channel, level, (volume == SNDVOL_NORMAL) ? SND_NOFLAGS : SND_CHANGEVOL, volume);
					return Plugin_Stop;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

int FindRadioBySample(char [] sample)
{
	int r = -1;
	for (int i = 0; i < sizeof(g_radioSounds); i++)
	{
		if(StrContains(sample, g_radioSounds[i]) != -1){
			r = i;
			break;
		}
	}
	return r;
}

int FindModelIDByName(char [] model)
{
	int r = -1;
	for (int i = 0; i < modelcount; i++)
	{
		if(StrContains(model, g_model[i]) != -1) 
		{
			r = i;
			break;
		}
	}
	return r;
}

void LoadRadio()
{
	char Configfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/kento_radio.cfg");
	
	if (!FileExists(Configfile))
	{
		SetFailState("Fatal error: Unable to open configuration file \"%s\"!", Configfile);
		return;
	}
	
	KeyValues kv = CreateKeyValues("Radio");
	if (!kv.ImportFromFile(Configfile) || !kv.GotoFirstSubKey())
	{
		delete kv;
		SetFailState("Fatal error: Unable to read configuration file \"%s\"!", Configfile);
		return;
	}
	
	char model[512], file[512];
	modelcount = 0;
	do
	{
		if (modelcount >= sizeof(g_model))
		{
			LogError("Too many radio models in \"%s\". Limit: %d", Configfile, sizeof(g_model));
			break;
		}

		kv.GetSectionName(model, sizeof(model));
		strcopy(g_model[modelcount], sizeof(g_model[]), model);
		
		for (int i = 0; i < sizeof(g_radioSounds); i++)
		{
			g_radioFiles[modelcount][i][0] = '\0';
			kv.GetString(g_radioSounds[i], file, sizeof(file), "");
			if (file[0] == '\0')
				continue;

			char filepath[PLATFORM_MAX_PATH];
			if (strlen(file) + sizeof("sound/") > sizeof(filepath))
			{
				LogError("Radio sound path is too long for model \"%s\", sample \"%s\".", model, g_radioSounds[i]);
				continue;
			}

			PrecacheSound(file);
			Format(filepath, sizeof(filepath), "sound/%s", file);
			AddFileToDownloadsTable(filepath);

			char soundpath[PLATFORM_MAX_PATH];
			Format(soundpath, sizeof(soundpath), "*/%s", file);
			FakePrecacheSound(soundpath);
			strcopy(g_radioFiles[modelcount][i], sizeof(g_radioFiles[][]), file);
		}
		modelcount++;
	} while (kv.GotoNextKey());
	
	delete kv;
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

stock int FindIndex(int[] array, int length, int item)
{
	for (int i = 0; i < length; i++)
	{
		if (array[i] == item)
		{
			return i;
		}
	}
	return -1;
}

bool ArrayDeleteItem(int[] array, int length, int item)
{
	int index = FindIndex(array, length, item);
	if (index == -1)
	{
		return false;
	}
	else
	{
		int lastIndex = length - 1;
		if (lastIndex == index)
		{
			array[index] = 0;
		}
		else
		{
			for (int i = index + 1; i < length; i++)
			{
				array[i - 1] = array[i];
			}
		}
		return true;
	}
}

// https://wiki.alliedmods.net/Csgo_quirks
stock void FakePrecacheSound(const char[] szPath)
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}

public Action Command_Model(int client, int args){
	PrintToConsole(client, "Models: %d", modelcount);
	for (int i = 0; i < modelcount; i++)
	{
		PrintToConsole(client, "%d - %s", i, g_model[i]);
	}
	return Plugin_Handled;
}


public Action SendAudioNew(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char sBuffer[128];
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadString(msg, sBuffer, sizeof(sBuffer));
	
	ReplaceString(sBuffer, sizeof(sBuffer), "dio.", "", false);
	// PrintToServer("声音内容old： %s", sBuffer);
	
	if(StrEqual(sBuffer, "moveout") || StrEqual(sBuffer, "locknload") || StrEqual(sBuffer, "go") || StrEqual(sBuffer, "letsgo"))
	{
		if(playersNum > 0)
		{
			if (IsValidClient(players[0]) && GetClientTeam(players[0]) == CS_TEAM_T)
			{
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}


public void RoundStart_Radio(Event event, const char[] name, bool dontBroadcast)
{
	g_RoundGeneration++;
}

public void RoundEnd_Radio(Event event, const char[] name, bool dontBroadcast)
{
	int winner = event.GetInt("winner");
	if (winner != CS_TEAM_T && winner != CS_TEAM_CT)
		return;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client))
			continue;

		StopSound(client, -2, winner == CS_TEAM_T ? "radio/terwin.wav" : "radio/ctwin.wav");
		DataPack pack;
		if (CreateDataTimer(0.5, StopRoundEndSound, pack, TIMER_FLAG_NO_MAPCHANGE) != null)
		{
			pack.WriteCell(g_RoundGeneration);
			pack.WriteCell(GetClientSerial(client));
			pack.WriteCell(winner == CS_TEAM_T && GetClientTeam(client) != CS_TEAM_T);
		}
		else
			delete pack;
	}
}

public void StopRoundEndSound(Handle timer, DataPack pack)
{
	pack.Reset();
	if (pack.ReadCell() != g_RoundGeneration)
		return;

	int client = GetClientFromSerial(pack.ReadCell());
	if (IsValidClient(client))
	{
		bool stopTerroristSound = pack.ReadCell() != 0;
		EmitSoundToClient(client, stopTerroristSound ? "radio/terwin.wav" : "radio/ctwin.wav", client, SNDCHAN_VOICE, _, SND_STOP);
	}
}
