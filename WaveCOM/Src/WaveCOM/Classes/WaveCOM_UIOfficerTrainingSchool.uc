class WaveCOM_UIOfficerTrainingSchool extends UIOfficerTrainingSchool;

function bool OnUnlockOption(int iOption)
{
	local bool result;
	local XComGameState_Unit UnitState;
	local XComGameState NewGameState;
	local XComGameState_Effect EffectState;
	local StateObjectReference AbilityReference;
	local XComGameState_Player XComPlayer;
	local XComGameState_BattleData BattleData;
	result = super.OnUnlockOption(iOption);

	if (result)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update OTS Entries");

		BattleData = XComGameState_BattleData( `XCOMHISTORY.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
		XComPlayer = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(BattleData.PlayerTurnOrder[0].ObjectID));
		XComPlayer = XComGameState_Player(NewGameState.CreateStateObject(class'XComGameState_Player', XComPlayer.ObjectID));
		XComPlayer.SoldierUnlockTemplates = XComHQ.SoldierUnlockTemplates;
		NewGameState.AddStateObject(XComPlayer);

		`XEVENTMGR.TriggerEvent('ItemConstructionCompleted',,, NewGameState);

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if( UnitState.GetTeam() == eTeam_XCom && UnitState.IsAlive() && XComHQ.Squad.Find('ObjectID', UnitState.GetReference().ObjectID) != INDEX_NONE && !UnitState.bRemovedFromPlay)
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clean Unit State");
				UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				NewGameState.AddStateObject(UnitState);
				`log("Cleaning and readding Abilities");
				foreach UnitState.Abilities(AbilityReference)
				{
					NewGameState.RemoveStateObject(AbilityReference.ObjectID);
				}

				while (UnitState.AppliedEffectNames.Length > 0)
				{
					EffectState = XComGameState_Effect( `XCOMHISTORY.GetGameStateForObjectID( UnitState.AppliedEffects[ 0 ].ObjectID ) );
					if (EffectState != None)
					{
						EffectState.GetX2Effect().UnitEndedTacticalPlay(EffectState, UnitState);
					}
					EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
				}

				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			
				class'WaveCOM_UIArmory_FieldLoadout'.static.UpdateUnit(UnitState.GetReference().ObjectID);
			}
		}
	}

	return result;
}