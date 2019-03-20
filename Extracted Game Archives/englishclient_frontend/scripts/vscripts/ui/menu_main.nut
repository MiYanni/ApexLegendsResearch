global function InitMainMenu
//
global function LaunchMP
global function AttemptLaunch
global function GetUserSignInState
global function UpdateSignedInState

struct
{
	var menu
	var titleArt
	var subtitle
	var versionDisplay
	var signedInDisplay
	#if(PS4_PROG)
		bool chatRestrictionNoticeJustHandled = false
	#endif //
} file


void function InitMainMenu()
{
	var menu = GetMenu( "MainMenu" )
	file.menu = menu

	SetGamepadCursorEnabled( menu, false )

	AddMenuEventHandler( menu, eUIEvent.MENU_SHOW, OnMainMenu_Show )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, OnMainMenu_Close )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, OnMainMenu_NavigateBack )

	file.titleArt = Hud_GetChild( file.menu, "TitleArt" )
	var titleArtRui = Hud_GetRui( file.titleArt )
	RuiSetImage( titleArtRui, "basicImage", $"ui/menu/title_screen/title_art" )

	file.subtitle = Hud_GetChild( file.menu, "Subtitle" )
	var subtitleRui = Hud_GetRui( file.subtitle )
	RuiSetString( subtitleRui, "subtitleText", Localize( "#BATTLE_PASS_SEASON_NUMBER", 1 ).toupper() )

	file.versionDisplay = Hud_GetChild( menu, "VersionDisplay" )
	file.signedInDisplay = Hud_GetChild( menu, "SignInDisplay" )
}


void function OnMainMenu_Show()
{
	//
	int width = int( Hud_GetHeight( file.titleArt ) * 1.77777778 )
	Hud_SetWidth( file.titleArt, width )
	Hud_SetWidth( file.subtitle, width )

	Hud_SetText( file.versionDisplay, GetPublicGameVersion() )
	Hud_Show( file.versionDisplay )

	ActivatePanel( GetPanel( "MainMenuPanel" ) )

	Chroma_MainMenu()
}


void function OnMainMenu_Close()
{
	HidePanel( GetPanel( "MainMenuPanel" ) )
}


void function ActivatePanel( var panel )
{
	Assert( panel != null )

	array<var> elems = GetElementsByClassname( file.menu, "MainMenuPanelClass" )
	foreach ( elem in elems )
	{
		if ( elem != panel && Hud_IsVisible( elem ) )
			HidePanel( elem )
	}

	ShowPanel( panel )
}


void function OnMainMenu_NavigateBack()
{
	if ( IsSearchingForPartyServer() )
	{
		StopSearchForPartyServer( "", Localize( "#MAINMENU_CONTINUE" ) )
		return
	}

	#if(PC_PROG)
		OpenConfirmExitToDesktopDialog()
	#endif //
}


int function GetUserSignInState()
{
	#if(DURANGO_PROG)
		if ( Durango_InErrorScreen() )
		{
			return userSignInState.ERROR
		}
		else if ( Durango_IsSigningIn() )
		{
			return userSignInState.SIGNING_IN
		}
		else if ( !Console_IsSignedIn() && !Console_SkippedSignIn() )
		{
			//
			return userSignInState.SIGNED_OUT
		}

		Assert( Console_IsSignedIn() || Console_SkippedSignIn() )
	#endif
	return userSignInState.SIGNED_IN
}


void function UpdateSignedInState()
{
	#if(DURANGO_PROG)
		if ( Console_IsSignedIn() )
		{
			Hud_SetText( file.signedInDisplay, Localize( "#SIGNED_IN_AS_N", Durango_GetGameDisplayName() ) )
			return
		}
	#endif
	Hud_SetText( file.signedInDisplay, "" )
}

void function LaunchMP()
{
	uiGlobal.launching = eLaunching.MULTIPLAYER
	AttemptLaunch()
}


void function AttemptLaunch()
{
	if ( uiGlobal.launching == eLaunching.FALSE )
		return
	Assert( uiGlobal.launching == eLaunching.MULTIPLAYER ||	uiGlobal.launching == eLaunching.MULTIPLAYER_INVITE )

	#if(CONSOLE_PROG)
		if ( !IsEULAAccepted() )
		{
			if ( GetActiveMenu() == GetMenu( "EULADialog" ) )
				return

			if ( IsDialog( GetActiveMenu() ) )
				CloseActiveMenu( true )

			if ( GetUserSignInState() != userSignInState.SIGNED_IN )
				return

			OpenEULADialog( false )
			return
		}
	#endif //

	#if(PS4_PROG)
		//
		//
		if ( !file.chatRestrictionNoticeJustHandled )
		{
			thread PS4_ChatRestrictionNotice()
			return
		}
	#endif //

	if ( !IsIntroViewed() )
	{
		if ( GetActiveMenu() == GetMenu( "PlayVideoMenu" ) )
			return

		if ( IsDialog( GetActiveMenu() ) )
			CloseActiveMenu( true )

		PlayVideoMenu( "intro", "Apex_Opening_Movie", true, PrelaunchValidateAndLaunch )
		return
	}

	StartSearchForPartyServer()

	uiGlobal.launching = eLaunching.FALSE
	#if(PS4_PROG)
		file.chatRestrictionNoticeJustHandled = false
	#endif //
}


#if(PS4_PROG)
void function PS4_ChatRestrictionNotice()
{
	Plat_ShowChatRestrictionNotice()
	while ( Plat_IsSystemMessageDialogOpen() )
		WaitFrame()

	file.chatRestrictionNoticeJustHandled = true
	PrelaunchValidateAndLaunch()
}
#endif //
