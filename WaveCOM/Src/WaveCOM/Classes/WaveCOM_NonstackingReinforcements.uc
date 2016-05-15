class WaveCOM_NonstackingReinforcements extends XComGameState_AIReinforcementSpawner;

static function InitiateReinforcements(
	Name EncounterID, 
	optional int OverrideCountdown, 
	optional bool OverrideTargetLocation,
	optional const out Vector TargetLocationOverride,
	optional int IdealSpawnTilesOffset,
	optional XComGameState IncomingGameState,
	optional bool InKismetInitiatedReinforcements)
{
	local WaveCOM_NonstackingReinforcements NewAIReinforcementSpawnerState, ExistingSpawnerState;
	local XComGameState NewGameState;
	local XComTacticalMissionManager MissionManager;
	local ConfigurableEncounter Encounter;
	local XComAISpawnManager SpawnManager;
	local Vector DesiredSpawnLocation;

	local bool ReinforcementsCleared;
	local int TileOffset;

	SpawnManager = `SPAWNMGR;

	MissionManager = `TACTICALMISSIONMGR;
	MissionManager.GetConfigurableEncounter(EncounterID, Encounter);

	if (IncomingGameState == none)
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating Reinforcement Spawner");
	else
		NewGameState = IncomingGameState;

	// Update AIPlayerData with CallReinforcements data.
	NewAIReinforcementSpawnerState = WaveCOM_NonstackingReinforcements(NewGameState.CreateStateObject(class'WaveCOM_NonstackingReinforcements'));
	NewAIReinforcementSpawnerState.SpawnInfo.EncounterID = EncounterID;

	if( OverrideCountdown > 0 )
	{
		NewAIReinforcementSpawnerState.Countdown = OverrideCountdown;
	}
	else
	{
		NewAIReinforcementSpawnerState.Countdown = Encounter.ReinforcementCountdown;
	}

	if( OverrideTargetLocation )
	{
		DesiredSpawnLocation = TargetLocationOverride;
	}
	else
	{
		DesiredSpawnLocation = SpawnManager.GetCurrentXComLocation();
	}

	NewAIReinforcementSpawnerState.SpawnInfo.SpawnLocation = SpawnManager.SelectReinforcementsLocation(NewAIReinforcementSpawnerState, DesiredSpawnLocation, IdealSpawnTilesOffset, Encounter.bSpawnViaPsiGate);

	ReinforcementsCleared = false;
	TileOffset = 0;

	NewGameState.AddStateObject(NewAIReinforcementSpawnerState);

	while (!ReinforcementsCleared)
	{
		if (TileOffset > 15)
		{
			// Max tries
			//Discard gamestate and return
			if (IncomingGameState == none)
				`XCOMHISTORY.CleanupPendingGameState(NewGameState);
			return;
		}
		ReinforcementsCleared = true;
		foreach `XCOMHISTORY.IterateByClassType(class'WaveCOM_NonstackingReinforcements', ExistingSpawnerState)
		{
			// Must not be same reinforcements object and must be pending for reinforcements
			if (ExistingSpawnerState.ObjectID != NewAIReinforcementSpawnerState.ObjectID && ExistingSpawnerState.Countdown > 0)
			{
				if (NewAIReinforcementSpawnerState.SpawnInfo.SpawnLocation == ExistingSpawnerState.SpawnInfo.SpawnLocation)
				{
					ReinforcementsCleared = false;
					// Move reinforcements away and reroll
					TileOffset++;
					NewAIReinforcementSpawnerState.SpawnInfo.SpawnLocation = SpawnManager.SelectReinforcementsLocation(NewAIReinforcementSpawnerState, DesiredSpawnLocation, IdealSpawnTilesOffset + TileOffset, Encounter.bSpawnViaPsiGate);
					break;
				}
			}
		}
	}

	NewAIReinforcementSpawnerState.bKismetInitiatedReinforcements = InKismetInitiatedReinforcements;

	if (IncomingGameState == none)
		`TACTICALRULES.SubmitGameState(NewGameState);
}