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

// Ensure compilation settings support Harbour Unicode string operations if enabled.
#include "SET_COMPILE_HMG_UNICODE.ch"

// Include standard Win32 message definitions, MiniGUI definitions, and error codes.
#include "i_winuser.ch"
#include "minigui.ch"
#include "error.ch"

// Windows SystemParametersInfo constant for wheel scroll lines query
#define SPI_GETWHEELSCROLLLINES      0x0068

/*
   Local static array index definitions mapping static global state variables.
   Using pseudo-globals stored in s_Global array avoids global variable pollution
   and maintains encapsulation within this module.
*/
#define lOpaque                      s_Global [1]  // Indicates if container brush rendering should be opaque
#define IsInitMenuPopup              s_Global [2]  // Flag indicating active popup menu initialization state
#define lEnterSizeMove               s_Global [3]  // Tracks window sizing/moving state transitions
#define lCellGridRowChanged          s_Global [4]  // Grid control cell/row selection change indicator
#define IsXPThemed                   s_Global [5]  // Cached theme state (Windows XP / Visual Styles active)
#define nOldPage                     s_Global [6]  // Tab control previous page index during tab changes
#define SpaceKeyIsPressedInGrid      s_Global [7]  // Tracks spacebar toggle state within Grid controls
#define nLastRadioGroupFocusedIndex  s_Global [8]  // Stores index of last focused RadioGroup control
#define nWheelLines                  s_Global [9]  // System mouse wheel scroll line configuration count

#ifdef _TSBROWSE_
   // Declare external memory variables used for TSBrowse custom control integration.
   MEMVAR _TSB_aControlhWnd, _TSB_aControlObjects
#endif

// Compatibility macros for Harbour/xHarbour version differences regarding Unicode API functions.
#if defined( __XHARBOUR__ ) .OR. ( __HARBOUR__ - 0 < 0x030200 )
   #xtranslate hb_UAt( <c>, <n> ) => At( <c>, <n> )
   #xtranslate hb_ULeft( <c>, <n> ) => Left( <c>, <n> )
#endif

#ifdef _OBJECT_

STATIC s_bEvents, s_lEvents := .F.

/*
   FUNCTION Set_bEvents ( bBlock )
   
   Purpose:
      Sets or retrieves the user-defined global event handler block or procedure name
      used when Object-Oriented or hook-based event handling is enabled in HMG Extended.
      
   Parameters:
      bBlock - [Block|String] Codeblock or function name string to handle low-level events.
      
   Returns:
      bOldBlock - The previously registered codeblock or function string.
      
   Side Effects:
      Updates s_bEvents static variable and toggles s_lEvents flag.
*/
FUNCTION Set_bEvents ( bBlock )
   LOCAL bOldBlock := s_bEvents

   // If passed as a function call string (e.g., "MyEvents()"), strip parameters part.
   IF HB_ISCHAR( bBlock ) .AND. "(" $ bBlock
      bBlock := hb_ULeft( bBlock, hb_UAt( "(", bBlock ) - 1 )
   ENDIF

   s_bEvents := bBlock
   s_lEvents := ! Empty( s_bEvents )

RETURN bOldBlock
#endif

/*
   FUNCTION Events ( hWnd, nMsg, wParam, lParam )
   
   Purpose:
      Central Window Procedure (WndProc) dispatcher for HMG Extended framework.
      Interprets Win32 messages sent to form windows and controls, mapping them to
      internal framework structures and triggering user-defined event procedures.
      
   Parameters:
      hWnd    - [HWND / Numeric] Handle of the target window receiving the message.
      nMsg    - [Numeric] Win32 message identifier (WM_*).
      wParam  - [Numeric] Additional message information depending on nMsg.
      lParam  - [Numeric] Additional message information depending on nMsg.
      
   Returns:
      Numeric - Message processing result. Returns 0 to indicate standard processing completed,
                or 1 / non-zero value to override default OS message handling where applicable.
                
   Side Effects:
      - Alters global state vectors (_HMG_aControl*, _HMG_aForm*).
      - Executes assigned callback codeblocks and event procedures.
      - Triggers visual redraws, component repaints, and focus adjustments.
*/
FUNCTION Events ( hWnd, nMsg, wParam, lParam )
   // Local variable declarations for internal event routing and state maintenance
   LOCAL NextControlHandle
   LOCAL oGet
   LOCAL aPos
   LOCAL aCellData
   LOCAL NewPos, NewHPos, NewVPos
   LOCAL maskstart
   LOCAL ControlCount
   LOCAL mVar
   LOCAL TmpStr, Tmp
   LOCAL nGridRowValue
   LOCAL i, z, x, lvc, k, ts, r, a
#ifdef _DBFBROWSE_
   LOCAL BackRec, BackArea, BrowseArea
   LOCAL RecordCount, SkipCount
   LOCAL aTemp, aTemp2
   LOCAL DeltaSelect
   LOCAL dBc, dFc
   LOCAL xs, xd
   LOCAL nr, hws, hwm
#endif
   LOCAL backcolor, fontcolor, titlebkclr, titlefrclr, trlfontclr
   LOCAL nDestinationColumn, nFrozenColumnCount, aOriginalColumnWidths
#ifdef _USERINIT_
   LOCAL cProc
#endif
   LOCAL cParent, hEdit, nStart, nEnd

   // Static module state array maintained across message loops.
   STATIC s_Global := { .F., .F., .F., .F., NIL, NIL, 0, 0, 0 }

#ifdef _OBJECT_
   // Evaluate user-defined custom global event handler block if hooked into HMG OOP mode.
   IF s_lEvents
      IF HB_ISBLOCK( s_bEvents )     // Codeblock event handler
         IF !Empty( Eval( s_bEvents, hWnd, nMsg, wParam, lParam ) )
            RETURN 1                 // Intercept message if handler returns non-empty value
         ENDIF
      ELSEIF HB_ISCHAR( s_bEvents )  // Function name string event handler
         IF !Empty( hb_ExecFromArray( s_bEvents, { hWnd, nMsg, wParam, lParam } ) )
            RETURN 1                 // Intercept message
         ENDIF
      ENDIF
   ENDIF
#endif

#ifdef _TSBROWSE_
   // Route message to TSBrowse control object handler if target matches a TSBrowse control.
   oGet := GetObjectByHandle ( hWnd )
   IF ISOBJECT ( oGet )
      r := oGet:HandleEvent ( nMsg, wParam, lParam )
      IF ValType ( r ) == 'N'
         IF r != 0
            RETURN r
         ENDIF
      ENDIF
   ENDIF
#endif

#ifdef _USERINIT_
   // Execute custom registered user initialization event procedures.
   FOR EACH cProc IN _HMG_aCustomEventProcedure
      r := &cProc ( hWnd , nMsg , wParam , lParam )
      IF ValType ( r ) <> 'U'
         RETURN r
      ENDIF
   NEXT
#endif

   // Dispatch logic based on Win32 Message Identifier (nMsg)
   SWITCH nMsg

   ****************************************************************************
   CASE WM_MEASUREITEM
   ****************************************************************************
      // Requested when owner-draw controls (Menus, ListBoxes) are created to define dimensions.
      SWITCH GETMISCTLTYPE ( lParam )
      CASE ODT_MENU
         _OnMeasureMenuItem ( hWnd, nMsg, wParam, lParam )
         EXIT
      CASE ODT_LISTBOX
         _OnMeasureListBoxItem ( lParam )
      END SWITCH
      EXIT

   ****************************************************************************
   CASE WM_DRAWITEM
   ****************************************************************************
      // Sent when a visual aspect of an owner-draw control or menu item has changed.
      i := AScan ( _HMG_aFormHandles, hWnd )

      // Determine if parent form owns a defined status bar requiring owner-drawing.
      ts := ( i > 0 .AND. _IsControlDefined ( "StatusBar", _HMG_aFormNames [i] ) )

      SWITCH GETOWNBTNCTLTYPE ( lParam )
      CASE ODT_MENU
         IF ts .AND. GetDrawItemHandle ( lParam ) == GetControlHandle ( "StatusBar", _HMG_aFormNames [i] )
            _OnDrawStatusItem ( hWnd, lParam )
            RETURN 0
         ELSE
            _OnDrawMenuItem ( lParam )
            RETURN 0
         ENDIF
      CASE ODT_LISTBOX
         _OnDrawListBoxItem ( lParam )
         RETURN 0
      CASE ODT_BUTTON
         RETURN ( OwnButtonPaint ( lParam ) )
      CASE ODT_TAB
         RETURN ( OwnTabPaint ( lParam ) )
      END SWITCH

      IF ts
         _OnDrawStatusItem ( hWnd, lParam )
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_CTLCOLORSTATIC
   ****************************************************************************
      // Sent before Windows draws a static control, radio group, checkbox, or label.
      // Customizes text foreground/background colors and brush handles.
      i := AScan ( _HMG_aControlHandles , lParam )

      IF i > 0

         TmpStr := _HMG_aControlType [i]

         IF TmpStr $ "GETBOX,LABEL,HYPERLINK,CHECKBOX,FRAME,SLIDER,NUMTEXT,MASKEDTEXT,CHARMASKTEXT,BTNTEXT,BTNNUMTEXT,EDIT,ANIMATEBOX,CHECKLABEL"

            IF TmpStr $ "GETBOX,NUMTEXT,MASKEDTEXT,CHARMASKTEXT,BTNTEXT,BTNNUMTEXT,EDIT"

               IF IsWindowEnabled( _HMG_aControlHandles [i] )

                  // Apply custom foreground/font color settings
                  IF _HMG_aControlFontColor [i] != Nil
                     IF ValType( _HMG_aControlFontColor [ i, 2 ] ) == "A" .AND. Len( _HMG_aControlFontColor [ i, 2 ] ) == 3
                        SetTextColor( wParam, _HMG_aControlFontColor [ i, 2, 1 ], _HMG_aControlFontColor [ i, 2, 2 ], _HMG_aControlFontColor [ i, 2, 3 ] )
                     ELSEIF ValType( _HMG_aControlFontColor [ i, 2 ] ) == "N" .AND. Len( _HMG_aControlFontColor [ i ] ) == 3
                        SetTextColor( wParam, _HMG_aControlFontColor [ i, 1 ], _HMG_aControlFontColor [ i, 2 ], _HMG_aControlFontColor [ i, 3 ] )
                     ENDIF
                  ENDIF

                  // Apply custom background colors and solid brushes
                  IF _HMG_aControlBkColor [i] != Nil

                     IF ValType( _HMG_aControlBkColor [ i, 2 ] ) == "A" .AND. Len( _HMG_aControlBkColor [ i, 2 ] ) == 3
                        SetBkColor( wParam , _HMG_aControlBkColor [ i, 2, 1 ] , _HMG_aControlBkColor [ i, 2, 2 ] , _HMG_aControlBkColor [ i, 2, 3 ] )
                        DeleteObject ( _HMG_aControlBrushHandle [ i ] )
                        _HMG_aControlBrushHandle [ i ] := CreateSolidBrush( _HMG_aControlBkColor [ i, 2, 1 ] , _HMG_aControlBkColor [ i, 2, 2 ] , _HMG_aControlBkColor [ i, 2, 3 ] )
                        RETURN ( _HMG_aControlBrushHandle [i] )
                     ELSE
                        IF ValType( _HMG_aControlBkColor [ i, 2 ] ) == "N" .AND. Len( _HMG_aControlBkColor [ i ] ) == 3
                           SetBkColor( wParam , _HMG_aControlBkColor [ i, 1 ] , _HMG_aControlBkColor [ i, 2 ] , _HMG_aControlBkColor [ i, 3 ] )
                           DeleteObject ( _HMG_aControlBrushHandle [ i ] )
                           _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [ i, 1 ] , _HMG_aControlBkColor [ i, 2 ] , _HMG_aControlBkColor [ i, 3 ] )
                           RETURN _HMG_aControlBrushHandle [i]
                        ENDIF
                     ENDIF

                  ELSE

                     // Default fallback background color using system face color
                     a := nRGB2Arr ( GetSysColor ( COLOR_3DFACE ) )
                     SetBkColor( wParam , a [1] , a [2] , a [3] )
                     DeleteObject ( _HMG_aControlBrushHandle [i] )
                     _HMG_aControlBrushHandle [i] := CreateSolidBrush( a [1] , a [2] , a [3] )
                     RETURN _HMG_aControlBrushHandle [i]

                  ENDIF

               ENDIF

            ELSE

               // Theme-aware rendering logic for static elements (Sliders, Frames, Checkboxes)
               IF IsXPThemed == Nil
                  IsXPThemed := _HMG_IsThemed
               ENDIF

               Tmp := _HMG_aControlContainerRow [i] <> -1 .AND. _HMG_aControlContainerCol [i] <> -1 .AND. _HMG_aControlBkColor [i] == Nil

               // Slider transparency / background paint within Tab pages or Containers
               IF IsXPThemed .AND. TmpStr == "SLIDER" .AND. Tmp

                  IF ( a := _GetBackColor ( _HMG_aControlFontHandle [i] , _HMG_aControlMiscData1 [i] ) ) != Nil
                     _HMG_aControlBkColor [i] := a
                  ELSE
                     IF _HMG_aControlDblClick [i] == .F. .AND. !lOpaque
                        r := GetControlIndex( _HMG_aControlFontHandle [i] , _HMG_aControlMiscData1 [i] )
                        DeleteObject ( _HMG_aControlBrushHandle [r] )
                        z := GetControlHandle( _HMG_aControlFontHandle [i] , _HMG_aControlMiscData1 [i] )
                        _HMG_aControlBrushHandle [r] := GetTabBrush( z )
                        RETURN GetTabbedControlBrush ( wParam , lParam , z , _HMG_aControlBrushHandle [r] )
                     ENDIF
                  ENDIF
               ENDIF

               IF _HMG_aControlFontColor [i] != Nil
                  SetTextColor( wParam , _HMG_aControlFontColor [i] [1] , _HMG_aControlFontColor [i] [2] , _HMG_aControlFontColor [i] [3] )
               ENDIF

               // Frame control theme-aware background rendering
               IF IsXPThemed .AND. TmpStr == "FRAME" .AND. Tmp

                  IF ( a := _GetBackColor ( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] ) ) != Nil
                     IF ISLOGICAL ( _HMG_aControlInputMask [i] ) .AND. _HMG_aControlInputMask [i] == .T.
                        SetBkColor ( wParam , a [1] , a [2] , a [3] )
                        DeleteObject ( _HMG_aControlBrushHandle [i] )
                        _HMG_aControlBrushHandle [i] := CreateSolidBrush( a [1] , a [2] , a [3] )
                        RETURN _HMG_aControlBrushHandle [i]
                     ENDIF
                  ELSE
                     IF _HMG_aControlDblClick [i] == .F.
                        r := GetControlIndex( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                        DeleteObject ( _HMG_aControlBrushHandle [r] )
                        z := GetControlHandle( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                        _HMG_aControlBrushHandle [r] := GetTabBrush( z )
                        RETURN GetTabbedControlBrush ( wParam , lParam , z , _HMG_aControlBrushHandle [r] )
                     ELSE
                        lOpaque := .T.
                     ENDIF
                  ENDIF

               ENDIF

               // Checkbox control background handling
               IF IsXPThemed .AND. TmpStr == "CHECKBOX" .AND. Tmp

                  lvc := ( ISLOGICAL ( _HMG_aControlInputMask [i] ) .AND. _HMG_aControlInputMask [i] == .F. )

                  IF ( a := _GetBackColor ( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] ) ) != Nil
                     IF lvc
                        SetBkColor( wParam , a [1] , a [2] , a [3] )
                        DeleteObject ( _HMG_aControlBrushHandle [i] )
                        _HMG_aControlBrushHandle [i] := CreateSolidBrush( a [1] , a [2] , a [3] )
                        RETURN _HMG_aControlBrushHandle [i]
                     ENDIF
                  ELSE
#if defined( _PANEL_ ) .AND. defined( _HMG_COMPAT_ )
                     IF GetFormNameByHandle ( _HMG_aControlParentHandles [i] , @z ) > 0 .AND. GetWindowType ( z ) == 'P'
                     ELSEIF _HMG_aControlDblClick [i] == .F. .AND. ( !lOpaque .OR. !lvc )
#else
                     IF _HMG_aControlDblClick [i] == .F. .AND. ( !lOpaque .OR. !lvc )
#endif
                        r := GetControlIndex( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                        DeleteObject ( _HMG_aControlBrushHandle [r] )
                        z := GetControlHandle( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                        _HMG_aControlBrushHandle [r] := GetTabBrush( z )
                        RETURN GetTabbedControlBrush ( wParam , lParam , z , _HMG_aControlBrushHandle [r] )
                     ENDIF
                  ENDIF

               ENDIF

               // Handle explicit transparent background mode request
               IF ISLOGICAL ( _HMG_aControlInputMask [i] )
                  IF _HMG_aControlInputMask [i] == .T.
                     IF _HMG_aControlContainerRow [i] == -1 .AND. _HMG_aControlContainerCol [i] == -1 .AND. TmpStr == "CHECKBOX"
                        // Handled internally in checkbox code
                     ELSE
                        SetBkMode ( wParam , TRANSPARENT )
                        RETURN GetStockObject ( NULL_BRUSH )
                     ENDIF
                  ENDIF
               ENDIF

               // Label control themed background calculation
               IF IsXPThemed .AND. TmpStr == 'LABEL' .AND. Tmp

                  IF ( a := _GetBackColor ( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] ) ) == Nil
                     IF _HMG_aControlDblClick [i] == .T.
                        a := nRGB2Arr ( GetSysColor ( COLOR_BTNFACE ) )
#if defined( _PANEL_ ) .AND. defined( _HMG_COMPAT_ )
                     ELSEIF GetFormNameByHandle ( _HMG_aControlParentHandles [i] , @z ) > 0 .AND. GetWindowType ( z ) == 'P'
                        a := Nil
#endif
                     ELSEIF ( r := GetControlIndex( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] ) ) > 0
                        DeleteObject ( _HMG_aControlBrushHandle [r] )
                        z := GetControlHandle( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                        _HMG_aControlBrushHandle [r] := GetTabBrush( z )
                        RETURN GetTabbedControlBrush ( wParam , lParam , z , _HMG_aControlBrushHandle [r] )
                     ELSE
                        a := _HMG_ActiveTabColor [1]
                     ENDIF
                  ENDIF

                  IF ISARRAY( a )
                     SetBkColor( wParam , a [1] , a [2] , a [3] )
                     DeleteObject ( _HMG_aControlBrushHandle [i] )
                     _HMG_aControlBrushHandle [i] := CreateSolidBrush( a [1] , a [2] , a [3] )
                     RETURN _HMG_aControlBrushHandle [i]
                  ENDIF

               ENDIF

               // Final color brush assignment for general controls
               IF _HMG_aControlBkColor [i] != Nil .AND. IsArrayRGB ( _HMG_aControlBkColor [i] )
                  SetBkColor( wParam , _HMG_aControlBkColor [i] [1] , _HMG_aControlBkColor [i] [2] , _HMG_aControlBkColor [i] [3] )
                  DeleteObject ( _HMG_aControlBrushHandle [i] )
                  _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i] [1] , _HMG_aControlBkColor [i] [2] , _HMG_aControlBkColor [i] [3] )
                  RETURN _HMG_aControlBrushHandle [i]
               ELSE
                  a := nRGB2Arr ( GetSysColor ( COLOR_3DFACE ) )
                  SetBkColor( wParam , a [1] , a [2] , a [3] )
                  DeleteObject ( _HMG_aControlBrushHandle [i] )
                  _HMG_aControlBrushHandle [i] := CreateSolidBrush( a [1] , a [2] , a [3] )
                  RETURN _HMG_aControlBrushHandle [i]
               ENDIF

            ENDIF

         ENDIF

      ELSE

         // Handle composite multi-handle controls (e.g., Radio Groups)
         IF IsXPThemed == Nil
            IsXPThemed := _HMG_IsThemed
         ENDIF

         ControlCount := Len ( _HMG_aControlHandles )

         FOR i := 1 TO ControlCount

            IF ISARRAY ( _HMG_aControlHandles [i] )

               IF _HMG_aControlType [i] == 'RADIOGROUP'

                  Tmp := Len ( _HMG_aControlHandles [i] )

                  FOR x := 1 TO Tmp

                     IF _HMG_aControlHandles [i] [x] == lParam

                        IF _HMG_aControlFontColor [i] != Nil
                           SetTextColor( wParam , _HMG_aControlFontColor [i] [1] , _HMG_aControlFontColor [i] [2] , _HMG_aControlFontColor [i] [3] )
                        ENDIF

                        lvc := ( ISLOGICAL ( _HMG_aControlInputMask [i] ) .AND. _HMG_aControlInputMask [i] == .T. )

                        IF IsXPThemed .AND. _HMG_aControlContainerRow [i] <> -1 .AND. _HMG_aControlContainerCol [i] <> -1

                           IF ( a := _GetBackColor ( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] ) ) != Nil
                              IF lvc
                                 _HMG_aControlBkColor [i] := a
                              ENDIF
                           ELSE
#if defined( _PANEL_ ) .AND. defined( _HMG_COMPAT_ )
                              IF GetFormNameByHandle ( _HMG_aControlParentHandles [i] , @z ) > 0 .AND. GetWindowType ( z ) == 'P'
                              ELSEIF _HMG_aControlDblClick [i] == .F. .AND. ( !lOpaque .OR. lvc ) .AND. _HMG_aControlBkColor [i] == Nil
#else
                              IF _HMG_aControlDblClick [i] == .F. .AND. ( !lOpaque .OR. lvc ) .AND. _HMG_aControlBkColor [i] == Nil
#endif
                                 r := GetControlIndex( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                                 DeleteObject ( _HMG_aControlBrushHandle [r] )
                                 z := GetControlHandle( _HMG_aControlRangeMin [i] , _HMG_aControlRangeMax [i] )
                                 _HMG_aControlBrushHandle [r] := GetTabBrush( z )
                                 RETURN GetTabbedControlBrush ( wParam , lParam , z , _HMG_aControlBrushHandle [r] )
                              ENDIF
                           ENDIF

                        ENDIF

                        IF ISLOGICAL ( _HMG_aControlInputMask [i] )

                           IF _HMG_aControlInputMask [i] == .T. .AND. _HMG_aControlBkColor [i] == Nil
                              IF IsXPThemed .AND. ( a := _HMG_aFormBkColor [AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] )] ) [1] != -1
                                 _HMG_aControlBkColor [i] := a
                              ELSE
                                 SetBkMode( wParam , TRANSPARENT )
                                 RETURN GetStockObject( NULL_BRUSH )
                              ENDIF
                           ENDIF

                        ENDIF

                        IF _HMG_aControlBkColor [i] != Nil

                           SetBkColor( wParam , _HMG_aControlBkColor [i] [1] , _HMG_aControlBkColor [i] [2] , _HMG_aControlBkColor [i] [3] )
                           IF x == 1
                              DeleteObject ( _HMG_aControlBrushHandle [i] )
                              _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i] [1] , _HMG_aControlBkColor [i] [2] , _HMG_aControlBkColor [i] [3] )
                           ENDIF
                           RETURN _HMG_aControlBrushHandle [i]

                        ELSE

                           IF x == 1
                              DeleteObject ( _HMG_aControlBrushHandle [i] )
                              _HMG_aControlBrushHandle [i] := CreateSolidBrush( GetRed ( GetSysColor ( COLOR_3DFACE ) ) , GetGreen ( GetSysColor ( COLOR_3DFACE ) ) , GetBlue ( GetSysColor ( COLOR_3DFACE ) ) )
                           ENDIF
                           SetBkColor( wParam , GetRed ( GetSysColor ( COLOR_3DFACE ) ) , GetGreen ( GetSysColor ( COLOR_3DFACE ) ) , GetBlue ( GetSysColor ( COLOR_3DFACE ) ) )
                           RETURN _HMG_aControlBrushHandle [i]

                        ENDIF

                     ENDIF

                  NEXT x

               ENDIF

            ENDIF

         NEXT i

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_CTLCOLOREDIT
   CASE WM_CTLCOLORLISTBOX
   ****************************************************************************
      // Custom background and foreground color configuration for editable/list controls.
      i := AScan ( _HMG_aControlHandles , lParam )

      IF i > 0

         TmpStr := _HMG_aControlType [i]

         IF TmpStr $ "GETBOX,NUMTEXT,MASKEDTEXT,CHARMASKTEXT,EDIT,BTNTEXT,BTNNUMTEXT,MULTILIST,COMBO,MULTICHKLIST"

            // Set dynamic or static font colors based on focus state
            IF _HMG_aControlFontColor [i] != Nil

               IF ValType( _HMG_aControlFontColor [i, 1] ) == "N"

                  SetTextColor( wParam, _HMG_aControlFontColor [i][1] , _HMG_aControlFontColor [i][2] , _HMG_aControlFontColor [i][3] )

               ELSEIF ValType( _HMG_aControlFontColor [i, 1] ) == "A"

                  // Support focused vs unfocused text colors
                  IF Len( _HMG_aControlFontColor [i] ) > 2 .AND. GetFocus() == _HMG_aControlHandles [i]
                     SetTextColor( wParam, _HMG_aControlFontColor [i, 3, 1], _HMG_aControlFontColor [i, 3, 2] , _HMG_aControlFontColor [i, 3, 3] )
                  ELSE
                     SetTextColor( wParam, _HMG_aControlFontColor [i, 1, 1], _HMG_aControlFontColor [i, 1, 2] , _HMG_aControlFontColor [i, 1, 3] )
                  ENDIF

               ENDIF

               IF _HMG_aControlBkColor [i] == Nil

                  a := nRGB2Arr ( GetSysColor ( COLOR_WINDOW ) )
                  SetBkColor( wParam , a[1] , a[2] , a[3] )
                  DeleteObject ( _HMG_aControlBrushHandle [i] )
                  _HMG_aControlBrushHandle [i] := CreateSolidBrush( a[1] , a[2] , a[3] )
                  RETURN _HMG_aControlBrushHandle [i]

               ENDIF

            ENDIF

            // Set background brushes with focus state awareness
            IF _HMG_aControlBkColor [i] != Nil

               IF ValType( _HMG_aControlBkColor [i, 1] ) == "N"

                  SetBkColor( wParam, _HMG_aControlBkColor [i][1], _HMG_aControlBkColor [i][2], _HMG_aControlBkColor [i][3] )
                  DeleteObject ( _HMG_aControlBrushHandle [i] )
                  _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i][1], _HMG_aControlBkColor [i][2], _HMG_aControlBkColor [i][3] )
                  RETURN ( _HMG_aControlBrushHandle [i] )

               ELSE

                  IF ValType( _HMG_aControlBkColor [i, 1] ) == "A"

                     IF Len( _HMG_aControlBkColor[i] ) == 3 .AND. GetFocus() == _HMG_aControlHandles [i]

                        SetBkColor( wParam, _HMG_aControlBkColor [i, 3, 1], _HMG_aControlBkColor [i, 3, 2], _HMG_aControlBkColor [i, 3, 3] )
                        DeleteObject ( _HMG_aControlBrushHandle [i] )
                        _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i, 3, 1], _HMG_aControlBkColor [i, 3, 2], _HMG_aControlBkColor [i, 3, 3] )
                        RETURN ( _HMG_aControlBrushHandle [i] )

                     ELSE

                        SetBkColor( wParam, _HMG_aControlBkColor [i, 1, 1], _HMG_aControlBkColor [i, 1, 2], _HMG_aControlBkColor [i, 1, 3] )
                        DeleteObject ( _HMG_aControlBrushHandle [i] )
                        _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i, 1, 1], _HMG_aControlBkColor [i, 1, 2], _HMG_aControlBkColor [i, 1, 3] )
                        RETURN _HMG_aControlBrushHandle [i]

                     ENDIF

                  ENDIF

               ENDIF

            ENDIF

         ENDIF

      ELSE

         // Fallback search for nested multi-handle edit controls (e.g. Spinners and ComboBox edit boxes)
         ControlCount := Len ( _HMG_aControlHandles )

         FOR i := 1 TO ControlCount

            IF ValType ( _HMG_aControlHandles [i] ) == 'A'

               IF _HMG_aControlType [i] == 'SPINNER'

                  IF _HMG_aControlHandles [i][1] == lParam

                     IF _HMG_aControlFontColor [i] != Nil

                        SetTextColor( wParam , _HMG_aControlFontColor [i][1] , _HMG_aControlFontColor [i][2] , _HMG_aControlFontColor [i][3] )
                        IF _HMG_aControlBkColor [i] == Nil
                           a := nRGB2Arr ( GetSysColor ( COLOR_WINDOW ) )
                           SetBkColor( wParam , a[1] , a[2] , a[3] )
                           DeleteObject ( _HMG_aControlBrushHandle [i] )
                           _HMG_aControlBrushHandle [ i ] := CreateSolidBrush( a[1] , a[2] , a[3] )
                           RETURN _HMG_aControlBrushHandle [i]
                        ENDIF

                     ENDIF

                     IF _HMG_aControlBkColor [i] != Nil

                        SetBkColor( wParam , _HMG_aControlBkColor [i][1] , _HMG_aControlBkColor [i][2] , _HMG_aControlBkColor [i][3] )
                        DeleteObject ( _HMG_aControlBrushHandle [i] )
                        _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i][1] , _HMG_aControlBkColor [i][2] , _HMG_aControlBkColor [i][3] )
                        RETURN _HMG_aControlBrushHandle [i]

                     ENDIF

                  ENDIF

               ENDIF

            ENDIF

            IF _HMG_aControlType [i] == "COMBO"

               z := _HMG_aControlHandles [i]
               x := _HMG_aControlMiscData1 [i][2] // DisplayChange flag
               k := _HMG_aControlRangeMin [i] // DisplayChange Edit handle

               IF x == .T. .AND. ( GetFocus() == k .OR. k == lParam ) .OR. GetFocus() == z .AND. ( z == lParam .OR. x == .F. )

                  IF _HMG_aControlFontColor [i] != Nil

                     SetTextColor( wParam , _HMG_aControlFontColor [i][1] , _HMG_aControlFontColor [i][2] , _HMG_aControlFontColor [i][3] )
                     IF _HMG_aControlBkColor [i] == Nil
                        a := nRGB2Arr ( GetSysColor ( COLOR_WINDOW ) )
                        SetBkColor( wParam , a[1] , a[2] , a[3] )
                        DeleteObject ( _HMG_aControlBrushHandle [i] )
                        _HMG_aControlBrushHandle [ i ] := CreateSolidBrush( a[1] , a[2] , a[3] )
                        RETURN _HMG_aControlBrushHandle [i]
                     ENDIF

                  ENDIF

                  IF _HMG_aControlBkColor [i] != Nil

                     IF _HMG_aControlRangeMin [i] == lParam
                        SetBkColor( lParam , _HMG_aControlBkColor [i][1] , _HMG_aControlBkColor [i][2] , _HMG_aControlBkColor [i][3] )
                     ENDIF
                     SetBkColor( wParam , _HMG_aControlBkColor [i][1] , _HMG_aControlBkColor [i][2] , _HMG_aControlBkColor [i][3] )
                     DeleteObject ( _HMG_aControlBrushHandle [i] )
                     _HMG_aControlBrushHandle [i] := CreateSolidBrush( _HMG_aControlBkColor [i][1] , _HMG_aControlBkColor [i][2] , _HMG_aControlBkColor [i][3] )
                     RETURN _HMG_aControlBrushHandle [i]

                  ENDIF

               ENDIF

            ENDIF

         NEXT i

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_MENUSELECT
   ****************************************************************************
      // Triggered when user highlights a menu item. Displays menu item help text on Status Bar.
      IF AND( HiWord ( wParam ), MF_HILITE ) <> 0

         i := AScan ( _HMG_aControlIds, LoWord ( wParam ) )  // LoWord(wParam) maps to menu control ID

         IF i > 0

            IF ( x := AScan ( _HMG_aFormHandles, _HMG_aControlParentHandles [i] ) ) > 0
               IF _IsControlDefined ( "StatusBar", _HMG_aFormNames [x] )
                  IF _HMG_aControlValue [i] # Nil
                     SetProperty ( _HMG_aFormNames [x], "StatusBar", "Item", 1, _HMG_aControlValue [i] )
                  ELSEIF ISCHARACTER ( _HMG_DefaultStatusBarMessage )
                     SetProperty ( _HMG_aFormNames [x], "StatusBar", "Item", 1, _HMG_DefaultStatusBarMessage )
                  ENDIF
               ENDIF
            ENDIF

         ELSEIF ( x := AScan ( _HMG_aFormHandles, hWnd ) ) > 0

            IF _IsControlDefined ( "StatusBar", _HMG_aFormNames [x] )
               IF ISCHARACTER ( _HMG_DefaultStatusBarMessage )
                  SetProperty ( _HMG_aFormNames [x], "StatusBar", "Item", 1, _HMG_DefaultStatusBarMessage )
               ENDIF
            ENDIF

         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_MENUCHAR
   ****************************************************************************
      // Handles accelerator mnemonic hotkeys for extended owner-drawn menu popups.
      IF IsExtendedMenuStyleActive()
         x := Chr ( LoWord ( wParam ) )  // LoWord(wParam) contains character code
         IF ( i := AScan ( GetMenuItems ( ( HiWord ( wParam ) == MF_POPUP ), lParam ), {| r | "&" + Upper( x ) $ Upper( r ) } ) ) > 0
            RETURN MAKELRESULT ( i - 1, MNC_EXECUTE )
         ENDIF
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_INITMENUPOPUP
   ****************************************************************************
      // Set flag to inform system hotkey handler that a popup menu is active
      IsInitMenuPopup := .T.
      EXIT

   ****************************************************************************
   CASE WM_UNINITMENUPOPUP
   ****************************************************************************
      // Reset popup menu status flag when closed
      IsInitMenuPopup := .F.
      EXIT

   ****************************************************************************
   CASE WM_HOTKEY
   ****************************************************************************
      // Intercept and dispatch system-wide hotkey strokes assigned to forms or controls.
      i := AScan ( _HMG_aControlIds , wParam )

      IF i > 0

         IF _HMG_aControlType [i] == "HOTKEY"

            // Dismiss active popup menu if ESC key is pressed
            IF _HMG_aControlValue [i] == VK_ESCAPE .AND. IsInitMenuPopup == .T.
               _CloseMenu()
               RETURN 0
            ENDIF

            // Route HotKey execution depending on MDI child context vs global application scope
            IF _HMG_BeginWindowMDIActive
               IF _HMG_aControlParentHandles [i] == GetActiveMdiHandle() .OR. _HMG_InplaceParentHandle <> 0
                  IF _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
                     RETURN 0
                  ENDIF
               ELSEIF _HMG_aControlParentHandles [i] == GetActiveWindow() .OR. _HMG_GlobalHotkeys
                  IF _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
                     RETURN 0
                  ENDIF
               ENDIF
            ELSE
               IF _HMG_aControlParentHandles [i] == GetForegroundWindow() .OR. _HMG_GlobalHotkeys
                  IF _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
                     RETURN 0
                  ENDIF
               ENDIF
            ENDIF

         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_MOUSEWHEEL
   ****************************************************************************
      // Translates mouse wheel rotation events into vertical scrollbar page movements
      // for virtual-dimensioned window containers.
      hwnd := 0

      IF ! _HMG_AutoAdjust

         i := AScan ( _HMG_aFormHandles , GetFocus() )

         IF i > 0

            IF _HMG_aFormVirtualHeight [i] > 0
               hwnd := _HMG_aFormHandles [i]
            ENDIF

         ELSE

            IF ( i := AScan ( _HMG_aControlHandles , GetFocus() ) ) > 0

               IF ( x := AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] ) ) > 0
                  IF _HMG_aFormVirtualHeight [x] > 0
                     hwnd := _HMG_aFormHandles [x]
                  ENDIF
               ENDIF

            ELSE

               ControlCount := Len ( _HMG_aControlHandles )

               FOR i := 1 TO ControlCount
                  IF _HMG_aControlType [i] == 'RADIOGROUP'
                     IF AScan ( _HMG_aControlHandles [i] , GetFocus() ) > 0
                        IF ( z := AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] ) ) > 0
                           IF _HMG_aFormVirtualHeight [z] > 0
                              hwnd := _HMG_aFormHandles [z]
                              EXIT
                           ENDIF
                        ENDIF
                     ENDIF
                  ENDIF
               NEXT i

            ENDIF

         ENDIF

      ENDIF

      IF hwnd != 0

         /* Query Windows System Parameter for Wheel Scroll Lines count */
         SystemParametersInfo( SPI_GETWHEELSCROLLLINES, 0, @nWheelLines, 0 )

         /* Exit early if system wheel scrolling is disabled */
         IF nWheelLines == 0
            RETURN 0
         ENDIF

         nr := GET_WHEEL_DELTA_WPARAM ( wParam )

         // Forward scrolling up vs backward scrolling down
         IF nr < 65000
            IF GetScrollPos( hwnd , SB_VERT ) < 25
               SendMessage( hwnd , WM_VSCROLL , SB_TOP , 0 )
            ELSE
               SendMessage( hwnd , WM_VSCROLL , SB_PAGEUP , 0 )
            ENDIF
         ELSEIF nr <> 0
            IF GetScrollPos( hwnd , SB_VERT ) >= GetScrollRangeMax ( hwnd , SB_VERT ) - 10
               SendMessage( hwnd , WM_VSCROLL , SB_BOTTOM , 0 )
            ELSE
               SendMessage( hwnd , WM_VSCROLL , SB_PAGEDOWN , 0 )
            ENDIF
         ENDIF

         RETURN 0

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_CREATE
   ****************************************************************************
      // Initial window creation logic: initializes MDI client area if MDI mode is active.
      IF _HMG_BeginWindowMDIActive .AND. _HMG_MainClientMDIHandle == 0
         _HMG_MainClientMDIHandle := InitMDIClientWindow( hWnd )
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_ACTIVATE
   ****************************************************************************
      // Handles window activation state transitions. Unregisters non-global hotkeys
      // when window loses activation state.
      i := AScan ( _HMG_aFormhandles , hWnd )

      IF i > 0

         IF LoWord ( wParam ) == WA_INACTIVE

            IF ! _HMG_GlobalHotkeys

               FOR EACH r IN _HMG_aControlType

                  IF r == 'HOTKEY'
                     x := hb_enumindex ( r )
                     ReleaseHotKey ( _HMG_aControlParentHandles [x] , _HMG_aControlIds [x] )
                  ENDIF

               NEXT

            ENDIF

            _HMG_aFormFocusedControl [i] := GetFocus()
            _DoWindowEventProcedure ( _HMG_aFormLostFocusProcedure [i] , i , 'WINDOW_LOSTFOCUS' )

         ELSE

            UpdateWindow ( hWnd )

         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_SETFOCUS
   ****************************************************************************
      // Handles window focus acquisition, registers hotkeys, brings modal windows to top,
      // and executes ON GOTFOCUS event procedures.
      i := AScan ( _HMG_aFormHandles , hWnd )

      IF i > 0

         IF _HMG_aFormActive [i] == .T. .AND. _HMG_aFormType [i] != 'X'
            _HMG_UserWindowHandle := hWnd
         ENDIF

         ControlCount := Len ( _HMG_aControlHandles )

         // Reset hotkey registration for active window context
         FOR x := 1 TO ControlCount
            IF _HMG_aControlType [x] == 'HOTKEY'
               IF .NOT. _HMG_BeginWindowMDIActive
                  ReleaseHotKey ( _HMG_aControlParentHandles [x] , _HMG_aControlIds [x] )
               ELSEIF _HMG_aControlParentHandles [x] != GetFormHandle( _HMG_MainClientMDIName ) .OR. _HMG_InplaceParentHandle <> 0
                  ReleaseHotKey ( _HMG_aControlParentHandles [x] , _HMG_aControlIds [x] )
               ENDIF
            ENDIF
         NEXT x

         FOR x := 1 TO ControlCount
            IF _HMG_aControlType [x] == 'HOTKEY'
               IF _HMG_aControlParentHandles [x] == hWnd
                  InitHotKey ( hWnd , _HMG_aControlPageMap [x] , _HMG_aControlValue [x] , _HMG_aControlIds [x] )
               ENDIF
            ENDIF
         NEXT x

         _DoWindowEventProcedure ( _HMG_aFormGotFocusProcedure [i] , i , 'WINDOW_GOTFOCUS' )

         // Restrict focus escape from modal dialog windows
         IF _HMG_IsModalActive .AND. Empty ( _HMG_InplaceParentHandle ) .AND. ;
            ( _HMG_aFormVirtualWidth [i] == 0 .OR. _HMG_aFormVirtualHeight [i] == 0 ) .AND. ;
            _HMG_SplitLastControl != "TOOLBAR"

            IF _HMG_aFormType [i] != 'M'

               IF iswinnt()
                  IF ! _OnFlashExit ()
                     BringWindowToTop ( _HMG_ActiveModalHandle )
                     // Flash window frame if focus was attempted outside active modal window
                     FlashWindowEx ( _HMG_ActiveModalHandle, 1, 5, 60 )
                  ENDIF
               ELSE
                  IF ! _OnFlashExit ()
                     BringWindowToTop ( _HMG_ActiveModalHandle )
                  ENDIF
               ENDIF

            ENDIF

         ENDIF

         IF _HMG_aFormFocusedControl [i] != 0
            setfocus ( _HMG_aFormFocusedControl [i] )
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_HELP
   ****************************************************************************
      // Context Help (F1 key) handler. Launches HTML Help (.chm) or standard WinHelp (.hlp)
      i := AScan ( _HMG_aControlHandles , GetHelpData ( lParam ) )

      IF i > 0

         IF Right( AllTrim( Upper( _HMG_ActiveHelpFile ) ) , 4 ) == '.CHM'
            _HMG_nTopic := _HMG_aControlHelpId [i]
            _Execute ( hWnd , "open" , "hh.exe" , ;
               iif( ValType( _HMG_nTopic ) == "C", '"' + _HMG_ActiveHelpFile + '::/' + AllTrim( _HMG_nTopic ) + '"', ;
               iif( ValType( _HMG_nTopic ) == "N" .AND. _HMG_nTopic > 0, '-mapid ' + hb_ntos( _HMG_nTopic ) + ' ' + ;
               _HMG_ActiveHelpFile, '"' + _HMG_ActiveHelpFile + '"' ) ) , , SW_SHOW )
         ELSE
            WinHelp ( hWnd , _HMG_ActiveHelpFile , 2 , _HMG_aControlHelpId [i] )
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_GETMINMAXINFO
   ****************************************************************************
      // Restricts minimum and maximum window tracking dimensions during sizing operations.
      RETURN _OnGetMinMaxInfo ( hWnd, lParam )

   ****************************************************************************
   CASE WM_VSCROLL
   ****************************************************************************
      // Handles Vertical ScrollBar events for virtual windows and custom controls.
      i := AScan ( _HMG_aFormHandles , hWnd )

      IF i > 0

         // Process Virtual Window Scrolling logic
         IF _HMG_aFormVirtualHeight [i] > 0 .AND. lParam == 0

            IF _HMG_aFormRebarhandle [i] > 0
               *MsgMiniGuiError( "SplitBox's Parent Window cannot be a 'Virtual Dimensioned' window (use 'Virtual Dimensioned' SplitChild instead)." )
            ENDIF

            z := iif( _HMG_aScrollStep [1] > 0, _HMG_aScrollStep [1], GetScrollRangeMax ( hwnd , SB_VERT ) / _HMG_aScrollStep [2] )

            IF LoWord( wParam ) == SB_LINEDOWN
               NewPos := GetScrollPos ( hwnd, SB_VERT ) + z
               IF NewPos >= GetScrollRangeMax ( hwnd, SB_VERT ) - 10
                  NewPos := GetScrollRangeMax ( hwnd, SB_VERT )
               ENDIF
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ELSEIF LoWord( wParam ) == SB_LINEUP
               NewPos := GetScrollPos( hwnd, SB_VERT ) - z
               IF NewPos < 10
                  NewPos := 0
               ENDIF
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ELSEIF LoWord( wParam ) == SB_TOP
               NewPos := 0
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ELSEIF LoWord( wParam ) == SB_BOTTOM
               NewPos := GetScrollRangeMax ( hwnd, SB_VERT )
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ELSEIF LoWord( wParam ) == SB_PAGEUP
               NewPos := GetScrollPos ( hwnd, SB_VERT ) - _HMG_aScrollStep [2]
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ELSEIF LoWord( wParam ) == SB_PAGEDOWN
               NewPos := GetScrollPos ( hwnd, SB_VERT ) + _HMG_aScrollStep [2]
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ELSEIF LoWord( wParam ) == SB_THUMBPOSITION
               NewPos := HiWord( wParam )
               SetScrollPos ( hwnd , SB_VERT , NewPos , .T. )
            ENDIF

            IF _HMG_aFormVirtualWidth [i] > 0
               NewHPos := GetScrollPos ( hwnd , SB_HORZ )
            ELSE
               NewHPos := 0
            ENDIF

            // Reposition child controls relative to updated vertical scroll position
            IF LoWord( wParam ) == SB_THUMBPOSITION .OR. LoWord( wParam ) == SB_LINEDOWN .OR. LoWord( wParam ) == SB_LINEUP .OR. LoWord( wParam ) == SB_PAGEUP .OR. LoWord( wParam ) == SB_PAGEDOWN .OR. LoWord( wParam ) == SB_BOTTOM .OR. LoWord( wParam ) == SB_TOP .AND. ! _HMG_AutoAdjust

               FOR x := 1 TO Len ( _HMG_aControlHandles )

                  IF _HMG_aControlParentHandles [x] == hwnd

                     IF _HMG_aControlType [x] == 'SPINNER'

                        MoveWindow ( _HMG_aControlhandles [x] [1] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewPos , _HMG_aControlWidth [x] - GetWindowWidth( _HMG_aControlhandles [x] [2] ) + 1 , _HMG_aControlHeight [x] , .T. )
                        MoveWindow ( _HMG_aControlhandles [x] [2] , _HMG_aControlCol [x] + _HMG_aControlWidth [x] - GetWindowWidth( _HMG_aControlhandles [x] [2] ) - NewHPos , _HMG_aControlRow [x] - NewPos , GetWindowWidth( _HMG_aControlhandles [x] [2] ) , _HMG_aControlHeight [x] , .T. )
#ifdef _DBFBROWSE_
                     ELSEIF _HMG_aControlType [x] == 'BROWSE'

                        MoveWindow ( _HMG_aControlhandles [x] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewPos , _HMG_aControlWidth [x] - GETVSCROLLBARWIDTH() , _HMG_aControlHeight [x] , .T. )
                        MoveWindow ( _HMG_aControlIds [x] , _HMG_aControlCol [x] + _HMG_aControlWidth [x] - GETVSCROLLBARWIDTH() - NewHPos , _HMG_aControlRow [x] - NewPos , GETVSCROLLBARWIDTH() , GetWIndowHeight( _HMG_aControlIds [x] ) , .T. )

                        MoveWindow ( _HMG_aControlMiscData1 [x] [1] , _HMG_aControlCol [x] + _HMG_aControlWidth [x] - GETVSCROLLBARWIDTH() - NewHPos , _HMG_aControlRow [x] + _HMG_aControlHeight [x] - GetHScrollBarHeight () - NewPos , ;
                           GetWindowWidth( _HMG_aControlMiscData1 [x][1] ) , GetWindowHeight( _HMG_aControlMiscData1 [x][1] ) , .T. )

                        ReDrawWindow ( _HMG_aControlhandles [x] )
#endif
                     ELSEIF _HMG_aControlType [x] == 'RADIOGROUP'

                        FOR z := 1 TO Len ( _HMG_aControlhandles [x] )
                           IF _HMG_aControlMiscData1 [x] == .F.
                              MoveWindow ( _HMG_aControlhandles [x] [z] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewPos + ( z - 1 ) * _HMG_aControlSpacing[x], _HMG_aControlWidth [x] , _HMG_aControlHeight [x] / Len ( _HMG_aControlhandles [x] ) , .T. )
                           ELSE  // Horizontal layout
                              MoveWindow ( _HMG_aControlhandles [x] [z] , _HMG_aControlCol [x] - NewHPos + ( z - 1 ) * ( _HMG_aControlWidth [x] + _HMG_aControlSpacing[x] ), _HMG_aControlRow [x] - NewPos , _HMG_aControlWidth [x] , _HMG_aControlHeight [x] , .T. )
                           ENDIF
                        NEXT z

                     *ELSEIF _HMG_aControlType [x] == 'TOOLBAR'

                        *MsgMiniGuiError( "ToolBar's Parent Window cannot be a 'Virtual Dimensioned' window (use 'Virtual Dimensioned' SplitChild instead)." )

                     ELSE

                        _HMG_aControlCol [x] := IIF(_HMG_aControlCol [x]=Nil,0,_HMG_aControlCol [x])    
                        _HMG_aControlRow [x] := IIF(_HMG_aControlRow [x]=Nil,0,_HMG_aControlRow [x])    
                        MoveWindow ( _HMG_aControlhandles [x] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewPos , _HMG_aControlWidth [x] , _HMG_aControlHeight [x] , .T. )

                     ENDIF

                  ENDIF

               NEXT x

               ReDrawWindow ( hwnd )

            ENDIF

         ENDIF

         // Execute registered window scroll event callbacks
         SWITCH LoWord ( wParam )
         CASE SB_LINEDOWN
            _DoWindowEventProcedure ( _HMG_aFormScrollDown [i] , i )
            EXIT
         CASE SB_LINEUP
            _DoWindowEventProcedure ( _HMG_aFormScrollUp [i] , i )
            EXIT
         CASE SB_THUMBPOSITION
         CASE SB_PAGEUP
         CASE SB_PAGEDOWN
         CASE SB_TOP
         CASE SB_BOTTOM
            _DoWindowEventProcedure ( _HMG_aFormVScrollBox [i] , i )
         END SWITCH

      ENDIF

#ifdef _DBFBROWSE_
      // DBF Browse control vertical scrollbar interaction logic
      i := AScan ( _HMG_aControlIds , lParam )

      IF i > 0

         IF _HMG_aControlType [i] == 'BROWSE'

            IF LoWord( wParam ) == SB_LINEDOWN
               setfocus( _HMG_aControlHandles [i] )
               InsertDown()
            ENDIF

            IF LoWord( wParam ) == SB_LINEUP
               setfocus( _HMG_aControlHandles [i] )
               InsertUp()
            ENDIF

            IF LoWord( wParam ) == SB_PAGEUP
               setfocus( _HMG_aControlHandles [i] )
               InsertPrior()
            ENDIF

            IF LoWord( wParam ) == SB_PAGEDOWN
               setfocus( _HMG_aControlHandles [i] )
               InsertNext()
            ENDIF

            IF LoWord( wParam ) == SB_THUMBPOSITION

               BackArea := Alias()
               BrowseArea := _HMG_aControlSpacing [i]

               IF Select ( BrowseArea ) != 0

                  Select &BrowseArea
                  BackRec := RecNo()

                  IF ordKeyCount() > 0
                     RecordCount := ordKeyCount()
                  ELSE
                     RecordCount := RecCount()
                  ENDIF

                  SkipCount := Int ( HIWORD( wParam ) * RecordCount / GetScrollRangeMax ( _HMG_aControlIds [ i ] , 2 ) )

                  IF SkipCount > ( RecordCount / 2 )
                     GO BOTTOM
                     SKIP - ( RecordCount - SkipCount )
                  ELSE
                     GO TOP
                     IF SkipCount > 1
                        SKIP SkipCount - RecCount() / 100
                     ENDIF
                  ENDIF

                  IF EOF()
                     SKIP -1
                  ENDIF

                  nr := RecNo()

                  SetScrollPos ( _HMG_aControlIds [i] , 2 , HIWORD( wParam ) , .T. )

                  GO BackRec

                  IF Select ( BackArea ) != 0
                     Select &BackArea
                  ELSE
                     Select 0
                  ENDIF

                  _BrowseSetValue ( '' , '' , nr , i )

               ENDIF

            ENDIF

         ENDIF

      ENDIF
#endif
      _ProcessSliderEvents ( lParam , wParam )
      EXIT

   ****************************************************************************
   CASE WM_TASKBAR
   ****************************************************************************
      // Process System Tray Notification Icon events (Left Click, Double Click, Context Menu)
      IF wParam == ID_TASKBAR .AND. lParam # WM_MOUSEMOVE

         SWITCH lParam
         CASE WM_LBUTTONDOWN
            IF ( i := AScan ( _HMG_aFormHandles , hWnd ) ) > 0
               _DoWindowEventProcedure ( _HMG_aFormNotifyIconLeftClick [i] , i , "TASKBAR_CLICK" )
            ENDIF
            EXIT
         CASE TTM_DELTOOLA
            IF IsToolTipBalloonActive .AND. hWnd == _HMG_MainHandle
               _DoWindowEventProcedure ( _HMG_NotifyBalloonClick , AScan ( _HMG_aFormHandles , hWnd ) , "TOOLTIP_CLICK" )
            ENDIF
            EXIT
         CASE WM_LBUTTONDBLCLK
            IF ( i := AScan ( _HMG_aFormHandles , hWnd ) ) > 0
               _DoWindowEventProcedure ( _HMG_aFormNotifyIconDblClick [i] , i , "TASKBAR_DBLCLICK" )
            ENDIF
            EXIT
         CASE WM_RBUTTONDOWN
            IF _HMG_ShowContextMenus
               aPos := GetCursorPos()
               IF ( i := AScan ( _HMG_aFormHandles , hWnd ) ) > 0
                  IF _HMG_aFormNotifyMenuHandle [i] != 0
                     TrackPopupMenu ( _HMG_aFormNotifyMenuHandle [i] , aPos [2] , aPos [1] , hWnd , .T. )
                  ENDIF
               ENDIF
            ENDIF
         END SWITCH

      ENDIF
      EXIT

#ifdef _OBJECT_
   ****************************************************************************
   CASE WM_WND_LAUNCH
   ****************************************************************************
      IF _HMG_lOOPEnabled
         Eval ( _HMG_bOnWndLaunch, hWnd, nMsg, wParam, lParam )
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_CTL_LAUNCH
   ****************************************************************************
      IF _HMG_lOOPEnabled
         Eval ( _HMG_bOnCtlLaunch, hWnd, nMsg, wParam, lParam )
      ENDIF
      EXIT
#endif

   ****************************************************************************
   CASE WM_NEXTDLGCTL
   ****************************************************************************
      // Custom Tab/Shift+Tab dialog navigation logic managing focus shifts and default pushbuttons.
      IF LoWord ( lParam ) != 0
         NextControlHandle := wParam
      ELSE
         NextControlHandle := GetNextDlgTabITem ( GetActiveWindow() , GetFocus() , ( wParam != 0 ) )
      ENDIF

      setfocus( NextControlHandle )

      i := AScan ( _HMG_aControlHandles , NextControlHandle )

      IF i > 0

         IF _HMG_aControlType [i] == 'BUTTON'
            SendMessage ( NextControlHandle , BM_SETSTYLE , LOWORD ( BS_DEFPUSHBUTTON ) , 1 )
         ELSEIF _HMG_aControlType [i] == 'EDIT' .OR. _HMG_aControlType [i] == 'TEXT'
            SendMessage( _HMG_aControlHandles [i] , EM_SETSEL , 0 , -1 )
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_HSCROLL
   ****************************************************************************
      // Handles Horizontal ScrollBar events for virtual windows and slider controls.
      i := AScan ( _HMG_aFormHandles , hWnd )

      IF i > 0

         IF _HMG_aFormVirtualWidth [i] > 0 .AND. lParam == 0

            IF _HMG_aFormRebarhandle [i] > 0
               *MsgMiniGuiError( "SplitBox's Parent Window cannot be a 'Virtual Dimensioned' window (use 'Virtual Dimensioned' SplitChild instead)." )
            ENDIF

            z := iif( _HMG_aScrollStep [1] > 0, _HMG_aScrollStep [1], GetScrollRangeMax ( hwnd , SB_HORZ ) / _HMG_aScrollStep [2] )

            IF LoWord( wParam ) == SB_LINERIGHT
               NewHPos := GetScrollPos( hwnd, SB_HORZ ) + z
               IF NewHPos >= GetScrollRangeMax( hwnd, SB_HORZ ) - 10
                  NewHPos := GetScrollRangeMax( hwnd, SB_HORZ )
               ENDIF
               SetScrollPos ( hwnd , SB_HORZ , NewHPos , .T. )

            ELSEIF LoWord( wParam ) == SB_LINELEFT
               NewHPos := GetScrollPos( hwnd, SB_HORZ ) - z
               IF NewHPos < 10
                  NewHPos := 0
               ENDIF
               SetScrollPos ( hwnd , SB_HORZ , NewHPos , .T. )

            ELSEIF LoWord( wParam ) == SB_PAGELEFT
               NewHPos := GetScrollPos( hwnd, SB_HORZ ) - _HMG_aScrollStep [2]
               SetScrollPos ( hwnd , SB_HORZ , NewHPos , .T. )

            ELSEIF LoWord( wParam ) == SB_PAGERIGHT
               NewHPos := GetScrollPos( hwnd, SB_HORZ ) + _HMG_aScrollStep [2]
               SetScrollPos ( hwnd , SB_HORZ , NewHPos , .T. )

            ELSEIF LoWord( wParam ) == SB_THUMBPOSITION
               NewHPos := HIWORD( wParam )
               SetScrollPos ( hwnd , SB_HORZ , NewHPos , .T. )

            ENDIF

            IF _HMG_aFormVirtualHeight [i] > 0
               NewVPos := GetScrollPos ( hwnd , SB_VERT )
            ELSE
               NewVPos := 0
            ENDIF

            // Reposition child controls dynamically during horizontal scrolling
            IF LoWord( wParam ) == SB_THUMBPOSITION .OR. LoWord( wParam ) == SB_LINELEFT .OR. LoWord( wParam ) == SB_LINERIGHT .OR. LoWord( wParam ) == SB_PAGELEFT .OR. LoWord( wParam ) == SB_PAGERIGHT .AND. ! _HMG_AutoAdjust

               FOR x := 1 TO Len ( _HMG_aControlhandles )

                  IF _HMG_aControlParentHandles [x] == hwnd

                     IF _HMG_aControlType [x] == 'SPINNER'

                        MoveWindow ( _HMG_aControlhandles [x] [1] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewVPos , _HMG_aControlWidth [x] - GetWindowWidth( _HMG_aControlhandles [x] [2] ) + 1 , _HMG_aControlHeight [x] , .T. )
                        MoveWindow ( _HMG_aControlhandles [x] [2] , _HMG_aControlCol [x] + _HMG_aControlWidth [x] - GetWindowWidth( _HMG_aControlhandles [x] [2] ) - NewHPos , _HMG_aControlRow [x] - NewVPos , ;
                           GetWindowWidth( _HMG_aControlhandles [x] [2] ) , _HMG_aControlHeight [x] , .T. )
#ifdef _DBFBROWSE_
                     ELSEIF _HMG_aControlType [x] == 'BROWSE'

                        MoveWindow ( _HMG_aControlhandles [x] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewVPos , _HMG_aControlWidth [x] - GETVSCROLLBARWIDTH() , _HMG_aControlHeight [x] , .T. )

                        MoveWindow ( _HMG_aControlIds [x] , _HMG_aControlCol [x] + _HMG_aControlWidth [x] - GETVSCROLLBARWIDTH() - NewHPos , _HMG_aControlRow [x] - NewVPos , ;
                           GetWindowWidth( _HMG_aControlIds [x] ) , GetWindowHeight( _HMG_aControlIds [x] ) , .T. )

                        MoveWindow ( _HMG_aControlMiscData1 [x] [1] , _HMG_aControlCol [x] + _HMG_aControlWidth [x] - GETVSCROLLBARWIDTH() - NewHPos , _HMG_aControlRow [x] + _HMG_aControlHeight[x] - GethScrollBarHeight() - NewVPos , ;
                           GetWindowWidth( _HMG_aControlMiscData1 [x] [1] ) , GetWindowHeight ( _HMG_aControlMiscData1 [x][1] ) , .T. )

                        ReDrawWindow ( _HMG_aControlhandles [x] )
#endif
                     ELSEIF _HMG_aControlType [x] == 'RADIOGROUP'

                        FOR z := 1 TO Len ( _HMG_aControlhandles [x] )
                           IF _HMG_aControlMiscData1 [x] == .F.
                              MoveWindow ( _HMG_aControlhandles [x] [z] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewVPos + ( z - 1 ) * _HMG_aControlSpacing[x], ;
                                 _HMG_aControlWidth [x] , _HMG_aControlHeight [x] / Len ( _HMG_aControlhandles [x] ) , .T. )
                           ELSE  // Horizontal layout
                              MoveWindow ( _HMG_aControlhandles [x] [z] , _HMG_aControlCol [x] - NewHPos + ( z - 1 ) * ( _HMG_aControlWidth [x] + _HMG_aControlSpacing[x] ) , _HMG_aControlRow [x] - NewVPos , ;
                                 _HMG_aControlWidth [x] , _HMG_aControlHeight [x] , .T. )
                           ENDIF
                        NEXT z

                     *ELSEIF _HMG_aControlType [x] == 'TOOLBAR'

                       * MsgMiniGuiError( "ToolBar's Parent Window cannot be a 'Virtual Dimensioned' window (use 'Virtual Dimensioned' SplitChild instead)." )

                     ELSE

                        _HMG_aControlCol [x] := IIF(_HMG_aControlCol [x]=Nil,0,_HMG_aControlCol [x])    
                        _HMG_aControlRow [x] := IIF(_HMG_aControlRow [x]=Nil,0,_HMG_aControlRow [x])    
                        MoveWindow ( _HMG_aControlhandles [x] , _HMG_aControlCol [x] - NewHPos , _HMG_aControlRow [x] - NewVPos , _HMG_aControlWidth [x] , _HMG_aControlHeight [x] , .T. )

                     ENDIF

                  ENDIF
               NEXT x

               RedrawWindow ( hwnd )

            ENDIF

         ENDIF

         SWITCH LoWord ( wParam )
         CASE SB_LINERIGHT
            _DoWindowEventProcedure ( _HMG_aFormScrollRight [i] , i )
            EXIT
         CASE SB_LINELEFT
            _DoWindowEventProcedure ( _HMG_aFormScrollLeft [i] , i )
            EXIT
         CASE SB_THUMBPOSITION
         CASE SB_PAGELEFT
         CASE SB_PAGERIGHT
            _DoWindowEventProcedure ( _HMG_aFormHScrollBox [i] , i )
         END SWITCH

      ENDIF

      _ProcessSliderEvents ( lParam , wParam )
      EXIT

   ****************************************************************************
   CASE WM_PAINT
   ****************************************************************************
      // Executes custom graphics drawing tasks and triggers ON PAINT window procedures.
      FOR EACH r IN _HMG_aFormHandles
         z := hb_enumindex ( r )
         IF _HMG_aFormDeleted [z] == .F. .AND. _HMG_aFormType [z] == 'X'
            a := _HMG_aFormGraphTasks [z]
            IF ISARRAY ( a ) .AND. Len ( a ) > 0
               AEval ( a, { |x| Eval ( x ) } )
            ENDIF
         ENDIF
      NEXT

      i := AScan ( _HMG_aFormHandles , hWnd )

      IF i > 0
         _DoWindowEventProcedure ( _HMG_aFormPaintProcedure [i] , i )

         FOR x := 1 TO Len ( _HMG_aFormGraphTasks [i] )
            Eval ( _HMG_aFormGraphTasks [i] [x] )
         NEXT x

         // Adjust bottom toolbar alignment with status bar
         k := 0
         FOR EACH r IN _HMG_aControlHandles
            z := hb_enumindex ( r )
            IF _HMG_aControlParentHandles [z] == hWnd
               IF _HMG_aControlType [z] == "TOOLBAR" .AND. And ( GetWindowLong ( r , GWL_STYLE ), CCS_BOTTOM ) == CCS_BOTTOM
                  k := r
                  EXIT
               ENDIF
            ENDIF
         NEXT

         IF k > 0 .AND. _IsControlDefined ( "StatusBar" , _HMG_aFormNames [i] ) .AND. _HMG_SplitLastControl != "TOOLBAR"
            aPos := { 0, 0, 0, 0 }
            GetClientRect ( _HMG_aFormHandles [i], /*@*/ aPos )
            SetWindowPos ( k, 0, 0, aPos [4] - LoWord( GetSizeToolBar( k ) ) - GetBorderHeight() - GetProperty( _HMG_aFormNames [i], "StatusBar", "Height" ), 0, 0, SWP_NOSIZE + SWP_NOZORDER )
         ENDIF
         RETURN 0
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_MBUTTONDOWN
   CASE WM_RBUTTONDOWN
   ****************************************************************************
      // Captures mouse row/col coordinates and triggers form click procedures on right/middle click.
      _HMG_MouseRow := HIWORD( lParam )
      _HMG_MouseCol := LOWORD( lParam )
      _HMG_MouseState := iif( nMsg == WM_RBUTTONDOWN, 2, 3 )

      IF ! _HMG_ShowContextMenus

         i := AScan ( _HMG_aFormHandles , hWnd )

         IF i > 0
            _MouseCoordCorr ( hWnd , i )
            _DoWindowEventProcedure ( _HMG_aFormClickProcedure [i] , i )
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_LBUTTONDOWN
   ****************************************************************************
      // Captures mouse row/col coordinates and executes ON CLICK window callback.
      _HMG_MouseRow := HIWORD( lParam )
      _HMG_MouseCol := LOWORD( lParam )
      _HMG_MouseState := 1

      i := AScan ( _HMG_aFormhandles , hWnd )

      IF i > 0
         _MouseCoordCorr ( hWnd , i )
         _DoWindowEventProcedure ( _HMG_aFormClickProcedure [i] , i )
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_MBUTTONUP
   CASE WM_RBUTTONUP
   CASE WM_LBUTTONUP
   ****************************************************************************
      // Resets active mouse button tracking state flag
      _HMG_MouseState := 0
      EXIT

   ****************************************************************************
   CASE WM_MOUSEMOVE
   ****************************************************************************
      // Updates cursor coordinates and executes ON MOUSEMOVE / ON MOUSEDRAG procedures.
      _HMG_MouseRow := HIWORD( lParam )
      _HMG_MouseCol := LOWORD( lParam )

      i := AScan ( _HMG_aFormhandles , hWnd )

      IF i > 0
         _MouseCoordCorr ( hWnd , i )

         IF wParam == MK_LBUTTON
            _DoWindowEventProcedure ( _HMG_aFormMouseDragProcedure [i] , i )
         ELSE
            _DoWindowEventProcedure ( _HMG_aFormMouseMoveProcedure [i] , i )
         ENDIF
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_DROPFILES
   ****************************************************************************
      // Handles drag-and-drop file events onto form window (ON DROPFILES procedure).
      i := AScan ( _HMG_aFormhandles , hWnd )

      IF i > 0
         SetForegroundWindow( hWnd )
         Eval( _HMG_aFormDropProcedure [i], DragQueryFiles( wParam ) )
         DragFinish( wParam )
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_CONTEXTMENU
   ****************************************************************************
      // Displays control-specific or form-level context menus on right click.
      _HMG_MouseRow := HIWORD( lParam )
      _HMG_MouseCol := LOWORD( lParam )

      IF ( i := AScan ( _HMG_aControlHandles , wParam ) ) > 0 .AND. ;
         _HMG_aControlType [i] $ 'IMAGE,LABEL' .AND. ISBLOCK( _HMG_aControlChangeProcedure [i] )

         _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )

      ELSEIF ( i := AScan ( _HMG_aControlsContextMenu , { |x| x [1] == wParam } ) ) > 0 .AND. ;
         _HMG_aControlsContextMenu [i, 4] == .T.

         setfocus ( wParam )
         _HMG_xControlsContextMenuID := _HMG_aControlsContextMenu [i, 3]

         // Dynamic menu option enable/disable state for RichEditBox context menus
         IF _HMG_aControlType [ _HMG_xControlsContextMenuID ] = "RICHEDIT" .AND. _HMG_aControlMiscData1 [_HMG_xControlsContextMenuID] == 1

            cParent := GetParentFormName ( _HMG_xControlsContextMenuID )
            hEdit := _HMG_aControlHandles [_HMG_xControlsContextMenuID]

            // Calculate active selection character offset range
            a := RichEditBox_GetSelRange ( hEdit )
            nStart := a [1]
            nEnd := a [2]

            // Toggle Undo state availability
            SetProperty ( cParent, "mnuEditUndo", "Enabled", RichEditBox_CanUndo ( hEdit ) )

            // Toggle Cut, Copy, Delete state based on active selection
            SetProperty ( cParent, "mnuEditCut", "Enabled", ( nStart < nEnd ) )
            SetProperty ( cParent, "mnuEditCopy", "Enabled", ( nStart < nEnd ) )
            SetProperty ( cParent, "mnuEditDelete", "Enabled", ( nStart < nEnd ) )

            // Toggle Paste availability
            SetProperty ( cParent, "mnuEditPaste", "Enabled", RichEditBox_CanPaste ( hEdit ) )

            // Toggle Select All state
            SetProperty ( cParent, "mnuEditSelAll", "Enabled", .NOT. ( nStart == 0 .AND. nEnd == RichEditBox_GetTextLength ( hEdit ) + 1 ) )

         ENDIF

         TrackPopupMenu ( _HMG_aControlsContextMenu [i, 2], _HMG_MouseCol, _HMG_MouseRow, hWnd )

      ELSEIF _HMG_ShowContextMenus

         setfocus ( wParam )

         IF ( i := AScan ( _HMG_aFormHandles , hWnd ) ) > 0
            IF _HMG_aFormContextMenuHandle [i] != 0
               aPos := GetCursorPos()
               _HMG_MouseRow := aPos [1]
               _HMG_MouseCol := aPos [2]
               _MouseCoordCorr ( hWnd , i )
               TrackPopupMenu ( _HMG_aFormContextMenuHandle [i], _HMG_MouseCol, _HMG_MouseRow, hWnd )
            ENDIF
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_TIMER
   ****************************************************************************
      // Dispatches timer tick events to associated control procedures.
      i := AScan ( _HMG_aControlIds , wParam )

      IF i > 0

         IF _HMG_aControlPicture [i] == .T.  // Single-shot timer flag
            _DisableControl ( _HMG_aControlNames [i], GetParentFormName( i ) )
         ENDIF

         IF _HMG_aControlVisible [i] == .T.  // Active control scope
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
         ELSEIF ISBLOCK( _HMG_aControlProcedures [i] )
            IF _HMG_BeginWindowActive == .F. .OR. _HMG_MainClientMDIHandle != 0
               Eval ( _HMG_aControlProcedures [i] )
            ENDIF
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_MOVE
   ****************************************************************************
      // Executes ON MOVE event procedure when form window is moved across desktop screen.
      _HMG_MouseRow := HIWORD( lParam )
      _HMG_MouseCol := LOWORD( lParam )

      i := AScan ( _HMG_aFormhandles , hWnd )

      IF i > 0

         IF _HMG_MainActive == .T. .OR. _HMG_aFormActive [i] == .T.
            _DoWindowEventProcedure ( _HMG_aFormMoveProcedure [i] , i )
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_ENTERSIZEMOVE
   ****************************************************************************
      // Triggers when window begins interactive sizing or moving modal loop.
      IF ! _HMG_AutoAdjust
         lEnterSizeMove := NIL
         _HMG_MouseState := 1
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_SIZE
   ****************************************************************************
      // Handles window resizing events, updates child controls, rebars, and triggers ON SIZE events.
      IF HB_ISNIL( lEnterSizeMove ) .OR. ! lEnterSizeMove .OR. ! iswinnt()

         hb_default( @lEnterSizeMove, .T. )

         i := AScan ( _HMG_aFormHandles , hWnd )

         IF i > 0

            r := 0
            IF ( k := _HMG_aFormReBarHandle [i] ) > 0
               SizeRebar ( k )
               r := RebarHeight ( k )
               RedrawWindow ( k )
            ENDIF

            // Update status / message bars attached to window
            FOR EACH z IN _HMG_aControlHandles

               x := hb_enumindex ( z )

               IF _HMG_aControlParentHandles [x] == hWnd

                  IF _HMG_aControlType [x] == "MESSAGEBAR"

                     MoveWindow( z , 0 , 0 , 0 , 0 , .T. )
                     RefreshItemBar ( z , _GetStatusItemWidth( hWnd, 1 ) )

                     IF ( k := GetControlIndex( 'ProgressMessage', GetParentFormName( x ) ) ) != 0
                        RefreshProgressItem ( _HMG_aControlMiscData1 [k, 1], z, _HMG_aControlMiscData1 [k, 2] )
                     ENDIF
                     EXIT

                  ENDIF

               ENDIF

            NEXT

            IF _HMG_MainClientMDIHandle != 0

               IF wParam != SIZE_MINIMIZED

                  SizeClientWindow ( hWnd, _HMG_ActiveStatusHandle, _HMG_MainClientMDIHandle, r )

               ENDIF

            ENDIF

            // Dispatch state specific size events (Maximize, Minimize, Restore, Resize)
            IF _HMG_MainActive == .T. .OR. _HMG_aFormActive [i] == .T.

               IF wParam == SIZE_MAXIMIZED

                  _DoWindowEventProcedure ( _HMG_aFormMaximizeProcedure [i], i )

                  IF _HMG_AutoAdjust .AND. _HMG_MainClientMDIHandle == 0
                     _Autoadjust( hWnd )
                  ENDIF

               ELSEIF wParam == SIZE_MINIMIZED

                  _DoWindowEventProcedure ( _HMG_aFormMinimizeProcedure [i], i )

               ELSEIF wParam == SIZE_RESTORED .AND. !IsWindowSized( hWnd )

                  _DoWindowEventProcedure ( _HMG_aFormRestoreProcedure [i], i )

               ELSE

                  IF _HMG_aFormType [i] == 'M' .AND. IsMenu( GetMenu ( hWnd ) ) .AND. ! _HMG_aFormActive [i]
                  ELSEIF !lEnterSizeMove
                     _DoWindowEventProcedure ( _HMG_aFormSizeProcedure [i], i )
                  ENDIF

                  IF _HMG_AutoAdjust .AND. _HMG_MainClientMDIHandle == 0
                     _Autoadjust( hWnd )
                  ENDIF

               ENDIF

            ENDIF

         ENDIF

         // Auto-size toolbar controls
         FOR EACH x IN _HMG_aControlHandles

            i := hb_enumindex ( x )

            IF _HMG_aControlParentHandles [i] == hWnd
               IF _HMG_aControlType [i] == "TOOLBAR"
                  SendMessage ( x, TB_AUTOSIZE, 0, 0 )
               ENDIF
            ENDIF

         NEXT

         IF _HMG_MainClientMDIHandle != 0
            RETURN 1
         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_EXITSIZEMOVE
   ****************************************************************************
      // Clears sizing/moving loop flags upon completion.
      lEnterSizeMove := .F.
      IF ! _HMG_AutoAdjust
         _HMG_MouseState := 0
         SendMessage ( hWnd , WM_SIZE , 0 , 0 )
      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_COMMAND
   ****************************************************************************
      // Core Win32 notification command handler for Menus, Buttons, Edits, and Controls.
      i := AScan ( _HMG_aControlIds , LoWord( wParam ) )

      IF i > 0

         // Process Menu items
         IF HiWord ( wParam ) == 0 .AND. _HMG_aControlType [i] == "MENU"
            IF _HMG_aControlMiscData1 [i] == 1
               _CloseMenu()
            ENDIF
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            RETURN 0
         ENDIF

         // Process ToolBar Buttons
         IF _HMG_aControlType [i] == "TOOLBUTTON"
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            RETURN 0
         ENDIF

      ENDIF

#ifdef _TSBROWSE_
      oGet := GetObjectByHandle( lParam )
      IF ISOBJECT( oGet )
         r := oGet:HandleEvent ( nMsg, wParam, lParam )
         IF ValType( r ) == 'N'
            IF r != 0
               RETURN r
            ENDIF
         ENDIF
      ENDIF
#endif

      i := AScan ( _HMG_aControlHandles , lParam )

      // Search for composite controls (e.g., Spinner text box handle)
      IF i == 0

         FOR EACH r IN _HMG_aControlHandles
            IF ISARRAY ( r )
               x := hb_enumindex ( r )
               IF r [1] == lParam .AND. _HMG_aControlType [x] == 'SPINNER'
                  i := x
                  EXIT
               ENDIF
            ENDIF
         NEXT

      ENDIF

      IF i > 0

         // Button Click Notifications
         IF HiWord ( wParam ) == BN_CLICKED .AND. _HMG_aControlType [i] $ "OBUTTON"

            IF _HMG_aControlType [i] == "BUTTON"
               _SetFocus ( , , i )
            ELSEIF _HMG_aControlRangeMax [i][1] > 0  // Boundary check
               a := GetCursorPos()
               IF ( x := GetWindowCol( lParam ) ) + GetWindowWidth( lParam ) < a [2] .OR. ;
                  ( r := GetWindowRow( lParam ) ) + GetWindowHeight( lParam ) < a [1] .OR. x > a [2] .OR. r > a [1]
                  RETURN 0
               ENDIF
            ENDIF
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            RETURN 0

         ENDIF

         // CheckBox Click Notifications
         IF HiWord ( wParam ) == BN_CLICKED .AND. _HMG_aControlType [i] == "CHECKBOX"
            _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
            RETURN 0
         ENDIF

         // Label / HyperLink / Image Click Notifications
         IF HiWord ( wParam ) == STN_CLICKED .AND. ( "LABEL" $ _HMG_aControlType [i] .OR. _HMG_aControlType [i] $ "HYPERLINK,IMAGE" )
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            RETURN 0
         ENDIF

         // Label / Image Double Click Notifications
         IF HiWord ( wParam ) == STN_DBLCLK .AND. _HMG_aControlType [i] $ "LABEL,IMAGE"
            _DoControlEventProcedure ( _HMG_aControlHeadClick [i] , i )
            RETURN 0
         ENDIF

         // RichEdit Vertical Scroll Events
         IF HiWord ( wParam ) == EN_VSCROLL .AND. ( _HMG_aControlType [i] == "RICHEDIT" )
            IF _HMG_aControlMiscData1 [i] == 0
               _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            ELSE
               _DoControlEventProcedure ( _HMG_aControlRangeMax [i] , i )
            ENDIF
            RETURN 0
         ENDIF

         // TextBox, GetBox, MaskedText Change Events
         IF HiWord ( wParam ) == EN_CHANGE

            IF _HMG_aControlType [i] == 'GETBOX'

               IF GetFocus() == _HMG_aControlHandles [i]
                  oGet := _HMG_aControlHeadClick [i]
                  IF oGet:Changed
                     r := _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                     IF _HMG_aControlPageMap [i] != NIL .AND. _HMG_aControlMiscData1 [i, 10] == .T.
                        IF ValType( oGet:cargo ) == "D" .AND. oGet:BadDate
                           RETURN 0
                        ELSEIF ! ISBLOCK ( _HMG_aControlChangeProcedure [i] ) .OR. ISLOGICAL ( r ) .AND. r == .T.
                           _SaveData ( _HMG_aControlNames [i] , GetParentFormName( i ) )
                        ENDIF
                     ENDIF
                     RETURN 0
                  ENDIF
               ENDIF

            ENDIF

            IF _HMG_DateTextBoxActive == .T.

              _HMG_DateTextBoxActive := .F.

            ELSE

               IF Len ( _HMG_aControlInputMask [i] ) > 0
                  IF _HMG_aControlType [i] == 'MASKEDTEXT'
                     IF _HMG_aControlSpacing [i] == .T.
                        ProcessCharmask ( i, .T. )
                     ENDIF
                     _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                  ELSEIF _HMG_aControlType [i] == 'CHARMASKTEXT'
                     _HMG_DateTextBoxActive := .T.
                     ProcessCharMask ( i )
                     _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                  ENDIF
               ELSE
                  IF 'NUMTEXT' $ _HMG_aControlType[i]
                     ProcessNumText ( i )
                  ENDIF

                  IF _HMG_aControlType [i] <> 'GETBOX'
                     _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                  ENDIF
               ENDIF

            ENDIF

            RETURN 0

         ENDIF

         // Edit control Lost Focus (EN_KILLFOCUS) Processing
         IF HiWord ( wParam ) == EN_KILLFOCUS

            IF _HMG_aControlType [i] == 'MASKEDTEXT'
               _HMG_DateTextBoxActive := .T.
               _HMG_aControlSpacing [i] := .F.

               // Format dynamic numeric text formatting on loss of focus
               IF "E" $ _HMG_aControlPageMap [i]
                  Ts := GetWindowText ( _HMG_aControlHandles [i] )
                  IF "." $ _HMG_aControlPageMap [i]
                     DO CASE
                     CASE hb_UAt ( '.' , Ts ) > hb_UAt ( ',' , Ts )
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlHandles [i] ) , i ) , _HMG_aControlPageMap[i] ) )

                     CASE hb_UAt ( ',' , Ts ) > hb_UAt ( '.' , Ts )
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromTextSp ( GetWindowText ( _HMG_aControlHandles [i] ) , i ) , _HMG_aControlPageMap[i] ) )
                     ENDCASE
                  ELSE
                     DO CASE
                     CASE hb_UAt ( '.' , Ts ) != 0
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromTextSp ( GetWindowText ( _HMG_aControlHandles [i] ) , i ) , _HMG_aControlPageMap[i] ) )

                     CASE hb_UAt ( ',' , Ts ) != 0
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlHandles [i] ) , i ) , _HMG_aControlPageMap[i] ) )

                     OTHERWISE
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlHandles [i] ) , i ) , _HMG_aControlPageMap[i] ) )
                     ENDCASE
                  ENDIF
               ELSE
                  SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlhandles [i] ) , i ) , _HMG_aControlPageMap[i] ) )
               ENDIF

            ENDIF

            IF _HMG_aControlType [i] == 'CHARMASKTEXT'
               IF ValType ( _HMG_aControlHeadCLick [i] ) == 'L'
                  IF _HMG_aControlHeadCLick [i] == .T.
                     _HMG_DateTextBoxActive := .T.
                     SetWindowText ( _HMG_aControlHandles [i] , DToC ( CToD ( GetWindowText ( _HMG_aControlHandles [i] ) ) ) )
                  ENDIF
               ENDIF
            ENDIF

            IF _HMG_InteractiveCloseStarted != .T.
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i], i )

               // Validate spinner input range upon focus exit
               IF _HMG_aControlType [i] == "SPINNER"
                  Ts := GetWindowText ( _HMG_aControlHandles [i] [1] )
                  IF ! _HMG_aControlMiscData1 [i] [2] .AND. ! Empty ( Ts )
                     IF ( z := Val ( Ts ) ) < _HMG_aControlRangeMin [i]
                        SetSpinnerValue ( _HMG_aControlHandles [i] [2] , _HMG_aControlRangeMin [i] )
                     ELSEIF z > _HMG_aControlRangeMax [i]
                        SetSpinnerValue ( _HMG_aControlHandles [i] [2] , _HMG_aControlRangeMax [i] )
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF
            RETURN 0

         ENDIF

         // Edit control Got Focus (EN_SETFOCUS) Processing
         IF HiWord( wParam ) == EN_SETFOCUS

            VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )

            IF _HMG_aControlType [i] == 'MASKEDTEXT'

               _HMG_DateTextBoxActive := .T.

               IF "E" $ _HMG_aControlPageMap [i]

                  Ts := GetWindowText ( _HMG_aControlHandles [i] )
                  IF "." $ _HMG_aControlPageMap [i]
                     DO CASE
                     CASE hb_UAt ( '.' , Ts ) >  hb_UAt ( ',' , Ts )
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlhandles [i] ) , i ) , _HMG_aControlInputMask [i] ) )

                     CASE hb_UAt ( ',' , Ts ) > hb_UAt ( '.' , Ts )
                        TmpStr := Transform ( GetNumFromTextSP ( GetWindowText ( _HMG_aControlhandles [i] ) , i )  , _HMG_aControlInputMask [i] )
                        IF Val ( TmpStr ) == 0
                           TmpStr := StrTran ( TmpStr , '0.' , ' .' )
                        ENDIF
                        SetWindowText ( _HMG_aControlhandles [i] , TmpStr )
                     ENDCASE

                  ELSE

                     DO CASE
                     CASE hb_UAt ( '.' , Ts ) !=  0
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromTextSP ( GetWindowText ( _HMG_aControlhandles [i] ) , i ) , _HMG_aControlInputMask [i] ) )

                     CASE hb_UAt ( ',' , Ts )  != 0
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlhandles [i] ) , i ) , _HMG_aControlInputMask [i] ) )

                     OTHERWISE
                        SetWindowText ( _HMG_aControlhandles [i] , Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlhandles [i] ) , i ) , _HMG_aControlInputMask [i] ) )
                     ENDCASE

                  ENDIF

               ELSE

                  TmpStr := Transform ( GetNumFromText ( GetWindowText ( _HMG_aControlhandles [i] ) , i ) , _HMG_aControlInputMask [i] )
                  IF Val ( TmpStr ) == 0
                     TmpStr := StrTran ( TmpStr , '0.' , ' .' )
                  ENDIF
                  SetWindowText ( _HMG_aControlhandles [i] , TmpStr )

               ENDIF

               SendMessage( _HMG_aControlhandles [i] , EM_SETSEL , 0 , -1 )
               _HMG_aControlSpacing [i] := .T.

            ENDIF

            IF _HMG_aControlType [i] == 'CHARMASKTEXT'

               MaskStart := 1

               FOR EACH x IN _HMG_aControlInputMask [i]
                  IF hmg_IsDigit( x ) .OR. hmg_IsAlpha( x ) .OR. x == '!'
                     MaskStart := hb_enumindex( x )
                     EXIT
                  ENDIF
               NEXT

               SendMessage( _HMG_aControlhandles [i] , EM_SETSEL , MaskStart - 1 , -1 )

            ENDIF

            _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )

            RETURN 0

         ENDIF

         // ListBox Notifications (Change, Focus, Double Click)
         IF 'LIST' $ _HMG_aControlType[i]

            IF HiWord( wParam ) == LBN_SELCHANGE
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == LBN_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == LBN_SETFOCUS
               VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == LBN_DBLCLK
               _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
               RETURN 0
            ENDIF

         ENDIF

         // ComboBox Notifications
         IF _HMG_aControlType [i] == 'COMBO'

            IF HiWord( wParam ) == CBN_SELCHANGE
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == CBN_SELENDCANCEL .AND. _HMG_aControlMiscData1 [i][1] <> 1
               _DoControlEventProcedure ( _HMG_aControlMiscData1 [i][10] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == CBN_DROPDOWN
               _DoControlEventProcedure ( _HMG_aControlInputMask [i] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == CBN_CLOSEUP
               _DoControlEventProcedure ( _HMG_aControlPicture [i] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == CBN_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == CBN_SETFOCUS
               VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF HiWord( wParam ) == CBN_EDITCHANGE
               _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
               IF _HMG_aControlMiscData1 [i][1] == 0 .AND. _HMG_aControlMiscData1 [i][2] == .T. .AND. _HMG_aControlMiscData1 [i][7] == .T.
                  DoComboAutoComplete ( i )
               ENDIF
               RETURN 0
            ENDIF

         ENDIF

         // Button Lost/Got Focus Notifications
         IF HiWord( wParam ) == BN_KILLFOCUS .AND. _HMG_aControlType [i] != 'COMBO'
            _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
            RETURN 0
         ENDIF

         IF HiWord( wParam ) == BN_SETFOCUS
            VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
            _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
            RETURN 0
         ENDIF

      ENDIF

      // RadioGroup Notifications
      i := AScan ( _HMG_aControlHandles , { | x | iif ( hb_isArray ( x ), AScan ( x, lParam, , , .T. ) <> 0 , .F. ) } )

      IF i > 0 .AND. _HMG_aControlType [i] == "RADIOGROUP"

         IF HiWord( wParam ) == BN_CLICKED

            IF _HMG_aControlValue [i] != ( z := _GetValue ( , , i ) ) .OR. ! _HMG_ProgrammaticChange
               _HMG_aControlValue [i] := z
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
            ENDIF

            IF _HMG_aControlPicture [i] == .F. // No TabStop flag
               IF IsTabStop( lParam )
                  SetTabStop( lParam , .F. )
               ENDIF
            ENDIF
            RETURN 0

         ELSEIF HiWord( wParam ) == BN_KILLFOCUS .AND. _HMG_ProceedEachRadioButtonEvent

            _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
            RETURN 0

         ELSEIF HiWord( wParam ) == BN_SETFOCUS

            VirtualChildControlFocusProcess ( lParam , _HMG_aControlParentHandles [i] )

            IF _HMG_ProceedEachRadioButtonEvent
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
            ELSEIF nLastRadioGroupFocusedIndex <> i
               IF nLastRadioGroupFocusedIndex <> 0
                  _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [nLastRadioGroupFocusedIndex] , nLastRadioGroupFocusedIndex )
               ENDIF
               nLastRadioGroupFocusedIndex := i
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
            ENDIF

            IF _HMG_aControlPicture [i] == .F.
               IF IsTabStop( lParam )
                  SetTabStop( lParam , .F. )
               ENDIF
            ENDIF
            RETURN 0

         ENDIF

      ENDIF

      IF _HMG_ProceedEachRadioButtonEvent == .F. .AND. nLastRadioGroupFocusedIndex > 0 .AND. GetEscapeState() >= 0
         _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [nLastRadioGroupFocusedIndex] , nLastRadioGroupFocusedIndex )
         nLastRadioGroupFocusedIndex := 0
      ENDIF

      // Enter key (VK_RETURN) handling across active controls
#ifdef _TSBROWSE_
      oGet := GetObjectByHandle( GetFocus() )
      IF ISOBJECT( oGet )
         r := oGet:HandleEvent ( nMsg, wParam, lParam )
         IF ValType( r ) == 'N'
            IF r != 0
               RETURN r
            ENDIF
         ENDIF
      ENDIF
#endif

      i := AScan ( _HMG_aControlHandles , GetFocus() )

      IF i > 0

         IF _HMG_aControlType [i] == "CHECKBOX" .AND. HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1
            _HMG_SetFocusExecuted := .F.
            IF Empty( _HMG_aControlMiscData1 [i] )
               _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            ENDIF
            IF _HMG_SetFocusExecuted == .F.
               IF _HMG_ExtendedNavigation == .T.
                  _SetNextFocus()
               ENDIF
            ELSE
               _HMG_SetFocusExecuted := .F.
            ENDIF
            RETURN 0
         ENDIF

         IF _HMG_aControlType [i] == "OBUTTON" .AND. HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            RETURN 0
         ENDIF

         IF ( _HMG_aControlType [i] == "DATEPICK" .OR. _HMG_aControlType [i] == "TIMEPICK" ) .AND. ;
            ( HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1 )
            _HMG_SetFocusExecuted := .F.
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
            IF _HMG_SetFocusExecuted == .F.
               IF _HMG_ExtendedNavigation == .T.
                  _SetNextFocus()
               ENDIF
            ELSE
               _HMG_SetFocusExecuted := .F.
            ENDIF
            RETURN 0
         ENDIF

#ifdef _DBFBROWSE_
         IF _HMG_aControlType [i] == "BROWSE" .AND. lParam == 0 .AND. wParam == 2
            RETURN 1
         ENDIF

         IF _HMG_aControlType [i] == "BROWSE" .AND. lParam == 0 .AND. wParam == 1
            IF _hmg_acontrolmiscdata1 [i] [6] == .T.
               IF _HMG_aControlFontColor [i] == .T.
                  ProcessInPlaceKbdEdit ( i )
               ELSE
                  _BrowseEdit ( _hmg_acontrolhandles [i] , _HMG_acontrolmiscdata1 [i] [4] , _HMG_acontrolmiscdata1 [i] [5] , _HMG_acontrolmiscdata1 [i] [3] , _HMG_aControlInputMask [i] , .F. , _HMG_aControlFontColor [i] )
               ENDIF
            ELSE
               _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
            ENDIF
            RETURN 1
         ENDIF
#endif
         IF ( _HMG_aControlType [i] == "GRID" .OR. _HMG_aControlType [i] == "MULTIGRID" ) .AND. lParam == 0 .AND. wParam == 1

            IF _hmg_acontrolspacing [i] == .T.
               IF _HMG_aControlMiscData1 [i] [20] == .T. .OR. _HMG_aControlFontColor [i] == .T.
                  IF _HMG_aControlFontColor [i] == .F.
                     _GridInplaceKBDEdit ( i )
                  ELSE
                     _GridInplaceKBDEdit_2 ( i )
                  ENDIF
               ELSE
                  _EditItem ( _hmg_acontrolhandles [i] )
               ENDIF
            ELSE
               _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
            ENDIF
            RETURN 0

         ENDIF

         IF _HMG_aControlType [i] == "COMBO" .AND. HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1

            _HMG_SetFocusExecuted := .F.
            _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
            IF _HMG_SetFocusExecuted == .F.
               IF _HMG_ExtendedNavigation == .T.
                  _SetNextFocus()
               ENDIF
            ELSE
               _HMG_SetFocusExecuted := .F.
            ENDIF
            RETURN 0

         ENDIF

         IF ( _HMG_aControlType [i] == "LIST" .OR. _HMG_aControlType [i] == "MULTILIST" ) .AND. ;
            ( HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1 )
            _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
            RETURN 0
         ENDIF

         IF "TEXT" $ _HMG_aControlType [i] .AND. HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1

            IF _HMG_aControlType [i] == "BTNTEXT" .OR. _HMG_aControlType [i] == "BTNNUMTEXT"
               IF _HMG_aControlMiscData1 [i][4]
                  _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
                  RETURN 0
               ENDIF
            ENDIF
            _HMG_SetFocusExecuted := .F.
            _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
            IF _HMG_SetFocusExecuted == .F.
               IF _HMG_ExtendedNavigation == .T.
                  _SetNextFocus()
               ENDIF
            ELSE
               _HMG_SetFocusExecuted := .F.
            ENDIF
            RETURN 0

         ENDIF

         IF _HMG_aControlType [i] == "TREE" .AND. HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1
            _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
            RETURN 0
         ENDIF

      ELSE

         ControlCount := Len ( _HMG_aControlHandles )

         FOR i := 1 TO ControlCount
            IF _HMG_aControlType [i] == "COMBO" .AND. HiWord( wParam ) == 0 .AND. LoWord( wParam ) == 1
               IF _hmg_acontrolrangemin [i] == GetFocus() .OR. _hmg_acontrolrangemax [i] == GetFocus()
                  _HMG_SetFocusExecuted := .F.
                  _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
                  IF _HMG_SetFocusExecuted == .F.
                     IF _HMG_ExtendedNavigation == .T.
                        _SetNextFocus()
                     ENDIF
                  ELSE
                     _HMG_SetFocusExecuted := .F.
                  ENDIF
                  EXIT
               ENDIF
            ENDIF
         NEXT i

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_NOTIFY
   ****************************************************************************
      // Common Control Notification Handler (Grids, ListViews, Toolbars, TreeViews, MonthCal)
      IF _HMG_ProceedEachRadioButtonEvent == .F. .AND. nLastRadioGroupFocusedIndex > 0 .AND. GetNotifyCode ( lParam ) == NM_SETFOCUS
         _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [nLastRadioGroupFocusedIndex] , nLastRadioGroupFocusedIndex )
         nLastRadioGroupFocusedIndex := 0
      ENDIF

#ifdef _HMG_COMPAT_
      IF GetNotifyCode ( lParam ) == NM_CUSTOMDRAW

         i := AScan ( _HMG_aControlInputMask, GetHwndFrom ( lParam ) )

         IF i > 0 .AND. "GRID" $ _HMG_aControlType [i]
            r := Header_CustomDraw_GetAction ( lParam )
            IF r <> -1
               RETURN r
            ENDIF
            RETURN DoHeaderCustomDraw ( i , lParam , Header_CustomDraw_GetItem ( lParam ) + 1 )
         ENDIF

      ENDIF
#endif
      // Grid Column Width Resizing / Tracking
      IF "GRID" $ _GetFocusedControlType ( hWnd )

         x := GetFocus()
         i := AScan ( _HMG_aControlHandles, x )
#ifdef UNICODE
         IF i > 0 .AND. ! ISBLOCK ( _HMG_aControlProcedures [i] )
#else
         IF i > 0
#endif
            IF GetHwndFrom ( lParam ) == ListView_GetHeader ( x )

               IF GetNotifyCode ( lParam ) == HDN_ITEMCHANGING
                  k := GetHeaderListViewItemCX ( lParam )
                  IF k >= 0
                     z := GetHeaderListViewItem ( lParam ) + 1
                     aCellData := _HMG_aControlMiscData1 [i] [ 25 ]
                     IF ISARRAY( aCellData ) .AND. z <= Len( aCellData ) .AND. ISARRAY( aCellData [z] )
                        NewHPos := aCellData [z] [1]
                        NewVPos := aCellData [z] [2]

                        IF k < NewHPos
                           ListView_SetColumnWidth ( x, z - 1, NewHPos )
                           RETURN 1
                        ELSEIF k > NewVPos
                           ListView_SetColumnWidth ( x, z - 1, NewVPos )
                           RETURN 1
                        ENDIF
                     ENDIF
                  ENDIF
                  RETURN 0
               ELSEIF GetNotifyCode ( lParam ) == HDN_ITEMCHANGED
                  _DoControlEventProcedure ( _HMG_aControlMiscData1 [i] [ 26 ] , i )
                  RETURN 0
               ENDIF

            ENDIF

         ENDIF

      ENDIF

      // ToolBar ToolTip Request
      IF GetNotifyCode ( lParam ) == TTN_NEEDTEXT .AND. IsToolTipActive

         x := AScan ( _HMG_aControlIds, GetNotifyId ( lParam ) )

         IF x > 0 .AND. _HMG_aControlType [x] == "TOOLBUTTON"
            IF ISCHAR ( _HMG_aControlToolTip [x] )
               SetButtonTip ( lParam, _HMG_aControlToolTip [x] )
            ENDIF
            k := GetHwndFrom ( lParam )
#ifdef _HMG_COMPAT_
            IF GetFormNameByHandle ( _HMG_aControlParentHandles [x], @z ) > 0 .AND. ISARRAY( a := _WindowCargo ( z ) ) .AND. ;
               Len ( a ) == 2 .AND. ISCHAR ( a [2] ) .AND. ! Empty ( a [2] )

               SendMessageString ( k, TTM_SETTITLE, a [1], a [2] )
            ENDIF
#endif
            IF IsToolTipBalloonActive
               IF ! ( And ( GetWindowLong ( k, GWL_STYLE ), TTS_BALLOON ) == TTS_BALLOON )
                  SetWindowStyle ( k, TTS_BALLOON, .T. )
               ENDIF
            ENDIF
         ELSE
            a := GetMessagePos()
            k := WindowFromPoint ( { LoWord( a ), HiWord( a ) } )
            x := AScan( _HMG_aControlHandles, k )

            IF x > 0 .AND. _HMG_aControlType [x] == 'TAB'
               IF ValType ( _HMG_aControlTooltip [x] ) == 'A'
                  i := GetNotifyId ( lParam )
                  SetButtonTip ( lParam, _HMG_aControlTooltip [x, i + 1] )
               ELSE
                  SetButtonTip ( lParam, _HMG_aControlTooltip [x] )
               ENDIF
            ENDIF
         ENDIF

      ENDIF

      IF GetNotifyCode ( lParam ) == RBN_CHEVRONPUSHED
         _CreatePopUpChevron ( hWnd, wParam, lParam )
      ENDIF

#ifdef _TSBROWSE_
      oGet := GetObjectByHandle( GetHwndFrom ( lParam ) )
      IF ISOBJECT ( oGet )
         r := oGet:HandleEvent ( nMsg, wParam, lParam )
         IF ValType( r ) == 'N'
            IF r != 0
               RETURN r
            ENDIF
         ENDIF
      ENDIF
#endif

      i := AScan ( _HMG_aControlHandles , GetHwndFrom ( lParam ) )

      IF i > 0
#ifdef _PAGER_
         IF _HMG_aControlType [i] == "PAGER"
            IF GetNotifyCode ( lParam ) == PGN_CALCSIZE
               IF _HMG_aControlMiscData1 [i] == .T.
                  PagerCalcSize( lParam , _HMG_aControlHeight [i] )
               ELSE
                  PagerCalcSize( lParam , _HMG_aControlWidth [i] )
               ENDIF
            ENDIF
            IF GetNotifyCode ( lParam ) == PGN_SCROLL
               PagerScroll( lParam , _HMG_aControlSpacing [i] )
            ENDIF
         ENDIF
#endif

#ifdef _DBFBROWSE_
         IF _HMG_aControlType [i] == "BROWSE"

            IF GetNotifyCode ( lParam ) == NM_CUSTOMDRAW

               hws := 0
               hwm := .F.
               FOR EACH r IN _HMG_aControlProcedures [i]
                  x := hb_enumindex ( r )
                  hws += ( lvc := ListView_GetColumnWidth ( _HMG_aControlHandles [i] , x - 1 ) )
                  IF _HMG_aControlProcedures [i][x] != lvc
                     hwm := .T.
                     _HMG_aControlProcedures [i][x] := lvc
                     _BrowseRefresh ( '', '', i )
                  ENDIF
               NEXT

               IF _HMG_aControlIds [i] != 0 .AND. hwm == .T.
                  IF hws > _HMG_aControlWidth [i] - GETVSCROLLBARWIDTH() - 4
                     MoveWindow ( _HMG_aControlIds [i] , _HMG_aControlCol [i] + _HMG_aControlWidth [i] - GETVSCROLLBARWIDTH() , _HMG_aControlRow[i] , GETVSCROLLBARWIDTH() , ;
                        _HMG_aControlHeight [i] - GETHSCROLLBARHEIGHT() , .T. )
                     MoveWindow ( _HMG_aControlMiscData1 [i][1], _HMG_aControlCol [i] + _HMG_aControlWidth [i] - GETVSCROLLBARWIDTH() , _HMG_aControlRow [i] + _HMG_aControlHeight [i] - GETHSCROLLBARHEIGHT() , ;
                        GETVSCROLLBARWIDTH() , GETHSCROLLBARHEIGHT() , .T. )
                  ELSE
                     MoveWindow ( _HMG_aControlIds [i] , _HMG_aControlCol [i] + _HMG_aControlWidth [i] - GETVSCROLLBARWIDTH() , _HMG_aControlRow [i] , GETVSCROLLBARWIDTH() , _HMG_aControlHeight [i] , .T. )
                     MoveWindow ( _HMG_aControlMiscData1 [i][1] , _HMG_aControlCol [i] + _HMG_aControlWidth [i] - GETVSCROLLBARWIDTH() , _HMG_aControlRow [i] + _HMG_aControlHeight [i] - GETHSCROLLBARHEIGHT() , 0 , 0 , .T. )
                  ENDIF
               ENDIF

            ENDIF

            dBc := _HMG_aControlMiscData1 [i] [10]
            dFc := _HMG_aControlMiscData1 [i] [ 9]

            IF GetNotifyCode ( lParam ) == NM_CUSTOMDRAW .AND. ( ValType ( dBc ) == 'A' .OR. ValType ( dFc ) == 'A' )

               IF ( r := GetDs ( lParam ) ) <> -1
                  RETURN r
               ELSE
                  a := GetRc ( lParam )

                  IF a[1] >= 1 .AND. a[1] <= Len ( _HMG_aControlRangeMax [i] ) .AND. ;
                     a[2] >= 1 .AND. a[2] <= Len ( _HMG_aControlRangeMin [i] )

                     aTemp  := _HMG_aControlMiscData1 [i] [18]
                     aTemp2 := _HMG_aControlMiscData1 [i] [17]

                     IF ValType ( aTemp ) == 'A' .AND. ValType ( aTemp2 ) <> 'A'
                        IF Len ( aTemp ) >= a[1]
                           IF aTemp [a[1]] [a[2]] <> -1
                              RETURN SetBcFc ( lParam , aTemp [a[1]] [a[2]] , RGB( 0, 0, 0 ) )
                           ELSE
                              RETURN SETBRCCD( lParam )
                           ENDIF
                        ENDIF
                     ELSEIF ValType ( aTemp ) <> 'A' .AND. ValType ( aTemp2 ) == 'A'
                        IF Len ( aTemp2 ) >= a[1]
                           IF aTemp2 [a[1]] [a[2]] <> -1
                              RETURN SetBcFc ( lParam , RGB( 255, 255, 255 ) , aTemp2 [a[1]] [a[2]] )
                           ELSE
                              RETURN SETBRCCD( lParam )
                           ENDIF
                        ENDIF
                     ELSEIF ValType ( aTemp ) == 'A' .AND. ValType ( aTemp2 ) == 'A'
                        IF Len ( aTemp ) >= a[1] .AND. Len ( aTemp2 ) >= a[1]
                           IF aTemp [a[1]] [a[2]] <> -1
                              RETURN SetBcFc ( lParam , aTemp [a[1]] [a[2]] , aTemp2 [a[1]] [a[2]] )
                           ELSE
                              RETURN SETBRCCD( lParam )
                           ENDIF
                        ENDIF
                     ENDIF
                  ELSE
                     RETURN SETBRCCD( lParam )
                  ENDIF
               ENDIF

            ENDIF

            IF GetNotifyCode ( lParam ) == NM_CLICK .OR. GetNotifyCode ( lParam ) == LVN_BEGINDRAG .OR. ;
               GetNotifyCode ( lParam ) == NM_RCLICK

               IF ( r := LISTVIEW_GETFIRSTITEM ( _HMG_aControlHandles [i] ) ) > 0
                  DeltaSelect := r - AScan ( _HMG_aControlRangeMax [i] , _HMG_aControlValue [i] )
                  nr := _HMG_aControlValue [i]
                  _HMG_aControlValue [i] := _HMG_aControlRangeMax [i] [r]
                  _BrowseVscrollFastUpdate ( i , DeltaSelect )
                  IF nr != _HMG_aControlValue [i] .OR. _HMG_BrowseUpdateStatus
                     _BrowseOnChange ( i )
                  ENDIF
               ENDIF
               RETURN 0

            ENDIF

            IF GetNotifyCode ( lParam ) == LVN_KEYDOWN

               DO CASE
               CASE GetGridvKey( lParam ) == 65 .AND. ;
                  IsAltActive() .AND. GetKeyState( VK_CONTROL ) >= 0 .AND. GetKeyState( VK_SHIFT ) >= 0

                  IF _HMG_aControlMiscData1 [i] [2] == .T.
                     _BrowseEdit ( _hmg_acontrolhandles [i] , _HMG_acontrolmiscdata1 [i] [4] , _HMG_acontrolmiscdata1 [i] [5] , ;
                        _HMG_acontrolmiscdata1 [i] [3] , _HMG_aControlInputMask [i] , .T. , _HMG_aControlFontColor [i] , _HMG_acontrolmiscdata1 [i] [13] )
                  ENDIF
               CASE GetGridvKey( lParam ) == 46 // DEL
                  IF _HMG_aControlMiscData1 [i] [12] == .T.
                     IF MsgYesNo ( _HMG_BRWLangMessage [1] , _HMG_BRWLangMessage [2] )
                        _BrowseDelete( '', '', i )
                     ENDIF
                  ENDIF
               CASE GetGridvKey( lParam ) == 36 // HOME
                  _BrowseHome( '', '', i )
                  RETURN 1
               CASE GetGridvKey( lParam ) == 35 // END
                  _BrowseEnd( '', '', i )
                  RETURN 1
               CASE GetGridvKey( lParam ) == 33 // PGUP
                  _BrowsePrior( '', '', i )
                  RETURN 1
               CASE GetGridvKey( lParam ) == 34 // PGDN
                  _BrowseNext( '', '', i )
                  RETURN 1
               CASE GetGridvKey( lParam ) == 38 // UP
                  _BrowseUp( '', '', i )
                  RETURN 1
               CASE GetGridvKey( lParam ) == 40 // DOWN
                  _BrowseDown( '', '', i )
                  RETURN 1
               ENDCASE
               RETURN 0

            ENDIF

            IF GetNotifyCode ( lParam ) == NM_DBLCLK

               _PushEventInfo()
               _HMG_ThisFormIndex := AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] )
               _HMG_ThisType := 'C'
               _HMG_ThisIndex := i
               _HMG_ThisFormName :=  _HMG_aFormNames [ _HMG_ThisFormIndex ]
               _HMG_ThisControlName := _HMG_aControlNames [_HMG_THISIndex ]
               r := ListView_HitTest ( _HMG_aControlHandles [i] , GetCursorRow() - GetWindowRow ( _HMG_aControlHandles [i] ) , GetCursorCol() - GetWindowCol ( _HMG_aControlHandles [i] ) )
               IF r [2] == 1
                  ListView_Scroll( _HMG_aControlHandles [i] , -10000 , 0 )
                  r := ListView_HitTest ( _HMG_aControlHandles [i] , GetCursorRow() - GetWindowRow ( _HMG_aControlHandles [i] ) , GetCursorCol() - GetWindowCol ( _HMG_aControlHandles [i] ) )
               ELSE
                  r := LISTVIEW_GETSUBITEMRECT ( _HMG_aControlHandles [i] , r [1] - 1 , r [2] - 1 )
                  xs := ( _HMG_aControlCol [i] + r [2] + r [3] ) - ( _HMG_aControlCol [i] + _HMG_aControlWidth [i] )
                  xd := 20
                  IF xs > - xd
                     ListView_Scroll( _HMG_aControlHandles [i] , xs + xd , 0 )
                  ELSE
                     IF r [2] < 0
                        ListView_Scroll( _HMG_aControlHandles [i] , r[2] , 0 )
                     ENDIF
                  ENDIF
                  r := ListView_HitTest ( _HMG_aControlHandles [i] , GetCursorRow() - GetWindowRow ( _HMG_aControlHandles [i] ) , GetCursorCol() - GetWindowCol ( _HMG_aControlHandles [i] ) )
               ENDIF

               _HMG_ThisItemRowIndex := r [1]
               _HMG_ThisItemColIndex := r [2]
               IF r [2] == 1
                  r := LISTVIEW_GETITEMRECT ( _HMG_aControlHandles [i] , r [1] - 1 )
               ELSE
                  r := LISTVIEW_GETSUBITEMRECT ( _HMG_aControlHandles [i] , r [1] - 1 , r [2] - 1 )
               ENDIF
               _HMG_ThisItemCellRow := _HMG_aControlRow [i] + r [1]
               _HMG_ThisItemCellCol := _HMG_aControlCol [i] + r [2]
               _HMG_ThisItemCellWidth  := r [3]
               _HMG_ThisItemCellHeight := r [4]

               IF _hmg_acontrolmiscdata1 [i] [6] == .T.
                  _BrowseEdit ( _hmg_acontrolhandles [i] , _HMG_acontrolmiscdata1 [i] [4] , _HMG_acontrolmiscdata1 [i] [5] , ;
                     _HMG_acontrolmiscdata1 [i] [3] , _HMG_aControlInputMask [i] , .F. , _HMG_aControlFontColor [i] , _HMG_acontrolmiscdata1 [i] [13] )
               ELSE
                  IF ISBLOCK( _HMG_aControlDblClick [i] )
                     Eval ( _HMG_aControlDblClick [i] )
                  ENDIF
               ENDIF

               _PopEventInfo()
               _HMG_ThisItemRowIndex := 0
               _HMG_ThisItemColIndex := 0
               _HMG_ThisItemCellRow := 0
               _HMG_ThisItemCellCol := 0
               _HMG_ThisItemCellWidth := 0
               _HMG_ThisItemCellHeight := 0

            ENDIF

            IF GetNotifyCode ( lParam ) == NM_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_SETFOCUS
               VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == LVN_COLUMNCLICK
               IF ValType ( _HMG_aControlHeadClick [i] ) == 'A'
                  lvc := GetGridColumn( lParam ) + 1
                  IF Len ( _HMG_aControlHeadClick [i] ) >= lvc
                     _DoControlEventProcedure ( _HMG_aControlHeadClick [i] [lvc] , i , , lvc )
                  ENDIF
               ENDIF
               RETURN 0
            ENDIF

         ENDIF
#endif
         // ToolBar DropDown Button Click Notifications
         IF GetNotifyCode ( lParam ) == TBN_DROPDOWN

            DefWindowProc( hWnd, TBN_DROPDOWN, wParam, lParam )

            x := AScan ( _HMG_aControlIds , GetButtonPos( lParam ) )

            IF x > 0 .AND. _HMG_aControlType [x] == "TOOLBUTTON"
               aPos := { 0, 0, 0, 0 }
               GetWindowRect ( _HMG_aControlHandles [i] , aPos )

               r := GetButtonBarRect ( _HMG_aControlHandles [i] , _HMG_aControlValue [x] - 1 )

               k := AScan ( _HMG_aControlHandles , _HMG_aControlParentHandles [i] )

               IF _HMG_ActiveSplitBoxInverted .OR. ;
                  ( k > 0 .AND. _HMG_aControlType [k] == "PAGER" .AND. _HMG_aControlMiscData1 [k] == .T. )
                  TrackPopupMenu ( _HMG_aControlRangeMax [x] , aPos [1] + LoWord( r ) , aPos [2] + HiWord( r ), hWnd )
               ELSE
                  TrackPopupMenu ( _HMG_aControlRangeMax [x] , aPos [1] + LoWord( r ) , aPos [2] + HiWord( r ) + ( aPos [4] - aPos [2] - HiWord( r ) ) / 2 , hWnd )
               ENDIF
            ENDIF
            RETURN 0

         ENDIF

         // RichEdit Selection / Drag-Drop / Link Notifications
         IF _HMG_aControlType [i] == "RICHEDIT" .AND. _HMG_aControlMiscData1 [i] == 0

            IF GetNotifyCode ( lParam ) == EN_MSGFILTER
               IF ISBLOCK( _HMG_aControlChangeProcedure [i] )
                  _HMG_ThisType := 'C'
                  _HMG_ThisIndex := i
                  Eval( _HMG_aControlChangeProcedure [i] )
                  _HMG_ThisIndex := 0
                  _HMG_ThisType := ''
                  RETURN 0
               ENDIF
            ENDIF

            IF GetNotifyCode ( lParam ) == EN_DRAGDROPDONE
               IF ISBLOCK( _HMG_aControlChangeProcedure [i] )
                  _HMG_ThisType := 'C'
                  _HMG_ThisIndex := i
                  Eval( _HMG_aControlChangeProcedure [i] )
                  _HMG_ThisIndex := 0
                  _HMG_ThisType := ''
                  RETURN 0
               ENDIF
            ENDIF

            IF GetNotifyCode ( lParam ) == EN_SELCHANGE
               IF ISBLOCK( _HMG_aControlDblClick [i] )
                  _HMG_ThisType := 'C'
                  _HMG_ThisIndex := i
                  Eval( _HMG_aControlDblClick [i] )
                  _HMG_ThisIndex := 0
                  _HMG_ThisType := ''
                  RETURN 0
               ENDIF
            ENDIF

         ENDIF

         // MonthCalendar Notifications
         IF _HMG_aControlType [i] == "MONTHCAL"
#ifndef __XHARBOUR__
            Tmp := ( hb_Version( HB_VERSION_BITWIDTH ) >= 64 )
#else
            Tmp := IsExe64()
#endif
            IF GetNotifyCode ( lParam ) == MCN_SELECT
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )

               IF Tmp
                  SetDayState ( _HMG_aControlNames [i] , GetParentFormName( i ) )
               ENDIF
               RETURN 0

            ELSEIF GetNotifyCode ( lParam ) == MCN_SELCHANGE
               _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i , 'CONTROL_ONCHANGE' )

               IF Tmp
                  SetDayState ( _HMG_aControlNames [i] , GetParentFormName( i ) )
               ENDIF
               RETURN 0

            ELSEIF GetNotifyCode ( lParam ) == MCN_GETDAYSTATE
               RetDayState ( i , lParam )
               RETURN 0
            ENDIF
         ENDIF

         // Grid Control Processing (Navigation, Keyboard, Custom Draw, QueryData)
         IF _HMG_aControlType [i] $ "MULTIGRID"

            IF _HMG_aControlFontColor [i] == .T.

               // Keyboard arrow navigation handling for cell-based navigation
               IF GetNotifyCode ( lParam ) == LVN_KEYDOWN

                  SWITCH GetGridvKey( lParam )
                  CASE 37 // LEFT
                     IF _HMG_aControlMiscData1 [i] [ 17 ] > 1
                        _HMG_aControlMiscData1 [i] [ 17 ] --

                        nFrozenColumnCount := _HMG_aControlMiscData1 [i] [ 19 ]
                        IF nFrozenColumnCount > 0
                           nDestinationColumn := _HMG_aControlMiscData1 [i] [ 17 ]
                           IF nDestinationColumn >= nFrozenColumnCount + 1
                              aOriginalColumnWidths := _HMG_aControlMiscData1 [i] [ 2 ]
                              LISTVIEW_SETCOLUMNWIDTH ( _HMG_aControlHandles [i] , nDestinationColumn - 1 , aOriginalColumnWidths [ nDestinationColumn ] )
                           ENDIF
                        ENDIF

                        _GRID_KBDSCROLL( i )

                        LISTVIEW_REDRAWITEMS ( _HMG_aControlHandles [i] , _HMG_aControlMiscData1 [i] [ 1 ] - 1 , _HMG_aControlMiscData1 [i] [ 1 ] - 1 )
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 39 // RIGHT
                     IF _HMG_aControlMiscData1 [i] [ 17 ] < Len ( _HMG_aControlCaption [i] )
                        _HMG_aControlMiscData1 [i] [ 17 ] ++

                        nFrozenColumnCount := _HMG_aControlMiscData1 [i] [ 19 ]
                        IF nFrozenColumnCount > 0
                           nDestinationColumn := _HMG_aControlMiscData1 [i] [ 17 ]
                           FOR k := nDestinationColumn TO Len( _HMG_aControlCaption [ i ] ) - 1
                              IF LISTVIEW_GETCOLUMNWIDTH ( _HMG_aControlHandles [i] , k - 1 ) == 0
                                 _HMG_aControlMiscData1 [i] [ 17 ] ++
                              ENDIF
                           NEXT k

                           IF nDestinationColumn > nFrozenColumnCount + 1
                              LISTVIEW_SETCOLUMNWIDTH ( _HMG_aControlHandles [i] , nDestinationColumn - 2 , 0 )
                           ENDIF
                        ENDIF

                        _GRID_KBDSCROLL( i )

                        LISTVIEW_REDRAWITEMS ( _HMG_aControlHandles [i] , _HMG_aControlMiscData1 [i] [ 1 ] - 1 , _HMG_aControlMiscData1 [i] [ 1 ] - 1 )
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 38 // UP
                     IF _HMG_aControlMiscData1 [i] [ 17 ] == 0
                        _HMG_aControlMiscData1 [i] [ 17 ] := 1
                     ENDIF
                     IF _HMG_aControlMiscData1 [i] [ 1 ] > 1
                        _HMG_aControlMiscData1 [i] [ 1 ] --
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 40 // DOWN
                     IF _HMG_aControlMiscData1 [i] [ 17 ] == 0
                        _HMG_aControlMiscData1 [i] [ 17 ] := 1
                     ENDIF
                     IF _HMG_aControlMiscData1 [i] [ 1 ] < SendMessage( _HMG_aControlHandles [i] , LVM_GETITEMCOUNT , 0 , 0 )
                        _HMG_aControlMiscData1 [i] [ 1 ] ++
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 33 // PGUP
                     nGridRowValue := _HMG_aControlMiscData1 [i] [ 1 ]

                     IF _HMG_aControlMiscData1 [i] [ 1 ] == SendMessage ( _HMG_aControlHandles [i] , LVM_GETTOPINDEX , 0 , 0 ) + 1
                        _HMG_aControlMiscData1 [i] [ 1 ] -= SendMessage ( _HMG_aControlHandles [i] , LVM_GETCOUNTPERPAGE , 0 , 0 ) - 1
                     ELSE
                        _HMG_aControlMiscData1 [i] [ 1 ] := SendMessage ( _HMG_aControlHandles [i] , LVM_GETTOPINDEX , 0 , 0 ) + 1
                     ENDIF

                     IF _HMG_aControlMiscData1 [i] [ 1 ] < 1
                        _HMG_aControlMiscData1 [i] [ 1 ] := 1
                     ENDIF

                     IF nGridRowValue <> _HMG_aControlMiscData1 [i] [ 1 ]
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 34 // PGDOWN
                     nGridRowValue := _HMG_aControlMiscData1 [i] [ 1 ]

                     IF _HMG_aControlMiscData1 [i] [ 1 ] == SendMessage ( _HMG_aControlHandles [i] , LVM_GETTOPINDEX , 0 , 0 ) + SendMessage ( _HMG_aControlHandles [i] , LVM_GETCOUNTPERPAGE , 0 , 0 )
                        _HMG_aControlMiscData1 [i] [ 1 ] += SendMessage ( _HMG_aControlHandles [i] , LVM_GETCOUNTPERPAGE , 0 , 0 ) - 1
                     ELSE
                        _HMG_aControlMiscData1 [i] [ 1 ] := SendMessage ( _HMG_aControlHandles [i] , LVM_GETTOPINDEX , 0 , 0 ) + SendMessage ( _HMG_aControlHandles [i] , LVM_GETCOUNTPERPAGE , 0 , 0 )
                     ENDIF

                     IF _HMG_aControlMiscData1 [i] [ 1 ] > SendMessage( _HMG_aControlHandles [i] , LVM_GETITEMCOUNT , 0 , 0 )
                        _HMG_aControlMiscData1 [i] [ 1 ] := SendMessage( _HMG_aControlHandles [i] , LVM_GETITEMCOUNT , 0 , 0 )
                     ENDIF

                     IF nGridRowValue <> _HMG_aControlMiscData1 [i] [ 1 ]
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 35 // END
                     nGridRowValue := _HMG_aControlMiscData1 [i] [ 1 ]

                     _HMG_aControlMiscData1 [i] [ 1 ] := SendMessage( _HMG_aControlHandles [i] , LVM_GETITEMCOUNT , 0 , 0 )

                     IF nGridRowValue <> _HMG_aControlMiscData1 [i] [ 1 ]
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  CASE 36 // HOME
                     nGridRowValue := _HMG_aControlMiscData1 [i] [ 1 ]

                     _HMG_aControlMiscData1 [i] [ 1 ] := 1

                     IF nGridRowValue <> _HMG_aControlMiscData1 [i] [ 1 ]
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                     EXIT
                  DEFAULT
                     RETURN 1
                  END SWITCH

               ENDIF

            ENDIF

            // Custom draw grid cell highlighting based on selection
            IF GetNotifyCode ( lParam ) == NM_CUSTOMDRAW

               IF ( r := iif( _HMG_aControlFontColor [i] == .T. , ;
                     GetDs ( lParam , _HMG_aControlHandles [i] , _HMG_aControlMiscData1 [i] [ 1 ] - 1 ), ;
                     GetDs ( lParam ) ) ) <> -1

                  RETURN r

               ELSE

                  a := GetRc ( lParam )
                  IF _HMG_aControlFontColor [i] == .T.
                     IF a[1] == _HMG_aControlMiscData1 [i][ 1 ] .AND. a[2] == _HMG_aControlMiscData1 [i][ 17 ]
                        RETURN SetBcFc ( lParam , RGB( _HMG_GridSelectedCellBackColor[1] , _HMG_GridSelectedCellBackColor[2] , _HMG_GridSelectedCellBackColor[3] ) , RGB( _HMG_GridSelectedCellForeColor[1] , _HMG_GridSelectedCellForeColor[2] , _HMG_GridSelectedCellForeColor[3] ) )
                     ELSEIF a[1] == _HMG_aControlMiscData1 [i][ 1 ] .AND. a[2] <> _HMG_aControlMiscData1 [i][ 17 ]
                        RETURN SetBcFc ( lParam , RGB( _HMG_GridSelectedRowBackColor[1] , _HMG_GridSelectedRowBackColor[2] , _HMG_GridSelectedRowBackColor[3] ) , RGB( _HMG_GridSelectedRowForeColor[1] , _HMG_GridSelectedRowForeColor[2] , _HMG_GridSelectedRowForeColor[3] ) )
                     ELSE
                        RETURN _DoGridCustomDraw ( i , a , lParam )
                     ENDIF
                  ELSE
                     RETURN _DoGridCustomDraw ( i , a , lParam )
                  ENDIF

               ENDIF

            ENDIF

            IF GetNotifyCode ( lParam ) == -181
               ReDrawWindow ( _hmg_acontrolhandles [i] )
            ENDIF

            // Virtual Grid ON QUERYDATA callback handling
            IF GetNotifyCode ( lParam ) == LVN_GETDISPINFO

               IF ISBLOCK ( _HMG_aControlProcedures [i] )

                  _PushEventInfo()
                  _HMG_ThisFormIndex := AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] )
                  _HMG_ThisType  := 'C'
                  _HMG_ThisIndex := i
                  _HMG_ThisFormName := _HMG_aFormNames [ _HMG_ThisFormIndex ]
                  _HMG_ThisControlName := _HMG_aControlNames [ _HMG_ThisIndex ]

                  aPos := GETGRIDDISPINFOINDEX ( lParam )
                  _HMG_ThisQueryRowIndex := aPos [1]
                  _HMG_ThisQueryColIndex := aPos [2]

                  Eval ( _HMG_aControlProcedures [i] )

                  IF Len ( _HMG_aControlBkColor [i] ) > 0 .AND. _HMG_ThisQueryColIndex == 1
                     SetGridQueryImage ( lParam , _HMG_ThisQueryData )
                  ELSE
                     SetGridQueryData ( lParam , hb_ValToStr( _HMG_ThisQueryData ) )
                  ENDIF

                  _HMG_ThisQueryRowIndex := 0
                  _HMG_ThisQueryColIndex := 0
                  _HMG_ThisQueryData := ""
                  _PopEventInfo()

                  RETURN 0

               ENDIF

            ENDIF

            IF GetNotifyCode ( lParam ) == NM_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_SETFOCUS
               VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == LVN_KEYDOWN .AND. GetGridvKey ( lParam ) == 32
               SpaceKeyIsPressedInGrid := _HMG_aControlHandles [i]
            ENDIF

            IF GetNotifyCode ( lParam ) == LVN_ITEMCHANGED

               #define LVIS_UNCHECKED 0x1000
               #define LVIS_CHECKED   0x2000
               IF GetGridNewState( lParam ) == LVIS_UNCHECKED .OR. GetGridNewState( lParam ) == LVIS_CHECKED

                  aCellData := _GetGridCellData ( i )
                  r := aCellData [1]

                  IF r > 0 .AND. r <= ListViewGetItemCount ( _HMG_aControlHandles [i] ) .OR. SpaceKeyIsPressedInGrid == _HMG_aControlHandles [i]
                     _DoControlEventProcedure ( _HMG_aControlMiscData1 [i] [23] , i , 'CONTROL_ONCHANGE' , SpaceKeyIsPressedInGrid , r )
                     SpaceKeyIsPressedInGrid := 0
                     RETURN 0
                  ENDIF

               ENDIF

               IF _HMG_aControlMiscData1 [i, 10] == .T.

                  IF GetGridNewState( lParam ) != 0
                     _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                     RETURN 0
                  ENDIF

               ELSEIF GetGridOldState( lParam ) == 0 .AND. GetGridNewState( lParam ) != 0

                  IF _HMG_aControlFontColor [i] == .T.
                     lCellGridRowChanged := .T.
                     _HMG_aControlMiscData1 [i] [ 1 ] := LISTVIEW_GETFIRSTITEM ( _HMG_aControlHandles [i] )
                  ELSE
                     _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                  ENDIF

                  RETURN 0

               ENDIF

            ENDIF

            IF GetNotifyCode ( lParam ) == LVN_COLUMNCLICK

               IF ValType ( _HMG_aControlHeadClick [i] ) == 'A'
                  lvc := GetGridColumn( lParam ) + 1
                  IF Len ( _HMG_aControlHeadClick [i] ) >= lvc
                     _DoControlEventProcedure ( _HMG_aControlHeadClick [i] [lvc] , i , , lvc )
                     RETURN 0
                  ENDIF
               ENDIF

            ENDIF

            IF GetNotifyCode ( lParam ) == NM_CLICK

               IF _HMG_aControlFontColor [i] == .T.

                  aCellData := _GetGridCellData ( i )

                  IF ( NewPos := aCellData [2] ) > 0
                     x := _HMG_aControlMiscData1 [i] [ 17 ]
                     _HMG_aControlMiscData1 [i] [ 17 ] := NewPos

                     IF ( nGridRowValue := _HMG_aControlMiscData1 [i] [ 1 ] ) == 0
                        _HMG_aControlMiscData1 [i] [ 1 ] := aCellData [1]
                     ENDIF

                     IF lCellGridRowChanged .OR. x != NewPos
                        lCellGridRowChanged := .F.
                        LISTVIEW_REDRAWITEMS ( _HMG_aControlHandles [i] , nGridRowValue - 1 , nGridRowValue - 1 )
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
                     ENDIF
                  ENDIF

               ENDIF

               RETURN 0

            ENDIF

            // Inplace cell editing or double click callback activation
            IF GetNotifyCode ( lParam ) == NM_DBLCLK

               IF _HMG_aControlSpacing [i] == .T.

                  IF _HMG_aControlMiscData1 [i] [20] == .T. .OR. _HMG_aControlFontColor [i] == .T.

                     _PushEventInfo()
                     _HMG_ThisFormIndex := AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] )
                     _HMG_ThisType := 'C'
                     _HMG_ThisIndex := i
                     _HMG_ThisFormName := _HMG_aFormNames [ _HMG_ThisFormIndex ]
                     _HMG_ThisControlName := _HMG_aControlNames [ _HMG_ThisIndex ]

                     aCellData := _GetGridCellData ( i )

                     _HMG_ThisItemRowIndex   := aCellData [1]
                     _HMG_ThisItemColIndex   := aCellData [2]
                     _HMG_ThisItemCellRow    := aCellData [3]
                     _HMG_ThisItemCellCol    := aCellData [4]
                     _HMG_ThisItemCellWidth  := aCellData [5]
                     _HMG_ThisItemCellHeight := aCellData [6]

                     _GridInplaceEdit ( i )

                     _PopEventInfo()
                     _HMG_ThisItemRowIndex   := 0
                     _HMG_ThisItemColIndex   := 0
                     _HMG_ThisItemCellRow    := 0
                     _HMG_ThisItemCellCol    := 0
                     _HMG_ThisItemCellWidth  := 0
                     _HMG_ThisItemCellHeight := 0

                  ELSE

                     _EditItem ( _hmg_acontrolhandles [i] )

                  ENDIF

               ELSE

                  IF ISBLOCK( _HMG_aControlDblClick [i] )

                     _PushEventInfo()
                     _HMG_ThisFormIndex := AScan ( _HMG_aFormHandles , _HMG_aControlParentHandles [i] )
                     _HMG_ThisType := 'C'
                     _HMG_ThisIndex := i
                     _HMG_ThisFormName := _HMG_aFormNames [ _HMG_ThisFormIndex ]
                     _HMG_ThisControlName := _HMG_aControlNames [ _HMG_ThisIndex ]

                     aCellData := _GetGridCellData ( i )

                     _HMG_ThisItemRowIndex   := aCellData [1]
                     _HMG_ThisItemColIndex   := aCellData [2]
                     _HMG_ThisItemCellRow    := aCellData [3]
                     _HMG_ThisItemCellCol    := aCellData [4]
                     _HMG_ThisItemCellWidth  := aCellData [5]
                     _HMG_ThisItemCellHeight := aCellData [6]

                     Eval ( _HMG_aControlDblClick [i] )

                     _PopEventInfo()
                     _HMG_ThisItemRowIndex   := 0
                     _HMG_ThisItemColIndex   := 0
                     _HMG_ThisItemCellRow    := 0
                     _HMG_ThisItemCellCol    := 0
                     _HMG_ThisItemCellWidth  := 0
                     _HMG_ThisItemCellHeight := 0

                  ENDIF

               ENDIF

               RETURN 0

            ENDIF

            IF GetNotifyCode ( lParam ) == NM_RCLICK
               IF _DoControlEventProcedure ( _HMG_aControlMiscData1 [i] [29] , i )
                  RETURN 1
               ENDIF
            ENDIF

         ENDIF

         // DatePicker / TimePicker Control Notifications
         IF _HMG_aControlType [i] == "DATEPICK" .OR. _HMG_aControlType [i] == "TIMEPICK"

            IF _HMG_aControlType [i] == "DATEPICK" .AND. GetNotifyCode ( lParam ) == DTN_DROPDOWN
               BackColor  := _HMG_aControlMiscData1 [i][1]
               FontColor  := _HMG_aControlMiscData1 [i][2]
               TitleBkClr := _HMG_aControlMiscData1 [i][3]
               TitleFrClr := _HMG_aControlMiscData1 [i][4]
               TrlFontClr := _HMG_aControlMiscData1 [i][5]
               IF _HMG_IsThemed .AND. ( IsArrayRGB ( backcolor ) .OR. IsArrayRGB ( fontcolor ) .OR. IsArrayRGB ( TitleBkClr ) .OR. IsArrayRGB ( TitleFrClr ) )
                  hWnd := SendMessage ( _HMG_aControlHandles [i], DTM_GETMONTHCAL, 0, 0 )
                  SetWindowTheme ( hWnd, "", "" )
                  IF IsArrayRGB( BackColor )
                     SetMonthCalMonthBkColor( hWnd, BackColor[1], BackColor[2], BackColor[3] )
                  ENDIF
                  IF IsArrayRGB( FontColor )
                     SetMonthCalFontColor( hWnd, FontColor[1], FontColor[2], FontColor[3] )
                  ENDIF
                  IF IsArrayRGB( TitleBkClr )
                     SetMonthCalTitleBkColor( hWnd, TitleBkClr[1], TitleBkClr[2], TitleBkClr[3] )
                  ENDIF
                  IF IsArrayRGB( TitleFrClr )
                     SetMonthCalTitleFontColor( hWnd, TitleFrClr[1], TitleFrClr[2], TitleFrClr[3] )
                  ENDIF
                  IF IsArrayRGB( TrlFontClr )
                     SetMonthCalTrlFontColor( hWnd, TrlFontClr[1], TrlFontClr[2], TrlFontClr[3] )
                  ENDIF
                  aPos := { 0, 0, 0, 0 }
                  GetWindowRect( hWnd, aPos )
                  SetPosMonthCal( GetParent ( hWnd ), aPos[1], aPos[2], .T. )
                  setfocus( hWnd )
               ENDIF
               RETURN 0
            ENDIF

            IF _HMG_aControlType [i] == "DATEPICK" .AND. GetNotifyCode ( lParam ) == DTN_DATETIMECHANGE .AND. ;
               SendMessage( _HMG_aControlHandles [i] , DTM_GETMONTHCAL , 0 , 0 ) == 0 .OR. GetNotifyCode ( lParam ) == DTN_CLOSEUP
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
               RETURN 0
            ELSEIF _HMG_aControlType [i] == "TIMEPICK" .AND. GetNotifyCode ( lParam ) == DTN_DATETIMECHANGE
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_SETFOCUS
               VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

         ENDIF

         // RichEditBox Extended Link / Selection events
         IF _HMG_aControlType [i] = "RICHEDIT" .AND. _HMG_aControlMiscData1 [i] == 1

            IF GetNotifyCode ( lParam ) = EN_SELCHANGE
               _DoControlEventProcedure ( _HMG_aControlSpacing [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) = EN_LINK

               IF GetNotifyLink ( lParam , NIL , NIL , @_HMG_CharRange_Min , @_HMG_CharRange_Max ) == WM_LBUTTONDOWN
                  _DoControlEventProcedure ( _HMG_aControlRangeMin [i] , i )
                  _HMG_CharRange_Min := 0
                  _HMG_CharRange_Max := 0
                  RETURN 0
               ENDIF

            ENDIF

         ENDIF

         // Tab Control Page Change Notifications
         IF _HMG_aControlType [i] == "TAB"

            IF GetNotifyCode ( lParam ) == TCN_SELCHANGING
               nOldPage := _GetValue ( , , i )
               _SetFocus ( , , i )
               RETURN 0
            ELSEIF GetNotifyCode ( lParam ) == TCN_SELCHANGE
               IF Len ( _HMG_aControlPageMap [i] ) > 0
                  IF ! _HMG_ProgrammaticChange
                     UpdateTab ( i )
                     _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
                  ELSEIF ! ISBLOCK( _HMG_aControlChangeProcedure [i] ) .OR. ;
                        _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' , nOldPage )
                     UpdateTab ( i )
                  ELSE
                     TabCtrl_SetCurSel ( _HMG_aControlHandles [i] , nOldPage )
                  ENDIF
               ENDIF
               RETURN 0
            ENDIF

         ENDIF

         // TreeView Control Notifications
         IF _HMG_aControlType [i] == "TREE"

            IF GetNotifyCode ( lParam ) == NM_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_SETFOCUS
               VirtualChildControlFocusProcess ( _HMG_aControlHandles [i] , _HMG_aControlParentHandles [i] )
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == TVN_SELCHANGED
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_DBLCLK
               _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
               RETURN 0
            ENDIF

         ENDIF

#ifdef _TSBROWSE_
         IF _HMG_aControlType [i] == "TOOLBAR"

            IF GetNotifyCode ( lParam ) == TBN_QUERYINSERT .OR. ;
               GetNotifyCode ( lParam ) == TBN_QUERYDELETE
               RETURN 1
            ENDIF
            IF GetNotifyCode ( lParam ) == TBN_DELETINGBUTTON
                RETURN 1
            ENDIF
            IF GetNotifyCode ( lParam ) == TBN_INITCUSTOMIZE
               RETURN TBNRF_HIDEHELP
            ENDIF

            RETURN iif( ToolBarExCustFunc ( hWnd, nMsg, wParam, lParam ), 1, 0 )

         ENDIF
#endif

#ifdef _PROPGRID_
         // Property Grid Control Notifications
         IF _HMG_aControlType [i] == "PROPGRID"

            IF GetNotifyCode ( lParam ) == NM_KILLFOCUS
               _DoControlEventProcedure ( _HMG_aControlLostFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_SETFOCUS
               _DoControlEventProcedure ( _HMG_aControlGotFocusProcedure [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == NM_DBLCLK
               _DoControlEventProcedure ( _HMG_aControlDblClick [i] , i )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == TVN_SELCHANGED
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i , 'CONTROL_ONCHANGE' )
               RETURN 0
            ENDIF

            IF GetNotifyCode ( lParam ) == -181
               ReDrawWindow ( _hmg_acontrolhandles [i] )
            ENDIF

         ENDIF
#endif
         // StatusBar Item Click Notifications
         IF _HMG_aControlType [i] == "MESSAGEBAR"

            IF GetNotifyCode ( lParam ) == NM_CLICK

               DefWindowProc( hWnd, NM_CLICK, wParam, lParam )

               x := GetItemPos( lParam ) + 1

               FOR EACH r IN _HMG_aControlHandles

                  i := hb_enumindex ( r )

                  IF _HMG_aControlParentHandles [i] == hWnd

                     IF _HMG_aControlType [i] == "ITEMMESSAGE"

                        IF r == x

                           IF _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )
                              RETURN 0
                           ENDIF

                        ENDIF

                     ENDIF

                  ENDIF

               NEXT

            ENDIF

         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_NCACTIVATE
   ****************************************************************************
      // Process Non-Client Area Activation (prevents unwanted frame inactivation in inplace popups)
      IF _HMG_IsXPorLater .AND. wParam == 0 .AND. lParam == 0
         IF _HMG_InplaceParentHandle <> 0
            InsertReturn ()
         ENDIF
      ENDIF
      EXIT

#ifdef _HMG_COMPAT_
   ****************************************************************************
   CASE WM_WINDOWPOSCHANGING
   ****************************************************************************
      _HMG_DialogBoxProcedure()
      EXIT
#endif

   ****************************************************************************
   CASE WM_QUERYENDSESSION
   ****************************************************************************
      // Triggered on Windows shutdown request. Gracefully closes application.
      __Quit()
      EXIT

   ****************************************************************************
   CASE WM_CLOSE
   ****************************************************************************
      // Intercepts close button (X) press or Alt+F4. Manages interactive close handlers,
      // confirmation prompts, and release procedures.
#ifdef _TSBROWSE_
      oGet := GetObjectByHandle( hWnd )
      IF GetEscapeState() < 0 .AND. ( 'EDIT' $ _GetFocusedControlType( hWnd ) .OR. iif( ISOBJECT( oGet ), 'Edit' $ oGet:cChildControl, .F. ) )
#else
      IF GetEscapeState() < 0 .AND. 'EDIT' $ _GetFocusedControlType( hWnd )
#endif
         RETURN ( 1 )
      ENDIF

      IF ( i := AScan ( _HMG_aFormHandles , hWnd ) ) > 0

         // Run user interactive close handler codeblock if defined
         IF ISBLOCK ( _HMG_aFormInteractiveCloseProcedure [i] )
            r := _DoWindowEventProcedure ( _HMG_aFormInteractiveCloseProcedure [i] , i , 'WINDOW_ONINTERACTIVECLOSE' )
            IF ValType ( r ) == 'L' .AND. r == .F.
               RETURN ( 1 ) // Suppress form close request
            ENDIF
         ENDIF

         IF lParam <> 1

            SWITCH _HMG_InteractiveClose
            CASE 0 // Close prohibited
               MsgStop ( _HMG_MESSAGE [3] )
               RETURN ( 1 )
            CASE 2 // Require prompt confirmation
               IF ! MsgYesNo ( _HMG_MESSAGE [1] , _HMG_MESSAGE [2] )
                  RETURN ( 1 )
               ENDIF
               EXIT
            CASE 3 // Require prompt on main window only
               IF _HMG_aFormType [i] == 'A'
                  IF ! MsgYesNo ( _HMG_MESSAGE [1] , _HMG_MESSAGE [2] )
                     RETURN ( 1 )
                  ENDIF
               ENDIF
            END SWITCH

         ENDIF

         // Check form AutoRelease configuration
         IF _HMG_aFormAutoRelease [i] == .F.
            _HideWindow ( _HMG_aFormNames [i] )
            RETURN ( 1 )
         ENDIF

         // Execute release sequence
         IF _HMG_aFormType [i] == 'A'

            ReleaseAllWindows()

         ELSE

            IF ISBLOCK( _HMG_aFormReleaseProcedure [i] )
               _HMG_InteractiveCloseStarted := .T.
               _DoWindowEventProcedure ( _HMG_aFormReleaseProcedure [i] , i , 'WINDOW_RELEASE' )
            ENDIF

            IF _HMG_lOOPEnabled
               Eval ( _HMG_bOnFormDestroy, i )
            ENDIF

            _hmg_OnHideFocusManagement ( i )

            IF lParam == 1
               DestroyWindow ( hWnd )
            ENDIF

         ENDIF

      ENDIF
      EXIT

   ****************************************************************************
   CASE WM_DESTROY
   ****************************************************************************
      // Final window cleanup handler. Frees GDI objects, unlinks control handles,
      // clears form state vectors, and posts quit message when last form closes.
      i := AScan ( _HMG_aFormHandles , hWnd )

      IF i > 0

#ifndef __XHARBOUR__
         // Remove window properties attached via Win32 API
         IF Len( EnumProps( hWnd ) ) > 0
            EnumPropsEx( hWnd, {|hWnd, cPropName, hHandle| HB_SYMBOL_UNUSED( hHandle ), ;
               iif( hb_LeftEqI( cPropName, "HMG_" ), RemoveProp( hWnd, cPropName ), Nil ), .T. } )
         ENDIF
#endif
         // Destroy child control handles and release resources
         FOR EACH r IN _HMG_aControlParentHandles
            IF r == hWnd
               x := hb_enumindex ( r )
               IF _HMG_aControlType [x] == "MESSAGEBAR"
                  _ReleaseControl ( "StatusBar" , GetParentFormName( x ) )
               ELSE
                  _EraseControl ( x , i )
               ENDIF
            ENDIF
         NEXT

         // Release dynamic brushes and tooltip handles
         DeleteObject ( _HMG_aFormBrushHandle [i] )
         ReleaseControl ( _HMG_aFormToolTipHandle [i] )

         // Delete form dynamic variable references
         mVar := '_' + _HMG_aFormNames [i]
#ifdef _NAMES_LIST_
         _DelNameList ( mVar )
#else
         IF __mvExist ( mVar )
   #ifndef _PUBLIC_RELEASE_
            __mvPut ( mVar , 0 )
   #else
            __mvXRelease ( mVar )
   #endif
         ENDIF
#endif
         // Post WM_QUIT message to exit event loop when appropriate
         IF _HMG_aFormActivateId [i] > 0
            TmpStr := '_HMG_ACTIVATE_' + hb_ntos ( _HMG_aFormActivateId [i] )
#ifdef _NAMES_LIST_
            Tmp := _GetNameList ( TmpStr )
#else
            Tmp := __mvGetDef ( TmpStr )
#endif
            IF ValType ( Tmp ) == 'N'
#ifdef _NAMES_LIST_
               _SetNameList ( TmpStr , --Tmp )
#else
               __mvPut ( TmpStr , --Tmp )
#endif
               IF Tmp == 0
                  PostQuitMessage ( 0 )
#ifdef _NAMES_LIST_
                  _DelNameList ( TmpStr )
#else
                  __mvXRelease ( TmpStr )
#endif
               ENDIF
            ENDIF
         ELSE
            PostQuitMessage( 0 )
         ENDIF

         // Reset form tracking arrays slot
         _HMG_aFormDeleted             [i] := .T.
         _HMG_aFormhandles             [i] := 0
         _HMG_aFormNames               [i] := ""
         _HMG_aFormActive              [i] := .F.
         _HMG_aFormType                [i] := ""
         _HMG_aFormParenthandle        [i] := 0
         _HMG_aFormInitProcedure       [i] := ""
         _HMG_aFormReleaseProcedure    [i] := ""
         _HMG_aFormToolTipHandle       [i] := 0
         _HMG_aFormContextMenuHandle   [i] := 0
         _HMG_aFormMouseDragProcedure  [i] := ""
         _HMG_aFormSizeProcedure       [i] := ""
         _HMG_aFormClickProcedure      [i] := ""
         _HMG_aFormMouseMoveProcedure  [i] := ""
         _HMG_aFormMoveProcedure       [i] := ""
         _HMG_aFormDropProcedure       [i] := ""
         _HMG_aFormBkColor             [i] := Nil
         _HMG_aFormPaintProcedure      [i] := ""
         _HMG_aFormNoShow              [i] := .F.
         _HMG_aFormNotifyIconName      [i] := ''
         _HMG_aFormNotifyIconToolTip   [i] := ''
         _HMG_aFormNotifyIconLeftClick [i] := ''
         _HMG_aFormNotifyIconDblClick  [i] := ''
         _HMG_aFormReBarHandle         [i] := 0
         _HMG_aFormNotifyMenuHandle    [i] := 0
         _HMG_aFormBrowseList          [i] := {}
         _HMG_aFormSplitChildList      [i] := {}
         _HMG_aFormVirtualHeight       [i] := 0
         _HMG_aFormGotFocusProcedure   [i] := ""
         _HMG_aFormLostFocusProcedure  [i] := ""
         _HMG_aFormVirtualWidth        [i] := 0
         _HMG_aFormFocused             [i] := .F.
         _HMG_aFormScrollUp            [i] := ""
         _HMG_aFormScrollDown          [i] := ""
         _HMG_aFormScrollLeft          [i] := ""
         _HMG_aFormScrollRight         [i] := ""
         _HMG_aFormHScrollBox          [i] := ""
         _HMG_aFormVScrollBox          [i] := ""
         _HMG_aFormBrushHandle         [i] := 0
         _HMG_aFormFocusedControl      [i] := 0
         _HMG_aFormGraphTasks          [i] := {}
         _HMG_aFormMaximizeProcedure   [i] := Nil
         _HMG_aFormMinimizeProcedure   [i] := Nil
         _HMG_aFormRestoreProcedure    [i] := Nil
         _HMG_aFormAutoRelease         [i] := .F.
         _HMG_aFormInteractiveCloseProcedure [i] := ""
         _HMG_aFormMinMaxInfo          [i] := {}
         _HMG_aFormActivateId          [i] := 0
         _HMG_aFormMiscData1           [i] := {}
         _HMG_aFormMiscData2           [i] := ''

         _HMG_InteractiveCloseStarted := .F.

      ENDIF
      EXIT

   ****************************************************************************
   DEFAULT
   ****************************************************************************
     // Default message routing for custom registered Win32 messages (Find/Replace, Drag List)
     IF nMsg == _HMG_MsgIDFindDlg   // Find/Replace modeless dialog notifications

         _HMG_FindReplaceOptions := FindReplaceDlgGetOptions ( lParam )
         Eval ( _HMG_FindReplaceOnAction )
         IF _HMG_FindReplaceOptions [1] == 0   // User cancelled or closed dialog
            FindReplaceDlgRelease ( .T. )
         ENDIF
         AFill ( _HMG_FindReplaceOptions, NIL )

      ELSEIF nMsg == _HMG_ListBoxDragNotification // Drag-and-drop ordering within ListBoxes

         SWITCH GET_DRAG_LIST_NOTIFICATION_CODE( lParam )
         CASE DL_BEGINDRAG
            _HMG_ListBoxDragItem := GET_DRAG_LIST_DRAGITEM( lParam )
            RETURN 1
         CASE DL_DRAGGING
            _HMG_ListBoxDragListId := GET_DRAG_LIST_DRAGITEM( lParam )

            IF _HMG_ListBoxDragListId > _HMG_ListBoxDragItem
               DRAG_LIST_DRAWINSERT( hWnd, lParam, _HMG_ListBoxDragListId + 1 )
            ELSE
               DRAG_LIST_DRAWINSERT( hWnd, lParam, _HMG_ListBoxDragListId )
            ENDIF

            IF _HMG_ListBoxDragListId <> -1
               IF _HMG_ListBoxDragListId > _HMG_ListBoxDragItem
                  SetResCursor( LoadCursor( GetInstance(), "MINIGUI_DRAGDOWN" ) )
               ELSE
                  SetResCursor( LoadCursor( GetInstance(), "MINIGUI_DRAGUP" ) )
               ENDIF
               RETURN 0
            ENDIF
            RETURN DL_STOPCURSOR
         CASE DL_CANCELDRAG
            _HMG_ListBoxDragItem := -1
            EXIT
         CASE DL_DROPPED
            _HMG_ListBoxDragListId := GET_DRAG_LIST_DRAGITEM( lParam )

            IF _HMG_ListBoxDragListId <> -1
               DRAG_LIST_MOVE_ITEMS( lParam, _HMG_ListBoxDragItem, _HMG_ListBoxDragListId )
            ENDIF

            DRAG_LIST_DRAWINSERT( hWnd, lParam, -1 )
            _HMG_ListBoxDragItem := -1
         END SWITCH

      ENDIF

   END SWITCH

RETURN ( 0 )

/*
   PROCEDURE _SetNextFocus( lSkip )
   
   Purpose:
      Moves input focus to the next or previous control in tab order within active window.
      
   Parameters:
      lSkip - [Logical] Set to .T. to reverse focus navigation (Shift+Tab behavior).
      
   Side Effects:
      Alters focus control state in Windows and framework state vectors.
*/
PROCEDURE _SetNextFocus( lSkip )
   LOCAL NextControlHandle, hWnd
   LOCAL lMdiChildActive := ( _HMG_BeginWindowMDIActive .AND. !_HMG_IsModalActive )
   LOCAL lShift
   LOCAL i

   hWnd := iif( lMdiChildActive , GetActiveMdiHandle() , GetActiveWindow() )

   NextControlHandle := GetNextDlgTabITem ( hWnd , GetFocus() , hb_defaultValue( lSkip, .F. ) )

   lShift := _GetKeyState( VK_SHIFT )  // Query Shift key state

   IF ( i := AScan ( _HMG_aControlHandles , NextControlHandle ) ) > 0

      IF _HMG_aControlType [i] == 'BUTTON' .OR. lMdiChildActive
         SetFocus( NextControlHandle )
         IF lMdiChildActive .AND. ( i := AScan ( _HMG_aFormHandles , hWnd ) ) > 0
            _HMG_aFormFocusedControl [i] := NextControlHandle
         ELSE
            SendMessage ( NextControlHandle , BM_SETSTYLE , LOWORD ( BS_DEFPUSHBUTTON ) , 1 )
         ENDIF
      ELSE
         iif( lshift , InsertShiftTab() , InsertTab() )
      ENDIF

   ELSEIF ! lMdiChildActive

      iif( lshift , InsertShiftTab() , InsertTab() )

   ENDIF

RETURN

/*
   PROCEDURE _PushEventInfo
   
   Purpose:
      Pushes current event scope variables (_HMG_ThisFormIndex, _HMG_ThisControlName, etc.)
      onto event stack array _HMG_aEventInfo to preserve context during reentrant event execution.
*/
PROCEDURE _PushEventInfo
   AAdd ( _HMG_aEventInfo , { _HMG_ThisFormIndex , _HMG_ThisEventType , _HMG_ThisType , _HMG_ThisIndex , _HMG_ThisFormName , _HMG_ThisControlName } )

RETURN

/*
   PROCEDURE _PopEventInfo( n )
   
   Purpose:
      Pops previously saved event context state variables from _HMG_aEventInfo stack.
      
   Parameters:
      n - [Numeric] Specific stack position index to restore, defaults to last element (0).
*/
PROCEDURE _PopEventInfo( n )
   LOCAL l

   IF ( l := Len ( _HMG_aEventInfo ) ) > 0
      DEFAULT n := 0
      IF n > 0 .and. n <= l; l := n
      ENDIF

      _HMG_ThisFormIndex   := _HMG_aEventInfo [l] [1]
      _HMG_ThisEventType   := _HMG_aEventInfo [l] [2]
      _HMG_ThisType        := _HMG_aEventInfo [l] [3]
      _HMG_ThisIndex       := _HMG_aEventInfo [l] [4]
      _HMG_ThisFormName    := _HMG_aEventInfo [l] [5]
      _HMG_ThisControlName := _HMG_aEventInfo [l] [6]

      IF n == 0
         ASize ( _HMG_aEventInfo , l - 1 )
      ENDIF
   ELSE
      _HMG_ThisIndex := 0
      _HMG_ThisFormIndex := 0
      _HMG_ThisType := ''
      _HMG_ThisEventType := ''
      _HMG_ThisFormName :=  ''
      _HMG_ThisControlName := ''
   ENDIF

RETURN

#ifdef _TSBROWSE_
/*
   FUNCTION GetObjectByHandle ( hWnd )
   
   Purpose:
      Retrieves TSBrowse object instance corresponding to given HWND handle.
*/
FUNCTION GetObjectByHandle ( hWnd )
   LOCAL oWnd, nPos

   IF Type( '_TSB_aControlhWnd' ) == 'A' .AND. Len( _TSB_aControlhWnd ) > 0
      IF ( nPos := AScan( _TSB_aControlhWnd, hWnd ) ) > 0
         oWnd := _TSB_aControlObjects [nPos]
      ENDIF
   ENDIF

RETURN oWnd

#endif

#ifdef _USERINIT_
/*
   PROCEDURE InstallEventHandler ( cProcedure )
   
   Purpose: Registers user custom procedure for low-level event interception.
*/
PROCEDURE InstallEventHandler ( cProcedure )
   AAdd ( _HMG_aCustomEventProcedure , AllTrim ( Upper ( NoBrackets ( cProcedure ) ) ) )

RETURN

/*
   PROCEDURE InstallPropertyHandler ( cPropertyName , cSetProcedure , cGetProcedure )
   
   Purpose: Registers user custom handlers for dynamic control property get/set actions.
*/
PROCEDURE InstallPropertyHandler ( cPropertyName , cSetProcedure , cGetProcedure )
   AAdd ( _HMG_aCustomPropertyProcedure , { AllTrim ( Upper ( cPropertyName ) ) , AllTrim ( Upper ( cSetProcedure ) ) , AllTrim ( Upper ( cGetProcedure ) ) } )

RETURN

/*
   PROCEDURE InstallMethodHandler ( cEventName , cMethodProcedure )
   
   Purpose: Registers user custom handler procedures for control method calls.
*/
PROCEDURE InstallMethodHandler ( cEventName , cMethodProcedure )
   AAdd ( _HMG_aCustomMethodProcedure , { AllTrim ( Upper ( cEventName ) ) , AllTrim ( Upper ( cMethodProcedure ) ) } )

RETURN

/*
   STATIC FUNCTION NoBrackets ( cStr )
   
   Purpose: Helper function stripping parenthesized parameter definitions from procedure name strings.
*/
STATIC FUNCTION NoBrackets ( cStr )
   LOCAL nPos

   IF ( nPos := hb_UAt ( '(', cStr ) ) > 0
      RETURN hb_ULeft ( cStr, nPos - 1 )
   ENDIF

RETURN cStr
#endif

/*
   STATIC FUNCTION _DoGridCustomDraw ( i , a , lParam )
   
   Purpose:
      Evaluates dynamic background and foreground color settings for individual Grid cells
      during WM_NOTIFY custom draw operations.
      
   Parameters:
      i      - [Numeric] Internal control tracking index in _HMG_aControl* arrays.
      a      - [Array]   Coordinate pair array { Row, Column }.
      lParam - [Numeric] Pointer to Win32 NMLVCUSTOMDRAW structure.
*/
STATIC FUNCTION _DoGridCustomDraw ( i , a , lParam )
   LOCAL aTemp
   LOCAL aTemp2

   IF a[1] >= 1 .AND. a[1] <= ListViewGetItemCount ( _HMG_aControlHandles [i] ) .AND. ;
      a[2] >= 1 .AND. a[2] <= ListView_GetColumnCount ( _HMG_aControlHandles [i] )

      aTemp  := _HMG_aControlMiscData1 [i, 22] // Background color matrix
      aTemp2 := _HMG_aControlMiscData1 [i, 21] // Foreground color matrix

      IF ValType ( aTemp ) == 'A' .AND. ValType ( aTemp2 ) <> 'A'

         IF Len ( aTemp ) >= a[1]
            IF aTemp [a[1]] [a[2]] <> -1
               RETURN SetBcFc ( lParam , aTemp [a[1]] [a[2]] , RGB( 0, 0, 0 ) )
            ELSE
               RETURN SETBRCCD( lParam )
            ENDIF
         ENDIF

      ELSEIF ValType ( aTemp ) <> 'A' .AND. ValType ( aTemp2 ) == 'A'

         IF Len ( aTemp2 ) >= a[1]
            IF aTemp2 [a[1]] [a[2]] <> -1
               RETURN SetBcFc ( lParam , RGB( 255, 255, 255 ) , aTemp2 [a[1]] [a[2]] )
            ELSE
               RETURN SETBRCCD( lParam )
            ENDIF
         ENDIF

      ELSEIF ValType ( aTemp ) == 'A' .AND. ValType ( aTemp2 ) == 'A'

         IF Len ( aTemp ) >= a[1] .AND. Len ( aTemp2 ) >= a[1]
            IF aTemp [a[1]] [a[2]] <> -1
               RETURN SetBcFc ( lParam , aTemp [a[1]] [a[2]] , aTemp2 [a[1]] [a[2]] )
            ELSE
               RETURN SETBRCCD( lParam )
            ENDIF
         ENDIF

      ENDIF

   ELSE

      RETURN SETBRCCD( lParam )

   ENDIF

RETURN 0

/*
   STATIC FUNCTION _GetGridCellData ( i )
   
   Purpose:
      Calculates pixel dimensions, column/row index, and desktop coordinates
      of a clicked Grid cell via hit testing.
      
   Parameters:
      i - [Numeric] Control index.
      
   Returns:
      Array - { RowIndex, ColIndex, CellRowPos, CellColPos, CellWidth, CellHeight }
*/
STATIC FUNCTION _GetGridCellData ( i )
   LOCAL ThisItemRowIndex
   LOCAL ThisItemColIndex
   LOCAL ThisItemCellRow
   LOCAL ThisItemCellCol
   LOCAL ThisItemCellWidth
   LOCAL ThisItemCellHeight
   LOCAL r
   LOCAL xs
   LOCAL xd
   LOCAL aCellData

   r := ListView_HitTest ( _HMG_aControlHandles [ i ], GetCursorRow() - GetWindowRow ( _HMG_aControlHandles [ i ] ), GetCursorCol() - GetWindowCol ( _HMG_aControlHandles [ i ] ) )

   IF r [ 2 ] == 1

      ListView_Scroll( _HMG_aControlHandles [ i ], -10000, 0 )
      r := ListView_HitTest ( _HMG_aControlHandles [ i ], GetCursorRow() - GetWindowRow ( _HMG_aControlHandles [ i ] ), GetCursorCol() - GetWindowCol ( _HMG_aControlHandles [ i ] ) )

   ELSEIF r[ 1 ] > 0 .AND. r[ 2 ] > 0

      r := LISTVIEW_GETSUBITEMRECT ( _HMG_aControlHandles [ i ], r[ 1 ] - 1, r[ 2 ] - 1 )

      xs := ( ( _HMG_aControlCol [ i ] + r [ 2 ] ) + ( r[ 3 ] ) ) - ( _HMG_aControlCol [ i ] + _HMG_aControlWidth [ i ] )

      IF ListViewGetItemCount( _HMG_aControlHandles [ i ] ) > ListViewGetCountPerPage( _HMG_aControlHandles [ i ] )
         xd := 20
      ELSE
         xd := 0
      ENDIF

      IF xs > -xd
         ListView_Scroll( _HMG_aControlHandles [ i ], xs + xd, 0 )
      ELSE
         IF r [ 2 ] < 0
            ListView_Scroll( _HMG_aControlHandles [ i ], r[ 2 ], 0 )
         ENDIF
      ENDIF

      r := ListView_HitTest ( _HMG_aControlHandles [ i ], GetCursorRow() - GetWindowRow ( _HMG_aControlHandles [ i ] ), GetCursorCol() - GetWindowCol ( _HMG_aControlHandles [ i ] ) )

   ELSE

      r := AFill( Array( 4 ), 0 )

   ENDIF

   ThisItemRowIndex := r[ 1 ]
   ThisItemColIndex := r[ 2 ]

   IF r [ 2 ] == 1

      r := ListView_GetItemRect ( _HMG_aControlHandles [ i ], r[ 1 ] - 1 )

   ELSEIF r[ 1 ] > 0 .AND. r[ 2 ] > 0

      r := ListView_GetSubItemRect ( _HMG_aControlHandles [ i ], r[ 1 ] - 1, r[ 2 ] - 1 )

   ENDIF

   ThisItemCellRow := _HMG_aControlRow [ i ] + r[ 1 ]
   ThisItemCellCol := _HMG_aControlCol [ i ] + r[ 2 ]
   ThisItemCellWidth := r[ 3 ]
   ThisItemCellHeight := r[ 4 ]

   aCellData := { ThisItemRowIndex, ThisItemColIndex, ThisItemCellRow, ThisItemCellCol, ThisItemCellWidth, ThisItemCellHeight }

RETURN aCellData

/*
   STATIC FUNCTION _GetFocusedControlType ( nFormHandle )
   
   Purpose: Returns control type string of currently focused control child of nFormHandle.
*/
STATIC FUNCTION _GetFocusedControlType ( nFormHandle )
   LOCAL nHandle := GetFocus()
   LOCAL cType As String
   LOCAL hControl, i

   FOR EACH hControl IN _HMG_aControlHandles

      i := hb_enumindex ( hControl )

      IF _HMG_aControlParentHandles [i] == nFormHandle

         IF ValType ( hControl ) == 'N' .AND. hControl == nHandle
            cType := _HMG_aControlType [i]
            EXIT
         ENDIF

      ENDIF

   NEXT

RETURN cType

/*
   STATIC FUNCTION GetMenuItems ( lMenuItem, hMenu )
   
   Purpose: Helper function building list of menu item caption strings.
*/
STATIC FUNCTION GetMenuItems ( lMenuItem, hMenu )
   LOCAL i, h, aMenuItems := {}
   LOCAL cMenuType := iif( lMenuItem, "MENU", "POPUP" )

   FOR EACH h IN _HMG_aControlHandles

      i := hb_enumindex ( h )

      IF _HMG_aControlType [i] == cMenuType .AND. _HMG_aControlPageMap [i] == hMenu .AND. iif( lMenuItem, .T., ( _HMG_aControlIds [i] == 1 ) )
         AAdd( aMenuItems, _HMG_aControlCaption [i] )
      ENDIF

   NEXT

RETURN aMenuItems

#define DT_VCENTER       0x00000004
#define DT_SINGLELINE    0x00000020

/*
   STATIC PROCEDURE _OnDrawStatusItem ( hWnd, lParam )
   
   Purpose: Owner-draw rendering handler for custom Status Bar item panels.
*/
STATIC PROCEDURE _OnDrawStatusItem ( hWnd, lParam )
   LOCAL hDC, aRect, nItem, hBrush, oldBkMode
   LOCAL i, h, nIndex := 0

   hDC := GETOWNBTNDC( lParam )
   aRect := GETOWNBTNRECT( lParam )
   nItem := GETOWNBTNITEMID( lParam )

   FOR EACH h IN _HMG_aControlParentHandles

      i := hb_enumindex ( h )

      IF _HMG_aControlType [i] == "ITEMMESSAGE" .AND. h == hWnd

         IF nIndex++ == nItem
            oldBkMode := SetBkMode( hDC, TRANSPARENT )

            IF _HMG_aControlBkColor [i] != NIL
               hBrush := CreateSolidBrush( _HMG_aControlBkColor [i] [1], _HMG_aControlBkColor [i] [2], _HMG_aControlBkColor [i] [3] )
               FillRect( hDC, aRect [1], aRect [2], aRect [3], aRect [4], hBrush )
               DeleteObject( hBrush )
            ENDIF

            IF _HMG_aControlFontColor [i] != NIL
               SetTextColor( hDC, _HMG_aControlFontColor [i] [1], _HMG_aControlFontColor [i] [2], _HMG_aControlFontColor [i] [3] )
            ENDIF

            DrawText( hDC, _HMG_aControlCaption [i], aRect [1] + 1, aRect [2], aRect [3] - 1, aRect [4], hb_BitOr( _HMG_aControlSpacing [i], DT_SINGLELINE, DT_VCENTER ) )

            SetBkMode( hDC, oldBkMode )
            EXIT
         ENDIF

      ENDIF

   NEXT

RETURN

/*
   STATIC FUNCTION _OnGetMinMaxInfo ( hWnd, pMinMaxInfo )
   
   Purpose: Enforces minimum and maximum window tracking dimensions during sizing.
*/
STATIC FUNCTION _OnGetMinMaxInfo ( hWnd, pMinMaxInfo )
   LOCAL i, nRet := 0

   IF ( i := AScan ( _HMG_aFormHandles, hWnd ) ) > 0

      IF Len ( _HMG_aFormMinMaxInfo [i] ) > 0
         nRet := SetMinMaxInfo ( pMinMaxInfo, _HMG_aFormMinMaxInfo [i] )
      ENDIF

   ENDIF

RETURN nRet

/*
   STATIC FUNCTION _OnFlashExit ()
   
   Purpose: Flashes active modal window frame if user attempts to select parent window.
*/
STATIC FUNCTION _OnFlashExit ()
   LOCAL x, lExit := .F., nFormCount := Len ( _HMG_aFormNames )

   FOR x := 1 TO nFormCount

      IF _HMG_aFormHandles [x] == _HMG_ActiveModalHandle .AND. _HMG_aFormFocused [x]

         PostMessage ( _HMG_ActiveModalHandle, WM_CLOSE, 0, 0 )
         lExit := .T.
         EXIT

      ENDIF

   NEXT x

RETURN lExit

/*
   STATIC PROCEDURE _MouseCoordCorr ( hWnd, i )
   
   Purpose: Adjusts mouse event coordinates according to virtual window scrollbar offsets.
*/
STATIC PROCEDURE _MouseCoordCorr ( hWnd, i )
   IF _hmg_aformvirtualheight [i] > 0
      _HMG_MouseRow += GetScrollPos( hWnd, SB_VERT )
   ENDIF

   IF _hmg_aformvirtualwidth [i] > 0
      _HMG_MouseCol += GetScrollPos( hWnd, SB_HORZ )
   ENDIF

RETURN

/*
   STATIC PROCEDURE _ProcessSliderEvents ( lParam, wParam )
   
   Purpose: Processes trackbar / slider thumb movement and scroll events.
*/
STATIC PROCEDURE _ProcessSliderEvents ( lParam, wParam )
   LOCAL i
   IF _SetGetGlobal( '_HMG_OnChangeEvent' ) == NIL
      STATIC _HMG_OnChangeEvent AS GLOBAL VALUE .F., _HMG_OnScrollEvent AS GLOBAL VALUE .F.
   ENDIF

   IF ( i := AScan ( _HMG_aControlHandles , lParam ) ) > 0

      IF _HMG_aControlType [i] == 'SLIDER'

         SWITCH LoWord ( wParam )

         CASE TB_ENDTRACK
            IF _SetGetGlobal( '_HMG_OnScrollEvent' )
               ASSIGN GLOBAL _HMG_OnScrollEvent := .F.
            ELSE
               ASSIGN GLOBAL _HMG_OnChangeEvent := .T.
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
            ENDIF
            EXIT

         CASE TB_THUMBPOSITION
            IF _SetGetGlobal( '_HMG_OnChangeEvent' )
               ASSIGN GLOBAL _HMG_OnChangeEvent := .F.
            ELSE
               ASSIGN GLOBAL _HMG_OnScrollEvent := .T.
               _DoControlEventProcedure ( _HMG_aControlChangeProcedure [i] , i )
            ENDIF
            EXIT

         CASE TB_THUMBTRACK
         CASE TB_LINEUP
         CASE TB_LINEDOWN
         CASE TB_PAGEUP
         CASE TB_PAGEDOWN
            _DoControlEventProcedure ( _HMG_aControlProcedures [i] , i )

         END SWITCH

      ENDIF

   ENDIF

RETURN

/*
   STATIC PROCEDURE RetDayState ( i, lParam )
   
   Purpose: Computes bold day state flags for MonthCalendar controls.
*/
STATIC PROCEDURE RetDayState ( i, lParam )
   LOCAL aData
   LOCAL aDays
   LOCAL aBoldDays
   LOCAL dStart
   LOCAL dEoM
   LOCAL dDay
   LOCAL nCount
   LOCAL iNextD
   LOCAL nMonth
   LOCAL nLen

   aBoldDays := _HMG_aControlPageMap[ i ]

   aData := GetDayStateData( lParam )
   nCount := aData[ 1 ]

   IF nCount < 1 .OR. Empty( Len( aBoldDays ) )
      RETURN
   ENDIF

   _HMG_aControlMiscData1[ i ] := lParam

   aDays := Array( nCount * 32 )
   AFill( aDays, 0 )

   dStart := aData[ 2 ]
   iNextD := AScan( aBoldDays, {| d | d >= dStart } )

   IF iNextD > 0

      dEoM := EoM( dStart )
      nMonth := 0
      dDay := aBoldDays[ iNextD ]
      nLen := Len( aBoldDays )

      DO WHILE nMonth < nCount

         IF dDay <= dEoM
            aDays[ nMonth * 32 + Day( dDay ) ] := 1
            iNextD++
            IF iNextD > nLen
               EXIT
            ENDIF
            dDay := aBoldDays[ iNextD ]
         ELSE
            nMonth++
            dEoM := EoM( dEoM + 1 )
         ENDIF

      ENDDO

   ENDIF

   C_RETDAYSTATE( lParam, nCount, aDays )

RETURN

/*
   STATIC PROCEDURE DoComboAutoComplete ( i )
   
   Purpose: Implements automatic incremental search completion within editable ComboBoxes.
*/
STATIC PROCEDURE DoComboAutoComplete ( i )
   LOCAL hWnd := _HMG_aControlHandles [i]
   LOCAL cValue := GetWindowText( _HMG_aControlRangeMin [i] )
   LOCAL nStart := Len( cValue )
   LOCAL lShowDropDown := _HMG_aControlMiscData1 [i][8]
   LOCAL nPos := _HMG_aControlMiscData1 [i][9]

   IF nPos > 0

      IF nStart == nPos

         IF nStart > 1

            cValue := SubStr( cValue, 1, nStart - 1 )

         ELSE

            IF ComboFindString( hWnd, cValue ) > 0

               ComboSelectString( hWnd, cValue )
               ComboEditSetSel( hWnd, 0, -1 )
               _HMG_aControlMiscData1 [i][9] := 0

               RETURN

            ENDIF

         ENDIF

      ENDIF

   ENDIF

   _HMG_aControlMiscData1 [i][9] := nStart

   IF hWnd > 0

      IF lShowDropDown
         ComboShowDropDown( hWnd )
      ENDIF

      IF ComboFindString( hWnd, cValue ) > 0

         ComboSelectString( hWnd, cValue )
         ComboEditSetSel( hWnd, nStart, -1 )

      ENDIF

   ENDIF

RETURN

#ifdef _HMG_COMPAT_
/*
   STATIC FUNCTION DoHeaderCustomDraw ( i, lParam, nCol )
   
   Purpose: Handles dynamic header font and color rendering for Grid columns.
*/
STATIC FUNCTION DoHeaderCustomDraw ( i, lParam, nCol )
   LOCAL aHeaderBackColor := _HMG_aControlMiscData1 [ i, _GRID_COLUMN_HEADERDYNAMICBACKCOLOR_ ]
   LOCAL aHeaderForeColor := _HMG_aControlMiscData1 [ i, _GRID_COLUMN_HEADERDYNAMICFORECOLOR_ ]
   LOCAL aHeaderFont := _HMG_aControlMiscData1 [ i, _GRID_COLUMN_HEADERDYNAMICFONT_ ]
   LOCAL nRGB_BackColor := GetSysColor ( COLOR_BTNFACE )
   LOCAL nRGB_ForeColor := RGB ( 0, 0, 0 )
   LOCAL hFont := _HMG_aControlFontHandle [i]
   LOCAL cFontName, hDynamicFont
   LOCAL aRGB

   _HMG_ThisItemRowIndex := 0
   _HMG_ThisItemColIndex := nCol

   IF ValType ( aHeaderBackColor ) == "A"
      IF Len ( aHeaderBackColor ) < nCol
         ASize ( aHeaderBackColor, nCol )
      ENDIF
      IF ValType ( aHeaderBackColor [nCol] ) == "B"
         aRGB := Eval ( aHeaderBackColor [nCol] )
         IF IsArrayRGB ( aRGB )
            nRGB_BackColor := RGB ( aRGB[1], aRGB[2], aRGB[3] )
         ENDIF
      ENDIF
   ENDIF

   IF ValType ( aHeaderForeColor ) == "A"
      IF Len ( aHeaderForeColor ) < nCol
         ASize ( aHeaderForeColor, nCol )
      ENDIF
      IF ValType ( aHeaderForeColor [nCol] ) == "B"
         aRGB := Eval ( aHeaderForeColor [nCol] )
         IF IsArrayRGB ( aRGB )
            nRGB_ForeColor := RGB ( aRGB[1], aRGB[2], aRGB[3] )
         ENDIF
      ENDIF
   ENDIF

   IF ValType ( aHeaderFont ) == "A"
      IF Len ( aHeaderFont ) < nCol
         ASize ( aHeaderFont, nCol )
      ENDIF
      IF ValType ( aHeaderFont [nCol] ) == "B"
         cFontName := Eval ( aHeaderFont [nCol] )
         IF ( hDynamicFont := GetFontHandle( cFontName ) ) != 0
            hFont := hDynamicFont
         ENDIF
      ENDIF
   ENDIF

RETURN HEADER_SetFont ( lParam, nRGB_BackColor, nRGB_ForeColor, hFont )

#endif

/*
   PROCEDURE _AutoAdjust ( hWnd, aInitSize )
   
   Purpose:
      Dynamically resizes and repositions form controls when form dimensions change
      or during automatic application layout zooming.
      
   Parameters:
      hWnd      - [HWND / Numeric] Target form handle.
      aInitSize - [Array] Optional array defining initial reference dimensions { Width, Height }.
      
   Side Effects:
      Updates physical coordinates and font sizes of all child controls on form.
*/
PROCEDURE _AutoAdjust ( hWnd, aInitSize )
   LOCAL ParentForm
   LOCAL ControlCount
   LOCAL ControlName, ControlType
   LOCAL nDivw, nDivh, nDivw2, nDivh2
   LOCAL lAutoZooming := ( _HMG_AutoZooming == .T. )
   LOCAL cControlExcept := "IMAGE"
   LOCAL lInvisible := .T.
   LOCAL nWidth, nHeight
   LOCAL i, k
#ifdef _TSBROWSE_
   LOCAL oBrw
#endif

   nWidth := iif( GetDesktopWidth() < GetWindowWidth( hWnd ), GetDesktopWidth(), GetWindowWidth( hWnd ) )
   nHeight := iif( GetDesktopHeight() < GetWindowHeight( hWnd ), GetDesktopHeight(), GetWindowHeight( hWnd ) )

   // Prevent visual flickering during dynamic control repositioning
   IF IsWindowVisible( hWnd ) .AND. ! IsAppXPThemed()
      HideWindow( hWnd )
   ELSE
      lInvisible := .NOT. LockWindowUpdate( hWnd )
   ENDIF

   i := AScan( _HMG_aFormHandles, hWnd )
   ParentForm := _HMG_aFormNames [i]

   IF ISARRAY( aInitSize )
      _HMG_aFormVirtualWidth  [i] := aInitSize [1]
      _HMG_aFormVirtualHeight [i] := aInitSize [2]
   ENDIF

   IF _HMG_aFormVirtualWidth [i] > 0 .AND. _HMG_aFormVirtualHeight [i] > 0
      nDivw := nWidth / _HMG_aFormVirtualWidth [i]
      nDivh := nHeight / _HMG_aFormVirtualHeight [i]
   ELSE
      nDivw := 1
      nDivh := 1
   ENDIF

   IF lAutoZooming
      nDivw2 := nDivw
      nDivh2 := nDivh
   ELSEIF _HMG_AutoAdjustException == .T.
      cControlExcept += ",OBUTTON,CHECKBOX"
   ENDIF

   ControlCount := Len( _HMG_aControlHandles )

   // Adjust position, scale, and font sizes across child controls
   FOR k := 1 TO ControlCount

      IF _HMG_aControlParentHandles [k] == hWnd

         ControlName := _HMG_aControlNames [k]
         ControlType := _HMG_aControlType [k]

         IF ! Empty( ControlName ) .AND. !( ControlType $ "MENU,HOTKEY,TOOLBAR,MESSAGEBAR,ITEMMESSAGE,TIMER" ) .AND. ;
            Empty( GetControlContainerHandle( ControlName, ParentForm ) )

            IF ControlType == "RADIOGROUP"
               _HMG_aControlSpacing [k] := _HMG_aControlSpacing [k] * iif( _HMG_aControlMiscData1 [k], nDivw, nDivh )
            ENDIF

            IF ! lAutoZooming
               DO CASE
               CASE ControlType $ cControlExcept .OR. "PICK" $ ControlType
                  nDivw2 := 1
                  nDivh2 := 1
               CASE "TEXT" $ ControlType .OR. "LABEL" $ ControlType .OR. ControlType $ "GETBOX,SPINNER,HYPERLINK,PROGRESSBAR,COMBO,HOTKEYBOX"
                  nDivw2 := nDivw
                  nDivh2 := 1
               OTHERWISE
                  nDivw2 := nDivw
                  nDivh2 := nDivh
               ENDCASE
            ENDIF

            _SetControlSizePos( ControlName, ParentForm, ;
               _GetControlRow( ControlName, ParentForm ) * nDivh, _GetControlCol( ControlName, ParentForm ) * nDivw, ;
               _GetControlWidth( ControlName, ParentForm ) * nDivw2, _GetControlHeight( ControlName, ParentForm ) * nDivh2 )

#ifdef _TSBROWSE_
            IF ControlType == "TBROWSE"
               oBrw := _HMG_aControlIds [k]
               IF oBrw:nDataType == 1 /*DATATYPE_RDD*/
                  oBrw:UpStable()
               ELSE
                  oBrw:Refresh( .T. )
                  oBrw:DrawSelect()
               ENDIF
            ELSEIF lAutoZooming .AND. ControlType <> "SLIDER"
#else
               IF lAutoZooming .AND. ControlType <> "SLIDER"
#endif
                  _SetFontSize( ControlName, ParentForm, _HMG_aControlFontSize [k] * nDivh )
               ENDIF

            ENDIF

         ENDIF

   NEXT k

   _HMG_aFormVirtualWidth  [i] := nWidth
   _HMG_aFormVirtualHeight [i] := nHeight

   // Re-enable window updates and force complete window redraw
   IF lInvisible
      ShowWindow( hWnd )
   ELSE
      LockWindowUpdate( 0 )
      RedrawWindow ( hWnd )
   ENDIF

RETURN
