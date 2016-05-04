
class WaveCOMMissionSource extends X2StrategyElement
	config(GameData);

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> MissionSources;

	MissionSources.AddItem(CreateWaveCOMTemplate());
	return MissionSources;
}

// AVENGER DEFENSE
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateWaveCOMTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_WaveCOM');
	Template.DifficultyValue = 3;
	Template.bSkipRewardsRecap = true;
	Template.CustomMusicSet = 'Tutorial';
	Template.CustomLoadingMovieName_Intro = "1080_LoadingScreen5.bk2";
	Template.bRequiresSkyRangerTravel = false;
	Template.OnSuccessFn = AvengerDefenseOnSuccess;
	Template.OnFailureFn = AvengerDefenseOnFailure;
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromTemplate;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;

	return Template;
}

function AvengerDefenseOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_UFO UFOState;
	local XComGameState_MissionSiteAvengerDefense AvengerDefense;

	AvengerDefense = XComGameState_MissionSiteAvengerDefense(MissionState);
	if (AvengerDefense != none)
	{
		UFOState = XComGameState_UFO(`XCOMHISTORY.GetGameStateForObjectID(AvengerDefense.AttackingUFO.ObjectID));
		UFOState.RemoveEntity(NewGameState);
	}

	GiveRewards(NewGameState, MissionState);
	MissionState.RemoveEntity(NewGameState);
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvengerDefenseCompleted');
}
function AvengerDefenseOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
}


// #######################################################################################
// -------------------- GENERIC FUNCTIONS ------------------------------------------------
// #######################################################################################
static function IncreaseForceLevel(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;

	if(MissionState.GetMissionSource().bIncreasesForceLevel)
	{
		History = `XCOMHISTORY;

		foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersAlien', AlienHQ)
		{
			break;
		}

		if(AlienHQ == none)
		{
			AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
			AlienHQ = XComGameState_HeadquartersAlien(NewGameState.CreateStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));
			NewGameState.AddStateObject(AlienHQ);
		}

		AlienHQ.IncreaseForceLevel();
	}
}
function GiveRewards(XComGameState NewGameState, XComGameState_MissionSite MissionState, optional array<int> ExcludeIndices)
{
	local XComGameStateHistory History;
	local XComGameState_Reward RewardState;
	local int idx;

	History = `XCOMHISTORY;

	// First Check if we need to exclude some rewards
	for(idx = 0; idx < MissionState.Rewards.Length; idx++)
	{
		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(MissionState.Rewards[idx].ObjectID));
		if(RewardState != none)
		{
			if(ExcludeIndices.Find(idx) != INDEX_NONE)
			{
				RewardState.CleanUpReward(NewGameState);
				NewGameState.RemoveStateObject(RewardState.ObjectID);
				MissionState.Rewards.Remove(idx, 1);
				idx--;
			}
		}
	}

	class'XComGameState_HeadquartersResistance'.static.SetRecapRewardString(NewGameState, MissionState.GetRewardAmountString());

	// @mnauta: set VIP rewards string is deprecated, leaving blank
	class'XComGameState_HeadquartersResistance'.static.SetVIPRewardString(NewGameState, "" /*REWARDS!*/);

	for(idx = 0; idx < MissionState.Rewards.Length; idx++)
	{
		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(MissionState.Rewards[idx].ObjectID));

		// Give rewards
		if(RewardState != none)
		{
			RewardState.GiveReward(NewGameState);
		}

		// Remove the reward state objects
		NewGameState.RemoveStateObject(RewardState.ObjectID);
	}

	MissionState.Rewards.Length = 0;
}

function TemporarilyUnlockMissionRegion(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_WorldRegion RegionState;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(MissionState.Region.ObjectID));

	if(RegionState == none)
	{
		RegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', MissionState.Region.ObjectID));
		NewGameState.AddStateObject(RegionState);
	}

	RegionState.Unlock(NewGameState);
}

function LoseContactWithMissionRegion(XComGameState NewGameState, XComGameState_MissionSite MissionState, bool bRecord)
{
	local XComGameState_WorldRegion RegionState;
	local XGParamTag ParamTag;
	local EResistanceLevelType OldResLevel;
	local int OldIncome, NewIncome, IncomeDelta;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(MissionState.Region.ObjectID));

	if (RegionState == none)
	{
		RegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', MissionState.Region.ObjectID));
		NewGameState.AddStateObject(RegionState);
	}

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	ParamTag.StrValue0 = RegionState.GetMyTemplate().DisplayName;
	OldResLevel = RegionState.ResistanceLevel;
	OldIncome = RegionState.GetSupplyDropReward();

	RegionState.SetResistanceLevel(NewGameState, eResLevel_Unlocked);
	
	NewIncome = RegionState.GetSupplyDropReward();
	IncomeDelta = NewIncome - OldIncome;

	if (bRecord)
	{
		if(RegionState.ResistanceLevel < OldResLevel)
		{
			class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strRegionLostContact), true);
		}

		if(IncomeDelta < 0)
		{
			ParamTag.StrValue0 = string(-IncomeDelta);
			class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strDecreasedSupplyIncome), true);
		}
	}
}

function ModifyRegionSupplyYield(XComGameState NewGameState, XComGameState_MissionSite MissionState, float DeltaYieldPercent, optional int DeltaFromLevelChange = 0, optional bool bRecord = true)
{
	local XComGameState_WorldRegion RegionState;
	local XGParamTag ParamTag;
	local int TotalDelta, OldIncome, NewIncome;

	if (DeltaYieldPercent != 1.0)
	{
		// Region gets permanent supply bonus
		RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(MissionState.Region.ObjectID));
		TotalDelta = DeltaFromLevelChange;
		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

		if (RegionState == none)
		{
			RegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', MissionState.Region.ObjectID));
			NewGameState.AddStateObject(RegionState);
		}
		
		OldIncome = RegionState.GetSupplyDropReward();
		RegionState.BaseSupplyDrop *= DeltaYieldPercent;

		if (RegionState.HaveMadeContact())
		{
			NewIncome = RegionState.GetSupplyDropReward();
			TotalDelta += (NewIncome - OldIncome);
		}
		
		if (bRecord)
		{
			if (DeltaYieldPercent < 1.0)
			{
				ParamTag.StrValue0 = RegionState.GetMyTemplate().DisplayName;
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strDecreasedRegionSupplyOutput), true);
				ParamTag.StrValue0 = string(-TotalDelta);
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strDecreasedSupplyIncome), true);
			}
			else
			{
				ParamTag.StrValue0 = RegionState.GetMyTemplate().DisplayName;
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strIncreasedRegionSupplyOutput), false);
				ParamTag.StrValue0 = string(TotalDelta);
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strIncreasedSupplyIncome), false);
			}
		}
	}
}

function ModifyContinentSupplyYield(XComGameState NewGameState, XComGameState_MissionSite MissionState, float DeltaYieldPercent, optional int DeltaFromLevelChange = 0, optional bool bRecord = true)
{
	local XComGameStateHistory History;
	local XComGameState_Continent ContinentState;
	local XComGameState_WorldRegion RegionState;
	local XGParamTag ParamTag;
	local int idx, TotalDelta, OldIncome, NewIncome;

	if(DeltaYieldPercent != 1.0)
	{
		// All Regions in continent get permanent supply bonus
		RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(MissionState.Region.ObjectID));
		TotalDelta = DeltaFromLevelChange;

		if(RegionState == none)
		{
			RegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', MissionState.Region.ObjectID));
			NewGameState.AddStateObject(RegionState);
		}

		History = `XCOMHISTORY;
		ContinentState = XComGameState_Continent(History.GetGameStateForObjectID(RegionState.Continent.ObjectID));

		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		
		
		for(idx = 0; idx < ContinentState.Regions.Length; idx++)
		{
			RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ContinentState.Regions[idx].ObjectID));

			if(RegionState == none)
			{
				RegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', ContinentState.Regions[idx].ObjectID));
				NewGameState.AddStateObject(RegionState);
			}

			OldIncome = RegionState.GetSupplyDropReward();
			RegionState.BaseSupplyDrop *= DeltaYieldPercent;

			if(RegionState.HaveMadeContact())
			{
				NewIncome = RegionState.GetSupplyDropReward();
				TotalDelta += (NewIncome - OldIncome);
			}
		}

		if(bRecord)
		{
			if(DeltaYieldPercent < 1.0)
			{
				ParamTag.StrValue0 = ContinentState.GetMyTemplate().DisplayName;
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strDecreasedContinentalSupplyOutput), true);
				ParamTag.StrValue0 = string(-TotalDelta);
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strDecreasedSupplyIncome), true);
			}
			else
			{
				ParamTag.StrValue0 = ContinentState.GetMyTemplate().DisplayName;
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strIncreasedContinentalSupplyOutput), false);
				ParamTag.StrValue0 = string(TotalDelta);
				class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strIncreasedSupplyIncome), false);
			}
		}
	}
}

function SpawnPointOfInterest(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_PointOfInterest POIState;
	local XComGameState_BlackMarket BlackMarketState;

	History = `XCOMHISTORY;
	BlackMarketState = XComGameState_BlackMarket(History.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));

	if (!BlackMarketState.ShowBlackMarket(NewGameState) && MissionState.POIToSpawn.ObjectID != 0)
	{
		POIState = XComGameState_PointOfInterest(History.GetGameStateForObjectID(MissionState.POIToSpawn.ObjectID));
		
		if (POIState != none)
		{
			POIState = XComGameState_PointOfInterest(NewGameState.CreateStateObject(class'XComGameState_PointOfInterest', POIState.ObjectID));
			NewGameState.AddStateObject(POIState);
			POIState.Spawn(NewGameState);
		}
	}
}

function SpawnUFO(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_UFO NewUFOState;

	// First get Alien HQ to check if a Golden Path UFO has spawned previously
	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersAlien', AlienHQ)
	{
		break;
	}

	if (AlienHQ == none)
	{
		AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
		AlienHQ = XComGameState_HeadquartersAlien(NewGameState.CreateStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));
		NewGameState.AddStateObject(AlienHQ);
	}

	if (!AlienHQ.bHasGoldenPathUFOAppeared && MissionState.bSpawnUFO)
	{
		AlienHQ.bHasGoldenPathUFOAppeared = true;

		NewUFOState = XComGameState_UFO(NewGameState.CreateStateObject(class'XComGameState_UFO'));
		NewUFOState.OnCreation(NewGameState, true);
		NewGameState.AddStateObject(NewUFOState);
	}
}

function int GetMissionDifficultyFromDoom(XComGameState_MissionSite MissionState)
{
	local int Difficulty;

	Difficulty = MissionState.GetMissionSource().DifficultyValue;

	Difficulty += (MissionState.Doom/2);

	Difficulty = Clamp(Difficulty, class'X2StrategyGameRulesetDataStructures'.default.MinMissionDifficulty, 5);

	return Difficulty;
}

function int GetMissionDifficultyFromTemplate(XComGameState_MissionSite MissionState)
{
	local int Difficulty;

	Difficulty = MissionState.GetMissionSource().DifficultyValue;

	Difficulty = Clamp(Difficulty, class'X2StrategyGameRulesetDataStructures'.default.MinMissionDifficulty,
					   class'X2StrategyGameRulesetDataStructures'.default.MaxMissionDifficulty);

	return Difficulty;
}

function int GetMissionDifficultyFromMonth(XComGameState_MissionSite MissionState)
{
	local TDateTime StartDate;
	local array<int> MonthlyDifficultyAdd;
	local int Difficulty, MonthDiff;

	class'X2StrategyGameRulesetDataStructures'.static.SetTime(StartDate, 0, 0, 0, class'X2StrategyGameRulesetDataStructures'.default.START_MONTH,
		class'X2StrategyGameRulesetDataStructures'.default.START_DAY, class'X2StrategyGameRulesetDataStructures'.default.START_YEAR);

	Difficulty = 1;
	MonthDiff = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInMonths(class'XComGameState_GeoscapeEntity'.static.GetCurrentTime(), StartDate);
	MonthlyDifficultyAdd = GetMonthlyDifficultyAdd();

	if(MonthDiff >= MonthlyDifficultyAdd.Length)
	{
		MonthDiff = MonthlyDifficultyAdd.Length - 1;
	}

	Difficulty += MonthlyDifficultyAdd[MonthDiff];

	Difficulty = Clamp(Difficulty, class'X2StrategyGameRulesetDataStructures'.default.MinMissionDifficulty,
						class'X2StrategyGameRulesetDataStructures'.default.MaxMissionDifficulty);

	return Difficulty;
}

function int GetCouncilMissionDifficulty(XComGameState_MissionSite MissionState)
{
	local int Difficulty;

	Difficulty = GetMissionDifficultyFromMonth(MissionState);
	if(MissionState.GeneratedMission.Mission.sType != "Extract")
	{
		Difficulty--;
	}

	Difficulty = Clamp(Difficulty, class'X2StrategyGameRulesetDataStructures'.default.MinMissionDifficulty,
					   class'X2StrategyGameRulesetDataStructures'.default.MaxMissionDifficulty);

	return Difficulty;
}

function StopMissionDarkEvent(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersAlien AlienHQ;

	AlienHQ = GetAndAddAlienHQ(NewGameState);

	class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, MissionState.GetDarkEvent().GetPostMissionText(true), false);
	AlienHQ.CancelDarkEvent(MissionState.DarkEvent);
}

function RemoveGPDoom(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersAlien AlienHQ;
	local int DoomToRemove;
	local XGParamTag ParamTag;
	local string DoomString;
	local XComGameState_MissionSite FortressMission;
	
	AlienHQ = GetAndAddAlienHQ(NewGameState);
	FortressMission = AlienHQ.GetFortressMission();

	// Remove Doom based on min/max amounts from mission
	DoomToRemove = MissionState.FixedDoomToRemove;
	DoomToRemove = Clamp(DoomToRemove, 0, FortressMission.Doom);

	if(DoomToRemove > 0)
	{
		DoomString = MissionState.GetMissionSource().DoomLabel;
		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		ParamTag.StrValue0 = string(DoomToRemove);
		
		if(DoomToRemove == 1)
		{
			DoomString @= `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strAvatarProgressReducedSingular);
		}
		else
		{
			DoomString @= `XEXPAND.ExpandString(class'UIRewardsRecap'.default.m_strAvatarProgressReducedPlural);
		}

		AlienHQ.RemoveDoomFromFortress(NewGameState, DoomToRemove, DoomString);

		if(MissionState.Source == 'MissionSource_Blacksite')
		{
			AlienHQ.PendingDoomEvent = 'BlacksiteDoomEvent';
		}
		else if(MissionState.Source == 'MissionSource_Forge')
		{
			AlienHQ.PendingDoomEvent = 'ForgeDoomEvent';
		}
		else if(MissionState.Source == 'MissionSource_PsiGate')
		{
			AlienHQ.PendingDoomEvent = 'PsiGateDoomEvent';
		}

		if(FortressMission.ShouldBeVisible())
		{
			class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, DoomString, false);
		}
	}

	if(FortressMission.ShouldBeVisible())
	{
		class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvatarProgressReduced', DoomToRemove);
	}
}

function RemoveIntelRewards(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local MissionIntelOption IntelOption;

	if (MissionState.PurchasedIntelOptions.Length > 0)
	{
		foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
		{
			break;
		}

		if (XComHQ == none)
		{
			XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
			XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
			NewGameState.AddStateObject(XComHQ);
		}

		foreach MissionState.PurchasedIntelOptions(IntelOption)
		{
			XComHQ.TacticalGameplayTags.RemoveItem(IntelOption.IntelRewardName);
		}
	}
}

function XComGameState_MissionCalendar GetMissionCalendar(XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_MissionCalendar CalendarState;

	foreach NewGameState.IterateByClassType(class'XComGameState_MissionCalendar', CalendarState)
	{
		break;
	}

	if(CalendarState == none)
	{
		History = `XCOMHISTORY;
		CalendarState = XComGameState_MissionCalendar(History.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));
		CalendarState = XComGameState_MissionCalendar(NewGameState.CreateStateObject(class'XComGameState_MissionCalendar', CalendarState.ObjectID));
		NewGameState.AddStateObject(CalendarState);
	}

	return CalendarState;
}

//---------------------------------------------------------------------------------------
function array<name> GetShuffledRewardDeck(array<RewardDeckEntry> ConfigRewards)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;
	local int ForceLevel, idx, i, iTemp, iRand;
	local array<name> UnshuffledRewards, ShuffledRewards;
	local name EntryName;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	ForceLevel = AlienHQ.GetForceLevel();

	// Add all applicable rewards to unshuffled deck
	for(idx = 0; idx < ConfigRewards.Length; idx++)
	{
		if(ConfigRewards[idx].ForceLevelGate <= ForceLevel)
		{
			for(i = 0; i < ConfigRewards[idx].Quantity; i++)
			{
				UnshuffledRewards.AddItem(ConfigRewards[idx].RewardName);
			}
		}
	}

	// Shuffle the deck
	iTemp = UnshuffledRewards.Length;
	for(idx = 0; idx < iTemp; idx++)
	{
		iRand = `SYNC_RAND(UnshuffledRewards.Length);
		EntryName = UnshuffledRewards[iRand];
		UnshuffledRewards.Remove(iRand, 1);
		ShuffledRewards.AddItem(EntryName);
	}

	return ShuffledRewards;
}

//---------------------------------------------------------------------------------------
function XComGameState_WorldRegion GetRandomContactedRegion()
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local array<XComGameState_WorldRegion> ValidRegions, AllRegions;

	History = `XCOMHISTORY;

		foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
			AllRegions.AddItem(RegionState);

			if(RegionState.ResistanceLevel >= eResLevel_Contact)
			{
				ValidRegions.AddItem(RegionState);
			}
		}

	if(ValidRegions.Length > 0)
	{
		return ValidRegions[`SYNC_RAND(ValidRegions.Length)];
	}

	return AllRegions[`SYNC_RAND(AllRegions.Length)];
}

//---------------------------------------------------------------------------------------
function array<StateObjectReference> GetGoldenPathMissionRegions()
{
	local XComGameStateHistory History;
	local XComGameState_MissionSite MissionState;
	local array<StateObjectReference> MissionRegions;

	History = `XCOMHISTORY;

		foreach History.IterateByClassType(class'XComGameState_MissionSite', MissionState)
	{
			if(MissionState.GetMissionSource().bGoldenPath && MissionState.Available)
			{
				MissionRegions.AddItem(MissionState.GetReference());
			}
		}

	return MissionRegions;
}

//---------------------------------------------------------------------------------------
function array<StateObjectReference> GetAlienFacilityMissionRegions()
{
	local XComGameStateHistory History;
	local XComGameState_MissionSite MissionState;
	local array<StateObjectReference> MissionRegions;

	History = `XCOMHISTORY;

		foreach History.IterateByClassType(class'XComGameState_MissionSite', MissionState)
	{
			if(MissionState.GetMissionSource().bAlienNetwork)
			{
				MissionRegions.AddItem(MissionState.GetReference());
			}
		}

	return MissionRegions;
}

//---------------------------------------------------------------------------------------
function XComGameState_HeadquartersAlien GetAndAddAlienHQ(XComGameState NewGameState)
{
	local XComGameState_HeadquartersAlien AlienHQ;

	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersAlien', AlienHQ)
	{
		break;
	}

	if(AlienHQ == none)
	{
		AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
		NewGameState.AddStateObject(AlienHQ);
	}

	return AlienHQ;
}

//---------------------------------------------------------------------------------------
function bool IsInStartingRegion(XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;

	History = `XCOMHISTORY;
	RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(MissionState.Region.ObjectID));

	return (RegionState != none && RegionState.IsStartingRegion());
}

//---------------------------------------------------------------------------------------
function bool OneStrategyObjectiveCompleted(XComGameState_BattleData BattleDataState)
{
	return (BattleDataState.OneStrategyObjectiveCompleted());
}

//---------------------------------------------------------------------------------------
function bool StrategyObjectivePlusSweepCompleted(XComGameState_BattleData BattleDataState)
{
	return (BattleDataState.OneStrategyObjectiveCompleted() && BattleDataState.AllTacticalObjectivesCompleted());
}

// #######################################################################################
// -------------------- DIFFICULTY HELPERS -----------------------------------------------
// #######################################################################################

//---------------------------------------------------------------------------------------



//---------------------------------------------------------------------------------------

function array<int> GetMonthlyDifficultyAdd()
{
	local array<int> Diffs;
	Diffs.AddItem(0);
	return Diffs;

}