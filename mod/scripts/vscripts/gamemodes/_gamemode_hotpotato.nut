global function GamemodeHotPotato_Init

struct
{
    bool firstmarked
    float hotpotatobegin
    float hotpotatoend
    entity marked
    array<entity> realplayers
    int aliveplayers
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
    AddCallback_OnClientDisconnected( HotPotatoPlayerDisconnected )
    AddCallback_GameStateEnter( eGameState.Playing, HotPotatoInit )

    AddDamageCallback( "player", MarkNewPlayer )
}

void function HotPotatoInit()
{
    file.hotpotatoend = GetCurrentPlaylistVarFloat( "hotpotato_timer", 30.0)
    thread HotPotatoInitCountdown()
}

void function HotPotatoInitCountdown()
{
    wait 10
    
	file.realplayers = GetPlayerArray()
	file.aliveplayers = GetPlayerArray().len()
    entity player = GetRandomPlayer()
    thread MarkRandomPlayer(player)
}

// give them a red outline to indicate they have the potato, also give them the ability to melee other players to pass the outline
void function MarkRandomPlayer(entity player)
{
	if (GetGameState() != eGameState.Playing)
		return
	
    if (!IsAlive(player) || !IsValid(player) )
    {
        thread MarkRandomPlayer( GetRandomPlayer() )
        return
    }

    file.hotpotatobegin = Time()

    foreach ( entity p in GetPlayerArray() )
    {
		Highlight_ClearEnemyHighlight(p)
	    Remote_CallFunction_NonReplay( p, "ServerCallback_ShowHotPotatoCountdown", file.hotpotatobegin + file.hotpotatoend )
        if( p != player )
	        Remote_CallFunction_NonReplay( p, "ServerCallback_AnnounceNewMark", player.GetEncodedEHandle() )
    }
    file.firstmarked = true

	Highlight_SetEnemyHighlight( player, "enemy_boss_bounty" ) // red outline
    file.marked = player
	Remote_CallFunction_NonReplay( player, "ServerCallback_PassedHotPotato")
    thread HotPotatoCountdown()
}

void function HotPotatoCountdown()
{
    // wait until Time() reaches file.hotpotatoend
    while ( Time() < file.hotpotatobegin + file.hotpotatoend )
    {
        wait 1
    }
    
    // kill player once timer runs out
    entity player = file.marked
    if (!IsValid(player) || !IsAlive(player))
    {
        wait 10
    	thread MarkRandomPlayer( GetRandomPlayer() )
        return
    }

    player.Die( null, null, { scriptType = DF_GIB } )
    wait 10
    thread MarkRandomPlayer( GetRandomPlayer() )
}

void function MarkNewPlayer( entity victim, var damageInfo )
{
    entity attacker = DamageInfo_GetAttacker( damageInfo )
    if (!IsValid(attacker) && !IsValid(victim) && victim == attacker)
        return

    float damage = DamageInfo_GetDamage( damageInfo )
    damage = 0
    DamageInfo_SetDamage( damageInfo, damage )

    if (attacker == file.marked)
    {
        file.marked = victim
        foreach ( entity p in GetPlayerArray() )
		    Highlight_ClearEnemyHighlight(p)
        Highlight_SetEnemyHighlight( victim, "enemy_boss_bounty" )
        SetRoundWinningKillReplayAttacker(attacker)
        attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )
		Remote_CallFunction_NonReplay( victim, "ServerCallback_PassedHotPotato")
    }
}

void function HotPotatoInitPlayer( entity player )
{
	UpdateHotPotatoLoadout( player )
}

void function HotPotatoPlayerDisconnected( entity player )
{
    //if this player was in file.realplayers we remove them from the array as well as lower file.aliveplayers by one
    if ( file.realplayers.find( player ) != -1 )
    {
        file.realplayers.remove( file.realplayers.find( player ) )
        file.aliveplayers--
    }
}

void function UpdateHotPotatoLoadout( entity player )
{
	if (IsAlive(player) && player != null)
	{
		// set loadout
		foreach ( entity weapon in player.GetMainWeapons() )
			player.TakeWeaponNow( weapon.GetWeaponClassName() )

		foreach ( entity weapon in player.GetOffhandWeapons() )
			player.TakeWeaponNow( weapon.GetWeaponClassName() )

        // check if this player is inside file.realplayers
        if (file.realplayers.find(player) != -1 || !file.firstmarked)
        {
		    player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [ "allow_as_primary" ])
		    player.GiveOffhandWeapon( "mp_ability_heal", OFFHAND_LEFT )
		    player.SetActiveWeaponByName( "melee_pilot_emptyhanded" )

            SyncedMelee_Disable( player )
        }
        else
        {
            // let them able to noclip, no collision group as well as be invisible
            player.SetPhysics( MOVETYPE_NOCLIP )
            player.kv.VisibilityFlags = 0
            player.SetTakeDamageType( DAMAGE_NO )
		    player.SetDamageNotifications( false )
		    player.kv.CollisionGroup = TRACE_COLLISION_GROUP_NONE
        }
	}
}

// check if there's only one player alive, if so, they win
void function HotPotatoPlayerKilled( entity player, entity attacker, var damageInfo )
{
    int i = 0
    foreach( entity p in GetPlayerArray() )
        if (IsAlive(p))
            i++
	// if this player is in file.realplayers, lower file.aliveplayers by one and remove them from file.realplayers
	if (file.realplayers.find(player) != -1)
	{
		file.aliveplayers--
		file.realplayers.remove(file.realplayers.find(player))
	}

    if (file.aliveplayers == 1)
        SetWinner( file.realplayers[0].GetTeam() )
    else if (i == 0 || file.aliveplayers == 0)
        SetWinner( TEAM_UNASSIGNED )

}

entity function GetRandomPlayer()
{
    if (GetPlayerArray().len() == 1)
        return GetPlayerArray()[0]
    
    return GetPlayerArray()[ RandomInt( GetPlayerArray().len() - 1 ) ]
}
