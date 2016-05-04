// This is an Unreal Script

class WaveCOMStrategy extends XGStrategy config(WaveCOM);
var XComGameState_MissionSite WaveCOMMissionSite;

var const config int WaveCOMStartingSupplies;

state Initing
{
Begin:
	
	while( `HQPRES.IsBusy() )
		Sleep( 0 );
	
	StartWaveCOM();
}

function StartWaveCOM()
{
	`log("Init WaveCOMHQ");
	`STRATEGYRULES.StartNewGame();
	GoToState('StartingWaveCOM');	
}

state StartingWaveCOM
{
	function DebugInitHQ()
	{
		local XComGameStateHistory History;
		local XComGameState NewGameState;
		local XComGameState_HeadquartersXCom XComHQ;
		local XComGameState_Skyranger SkyrangerState;

		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("DEBUG Init HQ");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);

		XComHQ.bDontShowSetupMovies = true;
		XComHQ.AddResource(NewGameState, 'Supplies', (3000 - XComHQ.GetSupplies()));
		XComHQ.AddResource(NewGameState, 'Intel', (1000 - XComHQ.GetIntel()));
		XComHQ.AddResource(NewGameState, 'AlienAlloy', (10000 - XComHQ.GetAlienAlloys()));
		XComHQ.AddResource(NewGameState, 'EleriumDust', (10000 - XComHQ.GetEleriumDust()));

		// Dock Skyranger at HQ
		SkyrangerState = XComGameState_Skyranger(NewGameState.CreateStateObject(class'XComGameState_Skyranger', XComHQ.SkyrangerRef.ObjectID));
		NewGameState.AddStateObject(SkyrangerState);
		SkyrangerState.Location = XComHQ.Location;
		SkyrangerState.SourceLocation.X = SkyrangerState.Location.X;
		SkyrangerState.SourceLocation.Y = SkyrangerState.Location.Y;
		SkyrangerState.TargetEntity = XComHQ.GetReference();
		SkyrangerState.SquadOnBoard = false;

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

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
		XComHQ.AddResource(NewGameState, 'Intel', (1000 - XComHQ.GetIntel()));
		XComHQ.AddResource(NewGameState, 'AlienAlloy', (10000 - XComHQ.GetAlienAlloys()));
		XComHQ.AddResource(NewGameState, 'EleriumDust', (10000 - XComHQ.GetEleriumDust()));

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
		DebugInitHQ();
		RemoveStartingMission();

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
	
	// DEBUG STRATEGY
	if (m_bDebugStart)
	{
		DebugStuff();
	}

	SetupBaseResources();
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
	`HQPRES.UIAvengerFacilityMenu();
	`HQPC.GotoState('Headquarters');
	GetGeoscape().OnEnterMissionControl();
	GetGeoscape().Pause();
	PrepareTacticalBattle(WaveCOMMissionSite.ObjectID);
	`HQPRES.UISquadSelect(true/* No Cancel */);

}