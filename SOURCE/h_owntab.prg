/*----------------------------------------------------------------------------
MINIGUI - Harbour Win32 GUI library source code

Copyright 2008 Walter Formigoni <walter.formigoni@uol.com.br>

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

#include "i_winuser.ch"
#include "minigui.ch"

// Standard Windows constant for centered text alignment used in DrawText calls.
#define DT_CENTER 1

/*
   Internal metadata indexes for the _HMG_aControlMiscData1 array.
*/
#define IDX_HEIGHT         1
#define IDX_IMAGEFLAG      2
#define IDX_BOTTOMTAB      4
#define IDX_HOTTRACK       5
#define IDX_HOTTRACKCOLOR  6
#define IDX_INACTIVECOLOR  7

/*
   FUNCTION: OwnTabPaint
   PURPOSE:  Handles the WM_DRAWITEM message for Tab controls in owner-draw mode.
             Provides custom background colors, text colors, fonts, and image support
             for individual tabs, including special handling for bottom tabs.
   INPUT:    lParam - Pointer to the DRAWITEMSTRUCT from Windows.
   RETURNS:  0 if painting was handled, 1 if request is invalid.
   SIDE EFFECTS: Draws directly to the tab's Device Context. Updates internal HMG
                 control data (height, etc.).
*/
FUNCTION OwnTabPaint( lParam )

   LOCAL hDC, hBrush, hOldFont, hImage
   LOCAL aBkColor, aForeColor, aInactiveColor, aBmp, aMetrics, aBtnRect
   LOCAL nCtrlIndex, nItemId, nImageIndex, nTextColor, nBkColor
   LOCAL nFontSize, nTextOffset, nImageYOffset
   LOCAL x1, y1, x2, y2, xp1, yp1, xp2, yp2
   LOCAL lSelected, lBottomTab
   LOCAL cCaption

   /*--------------------------------------------------------------
    * Validate owner-draw request
    *-------------------------------------------------------------*/
   hDC := GETOWNBTNDC( lParam )

   nCtrlIndex := AScan( _HMG_aControlHandles, GETOWNBTNHANDLE( lParam ) )

   // Safety check: invalid DC, wrong control type, or not registered in HMG
   IF Empty( hDC ) .OR. ;
      GETOWNBTNCTLTYPE( lParam ) <> ODT_TAB .OR. ;
      nCtrlIndex == 0 .OR. ;
      _HMG_aControlType[ nCtrlIndex ] <> "TAB"
      RETURN 1
   ENDIF

   /*--------------------------------------------------------------
    * Read control and item state
    *-------------------------------------------------------------*/
   nItemId    := GETOWNBTNITEMID( lParam ) + 1
   aBtnRect   := GETOWNBTNRECT( lParam )
   lSelected  := ( AND( GETOWNBTNSTATE( lParam ), ODS_SELECTED ) == ODS_SELECTED )
   lBottomTab := _HMG_aControlMiscData1[ nCtrlIndex ][ IDX_BOTTOMTAB ]

   // Cache tab height for use by other HMG layout functions
   _HMG_aControlMiscData1[ nCtrlIndex ][ IDX_HEIGHT ] := aBtnRect[ 4 ] - aBtnRect[ 2 ]

   /*--------------------------------------------------------------
    * Prepare GDI drawing context
    *-------------------------------------------------------------*/
   hOldFont := SelectObject( hDC, _HMG_aControlFontHandle[ nCtrlIndex ] )
   aMetrics := GetTextMetric( hDC )
   SetBkMode( hDC, TRANSPARENT )

   // Default system text color
   nTextColor := GetSysColor( COLOR_BTNTEXT )
   SetTextColor( hDC, GetRed( nTextColor ), GetGreen( nTextColor ), GetBlue( nTextColor ) )

   /*--------------------------------------------------------------
    * Background color (per-tab or control default)
    *-------------------------------------------------------------*/
   aBkColor := iif( ISARRAY( _HMG_aControlMiscData2[ nCtrlIndex ] ) .AND. ;
      nItemId <= Len( _HMG_aControlMiscData2[ nCtrlIndex ] ) .AND. ;
      IsArrayRGB( _HMG_aControlMiscData2[ nCtrlIndex ][ nItemId ] ), ;
      _HMG_aControlMiscData2[ nCtrlIndex ][ nItemId ], ;
      _HMG_aControlBkColor[ nCtrlIndex ] )

   nBkColor := RGB( aBkColor[ 1 ], aBkColor[ 2 ], aBkColor[ 3 ] )
   SetBkColor( hDC, nBkColor )

   hBrush := CreateSolidBrush( aBkColor[ 1 ], aBkColor[ 2 ], aBkColor[ 3 ] )
   FillRect( hDC, aBtnRect[ 1 ], aBtnRect[ 2 ], aBtnRect[ 3 ], aBtnRect[ 4 ], hBrush )
   DeleteObject( hBrush )

   /*--------------------------------------------------------------
    * Initial text rectangle (vertical centering base)
    *-------------------------------------------------------------*/
   x1 := aBtnRect[ 1 ]
   y1 := Round( aBtnRect[ 4 ] / 2, 0 ) - ( aMetrics[ 1 ] - 10 )
   x2 := aBtnRect[ 3 ] - 2
   y2 := y1 + aMetrics[ 1 ]

   /*--------------------------------------------------------------
    * Optional image support
    *-------------------------------------------------------------*/
   IF _HMG_aControlMiscData1[ nCtrlIndex ][ IDX_IMAGEFLAG ]

      nImageIndex := Min( nItemId, Len( _HMG_aControlPicture[ nCtrlIndex ] ) )

      hImage := LoadBitmap( _HMG_aControlPicture[ nCtrlIndex ][ nImageIndex ] )
      IF Empty( hImage )
         hImage := LoadImage( _HMG_aControlPicture[ nCtrlIndex ][ nImageIndex ], , , , , , nBkColor )
      ENDIF

      aBmp := GetBitmapSize( hImage )

      xp1 := 4                    // left margin
      xp2 := aBmp[ 1 ]
      yp2 := aBmp[ 2 ]
      yp1 := Round( aBtnRect[ 4 ] / 2 - yp2 / 2, 0 )

      // Shift text to make room for image
      x1 += ( 2 * xp1 ) + xp2

      IF lBottomTab
         nImageYOffset := 2 * yp1 - iif( _HMG_aControlFontSize[ nCtrlIndex ] >= 12, 8, 5 )
         DrawGlyph( hDC, aBtnRect[ 1 ] + iif( lSelected, 2 * xp1, xp1 ), nImageYOffset, ;
            xp2, 2 * yp2 - iif( _HMG_aControlFontSize[ nCtrlIndex ] >= 12, 8, 5 ), ;
            hImage, nBkColor, .F., .F. )
      ELSE
         DrawGlyph( hDC, aBtnRect[ 1 ] + iif( lSelected, 2 * xp1, xp1 ), ;
            iif( lSelected, yp1 - 2, yp1 + 2 ), xp2, yp2, hImage, nBkColor, .F., .F. )
      ENDIF

      DeleteObject( hImage )
   ENDIF

   /*--------------------------------------------------------------
    * Text color logic
    *-------------------------------------------------------------*/
   IF lSelected
      IF _HMG_aControlMiscData1[ nCtrlIndex ][ IDX_HOTTRACK ]
         IF IsArrayRGB( aForeColor := _HMG_aControlMiscData1[ nCtrlIndex ][ IDX_HOTTRACKCOLOR ] )
            SetTextColor( hDC, aForeColor[ 1 ], aForeColor[ 2 ], aForeColor[ 3 ] )
         ELSEIF nBkColor == GetSysColor( COLOR_BTNFACE )
            SetTextColor( hDC, 0, 0, 128 )     // Navy on default background
         ELSE
            SetTextColor( hDC, 255, 255, 255 ) // White on custom background
         ENDIF
      ENDIF
   ELSEIF IsArrayRGB( aInactiveColor := _HMG_aControlMiscData1[ nCtrlIndex ][ IDX_INACTIVECOLOR ] )
      SetTextColor( hDC, aInactiveColor[ 1 ], aInactiveColor[ 2 ], aInactiveColor[ 3 ] )
   ENDIF

   /*--------------------------------------------------------------
    * Draw caption with font-size aware vertical adjustment
    *-------------------------------------------------------------*/
   nFontSize := _HMG_aControlFontSize[ nCtrlIndex ]
   cCaption  := _HMG_aControlCaption[ nCtrlIndex ][ nItemId ]

   IF lBottomTab
      // Bottom tabs need different offset logic
      nTextOffset := iif( lSelected, ;
         iif( nFontSize >= 24, -12, iif( nFontSize >= 18, -3, iif( nFontSize >= 12, 6, 12 ) ) ), ;
         iif( nFontSize >= 24, -18, iif( nFontSize >= 18, -8, iif( nFontSize >= 12, 0, 8 ) ) ) )

      DrawText( hDC, cCaption, x1, 2 * y1 - nTextOffset, x2, 2 * y2 - nTextOffset, DT_CENTER )
   ELSE
      IF lSelected
         nTextOffset := iif( nFontSize >= 24, -9, iif( nFontSize >= 18, -5, iif( nFontSize >= 12, 0, 4 ) ) )
         DrawText( hDC, cCaption, x1, y1 - nTextOffset, x2, y2 - nTextOffset, DT_CENTER )
      ELSE
         nTextOffset := iif( nFontSize >= 24, 14, iif( nFontSize >= 18, 8, iif( nFontSize >= 12, 4, 0 ) ) )
         DrawText( hDC, cCaption, x1, y1 + nTextOffset, x2, y2 + nTextOffset, DT_CENTER )
      ENDIF
   ENDIF

   /*--------------------------------------------------------------
    * Cleanup GDI resources
    *-------------------------------------------------------------*/
   SelectObject( hDC, hOldFont )
   SetBkMode( hDC, TRANSPARENT )
   SetTextColor( hDC, GetRed( nTextColor ), GetGreen( nTextColor ), GetBlue( nTextColor ) )

RETURN 0
