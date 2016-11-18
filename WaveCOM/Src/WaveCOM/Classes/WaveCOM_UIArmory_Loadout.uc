// This is an Unreal Script

class WaveCOM_UIArmory_Loadout extends UIArmory_Loadout;

simulated function PopulateData()
{
	UpdateEquippedList();
	UpdateLockerList();
	ChangeActiveList(EquippedList, true);
}

simulated function bool EquipItem(UIArmory_LoadoutItem Item)
{
	local StateObjectReference PrevItemRef, NewItemRef;
	local XComGameState_Item PrevItem, NewItem;
	local bool CanEquip, EquipSucceeded, AddToFront;
	local XComGameState_HeadquartersXCom XComHQ;
	local XGWeapon Weapon;
	local XGItem ItemVisualizer;
	local array<XComGameState_Item> PrevUtilityItems;
	local XComGameState_Unit UpdatedUnit;
	local XComGameState UpdatedState;

	UpdatedState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Equip Item");
	UpdatedUnit = XComGameState_Unit(UpdatedState.CreateStateObject(class'XComGameState_Unit', GetUnit().ObjectID));
	UpdatedState.AddStateObject(UpdatedUnit);
	
	PrevUtilityItems = class'UIUtilities_Strategy'.static.GetEquippedUtilityItems(UpdatedUnit, UpdatedState);

	NewItemRef = Item.ItemRef;
	PrevItemRef = UIArmory_LoadoutItem(EquippedList.GetSelectedItem()).ItemRef;
	PrevItem = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(PrevItemRef.ObjectID));

	if(PrevItem != none)
	{
		PrevItem = XComGameState_Item(UpdatedState.CreateStateObject(class'XComGameState_Item', PrevItem.ObjectID));
		UpdatedState.AddStateObject(PrevItem);
	}

	foreach UpdatedState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}

	if(XComHQ == none)
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(UpdatedState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		UpdatedState.AddStateObject(XComHQ);
	}

	// Attempt to remove previously equipped primary or secondary weapons - NOT WORKING, TODO FIX ME
	if( PrevItem != none && 
		X2WeaponTemplate(PrevItem.GetMyTemplate()) != none && 
		X2WeaponTemplate(PrevItem.GetMyTemplate()).InventorySlot == eInvSlot_PrimaryWeapon || 
		X2WeaponTemplate(PrevItem.GetMyTemplate()).InventorySlot == eInvSlot_SecondaryWeapon)
	{
		Weapon = XGWeapon(PrevItem.GetVisualizer());
		// Weapon must be graphically detach, otherwise destroying it leaves a NULL component attached at that socket

		Weapon.Destroy();
	}

	CanEquip = ((PrevItem == none || UpdatedUnit.RemoveItemFromInventory(PrevItem, UpdatedState)) && UpdatedUnit.CanAddItemToInventory(Item.ItemTemplate, GetSelectedSlot(), UpdatedState));

	if(CanEquip)
	{
		GetItemFromInventory(UpdatedState, NewItemRef, NewItem);
		NewItem = XComGameState_Item(UpdatedState.CreateStateObject(class'XComGameState_Item', NewItem.ObjectID));
		UpdatedState.AddStateObject(NewItem);

		// Fix for TTP 473, preserve the order of Utility items
		if(PrevUtilityItems.Length > 0)
		{
			AddToFront = PrevItemRef.ObjectID == PrevUtilityItems[0].ObjectID;
		}
		
		EquipSucceeded = UpdatedUnit.AddItemToInventory(NewItem, GetSelectedSlot(), UpdatedState, AddToFront);

		if( EquipSucceeded )
		{
			if( PrevItem != none )
			{
				XComHQ.PutItemInInventory(UpdatedState, PrevItem);
				ItemVisualizer = XGItem(`XCOMHISTORY.GetVisualizer(PrevItem.ObjectID));
				ItemVisualizer.Destroy();
				`XCOMHISTORY.SetVisualizer(PrevItem.ObjectID, none);
			}

			if(class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M5_EquipMedikit') == eObjectiveState_InProgress &&
			   NewItem.GetMyTemplateName() == class'UIInventory_BuildItems'.default.TutorialBuildItem)
			{
				`XEVENTMGR.TriggerEvent('TutorialItemEquipped', , , UpdatedState);
				bTutorialJumpOut = true;
			}
		}
		else
		{
			if(PrevItem != none)
			{
				UpdatedUnit.AddItemToInventory(PrevItem, GetSelectedSlot(), UpdatedState);
			}

			XComHQ.PutItemInInventory(UpdatedState, NewItem);
			ItemVisualizer = XGItem(`XCOMHISTORY.GetVisualizer(NewItem.ObjectID));
			ItemVisualizer.Destroy();
			`XCOMHISTORY.SetVisualizer(NewItem.ObjectID, none);
		}
	}

	UpdatedUnit.ValidateLoadout(UpdatedState);
	`XCOMGAME.GameRuleset.SubmitGameState(UpdatedState);

	if( EquipSucceeded && X2EquipmentTemplate(Item.ItemTemplate) != none)
	{
		if(X2EquipmentTemplate(Item.ItemTemplate).EquipSound != "")
		{
			`XSTRATEGYSOUNDMGR.PlaySoundEvent(X2EquipmentTemplate(Item.ItemTemplate).EquipSound);
		}

		// Removed Equipment narrative as it could cause problems outside of the avenger, besides the old code will ensure crashes when equiping items from alien hunters DLC
	}

	return EquipSucceeded;
}

simulated function PrevSoldier()
{
	// Do not switch soldiers in this screen
}

simulated function NextSoldier()
{
	// Do not switch soldiers in this screen
}

simulated function LoadSoldierEquipment()
{
}