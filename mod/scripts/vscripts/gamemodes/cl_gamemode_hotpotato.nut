global function ClGamemodeHotPotato_Init
global function ServerCallback_ShowHotPotatoCountdown
global function ServerCallback_AnnounceNewMark
global function ServerCallback_PassedHotPotato

struct {
	var countdownRui
} file

void function ClGamemodeHotPotato_Init()
{
	ClGameState_RegisterGameStateAsset( $"ui/gamestate_info_lts.rpak" )
	ClGameState_RegisterGameStateAsset( $"ui/gamestate_info_ffa.rpak" )
	
	// add music for mode, this is copied directly from the ffa/fra music registered in cl_music.gnut
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_freeagents_intro", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_INTRO, "music_mp_freeagents_intro", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_freeagents_outro_win", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_WIN, "music_mp_freeagents_outro_win", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_freeagents_outro_lose", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_DRAW, "music_mp_freeagents_outro_lose", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_freeagents_outro_lose", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LOSS, "music_mp_freeagents_outro_lose", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_THREE_MINUTE, "music_mp_freeagents_almostdone", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_THREE_MINUTE, "music_mp_freeagents_almostdone", TEAM_MILITIA )

	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LAST_MINUTE, "music_mp_freeagents_lastminute", TEAM_IMC )
	RegisterLevelMusicForTeam( eMusicPieceID.LEVEL_LAST_MINUTE, "music_mp_freeagents_lastminute", TEAM_MILITIA )
}

void function ServerCallback_ShowHotPotatoCountdown( float endTime )
{
	file.countdownRui = CreateCockpitRui( $"ui/dropship_intro_countdown.rpak", 0 )
	RuiSetResolutionToScreenSize( file.countdownRui )
	RuiSetGameTime( file.countdownRui, "gameStartTime", endTime )
}

void function ServerCallback_AnnounceNewMark( int survivorEHandle )
{
    entity player = GetEntityFromEncodedEHandle( survivorEHandle )

	AnnouncementData announcement = Announcement_Create( Localize("#HOTPOTATO_NEWMARK", player.GetPlayerName() ) )
	Announcement_SetSubText( announcement, "#HOTPOTATO_RUN" )
	Announcement_SetTitleColor( announcement, <1,0,0> )
	Announcement_SetPurge( announcement, true )
	Announcement_SetPriority( announcement, 200 ) //Be higher priority than Titanfall ready indicator etc
	Announcement_SetSoundAlias( announcement, SFX_HUD_ANNOUNCE_QUICK )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_QUICK )
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}

void function ServerCallback_PassedHotPotato()
{
	entity localPlayer = GetLocalClientPlayer()
	StartParticleEffectOnEntity( localPlayer.GetCockpit(), GetParticleSystemIndex( $"P_MFD" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	EmitSoundOnEntity( localPlayer, "UI_InGame_MarkedForDeath_PlayerMarked"  )
	HideEventNotification()
	AnnouncementData announcement = Announcement_Create( "#HOTPOTATO_PASSED" )
	Announcement_SetTitleColor( announcement, <1,0,0> )
	Announcement_SetPurge( announcement, true )
	Announcement_SetPriority( announcement, 200 ) //Be higher priority than Titanfall ready indicator etc
	Announcement_SetSoundAlias( announcement, SFX_HUD_ANNOUNCE_QUICK )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_QUICK )
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}