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
#include "i_winuser.ch"

#ifndef __XHARBOUR__
   SET PROCEDURE TO statics.prg
#endif

// Static variables used for text animation/scrolling effects in WaitWindow
STATIC nCtEfeito := 0, cDescEfeito := ""

/*
 * Routine: _DefineWindow
 * Purpose: Defines and registers standard HMG windows (Main, Child, MDI, or Panel).
 *
 * Parameters:
 *   FormName                [C]   - Unique window identifier name.
 *   Caption                 [C]   - Title bar caption text.
 *   x                       [N]   - X position on screen (left offset).
 *   y                       [N]   - Y position on screen (top offset).
 *   w                       [N]   - Total window width in pixels.
 *   h                       [N]   - Total window height in pixels.
 *   nominimize              [L]   - Disables minimize button/style if .T.
 *   nomaximize              [L]   - Disables maximize button/style if .T.
 *   nosize                  [L]   - Prevents window resizing if .T.
 *   nosysmenu               [L]   - Omits the system menu if .T.
 *   nocaption               [L]   - Removes window title bar and border frame if .T.
 *   aMin                    [A]   - Array of minimum { width, height } limits.
 *   aMax                    [A]   - Array of maximum { width, height } limits.
 *   InitProcedure           [B|C] - Event handler executed upon window activation.
 *   ReleaseProcedure        [B|C] - Event handler executed upon window destruction.
 *   MouseDragProcedure      [B|C] - Event handler executed during mouse drag.
 *   SizeProcedure           [B|C] - Event handler executed when window is resized.
 *   ClickProcedure          [B|C] - Event handler executed on mouse left click.
 *   MouseMoveProcedure      [B|C] - Event handler executed on mouse movement.
 *   aRGB                    [A|N] - Background color specification (RGB array or integer).
 *   PaintProcedure          [B|C] - Custom painting event procedure for WM_PAINT.
 *   noshow                  [L]   - Prevents automatically rendering window visible on activate.
 *   topmost                 [L]   - Keeps window on top of all other windows if .T.
 *   main                    [L]   - Identifies this window as the primary application window.
 *   icon                    [C]   - Icon resource name or filename for window title bar.
 *   child                   [L]   - Identifies window as a child form if .T.
 *   fontname                [C]   - Default font family for controls inside window.
 *   fontsize                [N]   - Default font size for controls inside window.
 *   NotifyIconName          [C]   - System tray notification icon resource name.
 *   NotifyIconTooltip       [C]   - System tray tooltip message.
 *   NotifyIconLeftClick     [B|C] - Callback for system tray left mouse click.
 *   GotFocus                [B|C] - Event handler executed when window gains focus.
 *   LostFocus               [B|C] - Event handler executed when window loses focus.
 *   VirtualHeight           [N]   - Scrollable area height if larger than physical height.
 *   VirtualWidth            [N]   - Scrollable area width if larger than physical width.
 *   scrollleft              [B|C] - Handler for horizontal scroll left event.
 *   scrollright             [B|C] - Handler for horizontal scroll right event.
 *   scrollup                [B|C] - Handler for vertical scroll up event.
 *   scrolldown              [B|C] - Handler for vertical scroll down event.
 *   hscrollbox              [B|C] - Handler for horizontal thumb scroll position change.
 *   vscrollbox              [B|C] - Handler for vertical thumb scroll position change.
 *   helpbutton              [L]   - Adds context help button (?) to title bar if .T.
 *   MaximizeProcedure       [B|C] - Handler for window maximize event.
 *   MinimizeProcedure       [B|C] - Handler for window minimize event.
 *   cursor                  [C]   - Resource or file name for default mouse cursor.
 *   NoAutoRelease           [L]   - Prevents auto-releasing memory upon close if .T.
 *   InteractiveCloseProcedure [B|C] - Handler executed when user clicks window Close button ('X').
 *   RestoreProcedure        [B|C] - Handler executed when window is restored from min/max.
 *   MoveProcedure           [B|C] - Handler executed when window is moved.
 *   DropProcedure           [B|C] - Handler executed when files are drag-and-dropped on window.
 *   mdi                     [L]   - Designates window as an MDI client frame if .T.
 *   palette                 [U]   - Custom color palette reference.
 *   NotifyIconDblClick      [B|C] - Callback for double-click on system tray icon.
 *   cPanelParent            [C]   - Form name of parent when panel == .T.
 *   panel                   [L]   - Specifies if this window behaves as an embedded panel.
 *   NotifyBalloonClick      [B|C] - Callback triggered when tray balloon notification is clicked.
 *   clientwidth             [N]   - Specific inner client area width requested in pixels.
 *   clientheight            [N]   - Specific inner client area height requested in pixels.
 *
 * Return:
 *   [N] - Native Windows handle (HWND) of the newly created window.
 *
 * Side Effects:
 *   Creates window object, updates internal HMG global state arrays (_HMG_aFormHandles,
 *   _HMG_aFormNames, etc.), instantiates dynamic global pointer variable `_<FormName>`,
 *   and registers window class with Win32 subsystem.
 */
FUNCTION _DefineWindow ( FormName, Caption, x, y, w, h, nominimize, nomaximize, ;
      nosize, nosysmenu, nocaption, aMin, aMax, InitProcedure, ReleaseProcedure, ;
      MouseDragProcedure, SizeProcedure, ClickProcedure, MouseMoveProcedure, aRGB, ;
      PaintProcedure, noshow, topmost, main, icon, child, fontname, fontsize, ;
      NotifyIconName, NotifyIconTooltip, NotifyIconLeftClick, GotFocus, LostFocus, ;
      VirtualHeight, VirtualWidth, scrollleft, scrollright, scrollup, scrolldown, ;
      hscrollbox, vscrollbox, helpbutton, MaximizeProcedure, MinimizeProcedure, cursor, ;
      NoAutoRelease, InteractiveCloseProcedure, RestoreProcedure, MoveProcedure, DropProcedure, ;
      mdi, palette, NotifyIconDblClick, cPanelParent, panel, NotifyBalloonClick, clientwidth, clientheight )
   LOCAL BrushHandle, FormHandle, ParentHandle
   LOCAL hnotifyicon, htooltip
   LOCAL ClassName
   LOCAL cType
   LOCAL mVar
   LOCAL vscroll, hscroll
   LOCAL k
#ifdef _OBJECT_
   LOCAL o
#endif

   // Ensure Borland C++ 5.8 compatibility flag global variable is initialized
   IF _SetGetGlobal( "_HMG_SetBCC58Compatible" ) == NIL
      STATIC _HMG_SetBCC58Compatible AS GLOBAL VALUE .F.
   ENDIF
   hb_default( @panel, .F. )

   // Assign dynamic default window name if omitted or set panel dimensions if applicable
   IF FormName == NIL
      FormName := _HMG_TempWindowName
#ifdef _PANEL_
      IF _HMG_LoadWindowRow <> -1

         y := _HMG_LoadWindowRow
         x := _HMG_LoadWindowCol
         w := _HMG_LoadWindowWidth
         h := _HMG_LoadWindowHeight

         _HMG_LoadWindowRow    := -1
         _HMG_LoadWindowCol    := -1
         _HMG_LoadWindowWidth  := -1
         _HMG_LoadWindowHeight := -1
      ENDIF
#endif
   ENDIF

#ifdef _PANEL_
   // Offset panel coordinates relative to active frame nesting level
   IF _HMG_FrameLevel > 0
      x := x + _HMG_ActiveFrameCol [ _HMG_FrameLevel ]
      y := y + _HMG_ActiveFrameRow [ _HMG_FrameLevel ]
   ENDIF
#endif
   IF mdi == NIL
      Mdi := .F.
   ENDIF

   FormName := AllTrim ( FormName )

   // Perform structural validation checks depending on main vs secondary/child windows
   IF Main

      IF AScan ( _HMG_aFormType, 'A' ) > 0
         MsgMiniGuiError( "Main Window is already defined." )
      ENDIF

      IF Child == .T.
         MsgMiniGuiError( "Child and Main clauses cannot be used simultaneously." )
      ENDIF

      IF NoAutoRelease == .T.
         MsgMiniGuiError( "NOAUTORELEASE and MAIN clauses cannot be used simultaneously." )
      ENDIF

   ELSE

      IF _HMG_MainWindowFirst == .T.
         IF AScan ( _HMG_aFormType, 'A' ) == 0
            MsgMiniGuiError( "Main Window is not defined." )
         ENDIF
      ENDIF

      IF _IsWindowDefined ( FormName )
         MsgMiniGuiError( "Window: " + FormName + " is already defined." )
      ENDIF

      IF ! Empty ( NotifyIconName )
         MsgMiniGuiError( "Notification icon allowed only in Main Window." )
      ENDIF

      IF _HMG_BeginWindowMDIActive == .T.
         MsgMiniGuiError( "Only MdiChild windows can be defined inside MdiWindow." )
      ENDIF

   ENDIF

#ifdef _PANEL_
   // Validate panel parent requirements and scope constraints
   IF ValType( cPanelParent ) == 'C' .AND. panel == .F.
      MsgMiniGuiError( "Parent can be specified only for Panel windows." )
   ENDIF

   IF !Empty( _HMG_ActiveFormName ) .AND. panel == .F. .AND. _HMG_ProgrammaticChange
      MsgMiniGuiError( "Only Panel windows can be defined inside a DEFINE WINDOW...END WINDOW structure." )
   ENDIF
#else
   HB_SYMBOL_UNUSED( cPanelParent )
#endif

   // Calculate window dimensions dynamically when explicit sizes are omitted
   IF !ISNUMBER( w ) .AND. !ISNUMBER( h )
      IF !ISNUMBER( clientwidth ) .AND. !ISNUMBER( clientheight )
         w := GetDesktopWidth()
         h := GetDesktopHeight()
         IF child
            IF w / h > 1.4 // Apply adjusted scale factor for widescreen displays
               w *= .5
               h *= .77
            ELSE
               w *= .78125
               h *= .78125
            ENDIF
         ENDIF
         IF h != GetDesktopRealHeight()
            h -= GetTaskBarHeight()
         ENDIF
      ELSE
         // Calculate window frame sizes based on target inner client dimensions
         mVar := ( nocaption .AND. nosize )
         w := ClientWidth + iif( mVar, 0, GetBorderWidth() ) + iif( mVar .OR. _HMG_IsThemed .AND. nosize, 0, GetBorderWidth() ) - iif( mVar .OR. (!_HMG_IsThemed .AND. !nosize) .OR. (_HMG_IsThemed .AND. !nocaption .AND. !nosize), 0, 2 )
         h := ClientHeight + iif( nocaption, 0, GetTitleHeight() ) + iif( mVar .OR. _HMG_IsThemed .AND. nosize, 0, GetBorderWidth() ) + iif( mVar, 0, GetBorderWidth() ) - iif( mVar .OR. (!_HMG_IsThemed .AND. !nosize) .OR. (_HMG_IsThemed .AND. !nocaption .AND. !nosize), 0, 2 )
         IF _HMG_IsBcc77OrLater
            IF !mVar .AND. nosize .AND. _HMG_IsThemed
               w += GetBorderWidth() + 2
               h += GetBorderHeight() + 2
            ENDIF
         ENDIF
      ENDIF
   ELSE
      IF _SetGetGlobal( "_HMG_SetBCC58Compatible" ) .AND. _HMG_IsBcc77OrLater
         IF nosize .AND. !nocaption .AND. _HMG_IsThemed
            w += GetBorderWidth() + 2
            h += GetBorderHeight() + 2
         ENDIF
      ENDIF
   ENDIF

   mVar := '_' + FormName

   ParentHandle := iif( child == .T., _HMG_MainHandle, 0 )

#ifdef _PANEL_
   // Establish parent handle for embedded Panel windows
   IF panel == .T.

      IF ValType( cPanelParent ) == 'C'
         IF GetWindowType ( cPanelParent ) == 'X'
            MsgMiniGuiError( "Panel Windows Can't Have SplitChild Parent." )
         ENDIF

         ParentHandle := GetFormHandle( cPanelParent )
         _HMG_ParentWindowActive := .F.

      ELSEIF ! Empty( _HMG_ActiveFormName )
         IF GetWindowType ( _HMG_ActiveFormName ) == 'X'
            MsgMiniGuiError( "Panel Windows Can't Have SplitChild Parent." )
         ENDIF

         ParentHandle := GetFormHandle( _HMG_ActiveFormName )
         _HMG_ParentWindowActive := .T.
         _HMG_ActiveFormNameBak  := _HMG_ActiveFormName

      ELSE
         MsgMiniGuiError( "Panel Windows Must Have a Parent." )
      ENDIF

   ENDIF
#endif

   // Store default active window font specifications
   _HMG_ActiveFontName := hb_defaultValue( FontName, _HMG_DefaultFontName )

   _HMG_ActiveFontSize := hb_defaultValue( FontSize, _HMG_DefaultFontSize )

   // Set default values for optional procedure/event parameters
   hb_default( @Caption, "" )
   __defaultNIL( @InitProcedure, "" )
   __defaultNIL( @ReleaseProcedure, "" )
   __defaultNIL( @MouseDragProcedure, "" )
   __defaultNIL( @SizeProcedure, "" )
   __defaultNIL( @ClickProcedure, "" )
   __defaultNIL( @MouseMoveProcedure, "" )
   __defaultNIL( @PaintProcedure, "" )
   __defaultNIL( @GotFocus, "" )
   __defaultNIL( @LostFocus, "" )
   __defaultNIL( @scrollup, "" )
   __defaultNIL( @scrolldown, "" )
   __defaultNIL( @scrollleft, "" )
   __defaultNIL( @scrollright, "" )
   __defaultNIL( @hscrollbox, "" )
   __defaultNIL( @vscrollbox, "" )

   // Configure vertical scrolling state based on virtual canvas height
   IF VirtualHeight == NIL
      VirtualHeight := 0
      vscroll := .F.
   ELSE
      IF VirtualHeight <= h
         MsgMiniGuiError( "DEFINE WINDOW: Virtual Height must be greater than Window Height." )
      ENDIF
      vscroll := .T.
   ENDIF

   // Configure horizontal scrolling state based on virtual canvas width
   IF VirtualWidth == NIL
      VirtualWidth := 0
      hscroll := .F.
   ELSE
      IF VirtualWidth <= w
         MsgMiniGuiError( "DEFINE WINDOW: Virtual Width must be greater than Window Width." )
      ENDIF
      hscroll := .T.
   ENDIF

   // Process RGB background color array conversion if numeric
   IF ValType ( aRGB ) == 'N'
      aRGB := nRGB2Arr( aRGB )
   ENDIF

   IF ValType ( aRGB ) != 'C' .AND. IsArrayRGB ( aRGB ) == .F.
      aRGB := { -1, -1, -1 }
   ENDIF

   IF icon == NIL .AND. _HMG_DefaultIconName != NIL
      icon := _HMG_DefaultIconName
   ENDIF

   _HMG_ActiveFormName := FormName
   IF mdi
      _HMG_MainClientMDIName := FormName  // Set MDI main client reference
   ENDIF

   _HMG_BeginWindowActive := .T.

   ClassName := "HMG_FORM_" + FormName
   UnRegisterWindow ( ClassName )

   // Register window class and construct Win32 API window object
   IF mdi
      _HMG_BeginWindowMDIActive := .T.  // Set MDI definition flag
      BrushHandle := RegisterMDIWindow( icon, FormName, aRGB )
      Formhandle := InitMDIWindow( Caption, x, y, w, h, nominimize, nomaximize, nosize, nosysmenu, nocaption, topmost, FormName, ParentHandle, vscroll, hscroll, helpbutton )
   ELSE
      BrushHandle := RegisterWindow( icon, ClassName, aRGB, cursor )  // Register class with custom background brush/cursor
      Formhandle := InitWindow( Caption, x, y, w, h, nominimize, nomaximize, nosize, nosysmenu, nocaption, topmost, ClassName, ParentHandle, vscroll, hscroll, helpbutton, palette, panel )
   ENDIF

   // Disable close button ('X') on caption bar when close behavior is restricted
   IF Empty( _HMG_InteractiveClose ) .AND. !Main .AND. !nosysmenu .AND. !nocaption
      xDisableCloseButton( FormHandle, .F. )
   ENDIF

   IF mdi .AND. cursor != NIL  // Set explicit window cursor for MDI forms
      SetWindowCursor ( FormHandle, cursor )
   ENDIF

   IF Main
      _HMG_MainHandle := FormHandle
      IF ISBLOCK ( NotifyBalloonClick )
         _HMG_NotifyBalloonClick := NotifyBalloonClick
      ENDIF
   ENDIF

   // Initialize system tray notification icon if provided
   IF NotifyIconName == NIL
      NotifyIconName := ""
   ELSE
      hnotifyicon := LoadTrayIcon( GetResources(), NotifyIconName )
      ShowNotifyIcon ( FormHandle, .T., hnotifyicon, NotifyIconTooltip )
   ENDIF

   // Attach tooltip control to the window
   htooltip := InitToolTip ( FormHandle, SetToolTipBalloon() )

   IF SetToolTipMaxWidth() <> -1
      SendMessage ( htooltip, TTM_SETMAXTIPWIDTH, 0, SetToolTipMaxWidth() )
   ENDIF

   cType := iif( Main == .T., 'A', iif( Child == .T., 'C', iif( Panel == .T., 'P', 'S' ) ) )

   // Check for recyclable array index slot in global form storage
   k := AScan ( _HMG_aFormDeleted, .T. )

   IF k > 0

#ifdef _NAMES_LIST_
      _SetNameList( mVar , k )
#else
      Public &mVar. := k
#endif

      _HMG_aFormNames [ k ] :=  FormName
      _HMG_aFormHandles [ k ] :=  FormHandle
      _HMG_aFormActive [ k ] :=  .F.
      _HMG_aFormType [ k ] :=  cType
      _HMG_aFormParentHandle [ k ] :=  iif( panel, ParentHandle, 0 )
      _HMG_aFormReleaseProcedure [ k ] :=  ReleaseProcedure
      _HMG_aFormInitProcedure [ k ] :=  InitProcedure
      _HMG_aFormToolTipHandle [ k ] :=  htooltip
      _HMG_aFormContextMenuHandle [ k ] :=  0
      _HMG_aFormMouseDragProcedure [ k ] :=  MouseDragProcedure
      _HMG_aFormSizeProcedure [ k ] :=  SizeProcedure
      _HMG_aFormClickProcedure [ k ] :=  ClickProcedure
      _HMG_aFormMouseMoveProcedure [ k ] :=  MouseMoveProcedure
      _HMG_aFormMoveProcedure [ k ] :=  MoveProcedure
      _HMG_aFormDropProcedure [ k ] :=  DropProcedure
      _HMG_aFormDeleted [ k ] := .F.
      _HMG_aFormBkColor [ k ] := aRGB
      _HMG_aFormPaintProcedure [ k ] :=  PaintProcedure
      _HMG_aFormNoShow [ k ] :=  noshow
      _HMG_aFormNotifyIconName [ k ] :=  NotifyIconName
      _HMG_aFormNotifyIconToolTip [ k ] :=  NotifyIconToolTip
      _HMG_aFormNotifyIconLeftClick [ k ] :=  NotifyIconLeftClick
      _HMG_aFormNotifyIconDblClick [ k ] :=  NotifyIconDblClick
      _HMG_aFormGotFocusProcedure [ k ] :=  GotFocus
      _HMG_aFormLostFocusProcedure [ k ] :=  LostFocus
      _HMG_aFormReBarHandle [ k ] :=  0
      _HMG_aFormNotifyMenuHandle [ k ] := 0
      _HMG_aFormBrowseList [ k ] :=  {}
      _HMG_aFormSplitChildList [ k ] := {}
      _HMG_aFormVirtualHeight [ k ] :=  VirtualHeight
      _HMG_aFormVirtualWidth [ k ] :=  VirtualWidth
      _HMG_aFormFocused [ k ] :=  .F.
      _HMG_aFormScrollUp [ k ] :=  ScrollUp
      _HMG_aFormScrollDown [ k ] :=  ScrollDown
      _HMG_aFormScrollLeft [ k ] :=  ScrollLeft
      _HMG_aFormScrollRight [ k ] :=  ScrollRight
      _HMG_aFormHScrollBox [ k ] := HScrollBox
      _HMG_aFormVScrollBox [ k ] := VScrollBox
      _HMG_aFormBrushHandle [ k ] := BrushHandle
      _HMG_aFormFocusedControl [ k ] := 0
      _HMG_aFormGraphTasks [ k ] := {}
      _HMG_aFormMaximizeProcedure [ k ] :=  MaximizeProcedure
      _HMG_aFormMinimizeProcedure [ k ] :=  MinimizeProcedure
      _HMG_aFormRestoreProcedure [ k ] :=  RestoreProcedure
      _HMG_aFormAutoRelease [ k ] :=  ! NoAutoRelease
      _HMG_aFormInteractiveCloseProcedure [ k ] :=  InteractiveCloseProcedure
      _HMG_aFormMinMaxInfo [ k ] := InitMinMaxInfo ( FormHandle )
      _HMG_aFormActivateId [ k ] := 0
      _HMG_aFormMiscData1  [ k ] := {hnotifyicon, cursor, 0}
      _HMG_aFormMiscData2  [ k ] := ''
#ifdef _HMG_COMPAT_
      _HMG_StopWindowEventProcedure [ k ] := .F.
#endif

   ELSE

      // Append new slot to global form arrays
      k := Len( _HMG_aFormNames ) + 1

#ifdef _NAMES_LIST_
      _SetNameList( mVar , k )
#else
      Public &mVar. := k
#endif

      AAdd ( _HMG_aFormNames, FormName )
      AAdd ( _HMG_aFormHandles, FormHandle )
      AAdd ( _HMG_aFormActive, .F. )
      AAdd ( _HMG_aFormType, cType )
      AAdd ( _HMG_aFormParentHandle, iif( panel, ParentHandle, 0 ) )
      AAdd ( _HMG_aFormReleaseProcedure, ReleaseProcedure )
      AAdd ( _HMG_aFormInitProcedure, InitProcedure )
      AAdd ( _HMG_aFormToolTipHandle, htooltip )
      AAdd ( _HMG_aFormContextMenuHandle, 0 )
      AAdd ( _HMG_aFormMouseDragProcedure, MouseDragProcedure )
      AAdd ( _HMG_aFormSizeProcedure, SizeProcedure )
      AAdd ( _HMG_aFormClickProcedure, ClickProcedure )
      AAdd ( _HMG_aFormMouseMoveProcedure, MouseMoveProcedure )
      AAdd ( _HMG_aFormMoveProcedure, MoveProcedure )
      AAdd ( _HMG_aFormDropProcedure, DropProcedure )
      AAdd ( _HMG_aFormDeleted, .F. )
      AAdd ( _HMG_aFormBkColor, aRGB )
      AAdd ( _HMG_aFormPaintProcedure, PaintProcedure )
      AAdd ( _HMG_aFormNoShow, noshow )
      AAdd ( _HMG_aFormNotifyIconName, NotifyIconName )
      AAdd ( _HMG_aFormNotifyIconToolTip, NotifyIconToolTip )
      AAdd ( _HMG_aFormNotifyIconLeftClick, NotifyIconLeftClick )
      AAdd ( _HMG_aFormNotifyIconDblClick, NotifyIconDblClick )
      AAdd ( _HMG_aFormGotFocusProcedure, GotFocus )
      AAdd ( _HMG_aFormLostFocusProcedure, LostFocus )
      AAdd ( _HMG_aFormReBarHandle, 0 )
      AAdd ( _HMG_aFormNotifyMenuHandle, 0 )
      AAdd ( _HMG_aFormBrowseList, {} )
      AAdd ( _HMG_aFormSplitChildList, {} )
      AAdd ( _HMG_aFormVirtualHeight, VirtualHeight )
      AAdd ( _HMG_aFormVirtualWidth, VirtualWidth )
      AAdd ( _HMG_aFormFocused, .F. )
      AAdd ( _HMG_aFormScrollUp, ScrollUp )
      AAdd ( _HMG_aFormScrollDown, ScrollDown )
      AAdd ( _HMG_aFormScrollLeft, ScrollLeft )
      AAdd ( _HMG_aFormScrollRight, ScrollRight )
      AAdd ( _HMG_aFormHScrollBox, HScrollBox )
      AAdd ( _HMG_aFormVScrollBox, VScrollBox )
      AAdd ( _HMG_aFormBrushHandle, BrushHandle )
      AAdd ( _HMG_aFormFocusedControl, 0 )
      AAdd ( _HMG_aFormGraphTasks, {} )
      AAdd ( _HMG_aFormMaximizeProcedure, MaximizeProcedure )
      AAdd ( _HMG_aFormMinimizeProcedure, MinimizeProcedure )
      AAdd ( _HMG_aFormRestoreProcedure, RestoreProcedure )
      AAdd ( _HMG_aFormAutoRelease, ! NoAutoRelease )
      AAdd ( _HMG_aFormInteractiveCloseProcedure, InteractiveCloseProcedure )
      AAdd ( _HMG_aFormMinMaxInfo, InitMinMaxInfo ( FormHandle ) )
      AAdd ( _HMG_aFormActivateId, 0 )
      AAdd ( _HMG_aFormMiscData1, {hnotifyicon, cursor, 0} )
      AAdd ( _HMG_aFormMiscData2, '' )
#ifdef _HMG_COMPAT_
      AAdd ( _HMG_StopWindowEventProcedure, .F. )
#endif

   ENDIF

#ifdef _PANEL_
   // Map panel window to active parent tab page
   IF _HMG_BeginTabActive .AND. Panel
      AAdd ( _HMG_ActiveTabCurrentPageMap, FormHandle )
      IF _HMG_ActiveTabPage > 1
         _HMG_aFormParentHandle [ k ] := 0
      ENDIF
   ENDIF
#endif

   _SetThisFormInfo ( k )

   // Initialize OOP object wrapper if object framework is enabled
   IF _HMG_lOOPEnabled
      Eval ( _HMG_bOnFormInit, k, mVar )
#ifdef _OBJECT_
      o := _WindowObj( FormHandle )
      IF HB_ISOBJECT( o )
         o:cProcFile := ProcFile( 1 )
         o:cProcName := ProcName( 1 )
         o:nProcLine := ProcLine( 1 )
      ENDIF
#endif
	ENDIF

   IF !mdi  // Skip dummy window creation for MDI frames
      InitDummy ( FormHandle )
   ENDIF

   // Set native Windows scrollbar ranges for virtual window canvas
   IF VirtualHeight > 0
      SetScrollRange ( Formhandle, SB_VERT, 0, VirtualHeight - h, .T. )
   ENDIF
   IF VirtualWidth > 0
      SetScrollRange ( Formhandle, SB_HORZ, 0, VirtualWidth - w, .T. )
   ENDIF

   // Store explicit min/max window dimension restrictions
   IF ISARRAY ( aMin ) .AND. ISARRAY ( aMax )
      iif( aMin[ 1 ] == NIL, NIL, _HMG_aFormMinMaxInfo [ k ] [ 5 ] := aMin[ 1 ] )
      iif( aMin[ 2 ] == NIL, NIL, _HMG_aFormMinMaxInfo [ k ] [ 6 ] := aMin[ 2 ] )
      iif( aMax[ 1 ] == NIL, NIL, _HMG_aFormMinMaxInfo [ k ] [ 7 ] := aMax[ 1 ] )
      iif( aMax[ 2 ] == NIL, NIL, _HMG_aFormMinMaxInfo [ k ] [ 8 ] := aMax[ 2 ] )
   ENDIF

RETURN ( FormHandle )

/*
 * Routine: _DefineModalWindow
 * Purpose: Defines and registers a modal window that blocks user interaction with parent forms.
 *
 * Parameters:
 *   FormName                [C]   - Identifier name of the modal window.
 *   Caption                 [C]   - Title bar caption.
 *   x                       [N]   - X screen coordinate.
 *   y                       [N]   - Y screen coordinate.
 *   w                       [N]   - Modal window width in pixels.
 *   h                       [N]   - Modal window height in pixels.
 *   Parent                  [N]   - HWND handle of parent form.
 *   nosize                  [L]   - Prevents window resizing if .T.
 *   nosysmenu               [L]   - Omits the system menu if .T.
 *   nocaption               [L]   - Removes window title bar if .T.
 *   aMin                    [A]   - Array of minimum size limits { width, height }.
 *   aMax                    [A]   - Array of maximum size limits { width, height }.
 *   InitProcedure           [B|C] - Event procedure run upon activation.
 *   ReleaseProcedure        [B|C] - Event procedure run upon window release.
 *   MouseDragProcedure      [B|C] - Handler for mouse drag.
 *   SizeProcedure           [B|C] - Handler for WM_SIZE events.
 *   ClickProcedure          [B|C] - Handler for mouse left clicks.
 *   MouseMoveProcedure      [B|C] - Handler for mouse movement.
 *   aRGB                    [A|N] - Background color array or integer color code.
 *   PaintProcedure          [B|C] - Handler for custom WM_PAINT commands.
 *   icon                    [C]   - Name of window icon resource.
 *   FontName                [C]   - Default font name.
 *   FontSize                [N]   - Default font size.
 *   GotFocus                [B|C] - Focus gain handler.
 *   LostFocus               [B|C] - Focus loss handler.
 *   VirtualHeight           [N]   - Scrollable height.
 *   VirtualWidth            [N]   - Scrollable width.
 *   scrollleft              [B|C] - Horizontal scroll left callback.
 *   scrollright             [B|C] - Horizontal scroll right callback.
 *   scrollup                [B|C] - Vertical scroll up callback.
 *   scrolldown              [B|C] - Vertical scroll down callback.
 *   hscrollbox              [B|C] - Horizontal thumb scroll callback.
 *   vscrollbox              [B|C] - Vertical thumb scroll callback.
 *   helpbutton              [L]   - Adds context help button if .T.
 *   cursor                  [C]   - Mouse cursor name/resource.
 *   noshow                  [L]   - Prevents rendering visible upon activation if .T.
 *   NoAutoRelease           [L]   - Keeps memory active after close if .T.
 *   InteractiveCloseProcedure [B|C] - Close button handler.
 *   MoveProcedure           [B|C] - Window movement handler.
 *   DropProcedure           [B|C] - File drag and drop handler.
 *   clientwidth             [N]   - Target client area width.
 *   clientheight            [N]   - Target client area height.
 *   flashexit               [L]   - Modal execution exit style flag.
 *
 * Return:
 *   [N] - Native Windows handle (HWND) of modal window.
 *
 * Side Effects:
 *   Creates a modal window object, disables parent windows during modal loop execution,
 *   and registers window details in global HMG forms structures.
 */
FUNCTION _DefineModalWindow ( FormName, Caption, x, y, w, h, Parent, nosize, nosysmenu, nocaption, aMin, aMax, ;
      InitProcedure, ReleaseProcedure, MouseDragProcedure, SizeProcedure, ClickProcedure, MouseMoveProcedure, aRGB, ;
      PaintProcedure, icon, FontName, FontSize, GotFocus, LostFocus, VirtualHeight, VirtualWidth, ;
      scrollleft, scrollright, scrollup, scrolldown, hscrollbox, vscrollbox, helpbutton, cursor, noshow, ;
      NoAutoRelease, InteractiveCloseProcedure, MoveProcedure, DropProcedure, clientwidth, clientheight, flashexit )
   LOCAL BrushHandle, FormHandle
   LOCAL htooltip
   LOCAL ClassName
   LOCAL mVar
   LOCAL vscroll, hscroll
   LOCAL k
#ifdef _OBJECT_
   LOCAL o
#endif

   IF _SetGetGlobal( "_HMG_SetBCC58Compatible" ) == NIL
      STATIC _HMG_SetBCC58Compatible AS GLOBAL VALUE .F.
   ENDIF
   IF FormName == NIL
      FormName := _HMG_TempWindowName
   ENDIF

   // Modal forms require an existing Main Window definition
   IF _HMG_MainWindowFirst == .T.
      IF AScan ( _HMG_aFormType, 'A' ) == 0
         MsgMiniGuiError( "Main Window is not defined." )
      ENDIF
   ENDIF

   IF _IsWindowDefined ( FormName )
      MsgMiniGuiError( "Window: " + FormName + " is already defined." )
   ENDIF

   // Calculate default window size if omitted
   IF !ISNUMBER( w ) .AND. !ISNUMBER( h )

      IF !ISNUMBER( clientwidth ) .AND. !ISNUMBER( clientheight )
         w := GetDesktopWidth()
         h := GetDesktopHeight()
         IF w / h > 1.75 // Scale for widescreen monitor aspect ratios
            w *= .4
            h *= .6
         ELSE
            w *= 0.614
            h *= 0.614
         ENDIF
         IF h != GetDesktopRealHeight()
            h -= GetTaskBarHeight()
         ENDIF
      ELSE
         mVar := ( nocaption .AND. nosize )
         w := ClientWidth + iif( mVar, 0, GetBorderWidth() ) + iif( mVar .OR. _HMG_IsThemed .AND. nosize, 0, GetBorderWidth() ) - iif( mVar .OR. (!_HMG_IsThemed .AND. !nosize) .OR. (_HMG_IsThemed .AND. !nocaption .AND. !nosize), 0, 2 )
         h := ClientHeight + iif( nocaption, 0, GetTitleHeight() ) + iif( mVar .OR. _HMG_IsThemed .AND. nosize, 0, GetBorderWidth() ) + iif( mVar, 0, GetBorderWidth() ) - iif( mVar .OR. (!_HMG_IsThemed .AND. !nosize) .OR. (_HMG_IsThemed .AND. !nocaption .AND. !nosize), 0, 2 )
         IF _HMG_IsBcc77OrLater
            IF ! mVar .AND. nosize .AND. _HMG_IsThemed
               w += GetBorderWidth() + 2
               h += GetBorderHeight() + 2
            ENDIF
         ENDIF
      ENDIF
   ELSE
      IF _SetGetGlobal( "_HMG_SetBCC58Compatible" ) .AND. _HMG_IsBcc77OrLater
         IF nosize .AND. !nocaption .AND. _HMG_IsThemed
            w += GetBorderWidth() + 2
            h += GetBorderHeight() + 2
         ENDIF
      ENDIF
   ENDIF

   mVar := '_' + FormName

   _HMG_ActiveFontName := hb_defaultValue( FontName, _HMG_DefaultFontName )

   _HMG_ActiveFontSize := hb_defaultValue( FontSize, _HMG_DefaultFontSize )

   hb_default( @Caption, "" )
   hb_default( @flashexit, .F. )
   __defaultNIL( @InitProcedure, "" )
   __defaultNIL( @ReleaseProcedure, "" )
   __defaultNIL( @MouseDragProcedure, "" )
   __defaultNIL( @SizeProcedure, "" )
   __defaultNIL( @ClickProcedure, "" )
   __defaultNIL( @MouseMoveProcedure, "" )
   __defaultNIL( @PaintProcedure, "" )
   __defaultNIL( @GotFocus, "" )
   __defaultNIL( @LostFocus, "" )
   __defaultNIL( @scrollup, "" )
   __defaultNIL( @scrolldown, "" )
   __defaultNIL( @scrollleft, "" )
   __defaultNIL( @scrollright, "" )
   __defaultNIL( @hscrollbox, "" )
   __defaultNIL( @vscrollbox, "" )

   IF VirtualHeight == NIL
      VirtualHeight := 0
      vscroll := .F.
   ELSE
      IF VirtualHeight <= h
         MsgMiniGuiError( "DEFINE WINDOW: Virtual Height must be greater than Window Height." )
      ENDIF
      vscroll := .T.
   ENDIF

   IF VirtualWidth == NIL
      VirtualWidth := 0
      hscroll := .F.
   ELSE
      IF VirtualWidth <= w
         MsgMiniGuiError( "DEFINE WINDOW: Virtual Width must be greater than Window Width." )
      ENDIF
      hscroll := .T.
   ENDIF

   IF ValType ( aRGB ) != 'C' .AND. IsArrayRGB ( aRGB ) == .F.
      aRGB := { -1, -1, -1 }
   ENDIF

   IF icon == NIL .AND. _HMG_DefaultIconName != NIL
      icon := _HMG_DefaultIconName
   ENDIF

   // Determine parent owner window for inplace modal nesting
   IF _HMG_OwnerModalHandle
      _HMG_InplaceParentHandle := iif( _HMG_BeginWindowMDIActive, GetActiveMdiHandle(), GetActiveWindow() )
   ENDIF

   IF _HMG_InplaceParentHandle <> 0
      Parent := _hmg_InplaceParentHandle
   ELSEIF ! _HMG_BeginWindowMDIActive
      Parent := _hmg_MainHandle
   ENDIF

   _HMG_ActiveFormName := FormName
   _HMG_BeginWindowActive := .T.

   ClassName := "HMG_FORM_" + FormName
   UnRegisterWindow ( ClassName )

   BrushHandle := RegisterWindow ( icon, ClassName, aRGB )
   Formhandle := InitModalWindow ( Caption, x, y, w, h, Parent, nosize, nosysmenu, nocaption, ClassName, vscroll, hscroll, helpbutton )

   IF Empty ( _HMG_InteractiveClose ) .AND. !nosysmenu .AND. !nocaption
      xDisableCloseButton ( FormHandle, .F. )
   ENDIF

   IF cursor != NIL
      SetWindowCursor( FormHandle, cursor )
   ENDIF

   htooltip := InitToolTip( , SetToolTipBalloon() )

   IF SetToolTipMaxWidth() <> -1
      SendMessage( htooltip, TTM_SETMAXTIPWIDTH, 0, SetToolTipMaxWidth() )
   ENDIF

   k := AScan ( _HMG_aFormDeleted, .T. )

   IF k > 0

#ifdef _NAMES_LIST_
      _SetNameList( mVar , k )
#else
      Public &mVar. := k
#endif

      _HMG_aFormNames [ k ] :=  FormName
      _HMG_aFormHandles [ k ] :=  FormHandle
      _HMG_aFormActive [ k ] :=  .F.
      _HMG_aFormType [ k ] :=  "M"
      _HMG_aFormParentHandle [ k ] :=  Parent
      _HMG_aFormReleaseProcedure [ k ] :=  ReleaseProcedure
      _HMG_aFormInitProcedure [ k ] :=  InitProcedure
      _HMG_aFormToolTipHandle [ k ] :=  htooltip
      _HMG_aFormContextMenuHandle [ k ] := 0
      _HMG_aFormMouseDragProcedure [ k ] :=  MouseDragProcedure
      _HMG_aFormSizeProcedure [ k ] :=  SizeProcedure
      _HMG_aFormClickProcedure [ k ] :=  ClickProcedure
      _HMG_aFormMouseMoveProcedure [ k ] :=  MouseMoveProcedure
      _HMG_aFormMoveProcedure [ k ] :=  MoveProcedure
      _HMG_aFormDropProcedure [ k ] :=  DropProcedure
      _HMG_aFormDeleted [ k ] :=  .F.
      _HMG_aFormBkColor [ k ] :=  aRGB
      _HMG_aFormPaintProcedure [ k ] :=  PaintProcedure
      _HMG_aFormNoShow [ k ] :=  noshow
      _HMG_aFormNotifyIconName [ k ] :=  ''
      _HMG_aFormNotifyIconToolTip [ k ] :=  ''
      _HMG_aFormNotifyIconLeftClick [ k ] :=  ''
      _HMG_aFormNotifyIconDblClick [ k ] :=  ''
      _HMG_aFormGotFocusProcedure [ k ] :=  GotFocus
      _HMG_aFormLostFocusProcedure [ k ] :=  LostFocus
      _HMG_aFormReBarHandle [ k ] :=  0
      _HMG_aFormNotifyMenuHandle [ k ] :=  0
      _HMG_aFormBrowseList [ k ] :=  {}
      _HMG_aFormSplitChildList [ k ] :=  {}
      _HMG_aFormVirtualHeight [ k ] :=  VirtualHeight
      _HMG_aFormVirtualWidth [ k ] :=  VirtualWidth
      _HMG_aFormFocused [ k ] :=  flashexit
      _HMG_aFormScrollUp [ k ] :=  ScrollUp
      _HMG_aFormScrollDown [ k ] :=  ScrollDown
      _HMG_aFormScrollLeft [ k ] :=  ScrollLeft
      _HMG_aFormScrollRight [ k ] :=  ScrollRight
      _HMG_aFormHScrollBox [ k ] :=  HScrollBox
      _HMG_aFormVScrollBox [ k ] :=  VScrollBox
      _HMG_aFormBrushHandle [ k ] :=  BrushHandle
      _HMG_aFormFocusedControl [ k ] := 0
      _HMG_aFormGraphTasks [ k ] :=  {}
      _HMG_aFormMaximizeProcedure [ k ] :=  Nil
      _HMG_aFormMinimizeProcedure [ k ] :=  Nil
      _HMG_aFormRestoreProcedure [ k ] :=  Nil
      _HMG_aFormAutoRelease [ k ] :=  ! NoAutoRelease
      _HMG_aFormInteractiveCloseProcedure [ k ] :=  InteractiveCloseProcedure
      _HMG_aFormMinMaxInfo [ k ] := InitMinMaxInfo ( FormHandle )
      _HMG_aFormActivateId [ k ] := 0
      _HMG_aFormMiscData1  [ k ] := {NIL, cursor, 0}
      _HMG_aFormMiscData2  [ k ] := ''
#ifdef _HMG_COMPAT_
      _HMG_StopWindowEventProcedure [ k ] := .F.
#endif

   ELSE

      k := Len( _HMG_aFormNames ) + 1

#ifdef _NAMES_LIST_
      _SetNameList( mVar , k )
#else
      Public &mVar. := k
#endif

      AAdd ( _HMG_aFormNames, FormName )
      AAdd ( _HMG_aFormHandles, FormHandle )
      AAdd ( _HMG_aFormActive, .F. )
      AAdd ( _HMG_aFormType, "M" )
      AAdd ( _HMG_aFormParentHandle, Parent )
      AAdd ( _HMG_aFormReleaseProcedure, ReleaseProcedure )
      AAdd ( _HMG_aFormInitProcedure, InitProcedure )
      AAdd ( _HMG_aFormToolTipHandle, htooltip )
      AAdd ( _HMG_aFormContextMenuHandle, 0 )
      AAdd ( _HMG_aFormMouseDragProcedure, MouseDragProcedure )
      AAdd ( _HMG_aFormSizeProcedure, SizeProcedure )
      AAdd ( _HMG_aFormClickProcedure, ClickProcedure )
      AAdd ( _HMG_aFormMouseMoveProcedure, MouseMoveProcedure )
      AAdd ( _HMG_aFormMoveProcedure, MoveProcedure )
      AAdd ( _HMG_aFormDropProcedure, DropProcedure )
      AAdd ( _HMG_aFormDeleted, .F. )
      AAdd ( _HMG_aFormBkColor, aRGB )
      AAdd ( _HMG_aFormPaintProcedure, PaintProcedure )
      AAdd ( _HMG_aFormNoShow, noshow )
      AAdd ( _HMG_aFormNotifyIconName, '' )
      AAdd ( _HMG_aFormNotifyIconToolTip, '' )
      AAdd ( _HMG_aFormNotifyIconLeftClick, '' )
      AAdd ( _HMG_aFormNotifyIconDblClick, '' )
      AAdd ( _HMG_aFormGotFocusProcedure, GotFocus )
      AAdd ( _HMG_aFormLostFocusProcedure, LostFocus )
      AAdd ( _HMG_aFormReBarHandle, 0 )
      AAdd ( _HMG_aFormNotifyMenuHandle, 0 )
      AAdd ( _HMG_aFormBrowseList, {} )
      AAdd ( _HMG_aFormSplitChildList, {} )
      AAdd ( _HMG_aFormVirtualHeight, VirtualHeight )
      AAdd ( _HMG_aFormVirtualWidth, VirtualWidth )
      AAdd ( _HMG_aFormFocused, flashexit )
      AAdd ( _HMG_aFormScrollUp, ScrollUp )
      AAdd ( _HMG_aFormScrollDown, ScrollDown )
      AAdd ( _HMG_aFormScrollLeft, ScrollLeft )
      AAdd ( _HMG_aFormScrollRight, ScrollRight )
      AAdd ( _HMG_aFormHScrollBox, HScrollBox )
      AAdd ( _HMG_aFormVScrollBox, VScrollBox )
      AAdd ( _HMG_aFormBrushHandle, BrushHandle )
      AAdd ( _HMG_aFormFocusedControl, 0 )
      AAdd ( _HMG_aFormGraphTasks, {} )
      AAdd ( _HMG_aFormMaximizeProcedure, Nil )
      AAdd ( _HMG_aFormMinimizeProcedure, Nil )
      AAdd ( _HMG_aFormRestoreProcedure, Nil )
      AAdd ( _HMG_aFormAutoRelease, ! NoAutoRelease )
      AAdd ( _HMG_aFormInteractiveCloseProcedure, InteractiveCloseProcedure )
      AAdd ( _HMG_aFormMinMaxInfo, InitMinMaxInfo ( FormHandle ) )
      AAdd ( _HMG_aFormActivateId, 0 )
      AAdd ( _HMG_aFormMiscData1, {NIL, cursor, 0} )
      AAdd ( _HMG_aFormMiscData2, '' )
#ifdef _HMG_COMPAT_
      AAdd ( _HMG_StopWindowEventProcedure, .F. )
#endif

   ENDIF

   _SetThisFormInfo ( k )

   IF _HMG_lOOPEnabled
      Eval ( _HMG_bOnFormInit, k, mVar )
#ifdef _OBJECT_
      o := _WindowObj( FormHandle )
      IF HB_ISOBJECT( o )
         o:cProcFile := ProcFile( 1 )
         o:cProcName := ProcName( 1 )
         o:nProcLine := ProcLine( 1 )
      ENDIF
#endif
	ENDIF

   InitDummy ( FormHandle )

   IF VirtualHeight > 0
      SetScrollRange ( Formhandle, SB_VERT, 0, VirtualHeight - h, .T. )
   ENDIF
   IF VirtualWidth > 0
      SetScrollRange ( Formhandle, SB_HORZ, 0, VirtualWidth - w, .T. )
   ENDIF

   IF ISARRAY ( aMin ) .AND. ISARRAY ( aMax )
      iif( aMin[ 1 ] == NIL, NIL, _HMG_aFormMinMaxInfo[ k ] [ 5 ] := aMin[ 1 ] )
      iif( aMin[ 2 ] == NIL, NIL, _HMG_aFormMinMaxInfo[ k ] [ 6 ] := aMin[ 2 ] )
      iif( aMax[ 1 ] == NIL, NIL, _HMG_aFormMinMaxInfo[ k ] [ 7 ] := aMax[ 1 ] )
      iif( aMax[ 2 ] == NIL, NIL, _HMG_aFormMinMaxInfo[ k ] [ 8 ] := aMax[ 2 ] )
   ENDIF

   IF _HMG_OwnerModalHandle
      _HMG_InplaceParentHandle := 0
   ENDIF

RETURN ( FormHandle )

/*
 * Routine: _DefineSplitChildWindow
 * Purpose: Defines a child window panel embedded within a SplitBox rebar container.
 *
 * Parameters:
 *   FormName      [C]   - Unique window identifier name.
 *   w             [N]   - Width in pixels.
 *   h             [N]   - Height in pixels.
 *   break         [L]   - Forces a new band/line break in the SplitBox if .T.
 *   grippertext   [C]   - Caption displayed on the split band gripper.
 *   nocaption     [L]   - Suppresses title caption if .T.
 *   title         [C]   - Band title text.
 *   fontname      [C]   - Default font family.
 *   fontsize      [N]   - Default font size.
 *   gotfocus      [B|C] - Event handler run on focus gain.
 *   lostfocus     [B|C] - Event handler run on focus loss.
 *   virtualheight [N]   - Scrollable canvas height.
 *   VirtualWidth  [N]   - Scrollable canvas width.
 *   Focused       [L]   - Sets initial focus flag if .T.
 *   scrollleft    [B|C] - Scroll left callback.
 *   scrollright   [B|C] - Scroll right callback.
 *   scrollup      [B|C] - Scroll up callback.
 *   scrolldown    [B|C] - Scroll down callback.
 *   hscrollbox    [B|C] - Horizontal thumb scroll callback.
 *   vscrollbox    [B|C] - Vertical thumb scroll callback.
 *   cursor        [C]   - Custom mouse cursor code/resource.
 *
 * Return:
 *   [N] - HWND handle of the created split child window.
 *
 * Side Effects:
 *   Adds a new band item to the parent ReBar control and attaches form metadata
 *   to `_HMG_aFormSplitChildList`.
 */
FUNCTION _DefineSplitChildWindow ( FormName, w, h, break, grippertext, nocaption, title, fontname, fontsize, gotfocus, lostfocus, ;
      virtualheight, VirtualWidth, Focused, scrollleft, scrollright, scrollup, scrolldown, hscrollbox, vscrollbox, cursor )
   LOCAL aRGB := { -1, -1, -1 }
   LOCAL BrushHandle, FormHandle
   LOCAL htooltip
   LOCAL ParentForm
   LOCAL mVar
   LOCAL hscroll, vscroll
   LOCAL nBand := 0
   LOCAL k
   LOCAL i
#ifdef _OBJECT_
   LOCAL o
#endif

   IF FormName == NIL
      FormName := _HMG_TempWindowName
   ENDIF

   IF _HMG_MainWindowFirst == .T.
      IF AScan ( _HMG_aFormType, 'A' ) == 0
         MsgMiniGuiError( "Main Window is not defined." )
      ENDIF
   ENDIF

   IF _IsWindowDefined ( FormName )
      MsgMiniGuiError( "Window: " + FormName + " is already defined." )
   ENDIF

   // Split child windows must reside strictly inside a SplitBox block
   IF _HMG_ActiveSplitBox == .F.
      MsgMiniGuiError( "SplitChild Windows can be defined only inside SplitBox." )
   ENDIF

   _HMG_ActiveFontName := hb_defaultValue( FontName, _HMG_DefaultFontName )

   _HMG_ActiveFontSize := hb_defaultValue( FontSize, _HMG_DefaultFontSize )

   IF VirtualHeight == NIL
      VirtualHeight := 0
      vscroll := .F.
   ELSE
      IF VirtualHeight <= h
         MsgMiniGuiError( "DEFINE WINDOW: Virtual Height must be greater than Window Height." )
      ENDIF
      vscroll := .T.
   ENDIF

   IF VirtualWidth == NIL
      VirtualWidth := 0
      hscroll := .F.
   ELSE
      IF VirtualWidth <= w
         MsgMiniGuiError( "DEFINE WINDOW: Virtual Width must be greater than Window Width." )
      ENDIF
      hscroll := .T.
   ENDIF

   _HMG_SplitChildActive := .T.

   ParentForm := _HMG_ActiveFormName

   mVar := '_' + FormName

   _HMG_ActiveFormNameBak := _HMG_ActiveFormName

   _HMG_ActiveFormName := FormName
   _HMG_BeginWindowActive := .T.

   UnRegisterWindow ( FormName )
   BrushHandle := RegisterSplitChildWindow( "", FormName, aRGB )

   i := GetFormIndex ( ParentForm )

   IF i > 0

      Formhandle := InitSplitChildWindow ( w, h, FormName, nocaption, title, vscroll, hscroll )

      IF cursor != NIL
         SetWindowCursor( FormHandle, cursor )
      ENDIF

      IF _HMG_SplitLastControl == 'TOOLBAR' .AND. _HMG_ActiveSplitBoxInverted == .F.
         Break := .T.
      ENDIF

      // Insert item band into the host ReBar control
      AddSplitBoxItem ( FormHandle, _HMG_aFormReBarHandle [i], w, break, grippertext,  ,  , _HMG_ActiveSplitBoxInverted )

      nBand := GetBandCount ( _HMG_aFormReBarHandle [i] )

      _HMG_SplitLastControl := 'SPLITCHILD'

   ENDIF

   __defaultNIL( @scrollup, "" )
   __defaultNIL( @scrolldown, "" )
   __defaultNIL( @scrollleft, "" )
   __defaultNIL( @scrollright, "" )
   __defaultNIL( @hscrollbox, "" )
   __defaultNIL( @vscrollbox, "" )

   htooltip := InitToolTip( FormHandle, SetToolTipBalloon() )

   IF SetToolTipMaxWidth() <> -1
      SendMessage( htooltip, TTM_SETMAXTIPWIDTH, 0, SetToolTipMaxWidth() )
   ENDIF

   k := AScan ( _HMG_aFormDeleted, .T. )

   IF k > 0

#ifdef _NAMES_LIST_
      _SetNameList( mVar , k )
#else
      Public &mVar. := k
#endif

      _HMG_aFormNames [ k ] := FormName
      _HMG_aFormHandles [ k ] :=  FormHandle
      _HMG_aFormActive [ k ] :=  .F.
      _HMG_aFormType [ k ] :=  'X'
      _HMG_aFormParentHandle [ k ] :=  GetFormHandle( ParentForm )
      _HMG_aFormReleaseProcedure [ k ] :=  ""
      _HMG_aFormInitProcedure [ k ] :=  ""
      _HMG_aFormToolTipHandle [ k ] :=  hToolTip
      _HMG_aFormContextMenuHandle [ k ] :=  0
      _HMG_aFormMouseDragProcedure [ k ] :=  ""
      _HMG_aFormSizeProcedure [ k ] :=  ""
      _HMG_aFormClickProcedure [ k ] :=  ""
      _HMG_aFormMouseMoveProcedure [ k ] :=  ""
      _HMG_aFormMoveProcedure [ k ] :=  ""
      _HMG_aFormDropProcedure [ k ] :=  ""
      _HMG_aFormDeleted [ k ] := .F.
      _HMG_aFormBkColor [ k ] := aRGB
      _HMG_aFormPaintProcedure [ k ] :=  ""
      _HMG_aFormNoShow [ k ] := .F.
      _HMG_aFormNotifyIconName [ k ] :=  ""
      _HMG_aFormNotifyIconToolTip [ k ] :=  ""
      _HMG_aFormNotifyIconLeftClick [ k ] :=  ""
      _HMG_aFormNotifyIconDblClick [ k ] :=  ""
      _HMG_aFormGotFocusProcedure [ k ] := gotfocus
      _HMG_aFormLostFocusProcedure [ k ] := lostfocus
      _HMG_aFormReBarHandle [ k ] :=  0
      _HMG_aFormNotifyMenuHandle [ k ] :=  _HMG_aFormReBarHandle [i]
      _HMG_aFormBrowseList [ k ] :=  {}
      _HMG_aFormSplitChildList [ k ] :=  {}
      _HMG_aFormVirtualHeight [ k ] :=  VirtualHeight
      _HMG_aFormVirtualWidth [ k ] :=  VirtualWidth
      _HMG_aFormFocused [ k ] :=  Focused
      _HMG_aFormScrollUp [ k ] :=  ScrollUp
      _HMG_aFormScrollDown [ k ] :=  ScrollDown
      _HMG_aFormScrollLeft [ k ] :=  ScrollLeft
      _HMG_aFormScrollRight [ k ] :=  ScrollRight
      _HMG_aFormHScrollBox [ k ] :=  HScrollBox
      _HMG_aFormVScrollBox [ k ] :=  VScrollBox
      _HMG_aFormBrushHandle [ k ] :=  BrushHandle
      _HMG_aFormFocusedControl [ k ] :=  0
      _HMG_aFormGraphTasks [ k ] :=  {}
      _HMG_aFormMaximizeProcedure [ k ] :=  Nil
      _HMG_aFormMinimizeProcedure [ k ] :=  Nil
      _HMG_aFormRestoreProcedure [ k ] :=  Nil
      _HMG_aFormAutoRelease [ k ] :=  .T.
      _HMG_aFormInteractiveCloseProcedure [ k ] :=  iif( nocaption, {|| .F.}, "" )
      _HMG_aFormMinMaxInfo [ k ] := InitMinMaxInfo ( FormHandle )
      _HMG_aFormActivateId [ k ] := 0
      _HMG_aFormMiscData1  [ k ] := {NIL, cursor, 0, nBand, grippertext}
      _HMG_aFormMiscData2  [ k ] := ''
#ifdef _HMG_COMPAT_
      _HMG_StopWindowEventProcedure [ k ] := .F.
#endif

   ELSE

      k := Len( _HMG_aFormNames ) + 1

#ifdef _NAMES_LIST_
      _SetNameList( mVar , k )
#else
      Public &mVar. := k
#endif

      AAdd ( _HMG_aFormNames, FormName )
      AAdd ( _HMG_aFormHandles, FormHandle )
      AAdd ( _HMG_aFormActive, .F. )
      AAdd ( _HMG_aFormType, 'X' )
      AAdd ( _HMG_aFormParentHandle, GetFormHandle( ParentForm ) )
      AAdd ( _HMG_aFormReleaseProcedure, "" )
      AAdd ( _HMG_aFormInitProcedure, "" )
      AAdd ( _HMG_aFormToolTipHandle, hToolTip )
      AAdd ( _HMG_aFormContextMenuHandle, 0 )
      AAdd ( _HMG_aFormMouseDragProcedure, "" )
      AAdd ( _HMG_aFormSizeProcedure, "" )
      AAdd ( _HMG_aFormClickProcedure, "" )
      AAdd ( _HMG_aFormMouseMoveProcedure, "" )
      AAdd ( _HMG_aFormMoveProcedure, "" )
      AAdd ( _HMG_aFormDropProcedure, "" )
      AAdd ( _HMG_aFormDeleted, .F. )
      AAdd ( _HMG_aFormBkColor, aRGB )
      AAdd ( _HMG_aFormPaintProcedure, "" )
      AAdd ( _HMG_aFormNoShow, .F. )
      AAdd ( _HMG_aFormNotifyIconName, "" )
      AAdd ( _HMG_aFormNotifyIconToolTip, "" )
      AAdd ( _HMG_aFormNotifyIconLeftClick, "" )
      AAdd ( _HMG_aFormNotifyIconDblClick, "" )
      AAdd ( _HMG_aFormGotFocusProcedure, gotfocus )
      AAdd ( _HMG_aFormLostFocusProcedure, lostfocus )
      AAdd ( _HMG_aFormReBarHandle, 0 )
      AAdd ( _HMG_aFormNotifyMenuHandle, _HMG_aFormReBarHandle [i] )
      AAdd ( _HMG_aFormBrowseList, {} )
      AAdd ( _HMG_aFormSplitChildList, {} )
      AAdd ( _HMG_aFormVirtualHeight, VirtualHeight )
      AAdd ( _HMG_aFormVirtualWidth, VirtualWidth )
      AAdd ( _HMG_aFormFocused, Focused )
      AAdd ( _HMG_aFormScrollUp, ScrollUp )
      AAdd ( _HMG_aFormScrollDown, ScrollDown )
      AAdd ( _HMG_aFormScrollLeft, ScrollLeft )
      AAdd ( _HMG_aFormScrollRight, ScrollRight )
      AAdd ( _HMG_aFormHScrollBox, HScrollBox )
      AAdd ( _HMG_aFormVScrollBox, VScrollBox )
      AAdd ( _HMG_aFormBrushHandle, BrushHandle )
      AAdd ( _HMG_aFormFocusedControl, 0 )
      AAdd ( _HMG_aFormGraphTasks, {} )
      AAdd ( _HMG_aFormMaximizeProcedure, Nil )
      AAdd ( _HMG_aFormMinimizeProcedure, Nil )
      AAdd ( _HMG_aFormRestoreProcedure, Nil )
      AAdd ( _HMG_aFormAutoRelease, .T. )
      AAdd ( _HMG_aFormInteractiveCloseProcedure, iif( nocaption, {|| .F.}, "" ) )
      AAdd ( _HMG_aFormMinMaxInfo, {} )
      AAdd ( _HMG_aFormActivateId, 0 )
      AAdd ( _HMG_aFormMiscData1, {NIL, cursor, 0, nBand, grippertext} )
      AAdd ( _HMG_aFormMiscData2, '' )
#ifdef _HMG_COMPAT_
      AAdd ( _HMG_StopWindowEventProcedure, .F. )
#endif

   ENDIF

   _HMG_ActiveSplitChildIndex := k
   _SetThisFormInfo ( k )

   IF _HMG_lOOPEnabled
      Eval ( _HMG_bOnFormInit, k, mVar )
#ifdef _OBJECT_
      o := _WindowObj( FormHandle )
      IF HB_ISOBJECT( o )
         o:cProcFile := ProcFile( 1 )
         o:cProcName := ProcName( 1 )
         o:nProcLine := ProcLine( 1 )
      ENDIF
#endif
   ENDIF

   InitDummy ( FormHandle )

   AAdd ( _HMG_aFormSplitChildList [i] , _HMG_ActiveSplitChildIndex )

   IF VirtualHeight > 0
      SetScrollRange ( FormHandle, SB_VERT, 0, VirtualHeight - h, .T. )
   ENDIF
   IF VirtualWidth > 0
      SetScrollRange ( FormHandle, SB_HORZ, 0, VirtualWidth - w, .T. )
   ENDIF

RETURN ( FormHandle )

/*
 * Routine: _SetThisFormInfo
 * Purpose: Updates pseudo-variables and global context information for the target form.
 *
 * Parameters:
 *   i [N|C|O] - (Optional) 1-based index, window name, or window object reference.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies `_HMG_ThisFormIndex`, `_HMG_ThisFormName`, `_HMG_ThisType`, and event stacks.
 */
FUNCTION _SetThisFormInfo ( i )
   LOCAL lDefine := .T. // Flag indicating window creation event context

   IF PCount() == 0

      // Pop previous form event context off stack when no parameters supplied
      _PopEventInfo()

   ELSE

      IF HB_ISCHAR( i )
         i := GetFormIndex( i )
         lDefine := ( _HMG_aFormType [ i ] == "C" )
#ifdef _OBJECT_
      ELSEIF HB_ISOBJECT( i )
         i := iif( i:ClassName == 'TSBROWSE', GetFormIndex( i:cParentWnd ), i:Index )
         lDefine := .F.
#endif
      ENDIF

#ifdef _HMG_COMPAT_
      _HMG_LastActiveFormIndex := i
#endif
      _PushEventInfo()

      _HMG_ThisFormIndex   := i
      _HMG_ThisEventType   := iif( lDefine, 'DEFINE_WINDOW', '' )
      _HMG_ThisType        := iif( lDefine, 'W', _HMG_aFormType [ i ] )
      _HMG_ThisIndex       := i
      _HMG_ThisFormName    := _HMG_aFormNames [ _HMG_ThisFormIndex ]
      _HMG_ThisControlName := ""

   ENDIF

RETURN NIL

/*
 * Routine: _SetWindowSizePos
 * Purpose: Resizes and/or repositions a target window on screen.
 *
 * Parameters:
 *   FormName [C|N] - Window name or native HWND handle.
 *   row      [N]   - New Y coordinate (row) in pixels.
 *   col      [N]   - New X coordinate (column) in pixels.
 *   width    [N]   - New window width in pixels.
 *   height   [N]   - New window height in pixels.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Invokes Win32 API MoveWindow function causing GUI window redraw/relocation.
 */
FUNCTION _SetWindowSizePos ( FormName, row, col, width, height )
   LOCAL actpos := { 0, 0, 0, 0 }
   LOCAL hWnd := iif( ISNUMERIC( FormName ), FormName, GetFormHandle ( FormName ) )
#ifdef _PANEL_
   LOCAL lspang := ( ISNUMBER( row ) .AND. ISNUMBER( col ) .AND. ISNUMBER( width ) .AND. ISNUMBER( height ) )
#endif
   GetWindowRect( hWnd, /*@*/actpos )

   // Fallback to current dimensions/position for omitted parameters
   col    := IFNIL( col, actpos [ 1 ], col )
   row    := IFNIL( row, actpos [ 2 ], row )
   width  := IFNIL( width, actpos [ 3 ] - actpos [ 1 ], width )
   height := IFNIL( height, actpos [ 4 ] - actpos [ 2 ], height )

#ifdef _PANEL_
   // Adjust panel coordinates to client area of parent container window
   IF ISCHARACTER( FormName ) .AND. GetWindowType ( FormName ) == 'P'
      IF lspang
         col += GetBorderWidth()
         row += GetTitleHeight() + GetBorderHeight()
      ENDIF
      actpos := ScreenToClient ( _HMG_aFormParentHandle [ GetFormIndex ( FormName ) ], col, row )
      col := actpos [ 1 ]
      row := actpos [ 2 ]
   ENDIF
#endif
   MoveWindow ( hWnd, col, row, width, height, .T. )

RETURN NIL

/*
 * Routine: _GetWindowSizePos
 * Purpose: Queries the current screen coordinates and dimensions of a window.
 *
 * Parameters:
 *   FormName [C|N] - Window identifier string or HWND handle.
 *
 * Return:
 *   [A] - Array { row, col, width, height } in pixels.
 *
 * Side Effects:
 *   Queries native Win32 window metrics.
 */
FUNCTION _GetWindowSizePos ( FormName )
   LOCAL actpos := { 0, 0, 0, 0 }
   LOCAL hWnd := iif( ISNUMERIC( FormName ), FormName, GetFormHandle ( FormName ) )
   LOCAL row, col, width, height

   GetWindowRect( hWnd, /*@*/actpos )
   col    := actpos [ 1 ]
   row    := actpos [ 2 ]
   width  := actpos [ 3 ] - actpos [ 1 ]
   height := actpos [ 4 ] - actpos [ 2 ]

#ifdef _PANEL_
   // Offset window rect metrics when handling Panel controls
   IF ISCHARACTER( FormName ) .AND. GetWindowType ( FormName ) == 'P'
      col -= GetBorderWidth()
      row -= GetTitleHeight() + GetBorderHeight()
   ENDIF
#endif

RETURN { row, col, width, height }

/*
 * Routine: GetFormIndex
 * Purpose: Resolves a form index from its string identifier name.
 *
 * Parameters:
 *   FormName [C] - Window identifier string name.
 *
 * Return:
 *   [N] - 1-based index in `_HMG_aFormNames`, or 0 if not defined.
 *
 * Side Effects:
 *   Reads internal variable name table or dynamic global variables (`_<FormName>`).
 */
FUNCTION GetFormIndex ( FormName )
   LOCAL mVar := '_' + FormName

#ifdef _NAMES_LIST_
RETURN _GetNameList ( mVar )
#else
RETURN __mvGetDef ( mVar , 0 )
#endif

/*
 * Routine: _SetNotifyIconName
 * Purpose: Updates or changes the notification icon assigned to a main window in the system tray.
 *
 * Parameters:
 *   FormName [C] - Name of the host window.
 *   IconName [C] - Resource name or file path of the new icon.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Loads icon resource, frees old handle, and calls Shell_NotifyIcon API via ChangeNotifyIcon.
 */
FUNCTION _SetNotifyIconName ( FormName, IconName )
   LOCAL i

   IF ( i := GetFormIndex ( FormName ) ) > 0 .AND. _HMG_aFormType [ i ] == 'A'

      IF _HMG_aFormMiscData1 [ i ] [ 1 ] != NIL .AND. IsHIcon( _HMG_aFormMiscData1 [ i ] [ 1 ] )
         DestroyIcon ( _HMG_aFormMiscData1 [ i ] [ 1 ] )
      ENDIF

      _HMG_aFormMiscData1 [ i ] [ 1 ] := LoadTrayIcon ( GetResources(), IconName )

      ChangeNotifyIcon ( _HMG_aFormHandles [ i ], _HMG_aFormMiscData1 [ i ] [ 1 ], _HMG_aFormNotifyIconTooltip [ i ] )

      _HMG_aFormNotifyIconName [ i ] := IconName

   ENDIF

RETURN NIL

/*
 * Routine: _SetNotifyIconTooltip
 * Purpose: Updates the tooltip text shown when mouse hovers over system tray icon.
 *
 * Parameters:
 *   FormName    [C] - Name of target form.
 *   TooltipText [C] - New tooltip message text.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates system tray icon tooltips via Win32 Shell API.
 */
FUNCTION _SetNotifyIconTooltip ( FormName, TooltipText )
   LOCAL i

   IF ( i := GetFormIndex ( FormName ) ) > 0 .AND. _HMG_aFormType [ i ] == 'A'

      IF _HMG_aFormMiscData1 [ i ] [ 1 ] == NIL .AND. ! Empty ( _HMG_aFormNotifyIconName [ i ] )
         _HMG_aFormMiscData1 [ i ] [ 1 ] := LoadTrayIcon ( GetResources(), _HMG_aFormNotifyIconName [ i ] )
      ENDIF

      ChangeNotifyIcon ( _HMG_aFormHandles [ i ], _HMG_aFormMiscData1 [ i ] [ 1 ], TooltipText )

      _HMG_aFormNotifyIconTooltip [ i ] := TooltipText

   ENDIF

RETURN NIL

/*
 * Routine: _DefineSplitBox
 * Purpose: Creates a ReBar band container control (SplitBox) on a parent window.
 *
 * Parameters:
 *   ParentForm [C] - Name of parent window.
 *   bottom     [L] - Aligns SplitBox at the window bottom if .T.
 *   inverted   [L] - Inverts splitter alignment behavior if .T.
 *
 * Return:
 *   [N] - HWND handle of created ReBar control.
 *
 * Side Effects:
 *   Creates Win32 ReBar control and sets active splitbox global status flags.
 */
FUNCTION _DefineSplitBox ( ParentForm, bottom, inverted )
   LOCAL ControlHandle
   LOCAL i

   IF _HMG_BeginWindowActive
      ParentForm := _HMG_ActiveFormName
   ENDIF

   IF _HMG_FrameLevel > 0
      MsgMiniGuiError( "SPLITBOX cannot be defined inside Tab control." )
   ENDIF

   IF ! _IsWindowDefined ( ParentForm )
      MsgMiniGuiError( "Window: " + ParentForm + " is not defined." )
   ENDIF

   IF _HMG_SplitChildActive == .T.
      MsgMiniGuiError( "SplitBox cannot be defined inside SplitChild Windows." )
   ENDIF

   IF _HMG_ActiveSplitBox == .T.
      MsgMiniGuiError( "SplitBox controls cannot be nested." )
   ENDIF

   _HMG_ActiveSplitBoxInverted := Inverted
   _HMG_ActiveSplitBox := .T.
   _HMG_ActiveSplitBoxParentFormName := ParentForm

   ControlHandle := InitSplitBox ( GetFormHandle ( ParentForm ), bottom, inverted )

   IF ( i := GetFormIndex ( ParentForm ) ) > 0
      _HMG_aFormReBarHandle [ i ] := ControlHandle
   ENDIF

RETURN ControlHandle

/*
 * Routine: _EndSplitBox
 * Purpose: Finalizes definition block for a SplitBox control structure.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Resets `_HMG_ActiveSplitBox` state flag to .F.
 */
FUNCTION _EndSplitBox ()

   _HMG_SplitLastControl := 'TOOLBAR'
   _HMG_ActiveSplitBox := .F.

RETURN NIL

/*
 * Routine: _EndSplitChildWindow
 * Purpose: Finalizes definition block for a SplitChild window within a SplitBox.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Restores previous active window context and sets form activation state flag.
 */
FUNCTION _EndSplitChildWindow ()

   _HMG_ActiveFormName := _HMG_ActiveFormNameBak
   _HMG_SplitChildActive := .F.
   _HMG_aFormActive[ _HMG_ActiveSplitChildIndex ] := .T.

RETURN NIL

#ifdef _PANEL_
/*
 * Routine: _EndPanelWindow
 * Purpose: Finalizes definition block for an embedded Panel window.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Restores active form state and resets `_HMG_ParentWindowActive`.
 */
FUNCTION _EndPanelWindow ()

   _HMG_ActiveFormName := _HMG_ActiveFormNameBak
   _HMG_ParentWindowActive := .F.

RETURN NIL

#endif

/*
 * Routine: _EndWindow
 * Purpose: Closes the current DEFINE WINDOW block structure for any window type.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Resets `_HMG_BeginWindowActive` to .F., updates active form globals, and pops event context.
 */
FUNCTION _EndWindow ()

   DO CASE
   CASE _HMG_SplitChildActive == .T.
      _EndSplitChildWindow ()
#ifdef _PANEL_
   CASE _HMG_ParentWindowActive == .T.
      _EndPanelWindow ()
#endif
   CASE _HMG_MdiChildActive == .T.  // Process MDI Child window end
      _EndMdiChildWindow ()
   OTHERWISE
      _HMG_BeginWindowActive := .F.
      _HMG_ActiveFormName := ""
   ENDCASE

   _PopEventInfo()

RETURN NIL

/*
 * Routine: InputBox
 * Purpose: Displays a modal dialog box prompting the user to enter text.
 *
 * Parameters:
 *   cInputPrompt   [C] - Label text instructing the user.
 *   cDialogCaption [C] - Window title caption.
 *   cDefaultValue  [C] - Initial default value for textbox.
 *   nTimeout       [N] - Auto-close timer interval in milliseconds.
 *   cTimeoutValue  [C] - Return value if dialog times out.
 *   lMultiLine     [L] - Enables multiline editbox input if .T.
 *   lCanceled     [@L] - Output pass-by-reference flag set to .T. if user cancels.
 *
 * Return:
 *   [C] - String value entered by user, or default value / timeout value if cancelled.
 *
 * Side Effects:
 *   Creates, renders, and activates a modal window named `_InputBox`, then destroys it.
 */
FUNCTION InputBox ( cInputPrompt, cDialogCaption, cDefaultValue, nTimeout, cTimeoutValue, lMultiLine, /*@*/lCanceled )
   LOCAL lIsVistaOrLater := IsVistaOrLater()
   LOCAL nBordW  := iif( lIsVistaOrLater, GetBorderWidth() / 2 + 2, 0 )
   LOCAL nTitleH := GetTitleHeight() + iif( lIsVistaOrLater, GetBorderHeight() / 2 + 2, 0 )
   LOCAL nMLines := iif( ValType ( lMultiLine ) == 'L' .AND. lMultiLine, 150, 0 )
   LOCAL bCancel := {|| _HMG_DialogCancelled := lCanceled := .T., DoMethod( '_InputBox', 'Release' ) }
   LOCAL RetVal  := '', lOk := .F.

   hb_default( @cInputPrompt, '' )
   hb_default( @cDialogCaption, '' )
   hb_default( @cDefaultValue, '' )

   DEFINE WINDOW _InputBox;
      AT 0, 0;
      WIDTH 350 + nBordW;
      HEIGHT 115 + nMLines + nTitleH;
      TITLE cDialogCaption;
      MODAL;
      ON SIZE _InputBoxAdjust( nTitleH, nBordW ) ;
      ON INTERACTIVECLOSE iif( lOk, NIL, _HMG_DialogCancelled := lCanceled := .T. )

      ON KEY ESCAPE ACTION Eval( bCancel )

      @ 07, 10 LABEL _Label VALUE cInputPrompt AUTOSIZE
      IF nMLines > 0
         @ 30, 10 EDITBOX _TextBox VALUE cDefaultValue HEIGHT 26 + nMLines WIDTH 320
      ELSE
         @ 30, 10 TEXTBOX _TextBox VALUE cDefaultValue HEIGHT 26 WIDTH 320 ;
            ON ENTER IFEMPTY( _InputBox._TextBox.Value, Nil, _InputBox._Ok.OnClick )

         _InputBox.MaxHeight := ( _InputBox.Height )
      ENDIF

      @ 67 + nMLines, 120 BUTTON _Ok;
         CAPTION _HMG_MESSAGE [ 6 ];
         ACTION ( lOk := .T., _HMG_DialogCancelled := lCanceled := .F., ;
            RetVal := _InputBox._TextBox.Value, _InputBox.Release )

      @ 67 + nMLines, 230 BUTTON _Cancel;
        CAPTION _HMG_MESSAGE [ 7 ];
        ACTION Eval( bCancel )

      IF ISNUMERIC ( nTimeout )
         DEFINE TIMER _InputBox INTERVAL nTimeout ;
            ACTION ( IFCHAR ( cTimeoutValue, RetVal := cTimeoutValue, Nil ), _InputBox.Release )
      ENDIF

   END WINDOW

   IF _InputBox._Label.Width > 280
      _InputBox.Width := _InputBox._Label.Width + 34 + nBordW
   ENDIF

   _InputBox.MinWidth  := ( _InputBox.Width )
   _InputBox.MinHeight := ( _InputBox.Height )

   CENTER WINDOW _InputBox
   ACTIVATE WINDOW _InputBox

RETURN ( RetVal )

/*
 * Routine: _InputBoxAdjust
 * Purpose: Resizes and repositions inner controls inside the InputBox on WM_SIZE events.
 *
 * Parameters:
 *   nTitleH [N] - Title bar height metric.
 *   nBordW  [N] - Border width metric.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates control dimensions and invalidates input box region for redraw.
 */
STATIC PROCEDURE _InputBoxAdjust ( nTitleH, nBordW )
   LOCAL nWidth  := _InputBox.Width
   LOCAL nHeight := _InputBox.Height

   _InputBox._TextBox.Width  := nWidth  - 30 - nBordW
   _InputBox._TextBox.Height := nHeight - 89 - nTitleH

   _InputBox._Ok.Row         := nHeight - 48 - nTitleH
   _InputBox._Ok.Col         := nWidth  - 230 - nBordW

   _InputBox._Cancel.Row     := nHeight - 48 - nTitleH
   _InputBox._Cancel.Col     := nWidth  - 120 - nBordW

   InvalidateRect( GetFormHandle( '_InputBox' ), 0 )  // Force window repaint

RETURN

/*
 * Routine: _SetWindowRgn
 * Purpose: Applies a rectangular clipping region to a window.
 *
 * Parameters:
 *   name [C] - Window name identifier.
 *   col  [N] - Region X offset.
 *   row  [N] - Region Y offset.
 *   w    [N] - Region width.
 *   h    [N] - Region height.
 *   lx   [N] - Corner roundness parameter or region type flag.
 *
 * Return:
 *   [N] - Region handle (HRGN).
 *
 * Side Effects:
 *   Calls Win32 SetWindowRgn function altering non-rectangular visual bounds of window.
 */
FUNCTION _SetWindowRgn ( name, col, row, w, h, lx )
   LOCAL i := GetFormIndex ( name )

   _HMG_aFormMiscData1 [ i ] [ 3 ] := c_SetWindowRgn( GetFormHandle( name ), col, row, w, h, lx )

RETURN _HMG_aFormMiscData1 [ i ] [ 3 ]

/*
 * Routine: _SetPolyWindowRgn
 * Purpose: Applies a custom polygonal clipping region to a window.
 *
 * Parameters:
 *   name    [C] - Window identifier string.
 *   apoints [A] - Array of { X, Y } vertex coordinate pairs.
 *   lx      [N] - Polygon fill mode flag.
 *
 * Return:
 *   [N] - Region handle (HRGN).
 *
 * Side Effects:
 *   Applies custom polygon window region via Win32 C library call.
 */
FUNCTION _SetPolyWindowRgn ( name, apoints, lx )
   LOCAL i := GetFormIndex ( name )
   LOCAL apx := {}, apy := {}

   AEval( apoints, {| x | AAdd( apx, x [ 1 ] ), AAdd( apy, x [ 2 ] ) } )

   _HMG_aFormMiscData1 [ i ] [ 3 ] := c_SetPolyWindowRgn( GetFormHandle( name ), apx, apy, lx )

RETURN _HMG_aFormMiscData1 [ i ] [ 3 ]

/*
 * Routine: _ActivateWindow
 * Purpose: Activates one or more specified defined windows and enters the event message loop.
 *
 * Parameters:
 *   aForm     [A] - Array of window names or single string name wrapped in an array.
 *   lNoWait   [L] - Skips entering message loop if .T.
 *   lDebugger [L] - Internal flag indicating debug execution mode.
 *   bInit     [B] - Optional initial block procedure parameter.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Displays window(s), executes init callbacks, refreshes controls, and runs DO MESSAGE LOOP.
 */
FUNCTION _ActivateWindow ( aForm, lNoWait, lDebugger, bInit )
   LOCAL MainFound := .F.
   LOCAL nForm := Len( aForm )
   LOCAL VisibleModalCount := 0
   LOCAL VisibleModalName := ''
   LOCAL FormName
   LOCAL TmpId
   LOCAL i
#ifdef _PANEL_
   LOCAL x, FormCount := Len ( _HMG_aFormNames )
#endif

   // Validate window activation state constraints
   IF _HMG_ThisEventType == 'WINDOW_RELEASE'
      IF !( "_ALERT" $ ProcName( 1 ) .OR. ProcName( 2 ) == "_ALERT" )
         MsgMiniGuiError( "ACTIVATE WINDOW: activate windows within an ON RELEASE window procedure is not allowed." )
      ENDIF
   ENDIF

   IF _HMG_BeginWindowActive
      MsgMiniGUIError( "ACTIVATE WINDOW: DEFINE WINDOW Structure is not closed." )
   ENDIF

   IF _HMG_ThisEventType == 'WINDOW_GOTFOCUS'
      MsgMiniGUIError( "ACTIVATE WINDOW / Activate(): Not allowed in window's GOTFOCUS event procedure." )
   ENDIF

   IF _HMG_ThisEventType == 'WINDOW_LOSTFOCUS'
      MsgMiniGUIError( "ACTIVATE WINDOW / Activate(): Not allowed in window's LOSTFOCUS event procedure." )
   ENDIF

   // Search form array for primary main application window
   FOR EACH FormName IN aForm

      i := GetFormIndex ( FormName )

      Do_WindowEventProcedure( bInit, i, 'WINDOW_ACTIVATE' )

      IF _HMG_aFormType [ i ] == 'A'
         MainFound := .T.
         EXIT
      ENDIF

   NEXT

   IF _HMG_MainWindowFirst == .T.
      // Validate correct sequence for Main Window activation
      IF _HMG_MainActive == .F.
         IF MainFound == .F.
            MsgMiniGUIError( "ACTIVATE WINDOW: Main Window must be activated in the first ACTIVATE WINDOW command." )
         ENDIF
      ELSE
         IF MainFound == .T.
            MsgMiniGUIError( "ACTIVATE WINDOW: Main Window already active." )
         ENDIF
      ENDIF
   ENDIF

   hb_default( @lNoWait, .F. )

   IF MainFound == .T.
      _HMG_MainActive := .T.
   ENDIF

   IF nForm > 1

      IF _HMG_IsModalActive .AND. bInit == NIL
         MsgMiniGUIError( "Multiple Activation can not be used when a Modal window is active." )
      ENDIF

      TmpId := _GenActivateId( nForm )

      FOR EACH FormName IN aForm

         IF ! _IsWindowDefined ( Formname )
            MsgMiniGUIError( "Window: " + FormName + " is not defined." )
         ENDIF

         IF _IsWindowActive ( FormName )
            MsgMiniGUIError( "Window: " + FormName + " already active." )
         ENDIF

#ifdef _PANEL_
         IF GetWindowType ( FormName ) == 'P'
            MsgMiniGUIError( "Panel Windows can't be explicity activated (They are activated via its parent)." )
         ENDIF
#endif
         i := GetFormIndex ( FormName )

#ifdef _PANEL_
         // Automatically activate child panel windows attached to this parent
         FOR x := 1 TO FormCount

            IF _HMG_aFormType [ x ] == 'P' .AND. _HMG_aFormParentHandle [ x ] == _HMG_aFormHandles [ i ]

               IF _HMG_aFormNoShow [ x ] == .F.
                  _ShowWindow ( _HMG_aFormNames [ x ] )
               ENDIF

               _SetActivationFlag( x )
               _ProcessInitProcedure( x )
               _RefreshDataControls( x )

               IF _SetFocusedSplitChild( x ) == .F.
                  _SetActivationFocus( x )
               ENDIF

            ENDIF

         NEXT x
#endif
         // Validate modal window display constraints
         IF _HMG_aFormType [ i ] == "M" .AND. _HMG_aFormNoShow [ i ] == .F.
            VisibleModalName := _HMG_aFormNames [ i ]
            IF ++VisibleModalCount > 1
               MsgMiniGUIError( "ACTIVATE WINDOW: Only one initially visible modal window is allowed." )
            ENDIF
         ENDIF

         _HMG_aFormActivateId [ i ] := TmpId

         IF _HMG_aFormNoShow [ i ] == .F.
            ShowWindow( _HMG_aFormHandles [ i ] )
         ENDIF

         _SetActivationFlag( i )
         _ProcessInitProcedure( i )
         _RefreshDataControls( i )

      NEXT

      // Set focus and visible status for active forms
      IF VisibleModalCount == 1
         _ShowWindow ( VisibleModalName )
      ELSE
         IF _SetFocusedSplitChild( i ) == .F.
            _SetActivationFocus( i )
         ENDIF
      ENDIF

   ELSE

      FormName := aForm [ 1 ]

      IF ! _IsWindowDefined ( Formname )
         MsgMiniGUIError( "Window " + FormName + " is not defined." )
      ENDIF

      IF _IsWindowActive ( FormName )
         MsgMiniGUIError( "Window " + FormName + " already active." )
      ENDIF

#ifdef _PANEL_
      IF GetWindowType ( FormName ) == 'P'
         MsgMiniGUIError( "Panel Windows can't be explicity activated (They are activated via its parent)." )
      ENDIF
#endif
      i := GetFormIndex ( FormName )

#ifdef _PANEL_
      FOR x := 1 TO FormCount

         IF _HMG_aFormType [ x ] == 'P' .AND. _HMG_aFormParentHandle [ x ] == _HMG_aFormHandles [ i ]

            IF _HMG_aFormNoShow [ x ] == .F.
               _ShowWindow ( _HMG_aFormNames [ x ] )
            ENDIF

            _SetActivationFlag( x )
            _ProcessInitProcedure( x )
            _RefreshDataControls( x )

            IF _SetFocusedSplitChild( x ) == .F.
               _SetActivationFocus( x )
            ENDIF

         ENDIF

      NEXT x
#endif
      // Apply background painting for MDI client parent handles
      IF _HMG_BeginWindowMDIActive
         IF _HMG_aFormBkColor [ i ] [ 1 ] != -1
            SetWindowBackground( _HMG_MainClientMDIHandle, PaintBkGnd( _HMG_MainClientMDIHandle, _HMG_aFormBkColor [ i ] ) )
         ENDIF
      ENDIF

      IF _HMG_aFormType [ i ] == "M"

         _ShowWindow ( _HMG_aFormNames [ i ], .F. )

         _SetActivationFlag( i )
         _ProcessInitProcedure( i )
         _RefreshDataControls( i )

      ELSE

         IF _HMG_IsModalActive .AND. lNoWait == .F.
            MsgMiniGUIError( "Non Modal Window " + Formname + " can't be activated when a Modal window is active." )
         ENDIF

         IF _HMG_aFormNoShow [ i ] == .F.
            ShowWindow ( GetFormHandle( FormName ) )
         ENDIF

         _SetActivationFlag( i )
         _ProcessInitProcedure( i )
         _RefreshDataControls( i )

         IF _SetFocusedSplitChild( i ) == .F.
            _SetActivationFocus( i )
         ENDIF

      ENDIF

   ENDIF

   IF lNoWait == .F.
      // Launch standard Windows event message dispatch loop
      DO MESSAGE LOOP
   ENDIF

   IF nForm == 1 .AND. hb_defaultValue( lDebugger, .F. )

      i := GetFormIndex( FormName )

      _HMG_aFormActivateId [ i ] := _GenActivateId( ++nForm )

   ENDIF

RETURN NIL

/*
 * Routine: _ActivateAllWindows
 * Purpose: Activates all defined application windows at startup.
 *
 * Parameters:
 *   bInit [B] - Optional initial block parameter.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Activates all defined non-modal child forms along with the main form.
 */
FUNCTION _ActivateAllWindows ( bInit )
   LOCAL aForm := {}
   LOCAL MainName := ''
   LOCAL FormName
   LOCAL i

   IF AScan ( _HMG_aFormActive, .T. ) > 0
      MsgMiniGuiError( "ACTIVATE WINDOW ALL: this command should be used at application startup only." )
   ENDIF

   // Configure NoShow/AutoRelease flags across forms
   FOR EACH FormName IN _HMG_aFormNames

      i := hb_enumindex( FormName )

      IF _HMG_aFormDeleted [ i ] == .F.

         IF ! _HMG_aFormType [ i ] $ 'XP'

            IF _HMG_aFormType [ i ] == 'A'
               _HMG_aFormNoShow [ i ] := .F.
               _HMG_aFormAutoRelease [ i ] := .T.
               MainName := FormName
            ELSE
               _HMG_aFormNoShow [ i ] := .T.
               _HMG_aFormAutoRelease [ i ] := .F.
               AAdd ( aForm, FormName )
            ENDIF

         ENDIF

      ENDIF

   NEXT

   IF Empty ( MainName )
      MsgMiniGuiError( "ACTIVATE WINDOW ALL: Main Window is not defined." )
   ELSEIF Len ( aForm ) == 0
      MsgMiniGuiError( "ACTIVATE WINDOW ALL: Child windows are not defined." )
   ENDIF

   AAdd ( aForm, MainName )

   _ActivateWindow ( aForm, , , bInit )

RETURN NIL

/*
 * Routine: _RefreshDataControls
 * Purpose: Repaints and syncs data-bound controls (Browse, Grid, Combo) on form activation.
 *
 * Parameters:
 *   i [N] - Form index in global structures.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Triggers control value/painting updates and invalidates custom paint regions.
 */
PROCEDURE _RefreshDataControls ( i )
   LOCAL ControlIndex
   LOCAL SplitIndex
   LOCAL v

   IF ( Len ( _HMG_aFormGraphTasks [ i ] ) > 0 .OR. ;
      ISBLOCK( _HMG_aFormPaintProcedure [ i ] ) ) .AND. _HMG_ProgrammaticChange
      InvalidateRect( _HMG_aFormHandles [ i ], 0 )  // Trigger repaint
   ENDIF

   // Refresh data-bound controls registered in the form browse list
   FOR EACH ControlIndex IN _HMG_aFormBrowseList [ i ]

      v := _HMG_aControlValue [ControlIndex]
      _Refresh ( ControlIndex )

      IF _HMG_aControlType [ControlIndex] $ 'COMBO,BROWSE' .OR. ;
         _HMG_aControlType [ControlIndex] == "GRID" .AND. _HMG_aControlFontColor [ControlIndex] == .T. .AND. ;
         ISARRAY ( v )
         _SetValue ( , , v, ControlIndex )
      ENDIF

   NEXT

   // Refresh data controls inside child split panels
   IF Len ( _HMG_aFormSplitChildList [ i ] ) > 0

      FOR EACH SplitIndex IN _HMG_aFormSplitChildList [ i ]

         FOR EACH ControlIndex IN _HMG_aFormBrowseList [ SplitIndex ]

            v := _HMG_aControlValue [ ControlIndex ]
            _Refresh ( ControlIndex )

            IF _HMG_aControlType [ ControlIndex ] $ 'COMBO,BROWSE'
               _SetValue ( , , v, ControlIndex )
            ENDIF

         NEXT

      NEXT

   ENDIF

RETURN

/*
 * Routine: _SetActivationFlag
 * Purpose: Sets window active flags and enables drop files / auto-keyboard behavior.
 *
 * Parameters:
 *   i [N] - Form index.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies `_HMG_aFormActive`, registers drag-and-drop targets via DragAcceptFiles.
 */
PROCEDURE _SetActivationFlag ( i )
   LOCAL FormName
   LOCAL NoAutoReleaseFound := .F.

   _HMG_aFormActive [i] := .T.

   IF Len ( _HMG_aFormSplitChildList [i] ) > 0
      AEval ( _HMG_aFormSplitChildList [i], {|x| _HMG_aFormActive [x] := .T. } )
   ENDIF

   // Register window as a file drop target if DropProcedure block is defined
   IF ISBLOCK ( _HMG_aFormDropProcedure [i] )
      DragAcceptFiles ( _HMG_aFormHandles [i], .T. )
   ENDIF

   IF _HMG_aFormType [i] == 'A' .AND. ! _HMG_aFormNoShow [i] .AND. ! IsInsertActive ()

      FOR EACH FormName IN _HMG_aFormNames

         i := hb_enumindex( FormName )

         IF _HMG_aFormDeleted [i] == .F.

            IF ! _HMG_aFormType [i] $ 'AXP'

               IF _HMG_aFormAutoRelease [i] == .F.
                  NoAutoReleaseFound := .T.
                  EXIT
               ENDIF

            ENDIF

         ENDIF

      NEXT

      IF NoAutoReleaseFound == .F. .AND. _HMG_AutoScroll
         iif( _HMG_IsXPorLater, KeyToggleNT( VK_INSERT ), KeyToggle( VK_INSERT ) )
         DO EVENTS
      ENDIF

   ENDIF

RETURN

/*
 * Routine: _ProcessInitProcedure
 * Purpose: Executes the user ON INIT callback code block and handles window auto-adjustment.
 *
 * Parameters:
 *   i [N] - Form index.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Evaluates `_HMG_aFormInitProcedure[i]` callback block and performs layout auto-adjustments.
 */
PROCEDURE _ProcessInitProcedure ( i )

   IF ISBLOCK ( _HMG_aFormInitProcedure [ i ] )

      SuppressKeyAndMouseEvents()

      _PushEventInfo()

      _HMG_ThisEventType := 'WINDOW_INIT'
      _HMG_ThisFormIndex := i
      _HMG_ThisType := 'W'
      _HMG_ThisIndex := i
      _HMG_ThisFormName := _HMG_aFormNames[ _HMG_ThisFormIndex ]
      _HMG_ThisControlName := ""

      IF ISBLOCK ( _HMG_aFormInitProcedure [ i ] )
         Eval ( _HMG_aFormInitProcedure [ i ] )
      ENDIF

      _PopEventInfo()

   ENDIF

   IF _HMG_AutoAdjust .AND. _HMG_MainClientMDIHandle == 0

      IF _HMG_aFormActive [ i ] .AND. IsWindowSized( _HMG_aFormHandles [ i ] )
         _Autoadjust( _HMG_aFormHandles [ i ] )
      ENDIF

   ENDIF

RETURN

/*
 * Routine: _SetFocusedSplitChild
 * Purpose: Restores input focus to the active split child band if focused.
 *
 * Parameters:
 *   i [N] - Form index.
 *
 * Return:
 *   [L] - .T. if a split child window received focus, otherwise .F.
 *
 * Side Effects:
 *   Calls SetFocus API on child window handle.
 */
FUNCTION _SetFocusedSplitChild ( i )
   LOCAL SplitFocusFlag := .F.
   LOCAL nIndex

   IF Len ( _HMG_aFormSplitChildList [ i ] ) > 0

      FOR EACH nIndex IN _HMG_aFormSplitChildList [ i ]

         IF _HMG_aFormFocused [ nIndex ] == .T.
            SetFocus ( _HMG_aFormHandles [ nIndex ] )
            SplitFocusFlag := .T.
         ENDIF

      NEXT

   ENDIF

RETURN SplitFocusFlag

/*
 * Routine: _SetActivationFocus
 * Purpose: Automatically selects and focuses the default control when activating a window.
 *
 * Parameters:
 *   i [N] - Form index.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Changes Win32 keyboard input focus to the target control handle.
 */
PROCEDURE _SetActivationFocus ( i )
   LOCAL FocusDefined := .F.
   LOCAL Sp := GetFocus()
   LOCAL hControl
   LOCAL hParent
   LOCAL x

   hParent := _HMG_aFormHandles [i]

   // Prioritize double-click ownerdraw buttons
   FOR EACH hControl IN _HMG_aControlHandles

      x := hb_enumindex( hControl )

      IF _HMG_aControlParentHandles [x] == hParent .AND. _HMG_aControlType [x] != "HOTKEY"

         IF _HMG_aControlType [x] == "OBUTTON" .AND. ISLOGICAL ( _HMG_aControlDblClick [x] ) .AND. _HMG_aControlDblClick [x] == .T.
            SetFocus ( hControl )
            FocusDefined := .T.
            EXIT
         ENDIF

      ENDIF

   NEXT

   IF FocusDefined == .F.

      // Search for default push buttons or current focus match
      FOR EACH hControl IN _HMG_aControlHandles

         x := hb_enumindex( hControl )

         IF _HMG_aControlParentHandles [x] == hParent .AND. _HMG_aControlType [x] != "HOTKEY" // Skip hotkeys

            IF ISNUMBER ( hControl )
               IF _HMG_aControlType [x] == 'BUTTON' .AND. IsWindowHasStyle ( hControl, BS_DEFPUSHBUTTON )
                  _SetFocus ( , , x )
                  FocusDefined := .T.
                  EXIT
               ENDIF
               IF hControl == Sp
                  FocusDefined := .T.
                  EXIT
               ENDIF

            ELSEIF ISARRAY ( hControl )
               IF hControl [1] == Sp
                  FocusDefined := .T.
                  EXIT
               ENDIF

            ENDIF

         ENDIF

      NEXT

   ENDIF

   IF FocusDefined == .F.

      // Fallback to next dialog tab stop item
      IF ( x := AScan ( _HMG_aControlHandles, GetNextDlgTabItem ( hParent, 0, .F. ) ) ) > 0 .OR. ;
         ( x := AScan ( _HMG_aControlHandles, { |x| iif ( ISARRAY( x ), x [1] == GetNextDlgTabItem ( hParent, 0, .F. ), .F. ) } ) ) > 0
         _SetFocus ( , , x )
      ENDIF

      IF _HMG_BeginWindowMDIActive
         _HMG_aFormFocusedControl [i] := GetFocus()
      ENDIF

   ENDIF

RETURN

/*
 * Routine: _GenActivateId
 * Purpose: Generates a unique activation ID token for window activation tracking.
 *
 * Parameters:
 *   nForm [N] - Form count or index context.
 *
 * Return:
 *   [N] - Integer timestamp-derived activation identifier.
 *
 * Side Effects:
 *   Creates global dynamic variable entries tracking the activation session.
 */
STATIC FUNCTION _GenActivateId ( nForm )
   LOCAL TmpStr
   LOCAL TmpId

   REPEAT

      TmpId := Int ( Seconds() * 100 )
      TmpStr := '_HMG_ACTIVATE_' + hb_ntos ( TmpId )

#ifdef _NAMES_LIST_
   UNTIL ( _GetNameList ( TmpStr ) > 0 )
#else
   UNTIL __mvExist ( TmpStr )
#endif

#ifdef _NAMES_LIST_
   _SetNameList ( TmpStr, nForm )
#else
   __mvPublic ( TmpStr )
   __mvPut ( TmpStr, nForm )
#endif

RETURN( TmpId )

/*
 * Routine: _hmg_OnHideFocusManagement
 * Purpose: Re-enables parent or non-modal windows when a window is hidden or closed.
 *
 * Parameters:
 *   i [N] - Form index being hidden.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Enables Win32 window input states and switches active window context.
 */
PROCEDURE _hmg_OnHideFocusManagement ( i )
   LOCAL bEnableWindow := {|y, z| iif( _HMG_aFormDeleted [ z ] == .F., ;
      EnableWindow ( _HMG_aFormhandles [ z ] ), ), HB_SYMBOL_UNUSED( y ) }
   LOCAL x

   IF _HMG_aFormParentHandle [ i ] == 0

      // Non-modal window focus restore
      IF _HMG_IsModalActive == .F.

         AEval( _HMG_aFormHandles, bEnableWindow )

      ENDIF

   ELSE

      // Modal parent window focus restore
      IF ( x := AScan ( _HMG_aFormHandles, _HMG_aFormParenthandle [ i ] ) ) > 0

         IF _HMG_aFormType [ x ] == "M"

            _HMG_IsModalActive := .T.
            _HMG_ActiveModalHandle := _HMG_aFormParenthandle [ i ]

            EnableWindow ( _HMG_aFormParenthandle [ i ] )

            SwitchToThisWindow ( _HMG_aFormParenthandle [ i ] )

         ELSE

            _HMG_IsModalActive := .F.
            _HMG_ActiveModalHandle := 0

            AEval ( _HMG_aFormHandles, bEnableWindow )

            SwitchToThisWindow ( _HMG_aFormParenthandle [ i ] )

         ENDIF

      ELSE

         _HMG_IsModalActive := .F.
         _hmg_ActiveModalHandle := 0

         AEval ( _HMG_aFormHandles, bEnableWindow )

         IF ! Empty ( _HMG_MainHandle )
            SetFocus ( _HMG_MainHandle )
         ENDIF

      ENDIF

   ENDIF

RETURN

/*
 * Routine: _DoControlEventProcedure
 * Purpose: Safely executes a code block event handler for a GUI control.
 *
 * Parameters:
 *   bBlock     [B] - Code block to execute.
 *   i          [N] - Control index in global arrays.
 *   cEventType [C] - Name of event type.
 *   nParam     [U] - Optional event parameter 1.
 *   nParam2    [U] - Optional event parameter 2.
 *
 * Return:
 *   [L] - Event handler return result or default .T. (.F. if skipped).
 *
 * Side Effects:
 *   Pushes and pops global event execution context (`_HMG_ThisControlName`, etc.).
 */
FUNCTION _DoControlEventProcedure ( bBlock, i, cEventType, nParam, nParam2 )
   LOCAL lRetVal

#ifdef _HMG_COMPAT_
   IF _HMG_aControlType [ i ] != "HOTKEY"  // Record last active control index
      _HMG_LastActiveControlIndex := i
   ENDIF
   IF Len( _HMG_StopControlEventProcedure ) >= i .AND. _HMG_StopControlEventProcedure [ i ] == .T.  // Skip stopped events
      RETURN .F.
   ENDIF
#endif
   IF ISBLOCK ( bBlock )
      _PushEventInfo()
      _HMG_ThisFormIndex := AScan ( _HMG_aFormHandles, _HMG_aControlParentHandles [ i ] )
      _HMG_ThisType := 'C'
      _HMG_ThisIndex := i
      _HMG_ThisFormName := _HMG_aFormNames[ _HMG_ThisFormIndex ]
      _HMG_ThisControlName := _HMG_aControlNames[ _HMG_ThisIndex ]

      IF _HMG_BeginWindowActive == .F. .OR. !( hb_defaultValue( cEventType, '' ) == 'CONTROL_ONCHANGE' ) .OR. _HMG_MainClientMDIHandle != 0
#ifdef _OBJECT_
         i := _WindowObj( _HMG_aFormHandles[ _HMG_ThisFormIndex ] )
#endif
         lRetVal := Eval ( bBlock, hb_defaultValue( nParam, 0 ), nParam2, _HMG_ThisControlName, i )
      ENDIF

      _PopEventInfo()
      lRetVal := IFLOGICAL ( lRetVal, lRetVal, .T. )
   ELSE
      lRetVal := .F.
   ENDIF

RETURN lRetVal

/*
 * Routine: _DoWindowEventProcedure
 * Purpose: Safely executes a code block event handler for a window.
 *
 * Parameters:
 *   bBlock     [B] - Code block to evaluate.
 *   i          [N] - Form index.
 *   cEventType [C] - Window event descriptor string.
 *
 * Return:
 *   [L] - Result of code block evaluation, or .F. if invalid/blocked.
 *
 * Side Effects:
 *   Pushes and pops form event execution context.
 */
FUNCTION _DoWindowEventProcedure ( bBlock, i, cEventType )
   LOCAL lRetVal := .F.

#ifdef _HMG_COMPAT_
   IF cEventType != "TASKBAR"  // Track last active form
      _HMG_LastActiveFormIndex := i
   ENDIF
   IF Len( _HMG_StopWindowEventProcedure ) >= i .AND. _HMG_StopWindowEventProcedure [ i ] == .T.  // Skip if blocked
      RETURN .F.
   ENDIF
#endif
   IF ISBLOCK( bBlock )
      _PushEventInfo()
      _HMG_ThisFormIndex := i
      _HMG_ThisEventType := hb_defaultValue( cEventType, '' )
      _HMG_ThisType := 'W'
      _HMG_ThisIndex := i
      _HMG_ThisFormName := _HMG_aFormNames[ _HMG_ThisFormIndex ]
      _HMG_ThisControlName :=  ""

#ifdef _OBJECT_
      i := _WindowObj( _HMG_aFormHandles[ _HMG_ThisFormIndex ] )
#endif
      lRetVal := Eval ( bBlock, _HMG_ThisFormName, i )

      _PopEventInfo()
   ENDIF

RETURN lRetVal

/*
 * Routine: IsThemed
 * Purpose: Determines if Windows visual styles/themes (comctl32 v6+) are active.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   [L] - .T. if visual styles are active, .F. otherwise.
 *
 * Side Effects:
 *   Queries comctl32.dll version and theme status.
 */
FUNCTION IsThemed ()
   LOCAL aRetVal := GetDllVersion( "comctl32.dll" )

   IF IsXPThemeActive () .AND. ;
      ( IsAppXPThemed () .AND. aRetVal[ 1 ] >= 6 .OR. aRetVal[ 1 ] == 6 .AND. aRetVal[ 2 ] >= 10 )
      RETURN .T.
   ENDIF

RETURN .F.

/*
 * Routine: IsAppXPThemed
 * Purpose: Checks whether the current application process is manifest-themed.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   [L] - .T. if application is themed via UxTheme library.
 *
 * Side Effects:
 *   Calls Windows UxTheme API functions.
 */
FUNCTION IsAppXPThemed ()
   LOCAL uResult := .F.

   IF _HMG_IsXPorLater
      InitUxTheme()
      uResult := IsAppThemed()
      EndUxTheme()
   ENDIF

RETURN uResult

/*
 * Routine: IsXPThemeActive
 * Purpose: Checks if Windows theme engine is globally active in the operating system.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   [L] - .T. if system theme service is active.
 *
 * Side Effects:
 *   Calls Windows UxTheme IsThemeActive API.
 */
FUNCTION IsXPThemeActive ()
   LOCAL uResult := .F.

   IF _HMG_IsXPorLater
      InitUxTheme()
      uResult := IsThemeActive()
      EndUxTheme()
   ENDIF

RETURN uResult

/*
 * Routine: VirtualChildControlFocusProcess
 * Purpose: Scrolls a virtual window canvas automatically when a child control gains focus.
 *
 * Parameters:
 *   nControlHandle [N] - Control HWND.
 *   nWindowHandle  [N] - Parent window HWND.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Adjusts window scrollbar positions via `_HMG_SETVSCROLLVALUE` and `_HMG_SETHSCROLLVALUE`.
 */
PROCEDURE VirtualChildControlFocusProcess ( nControlHandle, nWindowHandle )
   LOCAL nWindowVirtualWidth
   LOCAL nWindowVirtualHeight
   LOCAL nWindowHeight  := 0
   LOCAL nWindowWidth   := 0
   LOCAL nControlHeight := 0
   LOCAL nControlWidth  := 0
   LOCAL nControlRow    := 0
   LOCAL nControlCol    := 0
   LOCAL nHorizontalScrollBoxPos
   LOCAL nVerticalScrollBoxPos
   LOCAL nHorizontalScrollBarRangeMax
   LOCAL nVerticalScrollBarRangeMax
   LOCAL nVisibleAreaFromRow
   LOCAL nVisibleAreaFromCol
   LOCAL nVisibleAreaToRow
   LOCAL nVisibleAreaToCol
   LOCAL nNewScrollBarPos
   LOCAL x

   IF _HMG_AutoScroll == .F. .OR. _HMG_AutoAdjust == .T.
      RETURN
   ENDIF

   // Retrieve dimensions for virtual form
   FOR x := 1 TO Len ( _HMG_aFormHandles )

      IF _HMG_aFormHandles [ x ] == nWindowHandle

         nWindowVirtualHeight := _HMG_aFormVirtualHeight [ x ]
         nWindowVirtualWidth := _HMG_aFormVirtualWidth [ x ]

         IF  nWindowVirtualHeight == 0 .AND. nWindowVirtualWidth == 0
            RETURN
         ELSE
            nWindowHeight := GetWindowHeight ( nWindowHandle )
            nWindowWidth := GetWindowWidth ( nWindowHandle )
            IF _IsControlDefined ( "StatusBar", _HMG_aFormNames [ x ] )
               SetProperty ( _HMG_aFormNames [ x ], "StatusBar", "Visible", .F. )
            ENDIF
            EXIT
         ENDIF

      ENDIF

   NEXT x

   // Retrieve control position and dimensions
   FOR x := 1 TO Len ( _HMG_aControlHandles )

      IF ISNUMBER ( nControlHandle )

         IF ISNUMBER ( _HMG_aControlHandles [ x ] )

            IF _HMG_aControlHandles [ x ] == nControlHandle

               nControlHeight := _HMG_aControlHeight[ x ]
               nControlWidth := _HMG_aControlWidth[ x ]
               nControlRow := _HMG_aControlRow[ x ]
               nControlCol := _HMG_aControlCol[ x ]
               EXIT

            ENDIF

         ELSEIF ISARRAY ( _HMG_aControlHandles [ x ] )

            IF AScan ( _HMG_aControlHandles [ x ], nControlHandle ) > 0

               nControlHeight := _HMG_aControlHeight[ x ]
               nControlWidth := _HMG_aControlWidth[ x ]
               nControlRow := _HMG_aControlRow[ x ]
               nControlCol := _HMG_aControlCol[ x ]
               EXIT

            ENDIF

         ENDIF

      ENDIF

   NEXT x

   nHorizontalScrollBoxPos := GetScrollPos ( nWindowHandle, SB_HORZ )
   nVerticalScrollBoxPos := GetScrollPos ( nWindowHandle, SB_VERT )

   nHorizontalScrollBarRangeMax := GetScrollRangeMax( nWindowHandle, SB_HORZ )
   nVerticalScrollBarRangeMax := GetScrollRangeMax( nWindowHandle, SB_VERT )

   nVisibleAreaFromRow := nVerticalScrollBoxPos
   nVisibleAreaFromCol := nHorizontalScrollBoxPos

   nVisibleAreaToRow := nVisibleAreaFromRow + nWindowHeight - 50
   nVisibleAreaToCol := nVisibleAreaFromCol + nWindowWidth - 10

   // Adjust vertical scrollbar position if focused control is out of visible region
   IF nControlRow + nControlHeight > nVisibleAreaToRow

      nNewScrollBarPos := nControlRow + nControlHeight - nWindowHeight + 100

      IF nNewScrollBarPos > nVerticalScrollBarRangeMax
         nNewScrollBarPos := nVerticalScrollBarRangeMax
      ENDIF

      _HMG_SETVSCROLLVALUE( nWindowHandle, nNewScrollBarPos )

   ELSE

      IF nControlRow + nControlHeight < nVisibleAreaFromRow

         nNewScrollBarPos := nControlRow - nWindowHeight - 100

         IF nNewScrollBarPos < 0
            nNewScrollBarPos := 0
         ENDIF

         _HMG_SETVSCROLLVALUE( nWindowHandle, nNewScrollBarPos )

      ENDIF

   ENDIF

   // Adjust horizontal scrollbar position if focused control is out of visible region
   IF nControlCol + nControlWidth > nVisibleAreaToCol

      nNewScrollBarPos := nControlCol + nControlWidth - nWindowWidth + 100

      IF nNewScrollBarPos > nHorizontalScrollBarRangeMax
         nNewScrollBarPos := nHorizontalScrollBarRangeMax
      ENDIF

      _HMG_SETHSCROLLVALUE( nWindowHandle, nNewScrollBarPos )

   ELSE

      IF nControlCol + nControlWidth < nVisibleAreaFromCol

         nNewScrollBarPos := nControlCol - nWindowWidth - 100

         IF nNewScrollBarPos < 0
            nNewScrollBarPos := 0
         ENDIF

         _HMG_SETHSCROLLVALUE( nWindowHandle, nNewScrollBarPos )

      ENDIF

   ENDIF

RETURN

/*
 * Routine: _IsWindowActive
 * Purpose: Determines whether a named window is currently active and rendered.
 *
 * Parameters:
 *   FormName [C] - Window identifier string.
 *
 * Return:
 *   [L] - .T. if window is active, .F. otherwise.
 *
 * Side Effects:
 *   Reads `_HMG_aFormActive` global array.
 */
FUNCTION _IsWindowActive ( FormName )
   LOCAL mVar
   LOCAL i

   IF ISCHARACTER( FormName )

      mVar := '_' + _NoQuote( FormName )

#ifdef _NAMES_LIST_
      i := _GetNameList ( mVar )
      IF i == 0
         RETURN .F.
      ENDIF
      RETURN ( _HMG_aFormActive [ i ] )
#else
      IF __mvExist ( mVar )
         i := __mvGet ( mVar )
         IF i == 0
            RETURN .F.
         ENDIF
         RETURN ( _HMG_aFormActive [ i ] )
      ENDIF
#endif

   ENDIF

RETURN .F.

/*
 * Routine: _IsWindowDefined
 * Purpose: Checks whether a window with the specified name is defined in memory.
 *
 * Parameters:
 *   FormName [C] - Window name.
 *
 * Return:
 *   [L] - .T. if defined and not deleted, .F. otherwise.
 *
 * Side Effects:
 *   Reads `_HMG_aFormDeleted` global array.
 */
FUNCTION _IsWindowDefined ( FormName )
   LOCAL mVar
   LOCAL i

   IF ISCHARACTER( FormName )

      mVar := '_' + _NoQuote( FormName )

#ifdef _NAMES_LIST_
      i := _GetNameList ( mVar )
      IF i == 0
         RETURN .F.
      ENDIF
      RETURN ( .NOT. ( _HMG_aFormDeleted [ i ] ) )
#else
      IF __mvExist ( mVar )
         i := __mvGet ( mVar )
         IF i == 0
            RETURN .F.
         ENDIF
         RETURN ( .NOT. ( _HMG_aFormDeleted [ i ] ) )
      ENDIF
#endif

   ENDIF

RETURN .F.

/*
 * Routine: GetWindowType
 * Purpose: Retrieves the single-character window type code ('A', 'C', 'M', 'P', 'X', 'S').
 *
 * Parameters:
 *   FormName [C] - Target form name.
 *
 * Return:
 *   [C] - Type code string, or empty string if window not found.
 *
 * Side Effects:
 *   Reads `_HMG_aFormType`.
 */
FUNCTION GetWindowType ( FormName )
   LOCAL i

   IF ( i := GetFormIndex ( FormName ) ) == 0
      RETURN ''
   ENDIF

RETURN ( _HMG_aFormType [ i ] )

/*
 * Routine: GetFormName
 * Purpose: Returns the canonical name of a form, handling active MDI windows automatically.
 *
 * Parameters:
 *   FormName [C] - Base form name candidate.
 *
 * Return:
 *   [C] - Window string name.
 *
 * Side Effects:
 *   Queries active MDI child dynamic properties if MDI mode is active.
 */
FUNCTION GetFormName ( FormName )
   LOCAL i

   IF _HMG_BeginWindowMDIActive

      IF GetActiveMdiHandle() == 0
         RETURN _HMG_MainClientMDIName
      ELSE
         RETURN _GetWindowProperty ( GetActiveMdiHandle(), "PROP_FORMNAME" )
      ENDIF

   ENDIF

   IF ( i := GetFormIndex ( FormName ) ) == 0
      RETURN ''
   ENDIF

RETURN ( _HMG_aFormNames [ i ] )

/*
 * Routine: GetFormToolTipHandle
 * Purpose: Retrieves the HWND handle of the tooltip control assigned to a window.
 *
 * Parameters:
 *   FormName [C] - Window string name.
 *
 * Return:
 *   [N] - HWND tooltip handle.
 *
 * Side Effects:
 *   Raises runtime MiniGUI error if target form is undefined.
 */
FUNCTION GetFormToolTipHandle ( FormName )
   LOCAL i

   IF _HMG_BeginWindowMDIActive
      FormName := GetFormName ( FormName )
   ENDIF

   IF ( i := GetFormIndex ( FormName ) ) == 0
      MsgMiniGuiError( "Form " + FormName + " is not defined." )
   ENDIF

RETURN ( _HMG_aFormToolTipHandle [ i ] )

/*
 * Routine: GetFormHandle
 * Purpose: Returns the native Win32 window handle (HWND) for a named form.
 *
 * Parameters:
 *   FormName [C] - Target form name.
 *
 * Return:
 *   [N] - Native Windows handle (HWND).
 *
 * Side Effects:
 *   Raises error if form is not found.
 */
FUNCTION GetFormHandle ( FormName )
   LOCAL i

   IF ( i := GetFormIndex ( FormName ) ) == 0
      MsgMiniGuiError( "Form " + FormName + " is not defined." )
   ENDIF

RETURN ( _HMG_aFormHandles [ i ] )

/*
 * Routine: ReleaseAllWindows
 * Purpose: Releases all GUI windows, controls, fonts, and resources, and terminates application.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Destroys all Win32 GUI handles, executes release handlers, closes databases, shuts down GDI+, and exits process.
 */
FUNCTION ReleaseAllWindows ()
   LOCAL FormHandle, hMenu, hIcon
   LOCAL ControlType
   LOCAL i

   IF _HMG_ThisEventType == 'WINDOW_RELEASE'
      MsgMiniGuiError ( "Release a window in its own ON RELEASE procedure or release the Main Window in any ON RELEASE procedure is not allowed." )
   ENDIF

   // Execute release handlers and clean form resource handles
   FOR EACH FormHandle IN _HMG_aFormHandles

      i := hb_enumindex ( FormHandle )

      IF _HMG_aFormActive [ i ] == .T.

         IF ErrorLevel() == 0

            _DoWindowEventProcedure ( _HMG_aFormReleaseProcedure [ i ], i, 'WINDOW_RELEASE' )

            IF _HMG_lOOPEnabled
               Eval ( _HMG_bOnFormDestroy, i )
            ENDIF

         ENDIF

         IF ! Empty ( _HMG_aFormNotifyIconName [ i ] )

            _HMG_aFormNotifyIconName [ i ] := ''
            ShowNotifyIcon ( FormHandle, .F., NIL, NIL )

         ENDIF

         IF GetObjectType ( _HMG_aFormBrushHandle [ i ] ) == OBJ_BRUSH
            DeleteObject ( _HMG_aFormBrushHandle [ i ] )
         ENDIF

         IF Len ( _HMG_aFormMiscData1[ i ] ) > 0 .AND. ( hIcon := _HMG_aFormMiscData1 [ i ] [ 1 ] ) != NIL .AND. IsHIcon( hIcon )
            DestroyIcon ( hIcon )
         ENDIF

         IF Len ( _HMG_aFormMiscData1[ i ] ) > 2 .AND. ! Empty ( _HMG_aFormMiscData1 [ i ] [ 3 ] )
            DeleteObject ( _HMG_aFormMiscData1 [ i ] [ 3 ] )
         ENDIF

      ENDIF

   NEXT

   IF IsExtendedMenuStyleActive() .AND. ! Empty ( _HMG_MainHandle ) .AND. IsMenu ( hMenu := GetMenu ( _HMG_MainHandle ) )
      _OnDestroyMenu ( hMenu )  // Release ownerdraw main menu structures
   ENDIF

   _HMG_DialogBoxProperty ( , , , , .F., @hIcon )

   IF hIcon != NIL .AND. IsHIcon( hIcon )
      DestroyIcon ( hIcon )
   ENDIF

   // Free all active child controls
   FOR EACH ControlType IN _HMG_aControlType

      i := hb_enumindex ( ControlType )

      IF _HMG_aControlDeleted [ i ] == .F.

         DO CASE
         CASE ControlType == 'HOTKEY'

            ReleaseHotKey ( _HMG_aControlParentHandles [ i ] , _HMG_aControlIds [ i ] )

         CASE ControlType == 'FONT'

            _EraseFontDef ( i )

         CASE ControlType == 'ANIGIF'

            _ReleaseAniGif ( _HMG_aControlNames [ i ], GetParentFormName( i ) )

         OTHERWISE

            IF ISCHARACTER ( _HMG_aControlNames [ i ] )
               _EraseControl ( i , AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [ i ] ) )
            ENDIF

         ENDCASE

      ENDIF

   NEXT

   // Release subsystems and libraries
   OleDataRelease()

   UnloadRichEditLib()
   UnloadRichEditExLib()

   GdiplusShutdown()

   FreeResources()

   TRY
      dbCloseAll()
   CATCH
   END

   IF Set( _SET_DEBUG )
      CheckRes()
      CheckStatic()
   ENDIF

#ifndef __XHARBOUR__
   IF ErrorLevel() == 0 .AND. ! hb_mtvm()
#else
   IF ErrorLevel() == 0 .AND. ! Hb_MultiThread()
#endif
      __Quit()
   ELSE
      ExitProcess()
   ENDIF

RETURN NIL

/*
 * Routine: _ReleaseWindow
 * Purpose: Posts a close message to release and destroy a specific window.
 *
 * Parameters:
 *   FormName [C] - Name of window to close.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Sends WM_CLOSE message to target window. Releasing Main Window delegates to ReleaseAllWindows().
 */
FUNCTION _ReleaseWindow ( FormName )
   LOCAL FormHandle
   LOCAL b
   LOCAL i

   b := _HMG_InteractiveClose
   _HMG_InteractiveClose := 1  // Temporarily disable interactive close handlers

   IF ! _IsWindowDefined ( Formname )
      MsgMiniGuiError( "Window: " + FormName + " is not defined." )
   ENDIF

   IF ! _IsWindowActive ( Formname )
      MsgMiniGuiError( "Window: " + FormName + " is not active." )
   ENDIF

   IF _HMG_ThisEventType == 'WINDOW_RELEASE'
      IF GetFormIndex ( FormName ) == _HMG_ThisIndex
         MsgMiniGuiError( "Release a window in its own ON RELEASE procedure or release the Main Window in any ON RELEASE procedure is not allowed." )
      ENDIF
   ENDIF

   IF GetWindowType ( FormName ) == 'A'

      IF _HMG_ThisEventType == 'WINDOW_RELEASE'
         MsgMiniGuiError( "Release a window in its own ON RELEASE procedure or release the Main Window in any ON RELEASE procedure is not allowed." )
      ELSE
         ReleaseAllWindows()
      ENDIF

   ENDIF

#ifdef _PANEL_
   IF GetWindowType ( FormName ) == 'P'
      MsgMiniGuiError( "Release a PANEL window is not allowed (It wiil be released via its parent)." )
   ENDIF
#endif

   i := GetFormIndex ( Formname )

   FormHandle := _HMG_aFormHandles [ i ]

   IF _HMG_aFormType [ i ] == 'M' .AND. _HMG_ActiveModalHandle <> FormHandle

      EnableWindow ( FormHandle )
      PostMessage ( FormHandle, WM_CLOSE, 0, 1 )

   ELSE

      AEval( _HMG_aFormHandles, {|x, i| iif( _HMG_aFormParentHandle [ i ] == FormHandle, _HMG_aFormParentHandle [ i ] := _HMG_MainHandle, ), ;
         HB_SYMBOL_UNUSED( x ) } )

      EnableWindow ( FormHandle )
      PostMessage ( FormHandle, WM_CLOSE, 0, 1 )

   ENDIF

   _HMG_InteractiveClose := b

RETURN NIL

/*
 * Routine: _ShowWindow
 * Purpose: Renders a window visible on screen and updates modal hierarchy if necessary.
 *
 * Parameters:
 *   FormName         [C] - Target form name string.
 *   lProcessMessages [L] - Processes pending Windows message queue via DO EVENTS if .T.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Invokes ShowWindow API, disables non-child windows if modal, and forces event processing.
 */
FUNCTION _ShowWindow ( FormName, lProcessMessages )
   LOCAL ActiveWindowHandle
   LOCAL i

   i := GetFormIndex ( FormName )

   IF _HMG_aFormType [ i ] == "M"

      IF _HMG_IsModalActive

         _HMG_aFormParentHandle [ i ] := _HMG_ActiveModalHandle

      ELSE

         ActiveWindowHandle := _HMG_UserWindowHandle

         IF AScan ( _HMG_aFormHandles, ActiveWindowHandle ) == 0
            ActiveWindowHandle := _HMG_MainHandle
         ENDIF

         _HMG_aFormParentHandle [ i ] := ActiveWindowHandle

      ENDIF

      // Disable non-modal parent windows when modal form is activated
      AEval ( _HMG_aFormHandles, { |y, x| iif( x <> i .AND. ! _HMG_aFormType [ x ] $ 'XP' .AND. ;
         _HMG_aFormParentHandle [ x ] != _HMG_aFormHandles [ i ], DisableWindow ( _HMG_aFormHandles [ x ] ), ), HB_SYMBOL_UNUSED( y ) } )

      IF Len ( _HMG_aFormSplitChildList [ i ] ) > 0
         AEval ( _HMG_aFormSplitChildList [ i ], { | x | EnableWindow ( _HMG_aFormHandles[ x ] ) } )
      ENDIF

      IF _HMG_MainWindowFirst == .T.
         _HMG_IsModalActive := .T.
      ENDIF

      _HMG_ActiveModalHandle := _HMG_aFormHandles [ i ]

      EnableWindow ( _HMG_aFormHandles [ i ] )

      IF _SetFocusedSplitChild ( i ) == .F.
         _SetActivationFocus ( i )
      ENDIF

   ENDIF

#ifdef _PANEL_
   IF _HMG_aFormType [ i ] == "P"
      _HMG_aFormNoShow [ i ] := .F.
   ENDIF
#endif

   ShowWindow ( _HMG_aFormHandles [ i ] )

   IF hb_defaultValue( lProcessMessages, .T. )

      DO EVENTS

   ENDIF

RETURN NIL

/*
 * Routine: _HideWindow
 * Purpose: Makes a window invisible without destroying its handle.
 *
 * Parameters:
 *   FormName [C] - Window name identifier.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Calls Win32 HideWindow API and triggers focus management via `_hmg_OnHideFocusManagement`.
 */
FUNCTION _HideWindow ( FormName )
   LOCAL FormHandle
   LOCAL i

   IF ( i := GetFormIndex ( FormName ) ) > 0

      FormHandle := _HMG_aFormHandles [ i ]

      IF IsWindowVisible ( FormHandle )

         IF _HMG_aFormType [ i ] == 'M'

            IF _HMG_ActiveModalHandle <> FormHandle
               MsgMiniGuiError ( "Non top modal windows can't be hide." )
            ENDIF

         ENDIF

#ifdef _PANEL_
         IF _HMG_aFormType [ i ] == "P"
            _HMG_aFormNoShow [ i ] := .T.
         ENDIF
#endif
         HideWindow ( FormHandle )
         _hmg_OnHideFocusManagement ( i )

      ENDIF

   ENDIF

RETURN NIL

/*
 * Routine: _CenterWindow
 * Purpose: Centers a specified window on screen or relative to its parent.
 *
 * Parameters:
 *   FormName [C] - Target form name.
 *   lParent  [L] - Centers relative to parent window if .T., else screen centered.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Moves the window rect using C_Center API wrapper.
 */
FUNCTION _CenterWindow ( FormName, lParent )
   LOCAL FormHandle := GetFormHandle( FormName )

   C_Center( FormHandle, iif( FormHandle == _HMG_MainHandle, .F., hb_defaultValue( lParent, .F. ) ) )

RETURN NIL

/*
 * Routine: _SetCenterWindowStyle
 * Purpose: Gets/sets the global window centering style flag.
 *
 * Parameters:
 *   lNewStyle [L] - (Optional) New logical centering style value.
 *
 * Return:
 *   [L] - Previous centering style value.
 *
 * Side Effects:
 *   Updates global internal setting variable `_HMG_SetCenterWindowStyle`.
 */
FUNCTION _SetCenterWindowStyle ( lNewStyle )
   LOCAL cVarName := "_HMG_" + SubStr( ProcName(), 5 )
   LOCAL lOldStyle := _AddNewGlobal( cVarName, .F. )

   IF ISLOGICAL( lNewStyle )
      _SetGetGlobal( cVarName, lNewStyle )
   ENDIF

RETURN lOldStyle

/*
 * Routine: SuppressKeyAndMouseEvents
 * Purpose: Flushes keyboard and mouse input buffers during a brief waiting period.
 *
 * Parameters:
 *   nWait [N] - Waiting timeout period in milliseconds (default 20).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Clears GUI input queues and dispatches pending message events.
 */
FUNCTION SuppressKeyAndMouseEvents ( nWait )

      REPEAT
         HMG_KeyboardClearBuffer()
         HMG_MouseClearBuffer()
         DO EVENTS
      UNTIL ( InkeyGUI( hb_defaultValue( nWait, 20 ) ) <> 0 )

RETURN NIL

/*
 * Routine: GetParentFormName
 * Purpose: Resolves parent window name from a control's index.
 *
 * Parameters:
 *   nControlIndex [N] - Control index in global array.
 *
 * Return:
 *   [C] - Name of parent window, or empty string if not found.
 *
 * Side Effects:
 *   Searches `_HMG_aFormHandles`.
 */
FUNCTION GetParentFormName ( nControlIndex )
   LOCAL i := AScan( _HMG_aFormHandles, _HMG_aControlParentHandles [ nControlIndex ] )

RETURN iif( i > 0, _HMG_aFormNames [ i ], "" )

#ifdef __XHARBOUR__
   #xtranslate hb_ValToExp( [<x,...>] ) => ValToPrgExp( <x> )
#endif

/*
 * Routine: MsgDebug
 * Purpose: Displays runtime debug diagnostic information for supplied parameters.
 *
 * Parameters:
 *   ... [Usual] - Variable list of expressions to inspect.
 *
 * Return:
 *   [C] - Formatted debug output message string.
 *
 * Side Effects:
 *   Pops up an AlertInfo/MsgInfo dialog displaying source execution line context.
 */
FUNCTION MsgDebug ( ... )
   LOCAL nCnt := PCount()
   LOCAL cMsg, xVal
   LOCAL cFormName, hWnd
   LOCAL i

   cMsg := "Called from: " + ProcName( 1 ) + "(" + hb_ntos( ProcLine( 1 ) ) + ") --> " + ProcFile( 1 ) + CRLF + CRLF

   // Formatter loop converting values and object states into text
   FOR i := 1 TO nCnt
      xVal := PValue( i )
      IF ISOBJECT( xVal )
#ifdef _OBJECT_
         IF _HMG_lOOPEnabled
            xVal := _o2log( xVal, , '>>> ', .T., .T. ) + CRLF
         ELSE
#endif
            xVal := "O:" + xVal:ClassName
#ifdef _OBJECT_
         ENDIF
#endif
      ELSE
         xVal := hb_ValToExp( xVal )
      ENDIF
      cMsg += xVal + iif( i < nCnt, ", ", "" )
   NEXT

   IF _HMG_lOnErrorStop
      IF _HMG_BeginWindowActive
         cFormName := _HMG_ActiveFormName
      ENDIF
      hWnd := GetActiveWindow()

      AlertInfo( cMsg, "DEBUG INFO", "_dbgicon" )

      SetFocus( hWnd )
      IF ISCHAR( cFormName )
         _HMG_BeginWindowActive := .T.
         _HMG_ActiveFormName := cFormName
      ENDIF
   ELSE
      MsgInfo( cMsg, "DEBUG INFO", 32001 )
   ENDIF

RETURN cMsg

/*
 * Routine: _InitSplashWindow
 * Purpose: Instantiates internal hidden splash screen window structure.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Creates window object `_HMG_SPLASHWINDOW`.
 */
PROCEDURE _InitSplashWindow ()

   DEFINE WINDOW _HMG_SPLASHWINDOW ;
      CHILD NOSHOW NOAUTORELEASE NOSIZE NOSYSMENU NOCAPTION

      @ 0, 0 IMAGE Image PICTURE ""

   END WINDOW

RETURN

/*
 * Routine: _ShowSplashWindow
 * Purpose: Renders and displays a splash screen image window for a specified duration.
 *
 * Parameters:
 *   cImage     [C] - Image file path or resource name.
 *   nDelay     [N] - Delay time in seconds.
 *   bOnInit    [B] - Action evaluated upon splash display.
 *   bOnRelease [B] - Action evaluated upon splash hide.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Displays topmost modal splash window and draws border graphics on window DC.
 */
PROCEDURE _ShowSplashWindow ( cImage, nDelay, bOnInit, bOnRelease )
   LOCAL aBmpSize := BmpSize( cImage )
   LOCAL width    := aBmpSize [1]
   LOCAL height   := aBmpSize [2]

   IF _IsWindowDefined( "_HMG_SPLASHWINDOW" ) .AND. width > 0 .AND. height > 0

      DEFAULT nDelay := 2, bOnInit := {|| HideWindow( App.Handle ) }, ;
         bOnRelease := {|| DoEvents(), ShowWindow( App.Handle ) }

      _HMG_SPLASHWINDOW.Image.Picture := cImage

      _HMG_SPLASHWINDOW.Width  := width
      _HMG_SPLASHWINDOW.Height := height

      CENTER WINDOW _HMG_SPLASHWINDOW

      // Paint border lines around splash frame
      DRAW LINE IN WINDOW _HMG_SPLASHWINDOW ;
         AT 0, 0 TO 0, Width ;
         PENCOLOR BLACK ;
         PENWIDTH 2

      DRAW LINE IN WINDOW _HMG_SPLASHWINDOW ;
         AT Height, 0 TO Height, Width ;
         PENCOLOR BLACK ;
         PENWIDTH 2

      DRAW LINE IN WINDOW _HMG_SPLASHWINDOW ;
         AT 0, 0 TO Height, 0 ;
         PENCOLOR BLACK ;
         PENWIDTH 2

      DRAW LINE IN WINDOW _HMG_SPLASHWINDOW ;
         AT 0, Width TO Height, Width ;
         PENCOLOR BLACK ;
         PENWIDTH 2

      _HMG_SPLASHWINDOW.Topmost := .T.
      _HMG_SPLASHWINDOW.Show()

      Eval( bOnInit )

      SendMessage( _HMG_SPLASHWINDOW.Handle, WM_PAINT, 0, 0 )

      HMG_SysWait( nDelay )

      _HMG_SPLASHWINDOW.Topmost := .F.
      _HMG_SPLASHWINDOW.Hide()

      Eval( bOnRelease )

   ELSE

      DoMethod ( App.FormName, 'Show' )

   ENDIF

RETURN

#ifdef _HMG_COMPAT_
/*
 * Routine: StopWindowEventProcedure
 * Purpose: Enables or disables window event procedures for a form.
 *
 * Parameters:
 *   cFormName [C] - Name of form.
 *   lStop     [L] - Flag setting whether window events are blocked (.T.) or allowed (.F.).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates `_HMG_StopWindowEventProcedure` array element.
 */
FUNCTION StopWindowEventProcedure ( cFormName, lStop )
   LOCAL i

   IF ( i := GetFormIndex ( cFormName ) ) > 0
      _HMG_StopWindowEventProcedure [i] := iif( ISLOGICAL( lStop ), lStop, .F. )
   ENDIF

RETURN NIL

/*
 * Routine: StopControlEventProcedure
 * Purpose: Enables or disables event procedures for a specific control.
 *
 * Parameters:
 *   cControlName [C] - Control identifier.
 *   cFormName    [C] - Host form name.
 *   lStop        [L] - Flag setting whether control events are blocked (.T.).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates `_HMG_StopControlEventProcedure` entry.
 */
FUNCTION StopControlEventProcedure ( cControlName, cFormName, lStop )
   LOCAL i

   IF ( i := GetControlIndex ( cControlName, cFormName ) ) > 0
      _HMG_StopControlEventProcedure [i] := iif( ISLOGICAL( lStop ), lStop, .F. )
   ENDIF

RETURN NIL

/*
 * Routine: GetLastActiveFormIndex
 * Purpose: Returns the index of the form that last executed an event procedure.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   [N] - 1-based form index, or 0 if deleted.
 *
 * Side Effects:
 *   Checks `_HMG_LastActiveFormIndex`.
 */
FUNCTION GetLastActiveFormIndex ()
   IF _HMG_LastActiveFormIndex > 0 .AND. _HMG_aFormDeleted[ _HMG_LastActiveFormIndex ] == .T.
      _HMG_LastActiveFormIndex := 0
   ENDIF

RETURN _HMG_LastActiveFormIndex

/*
 * Routine: GetLastActiveControlIndex
 * Purpose: Returns the index of the control that last executed an event procedure.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   [N] - 1-based control index, or 0 if deleted.
 *
 * Side Effects:
 *   Checks `_HMG_LastActiveControlIndex`.
 */
FUNCTION GetLastActiveControlIndex ()
   IF _HMG_LastActiveControlIndex > 0 .AND. _HMG_aControlDeleted[ _HMG_LastActiveControlIndex ] == .T.
      _HMG_LastActiveControlIndex := 0
   ENDIF

RETURN _HMG_LastActiveControlIndex

#endif

/*
 * Routine: WaitWindow
 * Purpose: Displays a temporary borderless popup window with a wait/progress message.
 *
 * Parameters:
 *   cMessage   [C|A] - Text message or array of string lines to display.
 *   lNoWait    [L|B] - If .T., function returns immediately without blocking.
 *   nWidth     [N]   - Explicit window width in pixels.
 *   nSize      [N]   - Label font size.
 *   cFont      [C]   - Label font family.
 *   aFontColor [A]   - RGB font color array.
 *   aBackColor [A]   - RGB background color array.
 *
 * Return:
 *   [C] - Internal wait window name string ("_HMG_CHILDWAITWINDOW").
 *
 * Side Effects:
 *   Defines, displays, and releases window `_HMG_CHILDWAITWINDOW`.
 */
FUNCTION WaitWindow ( cMessage, lNoWait, nWidth, nSize, cFont, aFontColor, aBackColor )
   LOCAL cFormName := "_HMG_CHILDWAITWINDOW"
   LOCAL lDefined := _IsWindowDefined( cFormName )
   LOCAL lIsModal
   LOCAL lWidth := ( nWidth == NIL )
   LOCAL nHeight
   LOCAL nY, nX, nW, nH, nI, nK
   LOCAL hFont, cTmp, nTmp, cLbl, bOnInit, l_No_Wait := .T.
#ifdef _HMG_COMPAT_
   LOCAL hWnd
#endif
#ifdef _NAMES_LIST_
   LOCAL oo, lo
#endif

   IF PCount() == 0

      IF lDefined
         nCtEfeito := 0
         cDescEfeito := ""
         DoMethod( cFormName, "Release" )
      ENDIF

   ELSE

      IF HB_ISBLOCK( lNoWait )
         bOnInit := lNoWait
         lNoWait := NIL
      ENDIF

#ifdef _NAMES_LIST_
      IF HB_ISNUMERIC( lNoWait )
         oo := _SetGetNamesList():Get( cFormName )
         IF ( lo := Empty( oo ) ) ; oo := oHmgData()
         ENDIF
         IF ( HB_ISCHAR( cMessage ) .OR. HB_ISARRAY( cMessage ) ) .AND. ! Empty( cMessage )
            oo:cMessage := cMessage
         ENDIF
         IF HB_ISCHAR( cFont ) .AND. ! Empty( cFont )
            oo:cFontName := cFont
         ENDIF
         IF IsArrayRGB( aFontColor )
            oo:aFontColor := aFontColor
         ENDIF
         IF IsArrayRGB( aBackColor )
            oo:aBackColor := aBackColor
         ENDIF
         IF lo ; _SetGetNamesList():Set( cFormName, oo )
         ENDIF
         RETURN oo
      ENDIF
#endif

      IF HB_ISLOGICAL( cMessage )
         lNoWait := cMessage
         cMessage := NIL

#ifdef _NAMES_LIST_
         oo := _SetGetNamesList( cFormName )
         IF HB_ISOBJECT( oo )
            DEFAULT aFontColor := oo:aFontColor, cMessage := oo:cMessage, ;
               aBackColor := oo:aBackColor, cFont := oo:cFontName
         ENDIF
#endif
         DEFAULT cMessage := "... Wait for the preparation to complete ..."
      ENDIF

      hb_default( @lNoWait, .F. )
      hb_default( @cFont, _HMG_DefaultFontName )

      // Normalize message text parameter into line array
      IF HB_ISCHAR( cMessage )
         IF CRLF $ cMessage
            cMessage := hb_ATokens( cMessage, CRLF )
         ELSEIF ";" $ cMessage
            cMessage := hb_ATokens( cMessage, ";" )
         ELSE
            cMessage := { cMessage }
         ENDIF
      ELSEIF ! HB_ISARRAY( cMessage )
         cMessage := { cMessage }
      ENDIF

      nK := Len( cMessage )

      IF lDefined

         IF lNoWait
            FOR nI := 1 TO nK
               cLbl := "Message" + iif( nI > 1, hb_ntos( nI ), "" )
               IF _IsControlDefined( cLbl, cFormName )
                  SetProperty( cFormName, cLbl, "Value", cValToChar( cMessage[ nI ] ) )
               ENDIF
            NEXT
         ENDIF

      ELSE

         lIsModal := _HMG_IsModalActive

         // Find longest message line for auto-sizing window
         nTmp := 1
         cTmp := cMessage[ nTmp ]
         FOR nI := 1 TO nK
            nTmp := iif( Len( cValToChar( cMessage[ nI ] ) ) > Len( cTmp ), nI, nTmp )
         NEXT
         cTmp := cValToChar( cMessage[ nTmp ] )

         DEFAULT nSize := 10

         nY := iif( IsVistaOrLater(), 4, 7 )
         nX := 12

         hFont := InitFont( cFont, nSize )
         nHeight := GetTextHeight ( NIL, "A", hFont )

         IF lWidth
            nWidth := GetTextWidth( NIL, cTmp, hFont ) + nX * 2
         ENDIF

         DeleteObject( hFont )

         nHeight += 8

#ifdef _HMG_COMPAT_
         IF ! Empty( _HMG_MainHandle )
            hWnd := iif( _HMG_BeginWindowMDIActive, GetActiveMdiHandle(), GetActiveWindow() )
            IF hWnd != NIL .AND. ( nI := GetFormIndexByHandle( hWnd ) ) > 0
               IF _HMG_aFormType [ nI ] $ "MSY"
                  _HMG_IsModalActive := .T.
               ENDIF
            ENDIF
         ENDIF
#endif
         IF lNoWait .AND. ! _HMG_IsModalActive
            DEFINE WINDOW _HMG_CHILDWAITWINDOW CHILD
         ELSE
            DEFINE WINDOW _HMG_CHILDWAITWINDOW MODAL
            IF HB_ISBLOCK( bOnInit )
               l_No_Wait := .F.
            ENDIF
         ENDIF

         nW := Min( 2 * nWidth, Min( GetDesktopWidth(), 800 ) )
         nH := nHeight * nK + nY * 2 + GetBorderHeight()

         SetProperty( cFormName, "Width", nW )
         SetProperty( cFormName, "Height", nH )

         IF hb_osIsWin11() .AND. _HMG_IsThemed .AND. HB_ISARRAY( aBackColor )
            SET REGION OF _HMG_CHILDWAITWINDOW ROUNDRECT 10, 10, nW, nH
         ENDIF

         SetProperty( cFormName, "Title", "" )
         SetProperty( cFormName, "TitleBar", .F. )
         SetProperty( cFormName, "SysMenu", .F. )

         IF HB_ISARRAY( aBackColor )
            SetProperty( cFormName, "BackColor", aBackColor )
         ELSEIF hb_osIsWin10() .AND. _HMG_IsThemed
            SetProperty( cFormName, "Height", GetProperty( cFormName, "Height" ) + 7 )
            SetProperty( cFormName, "BackColor", nRGB2Arr( GetSysColor( COLOR_WINDOW ) ) )
         ENDIF

         nW := GetProperty( cFormName, "ClientWidth" ) - nX * 2

         FOR nI := 1 TO nK
            cLbl := "Message" + iif( nI > 1, hb_ntos( nI ), "" )
            @ nY, nX LABEL &( cLbl ) WIDTH nW HEIGHT nHeight ;
               VALUE cValToChar( cMessage[ nI ] ) ;
               FONT cFont SIZE nSize ;
               FONTCOLOR aFontColor ;
               CENTERALIGN TRANSPARENT
            nY += nHeight
         NEXT

         IF lWidth .AND. GetProperty( cFormName, "Width" ) < 2 * nWidth
            SetProperty( cFormName, "Message", "Value", "" )
            _DefineTimer( "Timer", cFormName, 100, {|| EfeitoLabel( cMessage[ 1 ] ) } )
         ENDIF

         IF HB_ISBLOCK( bOnInit )
            _HMG_IsModalActive := .T.
            nK := GetFormIndex( cFormName )
            _HMG_aFormInitProcedure [ nK ] := bOnInit
         ENDIF

         END WINDOW

         DoMethod ( cFormName, "Center" )
         _ActivateWindow ( { cFormName }, l_No_Wait )

         _HMG_IsModalActive := lIsModal

         IF ! lNoWait
            IF _IsWindowDefined( cFormName ) 
               InkeyGUI( 0 )

               IF _IsControlDefined( "Timer", cFormName )
                  nCtEfeito := 0
                  cDescEfeito := ""
               ENDIF
               DoMethod( cFormName, "Release" )
            ENDIF
         ENDIF

      ENDIF

   ENDIF

   DO EVENTS

RETURN cFormName

/*
 * Routine: EfeitoLabel
 * Purpose: Timer procedure animating scrolling text inside WaitWindow.
 *
 * Parameters:
 *   cTxt [C] - Message text to scroll.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates label property value in real time.
 */
STATIC PROCEDURE EfeitoLabel ( cTxt )
   LOCAL cFormName := ThisWindow.Name
   LOCAL nDescLen := GetTextWidth( , cDescEfeito, _HMG_aControlFontHandle[ GetControlIndex( "Message", cFormName ) ] )
   LOCAL nLblLen := GetProperty( cFormName, "Message", "Width" )

   IF ++nCtEfeito > Len( cTxt )

      IF nDescLen > nLblLen
         nCtEfeito := 0
         cDescEfeito := ""
      ENDIF

      cDescEfeito += " "

   ELSE

      cDescEfeito += SubStr( cTxt, nCtEfeito, 1 )

      IF nDescLen >= nLblLen
         cDescEfeito := SubStr( cDescEfeito, 2 )
      ENDIF

   ENDIF

   SetProperty( cFormName, "Message", "Value", cDescEfeito )

RETURN

/*
 * Routine: _HMG_DialogBoxProperty
 * Purpose: Stores and retrieves static layout and icon properties for modal DialogBox instances.
 *
 * Parameters:
 *   nRow    [@N] - Row position.
 *   nCol    [@N] - Column position.
 *   lCenter [@L] - Center flag.
 *   Form    [@U] - Form handle or identifier.
 *   lSet     [L] - Pass .T. to set properties, .F. to read back into parameters.
 *   hIcon   [@N] - Dialog icon handle.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Stores state array in static global variable space.
 */
FUNCTION _HMG_DialogBoxProperty ( nRow, nCol, lCenter, Form, lSet, hIcon )
   LOCAL cVarName := ProcName()
   LOCAL aDialogBoxPosSizeInfo

   IF _SetGetGlobal( cVarName ) == NIL
      STATIC &cVarName AS GLOBAL VALUE Array( 5 )
   ENDIF

   IF hb_defaultValue( lSet, .T. )

      aDialogBoxPosSizeInfo := { nCol, nRow, lCenter, ;
         iif( HB_ISSTRING( Form ), GetFormHandle( Form ), Form ), hIcon }
      _SetGetGlobal( cVarName, aDialogBoxPosSizeInfo )

   ELSE

      aDialogBoxPosSizeInfo := _SetGetGlobal( cVarName )
      nCol    := aDialogBoxPosSizeInfo [1]
      nRow    := aDialogBoxPosSizeInfo [2]
      lCenter := aDialogBoxPosSizeInfo [3]
      Form    := aDialogBoxPosSizeInfo [4]
      hIcon   := aDialogBoxPosSizeInfo [5]

   ENDIF

RETURN NIL

#ifdef _HMG_COMPAT_
/*
 * Routine: _HMG_DialogBoxProcedure
 * Purpose: Hooks Win32 standard dialog boxes (class #32770) to apply centering and custom icons.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Sets dialog window position and icon via SetWindowPos and SetWindowHIcon.
 */
FUNCTION _HMG_DialogBoxProcedure()
   LOCAL hWnd := GetActiveWindow()
   LOCAL hWndParent, hIcon
   LOCAL nRow, nCol
   LOCAL lCenter

   IF IsWindowHandle( hWnd ) .AND. GetClassName( hWnd ) == "#32770" // Win32 standard dialog box class name

      _HMG_DialogBoxProperty( @nRow, @nCol, @lCenter, @hWndParent, .F., @hIcon )

      IF hIcon == NIL .AND. HB_ISSTRING( _HMG_DefaultIconName )

         hIcon := LoadIconByName( _HMG_DefaultIconName, 0, 0 )

         _HMG_DialogBoxProperty( nRow, nCol, lCenter, hWndParent, .T., hIcon )

         STATIC HMG_DialogBoxhWnd AS GLOBAL VALUE 0

      ENDIF

      IF _SetGetGlobal( "HMG_DialogBoxhWnd" ) <> hWnd

         ASSIGN GLOBAL HMG_DialogBoxhWnd := hWnd

         IF hIcon != NIL
            SetWindowHIcon( hWnd, hIcon )
         ENDIF

      ENDIF

      IF nRow != NIL .OR. nCol != NIL .OR. lCenter != NIL .OR. hWndParent != NIL

         hb_default( @nCol, GetWindowCol( hWnd ) )
         hb_default( @nRow, GetWindowRow( hWnd ) )

         IF ( lCenter := hb_defaultValue( lCenter, .F. ) )

            hb_default( @hWndParent, GetParent( hWnd ) )

            nCol := GetWindowCol( hWndParent ) + Int( ( GetWindowWidth ( hWndParent ) - GetWindowWidth ( hWnd ) ) / 2 )
            nRow := GetWindowRow( hWndParent ) + Int( ( GetWindowHeight( hWndParent ) - GetWindowHeight( hWnd ) ) / 2 )

         ENDIF

         SetWindowPos( hWnd, 0, nCol, nRow, 0, 0, SWP_NOOWNERZORDER + SWP_NOSIZE )

      ENDIF

   ENDIF

RETURN NIL

/*
 * Routine: EnumChildWindows
 * Purpose: Enumerates all child window handles belonging to a parent window.
 *
 * Parameters:
 *   hWnd [N] - Parent HWND handle.
 *   bExt [L] - If .T., returns array of { handle, class, text }; else array of handles.
 *
 * Return:
 *   [A] - Array of child window details or HWND handles.
 *
 * Side Effects:
 *   Invokes C_EnumChildWindows Win32 API iteration logic.
 */
FUNCTION EnumChildWindows( hWnd, bExt )
   LOCAL aChilds := {}
   LOCAL bAction

   IF hb_defaultValue( bExt, .F. )
      bAction := {|hChild| AAdd( aChilds, { hChild, GetClassName( hChild ), GetWindowText( hChild ) } ), .T. }
   ELSE
      bAction := {|hChild| AAdd( aChilds, hChild ), .T. }
   ENDIF

   C_EnumChildWindows( hWnd, bAction )

RETURN aChilds

#endif

#ifdef __XHARBOUR__
#include "statics.prg"
#endif