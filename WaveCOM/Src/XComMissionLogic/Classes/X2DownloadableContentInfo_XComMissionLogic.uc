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
	local XComMissionLogic_Listener MissionListener;
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Loading Save Game Mission Logic Loader");
	MissionListener = XComMissionLogic_Listener(NewGameState.CreateStateObject(class'XComMissionLogic_Listener'));
	MissionListener.RegisterToListen();
	NewGameState.AddStateObject(MissionListener);
	MissionListener.RegisterToListen();

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	`log("XComMissionLogic :: OnLoadedSavedGame");
}

static event InstallNewCampaign(XComGameState StartState)
{
	local XComMissionLogic_Listener MissionListener;
	MissionListener = XComMissionLogic_Listener(StartState.CreateStateObject(class'XComMissionLogic_Listener'));
	MissionListener.RegisterToListen();
	StartState.AddStateObject(MissionListener);

	`log("XComMissionLogic :: InstallNewCampaign");
}
