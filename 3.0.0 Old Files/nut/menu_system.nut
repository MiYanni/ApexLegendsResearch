global function InitSystemMenu
global function InitSystemPanelMain
global function InitSystemPanel
global function UpdateSystemPanel

global function OpenSystemMenu

struct ButtonData
{
	string             label
	void functionref() activateFunc
}

struct
{
	var                    menu

	table<var, array<var> >            buttons
	table<var, array<ButtonData> > buttonDatas

	table<var, ButtonData > settingsButtonData
	table<var, ButtonData > leaveMatchButtonData
	table<var, ButtonData > exitButtonData
	table<var, ButtonData > lobbyReturnButtonData
	table<var, ButtonData > nullButtonData
	table<var, ButtonData > leavePartyData
	table<var, ButtonData > abandonMissionButtonData
} file

void function InitSystemMenu()
{
	var menu = GetMenu( "SystemMenu" )
	Hud_SetAboveBlur( menu, true )
	file.menu = menu

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnSystemMenu_Open )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, OnSystemMenu_Close )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, OnSystemMenu_NavigateBack )
}

void function InitSystemPanelMain( var panel )
{
	InitSystemPanel( panel )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	#if CONSOLE_PROG
	AddPanelFooterOption( panel, RIGHT, BUTTON_BACK, false, "#BUTTON_RETURN_TO_MAIN", "", ReturnToMain_OnActivate )
	#endif

	#if DEV
		AddPanelFooterOption( panel, LEFT, BUTTON_Y, true, "#Y_BUTTON_DEV_MENU", "#DEV_MENU", OpenDevMenu )
	#endif
}

void function InitSystemPanel( var panel )
{
	var menu = Hud_GetParent( panel )
	file.buttons[ panel ] <- GetElementsByClassname( menu, "SystemButtonClass" )
	file.buttonDatas[ panel ] <- []
	file.buttonDatas[ panel ].resize( file.buttons[ panel ].len() )

	ButtonData data

	file.nullButtonData[ panel ] <- clone data

	foreach ( index, button in file.buttons[ panel ] )
	{
		SetButtonData( panel, index, file.nullButtonData[ panel ] )
		Hud_AddEventHandler( button, UIE_CLICK, OnButton_Activate )
	}

	file.settingsButtonData[ panel ] <- clone data
	file.leaveMatchButtonData[ panel ] <- clone data
	file.exitButtonData[ panel ] <- clone data
	file.lobbyReturnButtonData[ panel ] <- clone data
	file.leavePartyData[ panel ] <- clone data
	file.abandonMissionButtonData[ panel ] <- clone data

	file.settingsButtonData[ panel ].label = "#SETTINGS"
	file.settingsButtonData[ panel ].activateFunc = OpenSettingsMenu

	file.leaveMatchButtonData[ panel ].label = "#LEAVE_MATCH"
	file.leaveMatchButtonData[ panel ].activateFunc = LeaveDialog

	file.exitButtonData[ panel ].label = "#EXIT_TO_DESKTOP"
	file.exitButtonData[ panel ].activateFunc = OpenConfirmExitToDesktopDialog

	file.lobbyReturnButtonData[ panel ].label = "#RETURN_TO_LOBBY"
	file.lobbyReturnButtonData[ panel ].activateFunc = LeaveDialog

	file.leavePartyData[ panel ].label = "#LEAVE_PARTY"
	file.leavePartyData[ panel ].activateFunc = LeavePartyDialog

	file.abandonMissionButtonData[ panel ].label = "#ABANDON_MISSION"
	file.abandonMissionButtonData[ panel ].activateFunc = LeaveDialog

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, SystemPanelShow )
}

void function SystemPanelShow( var panel )
{
	UpdateSystemPanel( panel )
}

void function OnSystemMenu_Open()
{
	SetBlurEnabled( true )
	ShowPanel( Hud_GetChild( file.menu, "SystemPanel" ) )
}


void function UpdateSystemPanel( var panel )
{
	foreach ( index, button in file.buttons[ panel ] )
		SetButtonData( panel, index, file.nullButtonData[ panel ] )

	int buttonIndex = 0
	if ( IsConnected() && !IsLobby() )
	{
		UISize screenSize = GetScreenSize()
		SetCursorPosition( <1920.0 * 0.5, 1080.0 * 0.5, 0> )

		SetButtonData( panel, buttonIndex++, file.settingsButtonData[ panel ] )
		SetButtonData( panel, buttonIndex++, file.leaveMatchButtonData[ panel ] )
	}
	else
	{
		if ( AmIPartyMember() || AmIPartyLeader() && GetPartySize() > 1 )
			SetButtonData( panel, buttonIndex++, file.leavePartyData[ panel ] )
		SetButtonData( panel, buttonIndex++, file.settingsButtonData[ panel ] )
		#if PC_PROG
			SetButtonData( panel, buttonIndex++, file.exitButtonData[ panel ] )
		#endif
	}
}

void function SetButtonData( var panel, int buttonIndex, ButtonData buttonData )
{
	file.buttonDatas[ panel ][buttonIndex] = buttonData

	var rui = Hud_GetRui( file.buttons[ panel ][buttonIndex] )
	RHud_SetText( file.buttons[ panel ][buttonIndex], buttonData.label )

	if ( buttonData.label == "" )
		Hud_SetVisible( file.buttons[ panel ][buttonIndex], false )
	else
		Hud_SetVisible( file.buttons[ panel ][buttonIndex], true )
}


void function OnSystemMenu_Close()
{
}


void function OnSystemMenu_NavigateBack()
{
	Assert( GetActiveMenu() == file.menu )
	CloseActiveMenu()
}


void function OnButton_Activate( var button )
{
	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()

	var panel = Hud_GetParent( button )

	int buttonIndex = int( Hud_GetScriptID( button ) )

	file.buttonDatas[ panel ][buttonIndex].activateFunc()
}

void function OpenSystemMenu()
{
	AdvanceMenu( file.menu )
}

void function OpenSettingsMenu()
{
	AdvanceMenu( GetMenu( "MiscMenu" ) )
}

#if CONSOLE_PROG
void function ReturnToMain_OnActivate( var button )
{
	ConfirmDialogData data
	data.headerText = "#EXIT_TO_MAIN"
	data.messageText = ""
	data.resultCallback = OnReturnToMainMenu
	//data.yesText = ["YES_RETURN_TO_TITLE_MENU", "#YES_RETURN_TO_TITLE_MENU"]

	OpenConfirmDialogFromData( data )
	AdvanceMenu( GetMenu( "ConfirmDialog" ) )
}

void function OnReturnToMainMenu( int result )
{
	if ( result == eDialogResult.YES )
		ClientCommand( "disconnect" )
}
#endif