//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_MissionLogic.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_XComMissionLogic extends X2DownloadableContentInfo Config(Game);

static event OnPostTemplatesCreated()
{
	`log("XComMissionLogic :: Present And Correct");
}

static event OnLoadedSavedGame()
{	
}

static function RegisterMissionLogicListener()
{
	local XComMissionLogic_Listener MissionListener;
	local XComGameState NewGameState;

	`log("XComMissionLogic :: RegisterMissionLogicListener");

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Loading Save Game Mission Logic Loader");
	MissionListener = XComMissionLogic_Listener(NewGameState.CreateStateObject(class'XComMissionLogic_Listener'));
	NewGameState.AddStateObject(MissionListener);
	MissionListener.RegisterToListen();

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

static event InstallNewCampaign(XComGameState StartState)
{
	local XComMissionLogic_Listener MissionListener;
	local XComGameState_CampaignSettings CampaignSettings;
	MissionListener = XComMissionLogic_Listener(StartState.CreateStateObject(class'XComMissionLogic_Listener'));
	MissionListener.RegisterToListen();
	StartState.AddStateObject(MissionListener);

	`log("XComMissionLogic :: InstallNewCampaign");


	// Removing all nerative content, so techs can be accessed from the mission
	foreach StartState.IterateByClassType(class'XComGameState_CampaignSettings', CampaignSettings)
	{
		break;
	}
	CampaignSettings.RemoveAllOptionalNarrativeDLC();
}
