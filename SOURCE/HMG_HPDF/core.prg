#ifdef __XHARBOUR__
#define __SYSDATA__
#define __MINIPRINT__
#endif

#include <hmg.ch>
#include "harupdf.ch"

// Global memory variable containing the active HaruPDF session state array
MEMVAR _HMG_HPDFDATA

// Predefined line dash patterns for HaruPDF stroked paths
STATIC DASH_MODE1 := { 3 }             // Dotted line pattern: 3pt dash
STATIC DASH_MODE2 := { 3, 7 }          // Dashed line pattern: 3pt dash, 7pt space
STATIC DASH_MODE3 := { 8, 7, 2, 7 }    // Dash-dot line pattern: 8pt dash, 7pt space, 2pt dot, 7pt space

/*
 * _HMG_HPDF_INIT
 * Initializes a new HaruPDF engine document session and sets up configuration settings.
 *
 * Parameters:
 *   cPDFFile     - Character - Target output PDF file path.
 *   nOrientation - Numeric   - Document orientation (1 = Portrait, 2 = Landscape). Defaults to 1.
 *   nPaperSize   - Numeric   - Predefined paper size ID or 256 for user-defined dimensions. Defaults to 1.
 *   nPaperLength - Numeric   - Custom paper height in millimeters (used when nPaperSize == 256).
 *   nPaperWidth  - Numeric   - Custom paper width in millimeters (used when nPaperSize == 256).
 *
 * Return:
 *   Logical - .T. if document session initialized successfully; .F. on error.
 *
 * Side Effects:
 *   Creates global memory array _HMG_HPDFDATA and allocates a HaruPDF document handle.
 */
FUNCTION _HMG_HPDF_INIT( cPDFFile, nOrientation, nPaperSize, nPaperLength, nPaperWidth )

   // Set default parameters for orientation and paper size if not provided
   DEFAULT nOrientation := 1
   DEFAULT nPaperSize := 1

   // Declare global session state array
   PUBLIC _HMG_HPDFDATA := Array( 1 )

   // Verify that session array slot is uninitialized before proceeding
   IF ValType( _HMG_HPDFDATA[ 1 ] ) == 'U'
      _HMG_HPDFDATA[ 1 ] := { ;
         NIL, ;                 // Index 1: HaruPDF Document Object Handle
         cPDFFile, ;            // Index 2: Target File Name
         0, ;                   // Index 3: Paper Size Code
         0, ;                   // Index 4: Page Width in Points (Pixels)
         0, ;                   // Index 5: Page Height in Points (Pixels)
         nOrientation, ;        // Index 6: Page Orientation (1=Portrait, 2=Landscape)
         NIL, ;                 // Index 7: Current Active HaruPDF Page Handle
         'Helvetica', ;         // Index 8: Default Font Name
         12, ;                  // Index 9: Default Font Size
         "StandardEncoding", ;  // Index 10: Default Text Encoding
         {}, ;                  // Index 11: Document Outlines Collection
         {}, ;                  // Index 12: Document Pages Collection
         0 ;                    // Index 13: Active Page Index (1-based)
         }
      // Allocate native C HaruPDF document instance
      _HMG_HPDFDATA[ 1 ][ 1 ] := HPDF_New()
      IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
         _HMG_HPDF_Error( 2 )
         RETURN .F.
      ENDIF
      _HMG_HPDFDATA[ 1 ][ 3 ] := nPaperSize
      // Calculate custom dimensions if user-defined paper size flag is passed
      IF nPaperSize == 256 // User-defined custom dimensions
         IF _HMG_HPDFDATA[ 1 ][ 6 ] == 1 // Portrait orientation
            _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( nPaperWidth )
            _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( nPaperLength )
         ELSE // Landscape orientation
            _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( nPaperLength )
            _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( nPaperWidth )
         ENDIF
      ELSE
         // Set dimensions based on standard paper size code
         _HMG_HPDF_INIT_PAPERSIZE( nPaperSize )
      ENDIF
   ELSE
      // PDF document session already exists
      _HMG_HPDF_Error( 1 )
      RETURN .F.
   ENDIF

RETURN .T.

/*
 * _hmg_hpdf_setencoding
 * Configures global text character encoding for the PDF document.
 *
 * Parameters:
 *   cEncoding - Character - Name of text encoding (e.g., "UTF-8", "StandardEncoding", "WinAnsiEncoding").
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates HaruPDF encoder state and session variable index 10.
 */
FUNCTION _hmg_hpdf_setencoding( cEncoding )

   // Verify document object availability
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Enable UTF-8 library support or set standard encoder string
   IF cEncoding == "UTF-8"
      HPDF_UseUTFEncodings( _HMG_HPDFDATA[ 1 ][ 1 ] )
   ELSE
      HPDF_SetCurrentEncoder( _HMG_HPDFDATA[ 1 ][ 1 ], cEncoding )
   ENDIF
   _HMG_HPDFDATA[ 1 ][ 10 ] := cEncoding

RETURN NIL

/*
 * _hmg_hpdf_startdoc
 * Compatibility stub for initiating document scope.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   None
 */
FUNCTION _hmg_hpdf_startdoc()

RETURN NIL

/*
 * _hmg_hpdf_startpage
 * Appends a new page to the active PDF document and sets its width/height dimensions.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Creates a page instance, updates active page reference (index 7) and list (index 12).
 */
FUNCTION _hmg_hpdf_startpage()

   // Verify active document handle
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Verify that no page is currently active before creating a new page
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDFDATA[ 1 ][ 7 ] := HPDF_AddPage( _HMG_HPDFDATA[ 1 ][ 1 ] )
      IF Empty( _HMG_HPDFDATA[ 1 ][ 7 ] )
         _HMG_HPDF_Error( 9, "Start Page" )
         RETURN NIL
      ELSE
         // Register page handle into pages array and track current index
         AAdd( _HMG_HPDFDATA[ 1 ][ 12 ], _HMG_HPDFDATA[ 1 ][ 7 ] )
         _HMG_HPDFDATA[ 1 ][ 13 ] := Len( _HMG_HPDFDATA[ 1 ][ 12 ] )
         // Apply default session page width and height dimensions
         HPDF_Page_SetWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDFDATA[ 1 ][ 4 ] )
         HPDF_Page_SetHeight( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDFDATA[ 1 ][ 5 ] )
      ENDIF
   ELSE
      _HMG_HPDF_Error( 4 )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_InsertPage
 * Inserts a new page before a specified existing page index.
 *
 * Parameters:
 *   nPage - Numeric - 1-based target page index where the new page will be inserted.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies the page array structure and sets newly created page as active.
 */
FUNCTION _HMG_HPDF_InsertPage( nPage )

   LOCAL oOldPage := NIL
   LOCAL aPages := AClone( _HMG_HPDFDATA[ 1 ][ 12 ] )

   // Check bounds of target page index
   IF nPage > Len( aPages ) .OR. nPage < 1
      _HMG_HPDF_Error( 16 )
      RETURN NIL
   ENDIF
   oOldPage := aPages[ nPage ]
   IF Empty( oOldPage )
      _HMG_HPDF_Error( 16 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Ensure current page handle is released before inserting
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDFDATA[ 1 ][ 7 ] := HPDF_InsertPage( _HMG_HPDFDATA[ 1 ][ 1 ], oOldPage )
      IF Empty( _HMG_HPDFDATA[ 1, 7 ] )
         _HMG_HPDF_Error( 9, "Insert Page" )
         RETURN NIL
      ELSE
         // Expand array and insert newly allocated page handle at position nPage
         ASize( aPages, Len( aPages ) + 1 )
         AIns( aPages, nPage )
         aPages[ nPage ] := _HMG_HPDFDATA[ 1, 7 ]
         _HMG_HPDFDATA[ 1 ][ 12 ] := AClone( aPages )
         _HMG_HPDFDATA[ 1 ][ 13 ] := nPage
         HPDF_Page_SetWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDFDATA[ 1 ][ 4 ] )
         HPDF_Page_SetHeight( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDFDATA[ 1 ][ 5 ] )
      ENDIF
   ELSE
      _HMG_HPDF_Error( 4 )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_GoToPage
 * Switches active editing context to a previously created page.
 *
 * Parameters:
 *   nPage - Numeric - Target page index (1-based).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates active page pointer (index 7) and current page number (index 13).
 */
FUNCTION _HMG_HPDF_GoToPage( nPage )

   LOCAL oPage := NIL
   LOCAL aPages := AClone( _HMG_HPDFDATA[ 1 ][ 12 ] )

   // Check validity of requested page index
   IF nPage > Len( aPages ) .OR. nPage < 1
      _HMG_HPDF_Error( 18 )
      RETURN NIL
   ENDIF
   oPage := aPages[ nPage ]
   IF Empty( oPage )
      _HMG_HPDF_Error( 18 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Activate selected page if no page context is open
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDFDATA[ 1 ][ 7 ] := aPages[ nPage ]
      IF Empty( _HMG_HPDFDATA[ 1, 7 ] )
         _HMG_HPDF_Error( 19 )
         RETURN NIL
      ENDIF
      _HMG_HPDFDATA[ 1 ][ 13 ] := nPage
   ENDIF

RETURN NIL

/*
 * _hmg_hpdf_endpage
 * Closes drawing operations on the currently active page.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Resets active page pointer (index 7) to NIL.
 */
FUNCTION _hmg_hpdf_endpage()

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Reset active page handle reference
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ELSE
      _HMG_HPDFDATA[ 1 ][ 7 ] := NIL
   ENDIF

RETURN NIL

/*
 * HMG_HPDF_PageCount
 * Returns the total number of pages created in the document.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   Numeric - Number of pages in document, or NIL on error.
 *
 * Side Effects:
 *   None
 */
FUNCTION HMG_HPDF_PageCount()

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF

RETURN Len( _HMG_HPDFDATA[ 1 ][ 12 ] )

/*
 * HMG_HPDF_PageNo
 * Retrieves the sequence number of the currently active page.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   Numeric - Active page number (1-based), or NIL if no active page context.
 *
 * Side Effects:
 *   None
 */
FUNCTION HMG_HPDF_PageNo()

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

RETURN _HMG_HPDFDATA[ 1 ][ 13 ]

/*
 * _hmg_hpdf_enddoc
 * Finalizes PDF file generation, saves document to disk, and frees native memory.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Writes PDF file to disk, releases HaruPDF C instance, clears _HMG_HPDFDATA[1].
 */
FUNCTION _hmg_hpdf_enddoc()

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Save constructed PDF structure to disk
   IF HPDF_SaveToFile( _HMG_HPDFDATA[ 1 ][ 1 ], _HMG_HPDFDATA[ 1 ][ 2 ] ) != 0
      _HMG_HPDF_Error( 20, "End Doc" )
   ENDIF
   // Release native C library allocation and clear session slot
   HPDF_Free( _HMG_HPDFDATA[ 1 ][ 1 ] )
   _HMG_HPDFDATA[ 1 ] := NIL

RETURN NIL

/*
 * _hmg_hpdf_abortdoc
 * Cancels document creation and releases allocated memory without saving output file.
 *
 * Parameters:
 *   None
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Frees native C structure, sets document handle to NIL.
 */
FUNCTION _hmg_hpdf_abortdoc()

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   HPDF_Free( _HMG_HPDFDATA[ 1 ][ 1 ] )
   _HMG_HPDFDATA[ 1 ][ 1 ] := NIL

RETURN NIL

/*
 * _HMG_HPDF_PRINT
 * Renders single-line text onto the active page with optional font styles, color, alignment, and rotation.
 *
 * Parameters:
 *   nRow       - Numeric   - Y coordinate in millimeters (from top edge).
 *   nCol       - Numeric   - X coordinate in millimeters (from left edge).
 *   cFontName  - Character - Font family name or TTF file path.
 *   nFontSize  - Numeric   - Font size in points.
 *   nRColor    - Numeric   - Red color component (0-255).
 *   nGColor    - Numeric   - Green color component (0-255).
 *   nBColor    - Numeric   - Blue color component (0-255).
 *   cText      - Character - Text string to render.
 *   lBold      - Logical   - Enable bold style flag.
 *   lItalic    - Logical   - Enable italic/oblique style flag.
 *   lUnderline - Logical   - Simulate underline flag.
 *   lStrikeout - Logical   - Simulate strikeout flag.
 *   lColor     - Logical   - Apply custom RGB fill color flag.
 *   lFont      - Logical   - Font specified flag.
 *   lSize      - Logical   - Size specified flag.
 *   cAlign     - Character - Text alignment ('LEFT', 'CENTER', 'RIGHT').
 *   nAngle     - Numeric   - Text rotation angle in degrees.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders text and vector line annotations directly onto active HaruPDF page stream.
 */
FUNCTION _HMG_HPDF_PRINT( nRow, nCol, cFontName, nFontSize, nRColor, nGColor, nBColor, cText, lBold, lItalic, lUnderline, lStrikeout, lColor, lFont, lSize, cAlign, nAngle )

   // Convert millimetric coordinates to PDF points (origin at bottom-left)
   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nTextWidth
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL oFont := NIL
   LOCAL cFont
   LOCAL nRad := 0

   // Initialize parameter defaults
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lUnderline := .F.
   DEFAULT lStrikeout := .F.
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''
   DEFAULT nAngle := 0

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Set active text fill color normalized to 0.0 - 1.0 range
   IF lColor
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   // Resolve font family name or file path
   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )

   // Load TrueType font from disk if specified by file extension
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'

      cFont := HPDF_LoadTTFontFromFile( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      // Load standard Base-14 or special embedded PDF font
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF
   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ELSE
      // Apply active font handle and size
      HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
      nTextWidth := HPDF_Page_TextWidth( _HMG_HPDFDATA[ 1 ][ 7 ], cText )
      // Calculate alignment offsets for standard 0-degree or 90-degree rotated text
      IF nAngle == 0
         DO CASE
         CASE Upper( AllTrim( cAlign ) ) == 'CENTER'
            nxPos -= ( nTextWidth / 2 )
         CASE Upper( AllTrim( cAlign ) ) == 'RIGHT'
            nxPos -= ( nTextWidth )
         ENDCASE
      ELSEIF nAngle == 90
         DO CASE
         CASE Upper( AllTrim( cAlign ) ) == 'CENTER'
            nyPos -= ( nTextWidth / 2 )
         CASE Upper( AllTrim( cAlign ) ) == 'RIGHT'
            nyPos -= ( nTextWidth )
         ENDCASE
      ENDIF
      HPDF_Page_BeginText( _HMG_HPDFDATA[ 1 ][ 7 ] )
      // Apply coordinate transformation matrix for arbitrary rotation angles
      IF nAngle != 0
         nRad := nAngle / 180 * 3.141592 // Convert degrees to radians
         HPDF_Page_SetTextMatrix( _HMG_HPDFDATA[ 1 ][ 7 ], cos( nRad ), sin( nRad ), -sin( nRad ), cos( nRad ), nxPos, nyPos )
      ENDIF
      HPDF_PAGE_TEXTOUT( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, cText )
      HPDF_Page_EndText( _HMG_HPDFDATA[ 1 ][ 7 ] )
      // Simulate underline or strikeout line effects via vector paths
      IF lStrikeout .OR. lUnderline
         IF lUnderline // Draw underline line along text baseline
            _HMG_HPDF_LINE( _HMG_HPDF_Pixel2MM( nHeight - nyPos ), _HMG_HPDF_Pixel2MM( nxPos ), _HMG_HPDF_Pixel2MM( nHeight - nyPos + ( nTextWidth * -sin( nRad ) ) ), _HMG_HPDF_Pixel2MM( nxPos + ( nTextWidth * cos( nRad ) ) ), _HMG_HPDF_Pixel2MM( .5 ), nRColor, nGColor, nBColor, .T., lColor )
         ENDIF
         IF lStrikeout // Offset position and draw strikeout line through vertical center
            nyPos += ( ( nFontSize / 2.5 ) * cos( nRad ) )
            nxPos -= ( ( nFontSize / 2.5 ) * sin( nRad ) )
            _HMG_HPDF_LINE( _HMG_HPDF_Pixel2MM( nHeight - nyPos ), _HMG_HPDF_Pixel2MM( nxPos ), _HMG_HPDF_Pixel2MM( nHeight - nyPos + ( nTextWidth * -sin( nRad ) ) ), _HMG_HPDF_Pixel2MM( nxPos + ( nTextWidth * cos( nRad ) ) ), _HMG_HPDF_Pixel2MM( .5 ), nRColor, nGColor, nBColor, .T., lColor )
         ENDIF
      ENDIF
   ENDIF

RETURN NIL

// Bounding box index definitions for HPDF_Font_GetBBox
#define bbox_left   1
#define bbox_top    2
#define bbox_right  3
#define bbox_bottom 4

/*
 * _HMG_HPDF_MULTILINE_PRINT
 * Prints formatted multi-line text block within a defined rectangle, supporting word wrap and auto-fitting.
 *
 * Parameters:
 *   nRow       - Numeric   - Top coordinate in millimeters.
 *   nCol       - Numeric   - Left coordinate in millimeters.
 *   nToRow     - Numeric   - Bottom boundary coordinate in millimeters.
 *   nToCol     - Numeric   - Right boundary coordinate in millimeters.
 *   cFontName  - Character - Font family name or TTF path.
 *   nFontSize  - Numeric   - Font size in points.
 *   nRColor    - Numeric   - Red color intensity (0-255).
 *   nGColor    - Numeric   - Green color intensity (0-255).
 *   nBColor    - Numeric   - Blue color intensity (0-255).
 *   cText      - Character - Paragraph text to format and render.
 *   lBold      - Logical   - Bold style flag.
 *   lItalic    - Logical   - Italic style flag.
 *   lUnderline - Logical   - Underline flag.
 *   lStrikeout - Logical   - Strikeout flag.
 *   lColor     - Logical   - Enable custom fill color flag.
 *   lFont      - Logical   - Font specified flag.
 *   lSize      - Logical   - Size specified flag.
 *   cAlign     - Character - Text alignment ('LEFT', 'CENTER', 'RIGHT', 'JUSTIFY').
 *   nAngle     - Numeric   - Rotation angle.
 *   lWrap      - Logical   - Word wrap control flag.
 *   cFit       - Character - Fitting mode ('FONTSIZEFIT' or 'HEIGHTFIT').
 *   xVariable  - Numeric   - [By Ref] Target variable receiving calculated bottom row in mm.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders multi-line wrapped text inside bounded rectangle and updates pass-by-reference output parameter.
 */
FUNCTION _HMG_HPDF_MULTILINE_PRINT ( nRow, nCol, nToRow, nToCol, cFontName, nFontSize, nRColor, nGColor, nBColor, cText, lBold, lItalic, lUnderline, lStrikeout, lColor, lFont, lSize, cAlign, nAngle, lWrap, cFit, xVariable )

   // Convert millimetric box boundaries to PDF coordinate space
   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL nToxPos := nxPos + _HMG_HPDF_MM2Pixel( nToCol - nCol )
   LOCAL nToyPos := nyPos - _HMG_HPDF_MM2Pixel( nToRow - nRow )
   LOCAL oFont := NIL
   LOCAL cFont
   LOCAL nRad
   LOCAL cTextIn, cTextOut, cLine, nLineSpacingPrev, nLineSpacing, nLineCount, nLineLen, bbox, nAreaHeight, nxLine

   // Set default parameter values
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lUnderline := .F.
   DEFAULT lStrikeout := .F.
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''
   DEFAULT nAngle := 0
   DEFAULT lWrap := .F.
   DEFAULT cFit := ''

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Set normalized RGB fill color
   IF lColor
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )

   // Load or fetch font instance
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'

      cFont := HPDF_LoadTTFontFromFile( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF
   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ELSE
      // Handle rotated multiline text using matrix context save/restore
      IF nAngle != 0
         nRad := nAngle / 180 * 3.141592 // Convert angle to radians
         HPDF_Page_GSave ( _HMG_HPDFDATA[ 1 ][ 7 ] )
         HPDF_Page_Concat ( _HMG_HPDFDATA[ 1 ][ 7 ], cos( nRad ), sin( nRad ), -sin( nRad ), cos( nRad ), nxPos, nyPos )

         HPDF_Page_BeginText ( _HMG_HPDFDATA[ 1 ][ 7 ] )
         HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
         DO CASE
         CASE Upper( cAlign ) == 'CENTER'
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], 0, 0, nToxPos - nxPos, nToyPos - nyPos, cText, HPDF_TALIGN_CENTER, NIL )
         CASE Upper( cAlign ) == 'RIGHT'
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], 0, 0, nToxPos - nxPos, nToyPos - nyPos, cText, HPDF_TALIGN_RIGHT, NIL )
         CASE Upper( cAlign ) == 'JUSTIFY'
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], 0, 0, nToxPos - nxPos, nToyPos - nyPos, cText, HPDF_TALIGN_JUSTIFY, NIL )
         OTHERWISE
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], 0, 0, nToxPos - nxPos, nToyPos - nyPos, cText, HPDF_TALIGN_LEFT, NIL )
         ENDCASE
         HPDF_Page_EndText ( _HMG_HPDFDATA[ 1 ][ 7 ] )
         HPDF_Page_GRestore ( _HMG_HPDFDATA[ 1 ][ 7 ] )
      ELSE
         // Standard axis-aligned multiline printing with optional auto-fit step
         nLineSpacingPrev := HPDF_Page_GetTextLeading( _HMG_HPDFDATA[ 1 ][ 7 ] )
         nLineSpacing := nLineSpacingPrev
         bbox := HPDF_Font_GetBBox ( oFont )
         IF nLineSpacing == 0 // Derive default line leading from font bounding box
            nLineSpacing := ( bbox[ bbox_top ] - bbox[ bbox_bottom ] ) / 1000 * nFontSize
         ENDIF

         // Loop to adjust font size and line leading if FONTSIZEFIT mode is active
         DO WHILE .T.
            HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
            HPDF_Page_SetTextLeading( _HMG_HPDFDATA[ 1 ][ 7 ], nLineSpacing )

            cTextIn := cText
            cTextOut := ""
            nLineCount := 0

            // Measure line breaking dynamically across target box width
            DO WHILE ! Empty( cTextIn )
               nLineLen := HPDF_Page_MeasureText( _HMG_HPDFDATA[ 1 ][ 7 ], cTextIn, nToxPos - nxPos, ! lWrap, NIL )
               IF nLineLen = 0
                  EXIT
               ENDIF
               nLineCount++
               cLine := Trim( hb_USubStr( cTextIn, 1, nLineLen ) )
               cTextIn := hb_USubStr( cTextIn, nLineLen + 1 )
               cTextOut += cLine + IF( ! Empty( cTextIn ), " ", "" )
            ENDDO

            // Total vertical space required by formatted text block
            nAreaHeight := ( ( nLineCount - 1 ) * nLineSpacing ) + ;
            ( ( bbox[ bbox_top ] - bbox[ bbox_bottom ] ) / 1000 * nFontSize ) + .01

            // Exit fit loop if font fitting is disabled or text fits inside target height
            IF !( Upper( cFit ) == 'FONTSIZEFIT' ) .OR. ;
               nAreaHeight <= nyPos - nToyPos .OR. ;
               nFontSize <= 4
               EXIT
            ENDIF
            nFontSize -= 0.1 // Iteratively reduce font size
            nLineSpacing := ( bbox[ bbox_top ] - bbox[ bbox_bottom ] ) / 1000 * nFontSize
         ENDDO

         cText := cTextOut

         // Adjust bottom position if HEIGHTFIT mode is active
         IF Upper( cFit ) == 'HEIGHTFIT'
            nToyPos := nyPos - nAreaHeight
         ENDIF

         // Pass back calculated ending row in millimeters to caller variable
         xVariable := Round( _HMG_HPDF_Pixel2MM ( nyPos - nToyPos ) + nRow, 1 )

         // Draw multiline text block inside bounding rectangle
         HPDF_Page_BeginText( _HMG_HPDFDATA[ 1 ][ 7 ] )
         HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
         DO CASE
         CASE Upper( cAlign ) == 'CENTER'
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, nToxPos, nToyPos, cText, HPDF_TALIGN_CENTER, NIL )
         CASE Upper( cAlign ) == 'RIGHT'
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, nToxPos, nToyPos, cText, HPDF_TALIGN_RIGHT, NIL )
         CASE Upper( cAlign ) == 'JUSTIFY'
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, nToxPos, nToyPos, cText, HPDF_TALIGN_JUSTIFY, NIL )
         OTHERWISE
            HPDF_Page_TextRect( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, nToxPos, nToyPos, cText, HPDF_TALIGN_LEFT, NIL )
         ENDCASE
         HPDF_Page_EndText( _HMG_HPDFDATA[ 1 ][ 7 ] )

         // Restore previous leading setting
         HPDF_Page_SetTextLeading( _HMG_HPDFDATA[ 1 ][ 7 ], nLineSpacingPrev )
         // Render line annotations for underline / strikeout on each wrapped line
         IF lUnderline .OR. lStrikeout
            nyPos -= bbox[ bbox_top ] / 1000 * nFontSize - IF ( lStrikeout, ( nFontSize / 2.5 ), 0 )
            DO WHILE ! Empty( cText )
               nLineLen := HPDF_Page_MeasureText( _HMG_HPDFDATA[ 1 ][ 7 ], cText, nToxPos - nxPos, ! lWrap, NIL )
               IF nLineLen = 0
                  EXIT
               ENDIF
               cLine := Trim( hb_USubStr( cText, 1, nLineLen ) )
               cText := hb_USubStr( cText, nLineLen + 1 )
               nLineLen := HPDF_Page_TextWidth( _HMG_HPDFDATA[ 1 ][ 7 ], cLine )
               nxLine := 0
               DO CASE
               CASE Upper( cAlign ) == 'CENTER'
                  nxLine := ( nToxpos - nxPos - nLineLen ) / 2
               CASE Upper( cAlign ) == 'RIGHT'
                  nxLine := nToxpos - nxPos - nLineLen
               CASE Upper( cAlign ) == 'JUSTIFY'
                  IF ! Empty( cText )
                     nLineLen := nToxpos - nxPos
                  ENDIF
               ENDCASE

               // Draw individual line decoration line vector
               _HMG_HPDF_LINE ( _HMG_HPDF_Pixel2MM( nHeight - nyPos ), ;
                  _HMG_HPDF_Pixel2MM( nxPos + nxLine ), ;
                  _HMG_HPDF_Pixel2MM( nHeight - nyPos ), ;
                  _HMG_HPDF_Pixel2MM( nxPos + nxLine + nLineLen ), ;
                  _HMG_HPDF_Pixel2MM( .5 ), ;
                  nRColor, nGColor, nBColor, .T., lColor )

               nyPos -= nLineSpacing

            ENDDO
         ENDIF
      ENDIF
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_GetHeight_MULTILINE_PRINT
 * Calculates total vertical height in millimeters required to print multiline text.
 *
 * Parameters:
 *   cText     - Character - Text string to evaluate.
 *   nLen      - Numeric   - Line width boundary in millimeters.
 *   cFontName - Character - Font family or file name.
 *   nFontSize - Numeric   - Font size in points.
 *   lBold     - Logical   - Bold style flag.
 *   lItalic   - Logical   - Italic style flag.
 *   lWrap     - Logical   - Word wrap flag.
 *
 * Return:
 *   Numeric - Height required by text block in millimeters.
 *
 * Side Effects:
 *   None
 */
FUNCTION _HMG_HPDF_GetHeight_MULTILINE_PRINT ( cText, nLen, cFontName, nFontSize, lBold, lItalic, lWrap )

   LOCAL oFont
   LOCAL cFont
   LOCAL nLineSpacing, nLineCount, nLineLen, bbox, nAreaHeight

   // Apply default parameters
   DEFAULT cText := ''
   DEFAULT nLen := 0
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lWrap := .F.

   nLen := _HMG_HPDF_MM2Pixel ( nLen )

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN 0
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN 0
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )

   // Load font instance for measuring
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'

      cFont := HPDF_LOADTTFONTFROMFILE( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN 0
      ENDIF
      oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF

   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN 0
   ELSE
      nLineSpacing := HPDF_Page_GetTextLeading( _HMG_HPDFDATA[ 1 ][ 7 ] )
      bbox := HPDF_Font_GetBBox ( oFont )
      IF nLineSpacing == 0 // Calculate standard line spacing based on font bounding box
         nLineSpacing := ( bbox[ bbox_top ] - bbox[ bbox_bottom ] ) / 1000 * nFontSize
      ENDIF

      HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
      nLineCount := 0

      // Measure character fitting per line block
      DO WHILE ! Empty( cText )
         nLineLen := HPDF_Page_MeasureText( _HMG_HPDFDATA[ 1 ][ 7 ], cText, nLen, ! lWrap, NIL )
         IF nLineLen = 0
            EXIT
         ENDIF
         nLineCount++
         cText := hb_USubStr( cText, nLineLen + 1 )
      ENDDO
   ENDIF
   // Calculate total vertical height including baseline adjustments
   nAreaHeight := ( ( nLineCount - 1 ) * nLineSpacing ) + ;
   ( ( bbox[ bbox_top ] - bbox[ bbox_bottom ] ) / 1000 * nFontSize ) + .01

RETURN _HMG_HPDF_Pixel2MM ( nAreaHeight )

/*
 * _HMG_HPDF_IMAGE
 * Draws a PNG or JPEG image onto the active page from disk or embedded application resources.
 *
 * Parameters:
 *   cImage       - Character - File path or resource identifier.
 *   nRow         - Numeric   - Top position in millimeters.
 *   nCol         - Numeric   - Left position in millimeters.
 *   nImageheight - Numeric   - Target image height in millimeters.
 *   nImageWidth  - Numeric   - Target image width in millimeters.
 *   lStretch     - Logical   - Image scaling/stretch flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Embeds raster image dynamic data into PDF page stream.
 */
FUNCTION _HMG_HPDF_IMAGE ( cImage, nRow, nCol, nImageheight, nImageWidth, lStretch )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL oImage, cMem

   DEFAULT lStretch := .F.
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF
   // Attempt loading image file from disk path
   IF hb_FileExists( cImage )
      IF Upper( cFileExt( cImage ) ) == '.PNG'
         oImage := HPDF_LoadPngImageFromFile( _HMG_HPDFDATA[ 1 ][ 1 ], cImage )
      ELSE
         oImage := HPDF_LoadJPEGImageFromFile( _HMG_HPDFDATA[ 1 ][ 1 ], cImage )
      ENDIF
   // Attempt loading raw binary image stream from executable resources
   ELSEIF !Empty( cMem := HMG_LoadResourceRawFile( cImage, "PNG" ) )
      oImage := HPDF_LOADPNGIMAGEFROMMEM( _HMG_HPDFDATA[ 1 ][ 1 ], cMem, Len( cMem ) )
   ELSEIF !Empty( cMem := HMG_LoadResourceRawFile( cImage, "JPG" ) )
      oImage := HPDF_LOADJPEGIMAGEFROMMEM( _HMG_HPDFDATA[ 1 ][ 1 ], cMem, Len( cMem ) )
   ELSE
      _HMG_HPDF_Error( 7 )
      RETURN NIL
   ENDIF
   IF Empty( oImage )
      _HMG_HPDF_Error( 7 )
      RETURN NIL
   ENDIF
   // Render loaded image at specified coordinate box
   HPDF_Page_DrawImage( _HMG_HPDFDATA[ 1 ][ 7 ], oImage, nxPos, nyPos - _HMG_HPDF_MM2Pixel( nImageHeight ), _HMG_HPDF_MM2Pixel( nImageWidth ), _HMG_HPDF_MM2Pixel( nImageHeight ) )

RETURN NIL

/*
 * _HMG_HPDF_LINE
 * Draws a straight line vector segment between two coordinate points.
 *
 * Parameters:
 *   nRow       - Numeric   - Starting point Y coordinate in mm.
 *   nCol       - Numeric   - Starting point X coordinate in mm.
 *   nToRow     - Numeric   - Ending point Y coordinate in mm.
 *   nToCol     - Numeric   - Ending point X coordinate in mm.
 *   nLineWidth - Numeric   - Thickness of stroke line in mm.
 *   nRColor    - Numeric   - Red component (0-255).
 *   nGColor    - Numeric   - Green component (0-255).
 *   nBColor    - Numeric   - Blue component (0-255).
 *   lWidth     - Logical   - Custom width flag.
 *   lColor     - Logical   - Custom color flag.
 *   style      - Character - Dash style ('HPDFDOTTED', 'HPDFDASHED', 'HPDFDASHDOT').
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Appends path and stroke graphics commands to active page context.
 */
FUNCTION _HMG_HPDF_LINE ( nRow, nCol, nToRow, nToCol, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor, style )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL nToxPos := nxPos + _HMG_HPDF_MM2Pixel( nToCol - nCol )
   LOCAL nToyPos := nyPos - _HMG_HPDF_MM2Pixel( nToRow - nRow )

   // Set default parameters
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Configure stroke RGB values
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   // Set stroke width in points
   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Apply dashed pattern if requested
   IF ValType( style ) != 'U'
      DO CASE
      CASE Upper( style ) == 'HPDFDOTTED'
         _HMG_HPDF_SetDash( 1 )
      CASE Upper( style ) == 'HPDFDASHED'
         _HMG_HPDF_SetDash( 2 )
      CASE Upper( style ) == 'HPDFDASHDOT'
         _HMG_HPDF_SetDash( 3 )
      ENDCASE
   ENDIF
   // Construct line path and stroke
   HPDF_Page_MoveTo( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos )
   HPDF_Page_LineTo( _HMG_HPDFDATA[ 1 ][ 7 ], nToxPos, nToyPos )
   HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   // Reset dash pattern back to solid line
   IF ValType( style ) != 'U'
      _HMG_HPDF_SetDash( 0 )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_RECTANGLE
 * Draws a standard axis-aligned rectangle vector shape.
 *
 * Parameters:
 *   nRow       - Numeric - Top position in mm.
 *   nCol       - Numeric - Left position in mm.
 *   nToRow     - Numeric - Bottom position in mm.
 *   nToCol     - Numeric - Right position in mm.
 *   nLineWidth - Numeric - Line border thickness in mm.
 *   nRColor    - Numeric - Red component (0-255).
 *   nGColor    - Numeric - Green component (0-255).
 *   nBColor    - Numeric - Blue component (0-255).
 *   lWidth     - Logical - Custom stroke width flag.
 *   lColor     - Logical - Custom color flag.
 *   lFilled    - Logical - Fill rectangle interior flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Appends rectangle graphics path and draws stroke/fill to page.
 */
FUNCTION _HMG_HPDF_RECTANGLE ( nRow, nCol, nToRow, nToCol, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor, lFilled )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )

   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.
   DEFAULT lFilled := .F.

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Configure stroke and fill colors
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      IF lFilled
         HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      ENDIF
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   // Apply line width settings
   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
      IF lFilled
         HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
      ENDIF
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Build rectangle path
   HPDF_Page_Rectangle( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos - _HMG_HPDF_MM2Pixel( nToRow - nRow ), _HMG_HPDF_MM2Pixel( nToCol - nCol ), _HMG_HPDF_MM2Pixel( nToRow - nRow ) )
   IF lFilled
      HPDF_Page_FillStroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ELSE
      HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_ROUNDRECTANGLE
 * Draws a rectangle vector path with rounded corners using Bezier curves.
 *
 * Parameters:
 *   nRow       - Numeric - Top coordinate in mm.
 *   nCol       - Numeric - Left coordinate in mm.
 *   nToRow     - Numeric - Bottom coordinate in mm.
 *   nToCol     - Numeric - Right coordinate in mm.
 *   nLineWidth - Numeric - Line border width in mm.
 *   nRColor    - Numeric - Red component (0-255).
 *   nGColor    - Numeric - Green component (0-255).
 *   nBColor    - Numeric - Blue component (0-255).
 *   lWidth     - Logical - Width flag.
 *   lColor     - Logical - Color flag.
 *   lFilled    - Logical - Fill shape interior flag.
 *   nRoundness - Numeric - Corner radius in millimeters.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders rounded rectangle vector path onto active page context.
 */
FUNCTION _HMG_HPDF_ROUNDRECTANGLE ( nRow, nCol, nToRow, nToCol, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor, lFilled, nRoundness )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL nToxPos := nxPos + _HMG_HPDF_MM2Pixel( nToCol - nCol )
   LOCAL nToyPos := nyPos - _HMG_HPDF_MM2Pixel( nToRow - nRow )
   LOCAL nRectWidth := nToCol - nCol
   LOCAL nRectHeight := nToRow - nRow

   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.
   DEFAULT lFilled := .F.
   DEFAULT nRoundness := 0
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF
   // Apply stroke and fill colors
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      IF lFilled
         HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      ENDIF
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF
   // Set line width
   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
      IF lFilled
         HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
      ENDIF
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Calculate default or validate specified corner roundness radius
   IF nRoundness == 0
      nRoundness := Int( Min( nRectWidth, nRectHeight ) * 10 / 100 )
   ELSE
      IF nRoundness > Int( Min( nRectWidth, nRectHeight ) / 2 )
         _HMG_HPDF_Error( 8 )
         RETURN NIL
      ENDIF
   ENDIF

   nRoundness := _HMG_HPDF_MM2Pixel( nRoundness )

   // Construct path using straight segments and Bezier curves at corners
   HPDF_Page_MoveTo( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos + nRoundness, nyPos ) // Top side start
   HPDF_Page_LineTo( _HMG_HPDFDATA[ 1 ][ 7 ], nToxPos - nRoundness, nyPos ) // Top line segment
   HPDF_Page_CurveTo2( _HMG_HPDFDATA[ 1 ][ 7 ], nToxPos, nyPos, nToxPos, nyPos - nRoundness ) // Top-right corner curve
   HPDF_Page_LineTo( _HMG_HPDFDATA[ 1 ][ 7 ], nToxPos, nToyPos + nRoundness ) // Right line segment
   HPDF_Page_CurveTo2( _HMG_HPDFDATA[ 1 ][ 7 ], nToxPos, nToyPos, nToxPos - nRoundness, nToyPos ) // Bottom-right corner curve
   HPDF_Page_LineTo( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos + nRoundness, nToyPos ) // Bottom line segment
   HPDF_Page_CurveTo2( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nToyPos, nxPos, nToyPos + nRoundness ) // Bottom-left corner curve
   HPDF_Page_LineTo( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos - nRoundness ) // Left line segment
   HPDF_Page_CurveTo2( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, nxPos + nRoundness, nyPos ) // Top-left corner curve

   // Draw stroke/fill along closed path
   IF lFilled
      HPDF_Page_FillStroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ELSE
      HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_CIRCLE
 * Draws a circle shape centered at specified coordinates.
 *
 * Parameters:
 *   nRow       - Numeric - Center Y position in mm.
 *   nCol       - Numeric - Center X position in mm.
 *   nR         - Numeric - Radius in mm.
 *   nLineWidth - Numeric - Line border width in mm.
 *   nRColor    - Numeric - Red component (0-255).
 *   nGColor    - Numeric - Green component (0-255).
 *   nBColor    - Numeric - Blue component (0-255).
 *   lWidth     - Logical - Custom width flag.
 *   lColor     - Logical - Custom color flag.
 *   lFilled    - Logical - Fill shape interior flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders circle path to page drawing context.
 */
FUNCTION _HMG_HPDF_CIRCLE( nRow, nCol, nR, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor, lFilled )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )

   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.
   DEFAULT lFilled := .F.
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Configure graphics stroke/fill parameters
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      IF lFilled
         HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      ENDIF
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Construct and render circle path
   HPDF_Page_Circle( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, _HMG_HPDF_MM2Pixel( nR ) )
   IF lFilled
      HPDF_Page_FillStroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ELSE
      HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_ELLIPSE
 * Draws an ellipse with specified horizontal and vertical radii.
 *
 * Parameters:
 *   nRow       - Numeric - Center Y position in mm.
 *   nCol       - Numeric - Center X position in mm.
 *   nHR        - Numeric - Horizontal radius in mm.
 *   nVR        - Numeric - Vertical radius in mm.
 *   nLineWidth - Numeric - Line border width in mm.
 *   nRColor    - Numeric - Red component (0-255).
 *   nGColor    - Numeric - Green component (0-255).
 *   nBColor    - Numeric - Blue component (0-255).
 *   lWidth     - Logical - Custom width flag.
 *   lColor     - Logical - Custom color flag.
 *   lFilled    - Logical - Fill shape interior flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Appends ellipse vector path to active page.
 */
FUNCTION _HMG_HPDF_ELLIPSE( nRow, nCol, nHR, nVR, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor, lFilled )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )

   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.
   DEFAULT lFilled := .F.
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Configure color and stroke properties
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      IF lFilled
         HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
      ENDIF
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Construct ellipse path
   HPDF_Page_Ellipse( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, _HMG_HPDF_MM2Pixel( nHR ), _HMG_HPDF_MM2Pixel( nVR ) )
   IF lFilled
      HPDF_Page_FillStroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ELSE
      HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_ARC
 * Draws a circular arc path between start and end angles.
 *
 * Parameters:
 *   nRow       - Numeric - Center point Y position in mm.
 *   nCol       - Numeric - Center point X position in mm.
 *   nR         - Numeric - Arc radius in mm.
 *   nFromAngle - Numeric - Starting angle in degrees.
 *   nToAngle   - Numeric - Ending angle in degrees.
 *   nLineWidth - Numeric - Stroke width in mm.
 *   nRColor    - Numeric - Red component (0-255).
 *   nGColor    - Numeric - Green component (0-255).
 *   nBColor    - Numeric - Blue component (0-255).
 *   lWidth     - Logical - Custom width flag.
 *   lColor     - Logical - Custom color flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders arc stroke onto active page stream.
 */
FUNCTION _HMG_HPDF_ARC( nRow, nCol, nR, nFromAngle, nToAngle, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )

   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Set color stroke
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Generate arc path and stroke
   HPDF_Page_Arc( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, _HMG_HPDF_MM2Pixel( nR ), nFromAngle, nToAngle )
   HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )

RETURN NIL

/*
 * _HMG_HPDF_CURVE
 * Draws a Bezier curve path using start, control, and target coordinates.
 *
 * Parameters:
 *   nRow       - Numeric - Start Y coordinate in mm.
 *   nCol       - Numeric - Start X coordinate in mm.
 *   nFromRow   - Numeric - Control point Y coordinate in mm.
 *   nFromCol   - Numeric - Control point X coordinate in mm.
 *   nToRow     - Numeric - Endpoint Y coordinate in mm.
 *   nToCol     - Numeric - Endpoint X coordinate in mm.
 *   nLineWidth - Numeric - Line stroke width in mm.
 *   nRColor    - Numeric - Red component (0-255).
 *   nGColor    - Numeric - Green component (0-255).
 *   nBColor    - Numeric - Blue component (0-255).
 *   lWidth     - Logical - Custom width flag.
 *   lColor     - Logical - Custom color flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders Bezier curve stroke onto page context.
 */
FUNCTION _HMG_HPDF_CURVE ( nRow, nCol, nFromRow, nFromCol, nToRow, nToCol, nLineWidth, nRColor, nGColor, nBColor, lWidth, lColor )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL nToxPos := nxPos + _HMG_HPDF_MM2Pixel( nToCol - nCol )
   LOCAL nToyPos := nyPos - _HMG_HPDF_MM2Pixel( nToRow - nRow )
   LOCAL nFromxPos := _HMG_HPDF_MM2Pixel( nFromCol )
   LOCAL nFromyPos := nHeight - _HMG_HPDF_MM2Pixel( nFromRow )

   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT nLineWidth := 1
   DEFAULT lWidth := .F.
   DEFAULT lColor := .F.

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Configure stroke attributes
   IF lColor
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBSTROKE( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   IF lWidth
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nlineWidth ) )
   ELSE
      HPDF_Page_SetLineWidth( _HMG_HPDFDATA[ 1 ][ 7 ], 1 )
   ENDIF
   // Construct Bezier curve path
   HPDF_Page_MoveTo( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos )
   HPDF_Page_CurveTo2( _HMG_HPDFDATA[ 1 ][ 7 ], nFromxPos, nFromyPos, nToxPos, nToyPos )
   HPDF_Page_Stroke( _HMG_HPDFDATA[ 1 ][ 7 ] )

RETURN NIL

/*
 * _HMG_HPDF_SetPassword
 * Sets owner and user security passwords for document encryption.
 *
 * Parameters:
 *   cOwnerPass - Character - Owner password string (grants full access).
 *   cUserPass  - Character - User password string (restricts operations). Defaults to empty.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates encryption properties of active HaruPDF document.
 */
FUNCTION _HMG_HPDF_SetPassword( cOwnerPass, cUserPass )

   DEFAULT cUserPass := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   HPDF_SetPassword( _HMG_HPDFDATA[ 1 ][ 1 ], cOwnerPass, cUserPass )

RETURN NIL

/*
 * _HMG_HPDF_SetCompression
 * Enables or configures internal PDF object compression.
 *
 * Parameters:
 *   cMode - Character - Compression target ('NONE', 'TEXT', 'IMAGE', 'METADATA', 'ALL').
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates compression mode state in HaruPDF C engine.
 */
FUNCTION _HMG_HPDF_SetCompression( cMode )

   DEFAULT cMode := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   cMode := Upper( cMode )
   DO CASE
   CASE cMode == 'NONE'
      HPDF_SetCompressionMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_COMP_NONE )
   CASE cMode == 'TEXT'
      HPDF_SetCompressionMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_COMP_TEXT )
   CASE cMode == 'IMAGE'
      HPDF_SetCompressionMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_COMP_IMAGE )
   CASE cMode == 'METADATA'
      HPDF_SetCompressionMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_COMP_METADATA )
   CASE cMode == 'ALL'
      HPDF_SetCompressionMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_COMP_ALL )
   OTHERWISE
      HPDF_SetCompressionMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_COMP_NONE )
   ENDCASE

RETURN NIL

/*
 * _HMG_HPDF_SetPermission
 * Sets user access permissions for encrypted PDF documents.
 *
 * Parameters:
 *   cMode - Character - Permission flag ('READ', 'PRINT', 'COPY', 'EDIT', 'EDIT_ALL').
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates document access flags in native library structure.
 */
FUNCTION _HMG_HPDF_SetPermission( cMode )

   DEFAULT cMode := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   cMode := Upper( cMode )
   DO CASE
   CASE cMode == 'READ'
      HPDF_SetPermission( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_ENABLE_READ )
   CASE cMode == 'PRINT'
      HPDF_SetPermission( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_ENABLE_PRINT )
   CASE cMode == 'COPY'
      HPDF_SetPermission( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_ENABLE_COPY )
   CASE cMode == 'EDIT'
      HPDF_SetPermission( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_ENABLE_EDIT )
   CASE cMode == 'EDIT_ALL'
      HPDF_SetPermission( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_ENABLE_EDIT_ALL )
   ENDCASE

RETURN NIL

/*
 * _HMG_HPDF_SetPageMode
 * Configures how the document should be displayed when opened in a PDF viewer.
 *
 * Parameters:
 *   cMode - Character - Display mode ('OUTLINE', 'NONE', 'THUMBS', 'FULL_SCREEN', 'EOF').
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies viewer preferences in document catalog.
 */
FUNCTION _HMG_HPDF_SetPageMode( cMode )

   DEFAULT cMode := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   cMode := Upper( cMode )
   DO CASE
   CASE cMode == 'OUTLINE'
      HPDF_SetPageMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_PAGE_MODE_USE_OUTLINE )
   CASE cMode == 'NONE'
      HPDF_SetPageMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_PAGE_MODE_USE_NONE )
   CASE cMode == 'THUMBS'
      HPDF_SetPageMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_PAGE_MODE_USE_THUMBS )
   CASE cMode == 'FULL_SCREEN'
      HPDF_SetPageMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_PAGE_MODE_FULL_SCREEN )
   CASE cMode == 'EOF'
      HPDF_SetPageMode( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_PAGE_MODE_EOF )
   ENDCASE

RETURN NIL

/*
 * _HMG_HPDF_RootOutline
 * Adds a document-level outline bookmark node to the outline tree hierarchy.
 *
 * Parameters:
 *   cTitle  - Character - Display text for the outline item.
 *   cName   - Character - Unique identifier for referencing this outline node.
 *   cParent - Character - Identifier of parent outline node, or empty string for root level.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Adds outline item handle and name tag to session outlines array (index 11).
 */
FUNCTION _HMG_HPDF_RootOutline( cTitle, cName, cParent )

   LOCAL aOutlines
   LOCAL oOutline, i

   DEFAULT cParent := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF Len( AllTrim( cTitle ) ) == 0
      _HMG_HPDF_Error( 11 )
      RETURN NIL
   ENDIF
   IF Len( AllTrim( cName ) ) == 0
      _HMG_HPDF_Error( 12 )
      RETURN NIL
   ENDIF
   // Create top-level root outline entry if parent is empty
   IF Len( AllTrim( cParent ) ) == 0
      oOutline := HPDF_CreateOutline( _HMG_HPDFDATA[ 1 ][ 1 ], NIL, cTitle, HPDF_GetCurrentEncoder() )
      IF Empty( oOutLine )
         _HMG_HPDF_Error( 10 )
         RETURN NIL
      ELSE
         AAdd( _HMG_HPDFDATA[ 1 ][ 11 ], { oOutline, cName } )
      ENDIF
   ELSE
      // Search existing outlines array for matching parent node
      aOutLines := AClone( _HMG_HPDFDATA[ 1 ][ 11 ] )
      FOR i := 1 TO Len( aOutLines )
         IF Upper( AllTrim( aOutLines[ i, 2 ] ) ) == Upper( AllTrim( cParent ) )
            oOutline := HPDF_CreateOutline( _HMG_HPDFDATA[ 1 ][ 1 ], aOutLines[ i, 1 ], cTitle, HPDF_GetCurrentEncoder() )
            IF Empty( oOutLine )
               _HMG_HPDF_Error( 10 )
               RETURN NIL
            ELSE
               AAdd( _HMG_HPDFDATA[ 1 ][ 11 ], { oOutline, cName } )
            ENDIF
            EXIT
         ENDIF
      NEXT i
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_PageOutline
 * Creates a document outline item that targets the current page destination.
 *
 * Parameters:
 *   cTitle  - Character - Display title of outline bookmark.
 *   cParent - Character - Parent node name, or empty for top level.
 *   cName   - Character - Unique identification string for this bookmark.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Allocates page destination structure and attaches it to new outline item.
 */
FUNCTION _HMG_HPDF_PageOutline( cTitle, cParent, cName )

   LOCAL aOutlines
   LOCAL oOutline, i
   LOCAL oDestination

   DEFAULT cParent := ''
   DEFAULT cName := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF
   // Create target destination on current page
   oDestination := HPDF_Page_CreateDestination( _HMG_HPDFDATA[ 1 ][ 7 ] )
   IF Empty( oDestination )
      _HMG_HPDF_Error( 13 )
      RETURN NIL
   ENDIF
   IF Len( AllTrim( cParent ) ) == 0 // Create root outline entry
      oOutline := HPDF_CreateOutline( _HMG_HPDFDATA[ 1 ][ 1 ], NIL, cTitle, HPDF_GetCurrentEncoder() )
      IF Empty( oOutline )
         _HMG_HPDF_Error( 13 )
         RETURN NIL
      ENDIF
   ELSE
      // Locate parent node in registered outlines collection
      aOutlines := AClone( _HMG_HPDFDATA[ 1 ][ 11 ] )
      FOR i := 1 TO Len( aOutlines )
         IF Upper( AllTrim( aOutlines[ i, 2 ] ) ) == Upper( AllTrim( cParent ) )
            oOutline := HPDF_CreateOutline( _HMG_HPDFDATA[ 1 ][ 1 ], aOutLines[ i, 1 ], cTitle, HPDF_GetCurrentEncoder() )
            EXIT
         ENDIF
      NEXT i
      IF Empty( oOutline )
         _HMG_HPDF_Error( 14 )
         RETURN NIL
      ENDIF
   ENDIF
   IF Len( AllTrim( cName ) ) > 0
      AAdd( _HMG_HPDFDATA[ 1 ][ 11 ], { oOutline, cName } )
   ENDIF
   // Bind page destination to outline handle
   HPDF_Outline_SetDestination( oOutline, oDestination )

RETURN NIL

/*
 * _HMG_HPDF_SetTextAnnot
 * Creates a pop-up text annotation icon at the specified page position.
 *
 * Parameters:
 *   nRow     - Numeric   - Y position in mm.
 *   nCol     - Numeric   - X position in mm.
 *   cToolTip - Character - Tooltip note text content.
 *   cIcon    - Character - Annotation icon symbol name ('COMMENT', 'KEY', 'NOTE', 'HELP', etc.).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Appends interactive text annotation object to active page.
 */
FUNCTION _HMG_HPDF_SetTextAnnot( nRow, nCol, cToolTip, cIcon )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nToRow := nRow + 5
   LOCAL nToCol := nCol + 5
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL nToxPos := nxPos + _HMG_HPDF_MM2Pixel( nToCol - nCol )
   LOCAL nToyPos := nyPos - _HMG_HPDF_MM2Pixel( nToRow - nRow )
   LOCAL aRect := { nxPos, nyPos, nToxPos, nToyPos }
   LOCAL oAnnot := NIL

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF
   // Instantiate text annotation within bounding box
   oAnnot := HPDF_Page_CreateTextAnnot ( _HMG_HPDFDATA[ 1 ][ 7 ], aRect, cTooltip, HPDF_GetCurrentEncoder() )
   IF Empty( oAnnot )
      _HMG_HPDF_Error( 15 )
      RETURN NIL
   ENDIF
   // Apply annotation icon type
   DO CASE
   CASE Upper( AllTrim( cIcon ) ) == "COMMENT"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_COMMENT )
   CASE Upper( AllTrim( cIcon ) ) == "KEY"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_KEY )
   CASE Upper( AllTrim( cIcon ) ) == "NOTE"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_NOTE )
   CASE Upper( AllTrim( cIcon ) ) == "HELP"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_HELP )
   CASE Upper( AllTrim( cIcon ) ) == "NEW_PARAGRAPH"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_NEW_PARAGRAPH )
   CASE Upper( AllTrim( cIcon ) ) == "PARAGRAPH"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_PARAGRAPH )
   CASE Upper( AllTrim( cIcon ) ) == "INSERT"
      HPDF_TextAnnot_SetIcon ( oAnnot, HPDF_ANNOT_ICON_INSERT )
   ENDCASE

RETURN NIL

/*
 * _HMG_HPDF_SetPageLink
 * Prints a text label with an interactive hyperlink jumping to another document page.
 *
 * Parameters:
 *   nRow         - Numeric   - Y position in mm.
 *   nCol         - Numeric   - X position in mm.
 *   cText        - Character - Label text.
 *   nPage        - Numeric   - Target page index (1-based).
 *   cFontName    - Character - Font family name.
 *   nFontSize    - Numeric   - Font size in points.
 *   nRColor      - Numeric   - Red component (0-255).
 *   nGColor      - Numeric   - Green component (0-255).
 *   nBColor      - Numeric   - Blue component (0-255).
 *   cAlign       - Character - Text alignment.
 *   lColor       - Logical   - Color specified flag.
 *   lFont        - Logical   - Font specified flag.
 *   lSize        - Logical   - Size specified flag.
 *   lBorder      - Logical   - Show link border box flag.
 *   lWidth       - Logical   - Border width specified flag.
 *   nBorderWidth - Numeric   - Thickness of border box in mm.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders text and creates link annotation pointing to target page context.
 */
FUNCTION _HMG_HPDF_SetPageLink( nRow, nCol, cText, nPage, cFontName, nFontSize, nRColor, nGColor, nBColor, cAlign, lColor, lFont, lSize, lBorder, lWidth, nBorderWidth )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nTextWidth
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL oFont := NIL
   LOCAL cFont
   LOCAL aRect
   LOCAL oAnnot := NIL
   LOCAL oDest := NIL
   LOCAL aPages
   LOCAL oLinkPage := NIL

   // Apply default parameters
   DEFAULT cFontName := ''
   DEFAULT nFontSize := 12
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''
   DEFAULT lBorder := .F.
   DEFAULT lWidth := .F.
   DEFAULT nBorderWidth := 0

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Validate target page index boundary
   aPages := AClone( _HMG_HPDFDATA[ 1 ][ 12 ] )
   IF nPage > Len( aPages ) .OR. nPage < 1
      _HMG_HPDF_Error( 17 )
      RETURN NIL
   ENDIF

   oLinkPage := aPages[ nPage ]
   IF Empty( oLinkPage )
      _HMG_HPDF_Error( 17 )
      RETURN NIL
   ENDIF
   // Create destination object on target link page
   oDest := HPDF_Page_CreateDestination( oLinkPage )
   IF Empty( oDest )
      _HMG_HPDF_Error( 17 )
      RETURN NIL
   ENDIF

   // Configure text fill color
   IF lColor
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName ) )

   // Load or fetch font
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'

      cFont := HPDF_LoadTTFontFromFile( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF
   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ELSE
      HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
      nTextWidth := HPDF_Page_TextWidth( _HMG_HPDFDATA[ 1 ][ 7 ], cText )
      DO CASE
      CASE Upper( AllTrim( cAlign ) ) == 'CENTER'
         nxPos := nxPos - ( nTextWidth / 2 )
      CASE Upper( AllTrim( cAlign ) ) == 'RIGHT'
         nxPos := nxPos - ( nTextWidth )
      ENDCASE
      // Output link text label
      HPDF_Page_BeginText( _HMG_HPDFDATA[ 1 ][ 7 ] )
      HPDF_PAGE_TEXTOUT( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, cText )
      // Define bounding rectangle and attach page link annotation
      aRect := { nxPos - 4, nyPos + nFontsize + 4, nxPos + nTextWidth + 4, nyPos - 4 }
      oAnnot := HPDF_Page_CreateLinkAnnot( _HMG_HPDFDATA[ 1 ][ 7 ], aRect, oDest )
      IF lBorder
         IF nBorderWidth == 0
            nBorderWidth := 1
         ELSE
            nBorderWidth := _HMG_HPDF_MM2Pixel( nBorderWidth )
         ENDIF
         HPDF_LinkAnnot_SetBorderStyle ( oAnnot, nBorderWidth, 0, 0 )
      ELSE
         HPDF_LinkAnnot_SetBorderStyle ( oAnnot, 0, 0, 0 )
      ENDIF
      HPDF_Page_EndText( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_SetURLLink
 * Prints text formatted with an active web URL hyperlink annotation.
 *
 * Parameters:
 *   nRow      - Numeric   - Y position in mm.
 *   nCol      - Numeric   - X position in mm.
 *   cText     - Character - Text label.
 *   cLink     - Character - Target URL destination string (e.g., "http://...").
 *   cFontName - Character - Font family name.
 *   nFontSize - Numeric   - Font size in points.
 *   nRColor   - Numeric   - Red component (0-255).
 *   nGColor   - Numeric   - Green component (0-255).
 *   nBColor   - Numeric   - Blue component (0-255).
 *   cAlign    - Character - Alignment option.
 *   lColor    - Logical   - Color flag.
 *   lFont     - Logical   - Font flag.
 *   lSize     - Logical   - Size flag.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Renders text and attaches URI link action annotation to active page.
 */
FUNCTION _HMG_HPDF_SetURLLink( nRow, nCol, cText, cLink, cFontName, nFontSize, nRColor, nGColor, nBColor, cAlign, lColor, lFont, lSize )

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nTextWidth
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL oFont := NIL
   LOCAL cFont
   LOCAL aRect
   LOCAL oAnnot := NIL
   LOCAL hUrlLink := NIL

   DEFAULT cFontName := ''
   DEFAULT nFontSize := 12
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Set normalized fill RGB
   IF lColor
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( _HMG_HPDFDATA[ 1 ][ 7 ], 0.0, 0.0, 0.0 )
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName ) )

   // Load font handle
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'

      cFont := HPDF_LoadTTFontFromFile( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF
   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ELSE
      HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
      nTextWidth := HPDF_Page_TextWidth( _HMG_HPDFDATA[ 1 ][ 7 ], cText )
      DO CASE
      CASE Upper( AllTrim( cAlign ) ) == 'CENTER'
         nxPos := nxPos - ( nTextWidth / 2 )
      CASE Upper( AllTrim( cAlign ) ) == 'RIGHT'
         nxPos := nxPos - ( nTextWidth )
      ENDCASE
      // Output label text
      HPDF_Page_BeginText( _HMG_HPDFDATA[ 1 ][ 7 ] )
      HPDF_PAGE_TEXTOUT( _HMG_HPDFDATA[ 1 ][ 7 ], nxPos, nyPos, cText )
      // Define annotation bounding rectangle and assign URI link target
      aRect := { nxPos - 4, nyPos + nFontsize + 4, nxPos + nTextWidth + 4, nyPos - 4 }
      hUrlLink := HPDF_Page_CreateURILinkAnnot( _HMG_HPDFDATA[ 1 ][ 7 ], aRect, cLink )
      IF hUrlLink != NIL
         HPDF_Annotation_SetBorderStyle( hUrlLink, HPDF_BS_UNDERLINED )
      ENDIF
      HPDF_Page_EndText( _HMG_HPDFDATA[ 1 ][ 7 ] )
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_SetLineSpacing
 * Adjusts line leading height for subsequent multiline text rendering on the active page.
 *
 * Parameters:
 *   nSpacing - Numeric - Inter-line spacing distance in millimeters.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies text leading state on active HaruPDF page object.
 */
FUNCTION _HMG_HPDF_SetLineSpacing( nSpacing )

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF
   HPDF_Page_SetTextLeading( _HMG_HPDFDATA[ 1 ][ 7 ], _HMG_HPDF_MM2Pixel( nSpacing ) )

RETURN NIL

/*
 * _HMG_HPDF_SetInfo
 * Updates document metadata entries (e.g., Title, Author, Creation Date).
 *
 * Parameters:
 *   cAttrib - Character - Property name ("AUTHOR", "CREATOR", "TITLE", "SUBJECT", "KEYWORDS", "DATECREATED", "DATEMODIFIED").
 *   xValue  - Mixed     - String or Date value to set.
 *   cTime   - Character - Time string ("HH:MM:SS") used when setting date metadata attributes.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies PDF file information dictionary parameters.
 */
FUNCTION _HMG_HPDF_SetInfo( cAttrib, xValue, cTime )

   LOCAL cValue := ''
   LOCAL dValue := ''
   LOCAL nHours := 0
   LOCAL nMinutes := 0
   LOCAL nSeconds := 0

   DEFAULT cTime := ''
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Distinguish between Date and String input types
   DO CASE
   CASE ValType( xValue ) == 'D'
      dValue := xValue
   OTHERWISE
      cValue := xValue
   ENDCASE
   // Set matching metadata attribute
   DO CASE
   CASE Upper( AllTrim( cAttrib ) ) == "AUTHOR"
      HPDF_SetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_AUTHOR, cValue )
   CASE Upper( AllTrim( cAttrib ) ) == "CREATOR"
      HPDF_SetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_CREATOR, cValue )
   CASE Upper( AllTrim( cAttrib ) ) == "TITLE"
      HPDF_SetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_TITLE, cValue )
   CASE Upper( AllTrim( cAttrib ) ) == "SUBJECT"
      HPDF_SetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_SUBJECT, cValue )
   CASE Upper( AllTrim( cAttrib ) ) == "KEYWORDS"
      HPDF_SetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_KEYWORDS, cValue )
   CASE Upper( AllTrim( cAttrib ) ) == "DATECREATED"
      IF Len( AllTrim( cTime ) ) > 0
         nHours := Val( SubStr( cTime, 1, 2 ) )
         nMinutes := Val( SubStr( cTime, 4, 2 ) )
         nSeconds := Val( SubStr( cTime, 7, 2 ) )
      ENDIF
      HPDF_SetInfoDateAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_CREATION_DATE, { Year( dValue ), Month( dVAlue ), Day( dValue ), nHours, nMinutes, nSeconds } )
   CASE Upper( AllTrim( cAttrib ) ) == "DATEMODIFIED"
      IF Len( AllTrim( cTime ) ) > 0
         nHours := Val( SubStr( cTime, 1, 2 ) )
         nMinutes := Val( SubStr( cTime, 4, 2 ) )
         nSeconds := Val( SubStr( cTime, 7, 2 ) )
      ENDIF
      HPDF_SetInfoDateAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_MOD_DATE, { Year( dValue ), Month( dVAlue ), Day( dValue ), nHours, nMinutes, nSeconds } )
   ENDCASE

RETURN NIL

/*
 * _HMG_HPDF_GetInfo
 * Retrieves metadata attribute values from the active document structure.
 *
 * Parameters:
 *   cAttrib - Character - Metadata attribute name ("AUTHOR", "TITLE", "DATECREATED", etc.).
 *
 * Return:
 *   Character - Value of requested metadata attribute, or empty string on failure.
 *
 * Side Effects:
 *   Temporarily alters global date format environment setting while parsing dates.
 */
FUNCTION _HMG_HPDF_GetInfo( cAttrib )

   LOCAL cRetValue := '', bd, bc

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   DO CASE
   CASE Upper( AllTrim( cAttrib ) ) == "AUTHOR"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_AUTHOR )
   CASE Upper( AllTrim( cAttrib ) ) == "CREATOR"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_CREATOR )
   CASE Upper( AllTrim( cAttrib ) ) == "TITLE"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_TITLE )
   CASE Upper( AllTrim( cAttrib ) ) == "SUBJECT"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_SUBJECT )
   CASE Upper( AllTrim( cAttrib ) ) == "KEYWORDS"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_KEYWORDS )
   CASE Upper( AllTrim( cAttrib ) ) == "DATECREATED"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_CREATION_DATE )
   CASE Upper( AllTrim( cAttrib ) ) == "DATEMODIFIED"
      cRetValue := HPDF_GetInfoAttr( _HMG_HPDFDATA[ 1 ][ 1 ], HPDF_INFO_MOD_DATE )
   ENDCASE
   // Reformat PDF date prefix string "D:YYYYMMDD..." to localized string
   IF Left( cRetValue, 2 ) == "D:"
      bd := Set( _SET_DATEFORMAT )
      bc := __SetCentury( .T. )
      SET DATE GERMAN
      cRetValue := DToC( SToD( SubStr( cRetValue, 3, 8 ) ) ) + " " + SubStr( cRetValue, 11, 2 ) + ":" + SubStr( cRetValue, 13, 2 ) + ":" + SubStr( cRetValue, 15, 2 )
      __SetCentury( bc )
      Set( _SET_DATEFORMAT, bd )
   ENDIF

RETURN cRetValue

/*
 * _HMG_HPDF_SetPageLabel
 * Sets page numbering numbering style and prefix for page tree ranges.
 *
 * Parameters:
 *   nPage   - Numeric   - Page sequence start index.
 *   cStyle  - Character - Numbering style ("DECIMAL", "ROMAN", "LETTERS").
 *   cCase   - Character - Text casing ("LOWER" or "UPPER").
 *   cPrefix - Character - Optional prefix label string.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Configures page label entries in document catalog.
 */
FUNCTION _HMG_HPDF_SetPageLabel( nPage, cStyle, cCase, cPrefix )

   // Set default parameter values
   DEFAULT cCase := ""
   DEFAULT cStyle := "DECIMAL"
   DEFAULT nPage := 1
   DEFAULT cPrefix := ""
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   // Register page label format rule
   DO CASE
   CASE Upper( AllTrim( cStyle ) ) == "DECIMAL"
      HPDF_AddPageLabel( _HMG_HPDFDATA[ 1 ][ 1 ], nPage, HPDF_PAGE_NUM_STYLE_DECIMAL, nPage, cPrefix )
   CASE Upper( AllTrim( cStyle ) ) == "ROMAN"
      IF Upper( AllTrim( cCase ) ) == "LOWER"
         HPDF_AddPageLabel( _HMG_HPDFDATA[ 1 ][ 1 ], nPage, HPDF_PAGE_NUM_STYLE_LOWER_ROMAN, nPage, cPrefix )
      ELSE
         HPDF_AddPageLabel( _HMG_HPDFDATA[ 1 ][ 1 ], nPage, HPDF_PAGE_NUM_STYLE_UPPER_ROMAN, nPage, cPrefix )
      ENDIF
   CASE Upper( AllTrim( cStyle ) ) == "LETTERS"
      IF Upper( AllTrim( cCase ) ) == "LOWER"
         HPDF_AddPageLabel( _HMG_HPDFDATA[ 1 ][ 1 ], nPage, HPDF_PAGE_NUM_STYLE_LOWER_LETTERS, nPage, cPrefix )
      ELSE
         HPDF_AddPageLabel( _HMG_HPDFDATA[ 1 ][ 1 ], nPage, HPDF_PAGE_NUM_STYLE_UPPER_LETTERS, nPage, cPrefix )
      ENDIF
   ENDCASE

RETURN NIL

/*
 * _HMG_HPDF_Error
 * Displays a modal error message dialog corresponding to an internal library error code.
 *
 * Parameters:
 *   nErr       - Numeric   - Integer error code.
 *   cExtraInfo - Character - Additional diagnostic contextual detail.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Displays a Stop message box on screen.
 */
FUNCTION _HMG_HPDF_Error( nErr, cExtraInfo )

   LOCAL cErr := ''

   DEFAULT cExtraInfo TO ''
   // Map integer error code to human-readable error text string
   DO CASE
   CASE nErr == 1
      cErr := 'A PDF document is already initiated.'
   CASE nErr == 2
      cErr := 'PDF document cannot be initialized.'
   CASE nErr == 3
      cErr := 'PDF PAGE cannot be added. PDF document cannot be found.'
   CASE nErr == 4
      cErr := 'A PDF PAGE is already initiated.'
   CASE nErr == 5
      cErr := 'PDF PAGE cannot be found.'
   CASE nErr == 6
      cErr := 'Font cannot be loaded.'
   CASE nErr == 7
      cErr := 'Image cannot be loaded.'
   CASE nErr == 8
      cErr := 'Round curve can not be longer than half of the width/height.'
   CASE nErr == 9
      cErr := 'Can not start new page.'
   CASE nErr == 10
      cErr := 'Can not create new parent outline.'
   CASE nErr == 11
      cErr := 'Outline Title is not valid.'
   CASE nErr == 12
      cErr := 'Outline Name is not valid.'
   CASE nErr == 13
      cErr := 'Can not create Page Outline.'
   CASE nErr == 14
      cErr := 'Can not find Parent Node.'
   CASE nErr == 15
      cErr := 'Tooltip creation error!'
   CASE nErr == 16
      cErr := 'Page not found. New page can not be inserted.'
   CASE nErr == 17
      cErr := 'Link Page not found.'
   CASE nErr == 18
      cErr := 'Selected Page can not be found.'
   CASE nErr == 19
      cErr := 'Page Selection error!'
   CASE nErr == 20
      cErr := 'Pdf creation error!'
   ENDCASE
   cErr += CRLF + cExtraInfo
   msgstop( cErr )

RETURN NIL

/*
 * _HMG_HPDF_Inch2Pixel
 * Converts linear inches to PDF point units (72 points/inch).
 *
 * Parameters:
 *   nInches - Numeric - Measurement in inches.
 *
 * Return:
 *   Numeric - Measurement in points/pixels.
 *
 * Side Effects:
 *   None
 */
FUNCTION _HMG_HPDF_Inch2Pixel( nInches )
RETURN ( nInches * 72 )

/*
 * _HMG_HPDF_Pixel2Inch
 * Converts PDF points to linear inches.
 *
 * Parameters:
 *   nPixels - Numeric - Measurement in points/pixels.
 *
 * Return:
 *   Numeric - Measurement in inches.
 *
 * Side Effects:
 *   None
 */
FUNCTION _HMG_HPDF_Pixel2Inch( nPixels )
RETURN ( nPixels / 72 )

/*
 * _HMG_HPDF_MM2Pixel
 * Converts millimeters to PDF point units.
 *
 * Parameters:
 *   nMM - Numeric - Measurement in millimeters.
 *
 * Return:
 *   Numeric - Measurement in points/pixels.
 *
 * Side Effects:
 *   None
 */
FUNCTION _HMG_HPDF_MM2Pixel( nMM )
RETURN ( ( nMM / 25.4 ) * 72 )

/*
 * _HMG_HPDF_Pixel2MM
 * Converts PDF point units to millimeters.
 *
 * Parameters:
 *   nPixel - Numeric - Measurement in points/pixels.
 *
 * Return:
 *   Numeric - Measurement in millimeters.
 *
 * Side Effects:
 *   None
 */
FUNCTION _HMG_HPDF_Pixel2MM( nPixel )
RETURN ( ( nPixel / 72 ) * 25.4 )

/*
 * _HMG_HPDF_INIT_PAPERSIZE
 * Sets global page width and height state variables based on a standard paper size ID.
 *
 * Parameters:
 *   nPaperSize - Numeric - Standard paper size selector constant.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates dimensions stored in global state variables _HMG_HPDFDATA[1][4] and [5].
 */
FUNCTION _HMG_HPDF_INIT_PAPERSIZE( nPaperSize )

   LOCAL nTemp

   DO CASE
   CASE nPaperSize == 1 .OR. nPaperSize == -999 // Letter standard format
      _HMG_HPDFDATA[ 1 ][ 4 ] := 612
      _HMG_HPDFDATA[ 1 ][ 5 ] := 792
   CASE nPaperSize == 2 // Letter Small
      _HMG_HPDFDATA[ 1 ][ 4 ] := 612
      _HMG_HPDFDATA[ 1 ][ 5 ] := 792
   CASE nPaperSize == 3 // Tabloid
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 11 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 17 )
   CASE nPaperSize == 4 // Ledger
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 17 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 5 // Legal
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 14 )
   CASE nPaperSize == 6 // Statement
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 5.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
   CASE nPaperSize == 7 // Executive
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 5.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
   CASE nPaperSize == 8 // ISO A3
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 297 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 420 )
   CASE nPaperSize == 9 // ISO A4
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 297 )
   CASE nPaperSize == 10 // ISO A4 Small
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 297 )
   CASE nPaperSize == 11 // ISO A5
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 148 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 210 )
   CASE nPaperSize == 12 // JIS B4
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 250 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 354 )
   CASE nPaperSize == 13 // JIS B5
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 185 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 257 )
   CASE nPaperSize == 14 // Folio
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 13 )
   CASE nPaperSize == 15 // Quarto
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 215 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 275 )
   CASE nPaperSize == 16 // 10x14 Sheet
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 10 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 140 )
   CASE nPaperSize == 17 // 11x17 Sheet
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 11 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 17 )
   CASE nPaperSize == 18 // Note
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 19 // Envelope #9
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 3 + ( 7 / 8 ) )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 8 + ( 7 / 8 ) )
   CASE nPaperSize == 20 // Envelope #10
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 4 + ( 1 / 8 ) )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 9.5 )
   CASE nPaperSize == 21 // Envelope #11
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 4.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 10 + ( 3 / 8 ) )
   CASE nPaperSize == 22 // Envelope #12
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 4.75 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 23 // Envelope #14
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11.5 )
   CASE nPaperSize == 24 // C Sheet
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 17 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 22 )
   CASE nPaperSize == 25 // D Sheet
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 22 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 34 )
   CASE nPaperSize == 26 // E Sheet
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 34 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 44 )
   CASE nPaperSize == 27 // DL Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 110 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 220 )
   CASE nPaperSize == 28 // C5 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 162 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 229 )
   CASE nPaperSize == 29 // C3 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 324 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 458 )
   CASE nPaperSize == 30 // C4 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 229 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 324 )
   CASE nPaperSize == 31 // C6 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 114 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 162 )
   CASE nPaperSize == 32 // C65 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 114 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 229 )
   CASE nPaperSize == 33 // B4 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 250 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 353 )
   CASE nPaperSize == 34 // B5 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 176 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 250 )
   CASE nPaperSize == 35 // B6 Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 176 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 125 )
   CASE nPaperSize == 36 // Italy Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 110 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 230 )
   CASE nPaperSize == 37 // Monarch Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 3.875 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 7.5 )
   CASE nPaperSize == 38 // Personal Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 3 + ( 5 / 8 ) )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 6.5 )
   CASE nPaperSize == 39 // US Fanfold
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 14 + ( 7 / 8 ) )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 40 // German Standard Fanfold
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 12 )
   CASE nPaperSize == 41 // German Legal Fanfold
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 13 )
   CASE nPaperSize == 42 // ISO B4
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 250 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 353 )
   CASE nPaperSize == 43 // Japanese Postcard
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 100 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 148 )
   CASE nPaperSize == 44 // 9x11 Continuous
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 9 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 45 // 10x11 Continuous
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 10 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 46 // 15x11 Continuous
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 15 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 47 // Invite Envelope
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 220 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 220 )
   CASE nPaperSize == 48 // Reserved Format 48
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 297 )
   CASE nPaperSize == 49 // Reserved Format 49
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 297 )
   CASE nPaperSize == 50 // Letter Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 9.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 12 )
   CASE nPaperSize == 51 // Legal Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 9.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 15 )
   CASE nPaperSize == 52 // Tabloid Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 11.69 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 18 )
   CASE nPaperSize == 53 // A4 Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 9.27 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 12.69 )
   CASE nPaperSize == 54 // Letter Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 55 // A4 Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 297 )
   CASE nPaperSize == 56 // Letter Extra Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 9.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 12 )
   CASE nPaperSize == 57 // Super A / A Plus
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 227 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 356 )
   CASE nPaperSize == 58 // Super B / B Plus
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 305 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 487 )
   CASE nPaperSize == 59 // Letter Plus
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 12.69 )
   CASE nPaperSize == 60 // A4 Plus
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 330 )
   CASE nPaperSize == 61 // A5 Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 148 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 210 )
   CASE nPaperSize == 62 // JIS B5 Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 182 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 257 )
   CASE nPaperSize == 63 // A3 Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 322 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 445 )
   CASE nPaperSize == 64 // A5 Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 174 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 235 )
   CASE nPaperSize == 65 // JIS B5 Extra
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 201 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 276 )
   CASE nPaperSize == 66 // ISO A2
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 420 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 594 )
   CASE nPaperSize == 67 // A3 Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 297 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 420 )
   CASE nPaperSize == 68 // A3 Extra Transverse
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 322 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 445 )
   CASE nPaperSize == 69 // Double Japanese Postcard
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 200 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 148 )
   CASE nPaperSize == 70 // ISO A6
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 105 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 148 )
   CASE nPaperSize == 71 // Japanese Envelope Kaku #2
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 240 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 332 )
   CASE nPaperSize == 72 // Japanese Envelope Kaku #3
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 216 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 277 )
   CASE nPaperSize == 73 // Japanese Envelope Chou #3
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 120 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 235 )
   CASE nPaperSize == 74 // Japanese Envelope Chou #4
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 90 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 205 )
   CASE nPaperSize == 75 // Letter Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 11 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 8.5 )
   CASE nPaperSize == 76 // A3 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 420 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 297 )
   CASE nPaperSize == 77 // A4 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 297 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 210 )
   CASE nPaperSize == 78 // A5 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 210 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 148 )
   CASE nPaperSize == 79 // JIS B4 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 364 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 257 )
   CASE nPaperSize == 80 // JIS B5 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 257 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 182 )
   CASE nPaperSize == 81 // Japanese Postcard Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 148 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 100 )
   CASE nPaperSize == 82 // Double Japanese Postcard Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 148 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 200 )
   CASE nPaperSize == 83 // A6 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 148 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 105 )
   CASE nPaperSize == 84 // Japanese Envelope Kaku #2 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 332 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 240 )
   CASE nPaperSize == 85 // Japanese Envelope Kaku #3 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 277 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 216 )
   CASE nPaperSize == 86 // Japanese Envelope Chou #3 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 235 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 120 )
   CASE nPaperSize == 87 // Japanese Envelope Chou #4 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 205 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 90 )
   CASE nPaperSize == 88 // JIS B6
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 128 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 182 )
   CASE nPaperSize == 89 // JIS B6 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 182 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 128 )
   CASE nPaperSize == 90 // 12x11 Continuous
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_Inch2Pixel( 12 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_Inch2Pixel( 11 )
   CASE nPaperSize == 91 // Japanese Envelope You #4
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 235 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 105 )
   CASE nPaperSize == 92 // Japanese Envelope You #4 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 105 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 235 )
   CASE nPaperSize == 93 // PRC 16K
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 146 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 215 )
   CASE nPaperSize == 94 // PRC 32K
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 97 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 151 )
   CASE nPaperSize == 95 // PRC 32K Big
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 97 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 151 )
   CASE nPaperSize == 96 // PRC Envelope #1
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 102 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 165 )
   CASE nPaperSize == 97 // PRC Envelope #2
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 102 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 176 )
   CASE nPaperSize == 98 // PRC Envelope #3
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 125 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 176 )
   CASE nPaperSize == 99 // PRC Envelope #4
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 110 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 208 )
   CASE nPaperSize == 100 // PRC Envelope #5
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 110 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 220 )
   CASE nPaperSize == 101 // PRC Envelope #6
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 120 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 230 )
   CASE nPaperSize == 102 // PRC Envelope #7
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 160 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 230 )
   CASE nPaperSize == 103 // PRC Envelope #8
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 120 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 208 )
   CASE nPaperSize == 104 // PRC Envelope #9
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 229 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 324 )
   CASE nPaperSize == 105 // PRC Envelope #10
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 324 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 458 )
   CASE nPaperSize == 106 // PRC 16K Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 215 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 146 )
   CASE nPaperSize == 107 // PRC 32K Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 151 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 97 )
   CASE nPaperSize == 108 // PRC 32K Big Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 151 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 97 )
   CASE nPaperSize == 109 // PRC Envelope #1 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 165 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 102 )
   CASE nPaperSize == 110 // PRC Envelope #2 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 176 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 102 )
   CASE nPaperSize == 111 // PRC Envelope #3 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 176 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 125 )
   CASE nPaperSize == 112 // PRC Envelope #4 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 208 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 110 )
   CASE nPaperSize == 113 // PRC Envelope #5 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 220 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 110 )
   CASE nPaperSize == 114 // PRC Envelope #6 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 230 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 120 )
   CASE nPaperSize == 115 // PRC Envelope #7 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 230 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 160 )
   CASE nPaperSize == 116 // PRC Envelope #8 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 309 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 120 )
   CASE nPaperSize == 117 // PRC Envelope #9 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 324 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 229 )
   CASE nPaperSize == 118 // PRC Envelope #10 Rotated
      _HMG_HPDFDATA[ 1 ][ 4 ] := _HMG_HPDF_MM2Pixel( 458 )
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDF_MM2Pixel( 324 )
   ENDCASE
   // Swap width and height if orientation mode is set to Landscape
   IF _HMG_HPDFDATA[ 1 ][ 6 ] == 2
      nTemp := _HMG_HPDFDATA[ 1 ][ 5 ]
      _HMG_HPDFDATA[ 1 ][ 5 ] := _HMG_HPDFDATA[ 1 ][ 4 ]
      _HMG_HPDFDATA[ 1 ][ 4 ] := nTemp
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_SetFont
 * Resolves a requested font name to a valid HaruPDF base font, TTF path, or fallback font.
 *
 * Parameters:
 *   cFntName - Character - Target font name or TTF path.
 *   lBold    - Logical   - Bold style request flag.
 *   lItalic  - Logical   - Italic style request flag.
 *
 * Return:
 *   Character - Valid font identifier or file path usable by HaruPDF.
 *
 * Side Effects:
 *   Searches system fonts folder and local directory.
 */
FUNCTION _HMG_HPDF_SetFont( cFntName, lBold, lItalic )

   LOCAL cFntTmp, cFnt, cFntNoExt

   DEFAULT lBold := .F., lItalic := .F.

   // Use default session font if no font name specified
   IF Len( AllTrim( cFntName ) ) == 0
      cFntName := _HMG_HPDFDATA[ 1 ][ 8 ]
   ENDIF

   // Search local folders for explicit TTF request
   IF Upper ( cFileExt ( cFntName ) ) == '.TTF'
      cFnt := _HMG_HPDF_ExistInLocal( cFntName )
      IF ! Empty( cFnt )
         RETURN cFnt
      ENDIF
   ENDIF

   // Check built-in standard HaruPDF Base-14 fonts
   cFntTmp := cFileNoExt( cFntName )
   cFntNoExt := cFntTmp
   cFnt := _HMG_HPDF_SeekHaruFonts( cFntTmp, lBold, lItalic )
   IF ! Empty( cFnt )
      RETURN cFnt
   ENDIF

   // Check standard Windows TTF equivalences
   cFnt := _HMG_HPDF_SeekEquivalences( cFntNoExt, lBold, lItalic )
   IF ! Empty( cFnt )
      RETURN cFnt
   ENDIF

   // Search system fonts directory matching prefix pattern
   cFnt := _HMG_HPDF_SeekInLocalOptions( cFntNoExt, lBold, lItalic )
   IF ! Empty( cFnt )
      cFntTmp := _HMG_HPDF_ExistInLocal( cFnt )
      IF ! Empty( cFntTmp )
         RETURN cFntTmp
      ENDIF
   ENDIF

RETURN "Helvetica"

/*
 * _HMG_HPDF_SeekHaruFonts
 * Maps a font name and style request to standard HaruPDF Base-14 font identifiers.
 *
 * Parameters:
 *   cFontName - Character - Target font family name.
 *   lBold     - Logical   - Bold flag.
 *   lItalic   - Logical   - Italic flag.
 *
 * Return:
 *   Character - HaruPDF Base-14 font identifier, or empty string if not matched.
 *
 * Side Effects:
 *   None
 */
FUNCTION _HMG_HPDF_SeekHaruFonts( cFontName, lBold, lItalic )

   // Standard HaruPDF Base-14 font name collection
   LOCAL aHpdf_Font := { "Courier", ;
      "Courier-Bold", ;
      "Courier-Oblique", ;
      "Courier-BoldOblique", ;
      "Helvetica", ;
      "Helvetica-Bold", ;
      "Helvetica-Oblique", ;
      "Helvetica-BoldOblique", ;
      "Times-Roman", ;
      "Times-Bold", ;
      "Times-Italic", ;
      "Times-BoldItalic", ;
      "Symbol", ;
      "ZapfDingbats" }
   LOCAL nPos, cFntHaru

   IF ( nPos := AScan( aHpdf_Font, {| cFnt | Upper( cFnt ) == Upper( cFontName ) } ) ) > 0
      cFntHaru := aHpdf_Font[ nPos ]

      // Append style modifier tags according to font family rules
      DO CASE
      CASE "SYMBOL" $ Upper( cFntHaru )
         cFntHaru := "Symbol"
      CASE "ZAPFDINGBATS" $ Upper( cFntHaru )
         cFntHaru := "ZapfDingbats"
      CASE Upper( hb_USubStr( cFntHaru, 1, 5 ) ) == 'TIMES'
         cFntHaru := "Times"
         IF lBold .AND. lItalic
            cFntHaru := cFntHaru + '-BoldItalic'
         ELSEIF lBold
            cFntHaru := cFntHaru + '-Bold'
         ELSEIF lItalic
            cFntHaru := cFntHaru + '-Italic'
         ELSE
            cFntHaru := cFntHaru + '-Roman'
         ENDIF
      OTHERWISE
         IF ( nPos := hb_UAt( '-', cFntHaru ) ) > 0
            cFntHaru := hb_USubStr( cFntHaru, 1, nPos - 1 )
         ENDIF
         IF lBold .AND. lItalic
            cFntHaru := cFntHaru + '-BoldOblique'
         ELSEIF lBold
            cFntHaru := cFntHaru + '-Bold'
         ELSEIF lItalic
            cFntHaru := cFntHaru + '-Oblique'
         ENDIF
      ENDCASE
      RETURN cFntHaru
   ENDIF

RETURN ""

/*
 * _HMG_HPDF_SeekEquivalences
 * Maps common Windows font family names (e.g. Arial, Times) to TrueType font files.
 *
 * Parameters:
 *   FontName - Character - Font family name.
 *   lBold    - Logical   - Bold flag.
 *   lItalic  - Logical   - Italic flag.
 *
 * Return:
 *   Character - Full file path to TTF font file, or empty string if not found.
 *
 * Side Effects:
 *   Performs file system lookups in system Fonts directory.
 */
FUNCTION _HMG_HPDF_SeekEquivalences( FontName, lBold, lItalic )

   LOCAL cFldWindows := GetSpecialFolder( CSIDL_FONTS )
   LOCAL cRet := ""

   DEFAULT lBold := .F., lItalic := .F.

   // Match standard font aliases to base TTF filenames
   DO CASE
   CASE "COUR" $ Upper( FontName )
      cRet := "cour"
   CASE "TIMES" $ Upper( FontName )
      cRet := "times"
   CASE "ARIAL NARROW" $ Upper( FontName )
      cRet := "arialn"
   CASE "ARIAL" $ Upper( FontName )
      cRet := "arial"
   CASE "VERDANA" $ Upper( FontName )
      cRet := "verdana"
   ENDCASE

   IF ! Empty( cRet )
      // Append style suffix letters
      IF lBold .AND. lItalic
         cRet := cRet + 'bi.ttf'
      ELSEIF lBold
         IF cRet = "arialn"
            cRet := cRet + 'b.ttf'
         ELSE
            cRet := cRet + 'bd.ttf'
         ENDIF
      ELSEIF lItalic
         cRet := cRet + 'i.ttf'
      ELSE
         cRet := cRet + '.ttf'
      ENDIF
      cRet := cFldWindows + "\" + cRet
      cRet := _HMG_HPDF_ExistInLocal( cRet )
   ENDIF

RETURN cRet

/*
 * _HMG_HPDF_ExistInLocal
 * Checks whether a font TTF file exists in the current directory or Windows Fonts folder.
 *
 * Parameters:
 *   FontName - Character - Font file path or filename.
 *
 * Return:
 *   Character - Validated absolute file path to font, or empty string if not found.
 *
 * Side Effects:
 *   Performs disk file existence checks.
 */
FUNCTION _HMG_HPDF_ExistInLocal( FontName )

   LOCAL cFldWindows := GetSpecialFolder( CSIDL_FONTS )
   LOCAL cFileTTF := cFileNoExt( FontName ) + ".ttf"
   LOCAL cFldLocal := GetCurrentFolder()
   LOCAL cFntTmp := ""

   // Return path immediately if file exists as passed
   IF File( FontName )
      RETURN FontName
   ENDIF
   // Check system Windows Fonts directory
   IF File( cFldWindows + "\" + cFileTTF )
      cFntTmp := cFldWindows + "\" + cFileTTF
   ENDIF
   // Check application working directory
   IF File( cFldLocal + "\" + cFileTTF )
      cFntTmp := cFldLocal + "\" + cFileTTF
   ENDIF

RETURN cFntTmp

/*
 * _HMG_HPDF_SeekInLocalOptions
 * Searches system fonts folder for TTF files matching the first four letters of a font name.
 *
 * Parameters:
 *   FontName - Character - Font family search string.
 *   lBold    - Logical   - Bold flag.
 *   lItalic  - Logical   - Italic flag.
 *
 * Return:
 *   Character - Full TTF file path, or empty string if not found.
 *
 * Side Effects:
 *   Scans Windows Fonts directory listing.
 */
FUNCTION _HMG_HPDF_SeekInLocalOptions( FontName, lBold, lItalic )

   LOCAL aDirFnts, cRet := ""
   LOCAL cFldWindows, cFileTTF

   DEFAULT lBold := .F., lItalic := .F.

   cFldWindows := GetSpecialFolder( CSIDL_FONTS )
   cFileTTF := cFileNoExt( FontName )
   // Retrieve directory list matching prefix and sort by filename length
   aDirFnts := ASort( Directory( cFldWindows + "\" + hb_USubStr( cFileTTF, 1, 4 ) + "*.ttf" ),,, {| x, y | Len( x[ 1 ] ) < Len( y[ 1 ] ) } )
   IF Len( aDirFnts ) > 0
      cRet := cFldWindows + "\" + cFileNoExt( aDirFnts[ 1, 1 ] )
      IF lBold .AND. lItalic
         cRet := cRet + 'bi.ttf'
      ELSEIF lBold
         cRet := cRet + 'bd.ttf'
      ELSEIF lItalic
         cRet := cRet + 'i.ttf'
      ELSE
         cRet := cRet + '.ttf'
      ENDIF
   ENDIF

RETURN IF( File( cRet ), cRet, "" )

/*
 * _HMG_HPDF_SetDash
 * Applies a line dash pattern to the active page stroke context.
 *
 * Parameters:
 *   nMode - Numeric - Dash pattern style identifier (0 = solid line, 1 = dotted, 2 = dashed, 3 = dash-dot).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates dash pattern settings on active HaruPDF page object.
 */
FUNCTION _HMG_HPDF_SetDash( nMode )

   LOCAL aPtn, nNum := 0, nFase := 0

   DEFAULT nMode := 0
   DO CASE
   CASE nMode == 1
      aPtn := DASH_MODE1 // Dotted pattern: {3}
      nNum := 1
      nFase := 1
   CASE nMode == 2
      aPtn := DASH_MODE2 // Dashed pattern: {7,3}
      nNum := 2
      nFase := 2
   CASE nMode == 3
      aPtn := DASH_MODE3 // Dash-dot pattern: {8,7,2,7}
      nNum := 4
      nFase := 0
   ENDCASE
   HPDF_Page_SetDash ( _HMG_HPDFDATA[ 1 ][ 7 ], @aPtn, nNum, nFase )

RETURN NIL

/*
 * _HMG_HPDF_SetOrientation
 * Changes document page orientation mode and swaps width/height dimensions accordingly.
 *
 * Parameters:
 *   nMode - Numeric - Orientation mode (1 = Portrait, 2 = Landscape). Defaults to 1.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Modifies session orientation (index 6) and page size values (indexes 4 and 5).
 */
FUNCTION _HMG_HPDF_SetOrientation( nMode )

   LOCAL nPaperWidth, nPaperLength

   DEFAULT nMode := 1
   _HMG_HPDFDATA[ 1 ][ 6 ] := nMode
   nPaperWidth := _HMG_HPDFDATA[ 1 ][ 4 ]
   nPaperLength := _HMG_HPDFDATA[ 1 ][ 5 ]
   IF _HMG_HPDFDATA[ 1 ][ 6 ] == 1 // Portrait orientation mode
      IF nPaperWidth > nPaperLength
         _HMG_HPDFDATA[ 1 ][ 4 ] := nPaperLength
         _HMG_HPDFDATA[ 1 ][ 5 ] := nPaperWidth
      ENDIF
   ELSE // Landscape orientation mode
      IF nPaperWidth < nPaperLength
         _HMG_HPDFDATA[ 1 ][ 4 ] := nPaperLength
         _HMG_HPDFDATA[ 1 ][ 5 ] := nPaperWidth
      ENDIF
   ENDIF

RETURN NIL

/*
 * _HMG_HPDF_SetFontSize
 * Sets default font size in points for the current session.
 *
 * Parameters:
 *   nFontSize - Numeric - Font size in points. Defaults to 12.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates default font size stored in global session array slot _HMG_HPDFDATA[1][9].
 */
FUNCTION _HMG_HPDF_SetFontSize( nFontSize )

   DEFAULT nFontSize := 12
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   _HMG_HPDFDATA[ 1 ][ 9 ] := nFontSize

RETURN NIL

/*
 * _HMG_HPDF_SetFontName
 * Sets default font family name for the active document session.
 *
 * Parameters:
 *   cFontName - Character - Font family name string. Defaults to 'Helvetica'.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Updates default font name stored in global session array slot _HMG_HPDFDATA[1][8].
 */
FUNCTION _HMG_HPDF_SetFontName( cFontName )

   DEFAULT cFontName := 'Helvetica'
   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   _HMG_HPDFDATA[ 1 ][ 8 ] := cFontName

RETURN NIL

/*
 * HPDF_SkewText
 * Renders text on page distorted by horizontal and vertical skew angles.
 *
 * Parameters:
 *   nRow      - Numeric   - Y coordinate in mm.
 *   nCol      - Numeric   - X coordinate in mm.
 *   cFontName - Character - Font name or TTF path.
 *   nFontSize - Numeric   - Font size in points.
 *   nRColor   - Numeric   - Red component (0-255).
 *   nGColor   - Numeric   - Green component (0-255).
 *   nBColor   - Numeric   - Blue component (0-255).
 *   cText     - Character - Text string to skew and display.
 *   lBold     - Logical   - Bold flag.
 *   lItalic   - Logical   - Italic flag.
 *   lColor    - Logical   - Color specified flag.
 *   lFont     - Logical   - Font specified flag.
 *   lSize     - Logical   - Size specified flag.
 *   cAlign    - Character - Alignment option ('LEFT', 'CENTER', 'RIGHT').
 *   nAngle1   - Numeric   - Horizontal skew angle in degrees.
 *   nAngle2   - Numeric   - Vertical skew angle in degrees.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Applies text transformation matrix and renders skewed text string.
 */
FUNCTION HPDF_SkewText( nRow, nCol, cFontName, nFontSize, nRColor, nGColor, nBColor, cText, lBold, lItalic, lColor, lFont, lSize, cAlign, nAngle1, nAngle2 )

   LOCAL nRad1, nRad2, nTextWidth
   LOCAL oFont := NIL
   LOCAL cFont

   // Local handles to document and current page state
   LOCAL hPdf := _HMG_HPDFDATA[ 1 ][ 1 ]
   LOCAL hPage := _HMG_HPDFDATA[ 1 ][ 7 ]

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )

   // Set default parameters
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''
   DEFAULT nAngle1 := 0
   DEFAULT nAngle2 := 0

   IF ! HB_ISNUMERIC( nAngle1 )
      nAngle1 := 0
   ENDIF

   IF ! HB_ISNUMERIC( nAngle2 )
      nAngle2 := 0
   ENDIF

   // Convert skew angles from degrees to radians
   nRad1 := nAngle1 / 180 * 3.141592
   nRad2 := nAngle2 / 180 * 3.141592

   IF hPdf == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF hPage == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Configure fill color
   IF lColor
      HPDF_Page_SetRGBFill( hPage, nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( hPage, 0.0, 0.0, 0.0 )
   ENDIF

   // Load font handle
   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'
      cFont := HPDF_LoadTTFontFromFile( hPdf, cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( hPdf, cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( hPdf, cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( hPdf, cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF

   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ENDIF

   HPDF_Page_SetFontAndSize( hPage, oFont, nFontSize )
   nTextWidth := HPDF_Page_TextWidth( hPage, cText )

   // Adjust starting position for alignment
   SWITCH Upper( Left( AllTrim( cAlign ), 1 ) )
   CASE "R" ; nxPos := nxPos - nTextWidth ; EXIT
   CASE "C" ; nxPos := nxPos - ( nTextWidth / 2 ) ; EXIT
   ENDSWITCH

   nyPos -= nFontSize

   // Render text transformed by tangent skew matrix
   HPDF_Page_BeginText( hPage )
   HPDF_Page_SetTextMatrix ( hPage, 1, tan ( nRad1 ), tan ( nRad2 ), 1, nxPos, nyPos )
   HPDF_Page_ShowText( hPage, cText )
   HPDF_Page_EndText( hPage )

RETURN NIL

/*
 * HPDF_ScaleText
 * Prints text scaled along X and Y axes independently.
 *
 * Parameters:
 *   nRow      - Numeric   - Y position in mm.
 *   nCol      - Numeric   - X position in mm.
 *   cFontName - Character - Font family name or TTF file path.
 *   nFontSize - Numeric   - Font size in points.
 *   nRColor   - Numeric   - Red component (0-255).
 *   nGColor   - Numeric   - Green component (0-255).
 *   nBColor   - Numeric   - Blue component (0-255).
 *   cText     - Character - Text string to scale.
 *   lBold     - Logical   - Bold flag.
 *   lItalic   - Logical   - Italic flag.
 *   lColor    - Logical   - Color specified flag.
 *   lFont     - Logical   - Font specified flag.
 *   lSize     - Logical   - Size specified flag.
 *   cAlign    - Character - Alignment option.
 *   nxScale   - Numeric   - Horizontal scale factor (1.0 = 100%).
 *   nyScale   - Numeric   - Vertical scale factor (1.0 = 100%).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Sets text scaling matrix and displays scaled text.
 */
FUNCTION HPDF_ScaleText( nRow, nCol, cFontName, nFontSize, nRColor, nGColor, nBColor, cText, lBold, lItalic, lColor, lFont, lSize, cAlign, nxScale, nyScale )

   LOCAL nTextWidth
   LOCAL oFont := NIL
   LOCAL cFont
   LOCAL nxPos
   LOCAL nyPos

   // Local page handles
   LOCAL hPdf := _HMG_HPDFDATA[ 1 ][ 1 ]
   LOCAL hPage := _HMG_HPDFDATA[ 1 ][ 7 ]

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]

   // Apply parameter defaults
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]

   nxPos := _HMG_HPDF_MM2Pixel( nCol )
   nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow ) + _HMG_HPDF_MM2Pixel( nFontSize / 3 )

   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''
   DEFAULT nxScale := 1
   DEFAULT nyScale := 1

   IF hPdf == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF hPage == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Set fill RGB
   IF lColor
      HPDF_Page_SetRGBFill( hPage, nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( hPage, 0.0, 0.0, 0.0 )
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'
      cFont := HPDF_LoadTTFontFromFile( hPdf, cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( hPdf, cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( hPdf, cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( hPdf, cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF

   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ENDIF

   HPDF_Page_SetFontAndSize( hPage, oFont, nFontSize )
   nTextWidth := HPDF_Page_TextWidth( hPage, cText )

   SWITCH Upper( Left( AllTrim( cAlign ), 1 ) )
   CASE "R" ; nxPos := nxPos - nTextWidth ; EXIT
   CASE "C" ; nxPos := nxPos - ( nTextWidth / 2 ) ; EXIT
   ENDSWITCH

   nyPos -= nFontSize

   // Render scaled text string
   HPDF_Page_BeginText( hPage )
   HPDF_Page_SetTextMatrix ( hPage, nxScale, 0, 0, nyScale, nxPos, nyPos )
   HPDF_Page_ShowText( hPage, cText )
   HPDF_Page_EndText( hPage )

RETURN NIL

/*
 * HPDF_RenderText
 * Renders text using advanced rendering modes such as outlining, filling, and clipping paths.
 *
 * Parameters:
 *   nRow      - Numeric   - Y position in mm.
 *   nCol      - Numeric   - X position in mm.
 *   cFontName - Character - Font family or TTF path.
 *   nFontSize - Numeric   - Font size in points.
 *   nRColor   - Numeric   - Red component (0-255).
 *   nGColor   - Numeric   - Green component (0-255).
 *   nBColor   - Numeric   - Blue component (0-255).
 *   cText     - Character - Text string to render.
 *   lBold     - Logical   - Bold style flag.
 *   lItalic   - Logical   - Italic style flag.
 *   lColor    - Logical   - Color specified flag.
 *   lFont     - Logical   - Font specified flag.
 *   lSize     - Logical   - Size specified flag.
 *   cAlign    - Character - Text alignment option.
 *   nMode     - Numeric   - Rendering mode constant (HPDF_FILL, HPDF_STROKE, HPDF_FILL_CLIPPING, etc.).
 *   nLineW    - Numeric   - Outline stroke width in points.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Sets page text rendering mode, strokes glyph outlines, and may invoke pattern fill routine.
 */
FUNCTION HPDF_RenderText( nRow, nCol, cFontName, nFontSize, nRColor, nGColor, nBColor, cText, lBold, lItalic, lColor, lFont, lSize, cAlign, nMode, nLineW )

   LOCAL nTextWidth
   LOCAL oFont := NIL
   LOCAL cFont

   LOCAL hPdf := _HMG_HPDFDATA[ 1 ][ 1 ]
   LOCAL hPage := _HMG_HPDFDATA[ 1 ][ 7 ]

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )

   // Set default parameter values
   DEFAULT nLineW := 0.5
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cAlign := ''
   DEFAULT nMode := HPDF_FILL

   IF ! HB_ISNUMERIC( nMode )
      nMode := HPDF_FILL
   ENDIF

   IF ! HB_ISNUMERIC( nLineW )
      nLineW := 0.5
   ENDIF

   IF hPdf == NIL
      _HMG_HPDF_Error( 3 )
      RETURN NIL
   ENDIF
   IF hPage == NIL
      _HMG_HPDF_Error( 5 )
      RETURN NIL
   ENDIF

   // Set fill color
   IF lColor
      HPDF_Page_SetRGBFill( hPage, nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( hPage, 0.0, 0.0, 0.0 )
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'
      cFont := HPDF_LoadTTFontFromFile( hPdf, cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( hPdf, cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( hPdf, cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( hPdf, cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF

   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ENDIF

   // Configure stroke width and rendering mode mode within saved graphics state
   HPDF_Page_SetFontAndSize( hPage, oFont, nFontSize )
   HPDF_Page_SetLineWidth ( hPage, nLineW )
   HPDF_Page_GSave ( hPage )
   HPDF_Page_SetTextRenderingMode ( hPage, nMode )
   nTextWidth := HPDF_Page_TextWidth( hPage, cText )

   SWITCH Upper( Left( AllTrim( cAlign ), 1 ) )
   CASE "R" ; nxPos := nxPos - nTextWidth ; EXIT
   CASE "C" ; nxPos := nxPos - ( nTextWidth / 2 ) ; EXIT
   ENDSWITCH

   nyPos -= nFontSize

   HPDF_Page_BeginText ( hPage )
   HPDF_Page_TextOut ( hPage, nxPos, nyPos, cText )
   HPDF_Page_EndText ( hPage )
   // Draw pattern lines inside text bounds if clipping mode is selected
   IF nMode = HPDF_FILL_CLIPPING .OR. nMode = HPDF_STROKE_CLIPPING .OR. nMode = HPDF_FILL_STROKE_CLIPPING
      show_stripe_pattern ( hPage, nxPos, nyPos, nTextWidth )
   ENDIF
   HPDF_Page_GRestore ( hPage )

   /* Reset text attributes back to default state */
   HPDF_Page_SetTextRenderingMode ( hPage, HPDF_FILL )
   HPDF_Page_SetRGBFill ( hPage, 0, 0, 0 )
   HPDF_Page_SetFontAndSize( hPage, HPDF_GetFont( hPdf, "Helvetica", NIL ), 12 )
   HPDF_Page_SetLineWidth ( hPage, 0.1 )
   HPDF_Page_BeginText ( hPage )
   HPDF_Page_EndText ( hPage )

RETURN NIL

/*
 * show_stripe_pattern
 * Helper function that draws horizontal stripe vectors across text clipped areas.
 *
 * Parameters:
 *   hPage  - Pointer/Handle - Active HaruPDF page object.
 *   x      - Numeric        - Left X position in points.
 *   y      - Numeric        - Baseline Y position in points.
 *   nTxtW  - Numeric        - Width of text bounding area in points.
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Strokes blue stripe lines inside clipped region.
 */
FUNCTION show_stripe_pattern ( hPage, x, y, nTxtW )

   LOCAL iy := 0

   // Step vertically and draw horizontal vector lines
   DO WHILE iy < 50
      HPDF_Page_SetRGBStroke ( hPage, 0.0, 0.0, 0.5 )
      HPDF_Page_SetLineWidth ( hPage, 1 )
      HPDF_Page_MoveTo ( hPage, x, y + iy )
      HPDF_Page_LineTo ( hPage, x + nTxtW, y + iy )
      HPDF_Page_Stroke ( hPage )
      iy += 3
   ENDDO
   HPDF_Page_SetLineWidth ( hPage, 2 )

RETURN NIL

/*
 * HPDF_CircleText
 * Renders text formatted around a circular arc trajectory.
 *
 * Parameters:
 *   nRow      - Numeric   - Center point Y coordinate in mm.
 *   nCol      - Numeric   - Center point X coordinate in mm.
 *   cFontName - Character - Font family name or TTF path.
 *   nFontSize - Numeric   - Font size in points.
 *   nRColor   - Numeric   - Red component (0-255).
 *   nGColor   - Numeric   - Green component (0-255).
 *   nBColor   - Numeric   - Blue component (0-255).
 *   cText     - Character - Text string to arrange around circle.
 *   lBold     - Logical   - Bold flag.
 *   lItalic   - Logical   - Italic flag.
 *   lColor    - Logical   - Color specified flag.
 *   lFont     - Logical   - Font specified flag.
 *   lSize     - Logical   - Size specified flag.
 *   nRadial   - Numeric   - Inner radius in millimeters.
 *   lCircle   - Logical   - Option to draw guide circles around text.
 *   cAlign    - Character - Arc sector alignment ('TOP', 'BOTTOM', or full circle).
 *
 * Return:
 *   NIL
 *
 * Side Effects:
 *   Calculates individual character angles and draws glyphs rotated along circle arc.
 */
FUNCTION HPDF_CircleText( nRow, nCol, cFontName, nFontSize, nRColor, nGColor, nBColor, cText, lBold, lItalic, lColor, lFont, lSize, nRadial, lCircle, cAlign )

   LOCAL nAngle2, nRlen
   LOCAL i, nRad1, nRad2, x, y
   LOCAL oFont := NIL
   LOCAL cFont

   LOCAL hPdf := _HMG_HPDFDATA[ 1 ][ 1 ]
   LOCAL hPage := _HMG_HPDFDATA[ 1 ][ 7 ]

   LOCAL nHeight := _HMG_HPDFDATA[ 1 ][ 5 ]
   LOCAL nxPos := _HMG_HPDF_MM2Pixel( nCol )
   LOCAL nyPos := nHeight - _HMG_HPDF_MM2Pixel( nRow )
   LOCAL nPxAng
   LOCAL nRange := 360

   // Apply default parameters
   DEFAULT lCircle := .F.
   DEFAULT nRadial := 15
   DEFAULT cFontName := ''
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT nRColor := 0
   DEFAULT nGColor := 0
   DEFAULT nBColor := 0
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lColor := .F.
   DEFAULT lFont := .F.
   DEFAULT lSize := .F.
   DEFAULT cText := ""

   IF ! HB_ISNUMERIC( nRadial )
      nRadial := 15
   ENDIF

   IF ! HB_ISSTRING( cAlign )
      cAlign := ""
   ENDIF

   nRLen := _HMG_HPDF_MM2Pixel( nRadial )

   // Configure fill color
   IF lColor
      HPDF_Page_SetRGBFill( hPage, nRColor / 255, nGColor / 255, nBColor / 255 )
   ELSE
      HPDF_Page_SetRGBFill( hPage, 0.0, 0.0, 0.0 )
   ENDIF

   // Draw boundary guide circles if requested
   IF lCircle
      IF lColor
         HPDF_Page_SetRGBSTROKE( hPage, nRColor / 255, nGColor / 255, nBColor / 255 )
      ELSE
         HPDF_Page_SetRGBSTROKE( hPage, 0.0, 0.0, 0.0 )
      ENDIF
      HPDF_Page_SetLineWidth ( hPage, 1.5 )
      HPDF_Page_Circle ( hPage, nxPos, nyPos, nRlen + nFontSize )
      HPDF_Page_Circle ( hPage, nxPos, nyPos, nRlen - ( nFontSize / 3 ) )
      HPDF_Page_Stroke ( hPage )
      HPDF_Page_SetLineWidth ( hPage, 1 )
   ENDIF

   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'
      cFont := HPDF_LoadTTFontFromFile( hPdf, cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN NIL
      ENDIF
      oFont := HPDF_GetFont( hPdf, cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( hPdf, cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( hPdf, cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF

   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN NIL
   ENDIF
   HPDF_Page_SetFontAndSize( hPage, oFont, nFontSize )

   // Determine angle spread range
   SWITCH Upper( Left( AllTrim( cAlign ), 1 ) )
   CASE "T" ; nRange := 180 ; EXIT // Upper semi-circle
   CASE "B" ; nRange := 180 ; EXIT // Lower semi-circle
   ENDSWITCH

   nAngle2 := 180

   // Compute proportional angular step per pixel width
   nPxAng := nRange / HPDF_Page_TextWidth( hPage, cText )

   // Iterate through string characters and project each along radial coordinates
   HPDF_Page_BeginText ( hPage )
   FOR i = 1 TO Len( cText )
      nRad1 := ( nAngle2 - Int( ( HPDF_Page_TextWidth( hPage, SubStr( cText, i, 1 ) ) * nPxAng ) / 2 ) - 90 ) / 180 * 3.141592
      nRad2 := nAngle2 / 180 * 3.141592

      SWITCH Upper( Left( AllTrim( cAlign ), 1 ) )
      CASE "B" // Bottom semi-circle projection
         x := nxPos + cos( nRad2 ) * ( nRlen + nFontSize * ( 2 / 3 ) )
         y := nyPos - sin( nRad2 ) * ( nRlen + nFontSize * ( 2 / 3 ) )

         HPDF_Page_SetTextMatrix( hPage, cos( nRad1 ), -sin( nRad1 ), sin( nRad1 ), cos( nRad1 ), x, y )
         EXIT

      DEFAULT // Standard top semi-circle or full circular projection
         x := nxPos + cos( nRad2 ) * nRlen
         y := nyPos + sin( nRad2 ) * nRlen

         HPDF_Page_SetTextMatrix( hPage, cos( nRad1 ), sin( nRad1 ), -sin( nRad1 ), cos( nRad1 ), x, y )

      ENDSWITCH

      HPDF_Page_ShowText ( hPage, SubStr( cText, i, 1 ) )

      // Advance angle based on individual character width
      nAngle2 -= ( HPDF_Page_TextWidth( hPage, SubStr( cText, i, 1 ) ) * nPxAng )

   NEXT i
   HPDF_Page_EndText ( hPage )

RETURN NIL

/*
 * HMG_GetPDFTextWidth
 * Calculates rendered text string width in millimeters using specified font settings.
 *
 * Parameters:
 *   cText      - Character - String to measure.
 *   cFontName  - Character - Font family name or TTF path.
 *   nFontSize  - Numeric   - Font size in points.
 *   lBold      - Logical   - Bold flag.
 *   lItalic    - Logical   - Italic flag.
 *   lUnderline - Logical   - Underline flag.
 *   lStrikeout - Logical   - Strikeout flag.
 *
 * Return:
 *   Numeric - Computed text width in millimeters, or 0 on error.
 *
 * Side Effects:
 *   None
 */
FUNCTION HMG_GetPDFTextWidth ( cText, cFontName, nFontSize, lBold, lItalic, lUnderline, lStrikeout )

   LOCAL cFont, oFont, nWidth

   DEFAULT cFontName := ""
   DEFAULT nFontSize := _HMG_HPDFDATA[ 1 ][ 9 ]
   DEFAULT lBold := .F.
   DEFAULT lItalic := .F.
   DEFAULT lUnderline := .F.
   DEFAULT lStrikeout := .F.

   IF _HMG_HPDFDATA[ 1 ][ 1 ] == NIL
      _HMG_HPDF_Error( 3 )
      RETURN 0
   ENDIF
   IF _HMG_HPDFDATA[ 1 ][ 7 ] == NIL
      _HMG_HPDF_Error( 5 )
      RETURN 0
   ENDIF

   // Resolve font handle
   cFontName := AllTrim( _HMG_HPDF_SetFont( cFontName, lBold, lItalic ) )
   IF Upper ( cFileExt ( cFontName ) ) == '.TTF'
      cFont := HPDF_LOADTTFONTFROMFILE( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, .T. )
      IF Len( AllTrim( cFont ) ) == 0
         _HMG_HPDF_Error( 6, cFontName )
         RETURN 0
      ENDIF
      oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFont, _HMG_HPDFDATA[ 1 ][ 10 ] )
   ELSE
      IF Upper( AllTrim( cFontName ) ) == "SYMBOL" .OR. Upper( AllTrim( cFontName ) ) == "ZAPFDINGBATS"
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, NIL )
      ELSE
         oFont := HPDF_GetFont( _HMG_HPDFDATA[ 1 ][ 1 ], cFontName, _HMG_HPDFDATA[ 1 ][ 10 ] )
      ENDIF
   ENDIF

   IF oFont == NIL
      _HMG_HPDF_Error( 6, cFontName )
      RETURN 0
   ELSE
      // Apply font and measure text width converted to millimeters
      HPDF_Page_SetFontAndSize( _HMG_HPDFDATA[ 1 ][ 7 ], oFont, nFontSize )
      nWidth := _HMG_HPDF_Pixel2MM( HPDF_Page_TextWidth( _HMG_HPDFDATA[ 1 ][ 7 ], cText ) )
   ENDIF

RETURN nWidth

/*
 * cFileExt
 * Extracts extension component from a file system path string.
 *
 * Parameters:
 *   cPathMask - Character - File system path string.
 *
 * Return:
 *   Character - File extension including leading dot (e.g., ".ttf").
 *
 * Side Effects:
 *   None
 */
FUNCTION cFileExt( cPathMask )

   LOCAL cExt

   // Parse path component parts using Harbour system runtime call
   hb_FNameSplit( cPathMask, , , @cExt )

RETURN cExt
