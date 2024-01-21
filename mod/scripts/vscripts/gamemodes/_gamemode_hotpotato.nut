global function GamemodeHotPotato_Init

struct
{
	bool firstMarked                     // true when the first player has been marked
	float hotPotatoStart                 // Time() when first started
	float hotPotatoEnd = 30.0                   // playlist var "hotpotato_timer", default 30.0 seconds
	entity marked                        // player that is currently marked
	array<entity> activePlayers          // non-spectators players
	int alivePlayers                     // separate from activePlayers because I have trust issues in my own code
} file

void function GamemodeHotPotato_Init()
{
    SetSpawnpointGamemodeOverride( FFA )

    SetShouldUseRoundWinningKillReplay( true )
    SetLoadoutGracePeriodEnabled( false ) // prevent modifying loadouts with grace period
    SetWeaponDropsEnabled( false )
    SetRespawnsEnabled( true )
    Riff_ForceTitanAvailability( eTitanAvailability.Never )
    Riff_ForceBoostAvailability( eBoostAvailability.Disabled )
    ClassicMP_ForceDisableEpilogue( true )

    AddCallback_OnClientConnected( HotPotatoInitPlayer )
    AddCallback_OnPlayerRespawned( UpdateHotPotatoLoadout )
    AddCallback_OnPlayerKilled( HotPotatoPlayerKilled )
    AddCallback_OnClientDisconnected( HotPotatoPlayerDisconnected )
    AddCallback_GameStateEnter( eGameState.Playing, HotPotatoInit )

    AddDamageCallback( "player", MarkNewPlayer )
    RegisterWeaponDamageSource( "mp_weapon_hotpotato", "Hot Potato Exploded" ) // yay i love 1.9.4
    RegisterSignal( "OnMarkedDeath" )
    // DROP_BATTERY_ON_DEATH = false
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker && victim.IsPlayer() && attacker.IsPlayer() && GetGameState() == eGameState.Playing )
	{
		AddTeamScore( attacker.GetTeam(), 1 )
		// why isn't this PGS_SCORE? odd game
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )
	}
}

void function HotPotatoInit()
{
	file.hotPotatoEnd = GetConVarFloat( "hotpotato_timer" ) 
	thread HotPotatoInitCountdown()
}

void function HotPotatoInitCountdown()
{
	wait 10
	
	file.activePlayers = GetPlayerArray()
	file.alivePlayers = GetPlayerArray().len()

	if ( GetGameState() != eGameState.Playing )
		return

	entity player = GetRandomPlayer()
	thread MarkRandomPlayer( player )
}

// give them a red outline to indicate they have the potato, also give them the ability to melee other players to pass the outline
void function MarkRandomPlayer( entity player )
{
	if ( GetGameState() != eGameState.Playing )
		return
	
	if ( !IsAlive(player) || !IsValid(player) )
	{
		thread MarkRandomPlayer( GetRandomPlayer() )
		return
	}

	file.hotPotatoStart = Time()

	foreach ( entity p in GetPlayerArray() )
	{
	    Remote_CallFunction_NonReplay( p, "ServerCallback_ShowHotPotatoCountdown", file.hotPotatoStart + file.hotPotatoEnd )
		Highlight_SetEnemyHighlightWithParam1( p, "enemy_sonar", <0, 0, 0> )
		if ( p != player )
			NSSendAnnouncementMessageToPlayer( p, "Hot Potato", player.GetPlayerName() + " has the potato!", <1,1,0>, 1, 1)
			// Remote_CallFunction_NonReplay( p, "ServerCallback_AnnounceNewMark", player.GetEncodedEHandle() )
			
		// Remote_CallFunction_NonReplay( p, "ServerCallback_MarkedChanged", player.GetEncodedEHandle() )
	}

	file.firstMarked = true

	// Rodeo_GiveBatteryToPlayer( player )
	Highlight_SetEnemyHighlight( player, "enemy_boss_bounty" ) // red outline
	file.marked = player
	// Remote_CallFunction_NonReplay( player, "ServerCallback_PassedHotPotato" ) // the big announcement
	NSSendAnnouncementMessageToPlayer( player, "You have the Potato!", "Melee someone to pass the potato!", <1,1,0>, 1, 1 )
	player.GiveOffhandWeapon( "mp_weapon_grenade_sonar", OFFHAND_ORDNANCE, [] )
	thread HotPotatoCountdown()
}

void function HotPotatoCountdown()
{
	svGlobal.levelEnt.EndSignal( "OnMarkedDeath" )

	// wait until Time() reaches file.hotPotatoEnd
	while ( Time() < file.hotPotatoStart + file.hotPotatoEnd )
	{
		wait 1
	}
	
	// kill player once timer runs out
	entity player = file.marked
	if ( !IsValid( player ) || !IsAlive( player ) )
	{
		if (GetGameState() != eGameState.Playing)
			return

		wait 10
		thread MarkRandomPlayer( GetRandomPlayer() )
		return
	}

	player.Die( null, null, { scriptType = DF_GIB, damageSourceId = eDamageSourceId.mp_weapon_hotpotato } )
	CreatePhysExplosion( player.GetOrigin(), 250, PHYS_EXPLOSION_LARGE, 11 )
	foreach ( entity p in file.activePlayers )
		p.AddToPlayerGameStat( PGS_PILOT_KILLS, 1 ) // adds "Waves Survived" to the scoreboard
}

void function MarkNewPlayer( entity victim, var damageInfo ) // when marked punch someone, pass the hot potato
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) && !IsValid( victim ) && victim == attacker )
		return

	float damage = DamageInfo_GetDamage( damageInfo )
	damage = 0
	DamageInfo_SetDamage( damageInfo, damage )

	// they passed mark to someone else
	if ( attacker == file.marked && ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.mp_weapon_grenade_sonar || DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.melee_pilot_emptyhanded ) )
	{
		file.marked = victim
		foreach ( entity p in GetPlayerArray() )
		{
			Highlight_SetEnemyHighlightWithParam1( p, "enemy_sonar", <0, 0, 0> )
			// Remote_CallFunction_NonReplay( p, "ServerCallback_MarkedChanged", victim.GetEncodedEHandle() )
			NSSendPopUpMessageToPlayer( p, "The potato has been passed to " + victim.GetPlayerName() + "!" )
		}

		Highlight_SetEnemyHighlight( victim, "enemy_boss_bounty" ) // make the enemy glow to other players
		SetRoundWinningKillReplayAttacker(attacker)
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 ) // adds "Potato Passes" to the scoreboard
		// Remote_CallFunction_NonReplay( victim, "ServerCallback_PassedHotPotato" )
		NSSendAnnouncementMessageToPlayer( victim, "You have the Potato!", "Melee someone to pass the potato!", <1,1,0>, 1, 1)
		MarkHasSonar( attacker, victim )
		// Rodeo_RemoveBatteryOffPlayer( attacker ) // not possible without modifying _rodeo to remove battery on death
		// Rodeo_GiveBatteryToPlayer( victim )

		attacker.TakeOffhandWeapon( OFFHAND_ORDNANCE )
		victim.GiveOffhandWeapon( "mp_weapon_grenade_sonar", OFFHAND_ORDNANCE, [] )
	}

	if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.mp_weapon_wingman )
		EMP_DamagedPlayerOrNPC( victim, damageInfo ) // apply slow effect
}

void function MarkHasSonar( entity old, entity newp ) // give marked the ability to see all players through walls
{
	foreach( entity p in GetPlayerArray() )
	{
		p.HighlightDisableForTeam( old.GetTeam() )
		p.HighlightEnableForTeam( newp.GetTeam() )
	}
}

void function HotPotatoInitPlayer( entity player )
{
	UpdateHotPotatoLoadout( player )
	Highlight_SetEnemyHighlightWithParam1( player, "enemy_sonar", <0, 0, 0> )
}

void function HotPotatoPlayerDisconnected( entity player )
{
	//if this player was in file.activePlayers we remove them from the array as well as lower file.alivePlayers by one
	if ( file.activePlayers.find( player ) != -1 )
	{
		file.activePlayers.remove( file.activePlayers.find( player ) )
		file.alivePlayers--

		if ( player == file.marked ) // reset countdown etc if marked player suicides or disconnects
		{
			foreach ( entity p in GetPlayerArray() )
			{
				Highlight_ClearEnemyHighlight(p)
                Remote_CallFunction_NonReplay( p, "ServerCallback_ShowHotPotatoCountdown", Time() )
				NSSendPopUpMessageToPlayer( p, "The player with the hot potato has disconnected!" )
			}

			svGlobal.levelEnt.Signal( "OnMarkedDeath" )
				
			thread WaitBeforeMark()
		}
	}
}

void function UpdateHotPotatoLoadout( entity player )
{
	if ( IsAlive(player) && player != null )
	{
		// set loadout
		foreach ( entity weapon in player.GetMainWeapons() )
			player.TakeWeaponNow( weapon.GetWeaponClassName() )

		foreach ( entity weapon in player.GetOffhandWeapons() )
			player.TakeWeaponNow( weapon.GetWeaponClassName() )

		// check if this player is inside file.activePlayers
		if ( file.activePlayers.find( player ) != -1 || !file.firstMarked )
		{
			player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE,  [] )
			player.GiveOffhandWeapon( "mp_ability_heal", OFFHAND_LEFT )
			player.GiveWeapon( "mp_weapon_wingman", [ "hotpotato" ] )
			// player.SetActiveWeaponByName( "melee_pilot_emptyhanded" )

			SyncedMelee_Disable( player )
		}
		else
		{
			// let them able to noclip, no collision group as well as be invisible
			player.SetPhysics( MOVETYPE_NOCLIP )
			player.kv.VisibilityFlags = 0
			player.SetTakeDamageType( DAMAGE_NO )
			player.SetDamageNotifications( false )
			player.SetNameVisibleToEnemy( false )
			player.SetNameVisibleToFriendly( false )
			player.kv.CollisionGroup = TRACE_COLLISION_GROUP_NONE

			// Remote_CallFunction_NonReplay( player, "ServerCallback_HotPotatoSpectator" )
			NSSendInfoMessageToPlayer( player, "You are now a spectator!" )
		}
		thread RemoveEarnMeter_Threaded( player )
	}
}

// check if there's only one player alive, if so, they win
void function HotPotatoPlayerKilled( entity player, entity attacker, var damageInfo )
{
	int i = 0
	foreach( entity p in GetPlayerArray() )
		if ( IsAlive(p) )
			i++

	// if this player is in file.activePlayers, lower file.alivePlayers by one and remove them from file.activePlayers
	if ( file.activePlayers.find( player ) != -1 )
	{
		file.alivePlayers--
		file.activePlayers.remove( file.activePlayers.find( player ) )
	}

	if ( file.alivePlayers == 1 )
		SetWinner( file.activePlayers[0].GetTeam() )
	else if (i == 0 || file.alivePlayers == 0)
		SetWinner( TEAM_UNASSIGNED )

	if ( player == file.marked ) // reset countdown etc if marked player suicides or disconnects
	{
		foreach ( entity p in GetPlayerArray() )
		{
			Highlight_ClearEnemyHighlight(p)
			Remote_CallFunction_NonReplay( p, "ServerCallback_ShowHotPotatoCountdown", Time() )
		}
		
		svGlobal.levelEnt.Signal( "OnMarkedDeath" )
		//foreach (entity p in GetPlayerArray())
		//	Remote_CallFunction_NonReplay( p, "ServerCallback_MarkedChanged", player.GetEncodedEHandle() )

		thread WaitBeforeMark()
	}
}

void function WaitBeforeMark()
{
	if ( GetGameState() != eGameState.Playing )
		return

	wait 10
	thread MarkRandomPlayer( GetRandomPlayer() )
}

// utility functions goes below here

entity function GetRandomPlayer()
{
	if ( GetPlayerArray().len() == 1 )
		return GetPlayerArray()[0]
	
	if ( file.activePlayers.len() <= 1 )
		return file.activePlayers[0]

	return file.activePlayers.getrandom()
}

void function RemoveEarnMeter_Threaded( entity player )
{
	WaitFrame()
	if ( IsValid( player ) )
		PlayerEarnMeter_SetMode( player, 0 ) // this hides the earn meter UI
}