/*----------------------------------------------------------------------------
MINIGUI - Harbour Win32 GUI library source code
Copyright 2002-2010 Roberto Lopez <harbourminigui@gmail.com>
http://harbourminigui.googlepages.com/

MsgBox code rewrotten by Jacek Kubica <kubica@wssk.wroc.pl>
(c) 2006 HMG Experimental Build 16g

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

// Icon configuration default value
#define MB_DEFAULT_ICON   0

// Normalized return status codes for ternary dialog operations
#define MESSAGE_YES       1
#define MESSAGE_NO        0
#define MESSAGE_CANCEL   -1

/*
 * Function: _NormalizeMsg
 *
 * Purpose:
 *    Converts input message content of various data types into a single,
 *    displayable character string suitable for Win32 dialog output.
 *
 * Parameters:
 *    cMsg [Variant] - Message body. Supports String, Array of elements, or
 *                     any data type convertible via Harbour's hb_ValToStr().
 *
 * Returns:
 *    Character - Sanitized string containing concatenated or converted text.
 *
 * Side Effects:
 *    None.
 */
STATIC FUNCTION _NormalizeMsg( cMsg )
   LOCAL cText := "", xVal

   // Standardize NIL inputs to an empty character string
   __defaultNIL( @cMsg, "" )

   IF ISARRAY( cMsg )
      // Iterate through message array to flatten multi-line or mixed data into a single string
      FOR EACH xVal IN cMsg
         cText += hb_ValToStr( xVal )
      NEXT
      RETURN cText
   ENDIF

   // Convert scalar values (numbers, dates, logicals) into string representation
RETURN hb_ValToStr( cMsg )

/*
 * Function: _ApplyBoxFlags
 *
 * Purpose:
 *    Merges window modality and Z-order display flags into a Win32 style bitmask.
 *
 * Parameters:
 *    nStyle [Numeric] - Initial Win32 MessageBox style flags.
 *    lSys   [Logical] - Modality state (.T. for system modal, .F. for application modal).
 *    lTop   [Logical] - Topmost window flag (.T. to force foreground Z-order).
 *
 * Returns:
 *    Numeric - Combined bitmask with modal and Z-order flags applied.
 *
 * Side Effects:
 *    None.
 */
STATIC FUNCTION _ApplyBoxFlags( nStyle, lSys, lTop )
   // Default to system modal and topmost display for critical HMG alerts
   LOCAL lSystem  := hb_defaultValue( lSys, .T. )
   LOCAL lTopMost := hb_defaultValue( lTop, .T. )

   // Perform bitwise OR operation to set window modality
   nStyle := hb_bitOr( nStyle, ;
                       iif( lSystem, MB_SYSTEMMODAL, MB_APPLMODAL ) )

   // Force dialog to top of screen Z-order if requested
   IF lTopMost
      nStyle := hb_bitOr( nStyle, MB_TOPMOST )
   ENDIF

RETURN nStyle

/*
 * Function: _BuildStyle
 *
 * Purpose:
 *    Constructs the full Win32 MessageBox style bitmask by combining button layout,
 *    icon resource options, and initial button focus index.
 *
 * Parameters:
 *    nButtons [Numeric] - Button combination flag (e.g., MB_YESNO, MB_OKCANCEL).
 *    nIcon    [Numeric] - Custom icon resource ID or MB_DEFAULT_ICON (0).
 *    nDefIcon [Numeric] - Fallback system icon flag (e.g., MB_ICONQUESTION).
 *    nDefBtn  [Numeric] - 1-based index of button to receive initial focus.
 *
 * Returns:
 *    Numeric - Fully assembled Win32 MessageBox style flag bitmask.
 *
 * Side Effects:
 *    None.
 */
STATIC FUNCTION _BuildStyle( nButtons, nIcon, nDefIcon, nDefBtn )
   LOCAL nStyle
   LOCAL nBtn := hb_defaultValue( nDefBtn, 1 )
   LOCAL nIconStyle

   // Select system default icon style or signal a user-defined resource
   nIconStyle := iif( hb_defaultValue( nIcon, 0 ) == MB_DEFAULT_ICON, ;
                      nDefIcon, ;
                      MB_USERICON )

   nStyle := hb_bitOr( nButtons, nIconStyle )

   // Shift default button selection into Win32 MB_DEFBUTTON bits (256 * (n - 1))
   IF ISNUMERIC( nBtn ) .AND. nBtn > 1
      nStyle := hb_bitOr( nStyle, ( nBtn - 1 ) * 256 )
   ENDIF

RETURN nStyle

/*
 * Function: _MsgBox
 *
 * Purpose:
 *    Core internal wrapper around the native Windows MessageBoxIndirect API.
 *
 * Parameters:
 *    cMsg   [Variant]   - Dialog text body (string or array).
 *    cTitle [Character] - Caption text displayed in the title bar.
 *    nStyle [Numeric]   - Combined Win32 style bitmask.
 *    nIcon  [Numeric]   - Icon resource identifier or handle.
 *    lSys   [Logical]   - System modal flag.
 *    lTop   [Logical]   - Topmost window flag.
 *
 * Returns:
 *    Numeric - Direct Win32 response identifier (e.g., IDOK, IDYES, IDNO, IDCANCEL).
 *
 * Side Effects:
 *    Displays a modal Win32 dialog box, halting calling thread execution until closed.
 */
STATIC FUNCTION _MsgBox( cMsg, cTitle, nStyle, nIcon, lSys, lTop )
   // Pre-process message content and apply window behavior flags
   cMsg   := _NormalizeMsg( cMsg )
   nStyle := _ApplyBoxFlags( nStyle, lSys, lTop )

   // Invoke native Win32 API via HMG C-level bindings
RETURN MessageBoxIndirect( NIL, ;
                           cMsg, ;
                           hb_defaultValue( cTitle, "" ), ;
                           nStyle, ;
                           nIcon )

/*
 * Function: MsgYesNo
 *
 * Purpose:
 *    Displays a binary confirmation dialog featuring 'Yes' and 'No' buttons
 *    accompanied by a question icon.
 *
 * Parameters:
 *    cMsg    [Variant]   - Message content (String or Array).
 *    cTitle  [Character] - Window caption text.
 *    lRevDef [Logical]   - If .T., sets default button focus to 'No' (Button 2).
 *    nIcon   [Numeric]   - Custom icon resource ID.
 *    lSys    [Logical]   - Modality flag (.T. system modal, .F. application modal).
 *    lTop    [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Logical - .T. if 'Yes' button was selected; .F. otherwise.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgYesNo ( cMsg, cTitle, lRevDef, nIcon, lSys, lTop )
   LOCAL nStyle

   // Build style using MB_YESNO and MB_ICONQUESTION, adjusting default focus button
   nStyle := _BuildStyle( MB_YESNO, ;
                          nIcon, ;
                          MB_ICONQUESTION, ;
                          iif( hb_defaultValue( lRevDef, .F. ), 2, 1 ) )

RETURN ( _MsgBox( cMsg, cTitle, nStyle, nIcon, lSys, lTop ) == IDYES )

/*
 * Function: MsgYesNoCancel
 *
 * Purpose:
 *    Displays a ternary decision dialog featuring 'Yes', 'No', and 'Cancel'
 *    buttons with a question icon.
 *
 * Parameters:
 *    cMsg    [Variant]   - Message content (String or Array).
 *    cTitle  [Character] - Window caption text.
 *    nIcon   [Numeric]   - Custom icon resource ID.
 *    lSys    [Logical]   - Modality flag.
 *    nDefBtn [Numeric]   - Default button focus index (1=Yes, 2=No, 3=Cancel).
 *    lTop    [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Numeric - MESSAGE_YES (1) if Yes clicked, MESSAGE_NO (0) if No clicked,
 *              or MESSAGE_CANCEL (-1) if Cancel clicked or dialog closed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgYesNoCancel ( cMsg, cTitle, nIcon, lSys, nDefBtn, lTop )
   LOCAL nRes

   // Display the dialog and retrieve native Win32 return ID
   nRes := _MsgBox( cMsg, cTitle, ;
                    _BuildStyle( MB_YESNOCANCEL, nIcon, MB_ICONQUESTION, nDefBtn ), ;
                    nIcon, lSys, lTop )

   // Translate Win32 return constants to HMG standardized ternary constants
   IF nRes == IDYES
      RETURN MESSAGE_YES
   ELSEIF nRes == IDNO
      RETURN MESSAGE_NO
   ENDIF

RETURN MESSAGE_CANCEL

/*
 * Function: MsgRetryCancel
 *
 * Purpose:
 *    Displays a dialog with 'Retry' and 'Cancel' options for handling operation failures.
 *
 * Parameters:
 *    cMsg    [Variant]   - Message content (String or Array).
 *    cTitle  [Character] - Window caption text.
 *    nIcon   [Numeric]   - Custom icon resource ID.
 *    lSys    [Logical]   - Modality flag.
 *    nDefBtn [Numeric]   - Default button focus index (1=Retry, 2=Cancel).
 *    lTop    [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Logical - .T. if 'Retry' button was selected; .F. if 'Cancel' selected or dialog closed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgRetryCancel ( cMsg, cTitle, nIcon, lSys, nDefBtn, lTop )
RETURN ( _MsgBox( cMsg, cTitle, ;
                  _BuildStyle( MB_RETRYCANCEL, nIcon, MB_ICONQUESTION, nDefBtn ), ;
                  nIcon, lSys, lTop ) == IDRETRY )

/*
 * Function: MsgOkCancel
 *
 * Purpose:
 *    Displays a dialog with 'OK' and 'Cancel' options for user confirmation.
 *
 * Parameters:
 *    cMsg    [Variant]   - Message content (String or Array).
 *    cTitle  [Character] - Window caption text.
 *    nIcon   [Numeric]   - Custom icon resource ID.
 *    lSys    [Logical]   - Modality flag.
 *    nDefBtn [Numeric]   - Default button focus index (1=OK, 2=Cancel).
 *    lTop    [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Logical - .T. if 'OK' button was selected; .F. if 'Cancel' selected or dialog closed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgOkCancel ( cMsg, cTitle, nIcon, lSys, nDefBtn, lTop )
RETURN ( _MsgBox( cMsg, cTitle, ;
                  _BuildStyle( MB_OKCANCEL, nIcon, MB_ICONQUESTION, nDefBtn ), ;
                  nIcon, lSys, lTop ) == IDOK )

/*
 * Function: MsgExclamation
 *
 * Purpose:
 *    Displays a warning message dialog with an exclamation icon and an 'OK' button.
 *
 * Parameters:
 *    cMsg   [Variant]   - Message content (String or Array).
 *    cTitle [Character] - Title text; defaults to localized warning title (_HMG_MESSAGE[10]).
 *    nIcon  [Numeric]   - Custom icon resource ID.
 *    lSys   [Logical]   - Modality flag.
 *    lTop   [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Numeric - IDOK constant when dismissed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgExclamation ( cMsg, cTitle, nIcon, lSys, lTop )
RETURN _MsgBox( cMsg, ;
                hb_defaultValue( cTitle, _HMG_MESSAGE[ 10 ] ), ;
                _BuildStyle( MB_OK, nIcon, MB_ICONEXCLAMATION, 1 ), ;
                nIcon, lSys, lTop )

/*
 * Function: MsgInfo
 *
 * Purpose:
 *    Displays an informational message dialog with an 'i' icon and an 'OK' button.
 *
 * Parameters:
 *    cMsg   [Variant]   - Message content (String or Array).
 *    cTitle [Character] - Title text; defaults to localized info title (_HMG_MESSAGE[11]).
 *    nIcon  [Numeric]   - Custom icon resource ID.
 *    lSys   [Logical]   - Modality flag.
 *    lTop   [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Numeric - IDOK constant when dismissed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgInfo ( cMsg, cTitle, nIcon, lSys, lTop )
RETURN _MsgBox( cMsg, ;
                hb_defaultValue( cTitle, _HMG_MESSAGE[ 11 ] ), ;
                _BuildStyle( MB_OK, nIcon, MB_ICONINFORMATION, 1 ), ;
                nIcon, lSys, lTop )

/*
 * Function: MsgStop
 *
 * Purpose:
 *    Displays a critical error message dialog with a stop sign ('X') icon and an 'OK' button.
 *
 * Parameters:
 *    cMsg   [Variant]   - Message content (String or Array).
 *    cTitle [Character] - Title text; defaults to localized stop title (_HMG_MESSAGE[12]).
 *    nIcon  [Numeric]   - Custom icon resource ID.
 *    lSys   [Logical]   - Modality flag.
 *    lTop   [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Numeric - IDOK constant when dismissed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgStop ( cMsg, cTitle, nIcon, lSys, lTop )
RETURN _MsgBox( cMsg, ;
                hb_defaultValue( cTitle, _HMG_MESSAGE[ 12 ] ), ;
                _BuildStyle( MB_OK, nIcon, MB_ICONSTOP, 1 ), ;
                nIcon, lSys, lTop )

/*
 * Function: MsgBox
 *
 * Purpose:
 *    Displays a simple, basic notification message dialog with an 'OK' button.
 *
 * Parameters:
 *    cMsg   [Variant]   - Message content (String or Array).
 *    cTitle [Character] - Window caption text.
 *    lSys   [Logical]   - Modality flag.
 *    lTop   [Logical]   - Topmost window display flag.
 *
 * Returns:
 *    Numeric - IDOK constant when dismissed.
 *
 * Side Effects:
 *    Halts thread execution while displaying a modal window.
 */
FUNCTION MsgBox ( cMsg, cTitle, lSys, lTop )
RETURN _MsgBox( cMsg, cTitle, MB_OK, NIL, lSys, lTop )