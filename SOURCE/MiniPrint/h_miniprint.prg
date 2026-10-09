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
  Copyright 2001 Alexander S.Kresin <alex@belacy.ru>
  Copyright 2001 Antonio Linares <alinares@fivetech.com>
 www - https://harbour.github.io/

 "Harbour Project"
 Copyright 1999-2026, https://harbour.github.io/

 Parts of this module are based upon:

 "HBPRINT"
 Copyright 2002 Richard Rylko <rrylko@poczta.onet.pl>
 http://rrylko.republika.pl

 "HBPRINTER"
 Copyright 2002 Richard Rylko <rrylko@poczta.onet.pl>
 http://rrylko.republika.pl

 ---------------------------------------------------------------------------*/

///////////////////////////////////////////////////////////////////////////////
// HARBOUR LEVEL PRINT ROUTINES
///////////////////////////////////////////////////////////////////////////////

#include "minigui.ch"
#include "miniprint.ch"
#include "hp_images.ch"

#define SB_HORZ  0 // Standard Win32 scrollbar direction horizontal
#define SB_VERT  1 // Standard Win32 scrollbar direction vertical

#xtranslate Alltrim( Str( <i> ) ) => hb_ntos( <i> ) // Optimize string conversion of numbers

DECLARE WINDOW _HMG_PRINTER_PPNAV

STATIC IsVistaThemed // Tracks whether Windows Vista or later visual styles are active

/*
 * Routine: _HMG_PRINTER_SHOWPREVIEW()
 *
 * Purpose:
 *   Initializes and displays the print preview interface, including the main preview
 *   window, thumbnail viewer, navigation controls, and print options dialogs.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Disables the active modal window if one exists.
 *   - Defines and activates multiple HMG windows: _HMG_PRINTER_SHOWPREVIEW,
 *     _HMG_PRINTER_PRINTPAGES, _HMG_PRINTER_GO_TO_PAGE, _HMG_PRINTER_SHOWTHUMBNAILS,
 *     _HMG_PRINTER_Wait, and _HMG_PRINTER_PPNAV.
 *   - Configures scrollbars and key bindings for the preview interface.
 */
PROCEDURE _HMG_PRINTER_SHOWPREVIEW
   LOCAL ModalHandle
   LOCAL Tmp
   LOCAL tHeight
   LOCAL tFactor
   LOCAL tvHeight
   LOCAL icb

   // Detect if the application is running with Vista or later visual styles enabled
   IsVistaThemed := ( IsVistaOrLater() .AND. IsAppXPThemed() )

   _hmg_printer_BasePageName := GetTempFolder() + hb_ps() + _hmg_printer_timestamp + "_hmg_print_preview_"
   _hmg_printer_CurrentPageNumber := 1
   _hmg_printer_Dx := 0
   _hmg_printer_Dy := 0
   _hmg_printer_Dz := 0
   _hmg_printer_scrollstep := 10
   _hmg_printer_zoomclick_xoffset := 0
   _hmg_printer_thumbupdate := .T.
   _hmg_printer_PrevPageNumber := 0
   _hmg_printer_collate := PRINTER_COLLATE_FALSE

   IF _HMG_IsModalActive == .T.

      ModalHandle := _hmg_activemodalhandle

      _HMG_IsModalActive := .F.
      _hmg_activemodalhandle := 0

      DisableWindow ( ModalHandle )

   ELSE

      ModalHandle := 0

   ENDIF

   // Ensure a valid printer device context exists before showing preview
   IF _hmg_printer_hdc_bak == 0
      RETURN
   ENDIF

   // Prevent opening multiple instances of the print preview window
   IF _IsWindowDefined ( "_HMG_PRINTER_SHOWPREVIEW" )
      RETURN
   ENDIF

   icb := _HMG_InteractiveClose

   SET INTERACTIVECLOSE OFF

   // Calculate initial zoom factor based on desktop height and page height
   _hmg_printer_SizeFactor := GetDesktopHeight() / _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) * 0.63

   // Adjust zoom delta for large page formats
   IF _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) > 370
      _HMG_PRINTER_DELTA_ZOOM := -250
   ELSE
      _HMG_PRINTER_DELTA_ZOOM := 0
   ENDIF

   // Define a borderless wait dialog to display during thumbnail generation
   DEFINE WINDOW _HMG_PRINTER_Wait AT 0, 0 WIDTH 310 HEIGHT 85 TITLE '' child noshow nocaption
      DEFINE LABEL label_1
         ROW 30
         COL 5
         WIDTH 300
         HEIGHT 30
         VALUE _hmg_printer_usermessages[ 29 ]
         CENTERALIGN .T.
      END LABEL
   END WINDOW

   _HMG_PRINTER_Wait.CENTER

   // Define the main print preview window with virtual dimensions for panning
   DEFINE WINDOW _HMG_PRINTER_SHOWPREVIEW ;
         AT 0, 0 ;
         WIDTH GetDesktopWidth() - 103 - iif ( IsVistaThemed, 25, 0 ) ;
         HEIGHT GetDesktopHeight() - 103 - iif ( IsVistaThemed, 25, 0 ) ;
         VIRTUAL WIDTH ( GetDesktopWidth() - 103 ) * 2 ;
         VIRTUAL HEIGHT ( GetDesktopHeight() - 103 ) * 2 ;
         TITLE _hmg_printer_usermessages[ 01 ] + ' [' + AllTrim( Str( _hmg_printer_CurrentPageNumber ) ) + '/' + ;
         AllTrim( Str( _hmg_printer_PageCount ) ) + ']' ;
         CHILD ;
         NOSIZE ;
         NOMINIMIZE ;
         NOMAXIMIZE ;
         NOSYSMENU ;
         CURSOR IMG_CURSOR ;
         ON PAINT _HMG_PRINTER_PREVIEWRefresh() ;
         ON RELEASE _HMG_PRINTER_OnRelease( ModalHandle, icb ) ;
         BACKCOLOR GRAY ;
         ON MOUSECLICK ( _HMG_PRINTER_PPNAV.b5.VALUE := ! _HMG_PRINTER_PPNAV.b5.VALUE, _HMG_PRINTER_MouseZoom() ) ;
         ON SCROLLUP _HMG_PRINTER_ScrolluP() ;
         ON SCROLLDOWN _HMG_PRINTER_ScrollDown() ;
         ON SCROLLLEFT _HMG_PRINTER_ScrollLeft() ;
         ON SCROLLRIGHT _HMG_PRINTER_ScrollRight() ;
         ON HSCROLLBOX _HMG_PRINTER_hScrollBoxProcess() ;
         ON VSCROLLBOX _HMG_PRINTER_vScrollBoxProcess()

      _HMG_PRINTER_SetKeys( '_HMG_PRINTER_SHOWPREVIEW' )

   END WINDOW

   // Define the print range and options dialog
   DEFINE WINDOW _HMG_PRINTER_PRINTPAGES ;
         AT 0, 0 ;
         WIDTH 420 ;
         HEIGHT 168 + GetTitleHeight() ;
         TITLE _hmg_printer_usermessages[ 9 ] ;
         CHILD NOSHOW ;
         NOSIZE NOSYSMENU

      ON KEY ESCAPE ACTION ( HideWindow ( GetFormHandle ( "_HMG_PRINTER_PRINTPAGES" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) ), _HMG_PRINTER_SHOWPREVIEW.setfocus )
      ON KEY RETURN ACTION _HMG_PRINTER_PrintPagesDo()

      DEFINE FRAME Frame_1
         ROW 5
         COL 10
         WIDTH 275
         HEIGHT 147
         FONTNAME 'Arial'
         FONTSIZE 9
         CAPTION _hmg_printer_usermessages[ 15 ]
      END FRAME

      DEFINE RADIOGROUP Radio_1
         ROW 25
         COL 20
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE 1
         OPTIONS { _hmg_printer_usermessages[ 16 ], _hmg_printer_usermessages[ 17 ] }
         ONCHANGE iif ( This.VALUE == 1, ( _HMG_PRINTER_PRINTPAGES.Label_1.Enabled := .F., _HMG_PRINTER_PRINTPAGES.Label_2.Enabled := .F., _HMG_PRINTER_PRINTPAGES.Spinner_1.Enabled := .F., _HMG_PRINTER_PRINTPAGES.Spinner_2.Enabled := .F., _HMG_PRINTER_PRINTPAGES.Combo_1.Enabled := .F., _HMG_PRINTER_PRINTPAGES.Label_4.Enabled := .F. ), ( _HMG_PRINTER_PRINTPAGES.Label_1.Enabled := .T., _HMG_PRINTER_PRINTPAGES.Label_2.Enabled := .T., _HMG_PRINTER_PRINTPAGES.Spinner_1.Enabled := .T., _HMG_PRINTER_PRINTPAGES.Spinner_2.Enabled := .T., _HMG_PRINTER_PRINTPAGES.Combo_1.Enabled := .T., _HMG_PRINTER_PRINTPAGES.Label_4.Enabled := .T., _HMG_PRINTER_PRINTPAGES.Spinner_1.SetFocus ) )
      END RADIOGROUP

      DEFINE LABEL Label_1
         ROW 84
         COL 55
         WIDTH 50
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_usermessages[ 18 ] + ':'
      END LABEL

      DEFINE SPINNER Spinner_1
         ROW 81
         COL 110
         WIDTH 50
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE 1
         RANGEMIN 1
         RANGEMAX _hmg_printer_PageCount
      END SPINNER

      DEFINE LABEL Label_2
         ROW 84
         COL 165
         WIDTH 35
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_usermessages[ 19 ] + ':'
      END LABEL

      DEFINE SPINNER Spinner_2
         ROW 81
         COL 205
         WIDTH 50
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_PageCount
         RANGEMIN 1
         RANGEMAX _hmg_printer_PageCount
      END SPINNER

      DEFINE LABEL Label_4
         ROW 115
         COL 55
         WIDTH 50
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_usermessages[ 09 ] + ':'
      END LABEL

      DEFINE COMBOBOX Combo_1
         ROW 113
         COL 110
         WIDTH 145
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE 1
         ITEMS { _hmg_printer_usermessages[ 21 ], _hmg_printer_usermessages[ 22 ], _hmg_printer_usermessages[ 23 ] }
      END COMBOBOX

      DEFINE BUTTON Ok
         ROW 10
         COL 300
         WIDTH 105
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         CAPTION _hmg_printer_usermessages[ 11 ]
         ACTION _HMG_PRINTER_PrintPagesDo()
      END BUTTON

      DEFINE BUTTON Cancel
         ROW 40
         COL 300
         WIDTH 105
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         CAPTION _hmg_printer_usermessages[ 12 ]
         ACTION ( EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) ), HideWindow ( GetFormHandle ( "_HMG_PRINTER_PRINTPAGES" ) ), _HMG_PRINTER_SHOWPREVIEW.setfocus )
      END BUTTON

      DEFINE LABEL Label_3
         ROW 103
         COL 300
         WIDTH 45
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_usermessages[ 20 ] + ':'
      END LABEL

      DEFINE SPINNER Spinner_3
         ROW 100
         COL 355
         WIDTH 50
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_copies
         RANGEMIN 1
         RANGEMAX 999
         ONCHANGE iif ( IsControlDefined ( CheckBox_1, _HMG_PRINTER_PRINTPAGES ), iif ( This.Value > 1, SetProperty( '_HMG_PRINTER_PRINTPAGES', 'CheckBox_1', 'Enabled', .T. ), SetProperty( '_HMG_PRINTER_PRINTPAGES', 'CheckBox_1', 'Enabled', .F. ) ), Nil )
      END SPINNER

      DEFINE CHECKBOX CheckBox_1
         ROW 132
         COL 300
         WIDTH 110
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE iif ( _hmg_printer_collate == 1, .T., .F. )
         CAPTION _hmg_printer_usermessages[ 14 ]
      END CHECKBOX

   END WINDOW

   CENTER WINDOW _HMG_PRINTER_PRINTPAGES

   // Define the page navigation dialog
   DEFINE WINDOW _HMG_PRINTER_GO_TO_PAGE ;
         AT 0, 0 ;
         WIDTH 195 ;
         HEIGHT 90 + GetTitleHeight() ;
         TITLE _hmg_printer_usermessages[ 07 ] ;
         CHILD NOSHOW ;
         NOSIZE NOSYSMENU

      ON KEY ESCAPE ACTION ( HideWindow( GetFormHandle ( "_HMG_PRINTER_GO_TO_PAGE" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) ), _HMG_PRINTER_SHOWPREVIEW.setfocus )
      ON KEY RETURN ACTION ( _hmg_printer_CurrentPageNumber := _HMG_PRINTER_GO_TO_PAGE.Spinner_1.VALUE, HideWindow( GetFormHandle ( "_HMG_PRINTER_GO_TO_PAGE" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) ), _HMG_PRINTER_PREVIEWRefresh(), _HMG_PRINTER_SHOWPREVIEW.setfocus )

      DEFINE LABEL Label_1
         ROW 13
         COL 10
         WIDTH 94
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_usermessages[ 10 ] + ':'
      END LABEL

      DEFINE SPINNER Spinner_1
         ROW 10
         COL 105
         WIDTH 75
         FONTNAME 'Arial'
         FONTSIZE 9
         VALUE _hmg_printer_CurrentPageNumber
         RANGEMIN 1
         RANGEMAX _hmg_printer_PageCount
      END SPINNER

      DEFINE BUTTON Ok
         ROW 48
         COL 10
         WIDTH 80
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         CAPTION _hmg_printer_usermessages[ 11 ]
         ACTION ( _hmg_printer_CurrentPageNumber := _HMG_PRINTER_GO_TO_PAGE.Spinner_1.VALUE, HideWindow( GetFormHandle ( "_HMG_PRINTER_GO_TO_PAGE" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) ), _HMG_PRINTER_PREVIEWRefresh(), _HMG_PRINTER_SHOWPREVIEW.setfocus )
      END BUTTON

      DEFINE BUTTON Cancel
         ROW 48
         COL 100
         WIDTH 80
         HEIGHT 25
         FONTNAME 'Arial'
         FONTSIZE 9
         CAPTION _hmg_printer_usermessages[ 12 ]
         ACTION ( HideWindow( GetFormHandle ( "_HMG_PRINTER_GO_TO_PAGE" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) ), EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) ), _HMG_PRINTER_SHOWPREVIEW.setfocus )
      END BUTTON

   END WINDOW

   CENTER WINDOW _HMG_PRINTER_GO_TO_PAGE

   IF _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) > _HMG_PRINTER_GETPAGEWIDTH( _hmg_printer_hdc_bak )
      tFactor := 0.44
   ELSE
      tFactor := 0.26
   ENDIF

   tHeight := _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) * tFactor

   tHeight := Int ( tHeight )

   tvHeight := ( _hmg_printer_PageCount * ( tHeight + 10 ) ) + GetHScrollbarHeight() + GetTitleHeight() + ( GetBorderHeight() * 2 ) + 7

   IF tvHeight <= GetDesktopHeight() - 103
      _hmg_printer_thumbscroll := .F.
      tvHeight := GetDesktopHeight() - 102
   ELSE
      _hmg_printer_thumbscroll := .T.
   ENDIF

   // Define the thumbnail panel window
   DEFINE WINDOW _HMG_PRINTER_SHOWTHUMBNAILS ;
         AT 0, 5 ;
         WIDTH 130 ;
         HEIGHT GetDesktopHeight() - 103 - IF ( IsVistaThemed, 25, 0 ) ;
         VIRTUAL WIDTH 131 ;
         VIRTUAL HEIGHT tvHeight ;
         TITLE _hmg_printer_usermessages[ 28 ] ;
         CHILD ;
         NOSIZE ;
         NOMINIMIZE ;
         NOMAXIMIZE ;
         NOSYSMENU ;
         NOSHOW ;
         BACKCOLOR GRAY

      _HMG_PRINTER_SetKeys( '_HMG_PRINTER_SHOWTHUMBNAILS' )

   END WINDOW

   IF _hmg_printer_thumbscroll == .F.
      _HMG_PRINTER_PREVIEW_DISABLESCROLLBARS ( GetFormHandle( '_HMG_PRINTER_SHOWTHUMBNAILS' ) )
   ENDIF

   // Define the floating navigation toolbar palette
   DEFINE WINDOW _HMG_PRINTER_PPNAV ;
         AT 1 + iif ( IsVistaThemed, 3, 0 ), GetDesktopWidth() - 320 - iif ( IsVistaThemed, 5, 0 ) ;
         WIDTH 312 + GetBorderWidth() ;
         HEIGHT 35 + GetTitleHeight() - iif ( IsVistaThemed .OR. ! _HMG_IsXP, 0, GetBorderHeight() ) ;
         TITLE ' ' + _hmg_printer_usermessages[ 02 ] ;
         PALETTE ;
         NOMAXIMIZE ;
         NOMINIMIZE ;
         NOSIZE ;
         NOSYSMENU

      DEFINE BUTTONEX b1
         ROW 2
         COL 2
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_TOP
         TOOLTIP _hmg_printer_usermessages[ 03 ]
         ACTION ( _hmg_printer_CurrentPageNumber := 1, _HMG_PRINTER_PREVIEWRefresh() )
      END BUTTONEX

      DEFINE BUTTONEX b2
         ROW 2
         COL 32
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_BACK
         TOOLTIP _hmg_printer_usermessages[ 04 ]
         ACTION ( _hmg_printer_CurrentPageNumber--, _HMG_PRINTER_PREVIEWRefresh() )
      END BUTTONEX

      DEFINE BUTTONEX b3
         ROW 2
         COL 62
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_NEXT
         TOOLTIP _hmg_printer_usermessages[ 05 ]
         ACTION ( _hmg_printer_CurrentPageNumber++, _HMG_PRINTER_PREVIEWRefresh() )
      END BUTTONEX

      DEFINE BUTTONEX b4
         ROW 2
         COL 92
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_END
         TOOLTIP _hmg_printer_usermessages[ 06 ]
         ACTION ( _hmg_printer_CurrentPageNumber := _hmg_printer_PageCount, _HMG_PRINTER_PREVIEWRefresh() )
      END BUTTONEX

      DEFINE CHECKBUTTON thumbswitch
         ROW 2
         COL 126
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_THUMBNAIL
         TOOLTIP _hmg_printer_usermessages[ 28 ] + ' [Ctrl+T]'
         ONCHANGE _HMG_PRINTER_ProcessTHUMBNAILS()
      END CHECKBUTTON

      DEFINE BUTTONEX GoToPage
         ROW 2
         COL 156
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_GOPAGE
         TOOLTIP _hmg_printer_usermessages[ 07 ] + ' [Ctrl+G]'
         ACTION _HMG_PRINTER_GO_TO_PAGE()
      END BUTTONEX

      DEFINE CHECKBUTTON b5
         ROW 2
         COL 186
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_ZOOM
         TOOLTIP _hmg_printer_usermessages[ 08 ] + ' [*]'
         ON CHANGE _HMG_PRINTER_Zoom()
      END CHECKBUTTON

      DEFINE BUTTONEX b12
         ROW 2
         COL 216
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_PRINT
         TOOLTIP _hmg_printer_usermessages[ 09 ] + ' [Ctrl+P]'
         ACTION _HMG_PRINTER_PrintPages()
      END BUTTONEX

      DEFINE BUTTONEX b7
         ROW 2
         COL 246
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_SAVE
         TOOLTIP _hmg_printer_usermessages[ 27 ] + ' [Ctrl+S]'
         ACTION _hmg_printer_savepages()
      END BUTTONEX

      DEFINE BUTTONEX b6
         ROW 2
         COL 280
         WIDTH 30
         HEIGHT 30
         PICTURE IMG_CLOSE
         TOOLTIP _hmg_printer_usermessages[ 26 ] + ' [Ctrl+C]'
         ACTION _HMG_PRINTER_PreviewClose()
      END BUTTONEX

      _HMG_PRINTER_SetKeys( '_HMG_PRINTER_PPNAV' )

   END WINDOW

   // Adjust window height on Windows 10 to account for different border metrics
   IF hb_osIsWin10()
      SetProperty( '_HMG_PRINTER_PPNAV', "Height", GetProperty( '_HMG_PRINTER_PPNAV', "Height" ) + GetBorderHeight() / 2 )
   ENDIF

   // Initialize scrollbar ranges and center positions for panning
   SetScrollRange ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 0, 100, .T. )
   SetScrollRange ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 0, 100, .T. )

   SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 50, .T. )
   SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 50, .T. )

   // Disable scrollbars initially until zoom is activated
   _HMG_PRINTER_PREVIEW_DISABLESCROLLBARS ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ) )

   _HMG_PRINTER_PREVIEW_DISABLEHSCROLLBAR ( GetFormHandle( '_HMG_PRINTER_SHOWTHUMBNAILS' ) )

   CENTER WINDOW _HMG_PRINTER_SHOWPREVIEW

   Tmp := _HMG_PRINTER_SHOWPREVIEW.ROW + GetTitleHeight() + iif ( IsVistaThemed, GetBorderHeight(), 0 )

   _HMG_PRINTER_SHOWPREVIEW.ROW := Tmp

   _HMG_PRINTER_SHOWTHUMBNAILS.ROW := Tmp

   // Activate all preview-related windows simultaneously
   ACTIVATE WINDOW _HMG_PRINTER_PRINTPAGES, _HMG_PRINTER_GO_TO_PAGE, _HMG_PRINTER_SHOWTHUMBNAILS, _HMG_PRINTER_SHOWPREVIEW, _HMG_PRINTER_Wait, _HMG_PRINTER_PPNAV
RETURN

/*
 * Routine: _HMG_PRINTER_OnRelease()
 *
 * Purpose:
 *   Handles cleanup and window state restoration when the print preview window is released.
 *
 * Parameters:
 *   ModalHandle - Numeric - Handle of the modal window that was active before the preview.
 *   icb - Logical - The original state of the interactive close setting.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Restores the active printer device context.
 *   - Re-enables the previously disabled modal window and its child panel windows.
 *   - Restores the interactive close setting to its original state.
 */
STATIC PROCEDURE _HMG_PRINTER_OnRelease( ModalHandle, icb )
   LOCAL i

   _hmg_printer_hdc := _hmg_printer_hdc_bak

   IF ModalHandle != 0

      // Disable other active windows to maintain modal behavior
      FOR i := 1 TO Len ( _HMG_aFormHandles )
         IF _HMG_aFormDeleted[ i ] == .F.
            IF _HMG_aFormType[ i ] != 'X'
               IF _HMG_aFormHandles[ i ] != ModalHandle
                  DisableWindow ( _HMG_aFormHandles[ i ] )
               ENDIF
            ENDIF
         ENDIF
      NEXT i

      EnableWindow ( ModalHandle )

      // Re-enable panel child windows of the modal window
      FOR i := 1 TO Len ( _HMG_aFormHandles )
         IF _HMG_aFormDeleted[ i ] == .F.
            IF _HMG_aFormType[ i ] == 'P' .AND. _HMG_aFormParentHandle[ i ] == ModalHandle // Panel window into Modal window
               EnableWindow ( _HMG_aFormHandles[ i ] )
            ENDIF
         ENDIF
      NEXT i

      SetFocus ( ModalHandle )

      _HMG_IsModalActive := .T.
      _hmg_activemodalhandle := ModalHandle

   ENDIF

   _HMG_InteractiveClose := icb
RETURN

/*
 * Routine: _HMG_PRINTER_SetKeys()
 *
 * Purpose:
 *   Binds standard keyboard shortcuts to a specified parent window for print preview navigation.
 *
 * Parameters:
 *   parent - Character - The name of the window to which the key bindings will be applied.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Registers keyboard event handlers (HOME, PRIOR, NEXT, END, Ctrl+P, Ctrl+G, ESC,
 *     MULTIPLY, Ctrl+C, Alt+F4, Ctrl+S, Ctrl+T) on the specified window.
 */
STATIC PROCEDURE _HMG_PRINTER_SetKeys( parent )

   ON KEY HOME OF &parent ACTION ( _hmg_printer_CurrentPageNumber := 1, _HMG_PRINTER_PREVIEWRefresh() )
   ON KEY PRIOR OF &parent ACTION ( _hmg_printer_CurrentPageNumber--, _HMG_PRINTER_PREVIEWRefresh() )
   ON KEY NEXT OF &parent ACTION ( _hmg_printer_CurrentPageNumber++, _HMG_PRINTER_PREVIEWRefresh() )
   ON KEY END OF &parent ACTION ( _hmg_printer_CurrentPageNumber := _hmg_printer_PageCount, _HMG_PRINTER_PREVIEWRefresh() )
   ON KEY CONTROL + P OF &parent ACTION _HMG_PRINTER_Printpages()
   ON KEY CONTROL + G OF &parent ACTION _HMG_PRINTER_GO_TO_PAGE()
   ON KEY ESCAPE OF &parent ACTION _HMG_PRINTER_PreviewClose()
   ON KEY MULTIPLY OF &parent ACTION ( _HMG_PRINTER_PPNAV.b5.VALUE := ! _HMG_PRINTER_PPNAV.b5.VALUE, _HMG_PRINTER_MouseZoom() )
   ON KEY CONTROL + C OF &parent ACTION _HMG_PRINTER_PreviewClose()
   ON KEY ALT + F4 OF &parent ACTION _HMG_PRINTER_PreviewClose()
   ON KEY CONTROL + S OF &parent ACTION _hmg_printer_savepages()
   ON KEY CONTROL + T OF &parent ACTION _hmg_printer_ThumbnailToggle()
RETURN

/*
 * Routine: CreateThumbNails()
 *
 * Purpose:
 *   Generates and displays thumbnail images for all pages in the print preview.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Displays and hides the wait dialog (_HMG_PRINTER_Wait).
 *   - Dynamically defines EMF image controls on the _HMG_PRINTER_SHOWTHUMBNAILS window.
 *   - Assigns click actions and tooltips to each thumbnail control.
 */
STATIC PROCEDURE CreateThumbNails
   LOCAL tFactor
   LOCAL tWidth
   LOCAL tHeight
   LOCAL ttHandle
   LOCAL i
   LOCAL cMacroTemp
   LOCAL cAction

   IF _IsControlDefined ( 'Image1', '_HMG_PRINTER_SHOWTHUMBNAILS' )
      RETURN
   ENDIF

   ShowWindow ( GetFormHandle ( "_HMG_PRINTER_Wait" ) )

   IF _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) > _HMG_PRINTER_GETPAGEWIDTH( _hmg_printer_hdc_bak )
      tFactor := 0.44
   ELSE
      tFactor := 0.30
   ENDIF

   tWidth := _HMG_PRINTER_GETPAGEWIDTH( _hmg_printer_hdc_bak ) * tFactor
   tHeight := _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) * tFactor

   tHeight := Int ( tHeight )

   ttHandle := GetFormToolTipHandle ( '_HMG_PRINTER_SHOWTHUMBNAILS' )

   FOR i := 1 TO _hmg_printer_PageCount

      // Generate a unique control name for each page thumbnail
      cMacroTemp := 'Image' + AllTrim( Str( i ) )

      // Define the action to switch to the clicked page and refresh the preview
      cAction := "_HMG_MINIPRINT [4] := " + AllTrim( Str( i ) ) + ", _HMG_MINIPRINT [11] := .F., _HMG_PRINTER_PREVIEWRefresh(), _HMG_MINIPRINT [11] := .T."

      _DefineEmfFile( ;
         cMacroTemp, ;
         '_HMG_PRINTER_SHOWTHUMBNAILS', ;
         10, ;
         ( i * ( tHeight + 10 ) ) - tHeight, ;
         _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf", ;
         tWidth, ;
         tHeight, ;
         {|| &cAction }, ;
         NIL, ;
         .F., ;
         .F., ;
         .T. ;
         )

      SetToolTip ( GetControlHandle ( cMacroTemp, '_HMG_PRINTER_SHOWTHUMBNAILS' ), _hmg_printer_usermessages[ 01 ] + ' ' + AllTrim( Str( i ) ) + ' [Click]', ttHandle )

   NEXT i

   HideWindow ( GetFormHandle ( "_HMG_PRINTER_Wait" ) )
RETURN

/*
 * Routine: _hmg_printer_ThumbnailToggle()
 *
 * Purpose:
 *   Toggles the visibility state of the thumbnail panel.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Toggles the value of the thumbnail checkbutton in the navigation palette.
 *   - Triggers the thumbnail processing routine.
 */
STATIC PROCEDURE _hmg_printer_ThumbnailToggle()

   _HMG_PRINTER_PPNAV.thumbswitch.VALUE := ! _HMG_PRINTER_PPNAV.thumbswitch.VALUE

   _HMG_PRINTER_ProcessTHUMBNAILS()
RETURN

/*
 * Routine: _HMG_PRINTER_ProcessTHUMBNAILS()
 *
 * Purpose:
 *   Processes the layout and visibility of the thumbnail panel based on the checkbutton state.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Generates thumbnails if enabling the panel.
 *   - Adjusts the width, position, and zoom factor of the main preview window.
 *   - Shows or hides the _HMG_PRINTER_SHOWTHUMBNAILS window.
 *   - Refreshes the preview display.
 */
PROCEDURE _HMG_PRINTER_ProcessTHUMBNAILS()

   IF _HMG_PRINTER_PPNAV.thumbswitch.VALUE == .T.

      CreateThumbNails()

      _hmg_printer_zoomclick_xoffset := 90

      _hmg_printer_SizeFactor := GetDesktopHeight() / _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) * 0.58

      _HMG_PRINTER_SHOWPREVIEW.WIDTH := GetDesktopWidth() - 148 - IF ( IsVistaThemed, 30, 0 )

      _HMG_PRINTER_SHOWPREVIEW.COL := 138 + IF ( IsVistaThemed, 20, 0 )

      _HMG_PRINTER_PREVIEWRefresh()

      ShowWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) )

   ELSE

      _hmg_printer_zoomclick_xoffset := 0

      _hmg_printer_SizeFactor := GetDesktopHeight() / _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) * 0.63

      _HMG_PRINTER_SHOWPREVIEW.WIDTH := GetDesktopWidth() - 103

      _HMG_PRINTER_SHOWPREVIEW.COL := 51

      HideWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) )

      _HMG_PRINTER_PPNAV.SetFocus

   ENDIF
RETURN

/*
 * Routine: _hmg_printer_savepages()
 *
 * Purpose:
 *   Saves the temporary EMF preview pages to a user-specified destination directory.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Displays a file save dialog to the user.
 *   - Copies temporary EMF files to the selected destination path with sequential numbering.
 */
PROCEDURE _hmg_printer_savepages
   LOCAL c, i, f, t, d, x, a

   // Prompt the user to select a destination path and filename for the EMF files
   x := Putfile ( { { 'Images', '*.emf' } }, , GetCurrentFolder(), .T. )

   IF Empty( x )
      RETURN
   ENDIF

   x := cFilePath( x ) + hb_ps() + cFileNoExt( x )

   t := GetTempFolder() + hb_ps()

   // Retrieve the list of temporary EMF files generated for this session
   c := ADir ( t + _hmg_printer_timestamp + "_hmg_print_preview_*.Emf" )

   a := Array( c )

   ADir ( t + _hmg_printer_timestamp + "_hmg_print_preview_*.Emf", a )

   FOR i := 1 TO c
      f := t + a[ i ]
      d := x + '_' + StrZero ( i, 4 ) + '.emf'
      COPY File ( F ) TO ( D )
   NEXT i
RETURN

/*
 * Routine: _HMG_PRINTER_GO_TO_PAGE()
 *
 * Purpose:
 *   Displays the "Go To Page" dialog to allow direct page navigation.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Disables the navigation palette, thumbnail window, and main preview window.
 *   - Displays the modal-like _HMG_PRINTER_GO_TO_PAGE child window.
 */
PROCEDURE _HMG_PRINTER_GO_TO_PAGE

   DisableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) )

   DisableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) )

   DisableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) )

   ShowWindow ( GetFormHandle ( "_HMG_PRINTER_GO_TO_PAGE" ) )
RETURN

/*
 * Routine: _HMG_PRINTER_hScrollBoxProcess()
 *
 * Purpose:
 *   Processes horizontal scrollbar movements to pan the zoomed preview image.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Updates the horizontal offset variable (_hmg_printer_Dx).
 *   - Refreshes the preview display.
 */
STATIC PROCEDURE _HMG_PRINTER_hScrollBoxProcess()
   LOCAL Sp

   Sp := GetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ )

   _hmg_printer_Dx := -( Sp - 50 ) * 10

   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _HMG_PRINTER_vScrollBoxProcess()
 *
 * Purpose:
 *   Processes vertical scrollbar movements to pan the zoomed preview image.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Updates the vertical offset variable (_hmg_printer_Dy).
 *   - Refreshes the preview display.
 */
STATIC PROCEDURE _HMG_PRINTER_vScrollBoxProcess()
   LOCAL Sp

   Sp := GetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT )

   _hmg_printer_Dy := -( Sp - 50 ) * 10

   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _HMG_PRINTER_PreviewClose()
 *
 * Purpose:
 *   Closes the print preview interface and cleans up temporary resources.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Deletes temporary EMF files.
 *   - Releases all preview-related windows from memory.
 */
PROCEDURE _HMG_PRINTER_PreviewClose()

   _HMG_PRINTER_CleanPreview()

   _HMG_PRINTER_WAIT.RELEASE
   _HMG_PRINTER_SHOWTHUMBNAILS.RELEASE
   _HMG_PRINTER_SHOWPREVIEW.RELEASE
   _HMG_PRINTER_GO_TO_PAGE.RELEASE
   _HMG_PRINTER_PRINTPAGES.RELEASE
   _HMG_PRINTER_PPNAV.RELEASE
RETURN

/*
 * Routine: _HMG_PRINTER_CleanPreview()
 *
 * Purpose:
 *   Deletes all temporary EMF files generated for the current print preview session.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Deletes files matching the session timestamp pattern from the temporary directory.
 */
STATIC PROCEDURE _HMG_PRINTER_CleanPreview
   LOCAL t := GetTempFolder() + hb_ps()

   // Delete all temporary EMF files associated with the current session timestamp
   AEval( Directory( t + _hmg_printer_timestamp + "_hmg_print_preview_*.Emf" ), ;
      {| file | FErase( t + file[ 1 ] ) } )
RETURN

/*
 * Routine: _HMG_PRINTER_PREVIEWRefresh()
 *
 * Purpose:
 *   Refreshes the print preview display, updating the current page and synchronizing thumbnails.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Validates and constrains the current page number.
 *   - Automatically scrolls the thumbnail panel to keep the active page thumbnail visible.
 *   - Invalidates the preview window client area and redraws the EMF page.
 *   - Updates the preview window title with the current page progress.
 */
PROCEDURE _HMG_PRINTER_PREVIEWRefresh
   LOCAL hwnd
   LOCAL nRow
   LOCAL nScrollMax

   IF _IsControlDefined ( 'Image' + AllTrim( Str( _hmg_printer_CurrentPageNumber ) ), '_HMG_PRINTER_SHOWTHUMBNAILS' ) .AND. _HMG_PRINTER_THUMBUPDATE == .T. .AND. _hmg_printer_thumbscroll == .T.

      // Synchronize the thumbnail panel scrollbar position with the active page
      IF _hmg_printer_PrevPageNumber != _hmg_printer_CurrentPageNumber

         _hmg_printer_PrevPageNumber := _hmg_printer_CurrentPageNumber
         hwnd := GetFormHandle( '_HMG_PRINTER_SHOWTHUMBNAILS' )
         nRow := GetProperty ( '_HMG_PRINTER_SHOWTHUMBNAILS', 'Image' + AllTrim( Str( _hmg_printer_CurrentPageNumber ) ), 'Row' )
         nScrollMax := GetScrollRangeMax ( hwnd, SB_VERT )

         IF _hmg_printer_PageCount == _hmg_printer_CurrentPageNumber

            IF GetScrollPos( hwnd, SB_VERT ) != nScrollMax
               _HMG_SETVSCROLLVALUE ( hwnd, nScrollMax )
            ENDIF

         ELSEIF _hmg_printer_CurrentPageNumber == 1

            IF GetScrollPos( hwnd, SB_VERT ) != 0
               _HMG_SETVSCROLLVALUE ( hwnd, 0 )
            ENDIF

         ELSE

            IF ( nRow - 9 ) < nScrollMax
               _HMG_SETVSCROLLVALUE ( hwnd, nRow - 9 )
            ELSE
               IF GetScrollPos( hwnd, SB_VERT ) != nScrollMax
                  _HMG_SETVSCROLLVALUE ( hwnd, nScrollMax )
               ENDIF
            ENDIF

         ENDIF

      ENDIF

   ENDIF

   IF _hmg_printer_CurrentPageNumber < 1
      _hmg_printer_CurrentPageNumber := 1
      PlayBeep()
      RETURN
   ENDIF

   IF _hmg_printer_CurrentPageNumber > _hmg_printer_PageCount
      _hmg_printer_CurrentPageNumber := _hmg_printer_PageCount
      PlayBeep()
      RETURN
   ENDIF

   InvalidateRect ( GetFormHandle ( '_HMG_PRINTER_SHOWPREVIEW' ), 0 )

   // Render the EMF page onto the preview window using the current zoom and offsets
   _HMG_PRINTER_SHOWPAGE ( _hmg_printer_BasePageName + StrZero( _hmg_printer_CurrentPageNumber, 4 ) + ".emf", GetFormHandle ( '_HMG_PRINTER_SHOWPREVIEW' ), _hmg_printer_hdc_bak, _hmg_printer_SizeFactor * 10000, _hmg_printer_Dz, _hmg_printer_Dx, _hmg_printer_Dy )

   _HMG_PRINTER_SHOWPREVIEW.TITLE := _hmg_printer_usermessages[ 01 ] + ' [' + AllTrim( Str( _hmg_printer_CurrentPageNumber ) ) + '/' + AllTrim( Str( _hmg_printer_PageCount ) ) + ']'
RETURN

/*
 * Routine: _HMG_PRINTER_PrintPages()
 *
 * Purpose:
 *   Displays the print dialog to configure page ranges, copies, and collation before printing.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Disables the main preview, thumbnail, and navigation windows.
 *   - Resets and configures control states on the _HMG_PRINTER_PRINTPAGES dialog.
 *   - Displays the _HMG_PRINTER_PRINTPAGES window.
 */
PROCEDURE _HMG_PRINTER_PrintPages

   DIsableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) )
   DIsableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) )
   DIsableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) )

   _HMG_PRINTER_PRINTPAGES.Radio_1.VALUE := 1

   _HMG_PRINTER_PRINTPAGES.Label_1.Enabled := .F.
   _HMG_PRINTER_PRINTPAGES.Label_2.Enabled := .F.
   _HMG_PRINTER_PRINTPAGES.Label_4.Enabled := .F.
   _HMG_PRINTER_PRINTPAGES.Spinner_1.Enabled := .F.
   _HMG_PRINTER_PRINTPAGES.Spinner_2.Enabled := .F.
   _HMG_PRINTER_PRINTPAGES.Combo_1.Enabled := .F.
   _HMG_PRINTER_PRINTPAGES.CheckBox_1.Enabled := .F.

   IF _hmg_printer_usercopies == .T. ;
         .OR. ;
         _hmg_printer_usercollate == .T.

      _HMG_PRINTER_PRINTPAGES.Spinner_3.Enabled := .F.

   ENDIF

   ShowWindow ( GetFormHandle ( "_HMG_PRINTER_PRINTPAGES" ) )
RETURN

/*
 * Routine: _HMG_PRINTER_PrintPagesDo()
 *
 * Purpose:
 *   Executes the actual printing process by sending the selected EMF pages to the printer.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Initiates a print job via the Windows Spooler.
 *   - Iterates through the specified page range, applying odd/even filters, copies, and collation.
 *   - Sends EMF pages to the printer device context.
 *   - Closes the print job and re-enables the preview interface windows.
 */
PROCEDURE _HMG_PRINTER_PrintPagesDo
   LOCAL i
   LOCAL PageFrom
   LOCAL PageTo
   LOCAL p
   LOCAL OddOnly := .F.
   LOCAL EvenOnly := .F.

   IF _HMG_PRINTER_PrintPages.Radio_1.VALUE == 1

      PageFrom := 1
      PageTo := _hmg_printer_PageCount

   ELSEIF _HMG_PRINTER_PrintPages.Radio_1.VALUE == 2

      PageFrom := _HMG_PRINTER_PrintPages.Spinner_1.VALUE
      PageTo := _HMG_PRINTER_PrintPages.Spinner_2.VALUE

      IF _HMG_PRINTER_PrintPages.Combo_1.VALUE == 2
         OddOnly := .T.
      ELSEIF _HMG_PRINTER_PrintPages.Combo_1.VALUE == 3
         EvenOnly := .T.
      ENDIF

   ENDIF

   // Start the print document job in the Windows Spooler
   _hmg_printer_JobId := _HMG_PRINTER_StartDoc ( _hmg_printer_hdc_bak, _hmg_printer_JobName )

   // Store print job metadata in the user-specified global variable if defined
   If ! Empty ( _hmg_printer_JobData )
      IF __mvExist( _hmg_printer_JobData )
         __mvPut( _hmg_printer_JobData, OpenPrinterGetJobData() )
      ELSE
         MsgMiniGuiError ( "START PRINTDOC STOREJOBDATA: " + _hmg_printer_JobData + " must be declared as Public or Private." )
      ENDIF
   ENDIF

   // Print a single copy of the selected page range
   IF _HMG_PRINTER_PrintPages.Spinner_3.VALUE == 1 // Copies

      FOR i := PageFrom TO PageTo

         IF OddOnly == .T.
            IF i / 2 != Int ( i / 2 )
               _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
            ENDIF
         ELSEIF EvenOnly == .T.
            IF i / 2 == Int ( i / 2 )
               _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
            ENDIF
         ELSE
            _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
         ENDIF

      NEXT i

   ELSE

      // Print uncollated copies (e.g., Page 1, Page 1, Page 2, Page 2)
      IF _HMG_PRINTER_PrintPages.CheckBox_1.VALUE == .F.

         FOR p := 1 TO _HMG_PRINTER_PrintPages.Spinner_3.VALUE

            FOR i := PageFrom TO PageTo

               IF OddOnly == .T.
                  IF i / 2 != Int ( i / 2 )
                     _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
                  ENDIF
               ELSEIF EvenOnly == .T.
                  IF i / 2 == Int ( i / 2 )
                     _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
                  ENDIF
               ELSE
                  _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
               ENDIF

            NEXT i

         NEXT p

      ELSE

         // Print collated copies (e.g., Page 1, Page 2, Page 1, Page 2)
         FOR i := PageFrom TO PageTo

            FOR p := 1 TO _HMG_PRINTER_PrintPages.Spinner_3.VALUE

               IF OddOnly == .T.
                  IF i / 2 != Int ( i / 2 )
                     _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
                  ENDIF
               ELSEIF EvenOnly == .T.
                  IF i / 2 == Int ( i / 2 )
                     _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
                  ENDIF
               ELSE
                  _HMG_PRINTER_PRINTPAGE ( _hmg_printer_hdc_bak, _hmg_printer_BasePageName + StrZero( i, 4 ) + ".emf" )
               ENDIF

            NEXT p

         NEXT i

      ENDIF

   ENDIF

   // Finalize the print document job
   _HMG_PRINTER_ENDDOC ( _hmg_printer_hdc_bak )

   EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWPREVIEW" ) )
   EnableWindow ( GetFormHandle ( "_HMG_PRINTER_SHOWTHUMBNAILS" ) )
   EnableWindow ( GetFormHandle ( "_HMG_PRINTER_PPNAV" ) )

   HideWindow ( GetFormHandle ( "_HMG_PRINTER_PRINTPAGES" ) )

   _HMG_PRINTER_SHOWPREVIEW.setfocus
RETURN

/*
 * Routine: _HMG_PRINTER_ScrollLeft()
 *
 * Purpose:
 *   Scrolls the zoomed preview image to the left.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Adjusts the horizontal offset (_hmg_printer_Dx) and plays a beep if the boundary is reached.
 *   - Refreshes the preview display.
 */
STATIC PROCEDURE _HMG_PRINTER_ScrollLeft

   _hmg_printer_Dx := _hmg_printer_Dx + _hmg_printer_scrollstep
   IF _hmg_printer_Dx >= 500
      _hmg_printer_Dx := 500
      PlayBeep()
   ENDIF
   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _HMG_PRINTER_ScrollRight()
 *
 * Purpose:
 *   Scrolls the zoomed preview image to the right.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Adjusts the horizontal offset (_hmg_printer_Dx) and plays a beep if the boundary is reached.
 *   - Refreshes the preview display.
 */
STATIC PROCEDURE _HMG_PRINTER_ScrollRight

   _hmg_printer_Dx := _hmg_printer_Dx - _hmg_printer_scrollstep
   IF _hmg_printer_Dx <= -500
      _hmg_printer_Dx := -500
      PlayBeep()
   ENDIF
   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _HMG_PRINTER_ScrollUp()
 *
 * Purpose:
 *   Scrolls the zoomed preview image upward.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Adjusts the vertical offset (_hmg_printer_Dy) and plays a beep if the boundary is reached.
 *   - Refreshes the preview display.
 */
STATIC PROCEDURE _HMG_PRINTER_ScrollUp

   _hmg_printer_Dy := _hmg_printer_Dy + _hmg_printer_scrollstep
   IF _hmg_printer_Dy >= 500
      _hmg_printer_Dy := 500
      PlayBeep()
   ENDIF
   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _HMG_PRINTER_ScrollDown()
 *
 * Purpose:
 *   Scrolls the zoomed preview image downward.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Adjusts the vertical offset (_hmg_printer_Dy) and plays a beep if the boundary is reached.
 *   - Refreshes the preview display.
 */
STATIC PROCEDURE _HMG_PRINTER_ScrollDown

   _hmg_printer_Dy := _hmg_printer_Dy - _hmg_printer_scrollstep
   IF _hmg_printer_Dy <= -500
      _hmg_printer_Dy := -500
      PlayBeep()
   ENDIF

   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: GetPrinter()
 *
 * Purpose:
 *   Displays a modal dialog allowing the user to select from the installed system printers.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   Character - The name of the selected printer, or an empty string if cancelled.
 *
 * Side Effects:
 *   - Initializes user messages if not already initialized.
 *   - Defines and activates the modal window _HMG_PRINTER_GETPRINTER.
 */
FUNCTION GetPrinter()
   LOCAL RetVal := ''
   LOCAL Printers := ASort ( aPrinters() )
   LOCAL cDefaultPrinter := GetDefaultPrinter()
   LOCAL i
   LOCAL nInitPosition := 0

   FOR i := 1 TO Len ( Printers )

      IF Printers[ i ] == cDefaultPrinter
         nInitPosition := i
         EXIT
      ENDIF

   NEXT i

   IF Type ( '_HMG_MINIPRINT[22]' ) == "U"
      _hmg_printer_InitUserMessages()
   ENDIF

   DEFINE WINDOW _HMG_PRINTER_GETPRINTER ;
         AT 0, 0 ;
         WIDTH 345 ;
         HEIGHT GetTitleHeight() + 100 ;
         TITLE _hmg_printer_usermessages[ 13 ] ;
         MODAL ;
         NOSIZE

      @ 15, 10 COMBOBOX Combo_1 ITEMS Printers VALUE nInitPosition WIDTH 320 ;
         ON ENTER _HMG_PRINTER_GETPRINTER.Ok.OnClick () ;
         ON CANCEL If ( _GetKeyState ( VK_ESCAPE ), _HMG_PRINTER_GETPRINTER.Cancel.OnClick (), )

      @ 53, 65 BUTTON Ok CAPTION _hmg_printer_usermessages[ 11 ] ACTION ( RetVal := Printers[ GetProperty ( '_HMG_PRINTER_GETPRINTER', 'Combo_1', 'Value' ) ], DoMethod( '_HMG_PRINTER_GETPRINTER', 'Release' ) )

      @ 53, 175 BUTTON Cancel CAPTION _hmg_printer_usermessages[ 12 ] ACTION ( RetVal := '', DoMethod( '_HMG_PRINTER_GETPRINTER', 'Release' ) )

      ON KEY ESCAPE ACTION _HMG_PRINTER_GETPRINTER.Cancel.OnClick ()
   END WINDOW

   CENTER WINDOW _HMG_PRINTER_GETPRINTER

   ACTIVATE WINDOW _HMG_PRINTER_GETPRINTER
RETURN RetVal

#define TA_CENTER 6
#define TA_LEFT  0
#define TA_RIGHT 2

/*
 * Routine: _HMG_PRINTER_H_PRINT()
 *
 * Purpose:
 *   Prints a single line of text on the specified printer device context with custom formatting.
 *
 * Parameters:
 *   nHdc - Numeric - Device context handle.
 *   nRow - Numeric - Row position in millimeters.
 *   nCol - Numeric - Column position in millimeters.
 *   cFontName - Character - Font name.
 *   nFontSize - Numeric - Font size.
 *   nColor1 - Numeric - Red color component (0-255).
 *   nColor2 - Numeric - Green color component (0-255).
 *   nColor3 - Numeric - Blue color component (0-255).
 *   cText - Any - The text or value to print (automatically converted to string).
 *   lbold - Logical - Bold attribute flag.
 *   litalic - Logical - Italic attribute flag.
 *   lunderline - Logical - Underline attribute flag.
 *   lstrikeout - Logical - Strikeout attribute flag.
 *   lcolor - Logical - Custom color flag.
 *   lfont - Logical - Custom font flag.
 *   lsize - Logical - Custom size flag.
 *   cAlign - Character - Text alignment ('CENTER', 'RIGHT', or 'LEFT').
 *   lAngle - Logical - Text rotation flag (optional).
 *   nAngle - Numeric - Rotation angle in degrees (optional).
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Converts coordinates from millimeters to printer units.
 *   - Temporarily alters and restores text alignment on the device context.
 *   - Draws text on the printer device context.
 */
PROCEDURE _HMG_PRINTER_H_PRINT ( nHdc, nRow, nCol, cFontName, nFontSize, nColor1, nColor2, nColor3, cText, lbold, litalic, lunderline, lstrikeout, lcolor, lfont, lsize, cAlign, lAngle, nAngle )
   LOCAL lAlignChanged := .F.

DEFAULT lAngle TO .F., ;
      nAngle TO 0

   // Convert non-character values to their string representations
   IF ValType ( cText ) == "N"
      cText := AllTrim( Str( cText ) )
   ELSEIF ValType ( cText ) == "D"
      cText := DToC ( cText )
   ELSEIF ValType ( cText ) == "L"
      cText := iif ( cText == .T., _hmg_printer_usermessages[ 24 ], _hmg_printer_usermessages[ 25 ] )
   ELSEIF ValType ( cText ) == "A"
      RETURN
   ELSEIF ValType ( cText ) == "B"
      RETURN
   ELSEIF ValType ( cText ) == "O"
      RETURN
   ELSEIF ValType ( cText ) == "U"
      RETURN
   ENDIF

   // Convert coordinates from millimeters to printer units (0.1 mm)
   nRow := Int ( nRow * 10000 / 254 )
   nCol := Int ( nCol * 10000 / 254 )

   // Apply text alignment settings to the device context
   IF ValType ( cAlign ) = 'C'
      IF UPPER ( cAlign ) = 'CENTER'
         SetTextAlign ( nHdc, TA_CENTER )
         lAlignChanged := .T.
      ELSEIF UPPER ( cAlign ) = 'RIGHT'
         SetTextAlign ( nHdc, TA_RIGHT )
         lAlignChanged := .T.
      ENDIF
   ENDIF

   // Convert angle to tenths of a degree as required by Win32 API
   IF lAngle
      nAngle *= 10
   ENDIF

   _HMG_PRINTER_C_PRINT ( nHdc, nRow, nCol, cFontName, nFontSize, nColor1, nColor2, nColor3, cText, lbold, litalic, lunderline, lstrikeout, lcolor, lfont, lsize, lAngle, nAngle )

   // Restore default left alignment on the device context
   IF lAlignChanged
      SetTextAlign ( nHdc, TA_LEFT )
   ENDIF
RETURN

/*
 * Routine: _HMG_PRINTER_H_MULTILINE_PRINT()
 *
 * Purpose:
 *   Prints multi-line wrapped text within a bounding box on the specified printer device context.
 *
 * Parameters:
 *   nHdc - Numeric - Device context handle.
 *   nRow - Numeric - Starting row position in millimeters.
 *   nCol - Numeric - Starting column position in millimeters.
 *   nToRow - Numeric - Ending row position in millimeters.
 *   nToCol - Numeric - Ending column position in millimeters.
 *   cFontName - Character - Font name.
 *   nFontSize - Numeric - Font size.
 *   nColor1 - Numeric - Red color component (0-255).
 *   nColor2 - Numeric - Green color component (0-255).
 *   nColor3 - Numeric - Blue color component (0-255).
 *   cText - Any - The text or value to print (automatically converted to string).
 *   lbold - Logical - Bold attribute flag.
 *   litalic - Logical - Italic attribute flag.
 *   lunderline - Logical - Underline attribute flag.
 *   lstrikeout - Logical - Strikeout attribute flag.
 *   lcolor - Logical - Custom color flag.
 *   lfont - Logical - Custom font flag.
 *   lsize - Logical - Custom size flag.
 *   cAlign - Character - Text alignment ('CENTER', 'RIGHT', or 'LEFT').
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Converts bounding box coordinates from millimeters to printer units.
 *   - Draws wrapped multi-line text on the printer device context.
 */
PROCEDURE _HMG_PRINTER_H_MULTILINE_PRINT ( nHdc, nRow, nCol, nToRow, nToCol, cFontName, nFontSize, nColor1, nColor2, nColor3, cText, lbold, litalic, lunderline, lstrikeout, lcolor, lfont, lsize, cAlign )
   LOCAL nAlign := TA_LEFT

   // Convert non-character values to their string representations
   IF ValType ( cText ) == "N"
      cText := AllTrim( Str( cText ) )
   ELSEIF ValType ( cText ) == "D"
      cText := DToC ( cText )
   ELSEIF ValType ( cText ) == "L"
      cText := iif ( cText == .T., _hmg_printer_usermessages[ 24 ], _hmg_printer_usermessages[ 25 ] )
   ELSEIF ValType ( cText ) == "A"
      RETURN
   ELSEIF ValType ( cText ) == "B"
      RETURN
   ELSEIF ValType ( cText ) == "O"
      RETURN
   ELSEIF ValType ( cText ) == "U"
      RETURN
   ENDIF

   // Convert coordinates from millimeters to printer units (0.1 mm)
   nRow := Int ( nRow * 10000 / 254 )
   nCol := Int ( nCol * 10000 / 254 )
   nToRow := Int ( nToRow * 10000 / 254 )
   nToCol := Int ( nToCol * 10000 / 254 )

   IF ValType ( cAlign ) = 'C'
      IF UPPER ( cAlign ) = 'CENTER'
         nAlign := TA_CENTER
      ELSEIF UPPER ( cAlign ) = 'RIGHT'
         nAlign := TA_RIGHT
      ENDIF
   ENDIF

   _HMG_PRINTER_C_MULTILINE_PRINT ( nHdc, nRow, nCol, cFontName, nFontSize, nColor1, nColor2, nColor3, cText, lbold, litalic, lunderline, lstrikeout, lcolor, lfont, lsize, nToRow, nToCol, nAlign )
RETURN

/*
 * Routine: _HMG_PRINTER_H_IMAGE()
 *
 * Purpose:
 *   Draws an image on the specified printer device context.
 *
 * Parameters:
 *   nHdc - Numeric - Device context handle.
 *   cImage - Character - File path or resource name of the image.
 *   nRow - Numeric - Row position in millimeters.
 *   nCol - Numeric - Column position in millimeters.
 *   nHeight - Numeric - Image height in millimeters.
 *   nWidth - Numeric - Image width in millimeters.
 *   lStretch - Logical - Stretch image flag.
 *   lTransparent - Logical - Transparent background flag.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Converts coordinates and dimensions from millimeters to printer units.
 *   - Renders the image on the printer device context.
 */
PROCEDURE _HMG_PRINTER_H_IMAGE ( nHdc, cImage, nRow, nCol, nHeight, nWidth, lStretch, lTransparent )

   nRow := Int ( nRow * 10000 / 254 )
   nCol := Int ( nCol * 10000 / 254 )
   nWidth := Int ( nWidth * 10000 / 254 )
   nHeight := Int ( nHeight * 10000 / 254 )

   _HMG_PRINTER_C_IMAGE ( nHdc, cImage, nRow, nCol, nHeight, nWidth, lStretch, lTransparent )
RETURN

/*
 * Routine: _HMG_PRINTER_H_LINE()
 *
 * Purpose:
 *   Draws a line on the specified printer device context.
 *
 * Parameters:
 *   nHdc - Numeric - Device context handle.
 *   nRow - Numeric - Starting row position in millimeters.
 *   nCol - Numeric - Starting column position in millimeters.
 *   nToRow - Numeric - Ending row position in millimeters.
 *   nToCol - Numeric - Ending column position in millimeters.
 *   nWidth - Numeric - Line width in millimeters (optional).
 *   nColor1 - Numeric - Red color component (0-255).
 *   nColor2 - Numeric - Green color component (0-255).
 *   nColor3 - Numeric - Blue color component (0-255).
 *   lwidth - Logical - Custom width flag.
 *   lcolor - Logical - Custom color flag.
 *   nstyle - Numeric - Line style index (optional).
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Converts coordinates and width from millimeters to printer units.
 *   - Draws the line on the printer device context.
 */
PROCEDURE _HMG_PRINTER_H_LINE ( nHdc, nRow, nCol, nToRow, nToCol, nWidth, nColor1, nColor2, nColor3, lwidth, lcolor, nstyle )

   nRow := Int ( nRow * 10000 / 254 )
   nCol := Int ( nCol * 10000 / 254 )
   nToRow := Int ( nToRow * 10000 / 254 )
   nToCol := Int ( nToCol * 10000 / 254 )

DEFAULT nstyle TO 0

   // Resolve line width based on style or convert custom width to printer units
   IF ValType ( nWidth ) != 'U'
      nWidth := Int ( nWidth * 10000 / 254 )
   ELSEIF nstyle > 0
      IF nstyle == 1
         nWidth := 1
      ELSEIF nstyle == 2
         nWidth := 3
      ELSEIF nstyle == 3
         nWidth := 10
      ELSEIF nstyle == 4
         nWidth := 12
      ENDIF
      lwidth := .T.
   ENDIF

   _HMG_PRINTER_C_LINE ( nHdc, nRow, nCol, nToRow, nToCol, nWidth, nColor1, nColor2, nColor3, lwidth, lcolor, nstyle )
RETURN

/*
 * Routine: _HMG_PRINTER_H_RECTANGLE()
 *
 * Purpose:
 *   Draws a rectangle on the specified printer device context.
 *
 * Parameters:
 *   nHdc - Numeric - Device context handle.
 *   nRow - Numeric - Top row position in millimeters.
 *   nCol - Numeric - Left column position in millimeters.
 *   nToRow - Numeric - Bottom row position in millimeters.
 *   nToCol - Numeric - Right column position in millimeters.
 *   nWidth - Numeric - Border line width in millimeters (optional).
 *   nColor1 - Numeric - Red color component (0-255).
 *   nColor2 - Numeric - Green color component (0-255).
 *   nColor3 - Numeric - Blue color component (0-255).
 *   lwidth - Logical - Custom width flag.
 *   lcolor - Logical - Custom color flag.
 *   lfilled - Logical - Fill rectangle flag.
 *   lnoborder - Logical - Omit border flag.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Converts coordinates and border width from millimeters to printer units.
 *   - Draws the rectangle on the printer device context.
 */
PROCEDURE _HMG_PRINTER_H_RECTANGLE ( nHdc, nRow, nCol, nToRow, nToCol, nWidth, nColor1, nColor2, nColor3, lwidth, lcolor, lfilled, lnoborder )

   nRow := Int ( nRow * 10000 / 254 )
   nCol := Int ( nCol * 10000 / 254 )
   nToRow := Int ( nToRow * 10000 / 254 )
   nToCol := Int ( nToCol * 10000 / 254 )

   IF ValType ( nWidth ) != 'U'
      nWidth := Int ( nWidth * 10000 / 254 )
   ENDIF

   _HMG_PRINTER_C_RECTANGLE ( nHdc, nRow, nCol, nToRow, nToCol, nWidth, nColor1, nColor2, nColor3, lwidth, lcolor, lfilled, lnoborder )
RETURN

/*
 * Routine: _HMG_PRINTER_H_ROUNDRECTANGLE()
 *
 * Purpose:
 *   Draws a rounded rectangle on the specified printer device context.
 *
 * Parameters:
 *   nHdc - Numeric - Device context handle.
 *   nRow - Numeric - Top row position in millimeters.
 *   nCol - Numeric - Left column position in millimeters.
 *   nToRow - Numeric - Bottom row position in millimeters.
 *   nToCol - Numeric - Right column position in millimeters.
 *   nWidth - Numeric - Border line width in millimeters (optional).
 *   nColor1 - Numeric - Red color component (0-255).
 *   nColor2 - Numeric - Green color component (0-255).
 *   nColor3 - Numeric - Blue color component (0-255).
 *   lwidth - Logical - Custom width flag.
 *   lcolor - Logical - Custom color flag.
 *   lfilled - Logical - Fill rectangle flag.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Converts coordinates and border width from millimeters to printer units.
 *   - Draws the rounded rectangle on the printer device context.
 */
PROCEDURE _HMG_PRINTER_H_ROUNDRECTANGLE ( nHdc, nRow, nCol, nToRow, nToCol, nWidth, nColor1, nColor2, nColor3, lwidth, lcolor, lfilled )

   nRow := Int ( nRow * 10000 / 254 )
   nCol := Int ( nCol * 10000 / 254 )
   nToRow := Int ( nToRow * 10000 / 254 )
   nToCol := Int ( nToCol * 10000 / 254 )

   IF ValType ( nWidth ) != 'U'
      nWidth := Int ( nWidth * 10000 / 254 )
   ENDIF

   _HMG_PRINTER_C_ROUNDRECTANGLE ( nHdc, nRow, nCol, nToRow, nToCol, nWidth, nColor1, nColor2, nColor3, lwidth, lcolor, lfilled )
RETURN

/*
 * Routine: _hmg_printer_InitUserMessages()
 *
 * Purpose:
 *   Initializes global print preview variables and localized user interface messages.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Declares and populates the public array _HMG_MINIPRINT.
 *   - Populates the global _hmg_printer_usermessages array with localized strings
 *     based on the current language setting (supports CS, HR, EU, FR, DE, IT, PL, PT, RU, UK/UA, ES, FI, NL, SL, SK, HU, BG).
 */
PROCEDURE _hmg_printer_InitUserMessages

#ifdef _MULTILINGUAL_
   LOCAL cLang

#endif
   // Declare public array for miniprint state variables
   PUBLIC _HMG_MINIPRINT[ 27 ]

   _hmg_printer_name := ""
   _hmg_printer_JobId := 0
   _hmg_printer_usercopies := .F.
   _hmg_printer_usercollate := .F.

   _hmg_printer_usermessages := Array( 29 )

   _hmg_printer_usermessages[ 01 ] := 'Page'
   _hmg_printer_usermessages[ 02 ] := 'Print Preview'
   _hmg_printer_usermessages[ 03 ] := 'First Page [HOME]'
   _hmg_printer_usermessages[ 04 ] := 'Previous Page [PGUP]'
   _hmg_printer_usermessages[ 05 ] := 'Next Page [PGDN]'
   _hmg_printer_usermessages[ 06 ] := 'Last Page [END]'
   _hmg_printer_usermessages[ 07 ] := 'Go To Page'
   _hmg_printer_usermessages[ 08 ] := 'Zoom'
   _hmg_printer_usermessages[ 09 ] := 'Print'
   _hmg_printer_usermessages[ 10 ] := 'Page Number'
   _hmg_printer_usermessages[ 11 ] := 'Ok'
   _hmg_printer_usermessages[ 12 ] := 'Cancel'
   _hmg_printer_usermessages[ 13 ] := 'Select Printer'
   _hmg_printer_usermessages[ 14 ] := 'Collate Copies'
   _hmg_printer_usermessages[ 15 ] := 'Print Range'
   _hmg_printer_usermessages[ 16 ] := 'All'
   _hmg_printer_usermessages[ 17 ] := 'Pages'
   _hmg_printer_usermessages[ 18 ] := 'From'
   _hmg_printer_usermessages[ 19 ] := 'To'
   _hmg_printer_usermessages[ 20 ] := 'Copies'
   _hmg_printer_usermessages[ 21 ] := 'All Range'
   _hmg_printer_usermessages[ 22 ] := 'Odd Pages Only'
   _hmg_printer_usermessages[ 23 ] := 'Even Pages Only'
   _hmg_printer_usermessages[ 24 ] := 'Yes'
   _hmg_printer_usermessages[ 25 ] := 'No'
   _hmg_printer_usermessages[ 26 ] := 'Close'
   _hmg_printer_usermessages[ 27 ] := 'Save'
   _hmg_printer_usermessages[ 28 ] := 'Thumbnails'
   _hmg_printer_usermessages[ 29 ] := 'Generating Thumbnails... Please Wait...'

#ifdef _MULTILINGUAL_

   cLang := Upper( Left( Set ( _SET_LANGUAGE ), 2 ) )

   // LANGUAGE IS NOT SUPPORTED BY hb_langSelect() FUNCTION
   IF _HMG_LANG_ID == 'FI' // FINNISH
      cLang := 'FI'
   ENDIF

   DO CASE

   CASE cLang == "CS"
      /////////////////////////////////////////////////////////////
      // CZECH
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Strana'
	_hmg_printer_usermessages [02] := 'Náhled'
	_hmg_printer_usermessages [03] := 'První strana [HOME]'
	_hmg_printer_usermessages [04] := 'Pøedchozí strana [PGUP]'
	_hmg_printer_usermessages [05] := 'Další strana [PGDN]'
	_hmg_printer_usermessages [06] := 'Poslední strana [END]'
	_hmg_printer_usermessages [07] := 'Jdi na stranu'
	_hmg_printer_usermessages [08] := 'Lupa'
	_hmg_printer_usermessages [09] := 'Tisk'
	_hmg_printer_usermessages [10] := 'Èíslo strany'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Storno'
	_hmg_printer_usermessages [13] := 'Vyber tiskárnu'
	_hmg_printer_usermessages [14] := 'Tøídìní'
	_hmg_printer_usermessages [15] := 'Rozsah tisku'
	_hmg_printer_usermessages [16] := 'vše'
	_hmg_printer_usermessages [17] := 'strany'
	_hmg_printer_usermessages [18] := 'od'
	_hmg_printer_usermessages [19] := 'do'
	_hmg_printer_usermessages [20] := 'kopií'
	_hmg_printer_usermessages [21] := 'všechny strany'
	_hmg_printer_usermessages [22] := 'liché strany'
	_hmg_printer_usermessages [23] := 'sudé strany'
	_hmg_printer_usermessages [24] := 'Ano'
	_hmg_printer_usermessages [25] := 'No'
	_hmg_printer_usermessages [26] := 'Zavøi'
	_hmg_printer_usermessages [27] := 'Ulo'
	_hmg_printer_usermessages [28] := 'Miniatury'
	_hmg_printer_usermessages [29] := 'Generuji miniatury... Èekejte, prosím...'

   CASE cLang == "HR" // Croatian
      /////////////////////////////////////////////////////////////
      // CROATIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Page'
	_hmg_printer_usermessages [02] := 'Print Preview'
	_hmg_printer_usermessages [03] := 'First Page [HOME]'
	_hmg_printer_usermessages [04] := 'Previous Page [PGUP]'
	_hmg_printer_usermessages [05] := 'Next Page [PGDN]'
	_hmg_printer_usermessages [06] := 'Last Page [END]'
	_hmg_printer_usermessages [07] := 'Go To Page'
	_hmg_printer_usermessages [08] := 'Zoom'
	_hmg_printer_usermessages [09] := 'Print'
	_hmg_printer_usermessages [10] := 'Page Number'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Cancel'
	_hmg_printer_usermessages [13] := 'Select Printer'
	_hmg_printer_usermessages [14] := 'Collate Copies'
	_hmg_printer_usermessages [15] := 'Print Range'
	_hmg_printer_usermessages [16] := 'All'
	_hmg_printer_usermessages [17] := 'Pages'
	_hmg_printer_usermessages [18] := 'From'
	_hmg_printer_usermessages [19] := 'To'
	_hmg_printer_usermessages [20] := 'Copies'
	_hmg_printer_usermessages [21] := 'All Range'
	_hmg_printer_usermessages [22] := 'Odd Pages Only'
	_hmg_printer_usermessages [23] := 'Even Pages Only'
	_hmg_printer_usermessages [24] := 'Yes'
	_hmg_printer_usermessages [25] := 'No'
	_hmg_printer_usermessages [26] := 'Close'
	_hmg_printer_usermessages [27] := 'Save'
	_hmg_printer_usermessages [28] := 'Thumbnails'
	_hmg_printer_usermessages [29] := 'Generating Thumbnails... Please Wait...'

   CASE cLang == "EU" // Basque.
      /////////////////////////////////////////////////////////////
      // BASQUE
      ////////////////////////////////////////////////////////////

      _hmg_printer_usermessages[ 01 ] := 'Page'
      _hmg_printer_usermessages[ 02 ] := 'Print Preview'
      _hmg_printer_usermessages[ 03 ] := 'First Page [HOME]'
      _hmg_printer_usermessages[ 04 ] := 'Previous Page [PGUP]'
      _hmg_printer_usermessages[ 05 ] := 'Next Page [PGDN]'
      _hmg_printer_usermessages[ 06 ] := 'Last Page [END]'
      _hmg_printer_usermessages[ 07 ] := 'Go To Page'
      _hmg_printer_usermessages[ 08 ] := 'Zoom'
      _hmg_printer_usermessages[ 09 ] := 'Print'
      _hmg_printer_usermessages[ 10 ] := 'Page Number'
      _hmg_printer_usermessages[ 11 ] := 'Ok'
      _hmg_printer_usermessages[ 12 ] := 'Cancel'
      _hmg_printer_usermessages[ 13 ] := 'Select Printer'
      _hmg_printer_usermessages[ 14 ] := 'Collate Copies'
      _hmg_printer_usermessages[ 15 ] := 'Print Range'
      _hmg_printer_usermessages[ 16 ] := 'All'
      _hmg_printer_usermessages[ 17 ] := 'Pages'
      _hmg_printer_usermessages[ 18 ] := 'From'
      _hmg_printer_usermessages[ 19 ] := 'To'
      _hmg_printer_usermessages[ 20 ] := 'Copies'
      _hmg_printer_usermessages[ 21 ] := 'All Range'
      _hmg_printer_usermessages[ 22 ] := 'Odd Pages Only'
      _hmg_printer_usermessages[ 23 ] := 'Even Pages Only'
      _hmg_printer_usermessages[ 24 ] := 'Yes'
      _hmg_printer_usermessages[ 25 ] := 'No'
      _hmg_printer_usermessages[ 26 ] := 'Close'
      _hmg_printer_usermessages[ 27 ] := 'Save'
      _hmg_printer_usermessages[ 28 ] := 'Thumbnails'
      _hmg_printer_usermessages[ 29 ] := 'Generating Thumbnails... Please Wait...'

   CASE cLang == "FR" // French
      /////////////////////////////////////////////////////////////
      // FRENCH
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Page'
	_hmg_printer_usermessages [02] := "Aperçu avant impression"
	_hmg_printer_usermessages [03] := 'Première page [HOME]'
	_hmg_printer_usermessages [04] := 'Page précédente [PGUP]'
	_hmg_printer_usermessages [05] := 'Page suivante [PGDN]'
	_hmg_printer_usermessages [06] := 'Dernière page [END]'
	_hmg_printer_usermessages [07] := 'Allez page'
	_hmg_printer_usermessages [08] := 'Zoom'
	_hmg_printer_usermessages [09] := 'Imprimer'
	_hmg_printer_usermessages [10] := 'Page'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Annulation'
	_hmg_printer_usermessages [13] := "Sélection de l'imprimante"
	_hmg_printer_usermessages [14] := "Assemblez"
	_hmg_printer_usermessages [15] := "Paramètres d'impression"
	_hmg_printer_usermessages [16] := 'Tous'
	_hmg_printer_usermessages [17] := 'Pages'
	_hmg_printer_usermessages [18] := 'De'
	_hmg_printer_usermessages [19] := 'À'
	_hmg_printer_usermessages [20] := 'Copies'
	_hmg_printer_usermessages [21] := 'Toutes les pages'
	_hmg_printer_usermessages [22] := 'Pages Impaires'
	_hmg_printer_usermessages [23] := 'Pages Paires'
	_hmg_printer_usermessages [24] := 'Oui'
	_hmg_printer_usermessages [25] := 'Non'
	_hmg_printer_usermessages [26] := 'Fermer'
	_hmg_printer_usermessages [27] := 'Sauver'
	_hmg_printer_usermessages [28] := 'Affichettes'
	_hmg_printer_usermessages [29] := "Création des affichettes... Merci d'attendre..."

   CASE cLang == "DE" // German
      /////////////////////////////////////////////////////////////
      // GERMAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Seite'
	_hmg_printer_usermessages [02] := 'Druck Vorschau'
	_hmg_printer_usermessages [03] := 'Erste Seite [HOME]'
	_hmg_printer_usermessages [04] := 'Vorherige Seite [PGUP]'
	_hmg_printer_usermessages [05] := 'Nächste Seite [PGDN]'
	_hmg_printer_usermessages [06] := 'Letzte Seite [END]'
	_hmg_printer_usermessages [07] := 'Gehe zur Seite '
	_hmg_printer_usermessages [08] := 'Zoom'
	_hmg_printer_usermessages [09] := 'Drucken'
	_hmg_printer_usermessages [10] := 'Seite Nummer'
	_hmg_printer_usermessages [11] := 'Okay'
	_hmg_printer_usermessages [12] := 'Abbruch'
	_hmg_printer_usermessages [13] := 'Drucker wählen'
	_hmg_printer_usermessages [14] := 'Sortieren'
	_hmg_printer_usermessages [15] := 'Druckbereich Auswahl'
	_hmg_printer_usermessages [16] := 'Alle Seiten'
	_hmg_printer_usermessages [17] := 'Seiten'
	_hmg_printer_usermessages [18] := 'von'
	_hmg_printer_usermessages [19] := 'bis'
	_hmg_printer_usermessages [20] := 'Kopien'
	_hmg_printer_usermessages [21] := 'Alle Seiten'
	_hmg_printer_usermessages [22] := 'Nur ungerade Seiten'
	_hmg_printer_usermessages [23] := 'Nur gerade Seiten'
	_hmg_printer_usermessages [24] := 'Ja'
	_hmg_printer_usermessages [25] := 'Nein'
	_hmg_printer_usermessages [26] := 'Beenden'
	_hmg_printer_usermessages [27] := 'Speichern'
	_hmg_printer_usermessages [28] := 'Seitenvorschau'
	_hmg_printer_usermessages [29] := 'Erzeuge Vorschau...  Bitte warten...'

   CASE cLang == "IT" // Italian
      /////////////////////////////////////////////////////////////
      // ITALIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Pagina'
	_hmg_printer_usermessages [02] := 'Anteprima di stampa'
	_hmg_printer_usermessages [03] := 'Prima Pagina [HOME]'
	_hmg_printer_usermessages [04] := 'Pagina Precedente [PGUP]'
	_hmg_printer_usermessages [05] := 'Pagina Seguente [PGDN]'
	_hmg_printer_usermessages [06] := 'Ultima Pagina [END]'
	_hmg_printer_usermessages [07] := 'Vai Alla Pagina'
	_hmg_printer_usermessages [08] := 'Zoom'
	_hmg_printer_usermessages [09] := 'Stampa'
	_hmg_printer_usermessages [10] := 'Pagina'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Annulla'
	_hmg_printer_usermessages [13] := 'Selezioni Lo Stampatore'
	_hmg_printer_usermessages [14] := 'Fascicoli'
	_hmg_printer_usermessages [15] := 'Intervallo di stampa'
	_hmg_printer_usermessages [16] := 'Tutti'
	_hmg_printer_usermessages [17] := 'Pagine'
	_hmg_printer_usermessages [18] := 'Da'
	_hmg_printer_usermessages [19] := 'A'
	_hmg_printer_usermessages [20] := 'Copie'
	_hmg_printer_usermessages [21] := 'Tutte le pagine'
	_hmg_printer_usermessages [22] := 'Le Pagine Pari'
	_hmg_printer_usermessages [23] := 'Le Pagine Dispari'
	_hmg_printer_usermessages [24] := 'Si'
	_hmg_printer_usermessages [25] := 'No'
	_hmg_printer_usermessages [26] := 'Chiudi'
	_hmg_printer_usermessages [27] := 'Salva'
	_hmg_printer_usermessages [28] := 'Miniatura'
	_hmg_printer_usermessages [29] := 'Generando Miniatura...  Prego Attesa...'

   CASE cLang == "PL" // Polish
      /////////////////////////////////////////////////////////////
      // POLISH
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Strona'
	_hmg_printer_usermessages [02] := 'Podgl¹d wydruku'
	_hmg_printer_usermessages [03] := 'Pierwsza strona [HOME]'
	_hmg_printer_usermessages [04] := 'Poprzednia strona [PGUP]'
	_hmg_printer_usermessages [05] := 'Nastêpna strona [PGDN]'
	_hmg_printer_usermessages [06] := 'Ostatnia strona [END]'
	_hmg_printer_usermessages [07] := 'Skocz do strony'
	_hmg_printer_usermessages [08] := 'Powiêksz'
	_hmg_printer_usermessages [09] := 'Drukuj'
	_hmg_printer_usermessages [10] := 'Numer strony'
	_hmg_printer_usermessages [11] := 'Tak'
	_hmg_printer_usermessages [12] := 'Przerwij'
	_hmg_printer_usermessages [13] := 'Wybierz drukarkê'
	_hmg_printer_usermessages [14] := 'Sortuj kopie'
	_hmg_printer_usermessages [15] := 'Zakres wydruku'
	_hmg_printer_usermessages [16] := 'Wszystkie'
	_hmg_printer_usermessages [17] := 'Strony'
	_hmg_printer_usermessages [18] := 'Od'
	_hmg_printer_usermessages [19] := 'Do'
	_hmg_printer_usermessages [20] := 'Kopie'
	_hmg_printer_usermessages [21] := 'Wszystkie'
	_hmg_printer_usermessages [22] := 'Nieparzyste'
	_hmg_printer_usermessages [23] := 'Parzyste'
	_hmg_printer_usermessages [24] := 'Tak'
	_hmg_printer_usermessages [25] := 'Nie'
	_hmg_printer_usermessages [26] := 'Zamknij'
	_hmg_printer_usermessages [27] := 'Zapisz'
	_hmg_printer_usermessages [28] := 'Thumbnails'
	_hmg_printer_usermessages [29] := 'Generujê Thumbnails... Proszê czekaæ...'

   CASE cLang == "PT" // Portuguese
      /////////////////////////////////////////////////////////////
      // PORTUGUESE
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Página'
	_hmg_printer_usermessages [02] := 'Visualização da Impressão'
	_hmg_printer_usermessages [03] := 'Primeira Página [HOME]'
	_hmg_printer_usermessages [04] := 'Página Anterior [PGUP]'
	_hmg_printer_usermessages [05] := 'Página Seguinte [PGDN]'
	_hmg_printer_usermessages [06] := 'Última Página [END]'
	_hmg_printer_usermessages [07] := 'Ir Para a Página Nº'
	_hmg_printer_usermessages [08] := 'Ampliar'
	_hmg_printer_usermessages [09] := 'Imprimir'
	_hmg_printer_usermessages [10] := 'Página'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Cancelar'
	_hmg_printer_usermessages [13] := 'Selecione a Impressora'
	_hmg_printer_usermessages [14] := 'Ordenar Cópias'
	_hmg_printer_usermessages [15] := 'Intervalo de Impressão'
	_hmg_printer_usermessages [16] := 'Tudo'
	_hmg_printer_usermessages [17] := 'Páginas'
	_hmg_printer_usermessages [18] := 'De'
	_hmg_printer_usermessages [19] := 'Até'
	_hmg_printer_usermessages [20] := 'Nº de Cópias'
	_hmg_printer_usermessages [21] := 'Todas as Páginas'
	_hmg_printer_usermessages [22] := ' Somente Páginas Impares'
	_hmg_printer_usermessages [23] := ' Somente Páginas Pares'
	_hmg_printer_usermessages [24] := 'Sim'
	_hmg_printer_usermessages [25] := 'Não'
	_hmg_printer_usermessages [26] := 'Fechar'
	_hmg_printer_usermessages [27] := 'Salvar'
	_hmg_printer_usermessages [28] := 'Miniaturas'
	_hmg_printer_usermessages [29] := 'Aguarde, Gerando Miniaturas...'

   CASE cLang == "RU" // Russian
      /////////////////////////////////////////////////////////////
      // RUSSIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Ñòğàíèöà'
	_hmg_printer_usermessages [02] := 'Ïğåäâàğèòåëüíûé ïğîñìîòğ'
	_hmg_printer_usermessages [03] := 'Ïåğâàÿ [HOME]'
	_hmg_printer_usermessages [04] := 'Ïğåäûäóùàÿ [PGUP]'
	_hmg_printer_usermessages [05] := 'Ñëåäóşùàÿ [PGDN]'
	_hmg_printer_usermessages [06] := 'Ïîñëåäíÿÿ [END]'
	_hmg_printer_usermessages [07] := 'Ïåğåéòè ê'
	_hmg_printer_usermessages [08] := 'Ìàñøòàá'
	_hmg_printer_usermessages [09] := 'Ïå÷àòü'
	_hmg_printer_usermessages [10] := 'Ñòğàíèöà ¹'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Îòìåíà'
	_hmg_printer_usermessages [13] := 'Âûáîğ ïğèíòåğà'
	_hmg_printer_usermessages [14] := 'Ñîğòèğîâêà êîïèé'
	_hmg_printer_usermessages [15] := 'Èíòåğâàë ïå÷àòè'
	_hmg_printer_usermessages [16] := 'Âñå'
	_hmg_printer_usermessages [17] := 'Ñòğàíèöû'
	_hmg_printer_usermessages [18] := 'Îò'
	_hmg_printer_usermessages [19] := 'Äî'
	_hmg_printer_usermessages [20] := 'Êîïèé'
	_hmg_printer_usermessages [21] := 'Âåñü èíòåğâàë'
	_hmg_printer_usermessages [22] := 'Íå÷åòíûå òîëüêî'
	_hmg_printer_usermessages [23] := '×åòíûå òîëüêî'
	_hmg_printer_usermessages [24] := 'Äà'
	_hmg_printer_usermessages [25] := 'Íåò'
	_hmg_printer_usermessages [26] := 'Çàêğûòü'
	_hmg_printer_usermessages [27] := 'Ñîõğàíèòü'
	_hmg_printer_usermessages [28] := 'Ìèíèàòşğû'
	_hmg_printer_usermessages [29] := 'Æäèòå, ãåíåğèğóş ìèíèàòşğû...'

   CASE cLang == "UK" .OR. cLang == "UA" // Ukrainian
      /////////////////////////////////////////////////////////////
      // UKRAINIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Ñòîğ³íêà'
	_hmg_printer_usermessages [02] := 'Ïîïåğåäí³é ïåğåãëÿä'
	_hmg_printer_usermessages [03] := 'Ïåğøà [HOME]'
	_hmg_printer_usermessages [04] := 'Ïîïåğåäíÿ [PGUP]'
	_hmg_printer_usermessages [05] := 'Íàñòóïíà [PGDN]'
	_hmg_printer_usermessages [06] := 'Îñòàííÿ [END]'
	_hmg_printer_usermessages [07] := 'Ïåğåéòè äî'
	_hmg_printer_usermessages [08] := 'Ìàñøòàá'
	_hmg_printer_usermessages [09] := 'Äğóê'
	_hmg_printer_usermessages [10] := 'Ñòîğ³íêà ¹'
	_hmg_printer_usermessages [11] := 'Ãàğàçä'
	_hmg_printer_usermessages [12] := 'Â³äìîâà'
	_hmg_printer_usermessages [13] := 'Âèá³ğ ïğèíòåğà'
	_hmg_printer_usermessages [14] := 'Ñîğòóâàííÿ êîï³é'
	_hmg_printer_usermessages [15] := '²íòåğâàë äğóêó'
	_hmg_printer_usermessages [16] := 'Óñ³'
	_hmg_printer_usermessages [17] := 'Ñòîğ³íêè'
	_hmg_printer_usermessages [18] := 'Ç'
	_hmg_printer_usermessages [19] := 'Ïî'
	_hmg_printer_usermessages [20] := 'Êîï³é'
	_hmg_printer_usermessages [21] := 'Âåñü ³íòåğâàë'
	_hmg_printer_usermessages [22] := 'Ò³ëüêè íåïàğí³'
	_hmg_printer_usermessages [23] := 'Ò³ëüêè ïàğí³'
	_hmg_printer_usermessages [24] := 'Òàê'
	_hmg_printer_usermessages [25] := 'Í³'
	_hmg_printer_usermessages [26] := 'Çàêğèòè'
	_hmg_printer_usermessages [27] := 'Çáåğåãòè'
	_hmg_printer_usermessages [28] := 'Ì³í³àòşğè'
	_hmg_printer_usermessages [29] := 'Î÷³êóéòå, ãåíåğóş ì³í³àòşğè...'

   CASE cLang == "ES" // Spanish
      /////////////////////////////////////////////////////////////
      // SPANISH
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Página'
	_hmg_printer_usermessages [02] := 'Vista Previa'
	_hmg_printer_usermessages [03] := 'Inicio [INICIO]'
	_hmg_printer_usermessages [04] := 'Anterior [REPAG]'
	_hmg_printer_usermessages [05] := 'Siguiente [AVPAG]'
	_hmg_printer_usermessages [06] := 'Fin [FIN]'
	_hmg_printer_usermessages [07] := 'Ir a'
	_hmg_printer_usermessages [08] := 'Zoom'
	_hmg_printer_usermessages [09] := 'Imprimir'
	_hmg_printer_usermessages [10] := 'Página Nro.'
	_hmg_printer_usermessages [11] := 'Aceptar'
	_hmg_printer_usermessages [12] := 'Cancelar'
	_hmg_printer_usermessages [13] := 'Seleccionar Impresora'
	_hmg_printer_usermessages [14] := 'Ordenar Copias'
	_hmg_printer_usermessages [15] := 'Rango de Impresión'
	_hmg_printer_usermessages [16] := 'Todo'
	_hmg_printer_usermessages [17] := 'Páginas'
	_hmg_printer_usermessages [18] := 'Desde'
	_hmg_printer_usermessages [19] := 'Hasta'
	_hmg_printer_usermessages [20] := 'Copias'
	_hmg_printer_usermessages [21] := 'Todo El Rango'
	_hmg_printer_usermessages [22] := 'Solo Páginas Impares'
	_hmg_printer_usermessages [23] := 'Solo Páginas Pares'
	_hmg_printer_usermessages [24] := 'Si'
	_hmg_printer_usermessages [25] := 'No'
	_hmg_printer_usermessages [26] := 'Cerrar'
	_hmg_printer_usermessages [27] := 'Guardar'
	_hmg_printer_usermessages [28] := 'Miniaturas'
	_hmg_printer_usermessages [29] := 'Generando Miniaturas... Espere Por Favor...'

   CASE cLang == "FI" // Finnish
      ///////////////////////////////////////////////////////////////////////
      // FINNISH
      ///////////////////////////////////////////////////////////////////////

      _hmg_printer_usermessages[ 01 ] := 'Page'
      _hmg_printer_usermessages[ 02 ] := 'Print Preview'
      _hmg_printer_usermessages[ 03 ] := 'First Page [HOME]'
      _hmg_printer_usermessages[ 04 ] := 'Previous Page [PGUP]'
      _hmg_printer_usermessages[ 05 ] := 'Next Page [PGDN]'
      _hmg_printer_usermessages[ 06 ] := 'Last Page [END]'
      _hmg_printer_usermessages[ 07 ] := 'Go To Page'
      _hmg_printer_usermessages[ 08 ] := 'Zoom'
      _hmg_printer_usermessages[ 09 ] := 'Print'
      _hmg_printer_usermessages[ 10 ] := 'Page Number'
      _hmg_printer_usermessages[ 11 ] := 'Ok'
      _hmg_printer_usermessages[ 12 ] := 'Cancel'
      _hmg_printer_usermessages[ 13 ] := 'Select Printer'
      _hmg_printer_usermessages[ 14 ] := 'Collate Copies'
      _hmg_printer_usermessages[ 15 ] := 'Print Range'
      _hmg_printer_usermessages[ 16 ] := 'All'
      _hmg_printer_usermessages[ 17 ] := 'Pages'
      _hmg_printer_usermessages[ 18 ] := 'From'
      _hmg_printer_usermessages[ 19 ] := 'To'
      _hmg_printer_usermessages[ 20 ] := 'Copies'
      _hmg_printer_usermessages[ 21 ] := 'All Range'
      _hmg_printer_usermessages[ 22 ] := 'Odd Pages Only'
      _hmg_printer_usermessages[ 23 ] := 'Even Pages Only'
      _hmg_printer_usermessages[ 24 ] := 'Yes'
      _hmg_printer_usermessages[ 25 ] := 'No'
      _hmg_printer_usermessages[ 26 ] := 'Close'
      _hmg_printer_usermessages[ 27 ] := 'Save'
      _hmg_printer_usermessages[ 28 ] := 'Thumbnails'
      _hmg_printer_usermessages[ 29 ] := 'Generating Thumbnails... Please Wait...'

   CASE cLang == "NL" // Dutch
      /////////////////////////////////////////////////////////////
      // DUTCH
      ////////////////////////////////////////////////////////////

      _hmg_printer_usermessages[ 01 ] := 'Page'
      _hmg_printer_usermessages[ 02 ] := 'Print Preview'
      _hmg_printer_usermessages[ 03 ] := 'First Page [HOME]'
      _hmg_printer_usermessages[ 04 ] := 'Previous Page [PGUP]'
      _hmg_printer_usermessages[ 05 ] := 'Next Page [PGDN]'
      _hmg_printer_usermessages[ 06 ] := 'Last Page [END]'
      _hmg_printer_usermessages[ 07 ] := 'Go To Page'
      _hmg_printer_usermessages[ 08 ] := 'Zoom'
      _hmg_printer_usermessages[ 09 ] := 'Print'
      _hmg_printer_usermessages[ 10 ] := 'Page Number'
      _hmg_printer_usermessages[ 11 ] := 'Ok'
      _hmg_printer_usermessages[ 12 ] := 'Cancel'
      _hmg_printer_usermessages[ 13 ] := 'Select Printer'
      _hmg_printer_usermessages[ 14 ] := 'Collate Copies'
      _hmg_printer_usermessages[ 15 ] := 'Print Range'
      _hmg_printer_usermessages[ 16 ] := 'All'
      _hmg_printer_usermessages[ 17 ] := 'Pages'
      _hmg_printer_usermessages[ 18 ] := 'From'
      _hmg_printer_usermessages[ 19 ] := 'To'
      _hmg_printer_usermessages[ 20 ] := 'Copies'
      _hmg_printer_usermessages[ 21 ] := 'All Range'
      _hmg_printer_usermessages[ 22 ] := 'Odd Pages Only'
      _hmg_printer_usermessages[ 23 ] := 'Even Pages Only'
      _hmg_printer_usermessages[ 24 ] := 'Yes'
      _hmg_printer_usermessages[ 25 ] := 'No'
      _hmg_printer_usermessages[ 26 ] := 'Close'
      _hmg_printer_usermessages[ 27 ] := 'Save'
      _hmg_printer_usermessages[ 28 ] := 'Thumbnails'
      _hmg_printer_usermessages[ 29 ] := 'Generating Thumbnails... Please Wait...'

   CASE cLang == "SL" // Slovenian
      /////////////////////////////////////////////////////////////
      // SLOVENIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Stran'
	_hmg_printer_usermessages [02] := 'Predgled tiskanja'
	_hmg_printer_usermessages [03] := 'Prva stran [HOME]'
	_hmg_printer_usermessages [04] := 'Prej¹nja stran [PGUP]'
	_hmg_printer_usermessages [05] := 'Naslednja stran [PGDN]'
	_hmg_printer_usermessages [06] := 'Zadnja stran [END]'
	_hmg_printer_usermessages [07] := 'Pojdi na stran'
	_hmg_printer_usermessages [08] := 'Poveèava'
	_hmg_printer_usermessages [09] := 'Natisni'
	_hmg_printer_usermessages [10] := '©tevilka strani'
	_hmg_printer_usermessages [11] := 'V redu'
	_hmg_printer_usermessages [12] := 'Prekini'
	_hmg_printer_usermessages [13] := 'Izberi tiskalnik'
	_hmg_printer_usermessages [14] := 'Zbiranje kopij'
	_hmg_printer_usermessages [15] := 'Obseg tiskanja'
	_hmg_printer_usermessages [16] := 'Vse'
	_hmg_printer_usermessages [17] := 'Strani'
	_hmg_printer_usermessages [18] := 'od'
	_hmg_printer_usermessages [19] := 'do'
	_hmg_printer_usermessages [20] := 'Kopij'
	_hmg_printer_usermessages [21] := 'Ves obseg'
	_hmg_printer_usermessages [22] := 'Neparne strani'
	_hmg_printer_usermessages [23] := 'Parne strani'
	_hmg_printer_usermessages [24] := 'Ja'
	_hmg_printer_usermessages [25] := 'Ne'
	_hmg_printer_usermessages [26] := 'Zapri'
	_hmg_printer_usermessages [27] := 'Shrani'
	_hmg_printer_usermessages [28] := 'Slièice'
	_hmg_printer_usermessages [29] := 'Pripravljam slièice... prosim, poèakajte...'

   CASE cLang == "SK" // Slovak
      /////////////////////////////////////////////////////////////
      // SLOVAK
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Strana'
	_hmg_printer_usermessages [02] := 'Náh¾ad'
	_hmg_printer_usermessages [03] := 'Prvá strana [HOME]'
	_hmg_printer_usermessages [04] := 'Predcházajúca strana [PGUP]'
	_hmg_printer_usermessages [05] := 'Ïalšia strana [PGDN]'
	_hmg_printer_usermessages [06] := 'Posledná strana [END]'
	_hmg_printer_usermessages [07] := 'Uka stranu'
	_hmg_printer_usermessages [08] := 'Lupa'
	_hmg_printer_usermessages [09] := 'Tlaè'
	_hmg_printer_usermessages [10] := 'Èíslo strany'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Storno'
	_hmg_printer_usermessages [13] := 'Vyberte tlaèiáreò'
	_hmg_printer_usermessages [14] := 'Zoradenie'
	_hmg_printer_usermessages [15] := 'Rozsah tlaèe'
	_hmg_printer_usermessages [16] := 'všetko'
	_hmg_printer_usermessages [17] := 'strany'
	_hmg_printer_usermessages [18] := 'od'
	_hmg_printer_usermessages [19] := 'po'
	_hmg_printer_usermessages [20] := 'kópií'
	_hmg_printer_usermessages [21] := 'všetky strany'
	_hmg_printer_usermessages [22] := 'nepárné strany'
	_hmg_printer_usermessages [23] := 'párné strany'
	_hmg_printer_usermessages [24] := 'Áno'
	_hmg_printer_usermessages [25] := 'Nie'
	_hmg_printer_usermessages [26] := 'Zatvor'
	_hmg_printer_usermessages [27] := 'Ulo'
	_hmg_printer_usermessages [28] := 'Miniatury'
	_hmg_printer_usermessages [29] := 'Generujem miniatury... Èakajte, prosím...'

   CASE cLang == "HU" // Hungarian
      /////////////////////////////////////////////////////////////
      // HUNGARIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Oldal'
	_hmg_printer_usermessages [02] := 'Elõnézet'
	_hmg_printer_usermessages [03] := 'Elsõ oldal [HOME]'
	_hmg_printer_usermessages [04] := 'Elõzõ oldal [PGUP]'
	_hmg_printer_usermessages [05] := 'Következõ oldal [PGDN]'
	_hmg_printer_usermessages [06] := 'Utolsó oldal [END]'
	_hmg_printer_usermessages [07] := 'Oldalt mutasd'
	_hmg_printer_usermessages [08] := 'Nagyító'
	_hmg_printer_usermessages [09] := 'Nyomtasd'
	_hmg_printer_usermessages [10] := 'Oldal száma'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Elvetés'
	_hmg_printer_usermessages [13] := 'Válasszon nyomtatót'
	_hmg_printer_usermessages [14] := 'Rendezve'
	_hmg_printer_usermessages [15] := 'Oldalak nyomtatása'
	_hmg_printer_usermessages [16] := 'mindent'
	_hmg_printer_usermessages [17] := 'Oldalakat'
	_hmg_printer_usermessages [18] := 'ettõl'
	_hmg_printer_usermessages [19] := 'eddig'
	_hmg_printer_usermessages [20] := 'másolat'
	_hmg_printer_usermessages [21] := 'Minden oldalt'
	_hmg_printer_usermessages [22] := 'páros oldalakat'
	_hmg_printer_usermessages [23] := 'páratlan oldalakat'
	_hmg_printer_usermessages [24] := 'Igen'
	_hmg_printer_usermessages [25] := 'Nem'
	_hmg_printer_usermessages [26] := 'Zárd be'
	_hmg_printer_usermessages [27] := 'Mentsd'
	_hmg_printer_usermessages [28] := 'Miniatúrák'
	_hmg_printer_usermessages [29] := 'Miniatúrák létrehozása... Kérem, várjon...'

   CASE cLang == "BG" // Bulgarian
      /////////////////////////////////////////////////////////////
      // BULGARIAN
      ////////////////////////////////////////////////////////////

	_hmg_printer_usermessages [01] := 'Ñòğàíèöà'
	_hmg_printer_usermessages [02] := 'Ïğåäâàğèòåëåí ïğåãëåä'
	_hmg_printer_usermessages [03] := 'Ïúğâà [HOME]'
	_hmg_printer_usermessages [04] := 'Ïğåäèäóùà [PGUP]'
	_hmg_printer_usermessages [05] := 'Ñëåäâùà [PGDN]'
	_hmg_printer_usermessages [06] := 'Ïîñëåäíà [END]'
	_hmg_printer_usermessages [07] := 'Èäè íà'
	_hmg_printer_usermessages [08] := 'Ìàùàá'
	_hmg_printer_usermessages [09] := 'Ïå÷àò'
	_hmg_printer_usermessages [10] := 'Ñòğàíèöà ¹'
	_hmg_printer_usermessages [11] := 'Ok'
	_hmg_printer_usermessages [12] := 'Îòìÿíà'
	_hmg_printer_usermessages [13] := 'Èçáîğ íà ïğèíòåğ'
	_hmg_printer_usermessages [14] := 'Ñîğòèğîâêà íà êîïèÿòà'
	_hmg_printer_usermessages [15] := 'Èíòåğâàë çà ïå÷àò'
	_hmg_printer_usermessages [16] := 'Âñè÷êè'
	_hmg_printer_usermessages [17] := 'Ñòğàíèöè'
	_hmg_printer_usermessages [18] := 'Îò'
	_hmg_printer_usermessages [19] := 'Äî'
	_hmg_printer_usermessages [20] := 'Êîïèÿ'
	_hmg_printer_usermessages [21] := 'Öåëèÿ èíòåğâàë'
	_hmg_printer_usermessages [22] := 'Ñàìî íå÷åòíèòå'
	_hmg_printer_usermessages [23] := 'Ñàìî ÷åòíèòå'
	_hmg_printer_usermessages [24] := 'Äà'
	_hmg_printer_usermessages [25] := 'Íå'
	_hmg_printer_usermessages [26] := 'Çàòâîğè'
	_hmg_printer_usermessages [27] := 'Ñúõğàíè'
	_hmg_printer_usermessages [28] := 'Ìèíèàòşğè'
	_hmg_printer_usermessages [29] := 'Èç÷àêàéòå, ãåíåğèğàì ìèíèàòşğè...'

   ENDCASE

#endif
RETURN

/*
 * Routine: GETPRINTABLEAREAWIDTH()
 *
 * Purpose:
 *   Retrieves the width of the printable area of the current printer.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   Numeric - The width of the printable area in millimeters.
 *
 * Side Effects:
 *   - Queries the active printer device context.
 */
FUNCTION GETPRINTABLEAREAWIDTH()

RETURN _HMG_PRINTER_GETPRINTERWIDTH ( _hmg_printer_hdc )

/*
 * Routine: GETPRINTABLEAREAHEIGHT()
 *
 * Purpose:
 *   Retrieves the height of the printable area of the current printer.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   Numeric - The height of the printable area in millimeters.
 *
 * Side Effects:
 *   - Queries the active printer device context.
 */
FUNCTION GETPRINTABLEAREAHEIGHT()

RETURN _HMG_PRINTER_GETPRINTERHEIGHT ( _hmg_printer_hdc )

/*
 * Routine: GETPRINTABLEAREAHORIZONTALOFFSET()
 *
 * Purpose:
 *   Retrieves the horizontal physical offset of the printable area of the current printer.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   Numeric - The horizontal offset in millimeters.
 *
 * Side Effects:
 *   - Queries the active printer device context.
 */
FUNCTION GETPRINTABLEAREAHORIZONTALOFFSET()

   IF Type ( '_hmg_miniprint[19]' ) == 'U'
      RETURN 0
   ENDIF

   // Convert physical horizontal offset from pixels to millimeters
RETURN ( _HMG_PRINTER_GETPRINTABLEAREAPHYSICALOFFSETX ( _hmg_printer_hdc ) / _HMG_PRINTER_GETPRINTABLEAREALOGPIXELSX ( _hmg_printer_hdc ) * 25.4 )

/*
 * Routine: GETPRINTABLEAREAVERTICALOFFSET()
 *
 * Purpose:
 *   Retrieves the vertical physical offset of the printable area of the current printer.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   Numeric - The vertical offset in millimeters.
 *
 * Side Effects:
 *   - Queries the active printer device context.
 */
FUNCTION GETPRINTABLEAREAVERTICALOFFSET()

   IF Type ( '_hmg_miniprint[19]' ) == 'U'
      RETURN 0
   ENDIF

   // Convert physical vertical offset from pixels to millimeters
RETURN ( _HMG_PRINTER_GETPRINTABLEAREAPHYSICALOFFSETY ( _hmg_printer_hdc ) / _HMG_PRINTER_GETPRINTABLEAREALOGPIXELSY ( _hmg_printer_hdc ) * 25.4 )

/*
 * Routine: _HMG_PRINTER_MouseZoom()
 *
 * Purpose:
 *   Toggles the zoom state and pans the view to center on the quadrant where the user clicked.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Toggles zoom level (_hmg_printer_Dz) and offsets (_hmg_printer_Dx, _hmg_printer_Dy).
 *   - Updates scrollbar positions on the preview window.
 *   - Refreshes the preview display.
 */
PROCEDURE _HMG_PRINTER_MouseZoom
   LOCAL WIDTH := GetDesktopWidth()
   LOCAL HEIGHT := GetDesktopHeight()
   LOCAL Q := 0
   LOCAL DeltaHeight := 35 + GetTitleHeight() + GetBorderHeight() + 10

   IF _hmg_printer_Dz == 1000 + _HMG_PRINTER_DELTA_ZOOM

      _hmg_printer_Dz := 0
      _hmg_printer_Dx := 0
      _hmg_printer_Dy := 0

      SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 50, .T. )
      SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 50, .T. )

      _HMG_PRINTER_PREVIEW_DISABLESCROLLBARS ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ) )

   ELSE

      // Determine which screen quadrant was clicked to center the zoom there
      // Calculate Quadrant

      IF _HMG_MouseCol <= ( Width / 2 ) - _hmg_printer_zoomclick_xoffset ;
            .AND. ;
            _HMG_MouseRow <= ( Height / 2 ) - DeltaHeight

         Q := 1

      ELSEIF _HMG_MouseCol > ( Width / 2 ) - _hmg_printer_zoomclick_xoffset ;
            .AND. ;
            _HMG_MouseRow <= ( Height / 2 ) - DeltaHeight

         Q := 2

      ELSEIF _HMG_MouseCol <= ( Width / 2 ) - _hmg_printer_zoomclick_xoffset ;
            .AND. ;
            _HMG_MouseRow > ( Height / 2 ) - DeltaHeight

         Q := 3

      ELSEIF _HMG_MouseCol > ( Width / 2 ) - _hmg_printer_zoomclick_xoffset ;
            .AND. ;
            _HMG_MouseRow > ( Height / 2 ) - DeltaHeight

         Q := 4

      ENDIF

      IF _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) ;
            > ;
            _HMG_PRINTER_GETPAGEWIDTH( _hmg_printer_hdc_bak )

         // Portrait

         IF Q == 1
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := 100
            _hmg_printer_Dy := 400
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 10, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 40, .T. )
         ELSEIF Q == 2
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := -100
            _hmg_printer_Dy := 400
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 10, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 60, .T. )
         ELSEIF Q == 3
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := 100
            _hmg_printer_Dy := -400
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 90, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 40, .T. )
         ELSEIF Q == 4
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := -100
            _hmg_printer_Dy := -400
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 90, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 60, .T. )
         ENDIF

      ELSE

         // Landscape

         IF Q == 1
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := 500
            _hmg_printer_Dy := 300
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 20, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 1, .T. )
         ELSEIF Q == 2
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := -500
            _hmg_printer_Dy := 300
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 20, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 99, .T. )
         ELSEIF Q == 3
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := 500
            _hmg_printer_Dy := -300
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 80, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 1, .T. )
         ELSEIF Q == 4
            _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
            _hmg_printer_Dx := -500
            _hmg_printer_Dy := -300
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 80, .T. )
            SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 99, .T. )
         ENDIF

      ENDIF

      _HMG_PRINTER_PREVIEW_ENABLESCROLLBARS ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ) )

   ENDIF

   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _HMG_PRINTER_Zoom()
 *
 * Purpose:
 *   Toggles the zoom state of the print preview window.
 *
 * Parameters:
 *   None.
 *
 * Returns:
 *   None.
 *
 * Side Effects:
 *   - Toggles zoom level (_hmg_printer_Dz) and offsets (_hmg_printer_Dx, _hmg_printer_Dy).
 *   - Updates scrollbar positions on the preview window.
 *   - Refreshes the preview display.
 */
PROCEDURE _HMG_PRINTER_Zoom


   IF _hmg_printer_Dz == 1000 + _HMG_PRINTER_DELTA_ZOOM

      _hmg_printer_Dz := 0
      _hmg_printer_Dx := 0
      _hmg_printer_Dy := 0

      SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 50, .T. )
      SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 50, .T. )

      _HMG_PRINTER_PREVIEW_DISABLESCROLLBARS ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ) )

   ELSE

      IF _HMG_PRINTER_GETPAGEHEIGHT( _hmg_printer_hdc_bak ) ;
            > ;
            _HMG_PRINTER_GETPAGEWIDTH( _hmg_printer_hdc_bak )

         _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
         _hmg_printer_Dx := 100
         _hmg_printer_Dy := 400
         SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 10, .T. )
         SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 40, .T. )

      ELSE

         _hmg_printer_Dz := 1000 + _HMG_PRINTER_DELTA_ZOOM
         _hmg_printer_Dx := 500
         _hmg_printer_Dy := 300
         SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_VERT, 20, .T. )
         SetScrollPos ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ), SB_HORZ, 1, .T. )

      ENDIF

      _HMG_PRINTER_PREVIEW_ENABLESCROLLBARS ( GetFormHandle( '_HMG_PRINTER_SHOWPREVIEW' ) )

   ENDIF

   _HMG_PRINTER_PREVIEWRefresh()
RETURN

/*
 * Routine: _hmg_printer_setjobname()
 *
 * Purpose:
 *   Sets or defaults the print job name.
 *
 * Parameters:
 *   cName - Character - The desired print job name (optional).
 *
 * Returns:
 *   Character - The resolved print job name.
 *
 * Side Effects:
 *   None.
 */
FUNCTION _hmg_printer_setjobname( cName )

RETURN hb_defaultValue( cName, 'HMGPrintSys' )

/*
 * Routine: HMG_PrintGetJobInfo()
 *
 * Purpose:
 *   Retrieves detailed status information for a specific print job.
 *
 * Parameters:
 *   aJobData - Array - Print job data array containing printer handle and job ID (optional).
 *
 * Returns:
 *   Array - Information about the print job.
 *
 * Side Effects:
 *   - Queries the active printer spooler.
 */
FUNCTION HMG_PrintGetJobInfo ( aJobData ) // by Dr. Claudio Soto, August 2015

   IF ValType( aJobData ) == "U"
      aJobData := OpenPrinterGetJobData()
   ENDIF
RETURN _HMG_PrintGetJobInfo( aJobData[ 2 ], aJobData[ 1 ] ) // --> aJobInfo

/*
 * Routine: HMG_PrinterGetStatus()
 *
 * Purpose:
 *   Retrieves the current status of a specified printer.
 *
 * Parameters:
 *   cPrinterName - Character - The name of the printer to query (optional).
 *
 * Returns:
 *   Numeric - Status code of the printer.
 *
 * Side Effects:
 *   - Queries the printer spooler status.
 */
FUNCTION HMG_PrinterGetStatus ( cPrinterName )

   IF ValType( cPrinterName ) == "U"
      cPrinterName := _hmg_printer_name
   ENDIF
RETURN _HMG_PrinterGetStatus( cPrinterName ) // --> nStatus

/*
 * Routine: _DefineEmfFile()
 *
 * Purpose:
 *   Registers and initializes an Enhanced Metafile (EMF) image control within HMG.
 *
 * Parameters:
 *   ControlName - Character - Name of the control.
 *   ParentFormName - Character - Name of the parent form.
 *   x - Numeric - X coordinate in pixels.
 *   y - Numeric - Y coordinate in pixels.
 *   FileName - Character - Path to the EMF file.
 *   w - Numeric - Width of the control.
 *   h - Numeric - Height of the control.
 *   ProcedureName - Character/Block - Action callback procedure name or code block.
 *   HelpId - Numeric - Help context ID.
 *   invisible - Logical - Visibility flag.
 *   stretch - Logical - Stretch image flag.
 *   WhiteBackground - Logical - White background flag.
 *   transparent - Logical - Transparent background flag.
 *
 * Returns:
 *   NIL - Always returns NIL.
 *
 * Side Effects:
 *   - Registers the control in HMG's internal arrays (_HMG_aControlType, _HMG_aControlNames, etc.).
 *   - Creates the Win32 control handle and sets the EMF file association.
 */
FUNCTION _DefineEmfFile ( ControlName, ParentFormName, x, y, FileName, w, h, ;
      ProcedureName, HelpId, invisible, stretch, WhiteBackground, transparent )
   LOCAL ParentFormHandle, mVar, ACTION := .F., k
   LOCAL ControlHandle

   IF ValType( ProcedureName ) == "U"
      ProcedureName := ""
   ELSE
      ACTION := .T.
   ENDIF

DEFAULT stretch TO FALSE, WhiteBackground TO FALSE, transparent TO FALSE

   mVar := '_' + ParentFormName + '_' + ControlName
   k := _GetControlFree()

   ParentFormHandle := GetFormHandle ( ParentFormName )

   ControlHandle := InitEmfFile ( ParentFormHandle, 0, x, y, invisible, action )

   // Register the control name in the HMG names list or as a public variable

#ifdef _NAMES_LIST_
   _SetNameList( mVar, k )

#else
   PUBLIC &mVar. := k

#endif

   _HMG_aControlType[ k ] := "IMAGE"
   _HMG_aControlNames[ k ] := ControlName
   _HMG_aControlHandles[ k ] := ControlHandle
   _HMG_aControlParentHandles[ k ] := ParentFormHandle
   _HMG_aControlIds[ k ] := 0
   _HMG_aControlProcedures[ k ] := ProcedureName
   _HMG_aControlPageMap[ k ] := {}
   _HMG_aControlValue[ k ] := iif ( stretch, 1, 0 )
   _HMG_aControlInputMask[ k ] := iif ( transparent, 1, 0 )
   _HMG_aControllostFocusProcedure[ k ] := ""
   _HMG_aControlGotFocusProcedure[ k ] := ""
   _HMG_aControlChangeProcedure[ k ] := ""
   _HMG_aControlDeleted[ k ] := .F.
   _HMG_aControlBkColor[ k ] := NIL
   _HMG_aControlFontColor[ k ] := NIL
   _HMG_aControlDblClick[ k ] := ""
   _HMG_aControlHeadClick[ k ] := {}
   _HMG_aControlRow[ k ] := y
   _HMG_aControlCol[ k ] := x
   _HMG_aControlWidth[ k ] := w
   _HMG_aControlHeight[ k ] := h
   _HMG_aControlSpacing[ k ] := iif ( WhiteBackground, 1, 0 )
   _HMG_aControlContainerRow[ k ] := -1
   _HMG_aControlContainerCol[ k ] := -1
   _HMG_aControlPicture[ k ] := FileName
   _HMG_aControlContainerHandle[ k ] := 0
   _HMG_aControlFontName[ k ] := ''
   _HMG_aControlFontSize[ k ] := 0
   _HMG_aControlFontAttributes[ k ] := { .F., .F., .F., .F. }
   _HMG_aControlToolTip[ k ] := ''
   _HMG_aControlRangeMin[ k ] := 0
   _HMG_aControlRangeMax[ k ] := 0
   _HMG_aControlCaption[ k ] := ''
   _HMG_aControlVisible[ k ] := iif( invisible, .F., .T. )
   _HMG_aControlHelpId[ k ] := HelpId
   _HMG_aControlFontHandle[ k ] := 0
   // Associate the EMF file with the control handle and retrieve the brush handle
   _HMG_aControlBrushHandle[ k ] := C_SetEmfFile ( ControlHandle, FileName, W, H, _HMG_aControlValue[ k ], _HMG_aControlSpacing[ k ] )
   _HMG_aControlEnabled[ k ] := .T.
   _HMG_aControlMiscData1[ k ] := 0
   _HMG_aControlMiscData2[ k ] := ''
RETURN NIL
