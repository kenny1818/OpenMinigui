/*----------------------------------------------------------------------------
MINIGUI - Harbour Win32 GUI library source code

Copyright 2002-2010 Roberto Lopez <harbourminigui@gmail.com>
http://harbourminigui.googlepages.com/

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along with
   this software; see the file COPYING. If not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA (or
   visit the web site http://www.gnu.org/).

   As a special exception, you have permission for additional uses of the text
   contained in this release of Harbour Minigui.

   The exception is that, if you link the Harbour Minigui library with other
   files to produce an executable, this does not by itself cause the resulting
   executable to be covered by the GNU General Public License.
   Your use of that executable is in no way restricted on account of linking the
   Harbour-Minigui library code into it.

   Parts of this project are based upon:

   "Harbour GUI framework for Win32"
   Copyright 2001 Alexander S.Kresin <alex@kresin.ru>
   Copyright 2001 Antonio Linares <alinares@fivetech.com>
   www - https://harbour.github.io/

   "Harbour Project"
   Copyright 1999-2026, https://harbour.github.io/

   "WHAT32"
   Copyright 2002 AJ Wos <andrwos@aust1.net>

   "HWGUI"
   Copyright 2001-2021 Alexander S.Kresin <alex@kresin.ru>

 ---------------------------------------------------------------------------*/

#include "minigui.ch"

// Win32 common control definitions for status bars
#define ID_STATUSBAR    0
#define SB_SETTEXT      (WM_USER+1)
#define SBT_OWNERDRAW   0x1000

// Internal control class name and system object identifiers
#define ITEMTYPENAME    "ITEMMESSAGE"
#define ITEMNAME        "StatusItem"
#define PROGRESSNAME    "ProgressMessage"

// Map Unicode-aware string search function hb_UAt to At for legacy xHarbour/Harbour
#if defined( __XHARBOUR__ ) .OR. ( __HARBOUR__ - 0 < 0x030200 )
#xtranslate hb_UAt( <c>, <n> ) => At( <c>, <n> )
#endif

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _BeginMessageBar
 *
 * Purpose:
 *    Initializes and begins the creation sequence for a status bar (message bar)
 *    control associated with a parent window.
 *
 * Parameters:
 *    ControlName : Character - Identifier name for the new status bar control.
 *    ParentForm  : Character - Name of the parent window. Defaults to active window if NIL.
 *    kbd         : Logical   - Flag indicating whether to append standard keyboard indicator panels.
 *    FontName    : Character - Name of the font face for text rendering.
 *    FontSize    : Numeric   - Size of the font in points.
 *    Bold        : Logical   - Flag for bold font weight.
 *    Italic      : Logical   - Flag for italic font style.
 *    UnderLine   : Logical   - Flag for underline font style.
 *    StrikeOut   : Logical   - Flag for strikeout font style.
 *    Message     : Character - Initial text message to display in the main panel.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Creates the underlying Win32 status bar control window.
 *    - Registers control in global internal arrays (_HMG_aControl*).
 *    - Sets active status bar global state variables (_HMG_ActiveMessageBarName, _HMG_ActiveStatusHandle).
 */
FUNCTION _BeginMessageBar( ControlName, ParentForm, kbd, ;
                           FontName, FontSize, Bold, Italic, ;
                           UnderLine, StrikeOut, Message )
*-----------------------------------------------------------------------------*

   LOCAL hParent
   LOCAL hControl
   LOCAL hFont
   LOCAL aRect := { 0, 0, 0, 0 }
   LOCAL nIndex

   // Set global active message bar name for subsequent item additions
   _HMG_ActiveMessageBarName := ControlName

   // Default to currently active window definition if parent is not specified
   IF ParentForm == NIL
      ParentForm := _HMG_ActiveFormName
   ENDIF

   // Validate existence of parent form and ensure control name uniqueness
   IF ! _IsWindowDefined( ParentForm )
      MsgMiniGuiError( "Window: " + ParentForm + " is not defined." )
   ENDIF

   IF _IsControlDefined( ControlName, ParentForm )
      MsgMiniGuiError( ;
         "Control: " + ControlName + ;
         " Of " + ParentForm + ;
         " Already defined." )
   ENDIF

   // Retrieve handle of pre-defined font if available
   hFont := GetFontHandle( FontName )

   IF hFont != 0
      // Extract existing font parameters to synchronize style attributes
      GetFontParamByRef( ;
         hFont, ;
         @FontName, ;
         @FontSize, ;
         @Bold, ;
         @Italic, ;
         @UnderLine, ;
         @StrikeOut )
   ENDIF

   // Inherit active window font attributes when defined inside a window context
   IF _HMG_BeginWindowActive
      __defaultNIL( @FontName, _HMG_ActiveFontName )
      __defaultNIL( @FontSize, _HMG_ActiveFontSize )
   ENDIF

   // Obtain Win32 handle for parent form and create native status bar control
   hParent := GetFormHandle( ParentForm )
   hControl := InitMessageBar( hParent, ID_STATUSBAR )

   _HMG_ActiveStatusHandle := hControl

   // Apply existing font handle or construct a new GDI font object
   IF hFont != 0
      _SetFontHandle( hControl, hFont )
   ELSE
      // Fall back to system default GUI font configuration
      __defaultNIL( @FontName, _HMG_DefaultFontName )
      __defaultNIL( @FontSize, _HMG_DefaultFontSize )

      hFont := _SetFont( ;
         hControl, ;
         FontName, ;
         FontSize, ;
         Bold, ;
         Italic, ;
         UnderLine, ;
         StrikeOut )
   ENDIF

   // Query client rect to store initial control dimensions
   GetClientRect( hControl, aRect )

   // Register status bar in HMG internal control tracking tables
   nIndex := _RegisterControl( ;
             ControlName, ;
             ParentForm, ;
             hParent, ;
             hControl, ;
             "MESSAGEBAR", ;
             ID_STATUSBAR )

   // Populate control state arrays with dimensions and font configuration
   _HMG_aControlValue[ nIndex ] := Message

   _HMG_aControlWidth[ nIndex ] := aRect[3]
   _HMG_aControlHeight[ nIndex ] := aRect[4]

   _HMG_aControlFontName[ nIndex ] := FontName
   _HMG_aControlFontSize[ nIndex ] := FontSize

   _HMG_aControlFontHandle[ nIndex ] := hFont
   _HMG_aControlFontAttributes[ nIndex ] := { Bold, Italic, UnderLine, StrikeOut }

   // Reset item counter for child panel definitions
   _HMG_StatusItemCount := 0

   // Append standard keyboard status panels (Num, Caps, Scroll) if requested
   IF kbd
      _SetStatusBarKbd( ControlName, ParentForm )
   ENDIF

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _EndMessageBar
 *
 * Purpose:
 *    Finalizes the status bar definition, ensuring default items and progress
 *    controls are properly configured and laid out.
 *
 * Parameters:
 *    None
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - May define a default status bar item if no panels were added.
 *    - Refreshes position/size of any embedded progress bar control.
 *    - Resets active status bar tracking globals.
 */
FUNCTION _EndMessageBar()
*-----------------------------------------------------------------------------*
   LOCAL ParentForm
   LOCAL i

   IF _HMG_BeginWindowActive
      ParentForm := _HMG_ActiveFormName
      i := GetControlIndex ( _HMG_ActiveMessageBarName, ParentForm )
#ifdef _HMG_COMPAT_
   ELSE
      // Handle legacy/compatibility mode outside window definition block
      i := GetControlIndexByHandle ( _HMG_ActiveStatusHandle )
      ParentForm := GetParentFormName( i )
#endif
   ENDIF

   // Ensure status bar has at least one panel to prevent rendering anomalies
   IF _HMG_StatusItemCount == 0 
      _DefineItemMessage( ITEMNAME, _HMG_ActiveMessageBarName, 0, 0, ;
         hb_defaultValue( _HMG_aControlValue[ i ], GetProperty( ParentForm, "Title" ) ), , , 0, , , , .F. )
   ENDIF

   // Recalculate dimensions and refresh layout for embedded progress bar if present
   IF ( i := GetControlIndex( PROGRESSNAME, ParentForm ) ) != 0
      RefreshProgressItem( _HMG_aControlMiscData1[ i, 1 ], _HMG_aControlHandles[ i ], _HMG_aControlMiscData1[ i, 2 ] )
   ENDIF

   // Clear active status bar context globals
   _HMG_ActiveMessageBarName := ""
   _HMG_StatusItemCount := 0

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * STATIC FUNCTION _RegisterControl
 *
 * Purpose:
 *    Allocates an entry in HMG global control arrays and populates default
 *    properties for a new control instance.
 *
 * Parameters:
 *    cControlName : Character - Identifier name of the control.
 *    cParentForm  : Character - Identifier name of the parent window.
 *    hParentForm  : Numeric   - Win32 handle of the parent window.
 *    hControl     : Numeric   - Win32 handle of the control.
 *    cType        : Character - HMG internal control type string.
 *    nId          : Numeric   - Control resource/command identifier.
 *
 * Return:
 *    Numeric - Index of the registered control in HMG internal arrays.
 *
 * Side Effects:
 *    - Allocates dynamic memory in global arrays (_HMG_aControl*).
 *    - Declares a global reference variable for the control index.
 *    - Invokes OOP control initialization callback if OOP mode is enabled.
 */
STATIC FUNCTION _RegisterControl( cControlName, cParentForm, hParentForm, ;
                                  hControl, cType, nId )
*-----------------------------------------------------------------------------*

   LOCAL cVarName
   LOCAL k

   // Reserve a free slot in HMG internal parallel tracking arrays
   k := _GetControlFree()

   // Construct global handle variable identifier name
   cVarName := "_" + cParentForm + "_" + cControlName

#ifdef _NAMES_LIST_

   _SetNameList( cVarName, k )

#else

   PUBLIC &cVarName. := k

#endif

   // Assign core identifying handles and control parameters
   _HMG_aControlType[ k ]              := cType
   _HMG_aControlNames[ k ]             := cControlName
   _HMG_aControlHandles[ k ]           := hControl
   _HMG_aControlParentHandles[ k ]     := hParentForm
   _HMG_aControlIds[ k ]               := nId

   // Initialize event handlers, state flags, and formatting properties
   _HMG_aControlProcedures[ k ]        := ""
   _HMG_aControlPageMap[ k ]           := {}

   _HMG_aControlValue[ k ]             := NIL

   _HMG_aControlInputMask[ k ]         := ""

   _HMG_aControlLostFocusProcedure[ k ] := ""
   _HMG_aControlGotFocusProcedure[ k ]  := ""
   _HMG_aControlChangeProcedure[ k ]    := ""

   _HMG_aControlDeleted[ k ]           := .F.

   _HMG_aControlBkColor[ k ]           := NIL
   _HMG_aControlFontColor[ k ]         := NIL

   _HMG_aControlDblClick[ k ]          := ""
   _HMG_aControlHeadClick[ k ]         := {}

   _HMG_aControlRow[ k ]               := 0
   _HMG_aControlCol[ k ]               := 0

   _HMG_aControlWidth[ k ]             := 0
   _HMG_aControlHeight[ k ]            := 0

   _HMG_aControlSpacing[ k ]           := 0

   _HMG_aControlContainerRow[ k ]      := -1
   _HMG_aControlContainerCol[ k ]      := -1

   _HMG_aControlPicture[ k ]           := ""

   _HMG_aControlContainerHandle[ k ]   := 0

   _HMG_aControlFontName[ k ]          := ""
   _HMG_aControlFontSize[ k ]          := 0
   _HMG_aControlFontAttributes[ k ]    := { .F., .F., .F., .F. }
   _HMG_aControlToolTip[ k ]           := ""

   _HMG_aControlRangeMin[ k ]          := 0
   _HMG_aControlRangeMax[ k ]          := 0

   _HMG_aControlCaption[ k ]           := ""

   _HMG_aControlVisible[ k ]           := .T.

   _HMG_aControlHelpId[ k ]            := 0

   _HMG_aControlFontHandle[ k ]        := 0
   _HMG_aControlBrushHandle[ k ]       := 0

   _HMG_aControlEnabled[ k ]           := .T.

   _HMG_aControlMiscData1[ k ]         := 0
   _HMG_aControlMiscData2[ k ]         := ""

   // Trigger object-oriented framework integration hook if active
   IF _HMG_lOOPEnabled
      Eval( _HMG_bOnControlInit, k, cVarName )
   ENDIF

RETURN k

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _DefineItemMessage
 *
 * Purpose:
 *    Defines and appends an individual message panel (status item) to a status bar.
 *
 * Parameters:
 *    ControlName   : Character - Identifier name for the panel item.
 *    ParentControl : Character - Identifier name of the status bar container.
 *    x             : Numeric   - Horizontal coordinate offset (reserved).
 *    y             : Numeric   - Vertical coordinate offset (reserved).
 *    Caption       : Character - Text string displayed inside the panel.
 *    ProcedureName : Character/Block - Event procedure or block executed on click.
 *    w             : Numeric   - Width of the panel in pixels. Auto-sized if NIL.
 *    h             : Numeric   - Height of the panel in pixels (reserved).
 *    Icon          : Character - Icon resource name or filename.
 *    cStyl         : Character - Visual style designation ("RAISED", "FLAT", or standard).
 *    ToolTip       : Character - Tooltip string for the status panel.
 *    Default       : Logical   - Sets caption as default window message if .T.
 *    BackColor     : Array     - RGB array `{R,G,B}` for custom background color.
 *    FontColor     : Array     - RGB array `{R,G,B}` for custom text color.
 *    Align         : Numeric   - Text alignment (0 = Left, 1 = Center, 2 = Right).
 *
 * Return:
 *    Numeric - Win32 handle of the status item panel.
 *
 * Side Effects:
 *    - Appends a new panel to the Win32 status bar control.
 *    - Registers item in internal HMG control tracking arrays.
 *    - Registers accelerator hotkey if caption contains an ampersand (&).
 *    - Switches panel to owner-draw mode if custom colors are assigned.
 */
FUNCTION _DefineItemMessage( ControlName, ParentControl, x, y, Caption, ;
                             ProcedureName, w, h, Icon, cStyl, ;
                             ToolTip, Default, BackColor, ;
                             FontColor, Align )
*-----------------------------------------------------------------------------*

   LOCAL hControl
   LOCAL hParentForm
   LOCAL hStatusBar
   LOCAL cParentForm
   LOCAL ParentForm
   LOCAL cCaption
   LOCAL nIndex
   LOCAL nHotPos

   // Resolve parent form context
   IF _HMG_BeginWindowActive
      ParentForm := _HMG_ActiveFormName
#ifdef _HMG_COMPAT_
   ELSE
      nHotPos   := GetControlIndexByHandle( _HMG_ActiveStatusHandle )
      ParentForm := GetParentFormName( nHotPos )
#endif
   ENDIF

   IF ! _IsWindowDefined( ParentForm )
      MsgMiniGuiError( "Window: " + ParentForm + " is not defined." )
   ENDIF

   // Fall back to current active message bar if parent control is omitted
   IF ParentControl == NIL
      ParentControl := _HMG_ActiveMessageBarName
   ENDIF

   cParentForm := ParentForm
   hParentForm := GetFormHandle( ParentForm )
   hStatusBar := GetControlHandle( ParentControl, ParentForm )

   // Auto-calculate panel width based on text extent if width parameter is missing
   IF w == NIL
      w := Max( ;
         70, ;
         GetTextWidth( ;
            NIL, ;
            Caption, ;
            _HMG_aControlFontHandle[ ;
               GetControlIndex( ParentControl, cParentForm ) ;
            ] ;
         ) + 6 )
   ENDIF

   // Register keyboard shortcut if caption contains an accelerator prefix (&)
   IF ! Empty( ProcedureName )
      cCaption := Upper( Caption )
      nHotPos := hb_UAt( "&", cCaption )

      IF nHotPos > 0
         _DefineLetterOrDigitHotKey( ;
            cCaption, ;
            nHotPos, ;
            cParentForm, ;
            ProcedureName )
      ENDIF
      // Strip accelerator character for presentation
      Caption := StrTran( Caption, "&", "" )
   ENDIF

   // Assign default message global variable if requested
   IF hb_defaultValue( Default, .F. )
      _HMG_DefaultStatusBarMessage := Caption
   ENDIF

   // Adjust dimensions for first item vs subsequent items in native Win32 layout
   IF ++_HMG_StatusItemCount == 1
      w := 0
      h := 0
   ELSE
      h := 1
   ENDIF

   hb_default( @cStyl, "" )

   // Create status bar panel using C-level Win32 API wrapper
   hControl := InitItemBar( ;
      hStatusBar, ;
      Caption, ;
      0, ;
      w, ;
      h, ;
      Icon, ;
      ToolTip, ;
      iif( ;
         Upper( cStyl ) == "RAISED", ;
         1, ;
         iif( Upper( cStyl ) == "FLAT", 2, 0 ) ;
      ) )

   // Register panel item in HMG global control tracking arrays
   nIndex := _RegisterControl( ;
             ControlName, ;
             cParentForm, ;
             hParentForm, ;
             hControl, ;
             ITEMTYPENAME, ;
             0 )

   _HMG_aControlProcedures[ nIndex ] := ProcedureName

   _HMG_aControlBkColor[ nIndex ] := BackColor
   _HMG_aControlFontColor[ nIndex ] := FontColor

   _HMG_aControlRow[ nIndex ] := y
   _HMG_aControlCol[ nIndex ] := x

   _HMG_aControlWidth[ nIndex ] := w
   _HMG_aControlHeight[ nIndex ] := h
   _HMG_aControlSpacing[ nIndex ] := hb_defaultValue( Align, 0 )
   _HMG_aControlContainerHandle[ nIndex ] := hStatusBar

   _HMG_aControlToolTip[ nIndex ] := ToolTip

   _HMG_aControlCaption[ nIndex ] := Caption

   // Ensure default font color for aligned items
   IF _HMG_aControlSpacing[ nIndex ] > 0 .AND. ;
      _HMG_aControlFontColor[ nIndex ] == NIL
      FontColor := BLACK
      _HMG_aControlFontColor[ nIndex ] := FontColor
   ENDIF

   // Enable owner-draw mode when custom background or font colors are specified
   IF IsArrayRGB( BackColor ) .OR. ;
      IsArrayRGB( FontColor )

      SendMessage( ;
         hStatusBar, ;
         SB_SETTEXT, ;
         hb_bitOr( _HMG_StatusItemCount - 1, SBT_OWNERDRAW ), ;
         0 )

   ENDIF

RETURN hControl

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusClock
 *
 * Purpose:
 *    Creates a clock panel in the status bar that automatically updates time
 *    display every second via a dedicated timer.
 *
 * Parameters:
 *    BarName   : Character - Name of the target status bar control.
 *    FormName  : Character - Name of the parent window.
 *    Width     : Numeric   - Width of the clock panel in pixels.
 *    ToolTip   : Character - Tooltip text for the clock panel.
 *    Action    : Character/Block - Event procedure or block executed on click.
 *    lAMPM     : Logical   - Use 12-hour AM/PM format if .T., else 24-hour format.
 *    BackColor : Array     - RGB background color `{R,G,B}`.
 *    FontColor : Array     - RGB text color `{R,G,B}`.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Creates a status bar item named "TimerBar".
 *    - Creates an active system timer "StatusTimer" set to a 1000ms interval.
 */
FUNCTION _SetStatusClock( BarName, FormName, Width, ToolTip, ;
                          Action, lAMPM, BackColor, FontColor )
*-----------------------------------------------------------------------------*

   LOCAL nItem

   hb_default( @lAMPM, .F. )
   __defaultNIL( @Width,   iif( lAMPM, 92, 70 ) )
   __defaultNIL( @ToolTip, "" )
   __defaultNIL( @Action,  "" )

   // Create status bar item to display formatted system time
   nItem := _DefineItemMessage( ;
      "TimerBar", ;
      BarName, ;
      0, ;
      0, ;
      iif( lAMPM, AMPM( Time() ), Time() ), ;
      Action, ;
      Width, ;
      0, ;
      , ;
      "", ;
      ToolTip, ;
      , ;
      BackColor, ;
      FontColor, ;
      1 )

#ifdef _HMG_COMPAT_
   // Identify parent form outside active window definition scope
   IF ! _HMG_BeginWindowActive
      FormName := ;
         GetParentFormName( ;
            GetControlIndexByHandle( _HMG_ActiveStatusHandle ) )
   ENDIF
#endif

   // Define periodic timer to refresh clock display every second
   _DefineTimer( ;
      "StatusTimer", ;
      FormName, ;
      1000, ;
      {|| ;
         _SetItem( ;
            BarName, ;
            FormName, ;
            nItem, ;
            iif( lAMPM, AMPM( Time() ), Time() ) ;
         ) ;
      } )

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusKeybrd
 *
 * Purpose:
 *    Adds graphical LED indicators for NumLock, CapsLock, and Insert keys
 *    to the status bar with automatic state polling.
 *
 * Parameters:
 *    BarName  : Character - Name of the target status bar control.
 *    FormName : Character - Name of the parent window.
 *    Width    : Numeric   - Base panel width for each key indicator.
 *    ToolTip  : Character - Tooltip text for the key panels.
 *    Action   : Character/Block - Custom action when an indicator is clicked.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Defines status panels "TimerNum", "TimerCaps", and "TimerInsert".
 *    - Creates an active system timer "StatusKeyBrd" set to a 250ms interval.
 */
FUNCTION _SetStatusKeybrd( BarName, FormName, Width, ToolTip, Action )
*-----------------------------------------------------------------------------*

   LOCAL nNumLock
   LOCAL nCapsLock
   LOCAL nInsert
   LOCAL bAction

   __defaultNIL( @Width,   75 )
   __defaultNIL( @ToolTip, "" )
   __defaultNIL( @Action,  "" )

   // Create NumLock status panel with click-toggle handler
   bAction := iif( Empty( Action ), {|| KeyTogglePlatform( VK_NUMLOCK ) }, Action )
   nNumLock := _DefineItemMessage( "TimerNum", BarName, 0, 0, "NumLock", bAction, Width + 20, 0, ;
      iif( IsNumLockActive(), "zzz_led_on", "zzz_led_off" ), "", ToolTip )

   // Create CapsLock status panel with click-toggle handler
   bAction := iif( Empty( Action ), {|| KeyTogglePlatform( VK_CAPITAL ) }, Action )
   nCapsLock := _DefineItemMessage( "TimerCaps", BarName, 0, 0, "CapsLock", bAction, Width + 25, 0, ;
      iif( IsCapsLockActive(), "zzz_led_on", "zzz_led_off" ), "", ToolTip )

   // Create Insert status panel with click-toggle handler
   bAction := iif( Empty( Action ), {|| KeyTogglePlatform( VK_INSERT ) }, Action )
   nInsert := _DefineItemMessage( "TimerInsert", BarName, 0, 0, "Insert", bAction, Width, 0, ;
      iif( IsInsertActive(), "zzz_led_on", "zzz_led_off" ), "", ToolTip )

#ifdef _HMG_COMPAT_
   // Resolve parent form handle outside active window declaration context
   IF ! _HMG_BeginWindowActive
      FormName := GetParentFormName( GetControlIndexByHandle( _HMG_ActiveStatusHandle ) )
   ENDIF
#endif

   // Define timer to poll keyboard state every 250ms and update icon displays
   _DefineTimer( ;
      "StatusKeyBrd", ;
      FormName, ;
      250, ;
      {|| ;
         _SetStatusIcon( BarName, FormName, nNumLock, iif( IsNumLockActive(), "zzz_led_on", "zzz_led_off" ) ), ;
         _SetStatusIcon( BarName, FormName, nCapsLock, iif( IsCapsLockActive(), "zzz_led_on", "zzz_led_off" ) ), ;
         _SetStatusIcon( BarName, FormName, nInsert, iif( IsInsertActive(), "zzz_led_on", "zzz_led_off" ) ) ;
      } )

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION KeyTogglePlatform
 *
 * Purpose:
 *    Toggles the toggle state (e.g. NumLock, CapsLock) of a virtual key in
 *    an OS platform-compatible manner.
 *
 * Parameters:
 *    nKeyCode : Numeric - Win32 virtual key code (e.g., VK_NUMLOCK, VK_CAPITAL).
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Synthesizes key press/release events to toggle keyboard hardware state.
 */
FUNCTION KeyTogglePlatform( nKeyCode )
*-----------------------------------------------------------------------------*
   // Use NT key event API on Windows XP or newer platforms
   IF _HMG_IsXPorLater
      KeyToggleNT( nKeyCode )
   ELSE
      KeyToggle( nKeyCode )
   ENDIF

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _IsOwnerDrawStatusBarItem
 *
 * Purpose:
 *    Checks if a status bar item uses owner-draw rendering (custom colors)
 *    and optionally updates or returns item control metadata.
 *
 * Parameters:
 *    ParentHandle : Numeric - Win32 handle of the parent status bar.
 *    ItemID       : Numeric - 1-based index of the status bar item panel.
 *    Value        : Mixed   - Pass-by-reference output/input value (caption or control index).
 *    lSet         : Logical - If .T., assigns Value to item caption; else returns index in Value.
 *
 * Return:
 *    Logical - .T. if the status bar item is owner-drawn, .F. otherwise.
 *
 * Side Effects:
 *    - May update `_HMG_aControlCaption` array entry when `lSet` is .T.
 */
FUNCTION _IsOwnerDrawStatusBarItem( ParentHandle, ItemID, Value, lSet )
*-----------------------------------------------------------------------------*
   LOCAL h
   LOCAL nLocID := 0
   LOCAL lOwnerDraw := .F.
   LOCAL i

   hb_default( @lSet, .F. )

   IF Empty( ItemID ) .OR. ItemID == NIL
      ItemID := 1
   ENDIF

   // Search container handle registry for matching status bar panel index
   FOR EACH h IN _HMG_aControlContainerHandle

      i := hb_enumindex( h )

      IF h == ParentHandle .AND. _HMG_aControlType[ i ] == ITEMTYPENAME

         IF ++nLocID == ItemID
            // Item is owner-drawn if background or font colors are explicitly defined
            IF ( lOwnerDraw := ( _HMG_aControlBkColor[ i ] != NIL .OR. _HMG_aControlFontColor[ i ] != Nil ) )
               IF lSet
                  _HMG_aControlCaption[ i ] := Value
               ELSE
                  Value := i
               ENDIF
            ENDIF

            EXIT

         ENDIF

      ENDIF

   NEXT

RETURN lOwnerDraw

// Keyboard indicator panel width constants
#define KBD_CAPS_WIDTH    38
#define KBD_NUMLOCK_WIDTH 42
#define KBD_SCROLL_WIDTH  44

*-----------------------------------------------------------------------------*
/*
 * STATIC FUNCTION AMPM
 *
 * Purpose:
 *    Converts a 24-hour time string ("HH:MM:SS") into 12-hour format with
 *    "am" or "pm" suffix.
 *
 * Parameters:
 *    cTime : Character - 24-hour time string.
 *
 * Return:
 *    Character - Formatted 12-hour time string with am/pm indicator.
 *
 * Side Effects:
 *    None
 */
STATIC FUNCTION AMPM( cTime )
*-----------------------------------------------------------------------------*
   LOCAL nHour := Val( cTime )

   // Convert hour value and append 12-hour meridian designation
   DO CASE
   CASE nHour == 0 .OR. nHour == 24
      cTime := "12" + SubStr( cTime, 3 ) + " am"
   CASE nHour < 12
      cTime += " am"
   CASE nHour == 12
      cTime += " pm"
   OTHERWISE
      cTime := StrZero( nHour - 12, 2 ) + SubStr( cTime, 3 ) + " pm"
   ENDCASE

RETURN cTime

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusBarKbd
 *
 * Purpose:
 *    Appends text-based keyboard status indicators (CAP, NUM, SCRL) to a status
 *    bar and starts a periodic timer to update their active highlight colors.
 *
 * Parameters:
 *    BarName  : Character - Name of the target status bar control.
 *    FormName : Character - Name of the parent window.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Creates four status panels (main message item and three key state indicators).
 *    - Creates an active system timer "StatusBarKbd" with 250ms polling interval.
 */
FUNCTION _SetStatusBarKbd ( BarName, FormName )
*-----------------------------------------------------------------------------*
   LOCAL i := GetControlIndex ( BarName, FormName )
   LOCAL hWnd := GetFormHandle( FormName )

   // Define primary message panel, defaulting to window title if value is empty
   _DefineItemMessage ( ITEMNAME, BarName, 0, 0, ;
      hb_defaultValue( _HMG_aControlValue[ i ], GetProperty ( FormName, "Title" ) ), , , 0, , "RAISED" )

   // Define text panels for CapsLock, NumLock, and ScrollLock indicators
   _DefineItemMessage ( ITEMNAME, BarName, 0, 0, "CAP", , iif( _HMG_IsThemed, KBD_CAPS_WIDTH, KBD_CAPS_WIDTH - 2 ), 0, , , , , , SILVER )

   _DefineItemMessage ( ITEMNAME, BarName, 0, 0, "NUM", , KBD_NUMLOCK_WIDTH, 0, , , , , , SILVER )

   _DefineItemMessage ( ITEMNAME, BarName, 0, 0, "SCRL", , KBD_SCROLL_WIDTH, 0, , , , , , SILVER )

   // Define timer to poll key states every 250ms and set text color (Black = active, Silver = inactive)
   _DefineTimer ( "StatusBarKbd", FormName, 250, ;
      {|| ;
         _SetStatusItemProperty( 2, iif( IsCapsLockActive(), BLACK, SILVER ), hWnd, STATUS_ITEM_FONTCOLOR ), ;
         _SetStatusItemProperty( 3, iif( IsNumLockActive(), BLACK, SILVER ), hWnd, STATUS_ITEM_FONTCOLOR ), ;
         _SetStatusItemProperty( 4, iif( IsScrollLockActive(), BLACK, SILVER ), hWnd, STATUS_ITEM_FONTCOLOR ) ;
      } )

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _GetStatusItemWidth
 *
 * Purpose:
 *    Retrieves the width of a specific status bar item panel or an array of
 *    all panel widths for a parent window.
 *
 * Parameters:
 *    hWnd  : Numeric - Win32 handle of the parent form.
 *    nItem : Numeric - 1-based item panel index. Returns array of widths if NIL.
 *
 * Return:
 *    Numeric | Array - Width in pixels of requested panel or array of all widths.
 *
 * Side Effects:
 *    None
 */
FUNCTION _GetStatusItemWidth( hWnd, nItem )
*-----------------------------------------------------------------------------*
   LOCAL h
   LOCAL aItemWidth := {}
   LOCAL i

   // Iterate parent handle registrations to accumulate item panel widths
   FOR EACH h IN _HMG_aControlParentHandles

      i := hb_enumindex( h )

      IF _HMG_aControlType[ i ] == ITEMTYPENAME .AND. h == hWnd
         AAdd( aItemWidth, _HMG_aControlWidth[ i ] )
      ENDIF

   NEXT

RETURN iif( nItem == NIL, aItemWidth, aItemWidth[ hb_defaultValue( nItem, 1 ) ] )

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusItemProperty
 *
 * Purpose:
 *    Modifies a property (width, action, background color, text color, or alignment)
 *    for a specified status bar item panel and updates the display.
 *
 * Parameters:
 *    nItem : Numeric - 1-based index of the status bar item panel.
 *    Value : Mixed   - New property value to apply.
 *    hWnd  : Numeric - Win32 handle of the parent form.
 *    nType : Numeric - Property selector constant (e.g. STATUS_ITEM_WIDTH, STATUS_ITEM_FONTCOLOR).
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Updates HMG internal control property tracking arrays.
 *    - Triggers redraw of status bar item when visual properties are modified.
 */
FUNCTION _SetStatusItemProperty( nItem, Value, hWnd, nType )
*-----------------------------------------------------------------------------*
   LOCAL h
   LOCAL FormName
   LOCAL nIndex := 0
   LOCAL i

   // Scan parent handle array for matching status bar item panel
   FOR EACH h IN _HMG_aControlParentHandles

      i := hb_enumindex( h )

      IF _HMG_aControlType[ i ] == ITEMTYPENAME .AND. h == hWnd

         IF ++nIndex == nItem

            SWITCH nType
            CASE STATUS_ITEM_WIDTH
               _HMG_aControlWidth[ i ] := Value
               EXIT
            CASE STATUS_ITEM_ACTION
               _HMG_aControlProcedures[ i ] := Value
               EXIT
            CASE STATUS_ITEM_BACKCOLOR
               _HMG_aControlBkColor[ i ] := Value
               EXIT
            CASE STATUS_ITEM_FONTCOLOR
               _HMG_aControlFontColor[ i ] := Value
               EXIT
            CASE STATUS_ITEM_ALIGN
               _HMG_aControlSpacing[ i ] := Value
            ENDSWITCH

            // Redraw status panel if visual/color properties changed
            IF nType > STATUS_ITEM_ACTION
               FormName := GetParentFormName( i )
               _SetItem ( "StatusBar", FormName, nItem, _GetItem ( "StatusBar", FormName, nItem ) )
            ENDIF

            EXIT

         ENDIF

      ENDIF

   NEXT

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusProgressMessage
 *
 * Purpose:
 *    Creates and embeds a progress bar control within a status bar panel.
 *
 * Parameters:
 *    BarName  : Character - Name of the target status bar control.
 *    FormName : Character - Name of the parent window.
 *    width    : Numeric   - Width of the progress bar panel in pixels.
 *    tooltip  : Character - Tooltip text for the progress control.
 *    action   : Character/Block - Event procedure or block executed on click.
 *    nValue   : Numeric   - Initial progress position value.
 *    nMin     : Numeric   - Minimum range limit.
 *    nMax     : Numeric   - Maximum range limit.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Defines status panel "ProgressMessage".
 *    - Instantiates native Win32 ProgressBar control hosted inside status bar.
 *    - Stores status bar and progress handles in `_HMG_aControlMiscData1`.
 */
FUNCTION _SetStatusProgressMessage ( BarName, FormName, width, tooltip, action, nValue, nMin, nMax )
*-----------------------------------------------------------------------------*
   LOCAL hwndStatus, hwndProgress
   LOCAL nrItem
   LOCAL i

   hb_default( @nValue, 0 )
   hb_default( @nMin, 0 )
   hb_default( @nMax, 100 )
   __defaultNIL( @Width, 70 )
   __defaultNIL( @ToolTip, "" )
   __defaultNIL( @Action, "" )

   // Get status bar window handle based on active window definition context
   IF _HMG_BeginWindowActive
      hwndStatus := GetControlHandle ( BarName, FormName )
#ifdef _HMG_COMPAT_
   ELSE
      hwndStatus := _HMG_ActiveStatusHandle
      FormName := GetParentFormName ( GetControlIndexByHandle ( hwndStatus ) )
#endif
   ENDIF

   // Define placeholder panel inside status bar for hosting progress bar
   nrItem := _DefineItemMessage ( PROGRESSNAME, BarName, 0, 0, '', action, width, 0, , "", ToolTip )

   // Create native Win32 ProgressBar control embedded in status item
   hwndProgress := CreateProgressBarItem ( hwndStatus, nrItem, nValue, nMin, nMax )
   i := GetControlIndex ( PROGRESSNAME, FormName )

   // Save parent status bar handle and child progress bar handle in control tracking
   _HMG_aControlMiscData1[ i ] := { hwndStatus, hwndProgress }
   _HMG_aControlRangeMin[ i ] := nMin
   _HMG_aControlRangeMax[ i ] := nMax
   _HMG_aControlValue[ i ] := nValue

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusProgressPos
 *
 * Purpose:
 *    Updates the current position of an embedded status bar progress control.
 *
 * Parameters:
 *    FormName : Character - Name of the parent window.
 *    nValue   : Numeric   - New progress position value.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Sends Win32 progress bar positioning message (`PBM_SETPOS`) to update visual indicator.
 */
FUNCTION _SetStatusProgressPos ( FormName, nValue )
*-----------------------------------------------------------------------------*
   LOCAL i

   // Locate embedded progress bar control entry and update position
   IF ( i := GetControlIndex ( PROGRESSNAME, FormName ) ) > 0
      SetPosProgressBarItem ( _HMG_aControlMiscData1[ i, 2 ], hb_defaultValue( nValue, 0 ) )
   ENDIF

RETURN NIL

*-----------------------------------------------------------------------------*
/*
 * FUNCTION _SetStatusProgressRange
 *
 * Purpose:
 *    Configures the minimum and maximum range bounds of an embedded status bar progress control.
 *
 * Parameters:
 *    FormName : Character - Name of the parent window.
 *    nMin     : Numeric   - Minimum range value.
 *    nMax     : Numeric   - Maximum range value.
 *
 * Return:
 *    NIL
 *
 * Side Effects:
 *    - Updates range limits on the native Win32 progress bar control.
 */
FUNCTION _SetStatusProgressRange ( FormName, nMin, nMax )
*-----------------------------------------------------------------------------*
   LOCAL i

   // Locate embedded progress bar control entry and update range boundaries
   IF ( i := GetControlIndex ( PROGRESSNAME, FormName ) ) > 0
      SetProgressBarRange ( _HMG_aControlMiscData1[ i, 2 ], hb_defaultValue( nMin, 0 ), hb_defaultValue( nMax, 100 ) )
   ENDIF

RETURN NIL