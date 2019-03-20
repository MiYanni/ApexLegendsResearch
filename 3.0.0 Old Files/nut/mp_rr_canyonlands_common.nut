
global function Canyonlands_MapInit_Common

#if SERVER && DEV
	global function HoverTankTestPositions
#endif

#if SERVER
	global function HoverTank_DebugFlightPaths
	global function TestCreateTooManyLinks

	const int MAX_HOVERTANKS = 2
	const string HOVERTANK_START_NODE_NAME		= "hovertank_start_node"
	const string HOVERTANK_END_NODE_NAME		= "hovertank_end_node"
	const bool DEBUG_HOVERTANK_NODE_SELECTION	= false

	const string SIGNAL_HOVERTANK_AT_ENDPOINT = "HovertankAtEndpoint"

	const asset NESSY_MODEL = $"mdl/domestic/nessy_doll.rmdl"

	//const asset HOVERTANK_PATH_FX = $"P_wpn_arcball_beam"
	//const asset HOVERTANK_END_FX = $"P_ar_call_beacon_ring_hovertank"

	const float SKYBOX_Z_OFFSET_STAGING_AREA = 32.0
	const vector SKYBOX_ANGLES_STAGING_AREA = <0, 60, 0>

	const int HOVER_TANKS_DEFAULT_CIRCLE_INDEX = 1
	const int HOVER_TANKS_TYPE_INTRO = 0
	const int HOVER_TANKS_TYPE_MID = 1
#endif

const int HOVER_TANKS_DEFAULT_COUNT_INTRO = 1
const int HOVER_TANKS_DEFAULT_COUNT_MID = 1
const asset LEVIATHAN_MODEL = $"mdl/creatures/leviathan/leviathan_animated.rmdl"

struct
{
	#if SERVER
		array<HoverTank> hoverTanksIntro
		array<HoverTank> hoverTanksMid
		table<HoverTank, entity> hovertankEndpointMapObjects
		array<entity> hoverTankEndNodesIntro
		array<entity> hoverTankEndNodesMid
		vector skyboxStartingOrigin
		vector skyboxStartingAngles
	#endif
	int numHoverTanksIntro = 0
	int numHoverTanksMid = 0
} file

void function Canyonlands_MapInit_Common()
{
	printt( "Canyonlands_MapInit_Common" )

	PrecacheModel( LEVIATHAN_MODEL )

	SetVictorySequencePlatformModel( $"mdl/rocks/victory_platform.rmdl", < 0, 0, -10 >, < 0, 0, 0 > )

	file.numHoverTanksIntro = GetCurrentPlaylistVarInt( "hovertanks_count_intro", HOVER_TANKS_DEFAULT_COUNT_INTRO )
	#if SERVER
		printt( "HOVER TANKS INTRO MAX:", file.numHoverTanksIntro )
	#endif
	float chance = GetCurrentPlaylistVarFloat( "hovertanks_chance_intro", 1.0 ) * 100.0
	if ( RandomInt(100) > chance )
		file.numHoverTanksIntro = 0
	#if SERVER
		printt( "HOVER TANKS INTRO ACTUAL:", file.numHoverTanksIntro, "(was " + chance + "% chance)" )
	#endif

	file.numHoverTanksMid = GetCurrentPlaylistVarInt( "hovertanks_count_mid", HOVER_TANKS_DEFAULT_COUNT_MID )
	#if SERVER
		printt( "HOVER TANKS MID MAX:", file.numHoverTanksMid )
	#endif
	chance = GetCurrentPlaylistVarFloat( "hovertanks_chance_mid", 1.0 ) * 100.0
	if ( RandomInt(100) > chance )
		file.numHoverTanksMid = 0
	#if SERVER
		printt( "HOVER TANKS MID ACTUAL:", file.numHoverTanksMid, "(was " + chance + "% chance)" )
	#endif


	#if SERVER
		LootTicks_Init()

		FlagSet( "DisableDropships" )

		svGlobal.evacEnabled = false //Need to disable this on a map level if it doesn't support it at all

		RegisterSignal( "NessyDamaged" )
		RegisterSignal( SIGNAL_HOVERTANK_AT_ENDPOINT )

		PrecacheModel( NESSY_MODEL )

		//SURVIVAL_AddOverrideCircleLocation_Nitro( <24744, 24462, 3980>, 2048 )

		AddCallback_EntitiesDidLoad( EntitiesDidLoad )
		AddCallback_AINFileBuilt( HoverTank_DebugFlightPaths )

		AddCallback_GameStateEnter( eGameState.Playing, HoverTanksOnGamestatePlaying )
		AddCallback_OnSurvivalDeathFieldStageChanged( HoverTanksOnDeathFieldStageChanged )

		SURVIVAL_SetPlaneHeight( 24000 )
		SURVIVAL_SetAirburstHeight( 8000 )
		SURVIVAL_SetMapCenter( <0, 0, 0> )
		SetOutOfBoundsTimeLimit( 30.0 )

		AddSpawnCallback_ScriptName( "leviathan", LeviathanThink )
		AddSpawnCallback_ScriptName( "leviathan_staging", LeviathanThink )

		// adjust skybox for staging area
		AddCallback_GameStateEnter( eGameState.WaitingForPlayers, StagingArea_MoveSkybox )
		AddCallback_GameStateEnter( eGameState.PickLoadout, StagingArea_ResetSkybox )
	#endif

	#if CLIENT
		AddTargetNameCreateCallback( "LeviathanMarker", OnLeviathanCreated )
		AddTargetNameCreateCallback( "LeviathanStagingMarker", OnLeviathanCreated )

		SetVictorySequenceLocation( <11926.5957, -17612.0508, 11025.5176>, <0, 248.69014, 0> )
		SetMinimapBackgroundTileImage( $"overviews/mp_rr_canyonlands_bg" )

		if ( file.numHoverTanksIntro > 0 || file.numHoverTanksMid > 0 )
			SetMapFeatureItem( 500, "#HOVER_TANK", "#HOVER_TANK_DESC", $"rui/hud/gametype_icons/survival/sur_hovertank_minimap" )

		SetMapFeatureItem( 300, "#SUPPLY_DROP", "#SUPPLY_DROP_DESC", $"rui/hud/gametype_icons/survival/supply_drop" )

	#endif
}

#if SERVER
void function EntitiesDidLoad()
{
	FindHoverTankEndNodes()
	SpawnHoverTanks()
	Nessies()
}

void function FindHoverTankEndNodes()
{
	file.hoverTankEndNodesMid = GetHoverTankEndNodes( file.numHoverTanksMid, HOVER_TANKS_TYPE_MID, [] )
	file.hoverTankEndNodesIntro = GetHoverTankEndNodes( file.numHoverTanksIntro, HOVER_TANKS_TYPE_INTRO, file.hoverTankEndNodesMid )

	printt( "HOVER TANK MID NODES:", file.hoverTankEndNodesMid.len() )
	printt( "HOVER TANK INTRO NODES:", file.hoverTankEndNodesIntro.len() )

	file.numHoverTanksIntro = int( min( file.numHoverTanksIntro, file.hoverTankEndNodesIntro.len() ) )
	file.numHoverTanksMid = int( min( file.numHoverTanksMid, file.hoverTankEndNodesMid.len() ) )

	HideUnusedHovertankSpecificGeo()
}

void function SpawnHoverTanks()
{
	// Spawn hover tanks at level load, even though they don't fly in yet, so they exist when loot is spawned.
	if ( file.numHoverTanksIntro == 0 && file.numHoverTanksMid == 0 )
		return

	if ( GetEntArrayByScriptName( "_hover_tank_mover" ).len() == 0 )
		return

	int numHoverTankSpawnersInMap = GetEntArrayByScriptName( "_hover_tank_mover" ).len()
	Assert( numHoverTankSpawnersInMap >= file.numHoverTanksIntro + file.numHoverTanksMid, "Playlist is trying to spawn too many hover tanks than the map can support. hovertanks_count_intro + hovertanks_count_mid must be <= " + numHoverTankSpawnersInMap )

	array<string> spawners = [ "HoverTank_1", "HoverTank_2" ]
	spawners.resize( file.numHoverTanksIntro + file.numHoverTanksMid )

	foreach( int i, string spawnerName in spawners )
	{
		HoverTank hoverTank = SpawnHoverTank_Cheap( spawnerName )
		hoverTank.playerRiding = true
		if ( i + 1 <= file.numHoverTanksIntro )
		{
			printt( "HOVER TANKS INTRO SPAWNER:", spawnerName )
			file.hoverTanksIntro.append( hoverTank )
		}
		else
		{
			printt( "HOVER TANKS MID SPAWNER:", spawnerName )
			file.hoverTanksMid.append( hoverTank )
		}
	}
}

void function HoverTanksOnGamestatePlaying()
{
	if ( file.numHoverTanksIntro == 0 )
		return

	thread HoverTanksOnGamestatePlaying_Thread()
}

void function HoverTanksOnGamestatePlaying_Thread()
{
	FlagWait( "Survival_LootSpawned" )

	if ( GetCurrentPlaylistVarInt( "canyonlands_hovertank_flyin", 1 ) == 1 )
	{
		// Fly to final nodes
		FlyHoverTanksIntoPosition( file.hoverTanksIntro, HOVER_TANKS_TYPE_INTRO )
	}
	else
	{
		// Teleport to final nodes
		TeleportHoverTanksIntoPosition( file.hoverTanksIntro, HOVER_TANKS_TYPE_INTRO )
	}
}

void function HoverTanksOnDeathFieldStageChanged( int stage, float nextCircleStartTime )
{
	if ( file.numHoverTanksMid == 0 )
		return

	if ( stage == GetCurrentPlaylistVarInt( "canyonlands_hovertanks_circle_index", HOVER_TANKS_DEFAULT_CIRCLE_INDEX ) )
	{
		thread FlyHoverTanksIntoPosition( file.hoverTanksMid, HOVER_TANKS_TYPE_MID )
		wait 7.0
		AddSurvivalCommentaryEvent( eSurvivalEventType.HOVER_TANK_INBOUND )
	}
}

void function FlyHoverTanksIntoPosition( array<HoverTank> hoverTanks, int hoverTanksType )
{
	// Get start nodes and end nodes. Playlist vars change how these are selected.
	array<entity> startNodes
	array<entity> endNodes
	if ( hoverTanksType == HOVER_TANKS_TYPE_INTRO )
	{
		Assert( file.hoverTankEndNodesIntro.len() == hoverTanks.len(), "Not enough hover tank end locations found!" )
		startNodes = GetHoverTankStartNodes( file.hoverTankEndNodesIntro )
		endNodes = file.hoverTankEndNodesIntro
	}
	else if ( hoverTanksType == HOVER_TANKS_TYPE_MID )
	{
		Assert( file.hoverTankEndNodesMid.len() == hoverTanks.len(), "Not enough hover tank end locations found!" )
		startNodes = GetHoverTankStartNodes( file.hoverTankEndNodesMid )
		endNodes = file.hoverTankEndNodesMid
	}
	else
	{
		Assert( 0 )
	}

	Assert( startNodes.len() == hoverTanks.len(), "Not enough hover tank start locations found!" )

	if ( endNodes.len() == 0 )
		return

	foreach( int i, HoverTank hoverTank in hoverTanks )
	{
		CreateHoverTankMinimapIconForPlayers( hoverTank )

		array<entity> nodeChain = GetEntityChainOfType( endNodes[ i ] )

		HoverTankTeleportToPosition( hoverTank, startNodes[i].GetOrigin(), startNodes[i].GetAngles() )
		//thread HoverTankDrawPathFX( hoverTank, nodeChain[ 0 ] )

		thread HoverTankAdjustSpeed( hoverTank )
		thread HoverTankForceBoost( hoverTank )

		thread HoverTankFlyNodeChain( hoverTank, nodeChain )
		thread HideMinimapEndpointsWhenHoverTankFinishesFlyin( hoverTank )
		CreateHoverTankEndpointIconForPlayers( nodeChain.top(), hoverTank )
	}
}

void function HoverTankAdjustSpeed( HoverTank hoverTank )
{
	EndSignal( hoverTank, "OnDestroy" )

	float startSlowTime = Time() + 10.0
	float decelEndTime = startSlowTime + 20.0
	float startSpeed = 1200.0
	float endSpeed = 300.0

	HoverTankSetCustomFlySpeed( hoverTank, startSpeed )

	while ( Time() < decelEndTime )
	{

		float speed = GraphCapped( Time(), startSlowTime, decelEndTime, startSpeed, endSpeed )
		HoverTankSetCustomFlySpeed( hoverTank, speed )
		WaitFrame()
	}

	HoverTankSetCustomFlySpeed( hoverTank, endSpeed )
}

void function HoverTankForceBoost( HoverTank hoverTank )
{
	EndSignal( hoverTank, "OnDestroy" )
	EndSignal( hoverTank, "PathFinished" )

	while ( 1 )
	{
		HoverTankEngineBoost( hoverTank )
		wait RandomFloatRange( 1.0 , 5.0 )
	}
}

void function TeleportHoverTanksIntoPosition( array<HoverTank> hoverTanks, int hoverTanksType )
{
	array<entity> endNodes
	if ( hoverTanksType == HOVER_TANKS_TYPE_INTRO )
		endNodes = file.hoverTankEndNodesIntro
	else if ( hoverTanksType == HOVER_TANKS_TYPE_MID )
		endNodes = file.hoverTankEndNodesMid
	Assert( endNodes.len() == MAX_HOVERTANKS, "Not enough hover tank end locations found!" )

	foreach( int i, HoverTank hoverTank in hoverTanks )
	{
		entity teleportNode = GetLastLinkedEntOfType( endNodes[i] )
		HoverTankTeleportToPosition( hoverTank, teleportNode.GetOrigin(), teleportNode.GetAngles() )
		FireHoverTankZiplines( hoverTank, teleportNode )
	}
}

void function HideUnusedHovertankSpecificGeo()
{
	array<entity> hoverTankSpecificGeo
	array<entity> unusedEndNodes = GetAllHoverTankEndNodes()

	foreach( entity node in file.hoverTankEndNodesIntro )
		unusedEndNodes.fastremovebyvalue( node )

	foreach( entity node in file.hoverTankEndNodesMid )
		unusedEndNodes.fastremovebyvalue( node )

	foreach( entity node in unusedEndNodes )
	{
		entity lastNode = GetLastLinkedEntOfType( node )
		array<entity> endNodeLinkedEnts = lastNode.GetLinkEntArray()
		foreach( linkedEnt in endNodeLinkedEnts )
		{
			if ( linkedEnt.GetClassName() == "func_brush_lightweight" )
				linkedEnt.Destroy()
		}
	}
}

void function CreateHoverTankMinimapIconForPlayers( HoverTank hoverTank )
{
	vector hoverTankOrigin = hoverTank.interiorModel.GetOrigin()
	entity minimapObj = CreatePropScript( $"mdl/dev/empty_model.rmdl", hoverTankOrigin )
	minimapObj.Minimap_SetCustomState( eMinimapObject_prop_script.HOVERTANK )		// Minimap icon
	minimapObj.SetParent( hoverTank.interiorModel )
	minimapObj.SetLocalAngles( < 0, 0, 0 > )
	minimapObj.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	SetTeam( minimapObj, TEAM_UNASSIGNED )
	SetTargetName( minimapObj, "hovertank" )		// Full map icon

	SetMinimapObjectVisibleToPlayers( minimapObj, true )
}

void function CreateHoverTankEndpointIconForPlayers( entity endpoint, HoverTank hoverTank )
{
	vector hoverTankOrigin = endpoint.GetOrigin()
	entity minimapObj = CreatePropScript( $"mdl/dev/empty_model.rmdl", hoverTankOrigin )
	minimapObj.Minimap_SetCustomState( eMinimapObject_prop_script.HOVERTANK_DESTINATION )		// Minimap icon
	minimapObj.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	SetTeam( minimapObj, TEAM_UNASSIGNED )
	SetTargetName( minimapObj, "hovertankDestination" )		// Full map icon
	file.hovertankEndpointMapObjects[ hoverTank ] <- minimapObj

	SetMinimapObjectVisibleToPlayers( minimapObj, true )

	foreach( entity player in GetPlayerArray_Alive() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_SUR_PingMinimap", endpoint.GetOrigin(), 30.0, 500.0, 50.0, 2 )
}

void function HideHoverTankEndpointIconForPlayers( HoverTank hoverTank )
{
	if ( hoverTank in file.hovertankEndpointMapObjects )
	{
		entity endpoint = delete file.hovertankEndpointMapObjects[ hoverTank ]
		SetMinimapObjectVisibleToPlayers( endpoint, false )
	}
}

void function HideMinimapEndpointsWhenHoverTankFinishesFlyin( HoverTank hoverTank )
{
	EndSignal( hoverTank, "OnDestroy" )

	WaitSignal( hoverTank, SIGNAL_HOVERTANK_AT_ENDPOINT )

	HideHoverTankEndpointIconForPlayers( hoverTank )
}

void function SetMinimapObjectVisibleToPlayers( entity minimapObj, bool visible )
{
	foreach ( player in GetPlayerArray() )
	{
		if( visible )
			minimapObj.Minimap_AlwaysShow( 0, player )
		else
			minimapObj.Minimap_Hide( 0, player )
	}
}

const int ZIP_ATTACH_RIGHT_IDX 		= 0
const int ZIP_ATTACH_LEFT_IDX 		= 1
const int ZIP_ATTACH_BACK_IDX 		= 2

const int NUM_ZIP_ATTACHMENTS		= 3
const float ZIPLINE_ATTACH_FOV		= 0.707
void function FireHoverTankZiplines( HoverTank hoverTank, entity endNode )
{
	if ( IsValid( hoverTank.flightMover ) )
	{
		hoverTank.flightMover.AllowZiplines()
	}

	array<entity> endNodeZiplineTargets = endNode.GetLinkEntArray()
	array<vector> endNodeZiplineTargetOrigins
	int numZiplineTargets
	foreach( targetEnt in endNodeZiplineTargets )
	{
		if ( targetEnt.GetClassName() != "info_target" )
			continue

		endNodeZiplineTargetOrigins.append( targetEnt.GetOrigin() )
		numZiplineTargets++
	}

	array<vector> hoverTankZiplineAttachOrigins
	entity extModel = hoverTank.flightMover
	int ziplineRAttach 	= extModel.LookupAttachment( "ZIPLINE_R" )
	int ziplineLAttach 	= extModel.LookupAttachment( "ZIPLINE_L" )
	int ziplineBAttach 	= extModel.LookupAttachment( "ZIPLINE_B" )
	hoverTankZiplineAttachOrigins.append( extModel.GetAttachmentOrigin( ziplineRAttach ) )
	hoverTankZiplineAttachOrigins.append( extModel.GetAttachmentOrigin( ziplineLAttach ) )
	hoverTankZiplineAttachOrigins.append( extModel.GetAttachmentOrigin( ziplineBAttach ) )

	array< array< vector > > zipAttachPairCandidates

	for( int i; i < NUM_ZIP_ATTACHMENTS; i++ )
	{
		zipAttachPairCandidates.append( [] )
		vector attachDir = GetZiplineAttachDirectionFromIndex( i, extModel )
		for( int j; j < numZiplineTargets; j++ )
		{
			vector attachOrigin = hoverTankZiplineAttachOrigins[ i ]
			vector hoverTankToPoint = Normalize( FlattenVector( endNodeZiplineTargetOrigins[ j ] - attachOrigin ) )
			float dot2D             = DotProduct( hoverTankToPoint, attachDir )
			if ( dot2D > ZIPLINE_ATTACH_FOV )
			{
				vector ziplineEndOrigin = endNodeZiplineTargetOrigins[ j ]
				zipAttachPairCandidates[ i ].append( ziplineEndOrigin )
				array<entity> ziplineEnts = CreateHovertankZipline( attachOrigin, ziplineEndOrigin )
				//thread HovertankZiplineLaunchSequence( ziplineEnts, attachOrigin, ziplineEndOrigin )
			}
		}
	}
}

vector function GetZiplineAttachDirectionFromIndex( int idx, entity model )
{
	switch( idx )
	{
		case ZIP_ATTACH_RIGHT_IDX:
			return model.GetRightVector() * -1
		case ZIP_ATTACH_LEFT_IDX:
			return model.GetRightVector()
		case ZIP_ATTACH_BACK_IDX:
			return model.GetForwardVector() * -1
	}

	unreachable
}

void function HovertankZiplineLaunchSequence( array<entity> ziplineEnts, vector startPos, vector endPos )
{
	printt( "Hovertank zipline launch sequence!" )
	float time
	while ( time < 10 )
	{
		DebugDrawSphere( ziplineEnts[ 1 ].GetOrigin(), 64, 255, 0, 0, true, 0.2 )
		time += 0.1
		wait 0.1
	}
	entity mover = CreateScriptMover( startPos )
	ziplineEnts[ 1 ].SetParent( mover )

	mover.NonPhysicsMoveTo( endPos, 0.5, 0, 0 )
	while ( time < 10.5 )
	{
		DebugDrawSphere( mover.GetOrigin(), 16, 255, 0, 255, true, 0.2 )
		DebugDrawSphere( ziplineEnts[ 1 ].GetOrigin(), 64, 255, 0, 0, true, 0.2 )
		time += 0.1
		wait 0.1
	}
	DebugDrawSphere( mover.GetOrigin(), 16, 255, 0, 255, true, 20 )
	DebugDrawSphere( ziplineEnts[ 1 ].GetOrigin(), 64, 255, 0, 0, true, 20 )
	mover.Destroy()
	ziplineEnts[ 0 ].Zipline_Enable()
}

array<entity> function CreateHovertankZipline( vector startPos, vector endPos )
{
	entity zipline_start = CreateEntity( "zipline" )
	zipline_start.kv.Material = "cable/zipline.vmt"
	zipline_start.kv.ZiplineAutoDetachDistance = "160"
	zipline_start.kv._zipline_rest_point_0 = startPos.x + " " + startPos.y + " " + startPos.z
	zipline_start.kv._zipline_rest_point_1 = endPos.x + " " + endPos.y + " " + endPos.z
	zipline_start.SetOrigin( startPos )

	entity zipline_end = CreateEntity( "zipline_end" )
	zipline_end.kv.ZiplineAutoDetachDistance = "160"
	zipline_end.SetOrigin( endPos )
	// Comment in if using zipline sequence
	//zipline_end.SetOrigin( startPos )

	zipline_start.LinkToEnt( zipline_end )

	DispatchSpawn( zipline_start )
	DispatchSpawn( zipline_end )

	// Comment in if using zipline sequence
	//zipline_start.Zipline_Disable()

	array<entity> ziplineEnts = [ zipline_start, zipline_end ]
	return ziplineEnts
}

array<entity> function GetHoverTankStartNodes( array<entity> endNodes )
{
	if ( endNodes.len() == 1 )
	{
		array<entity> startNodes = GetEntArrayByScriptName( HOVERTANK_START_NODE_NAME )
		Assert( startNodes.len() >= 1 )
		startNodes.resize(1)
		return startNodes
	}

	const vector DEV_APPROX_Z_OFFSET = < 0, 0, 8000 >
	const float NODE_TO_TARGET_DIR_DOT_TOLERANCE = cos( PI / 4 ) 			// Start nodes to be considered for selection must be within 45 degrees of target dir

	Assert( endNodes.len() == 2, "Hover tank start location chooser only works with 2 hover tanks!" )
	array<entity> startNodes = GetEntArrayByScriptName( HOVERTANK_START_NODE_NAME )
	Assert( startNodes.len() >= 2 )

	array<vector> endNodeOrigins = [ endNodes[ 0 ].GetOrigin(), endNodes[ 1 ].GetOrigin() ]
	array<vector> endNodeOrigins2D
	foreach( origin in endNodeOrigins )
	{
		vector origin2D = origin
		origin2D.z = 0
		endNodeOrigins2D.append( origin2D )
	}

	vector endNodeBToA = endNodeOrigins2D[ 1 ] - endNodeOrigins2D[ 0 ]
	vector endNodesMiddlePoint = endNodeOrigins2D[ 0 ] + ( endNodeBToA * 0.5 )
	vector dirBToA = Normalize( endNodeBToA )
	vector orthoBToA = CrossProduct( dirBToA, < 0, 0, 1 > )

	array< array< table > > startNodesSplitByEndNodes
	for( int i; i < endNodes.len(); i++ ) // Crashes if declared as [ [], [] ]
	{
		startNodesSplitByEndNodes.append( [] )
	}

	// Split nodes into two halves, separated by the line between end nodes. Save dot product values for later.
	foreach( node in startNodes)
	{
		vector nodeOrigin2D = node.GetOrigin()
		nodeOrigin2D.z = 0

		vector nodeToMidpointDir = Normalize( endNodesMiddlePoint - nodeOrigin2D )
		float mapHalfDot = DotProduct( nodeToMidpointDir, orthoBToA )
		if ( mapHalfDot < 0 )
			startNodesSplitByEndNodes[ 1 ].append( { ent = node, dot = mapHalfDot } )		// Negative half
		else
			startNodesSplitByEndNodes[ 0 ].append( { ent = node, dot = mapHalfDot } )		// Positive half
	}

	// Pick a random half of the map to fly in from (using splits above). If not enough nodes in given half, use other half.
	int startNodeSplitToUse = RandomIntRangeInclusive( 0, 1 )

	if ( GetBugReproNum() == 31493 )
		startNodeSplitToUse = 0

	if ( startNodesSplitByEndNodes[ startNodeSplitToUse ].len() < 2 )
		startNodeSplitToUse = 1 - startNodeSplitToUse

	// Find the two start nodes closest to the vector orthogonal to vector connecting end nodes, stemming from the midpoint between both nodes.
	entity closestNode
	entity secondClosestNode
	float smallestDot = -1
	float secondSmallestDot = -1

	foreach( nodeData in startNodesSplitByEndNodes[ startNodeSplitToUse ] )
	{
		if ( DEBUG_HOVERTANK_NODE_SELECTION )
			DebugDrawCircle( expect entity(nodeData.ent).GetOrigin(), < 0, 0, 0 >, 1300.0, 0, 255, 0, true, 10 )

		float nodeDot = expect float( nodeData.dot )
		nodeDot = fabs( nodeDot )	// Since using a split half of the nodes, no issues if abs value this
		entity nodeEnt = expect entity( nodeData.ent )

		if ( (smallestDot < 0) || (nodeDot > smallestDot) )
		{
			secondSmallestDot = smallestDot
			secondClosestNode = closestNode
			smallestDot = nodeDot
			closestNode = nodeEnt
		}
		else if ( (secondSmallestDot < 0) || (nodeDot > secondSmallestDot) )
		{
			secondSmallestDot = nodeDot
			secondClosestNode = nodeEnt
		}
	}

	// Order the chosen start nodes to match end nodes. Make sure start node is paired with correct end node. If paths intersect, flip start -> node assignment
	array< entity > retArray		= [ secondClosestNode, closestNode ]
	bool intersect           = Do2DLinesIntersect( retArray[ 0 ].GetOrigin(), endNodes[ 0 ].GetOrigin(), retArray[ 1 ].GetOrigin(), endNodes[ 1 ].GetOrigin() )
	if ( intersect )
		retArray.reverse()

	if ( DEBUG_HOVERTANK_NODE_SELECTION )
	{
		DebugDrawCircle( closestNode.GetOrigin() + < 0, 0, 64 >, < 0, 0, 0 >, 1300.0, 255, 0, 255, true, 10 )
		DebugDrawCircle( secondClosestNode.GetOrigin() + < 0, 0, 64 >, < 0, 0, 0 >, 1300.0, 255, 0, 255, true, 10 )
		DebugDrawCircle( endNodeOrigins2D[ 0 ] + DEV_APPROX_Z_OFFSET, < 0, 0, 0 >, 1300.0, 0, 255, 255, true, 10 )
		DebugDrawCircle( endNodeOrigins2D[ 1 ] + DEV_APPROX_Z_OFFSET, < 0, 0, 0 >, 1300.0, 0, 255, 255, true, 10 )

		DebugDrawLine( endNodeOrigins2D[ 0 ] + DEV_APPROX_Z_OFFSET, endNodeOrigins2D[ 1 ] + DEV_APPROX_Z_OFFSET, 255, 255, 0, true, 10 )
		DebugDrawLine( endNodesMiddlePoint + (orthoBToA * 96000) + DEV_APPROX_Z_OFFSET, endNodesMiddlePoint + (orthoBToA * -96000) + DEV_APPROX_Z_OFFSET, 255, 120, 0, true, 10 )

		DebugDrawLine( retArray[ 0 ].GetOrigin(), endNodes[ 0 ].GetOrigin(), 255, 0, 0, true, 10 )
		DebugDrawLine( retArray[ 1 ].GetOrigin(), endNodes[ 1 ].GetOrigin(), 255, 0, 0, true, 10 )
		DebugDrawLine( closestNode.GetOrigin(), endNodesMiddlePoint + DEV_APPROX_Z_OFFSET, 255, 0, 0, true, 10 )
		DebugDrawLine( secondClosestNode.GetOrigin(), endNodesMiddlePoint + DEV_APPROX_Z_OFFSET, 255, 255, 0, true, 10 )

		DebugDrawSphere( endNodesMiddlePoint + DEV_APPROX_Z_OFFSET, 32, 255, 0, 255, true, 10 )
		DebugDrawSphere( endNodeOrigins2D[ 0 ] + DEV_APPROX_Z_OFFSET, 32, 255, 0, 255, true, 10 )
		DebugDrawSphere( endNodeOrigins2D[ 1 ] + DEV_APPROX_Z_OFFSET, 32, 125, 125, 255, true, 10 )
	}

	return retArray
}


array<entity> function GetHoverTankEndNodes( int count, int endNodeType, array<entity> excludeNodes )
{
	Assert( endNodeType == HOVER_TANKS_TYPE_INTRO || endNodeType == HOVER_TANKS_TYPE_MID )
	array<entity> potentialEndNodes = GetAllHoverTankEndNodes()

	// Remove exclude nodes
	foreach( entity node in excludeNodes )
		potentialEndNodes.fastremovebyvalue( node )

	if ( GetCurrentPlaylistVarInt( "canyonlands_dynamic_hovertank_locations", 1 ) != 1 )
	{
		// Don't use random locations, only use original end locations
		for ( int i = potentialEndNodes.len() - 1; i >= 0; i-- )
		{
			if ( !potentialEndNodes[i].HasKey( "original_tank_location" ) || (int( expect string( potentialEndNodes[i].kv.original_tank_location ) ) != 1) )
				potentialEndNodes.remove( i )
		}
	}
	potentialEndNodes.randomize()

	// Don't allow hover tank positions that will be within one of the final circles because they are OP positions for end game
	array<entity> nodesNotInFinalCircles
	DeathFieldStageData deathFieldStageDataSmall = GetDeathFieldStage( GetCurrentPlaylistVarInt( "canyonlands_hovertanks_circle_index", HOVER_TANKS_DEFAULT_CIRCLE_INDEX ) + 1 )
	float invalidRadius = deathFieldStageDataSmall.endRadius + HOVER_TANK_RADIUS
	for ( int i = potentialEndNodes.len() - 1; i >= 0; i-- )
	{
		if ( Distance2D( deathFieldStageDataSmall.endPos, potentialEndNodes[i].GetOrigin() ) <= invalidRadius )
			potentialEndNodes.remove( i )
	}

	if ( endNodeType == HOVER_TANKS_TYPE_MID )
	{
		// Exclude end nodes that are outside the current safe circle
		DeathFieldStageData deathFieldStageDataLarge = GetDeathFieldStage( GetCurrentPlaylistVarInt( "canyonlands_hovertanks_circle_index", HOVER_TANKS_DEFAULT_CIRCLE_INDEX ) )
		for ( int i = potentialEndNodes.len() - 1; i >= 0; i-- )
		{
			if ( Distance2D( deathFieldStageDataLarge.endPos, potentialEndNodes[i].GetOrigin() ) >= deathFieldStageDataLarge.endRadius )
				potentialEndNodes.remove( i )
		}
	}

	if ( potentialEndNodes.len() > 1 )
		potentialEndNodes.randomize()

	// Pick randomly from what we have left
	array<entity> endNodesToUse
	foreach( entity node in potentialEndNodes )
	{
		if ( endNodesToUse.len() >= count )
			break
		endNodesToUse.append( node )
	}
	return endNodesToUse
}

void function HoverTankFlyNodeChain( HoverTank hoverTank, array<entity> nodes )
{
	EndSignal( hoverTank, "OnDestroy" )
	EndSignal( hoverTank.flightMover, "OnDestroy" )

	int numNodes = nodes.len()
	for ( int i = 0; i < numNodes; i++ )
	{
		waitthread HoverTankFlyToNode( hoverTank, nodes[ i ] )
	}

	FireHoverTankZiplines( hoverTank, nodes.top() )
	Signal( hoverTank, SIGNAL_HOVERTANK_AT_ENDPOINT )
}

array<entity> function GetAllHoverTankEndNodes()
{
	return GetEntArrayByScriptName( HOVERTANK_END_NODE_NAME )
}

void function HoverTank_DebugFlightPaths()
{
	thread HoverTank_DebugFlightPaths_Thread()
}

void function HoverTank_DebugFlightPaths_Thread()
{
	printt( "++++--------------------------------------------------------------------------------------------------------------------------++++" )
	printt( ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> DEBUGGING HOVERTANK FLIGHT PATH PERMUTATIONS ON CANYONLANDS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" )
	printt( "++++--------------------------------------------------------------------------------------------------------------------------++++" )

	array<entity> endNodes = GetAllHoverTankEndNodes()
	array<entity> startNodes = GetEntArrayByScriptName( HOVERTANK_START_NODE_NAME )
	int numEndNodes = endNodes.len()
	int numStartNodes = startNodes.len()
	int numChecksPerFrame = 10
	int numChecksDone = 0

	for( int i = 0; i < numStartNodes; i++ )
	{
		entity currentStartNode = startNodes[ i ]

		for( int j = 0; j < numEndNodes; j++ )
		{
			entity currentEndNode = endNodes[ j ]
			if ( !HoverTankCanFlyPath( currentStartNode.GetOrigin(), currentEndNode ) )
			{
				Warning( "HoverTank can't fly from " + currentStartNode.GetOrigin() + " to " + currentEndNode.GetOrigin() + " because the path is broken" )
				DebugDrawLine( currentStartNode.GetOrigin(), currentEndNode.GetOrigin(), 255, 0, 0, true, 20.0 )
			}
			numChecksDone++
			if ( numChecksDone >= numChecksPerFrame )
			{
				numChecksDone = 0
				WaitFrame()
			}
		}
	}
	printt( "++++--------------------------------------------------------------------------------------------------------------------------++++" )
	printt( "++++--------------------------------------------------------------------------------------------------------------------------++++" )
}

#if SERVER && DEV
void function HoverTankTestPositions()
{
	entity player = GetPlayerArray()[0]

	HoverTank hoverTank = SpawnHoverTank_Cheap( "HoverTank_1" )
	hoverTank.playerRiding = true
	//file.hoverTanksMid.append( hoverTank )

	array<entity> endNodes = GetAllHoverTankEndNodes()

	foreach( entity node in endNodes )
	{
		//DebugDrawSphere( node.GetOrigin(), 1024, 255, 0, 0, true, 9999.0 )
		entity teleportNode = GetLastLinkedEntOfType( node )
		HoverTankTeleportToPosition( hoverTank, teleportNode.GetOrigin(), teleportNode.GetAngles() )
		FireHoverTankZiplines( hoverTank, teleportNode )

		player.SetOrigin( teleportNode.GetOrigin() + < 0, 0, 1024 > )
		player.SetAngles( teleportNode.GetAngles() )

		while( player.IsInputCommandHeld( IN_SPEED ) || player.IsInputCommandHeld( IN_ZOOM ) )
			WaitFrame()

		while( !player.IsInputCommandHeld( IN_SPEED ) || !player.IsInputCommandHeld( IN_ZOOM ) )
			WaitFrame()
	}
}
#endif

void function TestCreateTooManyLinks()
{
	wait 1
	entity fromEntity = GetEntByIndex( 1 );
	if ( IsValid( fromEntity ) )
	{
		for ( int i = 0; i < 100; ++i )
		{
			for ( int j = 0; j < 100; ++j )
			{
				int index = (i * 100) + j + 1
				entity toEntity = GetEntByIndex( index )
				if ( IsValid( toEntity ) )
				{
					if ( !fromEntity.IsLinkedToEnt( toEntity ) )
					{
						printt( "Linking " + fromEntity + " to " + toEntity )
						fromEntity.LinkToEnt( toEntity )
					}
				}
			}
			wait 0
		}
	}
}

void function LeviathanThink( entity leviathan )
{
	leviathan.EndSignal( "OnDestroy" )

	string targetName = "LeviathanMarker"
	if ( leviathan.GetScriptName() == "leviathan_staging" )
		targetName = "LeviathanStagingMarker"

	entity ent = CreatePropDynamic_NoDispatchSpawn( $"mdl/dev/empty_model.rmdl", leviathan.GetOrigin(), leviathan.GetAngles() )
	SetTargetName( ent, targetName )
	DispatchSpawn( ent )
	leviathan.Destroy()
}

void function StagingArea_MoveSkybox()
{
	thread StagingArea_MoveSkybox_Thread()
}


void function StagingArea_MoveSkybox_Thread()
{
	FlagWait( "EntitiesDidLoad" )

	entity skyboxCamera = GetEnt( "skybox_cam_level" )

	file.skyboxStartingOrigin = skyboxCamera.GetOrigin()
	file.skyboxStartingAngles = skyboxCamera.GetAngles()
	skyboxCamera.SetOrigin( skyboxCamera.GetOrigin() + <0, 0, SKYBOX_Z_OFFSET_STAGING_AREA> )

	skyboxCamera.SetAngles( SKYBOX_ANGLES_STAGING_AREA )
}


void function StagingArea_ResetSkybox()
{
	thread StagingArea_ResetSkybox_Thread()
}


void function StagingArea_ResetSkybox_Thread()
{
	FlagWait( "EntitiesDidLoad" )

	entity skyboxCamera = GetEnt( "skybox_cam_level" )

	skyboxCamera.SetOrigin( file.skyboxStartingOrigin )
	skyboxCamera.SetAngles( file.skyboxStartingAngles )
}

void function Nessies()
{
	entity skyboxCam = GetEnt( "skybox_cam_level" )
	if ( !IsValid( skyboxCam ) )
		return

	array<entity> nessies
	int i = 1
	while( true )
	{
		array<entity> ents = GetEntArrayByScriptName( "nessy" + i )
		if ( ents.len() != 1 )
			break
		entity nessy = ents.pop()
		nessy.Hide()
		nessy.NotSolid()
		nessies.append( nessy )
		i++
	}

	if ( nessies.len() == 0 )
		return

	int nessiesRequired = GetCurrentPlaylistVarInt( "nessies_required", nessies.len() )

	foreach( entity nessy in nessies )
	{
		nessy.Show()
		nessy.Solid()
		AddEntityCallback_OnDamaged( nessy, NessyDamageCallback )

		WaitSignal( nessy, "NessyDamaged" )
		nessy.Destroy()

		nessiesRequired--
		if ( nessiesRequired <= 0 )
			break

		foreach( entity player in GetPlayerArray() )
			Remote_CallFunction_NonReplay( player, "ServerCallback_NessyMessage", 0 )
	}

	foreach( entity player in GetPlayerArray() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_NessyMessage", 1 )

	entity nessy = CreateScriptMoverModel( NESSY_MODEL, skyboxCam.GetOrigin() + <90,10,-20>, <0,90,0> )
	nessy.NonPhysicsMoveTo( skyboxCam.GetOrigin() + <60,10,-4>, 30.0, 4.0, 4.0 )
	nessy.NonPhysicsRotateTo( <0,110,0>, 15, 5, 5 )
	wait 15.0
	nessy.NonPhysicsRotateTo( <0,90,0>, 20, 5, 5 )
	wait 20.0
	nessy.NonPhysicsMoveTo( skyboxCam.GetOrigin() + <60,10,-20>, 20.0, 4.0, 4.0 )
	nessy.NonPhysicsRotateTo( <0,-90,0>, 20, 8, 8 )
	wait 20.0
	nessy.Destroy()
}

void function NessyDamageCallback( entity ent, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsPlayer() )
	{
		Signal( ent, "NessyDamaged" )
		PlayerDamageFeedback( ent, damageInfo, 0 )
	}
}
#endif

#if CLIENT
void function OnLeviathanCreated( entity marker )
{
	bool stagingOnly = marker.GetTargetName() == "LeviathanStagingMarker"
	entity leviathan = CreateClientSidePropDynamic( marker.GetOrigin(), marker.GetAngles(), LEVIATHAN_MODEL )
	thread LeviathanThink( marker, leviathan, stagingOnly )
}

void function LeviathanThink( entity marker, entity leviathan, bool stagingOnly )
{
	marker.EndSignal( "OnDestroy" )
	leviathan.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function () : ( leviathan )
		{
			if ( IsValid( leviathan ) )
			{
				leviathan.Destroy()
			}
		}
	)

	int count = 0
	int liftCount = RandomIntRange( 3, 10 )

	while ( 1 )
	{
		if ( stagingOnly && GetGameState() >= eGameState.Playing )
			return

		if ( count < liftCount )
		{
			if ( CoinFlip() )
				waitthread PlayAnim( leviathan, "lev_idle_noloop" )
			else
				waitthread PlayAnim( leviathan, "leviathan_idle_short_noloop" )
			count++
		}
		else
		{
			waitthread PlayAnim( leviathan, "lev_idle_lookup_noloop" )
			count = 0
			liftCount = RandomIntRange( 3, 10 )
		}
	}
}
#endif