global function MapZones_SharedInit
global function MapZones_RegisterNetworking
global function MapZones_RegisterDataTable
global function GetZoneNameForZoneId
global function GetZoneMiniMapNameForZoneId
global function MapZones_GetZoneIdForTriggerName
global function GetDevNameForZoneId

#if CLIENT
global function SCB_OnPlayerEntersMapZone
global function MapZones_ZoneIntroText
#endif

#if SERVER
global function MapZones_GetZoneForOrigin
global function MapZones_GetTriggerForZone
global function MapZones_GetTriggerNameForZone
global function MapZones_GetTierForZone
global function MapZones_GetPopulationInfoForZone
global function MapZones_GetBoundsArea2DForZone
global function MapZones_PerZoneCallback
global function MapZones_RefreshZoneCalloutsForAll
global function MapZones_WaitForAnyPlayerEntersZone
//
global function MapZones_GetPopEnumForZone
//
global function MapZones_PushPlayerNoTouch
global function MapZones_PopPlayerNoTouch
global function MapZones_ClearPlayerNoTouch
global function MapZones_ForceRetouchForPlayer
//

#endif // SERVER

#if (SERVER && DEV)
global function DEV_PrintMapZoneInfo
global function DEV_MapZone_ToggleOverlay
#endif // (SERVER && DEV)

global struct ZonePopulationInfo
{
	int playersInside = 0
	int playersNearby = 0
}

global enum eZonePop
{
	NO_PLAYERS_AROUND,
	PLAYERS_NEARBY,
	PLAYERS_INSIDE,

	_count
}

#if SERVER
const string SIGNAL_ZONES_PLAYER_ENTERED = "PlayerEnteredZone"
#endif // SERVER

struct
{
	bool mapZonesInitialized = false
	var mapZonesDataTable
	table<int, int> calculatedZoneTiers
} file

const int INVALID_ZONE_ID = -1

string function GetDevNameForZoneId( int zoneId )
{
	return GetDataTableString( file.mapZonesDataTable, zoneId, GetDataTableColumnByName( file.mapZonesDataTable, "triggerName" ) )
}

const string EDITOR_CLASSNAME_ZONE_TRIGGER = "trigger_pve_zone"
void function MapZones_SharedInit()
{
#if SERVER
	AddSpawnCallbackEditorClass( "trigger_multiple", EDITOR_CLASSNAME_ZONE_TRIGGER, InitZoneTrigger )

	AddCallback_EntitiesDidLoad( EntitiesDidLoad )

	AddCallback_OnClientDisconnected( OnClientDisconnected )
	AddDeathCallback( "player", PlayerDeathCallback )

	RegisterSignal( SIGNAL_ZONES_PLAYER_ENTERED )
#endif // SERVER
}

const string FUNCNAME_OnPlayerEntersZone = "SCB_OnPlayerEntersMapZone"
void function MapZones_RegisterNetworking()
{
	Remote_RegisterClientFunction( FUNCNAME_OnPlayerEntersZone, "int", 0, 128, "int", 0, 4 )
}

void function MapZones_RegisterDataTable( asset dataTableAsset )
{
	file.mapZonesDataTable = GetDataTable( dataTableAsset )
	file.mapZonesInitialized = true
}

string function GetZoneMiniMapNameForZoneId( int zoneId )
{
	Assert( zoneId < GetDatatableRowCount( file.mapZonesDataTable ) )
	string zoneName = GetDataTableString( file.mapZonesDataTable, zoneId, GetDataTableColumnByName( file.mapZonesDataTable, "miniMapName" ) )
	return zoneName
}

string function GetZoneNameForZoneId( int zoneId )
{
	Assert( zoneId < GetDatatableRowCount( file.mapZonesDataTable ) )
	string zoneName = GetDataTableString( file.mapZonesDataTable, zoneId, GetDataTableColumnByName( file.mapZonesDataTable, "zoneName" ) )
	return zoneName
}

int function MapZones_GetZoneIdForTriggerName( string triggerName )
{
	int zoneId = GetDataTableRowMatchingStringValue( file.mapZonesDataTable, GetDataTableColumnByName( file.mapZonesDataTable, "triggerName" ), triggerName )
	return zoneId
}

#if SERVER

struct ZoneData
{
	entity     zoneTrigger
	int		   zoneTier
	array<int> neighborZoneIds

	float boundsArea2D

	int playersInside
	int playersNearby

	int zoneId
	string zoneName
}
table<int, ZoneData> s_zoneDatas


void function PlayerDeathCallback( entity player, var damageInfo )
{
	if ( !IsValid( player ) )
		return
	RemovePlayerFromCurrentZone( player )
	ExecutePendingPopulationNotifies()
}

void function OnClientDisconnected( entity player )
{
	RemovePlayerFromCurrentZone( player )
	ExecutePendingPopulationNotifies()
}

void function EntitiesDidLoad()
{
#if DEV
	thread DebugFrameThread()
#endif // DEV

	if ( !file.mapZonesInitialized )
		return

	for ( int zoneId = 0; zoneId < GetDatatableRowCount( file.mapZonesDataTable ); zoneId++ )
	{
		if ( !(zoneId in s_zoneDatas) )
			Warning( "Could not find trigger for zoneId " + zoneId + ": " + GetDevNameForZoneId( zoneId ) )
	}

	thread GenerateZoneTiers()
}

void function GenerateZoneTiers()
{
	array<LootZone> lootZones = GetAllLootZones()

	foreach ( mapZoneData in s_zoneDatas )
	{
		foreach ( lootZone in lootZones )
		{
			if ( !mapZoneData.zoneTrigger.ContainsPoint( lootZone.origin ) )
				continue

			int zoneTier = SURVIVAL_LootTierForLootGroup( lootZone.zoneClass )
			mapZoneData.zoneTier = maxint( zoneTier, mapZoneData.zoneTier )
		}

		//printt( mapZoneData.zoneName, mapZoneData.zoneTier )
		WaitFrame()
	}
}

int function MapZones_GetZoneForOrigin( vector point )
{
	foreach ( ZoneData zd in s_zoneDatas )
	{
		if ( zd.zoneTrigger.ContainsPoint( point ) )
			return zd.zoneId
	}

	return -1
}

string function MapZones_GetTriggerNameForZone( int zoneId )
{
	if ( !(zoneId in s_zoneDatas) )
		return ""

	ZoneData zd = s_zoneDatas[zoneId]
	return expect string( zd.zoneTrigger.kv.zone_name )
}

entity function MapZones_GetTriggerForZone( int zoneId )
{
	if ( !(zoneId in s_zoneDatas) )
		return null

	ZoneData zd = s_zoneDatas[zoneId]
	return zd.zoneTrigger
}

int function MapZones_GetTierForZone( int zoneId )
{
	if ( !(zoneId in s_zoneDatas) )
		return -1

	ZoneData zd = s_zoneDatas[zoneId]
	return zd.zoneTier
}

void function MapZones_PerZoneCallback( void functionref( int ) callbackFunc )
{
	foreach( int index, ZoneData zd in s_zoneDatas )
	{
		callbackFunc( index )
	}
}

ZonePopulationInfo function MapZones_GetPopulationInfoForZone( int zoneId )
{
	Assert( zoneId in s_zoneDatas )

	ZonePopulationInfo result
	ZoneData zd = s_zoneDatas[zoneId]
	result.playersInside = zd.playersInside
	result.playersNearby = zd.playersNearby
	return result
}

float function MapZones_GetBoundsArea2DForZone( int zoneId )
{
	Assert( zoneId in s_zoneDatas )

	ZoneData zd = s_zoneDatas[zoneId]
	return zd.boundsArea2D
}

float function GetZoneBoundsArea2D( entity trigger )
{
	vector mins  = trigger.GetBoundingMins()
	vector maxs  = trigger.GetBoundingMaxs()
	vector delta = (maxs - mins)

	return (delta.x * delta.y)
}

void function DestroyZoneTrigger( entity trigger )
{
	//destroy ent along with any linked ents
	array<entity> linkedEnts = trigger.GetLinkEntArray()
	foreach( linkedEnt in linkedEnts )
	{
		if ( IsValid( linkedEnt ) )
			linkedEnt.Destroy()
	}
	trigger.Destroy()
}

void function InitZoneTrigger( entity trigger )
{
	// Map does not support map zones
	if ( !file.mapZonesInitialized )
	{
		DestroyZoneTrigger( trigger )
		return
	}

	string zoneName = expect string( trigger.kv.zone_name )
	int zoneId      = MapZones_GetZoneIdForTriggerName( zoneName )
	if ( zoneId == INVALID_ZONE_ID )
	{
		Warning( "Could not find map zone in datatable: " + zoneName )
		DestroyZoneTrigger( trigger )
		return
	}

	ZoneData zd
	s_zoneDatas[zoneId] <- zd
	trigger.e.triggerZoneId = zoneId

	trigger.kv.triggerFilterUseNew = 1
	trigger.kv.triggerFilterPlayer = "all"
	trigger.kv.triggerFilterPhaseShift = "any"
	trigger.kv.triggerFilterNpc = "none"
	trigger.kv.triggerFilterNonCharacter = 0
	trigger.kv.triggerFilterTeamMilitia = 1
	trigger.kv.triggerFilterTeamIMC = 1
	trigger.kv.triggerFilterTeamNeutral = 1
	trigger.kv.triggerFilterTeamBeast = 1
	trigger.kv.triggerFilterTeamOther = 1
	trigger.ConnectOutput( "OnStartTouch", ZoneTrigger_OnStartTouch )

	zd.zoneTrigger = trigger
	zd.zoneId = zoneId
	zd.zoneName = GetZoneNameForZoneId( zoneId )

	zd.boundsArea2D = GetZoneBoundsArea2D( trigger )

	foreach( entity neighborEnt in trigger.GetLinkEntArray() )
	{
		if ( GetEditorClass( neighborEnt ) != EDITOR_CLASSNAME_ZONE_TRIGGER )
			continue

		string neighborZoneName = expect string( neighborEnt.kv.zone_name )
		int neighborZoneId = MapZones_GetZoneIdForTriggerName( neighborZoneName )
		zd.neighborZoneIds.append( neighborZoneId )
	}
}

int function MapZones_GetCount()
{
	if ( !file.mapZonesInitialized )
		return 0

	return GetDatatableRowCount( file.mapZonesDataTable )
}

void function MapZones_PushPlayerNoTouch( entity player )
{
	player.p.zoneNoTouchStack += 1
}

void function MapZones_PopPlayerNoTouch( entity player )
{
	Assert( player.p.zoneNoTouchStack > 0 )
	player.p.zoneNoTouchStack = maxint( 0, (player.p.zoneNoTouchStack - 1) )
}

void function MapZones_ClearPlayerNoTouch( entity player )
{
	player.p.zoneNoTouchStack = 0
}

bool function PlayerHasNoTouch( entity player )
{
	if ( player.p.zoneNoTouchStack > 0 )
		return true
	return false
}

void function MapZones_ForceRetouchForPlayer( entity player )
{
	for ( int index = 0; index < MapZones_GetCount(); ++index )
	{
		if ( !(index in s_zoneDatas) )
			continue
		ZoneData zd = s_zoneDatas[index]

		if ( zd.zoneTrigger.IsTouching( player ) )
		{
			OnPlayerEntersZone( player, zd.zoneTrigger )
			return
		}
	}
}

void function ZoneTrigger_OnStartTouch( entity self, entity activator, entity caller, var value )
{
	entity triggeringEnt = activator
	entity trigger       = self
	if ( !IsValid( triggeringEnt ) )
		return

	if ( triggeringEnt.IsPlayer() )
	{
		if ( !PlayerHasNoTouch( triggeringEnt ) )
			OnPlayerEntersZone( triggeringEnt, trigger )
	}
}

array<ZoneData> s_notifyZonesForPop
void function AddToPopNotify( ZoneData zd )
{
	if ( s_notifyZonesForPop.contains( zd ) )
		return
	s_notifyZonesForPop.append( zd )
}

void function RemovePlayerFromCurrentZone( entity player )
{
	if ( player.p.currentZoneId == INVALID_ZONE_ID )
		return

	ZoneData zd = s_zoneDatas[player.p.currentZoneId]
	foreach( int neighborId in zd.neighborZoneIds )
	{
		ZoneData neighbor = s_zoneDatas[neighborId]
		neighbor.playersNearby -= 1
		AddToPopNotify( neighbor )
	}
	zd.playersInside -= 1
	AddToPopNotify( zd )

	player.p.currentZoneId = INVALID_ZONE_ID
}

void function AddPlayerToNewZone( entity player, int zoneId )
{
	Assert( player.p.currentZoneId == INVALID_ZONE_ID )

	ZoneData zd = s_zoneDatas[zoneId]
	foreach( int neighborId in zd.neighborZoneIds )
	{
		ZoneData neighbor = s_zoneDatas[neighborId]
		neighbor.playersNearby += 1
		AddToPopNotify( neighbor )
	}
	zd.playersInside += 1
	AddToPopNotify( zd )

	player.p.currentZoneId = zoneId

	zd.zoneTrigger.Signal( SIGNAL_ZONES_PLAYER_ENTERED )
}

void function ExecutePendingPopulationNotifies()
{
}

void function MapZones_WaitForAnyPlayerEntersZone( int zoneId )
{
	ZoneData zd = s_zoneDatas[zoneId]
	zd.zoneTrigger.WaitSignal( SIGNAL_ZONES_PLAYER_ENTERED )
}

void function MapZones_RefreshZoneCalloutsForAll()
{
	array<entity> players = GetPlayerArray()
	foreach ( entity player in players )
	{
		int zoneId = player.p.currentZoneId
		if ( zoneId >= 0 )
			Remote_CallFunction_Replay( player, FUNCNAME_OnPlayerEntersZone, zoneId, s_zoneDatas[zoneId].zoneTier )
	}
}

void function OnPlayerEntersZone( entity player, entity zoneTrigger )
{
	//string zoneName = expect string( zoneTrigger.kv.zone_name )
	//Dev_PrintMessage( player, " ", zoneName, 4  )

	int zoneId = zoneTrigger.e.triggerZoneId

	Remote_CallFunction_Replay( player, FUNCNAME_OnPlayerEntersZone, zoneId, s_zoneDatas[zoneId].zoneTier )

	int newZone = zoneTrigger.e.triggerZoneId
	if ( newZone != player.p.currentZoneId )
	{
		RemovePlayerFromCurrentZone( player )
		AddPlayerToNewZone( player, newZone )
		ExecutePendingPopulationNotifies()
	}
}

int function MapZones_GetPopEnumForZone( int zoneId )
{
	ZoneData zd = s_zoneDatas[zoneId]
	if ( zd.playersInside > 0 )
		return eZonePop.PLAYERS_INSIDE
	if ( zd.playersNearby > 0 )
		return eZonePop.PLAYERS_NEARBY
	return eZonePop.NO_PLAYERS_AROUND
}
#endif // #if SERVER


#if CLIENT
var s_zoneIntroRui = null
void function MapZones_ZoneIntroText( entity player, string zoneDisplayName, int zoneTier )
{
	if ( s_zoneIntroRui != null )
		RuiDestroyIfAlive( s_zoneIntroRui )

	var rui = CreateCockpitRui( $"ui/map_zone_intro_title.rpak", 0 )
	RuiSetString( rui, "titleText", zoneDisplayName )
	RuiSetInt( rui, "zoneTier", zoneTier )
	s_zoneIntroRui = rui
}

array<string> s_lastZoneDisplayNames = ["", ""]
int s_lastZoneDisplayNameIndex = -1
void function SCB_OnPlayerEntersMapZone( int zoneId, int zoneTier )
{
	entity player = GetLocalViewPlayer()

	int ceFlags = player.GetCinematicEventFlags()
	if ( ceFlags & (CE_FLAG_HIDE_MAIN_HUD | CE_FLAG_INTRO) )
		return

	string zoneDisplayName = GetZoneNameForZoneId( zoneId )
	if ( s_lastZoneDisplayNames.contains( zoneDisplayName ) )
		return
	if ( zoneDisplayName.len() == 0 )
		return

	if ( zoneTier > 1 )
		ClientMusic_RequestStingerForNewZone( zoneId )

	MapZones_ZoneIntroText( player, zoneDisplayName, zoneTier )
	s_lastZoneDisplayNameIndex = ((s_lastZoneDisplayNameIndex + 1) % s_lastZoneDisplayNames.len())
	s_lastZoneDisplayNames[s_lastZoneDisplayNameIndex] = zoneDisplayName
}
#endif // CLIENT



#if (SERVER && DEV)
string function GetZoneLineForPlayer( entity player )
{
	int zoneId = player.p.currentZoneId
	if ( zoneId == INVALID_ZONE_ID )
		return format( "Not touching any zone." )

	return format( "%s    \"%s\"    (%.1f)", GetDevNameForZoneId( zoneId ), GetZoneNameForZoneId( zoneId ), sqrt( s_zoneDatas[zoneId].boundsArea2D ) )
}

void function MapZones_DebugDrawFrame()
{
	array<entity> players = GetPlayerArray()

	// Current zone info:
	{
		string text = ""
		foreach( entity player in players )
		{
			if ( player.p.zoneNoTouchStack > 0 )
				text += "  [NO_TOUCH]  "
			text += GetZoneLineForPlayer( player )
			if ( players.len() > 1 )
				text += format( "    (%s)\n", player.GetPlayerName() )
			else
				text += "\n"
		}
		DebugScreenText( 0.40, 0.125, text )
	}

	// All zones info:
	{
		string text = ""
		for ( int zoneId = 0; zoneId < MapZones_GetCount(); ++zoneId )
		{
			if ( !(zoneId in s_zoneDatas) )
				continue

			ZoneData zd = s_zoneDatas[zoneId]
			if ( (zd.playersInside == 0) && (zd.playersNearby == 0) )
				continue

			text += format( "%s\t p(%d,%d)\n", GetDevNameForZoneId( zoneId ), zd.playersInside, zd.playersNearby )

			vector mins = zd.zoneTrigger.GetBoundingMins()
			vector maxs = zd.zoneTrigger.GetBoundingMaxs()
			int rrr = ((zd.playersInside == 0) ? 150 : 255)
			int ggg = ((zd.playersInside == 0) ? 150 : 255)
			int bbb = ((zd.playersInside == 0) ? 128 : 255)
			DebugDrawBox( zd.zoneTrigger.GetOrigin(), mins, maxs, rrr, ggg, bbb, 1, 0.1 )
		}
		DebugScreenText( 0.85, 0.10, text )
	}
}

void function DEV_PrintMapZoneInfo()
{
	//foreach( int index, ZoneData zd in s_zoneDatas )
	for ( int index = 0; index < MapZones_GetCount(); ++index )
	{
		if ( !(index in s_zoneDatas) )
			continue
		ZoneData zd = s_zoneDatas[index]

		//printf( "**********************")
		printf( "%s   \"%s\"    Area: (%.0f)   %.0f  Trigger: '%s'  (%s)", GetDevNameForZoneId( index ), GetZoneNameForZoneId( index ), sqrt( zd.boundsArea2D ), zd.boundsArea2D, string( zd.zoneTrigger.kv.zone_name ), string( zd.zoneTrigger ) )

		string neighborsDesc = ""
		foreach( int neighborIndex in zd.neighborZoneIds )
			neighborsDesc += format( "%s%s", ((neighborsDesc.len() > 0) ? ", " : ""), GetDevNameForZoneId( neighborIndex ) )
		printf( "  Neighbors: %s", neighborsDesc )
		printf( "" )
	}
}

bool s_debugDrawFrame = false
void function DEV_MapZone_ToggleOverlay()
{
	s_debugDrawFrame = !s_debugDrawFrame
}

void function DebugFrameThread()
{
	while ( true )
	{
		if ( s_debugDrawFrame )
		{
			MapZones_DebugDrawFrame()
		}

		WaitFrame()
	}
}

#endif // #if (SERVER && DEV)
