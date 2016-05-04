// This is an Unreal Script
// i dont believe this can be overridden, so we did XComHeadquartersGame instead. Ignore this

class WaveCOMBaseGameInfo extends XComGameInfo;

// jboswell: This will change the GameInfo class based on the map we are about to load
static event class<GameInfo> SetGameType(string MapName, string Options, string Portal)
{
	local class<GameInfo>   GameInfoClass;
	local string            GameInfoClassName;

	local string            GameInfoClassToUse;

	GameInfoClassName = class'GameInfo'.static.ParseOption(Options, "Game");
	// 1) test MP game type before the map name tests just in case an MP map name contains one of the search strings -tsmith 
	if (InStr(GameInfoClassName, "XComMPTacticalGame", true, true) != INDEX_NONE)
	{
		GameInfoClassToUse = "XComGame.XComMPTacticalGame";
	}
	else if (InStr(GameInfoClassName, "X2MPLobbyGame", true, true) != INDEX_NONE)
	{
		GameInfoClassToUse = "XComGame.X2MPLobbyGame";
	}
	else if(InStr(GameInfoClassName, "MPShell", , true) != INDEX_NONE)
	{
		GameInfoClassToUse = "XComGame.XComMPShell";
	}
	
	// WaveCOMOverride
	else if(InStr(GameInfoClassName, "WaveCOMShell", , true) != INDEX_NONE)
	{
		GameInfoClassToUse = "WaveCOM.WaveCOMShell";
	}

	// 2) pick a gametype based on the filename of the map
	else if (InStr(MapName, "Shell", , true) != INDEX_NONE)
	{
		GameInfoClassToUse = "XComGame.XComShell";
	}
	else if (InStr(MapName, "Avenger_Root", , true) != INDEX_NONE || InStr(GameInfoClassName, "XComHeadquartersGame", true, true) != INDEX_NONE)
	{
		GameInfoClassToUse = "XComGame.XComHeadquartersGame";
	}
	else if (InStr(GameInfoClassName, "XComTacticalGameValidation", true, true) != INDEX_NONE)
	{
		GameInfoClassToUse = "XComGame.XComTacticalGameValidation";
	}
	else
	{
		GameInfoClassToUse = "XComGame.XComTacticalGame"; // likely it's a tactical map.
	}

	if (GameInfoClass == none)
	{
		GameInfoClass = class<GameInfo>(DynamicLoadObject(GameInfoClassToUse, class'Class'));
	}

	if (GameInfoClass != none)
	{
		return GameInfoClass;
	}
	else
	{
		`log("SetGameType: ERROR! failed loading requested gameinfo '" @ GameInfoClassToUse @ "', using default gameinfo.");
		return default.Class;
	}
}
