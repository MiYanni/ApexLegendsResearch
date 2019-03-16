global function ShCharacterCosmetics_LevelInit

global function Loadout_CharacterSkin
global function Loadout_CharacterExecution
global function Loadout_CharacterIntroQuip
global function Loadout_CharacterKillQuip
#if SERVER || CLIENT
global function PlayIntroQuipThread
global function PlayKillQuipThread
#endif
global function CharacterExecution_GetCharacterFlavor
global function CharacterExecution_GetAttackerAnimSeq
global function CharacterExecution_GetVictimAnimSeq
global function CharacterExecution_GetExecutionVideo
global function CharacterExecution_GetAttackerPreviewAnimSeq
global function CharacterExecution_GetVictimPreviewAnimSeq
global function CharacterExecution_GetSortOrdinal
global function CharacterSkin_GetCharacterFlavor
global function CharacterSkin_GetBodyModel
global function CharacterSkin_GetArmsModel
global function CharacterSkin_GetSkinName
global function CharacterSkin_GetCamoIndex
global function CharacterSkin_GetSortOrdinal
global function CharacterKillQuip_GetCharacterFlavor
global function CharacterKillQuip_GetAttackerConversationName
global function CharacterKillQuip_GetAttackerStingSoundEvent
global function CharacterKillQuip_GetVictimVoiceSoundEvent
global function CharacterKillQuip_GetVictimStingSoundEvent
global function CharacterKillQuip_GetStingSound
global function CharacterKillQuip_GetSortOrdinal
global function CharacterIntroQuip_GetCharacterFlavor
global function CharacterIntroQuip_GetVoiceSoundEvent
global function CharacterIntroQuip_GetStingSoundEvent
global function CharacterIntroQuip_GetSortOrdinal
#if SERVER || CLIENT
global function CharacterSkin_Apply
global function CharacterSkin_WaitForAndApplyFromLoadout
#endif
#if DEV && CLIENT
global function DEV_TestCharacterSkinData
#endif


//////////////////////
//////////////////////
//// Global Types ////
//////////////////////
//////////////////////
//


///////////////////////
///////////////////////
//// Private Types ////
///////////////////////
///////////////////////
struct FileStruct_LifetimeLevel
{
	table<ItemFlavor, LoadoutEntry>             loadoutCharacterSkinSlotMap
	table<ItemFlavor, LoadoutEntry>             loadoutCharacterExecutionSlotMap
	table<ItemFlavor, LoadoutEntry>             loadoutCharacterIntroQuipSlotMap
	table<ItemFlavor, LoadoutEntry>             loadoutCharacterKillQuipSlotMap

	table<ItemFlavor, ItemFlavor> skinCharacterMap
	table<ItemFlavor, ItemFlavor> executionCharacterMap
	table<ItemFlavor, ItemFlavor> killQuipCharacterMap
	table<ItemFlavor, ItemFlavor> introQuipCharacterMap

	table<ItemFlavor, int> cosmeticFlavorSortOrdinalMap
}
FileStruct_LifetimeLevel& fileLevel


////////////////////////
////////////////////////
//// Initialization ////
////////////////////////
////////////////////////
void function ShCharacterCosmetics_LevelInit()
{
	FileStruct_LifetimeLevel newFileLevel
	fileLevel = newFileLevel

	AddCallback_OnItemFlavorRegistered( eItemType.character, OnItemFlavorRegistered_Character )
}


void function OnItemFlavorRegistered_Character( ItemFlavor characterClass )
{
	// skins
	{
		array<ItemFlavor> skinList = RegisterReferencedItemFlavorsFromArray( characterClass, "skins", "flavor" )
		foreach( ItemFlavor skin in skinList )
		{
			fileLevel.skinCharacterMap[skin] <- characterClass
			SetupCharacterSkin( skin )
		}

		MakeItemFlavorSet( skinList, fileLevel.cosmeticFlavorSortOrdinalMap )

		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "character_skin_for_" + ItemFlavor_GetGUIDString( characterClass ) )
		entry.DEV_category = "character_skins"
		entry.DEV_name = ItemFlavor_GetHumanReadableRef( characterClass ) + " Skin"
		entry.stryderCharDataArrayIndex = ePlayerStryderCharDataArraySlots.CHARACTER_SKIN
		entry.defaultItemFlavor = skinList[0]
		entry.validItemFlavorList = skinList
		entry.isSlotLocked = bool function( EHI playerEHI ) {
			return !IsLobby()
		}
		entry.isActiveConditions = { [Loadout_CharacterClass()] = { [characterClass] = true, }, }
		entry.networkTo = eLoadoutNetworking.PLAYER_GLOBAL
		entry.networkVarName = "CharacterSkin"
		#if CLIENT
			if ( IsLobby() )
			{
		AddCallback_ItemFlavorLoadoutSlotDidChange_AnyPlayer( entry, void function( EHI playerEHI, ItemFlavor skin ) {
				UpdateMenuCharacterModel( FromEHI( playerEHI ) )
				} )
			}
			#endif
		fileLevel.loadoutCharacterSkinSlotMap[characterClass] <- entry
	}

	// executions
	{
		array<ItemFlavor> executionsList = RegisterReferencedItemFlavorsFromArray( characterClass, "executions", "flavor" )
		foreach( ItemFlavor execution in executionsList )
			fileLevel.executionCharacterMap[execution] <- characterClass
		MakeItemFlavorSet( executionsList, fileLevel.cosmeticFlavorSortOrdinalMap )

		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "character_execution_for_" + ItemFlavor_GetGUIDString( characterClass ) )
		entry.DEV_category = "character_executions"
		entry.DEV_name = ItemFlavor_GetHumanReadableRef( characterClass ) + " Execution"
		entry.defaultItemFlavor = executionsList[0]
		entry.validItemFlavorList = executionsList
		entry.isSlotLocked = bool function( EHI playerEHI ) {
			return !IsLobby()
		}
		entry.isActiveConditions = { [Loadout_CharacterClass()] = { [characterClass] = true, }, }
		entry.networkTo = eLoadoutNetworking.PLAYER_EXCLUSIVE
		fileLevel.loadoutCharacterExecutionSlotMap[characterClass] <- entry
	}

	// intro quips
	{
		array<ItemFlavor> quipList = RegisterReferencedItemFlavorsFromArray( characterClass, "introQuips", "flavor" )
		foreach( ItemFlavor quip in quipList )
			fileLevel.introQuipCharacterMap[quip] <- characterClass
		MakeItemFlavorSet( quipList, fileLevel.cosmeticFlavorSortOrdinalMap )

		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "character_intro_quip_for_" + ItemFlavor_GetGUIDString( characterClass ) )
		entry.DEV_category = "character_intro_quips"
		entry.DEV_name = ItemFlavor_GetHumanReadableRef( characterClass ) + " Intro Quip"
		entry.stryderCharDataArrayIndex = ePlayerStryderCharDataArraySlots.CHARACTER_INTRO_QUIP
		entry.defaultItemFlavor = quipList[0]
		entry.validItemFlavorList = quipList
		entry.isSlotLocked = bool function( EHI playerEHI ) {
			return !IsLobby()
		}
		entry.isActiveConditions = { [Loadout_CharacterClass()] = { [characterClass] = true, }, }
		entry.networkTo = eLoadoutNetworking.PLAYER_GLOBAL
		entry.networkVarName = "IntroQuip"
		fileLevel.loadoutCharacterIntroQuipSlotMap[characterClass] <- entry
	}

	// kill quips
	{
		array<ItemFlavor> quipList = RegisterReferencedItemFlavorsFromArray( characterClass, "killQuips", "flavor" )
		foreach( ItemFlavor quip in quipList )
			fileLevel.killQuipCharacterMap[quip] <- characterClass
		MakeItemFlavorSet( quipList, fileLevel.cosmeticFlavorSortOrdinalMap )

		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "character_kill_quip_for_" + ItemFlavor_GetGUIDString( characterClass ) )
		entry.DEV_category = "character_kill_quips"
		entry.DEV_name = ItemFlavor_GetHumanReadableRef( characterClass ) + " Kill Quip"
		entry.defaultItemFlavor = quipList[0]
		entry.validItemFlavorList = quipList
		entry.isSlotLocked = bool function( EHI playerEHI ) {
			return !IsLobby()
		}
		entry.isActiveConditions = { [Loadout_CharacterClass()] = { [characterClass] = true, }, }
		entry.networkTo = eLoadoutNetworking.PLAYER_GLOBAL
		entry.networkVarName = "KillQuip"
		fileLevel.loadoutCharacterKillQuipSlotMap[characterClass] <- entry
	}
}


void function SetupCharacterSkin( ItemFlavor skin )
{
	#if SERVER || CLIENT
		PrecacheModel( CharacterSkin_GetBodyModel( skin ) )
		PrecacheModel( CharacterSkin_GetArmsModel( skin ) )
	#endif
}


//////////////////////////
//////////////////////////
//// Global functions ////
//////////////////////////
//////////////////////////
LoadoutEntry function Loadout_CharacterSkin( ItemFlavor characterClass )
{
	return fileLevel.loadoutCharacterSkinSlotMap[characterClass]
}


LoadoutEntry function Loadout_CharacterExecution( ItemFlavor characterClass )
{
	return fileLevel.loadoutCharacterExecutionSlotMap[characterClass]
}


LoadoutEntry function Loadout_CharacterIntroQuip( ItemFlavor characterClass )
{
	return fileLevel.loadoutCharacterIntroQuipSlotMap[characterClass]
}


LoadoutEntry function Loadout_CharacterKillQuip( ItemFlavor characterClass )
{
	return fileLevel.loadoutCharacterKillQuipSlotMap[characterClass]
}


#if SERVER || CLIENT
void function PlayIntroQuipThread( entity emitter, EHI playerEHI, entity exceptionPlayer = null )
{
	EndSignal( emitter, "OnDestroy" )
	#if CLIENT
		Timeout timeout = BeginTimeout( 4.0 )
		EndSignal( timeout, "Timeout" )
	#endif
	ItemFlavor character = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_CharacterClass() )
	ItemFlavor quip      = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_CharacterIntroQuip( character ) )
	#if CLIENT
		CancelTimeoutIfAlive( timeout )
	#endif

	string quipAlias = CharacterIntroQuip_GetVoiceSoundEvent( quip )
	PlayQuip( quipAlias, emitter, playerEHI, exceptionPlayer )
}
#endif


#if SERVER || CLIENT
void function PlayKillQuipThread( entity emitter, EHI playerEHI, entity exceptionPlayer = null )
{
	EndSignal( emitter, "OnDestroy" )
	#if CLIENT
		Timeout timeout = BeginTimeout( 4.0 )
		EndSignal( timeout, "Timeout" )
	#endif
	ItemFlavor character = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_CharacterClass() )
	ItemFlavor quip      = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_CharacterKillQuip( character ) )
	#if CLIENT
		CancelTimeoutIfAlive( timeout )
	#endif

	string quipAlias = CharacterKillQuip_GetVictimVoiceSoundEvent( quip )
	PlayQuip( quipAlias, emitter, playerEHI, exceptionPlayer )
}
#endif


#if SERVER || CLIENT
void function PlayQuip( string quipAlias, entity emitter, EHI playerEHI, entity exceptionPlayer )
{
	if ( quipAlias != "" )
	{
		#if SERVER
			if ( exceptionPlayer == null )
				EmitSoundOnEntity( emitter, quipAlias )
			else
				EmitSoundOnEntityExceptToPlayer( emitter, exceptionPlayer, quipAlias )
		#else
		EmitSoundOnEntity( emitter, quipAlias )
		#endif
	}
}
#endif


asset function CharacterSkin_GetBodyModel( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_skin )

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( flavor ), "bodyModel" )
}


asset function CharacterSkin_GetArmsModel( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_skin )

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( flavor ), "armsModel" )
}


string function CharacterSkin_GetSkinName( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_skin )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "skinName" )
}


int function CharacterSkin_GetCamoIndex( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_skin )

	return GetGlobalSettingsInt( ItemFlavor_GetAsset( flavor ), "camoIndex" )
}


#if SERVER || CLIENT
void function CharacterSkin_Apply( entity ent, ItemFlavor skin )
{
	Assert( ItemFlavor_GetType( skin ) == eItemType.character_skin )

	asset bodyModel = CharacterSkin_GetBodyModel( skin )
	asset armsModel = CharacterSkin_GetArmsModel( skin )

	ent.SetSkin( 0 ) // Lame that we need this, but this avoids invalid skin errors when the model changes and the currently shown skin index doesn't exist for the new model
	ent.SetModel( bodyModel )

	int skinIndex = ent.GetSkinIndexByName( CharacterSkin_GetSkinName( skin ) )
	int camoIndex = CharacterSkin_GetCamoIndex( skin )

	if ( skinIndex == -1 )
	{
		skinIndex = 0
		camoIndex = 0
	}

	ent.SetSkin( skinIndex )
	ent.SetCamo( camoIndex )

	#if SERVER
		if ( ent.IsPlayer() )
		{
			ent.SetBodyModelOverride( bodyModel )
			ent.SetArmsModelOverride( armsModel )
		}
	#endif // SERVER
}
#endif // SERVER || CLIENT


#if SERVER || CLIENT
void function CharacterSkin_WaitForAndApplyFromLoadout( entity player, entity targetEnt )
{
	ItemFlavor character = LoadoutSlot_WaitForItemFlavor( ToEHI( player ), Loadout_CharacterClass() )
	if ( !IsValid( player ) || !IsValid( targetEnt ) )
		return

	ItemFlavor characterSkin = LoadoutSlot_WaitForItemFlavor( ToEHI( player ), Loadout_CharacterSkin( character ) )
	if ( !IsValid( player ) || !IsValid( targetEnt ) )
		return

	CharacterSkin_Apply( targetEnt, characterSkin )
}
#endif


int function CharacterSkin_GetSortOrdinal( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_skin )

	return fileLevel.cosmeticFlavorSortOrdinalMap[flavor]
}

ItemFlavor function CharacterSkin_GetCharacterFlavor( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_skin )

	return fileLevel.skinCharacterMap[flavor]
}


asset function CharacterExecution_GetAttackerAnimSeq( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( flavor ), "attackerAnimSeq" )
}


asset function CharacterExecution_GetVictimAnimSeq( ItemFlavor flavor, string rigWeight )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	string key
	switch ( rigWeight )
	{
		case "light": key = "victimLightAnimSeq"; break;

		case "medium": key = "victimMediumAnimSeq"; break;

		case "heavy": key = "victimHeavyAnimSeq"; break;
	}

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( flavor ), key )
}


asset function CharacterExecution_GetExecutionVideo( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	return GetGlobalSettingsStringAsAsset( ItemFlavor_GetAsset( flavor ), "video" )
}


asset function CharacterExecution_GetAttackerPreviewAnimSeq( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( flavor ), "attackerPreviewAnimSeq" )
}


asset function CharacterExecution_GetVictimPreviewAnimSeq( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( flavor ), "victimPreviewAnimSeq" )
}


int function CharacterExecution_GetSortOrdinal( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	return fileLevel.cosmeticFlavorSortOrdinalMap[flavor]
}


ItemFlavor function CharacterExecution_GetCharacterFlavor( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_execution )

	return fileLevel.executionCharacterMap[flavor]
}


bool function CharacterKillQuip_IsTheEmpty( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return GetGlobalSettingsBool( ItemFlavor_GetAsset( flavor ), "isTheEmpty" )
}


string function CharacterKillQuip_GetAttackerConversationName( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "attackerConversationName" )
}


string function CharacterKillQuip_GetAttackerStingSoundEvent( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "attackerStingSoundEvent" )
}


string function CharacterKillQuip_GetVictimVoiceSoundEvent( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "victimVoiceSoundEvent" )
}


string function CharacterKillQuip_GetVictimStingSoundEvent( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "victimStingSoundEvent" )
}


string function CharacterKillQuip_GetStingSound( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "stingSound" )
}


int function CharacterKillQuip_GetSortOrdinal( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return fileLevel.cosmeticFlavorSortOrdinalMap[flavor]
}


ItemFlavor function CharacterKillQuip_GetCharacterFlavor( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_kill_quip )

	return fileLevel.killQuipCharacterMap[flavor]
}


bool function CharacterIntroQuip_IsTheEmpty( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_intro_quip )

	return GetGlobalSettingsBool( ItemFlavor_GetAsset( flavor ), "isTheEmpty" )
}


string function CharacterIntroQuip_GetVoiceSoundEvent( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_intro_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "voiceSound" )
}


string function CharacterIntroQuip_GetStingSoundEvent( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_intro_quip )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "stingSound" )
}


int function CharacterIntroQuip_GetSortOrdinal( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_intro_quip )

	return fileLevel.cosmeticFlavorSortOrdinalMap[flavor]
}


ItemFlavor function CharacterIntroQuip_GetCharacterFlavor( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.gladiator_card_intro_quip )

	return fileLevel.introQuipCharacterMap[flavor]
}


#if DEV && CLIENT
void function DEV_TestCharacterSkinData()
{
	entity model = CreateClientSidePropDynamic( <0, 0, 0>, <0, 0, 0>, $"mdl/dev/empty_model.rmdl" )

	foreach ( character in GetAllCharacters() )
	{
		array<ItemFlavor> characterSkins = GetValidItemFlavorsForLoadoutSlot( LocalClientEHI(), Loadout_CharacterSkin( character ) )

		foreach ( skin in characterSkins )
		{
			printt( ItemFlavor_GetHumanReadableRef( skin ), "skinName:", CharacterSkin_GetSkinName( skin ) )
			CharacterSkin_Apply( model, skin )
		}
	}

	model.Destroy()
}
#endif // DEV && CLIENT