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
				MissionLogic = XComGameState_MissionLogic(NewGameState.CreateStateObject(MissionLogicClass));
				NewGameState.AddStateObject(MissionLogic);
				MissionLogic.SetupMissionStartState(NewGameState);
			}
			else
			{
				MissionLogic = XComGameState_MissionLogic(`XCOMHISTORY.GetSingleGameStateObjectForClass(MissionLogicClass));
				NewGameState.AddStateObject(MissionLogic);
			}
			MissionLogic.RegisterEventHandlers();
		}
	}
	`log("XComMissionLogic :: Loaded Mission Logic");
	return ELR_NoInterrupt;
}