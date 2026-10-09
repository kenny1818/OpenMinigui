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

/*--------------------------------------------------------------------------------
 * FUNCTION drawtextout( window, row, col, string, fontcolor, backcolor, fontname, fontsize, bold, italic, underline, strikeout, transparent, angle, once )
 *
 * Purpose:
 *    Renders text onto a specified window or device context with optional styling,
 *    colors, and orientation angle. Unless 'once' is .T., the rendering task is
 *    stored in the form's graphic task array to enable persistent redrawing on repaints.
 *
 * Parameters:
 *    window      - Character or Numeric. Name of the form or window/DC handle (HWND/HDC).
 *    row         - Numeric. Top Y-coordinate in pixels for text placement.
 *    col         - Numeric. Left X-coordinate in pixels for text placement.
 *    string      - Character. Text content to render.
 *    fontcolor   - Array or NIL. RGB color array {R, G, B} for text color (default: black {0, 0, 0}).
 *    backcolor   - Array or NIL. RGB color array {R, G, B} for text background (default: white {255, 255, 255}).
 *    fontname    - Character or NIL. Font family name (default: system/form default).
 *    fontsize    - Numeric or NIL. Font size in points (default: system/form default).
 *    bold        - Logical or NIL. Enables bold font weight if .T.
 *    italic      - Logical or NIL. Enables italic font style if .T.
 *    underline   - Logical or NIL. Enables font underline if .T.
 *    strikeout   - Logical or NIL. Enables font strikeout if .T.
 *    transparent - Logical or NIL. Enables transparent text background if .T.
 *    angle       - Numeric or NIL. Rotation angle in degrees (default: 0).
 *    once        - Logical or NIL. If .T., draws once without adding to persistent repaint queue (default: .F.).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders text onto the specified form or device context via textdraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i] when 'once' is .F.
 *--------------------------------------------------------------------------------*/
FUNCTION drawtextout( window, row, col, string, fontcolor, backcolor, fontname, fontsize, bold, italic, underline, strikeout, transparent, angle, once )
   LOCAL FormHandle, FontHandle
   LOCAL torow, tocol
   LOCAL i

   // Resolve window handle whether passed as a form name string or direct handle
   IF hb_IsString( window )
      IF ( i := GetFormIndex( window ) ) > 0
         FormHandle := _HMG_aFormHandles [i]
      ENDIF
   ELSE
      FormHandle := window
   ENDIF

   // Verify window handle or device context object before executing draw calls
   IF IsWindowHandle( FormHandle ) .OR. ( GetObjectType( FormHandle ) == OBJ_DC )
      // Extract registered font attributes by reference if a handle exists
      IF ( FontHandle := GetFontHandle( FontName ) ) != 0
         GetFontParamByRef( FontHandle, @FontName, @FontSize, @bold, @italic, @underline, @strikeout, @angle )
      ENDIF

      // Apply default font properties and styling parameters
      __defaultNIL( @fontname, _HMG_DefaultFontName )
      __defaultNIL( @fontsize, _HMG_DefaultFontSize )
      hb_default( @backcolor, { 255, 255, 255 } )
      hb_default( @fontcolor, { 0, 0, 0 } )
      hb_default( @angle, 0 )
      hb_default( @once, .F. )

      // Calculate bounding box endpoint coordinates for text layout
      torow := row + iif( transparent .OR. !Empty( angle ), 0, fontsize + 4 )
      tocol := col + ( Len( string ) - 1 ) * fontsize
      textdraw( FormHandle, row, col, string, torow, tocol, fontcolor, backcolor, fontname, fontsize, bold, italic, underline, strikeout, transparent, angle )
      // Queue codeblock for persistent redrawing on WM_PAINT unless single-shot requested
      IF ! once
         AAdd ( _HMG_aFormGraphTasks [i], {|| textdraw( FormHandle,row,col,string,torow,tocol,fontcolor,backcolor,fontname,fontsize,bold,italic,underline,strikeout,transparent,angle ) } )
      ENDIF
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawline( window, row, col, row1, col1, penrgb, penwidth )
 *
 * Purpose:
 *    Draws a straight line segment on a form and registers the drawing operation
 *    in the form's task list for automatic repainting during window refresh events.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    row      - Numeric. Starting Y-coordinate in pixels.
 *    col      - Numeric. Starting X-coordinate in pixels.
 *    row1     - Numeric. Ending Y-coordinate in pixels.
 *    col1     - Numeric. Ending X-coordinate in pixels.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for line stroke (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Line thickness in pixels (default: 1).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders a line on the form surface via linedraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawline( window, row, col, row1, col1, penrgb, penwidth )
   LOCAL FormHandle
   LOCAL i

   // Validate registered form index and retrieve underlying window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen color and stroke width
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )

      // Perform immediate line rendering and store persistent redraw block
      linedraw( FormHandle, row, col, row1, col1, penrgb, penwidth )
      AAdd ( _HMG_aFormGraphTasks [i] , {|| linedraw( FormHandle,row,col,row1,col1,penrgb,penwidth ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawrect( window, row, col, row1, col1, penrgb, penwidth, fillrgb )
 *
 * Purpose:
 *    Draws a rectangle on a window with customizable border pen and fill color,
 *    and registers the operation in the window's graphics task list for repainting.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    row      - Numeric. Top-left Y-coordinate in pixels.
 *    col      - Numeric. Top-left X-coordinate in pixels.
 *    row1     - Numeric. Bottom-right Y-coordinate in pixels.
 *    col1     - Numeric. Bottom-right X-coordinate in pixels.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for border pen (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Border line thickness in pixels (default: 1).
 *    fillrgb  - Array or NIL. RGB color array {R, G, B} for interior fill (default: white {255, 255, 255}).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately draws rectangle graphics on target form via rectdraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawrect( window, row, col, row1, col1, penrgb, penwidth, fillrgb )
   LOCAL FormHandle
   LOCAL i
   LOCAL fill

   // Validate registered form index and retrieve target window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )
      // Evaluate fill mode flag based on whether fillrgb is provided as an array
      IF !( fill := ISARRAY( fillrgb ) )
         fillrgb := { 255, 255, 255 }
      ENDIF

      // Render rectangle immediately and record redraw task block
      rectdraw( FormHandle, row, col, row1, col1, penrgb, penwidth, fillrgb, fill )
      AAdd ( _HMG_aFormGraphTasks [i] , {|| rectdraw( FormHandle,row,col,row1,col1,penrgb,penwidth,fillrgb,fill ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawroundrect( window, row, col, row1, col1, width, height, penrgb, penwidth, fillrgb )
 *
 * Purpose:
 *    Draws a rounded rectangle on a window defined by bounding coordinates and
 *    corner ellipse dimensions, and registers the task for window repainting.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    row      - Numeric. Top-left Y-coordinate in pixels.
 *    col      - Numeric. Top-left X-coordinate in pixels.
 *    row1     - Numeric. Bottom-right Y-coordinate in pixels.
 *    col1     - Numeric. Bottom-right X-coordinate in pixels.
 *    width    - Numeric. Horizontal diameter of ellipse for rounded corners.
 *    height   - Numeric. Vertical diameter of ellipse for rounded corners.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for border pen (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Border line thickness in pixels (default: 1).
 *    fillrgb  - Array or NIL. RGB color array {R, G, B} for interior fill (default: white {255, 255, 255}).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders rounded rectangle on screen via roundrectdraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawroundrect( window, row, col, row1, col1, width, height, penrgb, penwidth, fillrgb )
   LOCAL FormHandle
   LOCAL i
   LOCAL fill

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )
      // Set fill flag and fallback color if fill parameter is not an array
      IF !( fill := ISARRAY( fillrgb ) )
         fillrgb := { 255, 255, 255 }
      ENDIF

      // Render rounded rectangle and queue persistent drawing task block
      roundrectdraw( FormHandle, row, col, row1, col1, width, height, penrgb, penwidth, fillrgb, fill )
      AAdd ( _HMG_aFormGraphTasks [i] , {|| roundrectdraw( FormHandle,row,col,row1,col1,width,height,penrgb,penwidth,fillrgb,fill ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawellipse( window, row, col, row1, col1, penrgb, penwidth, fillrgb )
 *
 * Purpose:
 *    Draws an ellipse or circle bounded by specified rectangular coordinates on a window,
 *    and registers the task for window repainting.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    row      - Numeric. Top-left Y-coordinate of bounding box in pixels.
 *    col      - Numeric. Top-left X-coordinate of bounding box in pixels.
 *    row1     - Numeric. Bottom-right Y-coordinate of bounding box in pixels.
 *    col1     - Numeric. Bottom-right X-coordinate of bounding box in pixels.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for outline (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Outline stroke thickness in pixels (default: 1).
 *    fillrgb  - Array or NIL. RGB color array {R, G, B} for interior fill (default: white {255, 255, 255}).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders ellipse graphics on form via ellipsedraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawellipse( window, row, col, row1, col1, penrgb, penwidth, fillrgb )
   LOCAL FormHandle
   LOCAL i
   LOCAL fill

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )
      // Determine if interior fill should be enabled
      IF !( fill := ISARRAY( fillrgb ) )
         fillrgb := { 255, 255, 255 }
      ENDIF

      // Render ellipse and queue repaint task block
      ellipsedraw( FormHandle, row, col, row1, col1, penrgb, penwidth, fillrgb, fill )
      AAdd ( _HMG_aFormGraphTasks [i] , {|| ellipsedraw( FormHandle,row,col,row1,col1,penrgb,penwidth,fillrgb,fill ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawarc( window, row, col, row1, col1, rowr, colr, rowr1, colr1, penrgb, penwidth )
 *
 * Purpose:
 *    Draws an elliptical arc segment on a window defined by a bounding rectangle
 *    and radial intersection points, and adds the task to the repainting queue.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    row      - Numeric. Top Y-coordinate of bounding box.
 *    col      - Numeric. Left X-coordinate of bounding box.
 *    row1     - Numeric. Bottom Y-coordinate of bounding box.
 *    col1     - Numeric. Right X-coordinate of bounding box.
 *    rowr     - Numeric. Y-coordinate defining arc start radial line.
 *    colr     - Numeric. X-coordinate defining arc start radial line.
 *    rowr1    - Numeric. Y-coordinate defining arc end radial line.
 *    colr1    - Numeric. X-coordinate defining arc end radial line.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for stroke (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Stroke width in pixels (default: 1).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders arc graphics via arcdraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawarc( window, row, col, row1, col1, rowr, colr, rowr1, colr1, penrgb, penwidth )
   LOCAL FormHandle
   LOCAL i

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )

      // Render arc segment and store persistent graphics task
      arcdraw( FormHandle, row, col, row1, col1, rowr, colr, rowr1, colr1, penrgb, penwidth )
      AAdd ( _HMG_aFormGraphTasks [i] , {|| arcdraw( FormHandle,row,col,row1,col1,rowr,colr,rowr1,colr1,penrgb,penwidth ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawpie( window, row, col, row1, col1, rowr, colr, rowr1, colr1, penrgb, penwidth, fillrgb )
 *
 * Purpose:
 *    Draws a pie wedge sector on a window defined by a bounding rectangle and
 *    radial line vectors, and registers the operation in the window's repaint queue.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    row      - Numeric. Top Y-coordinate of bounding box.
 *    col      - Numeric. Left X-coordinate of bounding box.
 *    row1     - Numeric. Bottom Y-coordinate of bounding box.
 *    col1     - Numeric. Right X-coordinate of bounding box.
 *    rowr     - Numeric. Y-coordinate defining wedge start radial vector.
 *    colr     - Numeric. X-coordinate defining wedge start radial vector.
 *    rowr1    - Numeric. Y-coordinate defining wedge end radial vector.
 *    colr1    - Numeric. X-coordinate defining wedge end radial vector.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for border pen (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Border thickness in pixels (default: 1).
 *    fillrgb  - Array or NIL. RGB color array {R, G, B} for interior fill (default: white {255, 255, 255}).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders pie sector via piedraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawpie( window, row, col, row1, col1, rowr, colr, rowr1, colr1, penrgb, penwidth, fillrgb )
   LOCAL FormHandle
   LOCAL i
   LOCAL fill

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )
      // Evaluate fill mode flag based on presence of fill color array
      IF !( fill := ISARRAY( fillrgb ) )
         fillrgb := { 255, 255, 255 }
      ENDIF

      // Render pie wedge and append redraw block to form task list
      piedraw( FormHandle, row, col, row1, col1, rowr, colr, rowr1, colr1, penrgb, penwidth, fillrgb, fill )
      AAdd( _HMG_aFormGraphTasks [i] , {|| piedraw( FormHandle,row,col,row1,col1,rowr,colr,rowr1,colr1,penrgb,penwidth,fillrgb,fill ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawpolygon( window, apoints, penrgb, penwidth, fillrgb )
 *
 * Purpose:
 *    Draws a closed polygon on a window defined by an array of point coordinates,
 *    and registers the task for persistent window repainting.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    apoints  - Array of Arrays. Pairs of {{row1, col1}, {row2, col2}, ...} defining vertices.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for outline (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Line stroke width in pixels (default: 1).
 *    fillrgb  - Array or NIL. RGB color array {R, G, B} for polygon fill (default: white {255, 255, 255}).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately draws polygon graphics via polygondraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawpolygon( window, apoints, penrgb, penwidth, fillrgb )
   LOCAL FormHandle
   LOCAL i
   LOCAL fill
   LOCAL xarr := {}, yarr := {}

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )
      // Set fill flag and fallback color if fill parameter is not an array
      IF !( fill := ISARRAY( fillrgb ) )
         fillrgb := { 255, 255, 255 }
      ENDIF

      // Deconstruct array of {row, col} point pairs into separate x and y coordinate arrays
      AEval( apoints, { | x | AAdd( yarr, x[1] ), AAdd( xarr, x[2] ) } )
      // Render polygon and store persistent redraw task
      polygondraw( FormHandle, xarr, yarr, penrgb, penwidth, fillrgb, fill )
      AAdd( _HMG_aFormGraphTasks [i] , {|| polygondraw( FormHandle,xarr,yarr,penrgb,penwidth,fillrgb,fill ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION drawpolybezier( window, apoints, penrgb, penwidth )
 *
 * Purpose:
 *    Draws one or more cubic Bezier curves on a window using control point coordinates
 *    from an array, and registers the drawing operation in the window's repaint queue.
 *
 * Parameters:
 *    window   - Character or Numeric. Name of the form or form handle.
 *    apoints  - Array of Arrays. {{row1, col1}, ...} coordinate pairs for endpoints and control points.
 *    penrgb   - Array or NIL. RGB color array {R, G, B} for curve stroke (default: black {0, 0, 0}).
 *    penwidth - Numeric or NIL. Curve stroke width in pixels (default: 1).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Immediately renders Bezier curves via polybezierdraw().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION drawpolybezier( window, apoints, penrgb, penwidth )
   LOCAL FormHandle
   LOCAL xarr := {}, yarr := {}
   LOCAL i

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply default pen attributes
      hb_default( @penrgb, { 0, 0, 0 } )
      hb_default( @penwidth, 1 )

      // Unpack {row, col} point pairs into separate coordinate arrays
      AEval( apoints, { | x | AAdd( yarr, x[1] ), AAdd( xarr, x[2] ) } )
      // Draw Bezier spline and queue task block for form refresh
      polybezierdraw( FormHandle, xarr, yarr, penrgb, penwidth )
      AAdd( _HMG_aFormGraphTasks [i] , {|| polybezierdraw( FormHandle,xarr,yarr,penrgb,penwidth ) } )
   ENDIF

RETURN NIL

#define COLOR_BTNFACE	15

/*--------------------------------------------------------------------------------
 * FUNCTION HMG_DrawIcon( window, icon, row, col, w, h, rgb, transparent )
 *
 * Purpose:
 *    Renders an icon (from a numeric handle or named string resource) onto a window
 *    and registers the task in the form's task list for automatic repainting.
 *
 * Parameters:
 *    window      - Character or Numeric. Name of the form or form handle.
 *    icon        - Numeric or Character. HICON handle or named icon resource string.
 *    row         - Numeric. Top Y-coordinate in pixels.
 *    col         - Numeric. Left X-coordinate in pixels.
 *    w           - Numeric or NIL. Width in pixels (0 uses natural icon width).
 *    h           - Numeric or NIL. Height in pixels (0 uses natural icon height).
 *    rgb         - Array, Numeric, or NIL. RGB color array {R,G,B} or integer COLORREF for background.
 *    transparent - Logical or NIL. If .T., uses form background color for transparency (default: .F.).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Renders icon graphics onto form surface via DrawIconEx().
 *    - Appends a repaint codeblock to global array _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION HMG_DrawIcon( window, icon, row, col, w, h, rgb, transparent )
   LOCAL FormHandle
   LOCAL backcolor
   LOCAL i

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply dimension and transparency defaults
      hb_default( @w, 0 )
      hb_default( @h, 0 )
      hb_default( @transparent, .F. )
      // Resolve background color based on transparency mode and form configuration
      IF transparent
         backcolor := _HMG_aFormBkColor [i]
         IF IsArrayRGB( backcolor )
            rgb := RGB( backcolor [1], backcolor [2], backcolor [3] )
         ENDIF
      ELSE
         IF IsArrayRGB( rgb )
            rgb := RGB( rgb [1], rgb [2], rgb [3] )
         ENDIF
      ENDIF
      hb_default( @rgb, GetSysColor( COLOR_BTNFACE ) )

      // Handle numeric HICON handle versus named string resource icon loading
      IF ISNUMERIC( icon )
         DrawIconEx( FormHandle, Col, Row, icon, w, h, rgb, .F. )
         AAdd( _HMG_aFormGraphTasks [i] , {|| DrawIconEx( FormHandle, Col, Row, icon, w, h, rgb, .F. ) } )
      ELSEIF ISSTRING( icon )
         DrawIconEx( FormHandle, Col, Row, LoadIconByName( icon, w, h ), w, h, rgb, .T. )
         AAdd( _HMG_aFormGraphTasks [i] , {|| DrawIconEx( FormHandle, Col, Row, LoadIconByName( icon, w, h ), w, h, rgb, .T. ) } )
      ENDIF
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION HMG_DrawSysIcon( window, cIconDll, icon, row, col, w, h, rgb, transparent )
 *
 * Purpose:
 *    Extracts a system icon by index from a dynamic link library (DLL) and queues
 *    it for persistent rendering on a window.
 *
 * Parameters:
 *    window      - Character or Numeric. Name of the form or form handle.
 *    cIconDll    - Character or NIL. Path to icon library DLL (default: imageres.dll in system folder).
 *    icon        - Numeric. Zero-based index of the icon resource inside the DLL.
 *    row         - Numeric. Top Y-coordinate in pixels.
 *    col         - Numeric. Left X-coordinate in pixels.
 *    w           - Numeric or NIL. Target icon width in pixels (0 uses default).
 *    h           - Numeric or NIL. Target icon height in pixels (0 uses default).
 *    rgb         - Array, Numeric, or NIL. RGB color array {R,G,B} or integer COLORREF.
 *    transparent - Logical or NIL. If .T., enables transparent drawing mode (default: .F.).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Appends a repaint codeblock with ExtractIcon/DrawIconEx calls to _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION HMG_DrawSysIcon( window, cIconDll, icon, row, col, w, h, rgb, transparent )
   LOCAL FormHandle
   LOCAL backcolor
   LOCAL i

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Apply dimension and transparency defaults
      hb_default( @w, 0 )
      hb_default( @h, 0 )
      hb_default( @transparent, .F. )
      // Resolve background color array conversion if provided
      IF transparent
         backcolor := _HMG_aFormBkColor [i]
         IF IsArrayRGB( backcolor )
            rgb := RGB( backcolor [1], backcolor [2], backcolor [3] )
         ENDIF
      ELSE
         IF IsArrayRGB( rgb )
            rgb := RGB( rgb [1], rgb [2], rgb [3] )
         ENDIF
      ENDIF
      hb_default( @rgb, GetSysColor( COLOR_BTNFACE ) )
      hb_default( @cIconDll, System.SystemFolder + hb_ps() + "imageres.dll" )

      // Extract icon index from library DLL and queue persistent drawing task block
      IF ISNUMERIC( icon )
         AAdd( _HMG_aFormGraphTasks [i] , {|| DrawIconEx( FormHandle, Col, Row, ExtractIcon( cIconDll, icon ), w, h, rgb, .T. ) } )
      ENDIF
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION EraseWindow( window )
 *
 * Purpose:
 *    Clears all persistent graphic drawing tasks associated with a window and
 *    forces a full window repaint to restore the underlying background.
 *
 * Parameters:
 *    window - Character or Numeric. Name of the form or form handle.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Clears all elements from array _HMG_aFormGraphTasks[i].
 *    - Triggers Win32 RedrawWindow() call to refresh the form surface.
 *--------------------------------------------------------------------------------*/
FUNCTION EraseWindow( window )
   LOCAL i

   // Verify form registration index and check active window state
   IF ( i := GetFormIndex ( Window ) ) > 0
      IF ! _HMG_aFormDeleted [i]
         // Empty graph task queue array and trigger immediate window repaint
         IF ISARRAY ( _HMG_aFormGraphTasks [i] )
            ASize ( _HMG_aFormGraphTasks [i], 0 )
            RedrawWindow ( _HMG_aFormHandles [i] )
         ENDIF
      ENDIF
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION DrawWindowBoxIn( window, row, col, rowr, colr )
 *
 * Purpose:
 *    Draws a sunken 3D frame border (inset box) on a window and registers the task
 *    in the form's task list for automatic repainting.
 *
 * Parameters:
 *    window - Character or Numeric. Name of the form or form handle.
 *    row    - Numeric. Top Y-coordinate in pixels.
 *    col    - Numeric. Left X-coordinate in pixels.
 *    rowr   - Numeric. Bottom Y-coordinate in pixels.
 *    colr   - Numeric. Right X-coordinate in pixels.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Obtains temporary DC and renders inset box frame on window via WndBoxIn().
 *    - Appends a dynamic DC acquisition and repaint codeblock to _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION DrawWindowBoxIn( window, row, col, rowr, colr )
   LOCAL FormHandle
   LOCAL hDC
   LOCAL i

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Obtain window DC, render sunken 3D frame, and release DC immediately
      hDC := GetDC ( FormHandle )
      WndBoxIn ( hDC, row, col, rowr, colr )
      ReleaseDC ( FormHandle, hDC )
      // Queue codeblock for repainting that handles DC acquisition dynamically
      AAdd( _HMG_aFormGraphTasks [i] , {|| WndBoxIn( ( hDC := GetDC( FormHandle ) ), row, col, rowr, colr ), ReleaseDC( FormHandle, hDC ) } )
   ENDIF

RETURN NIL

/*--------------------------------------------------------------------------------
 * FUNCTION DrawWindowBoxRaised( window, row, col, rowr, colr )
 *
 * Purpose:
 *    Draws a raised 3D frame border on a window and registers the drawing operation
 *    in the form's task list for persistent repainting on window refresh.
 *
 * Parameters:
 *    window - Character or Numeric. Name of the form or form handle.
 *    row    - Numeric. Top Y-coordinate in pixels.
 *    col    - Numeric. Left X-coordinate in pixels.
 *    rowr   - Numeric. Bottom Y-coordinate in pixels.
 *    colr   - Numeric. Right X-coordinate in pixels.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    - Obtains temporary DC and renders raised 3D box frame on window via WndBoxRaised().
 *    - Appends a dynamic DC acquisition and repaint codeblock to _HMG_aFormGraphTasks[i].
 *--------------------------------------------------------------------------------*/
FUNCTION DrawWindowBoxRaised( window, row, col, rowr, colr )
   LOCAL FormHandle
   LOCAL hDC
   LOCAL i

   // Validate registered form index and retrieve window handle
   IF ( i := GetFormIndex ( Window ) ) > 0
      FormHandle := _HMG_aFormHandles [i]
      // Obtain window DC, render raised 3D frame, and release DC immediately
      hDC := GetDC ( FormHandle )
      WndBoxRaised ( hDC, row, col, rowr, colr )
      ReleaseDC ( FormHandle, hDC )
      // Queue codeblock for repainting that handles DC acquisition dynamically
      AAdd( _HMG_aFormGraphTasks [i] , {|| WndBoxRaised( ( hDC := GetDC( FormHandle ) ), row, col, rowr, colr ), ReleaseDC( FormHandle, hDC ) } )
   ENDIF

RETURN NIL