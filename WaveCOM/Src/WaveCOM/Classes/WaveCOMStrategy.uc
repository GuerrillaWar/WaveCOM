// This is an Unreal Script

class WaveCOMStrategy extends XGStrategy config(WaveCOM);
var XComGameState_MissionSite WaveCOMMissionSite;

var const config int WaveCOMStartingSupplies;

function LoadGame()
{
	`STRATEGYRULES.StartNewGame();
	GoToState('WaveCOMLoadingGame');
}

function TransferFromTactical()
{
	`STRATEGYRULES.StartNewGame();
	GoToState('WaveCOMStartingFromTactical');
}

state WaveCOMStartingFromTactical
{
Begin:		
	`HQPRES.UIEnterStrategyMap();
		
	// Movie will have already played so jump to player stats screen
	`HQPRES.UIYouWin();
}

state WaveCOMLoadingGame
{
Begin:
	PrepareTacticalBattle(WaveCOMMissionSite.ObjectID);
	LaunchTacticalBattle(WaveCOMMissionSite.ObjectID);
}

state Initing
{
Begin:
	
	while( `HQPRES.IsBusy() )
		Sleep( 0 );
	if( `XCOMHISTORY.GetNumGameStates() == 1 )
	{	
		// New Game
		StartWaveCOM();
	}
	else
	{
		// Loaded game, since there are no strategy save the code shouldn't reach here, but if it did, we need to handle things
		if(m_bLoadedFromSave)
		{
			// Somehow we loaded to strategy side. Give us a new WaveCOM mission
			LoadGame();
		}
		else
		{
			// We probably evac'd. End the Game.
			TransferFromTactical();
		}
	}
}

function StartWaveCOM()
{
	`log("Init WaveCOMHQ");
	`STRATEGYRULES.StartNewGame();
	GoToState('StartingWaveCOM');	
}

state StartingWaveCOM
{

	function SetupBaseResources()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;

		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SetupBase HQ");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);

		XComHQ.bDontShowSetupMovies = true;
		XComHQ.AddResource(NewGameState, 'Supplies', (WaveCOMStartingSupplies - XComHQ.GetSupplies()));
		XComHQ.AddResource(NewGameState, 'Intel', (0 - XComHQ.GetIntel())); // Reset to 0 intel
		XComHQ.AddResource(NewGameState, 'AlienAlloy', (10000 - XComHQ.GetAlienAlloys()));
		XComHQ.AddResource(NewGameState, 'EleriumDust', (10000 - XComHQ.GetEleriumDust()));

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	function OpenBlackMarket()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_BlackMarket Market;

		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Open Black Market");
		Market = XComGameState_BlackMarket(History.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));

		Market.OpenBlackMarket(NewGameState);

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	function AddDebugResources()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;

		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SetupBase HQ");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
		XComHQ.AddResource(NewGameState, 'Supplies', (20000 - XComHQ.GetSupplies()));

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	function RemoveStartingMission()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_MissionSite MissionState;

		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("DEBUG Remove Starting Mission");

		foreach History.IterateByClassType(class'XComGameState_MissionSite', MissionState)
		{
			if(MissionState.GetMissionSource().bStart)
			{
				NewGameState.RemoveStateObject(MissionState.ObjectID);
			}
		}

		// when removing the first mission, we still have to complete the objective for having completed the first mission

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	function DebugStuff()
	{
		RemoveStartingMission();
	}

	function InitSoldiers()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;
		local XComGameState_Unit UnitState;
		local XComOnlineProfileSettings ProfileSettings;
		local int idx;

		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("DEBUG Init Soldiers");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);

		ProfileSettings = `XPROFILESETTINGS;
		
		for(idx = 0; idx < 30; idx++)
		{
			UnitState = `CHARACTERPOOLMGR.CreateCharacter(NewGameState, ProfileSettings.Data.m_eCharPoolUsage);
			NewGameState.AddStateObject(UnitState);
			UnitState.ApplyInventoryLoadout(NewGameState);
			UnitState.SetHQLocation(eSoldierLoc_Barracks);

			XComHQ.AddToCrew(NewGameState, UnitState);
		}

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	function InitFacilities()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;
		local X2StrategyElementTemplateManager StratMgr;
		local X2FacilityTemplate FacilityTemplate;
		local array<X2FacilityTemplate> FacilityTemplates;
		local array<StateObjectReference> FacilityRefs;
		local XComGameState_FacilityXCom FacilityState;
		local XComGameState_HeadquartersRoom RoomState;
		local int idx;

		StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("DEBUG Init Facilities");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);

		for(idx = 0; idx < default.DEBUG_StartingFacilities.Length; idx++)
		{
			foreach History.IterateByClassType(class'XComGameState_HeadquartersRoom', RoomState)
			{
				if(RoomState.MapIndex == (default.DEBUG_FacilityIndex + idx))
				{
					FacilityTemplate = X2FacilityTemplate(StratMgr.FindStrategyElementTemplate(default.DEBUG_StartingFacilities[idx]));
					if(FacilityTemplate != none)
					{
						FacilityTemplates.AddItem(FacilityTemplate);
						RoomState = XComGameState_HeadquartersRoom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersRoom', RoomState.ObjectID));
						NewGameState.AddStateObject(RoomState);
						RoomState.ConstructionBlocked = false;
						RoomState.SpecialFeature = '';
						RoomState.Locked = false;
						XComHQ.UnlockAdjacentRooms(NewGameState, RoomState);
						
						FacilityState = FacilityTemplate.CreateInstanceFromTemplate(NewGameState);
						NewGameState.AddStateObject(FacilityState);
						FacilityRefs.AddItem(FacilityState.GetReference());
						FacilityState.Room = RoomState.GetReference();
						FacilityState.ConstructionDateTime = GetGameTime();
						
						RoomState.Facility = FacilityState.GetReference();
						XComHQ.Facilities.AddItem(FacilityState.GetReference());
					}
				}
			}
		}

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		for(idx = 0; idx < FacilityTemplates.Length; idx++)
		{
			if(FacilityTemplates[idx].OnFacilityBuiltFn != none)
			{
				FacilityTemplates[idx].OnFacilityBuiltFn(FacilityRefs[idx]);
			}
		}
	}
	
	function SpawnBaseMission() {

		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;
		local XComGameState_MissionSite MissionState;
		local X2MissionSourceTemplate MissionSource;
		local XComGameState_WorldRegion RegionState;
		local XComGameState_Reward RewardState;
		local array<XComGameState_Reward> MissionRewards;
		local X2RewardTemplate RewardTemplate;
		local X2StrategyElementTemplateManager StratMgr;
		local name MissionSourceName, MissionRewardName;

		MissionSourceName = 'MissionSource_WaveCOM';
		MissionRewardName = 'Reward_None';
	
		History = `XCOMHISTORY;
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(XComHQ.StartingRegion.ObjectID));
		StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
		MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate(MissionSourceName));
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate(MissionRewardName));

		if(MissionSource == none || RewardTemplate == none)
		{
			return;
		}

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: Spawn Mission");
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		NewGameState.AddStateObject(RewardState);
		RewardState.GenerateReward(NewGameState, , RegionState.GetReference());
		MissionRewards.AddItem(RewardState);

		MissionState = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite'));
		WaveCOMMissionSite = MissionState;
		NewGameState.AddStateObject(MissionState);
		MissionState.BuildMission(MissionSource, RegionState.GetRandom2DLocationInRegion(), RegionState.GetReference(), MissionRewards);



		if(NewGameState.GetNumGameStateObjects() > 0)
		{
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}


	function GiveScientist(optional int SkillLevel = 5, optional string UnitName)
	{
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;
		local XComGameStateHistory History;
		local XComGameState_Unit UnitState;
		local CharacterPoolManager CharMgr;

		History = `XCOMHISTORY;
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Give Scientist Cheat");

		CharMgr = `CHARACTERPOOLMGR;

		if(UnitName != "")
		{
			UnitState = CharMgr.CreateCharacter(NewGameState, eCPSM_PoolOnly, 'Scientist', , UnitName);
		}
		else
		{
			UnitState = CharMgr.CreateCharacter(NewGameState, eCPSM_Mixed, 'Scientist');
		}
	
		UnitState.SetSkillLevel(SkillLevel);
		NewGameState.AddStateObject(UnitState);

		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
		XComHQ.AddToCrew(NewGameState, UnitState);
		XComHQ.HandlePowerOrStaffingChange(NewGameState);

		if( NewGameState.GetNumGameStateObjects() > 0 )
		{
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}

		
	function GiveEngineer(optional int SkillLevel = 5, optional string UnitName)
	{
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;
		local XComGameStateHistory History;
		local XComGameState_Unit UnitState;
		local CharacterPoolManager CharMgr;

		History = `XCOMHISTORY;
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Give Engineer Cheat");

		CharMgr = `CHARACTERPOOLMGR;

		if(UnitName != "")
		{
			UnitState = CharMgr.CreateCharacter(NewGameState, eCPSM_PoolOnly, 'Engineer', , UnitName);
		}
		else
		{
			UnitState = CharMgr.CreateCharacter(NewGameState, eCPSM_Mixed, 'Engineer');
		}

		UnitState.SetSkillLevel(SkillLevel);
		NewGameState.AddStateObject(UnitState);

		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
		XComHQ.AddToCrew(NewGameState, UnitState);
		XComHQ.HandlePowerOrStaffingChange(NewGameState);

		if(NewGameState.GetNumGameStateObjects() > 0)
		{
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
		else
		{
			History.CleanupPendingGameState(NewGameState);
		}
	}


	
	function NonCheatDebugStuff()
	{
	}

Begin:
	`STRATEGYRULES.GameTime = GetGameTime();
	m_kGeoscape.Init();
	
	while(!GetGeoscape().m_kBase.MinimumAvengerStreamedInAndVisible())
	{
		Sleep(0);
	}

		
	NewGameEventHook();

	class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().ClientSetCameraFade(true, MakeColor(0, 0, 0), vect2d(0, 1), 0.0);

	SetupBaseResources();

	if (m_bDebugStart)
	{
		AddDebugResources();
	}

	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveEngineer();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	GiveScientist();
	InitSoldiers();
	InitFacilities();

	OpenBlackMarket();


	while(`HQPRES.IsBusy())
	{
		Sleep(0);
	}
		
	`ONLINEEVENTMGR.ResetAchievementState();

	GetGeoscape().m_kBase.StreamInBaseRooms(false);

	while(!GetGeoscape().m_kBase.MinimumAvengerStreamedInAndVisible())
	{
		Sleep(0);
	}
		
	WorldInfo.MyLocalEnvMapManager.SetEnableCaptures(true);

	Sleep(1.0f); //We don't want to populate the base rooms while capturing the environment, as it is very demanding on the games resources

	GetGeoscape().m_kBase.m_kCrewMgr.PopulateBaseRoomsWithCrew();
	GetGeoscape().m_kBase.SetAvengerVisibility(true);

	SpawnBaseMission();
	GetGeoscape().Pause();
	PrepareTacticalBattle(WaveCOMMissionSite.ObjectID);
	LaunchTacticalBattle(WaveCOMMissionSite.ObjectID);

}