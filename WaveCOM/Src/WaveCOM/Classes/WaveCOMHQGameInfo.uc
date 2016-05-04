// This is an Unreal Script

class WaveCOMHQGameInfo extends XComHeadquartersGame;

event InitGame( string Options, out string ErrorMessage )
{
	local string InOpt; 

	super.InitGame(Options, ErrorMessage);
	m_strSaveFile = ParseOption(Options, "SaveFile");

	`log("WAVECOMHQ IN DA HOUSE");

	InOpt = ParseOption(Options, "DebugStrategyFromShell");
	if (InOpt != "")
	{
		m_bDebugStrategyFromShell = true;
		`log("+++++ DEBUG STRATEGY activated from shell +++++");
	}
	
	InOpt = ParseOption(Options, "ControlledStartFromShell");
	if (InOpt != "")
	{
		m_bControlledStartFromShell = true;
		`log("+++++ CONTROLLED START activated from shell +++++");
	}	
}