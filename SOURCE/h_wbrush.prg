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

/*
 * Author: P.Chornyj <myorg63@mail.ru>
 * revised for build 16.10
 */

#include "minigui.ch"

// Compatibility macros for xHarbour SWITCH syntax differences
#ifdef __XHARBOUR__
#xcommand END SWITCH => END
#xcommand OTHERWISE  => DEFAULT
#endif

/*
 * Routine: _SetWindowBKBrush
 *
 * Purpose:
 *    Creates and assigns a background GDI brush (solid, hatch, or pattern)
 *    to a specified HMG window, updating global state tracking and managing
 *    the destruction or retention of the previously assigned brush.
 *
 * Parameters:
 *    cWindow     [C] : Name of the target registered window form.
 *    lNoDelete   [L] : Flag controlling whether to preserve the previous brush.
 *                      If .T., returns the old brush handle without deleting it;
 *                      if .F. (default), automatically deletes the old brush.
 *    cBrushStyle [C] : Requested brush style ("SOLID", "HATCH", "PATTERN").
 *                      Defaults to "SOLID". Evaluated by first character.
 *    nHatch      [N] : Hatch pattern style constant (e.g., HS_VERTICAL) used
 *                      when cBrushStyle is "HATCH". Defaults to HS_VERTICAL.
 *    aColor      [A] : Array of 3 integers {Red, Green, Blue} (0-255) for solid
 *                      or hatch brush color. Defaults to { 255, 0, 255 } (magenta).
 *    xImage      [C] : Bitmap image resource or filename used when cBrushStyle
 *                      is "PATTERN". Defaults to "MINIGUI_EDIT_DELETE".
 *
 * Return Value:
 *    [H/N] : Handle to the newly created GDI brush, or handle to the previous brush
 *            if lNoDelete is .T. Returns 0 if form is not found or brush creation fails.
 *
 * Side Effects:
 *    - Modifies the Win32 window background brush using SetWindowBrush().
 *    - Updates the global HMG array _HMG_aFormBrushHandle[nIndex].
 *    - Destroys the previous Win32 GDI brush via DELETE BRUSH unless lNoDelete is .T.
 *    - Forces a repaint of the window background surface.
 */
FUNCTION _SetWindowBKBrush( cWindow, lNoDelete, cBrushStyle, nHatch, aColor, xImage )
   LOCAL hWnd
   LOCAL hOldBrush
   LOCAL hBrush := 0
   LOCAL nIndex

   // Set default values for optional arguments
   __defaultNIL( @lNoDelete, .F. )
   __defaultNIL( @cBrushStyle, "SOLID" )
   __defaultNIL( @nHatch, HS_VERTICAL )
   __defaultNIL( @aColor, { 255, 0, 255 } )
   __defaultNIL( @xImage, "MINIGUI_EDIT_DELETE" )

   // Locate form in internal HMG registration table
   nIndex := GetFormIndex ( cWindow )

   IF nIndex > 0
      // Get Win32 window handle from internal registry
      hWnd := _HMG_aFormHandles[ nIndex ]

      // Create GDI brush based on style prefix ('S', 'H', or 'P')
      SWITCH Left ( cBrushStyle, 1 )
      CASE "S"
         // Solid brush with specified RGB components
         hBrush := CreateSolidBrush ( aColor[ 1 ], aColor[ 2 ], aColor[ 3 ] )
         EXIT
      CASE "H"
         // Hatched brush with specified style constant and RGB color
         hBrush := CreateHatchBrush ( nHatch, RGB( aColor[ 1 ], aColor[ 2 ], aColor[ 3 ] ) )
         EXIT
      CASE "P"
         // Pattern brush from image file or resource name
         hBrush := CreatePatternBrush ( xImage )
         EXIT
      OTHERWISE
         // Fallback: retrieve handle to existing window brush
         hBrush := GetWindowBrush ( hWnd )
      END SWITCH

      // Ensure created object is a valid GDI brush
      IF GetObjectType ( hBrush ) == OBJ_BRUSH
         // Assign new brush to window and store handle to replaced brush
         hOldBrush := SetWindowBrush ( hWnd, hBrush )
         // Update internal HMG brush handle reference for this form
         _HMG_aFormBrushHandle[ nIndex ] := hBrush

         IF lNoDelete
            // Pass handle of replaced brush back to caller for custom management
            RETURN hOldBrush
         ELSE
            // Release GDI resources for the replaced background brush
            DELETE BRUSH hOldBrush
         ENDIF
      ENDIF
   ENDIF

RETURN hBrush
