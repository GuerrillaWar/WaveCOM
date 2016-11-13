class XComMissionLogic_Listener extends XComGameState_BaseObject config(MissionLogic);

struct MissionLogicBinding
{
	var string MissionType;
	var string MissionLogicClass;
};

var const config array<MissionLogicBinding> arrMissionLogicBindings;

function RegisterToListen()
{
	local Object ThisObj;
	ThisObj = self;

	`log("XComMissionLogic :: TacticalEventListener Loaded");
	`XEVENTMGR.RegisterForEvent(ThisObj, 'OnTacticalBeginPlay', LoadRelevantMissionLogic, ELD_Immediate, , , true);
}

function EventListenerReturn LoadRelevantMissionLogic(Object EventData, Object EventSource, XComGameState NewGameState, name EventID)
{
	local XComGameState_BattleData BattleData;
	local XComGameState_MissionLogic MissionLogic;
	local MissionLogicBinding LogicBinding;
	local class<XComGameState_MissionLogic> MissionLogicClass;
	local string MissionType;
	`log("XComMissionLogic :: Start Loading Mission Logic");

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionType = BattleData.MapData.ActiveMission.sType;
	foreach arrMissionLogicBindings(LogicBinding)
	{

		if (LogicBinding.MissionType == MissionType || LogicBinding.MissionType == "__all__")
		{
			`log("XComMissionLogic :: Loading" @ LogicBinding.MissionLogicClass @ "for" @ LogicBinding.MissionType);
			MissionLogicClass = class<XComGameState_MissionLogic>(DynamicLoadObject(LogicBinding.MissionLogicClass, class'Class'));

			if (!X2TacticalGameRuleset(`XCOMGAME.GameRuleset).bLoadingSavedGame)
			{
				MissionLogic = XComGameState_MissionLogic(`XCOMHISTORY.GetSingleGameStateObjectForClass(MissionLogicClass));
				if (MissionLogic != none && !MissionLogic.bIsBeingTransferred)
				{
					// Discard any old mission logics
					`log("XComMissionLogic :: Old Mission Logic found, deleting");
					NewGameState.RemoveStateObject(MissionLogic.ObjectID);
					MissionLogic = none;
				}
				`log("XComMissionLogic :: Created mission logic " @ LogicBinding.MissionLogicClass);

				if (MissionLogic != none && MissionLogic.bIsBeingTransferred)
				{
					// Clear the flag so it gets transferred properly next time
					`log("XComMissionLogic :: Found transferring MissionLogic of same type, preserving...");
					MissionLogic = XComGameState_MissionLogic(NewGameState.CreateStateObject(MissionLogicClass, MissionLogic.ObjectID));
					MissionLogic.bIsBeingTransferred = false;
				}
				else
				{
					MissionLogic = XComGameState_MissionLogic(NewGameState.CreateStateObject(MissionLogicClass));
				}
				NewGameState.AddStateObject(MissionLogic);
				MissionLogic.SetupMissionStartState(NewGameState);
			}
			else
			{
				`log("XComMissionLogic :: Loaded single mission logic " @ LogicBinding.MissionLogicClass);
				MissionLogic = XComGameState_MissionLogic(`XCOMHISTORY.GetSingleGameStateObjectForClass(MissionLogicClass));
				NewGameState.AddStateObject(MissionLogic);
			}
			MissionLogic.RegisterEventHandlers();
		}
	}
	`log("XComMissionLogic :: Loaded Mission Logic");

	return ELR_NoInterrupt;
}