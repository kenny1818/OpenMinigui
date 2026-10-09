#include "hbvpdf.ch"
#include "fileio.ch"

// Compatibility macro for default NIL handling
#if defined( __XHARBOUR__ ) .OR. ( __HARBOUR__ - 0 < 0x030200 )
# xtranslate __defaultNIL( @<v>, <x> ) => ( <v> := iif( <v> == NIL, <x>, <v> ) )
#endif

// Carriage return and line feed sequence used throughout raw PDF stream generation
#define CRLF ( Chr( 13 ) + Chr( 10 ) )

// Module-wide static report array holding current PDF document state, buffers, and metadata
STATIC s_aReport

/*
 * Function:    pdfInit
 * Purpose:     Initializes the static PDF report state structure.
 * Parameters:  None
 * Returns:     Array - Reference to the newly allocated static report state array (s_aReport).
 * Side Effects: Re-allocates s_aReport with size PARAMLEN.
 */
FUNCTION pdfInit()
   s_aReport := Array( PARAMLEN )

RETURN s_aReport

/*
 * Function:    pdfWidth
 * Purpose:     Sets the virtual column width for report coordinate calculations.
 * Parameters:  _nWidth (Numeric) - Total columns/width for the virtual report grid.
 * Returns:     NIL
 * Side Effects: Updates the REPORTWIDTH element in static array s_aReport.
 */
FUNCTION pdfWidth( _nWidth )
   s_aReport[ REPORTWIDTH ] := _nWidth

RETURN NIL

/*
 * Function:    pdfTextWidth
 * Purpose:     Calculates the rendered width of a given text string in millimeters.
 * Parameters:  cStr (Character) - Text string to be measured.
 * Returns:     Numeric - Width of the text in millimeters.
 * Side Effects: None
 */
FUNCTION pdfTextWidth( cStr )
RETURN pdfLen( cStr ) / 25.4

/*
 * Function:    pdfAtSay
 * Purpose:     Renders a text string at specified coordinates within the active PDF page stream.
 * Parameters:  cString (Character) - Text string to output.
 *              nRow    (Numeric)   - Row position (defaults to current line).
 *              nCol    (Numeric)   - Column position.
 *              cUnits  (Character) - Position units ("R"=Rows, "M"=Millimeters; defaults to "R").
 *              lExact  (Logical)   - Bypass automatic line height checks (.T./.F.; defaults to .F.).
 *              cId     (Character) - Header item identifier for template editing.
 * Returns:     NIL
 * Side Effects: Appends raw PDF text operators to s_aReport[ PAGEBUFFER ],
 *              updates font tracking state, and may trigger automatic page breaks.
 */
FUNCTION pdfAtSay( cString, nRow, nCol, cUnits, lExact, cId )

   LOCAL _nFont, lReverse, nAt
   // Apply default values to optional parameters
   __defaultNIL( @nRow, s_aReport[ REPORTLINE ] )
   __defaultNIL( @cUnits, "R" )
   __defaultNIL( @lExact, .F. )
   __defaultNIL( @cId, "" )

   // Intercept and record call if currently defining a page header template
   IF s_aReport[ HEADEREDIT ]
      RETURN pdfHeader( "PDFATSAY", cId, { cString, nRow, nCol, cUnits, lExact } )
   ENDIF

   // Substitute page number placeholder tag with current page number
   IF ( nAt := At( "#pagenumber#", cString ) ) > 0
      cString := Left( cString, nAt - 1 ) + hb_ntos( pdfPageNumber() ) + SubStr( cString, nAt + 12 )
   ENDIF

   lReverse := .F.

   // Convert unit coordinates to absolute PDF points based on unit type
   IF cUnits == "M"
      nRow := pdfM2Y( nRow )
      nCol := pdfM2X( nCol )
   ELSEIF cUnits == "R"
      IF ! lExact
         pdfCheckLine( nRow )
         nRow := nRow + s_aReport[ PDFTOP ]
      ENDIF
      nRow := pdfR2D( nRow )
      nCol := pdfM2X( s_aReport[ PDFLEFT ] ) + ;
         nCol * 100.00 / s_aReport[ REPORTWIDTH ] * ;
         ( s_aReport[ PAGEX ] - pdfM2X( s_aReport[ PDFLEFT ] ) * 2 - 9.0 ) / 100.00
   ENDIF

   // Process and output formatted text if non-empty
   IF ! Empty( cString )
      cString := pdfStringB( cString )

      // Check trailing control characters for text attribute formatting (reverse / underline)
      IF Right( cString, 1 ) == Chr( 255 ) // Reverse video text attribute
         cString := Left( cString, Len( cString ) - 1 )
         pdfBox( s_aReport[ PAGEY ] - nRow - s_aReport[ FONTSIZE ] + 2.0, nCol, s_aReport[ PAGEY ] - nRow + 2.0, nCol + pdfM2X( pdfLen( cString ) ) + 1,, 100, "D" )
         s_aReport[ PAGEBUFFER ] += " 1 g "
         lReverse := .T.
      ELSEIF Right( cString, 1 ) == Chr( 254 ) // Underline text attribute
         cString := Left( cString, Len( cString ) - 1 )
         pdfBox( s_aReport[ PAGEY ] - nRow + 0.5, nCol, s_aReport[ PAGEY ] - nRow + 1, nCol + pdfM2X( pdfLen( cString ) ) + 1,, 100, "D" )
      ENDIF

      // Extract embedded RGB color control byte sequence
      IF ( nAt := At( Chr( 253 ), cString ) ) > 0 // Embedded RGB color specifier
         s_aReport[ PAGEBUFFER ] += CRLF + ;
            Chr_RGB( SubStr( cString, nAt + 1, 1 ) ) + " " + ;
            Chr_RGB( SubStr( cString, nAt + 2, 1 ) ) + " " + ;
            Chr_RGB( SubStr( cString, nAt + 3, 1 ) ) + " rg "
         cString := Stuff( cString, nAt, 4, "" )
      ENDIF

      // Construct PDF text object graphics stream
      _nFont := AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ FONTNAME ] } )
      IF !( s_aReport[ FONTNAME ] == s_aReport[ FONTNAMEPREV ] )
         s_aReport[ FONTNAMEPREV ] := s_aReport[ FONTNAME ]
         s_aReport[ PAGEBUFFER ] += CRLF + "BT /Fo" + hb_ntos( _nFont ) + " " + LTrim( Transform( s_aReport[ FONTSIZE ], "999.99" ) ) + " Tf " + LTrim( Transform( nCol, "9999.99" ) ) + " " + LTrim( Transform( nRow, "9999.99" ) ) + " Td (" + cString + ") Tj ET"
      ELSEIF s_aReport[ FONTSIZE ] != s_aReport[ FONTSIZEPREV ]
         s_aReport[ FONTSIZEPREV ] := s_aReport[ FONTSIZE ]
         s_aReport[ PAGEBUFFER ] += CRLF + "BT /Fo" + hb_ntos( _nFont ) + " " + LTrim( Transform( s_aReport[ FONTSIZE ], "999.99" ) ) + " Tf " + LTrim( Transform( nCol, "9999.99" ) ) + " " + LTrim( Transform( nRow, "9999.99" ) ) + " Td (" + cString + ") Tj ET"
      ELSE
         s_aReport[ PAGEBUFFER ] += CRLF + "BT " + LTrim( Transform( nCol, "9999.99" ) ) + " " + LTrim( Transform( nRow, "9999.99" ) ) + " Td (" + cString + ") Tj ET"
      ENDIF

      // Restore fill color if reverse video was applied
      IF lReverse
         s_aReport[ PAGEBUFFER ] += " 0 g "
      ENDIF
   ENDIF

RETURN NIL

/*
 * Function:    pdfBold
 * Purpose:     Selects the Bold style variant of the active font family.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Updates FONTNAME, PAGEFONTS, and FONTS in s_aReport.
 */
FUNCTION pdfBold()
   // Map bold font variant index based on active font family name
   IF pdfGetFontInfo( "NAME" ) == "Times"
      s_aReport[ FONTNAME ] := 2
   ELSEIF pdfGetFontInfo( "NAME" ) == "Helvetica"
      s_aReport[ FONTNAME ] := 6
   ELSE
      s_aReport[ FONTNAME ] := 10 // Courier
   ENDIF
   AAdd( s_aReport[ PAGEFONTS ], s_aReport[ FONTNAME ] )
   IF AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ FONTNAME ] } ) == 0
      AAdd( s_aReport[ FONTS ], { s_aReport[ FONTNAME ], ++s_aReport[ NEXTOBJ ] } )
   ENDIF

RETURN NIL

/*
 * Function:    pdfBoldItalic
 * Purpose:     Selects the Bold-Italic style variant of the active font family.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Updates FONTNAME, PAGEFONTS, and FONTS in s_aReport.
 */
FUNCTION pdfBoldItalic()
   // Map bold-italic font variant index based on active font family name
   IF pdfGetFontInfo( "NAME" ) == "Times"
      s_aReport[ FONTNAME ] := 4
   ELSEIF pdfGetFontInfo( "NAME" ) == "Helvetica"
      s_aReport[ FONTNAME ] := 8
   ELSE
      s_aReport[ FONTNAME ] := 12
   ENDIF
   AAdd( s_aReport[ PAGEFONTS ], s_aReport[ FONTNAME ] )
   IF AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ FONTNAME ] } ) == 0
      AAdd( s_aReport[ FONTS ], { s_aReport[ FONTNAME ], ++s_aReport[ NEXTOBJ ] } )
   ENDIF

RETURN NIL

/*
 * Function:    pdfBookAdd
 * Purpose:     Adds an entry (bookmark) to the PDF document navigation outline tree.
 * Parameters:  cTitle (Character) - Display text for the bookmark.
 *              nLevel (Numeric)   - Nesting level depth in outline tree hierarchy (1, 2, ...).
 *              nPage  (Numeric)   - Target page number linked to the bookmark.
 *              nLine  (Numeric)   - Target line position on the page.
 * Returns:     NIL
 * Side Effects: Appends outline record array to s_aReport[ BOOKMARK ].
 */
FUNCTION pdfBookAdd( cTitle, nLevel, nPage, nLine )
   AAdd( s_aReport[ BOOKMARK ], { nLevel, AllTrim( cTitle ), 0, 0, 0, 0, 0, 0, nPage, iif( nLevel == 1, s_aReport[ PAGEY ], s_aReport[ PAGEY ] - nLine * 72 / s_aReport[ LPI ] ) } )

RETURN NIL

/*
 * Function:    pdfBookClose
 * Purpose:     Clears and releases bookmark outline data structure.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Resets s_aReport[ BOOKMARK ] element to NIL.
 */
FUNCTION pdfBookClose()
   s_aReport[ BOOKMARK ] := NIL

RETURN NIL

/*
 * Function:    pdfBookCount
 * Purpose:     Counts immediate sub-elements under a given bookmark outline node.
 * Parameters:  nRecno    (Numeric) - Index of parent bookmark in s_aReport[ BOOKMARK ].
 *              nCurLevel (Numeric) - Nesting level of current parent node.
 * Returns:     Numeric - Negative count of child bookmarks (per PDF outline specification).
 * Side Effects: None
 */
STATIC FUNCTION pdfBookCount( nRecno, nCurLevel )

   LOCAL nTempLevel, nCount := 0, nLen := Len( s_aReport[ BOOKMARK ] )
   ++nRecno
   // Iterate forward through outline entries to count child elements
   WHILE nRecno <= nLen
      nTempLevel := s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
      IF nTempLevel <= nCurLevel
         EXIT
      ELSE
         IF nCurLevel + 1 == nTempLevel
            ++nCount
         ENDIF
      ENDIF
      ++nRecno
   ENDDO

RETURN -1 * nCount

/*
 * Function:    pdfBookFirst
 * Purpose:     Locates the first child bookmark node object ID for a given parent node.
 * Parameters:  nRecno    (Numeric) - Index of parent bookmark in s_aReport[ BOOKMARK ].
 *              nCurLevel (Numeric) - Nesting level of current parent node.
 *              nObj      (Numeric) - Base PDF object number offset for bookmarks.
 * Returns:     Numeric - PDF object ID of the first child bookmark, or 0 if none.
 * Side Effects: None
 */
STATIC FUNCTION pdfBookFirst( nRecno, nCurLevel, nObj )

   LOCAL nFirst := 0, nLen := Len( s_aReport[ BOOKMARK ] )
   ++nRecno
   IF nRecno <= nLen
      IF nCurLevel + 1 == s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
         nFirst := nRecno
      ENDIF
   ENDIF

RETURN iif( nFirst == 0, nFirst, nObj + nFirst )

/*
 * Function:    pdfBookLast
 * Purpose:     Locates the last child bookmark node object ID for a given parent node.
 * Parameters:  nRecno    (Numeric) - Index of parent bookmark in s_aReport[ BOOKMARK ].
 *              nCurLevel (Numeric) - Nesting level of current parent node.
 *              nObj      (Numeric) - Base PDF object number offset for bookmarks.
 * Returns:     Numeric - PDF object ID of the last child bookmark, or 0 if none.
 * Side Effects: None
 */
STATIC FUNCTION pdfBookLast( nRecno, nCurLevel, nObj )

   LOCAL nLast := 0, nLen := Len( s_aReport[ BOOKMARK ] )
   ++nRecno
   IF nRecno <= nLen
      IF nCurLevel + 1 == s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
         WHILE nRecno <= nLen .AND. nCurLevel + 1 <= s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
            IF nCurLevel + 1 == s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
               nLast := nRecno
            ENDIF
            ++nRecno
         ENDDO
      ENDIF
   ENDIF

RETURN iif( nLast == 0, nLast, nObj + nLast )

/*
 * Function:    pdfBookNext
 * Purpose:     Finds the next sibling bookmark node object ID at the same depth level.
 * Parameters:  nRecno    (Numeric) - Index of current bookmark in s_aReport[ BOOKMARK ].
 *              nCurLevel (Numeric) - Nesting level depth of current node.
 *              nObj      (Numeric) - Base PDF object number offset for bookmarks.
 * Returns:     Numeric - PDF object ID of next sibling bookmark, or 0 if none.
 * Side Effects: None
 */
STATIC FUNCTION pdfBookNext( nRecno, nCurLevel, nObj )

   LOCAL nTempLevel, nNext := 0, nLen := Len( s_aReport[ BOOKMARK ] )
   ++nRecno
   // Iterate forward to locate next entry at matching hierarchy level
   WHILE nRecno <= nLen
      nTempLevel := s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
      IF nCurLevel > nTempLevel
         EXIT
      ELSEIF nCurLevel == nTempLevel
         nNext := nRecno
         EXIT
      ELSE
         // Skip deeper nested child levels
      ENDIF
      ++nRecno
   ENDDO

RETURN iif( nNext == 0, nNext, nObj + nNext )

/*
 * Function:    pdfBookOpen
 * Purpose:     Initializes the document bookmark/outline collection list.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Sets s_aReport[ BOOKMARK ] to an empty array.
 */
FUNCTION pdfBookOpen()
   s_aReport[ BOOKMARK ] := {}

RETURN NIL

/*
 * Function:    pdfBookParent
 * Purpose:     Locates parent bookmark object ID for a child node.
 * Parameters:  nRecno    (Numeric) - Index of child bookmark in s_aReport[ BOOKMARK ].
 *              nCurLevel (Numeric) - Nesting level depth of child node.
 *              nObj      (Numeric) - Base PDF object number offset for bookmarks.
 * Returns:     Numeric - PDF object ID of parent bookmark.
 * Side Effects: None
 */
STATIC FUNCTION pdfBookParent( nRecno, nCurLevel, nObj )

   LOCAL nTempLevel
   LOCAL nParent := 0
   --nRecno
   // Traverse backwards to locate enclosing parent level
   WHILE nRecno > 0
      nTempLevel := s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
      IF nTempLevel < nCurLevel
         nParent := nRecno
         EXIT
      ENDIF
      --nRecno
   ENDDO

RETURN iif( nParent == 0, nObj - 1, nObj + nParent )

/*
 * Function:    pdfBookPrev
 * Purpose:     Finds previous sibling bookmark node object ID at the same depth level.
 * Parameters:  nRecno    (Numeric) - Index of current bookmark in s_aReport[ BOOKMARK ].
 *              nCurLevel (Numeric) - Nesting level depth of current node.
 *              nObj      (Numeric) - Base PDF object number offset for bookmarks.
 * Returns:     Numeric - PDF object ID of previous sibling bookmark, or 0 if none.
 * Side Effects: None
 */
STATIC FUNCTION pdfBookPrev( nRecno, nCurLevel, nObj )

   LOCAL nTempLevel
   LOCAL nPrev := 0
   --nRecno
   // Traverse backwards to locate preceding entry at matching level
   WHILE nRecno > 0
      nTempLevel := s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
      IF nCurLevel > nTempLevel
         EXIT
      ELSEIF nCurLevel == nTempLevel
         nPrev := nRecno
         EXIT
      ELSE
         // Skip nested elements
      ENDIF
      --nRecno
   ENDDO

RETURN iif( nPrev == 0, nPrev, nObj + nPrev )

/*
 * Function:    pdfBox
 * Purpose:     Draws a filled and/or bordered rectangle on the active PDF page.
 * Parameters:  x1      (Numeric)   - Top/Y1 coordinate position.
 *              y1      (Numeric)   - Left/X1 coordinate position.
 *              x2      (Numeric)   - Bottom/Y2 coordinate position.
 *              y2      (Numeric)   - Right/X2 coordinate position.
 *              nBorder (Numeric)   - Border line thickness (0 = no border).
 *              nShade  (Numeric)   - Fill shade percentage (0..100; 0 = transparent).
 *              cUnits  (Character) - Coordinate units ("M"=Millimeters, "D"=Dots/Points).
 *              cColor  (Character) - RGB color string specifier.
 *              cId     (Character) - Identifier if executing in header editing mode.
 * Returns:     NIL
 * Side Effects: Appends rectangle rendering commands to s_aReport[ PAGEBUFFER ].
 */
FUNCTION pdfBox( x1, y1, x2, y2, nBorder, nShade, cUnits, cColor, cId )

   LOCAL cBoxColor

   // Set default parameter values
   __defaultNIL( @nBorder, 0 )
   __defaultNIL( @nShade, 0 )
   __defaultNIL( @cUnits, "M" )
   __defaultNIL( @cColor, "" )

   // Build color string command if color parameter is supplied
   cBoxColor := ""
   IF ! Empty( cColor )
      cBoxColor := " " + Chr_RGB( SubStr( cColor, 2, 1 ) ) + " " + ;
         Chr_RGB( SubStr( cColor, 3, 1 ) ) + " " + ;
         Chr_RGB( SubStr( cColor, 4, 1 ) ) + " rg "
      IF Empty( AllTrim( cBoxColor ) )
         cBoxColor := ""
      ENDIF
   ENDIF

   // Store graphics command in header structure if header editing mode is enabled
   IF s_aReport[ HEADEREDIT ]
      RETURN pdfHeader( "PDFBOX", cId, { x1, y1, x2, y2, nBorder, nShade, cUnits } )
   ENDIF

   // Construct PDF path rectangle operators based on units
   IF cUnits == "M"
      y1 += 0.5
      y2 += 0.5
      IF nShade > 0
         s_aReport[ PAGEBUFFER ] += CRLF + Transform( 1.00 - nShade / 100.00, "9.99" ) + " g " + cBoxColor + hb_ntos( pdfM2X( y1 ) ) + " " + hb_ntos( pdfM2Y( x1 ) ) + " " + hb_ntos( pdfM2X( y2 - y1 ) ) + " -" + hb_ntos( pdfM2X( x2 - x1 ) ) + " re f 0 g"
      ENDIF
      IF nBorder > 0
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( pdfM2X( y1 ) ) + " " + hb_ntos( pdfM2Y( x1 ) ) + " " + hb_ntos( pdfM2X( y2 - y1 ) ) + " -" + hb_ntos( pdfM2X( nBorder ) ) + " re f"
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( pdfM2X( y2 - nBorder ) ) + " " + hb_ntos( pdfM2Y( x1 ) ) + " " + hb_ntos( pdfM2X( nBorder ) ) + " -" + hb_ntos( pdfM2X( x2 - x1 ) ) + " re f"
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( pdfM2X( y1 ) ) + " " + hb_ntos( pdfM2Y( x2 - nBorder ) ) + " " + hb_ntos( pdfM2X( y2 - y1 ) ) + " -" + hb_ntos( pdfM2X( nBorder ) ) + " re f"
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( pdfM2X( y1 ) ) + " " + hb_ntos( pdfM2Y( x1 ) ) + " " + hb_ntos( pdfM2X( nBorder ) ) + " -" + hb_ntos( pdfM2X( x2 - x1 ) ) + " re f"
      ENDIF
   ELSEIF cUnits == "D"// "Dots" points mode
      IF nShade > 0
         s_aReport[ PAGEBUFFER ] += CRLF + Transform( 1.00 - nShade / 100.00, "9.99" ) + " g " + cBoxColor + hb_ntos( y1 ) + " " + hb_ntos( s_aReport[ PAGEY ] - x1 ) + " " + hb_ntos( y2 - y1 ) + " -" + hb_ntos( x2 - x1 ) + " re f 0 g"
      ENDIF
      IF nBorder > 0
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( y1 ) + " " + hb_ntos( s_aReport[ PAGEY ] - x1 ) + " " + hb_ntos( y2 - y1 ) + " -" + hb_ntos( nBorder ) + " re f"
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( y2 - nBorder ) + " " + hb_ntos( s_aReport[ PAGEY ] - x1 ) + " " + hb_ntos( nBorder ) + " -" + hb_ntos( x2 - x1 ) + " re f"
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( y1 ) + " " + hb_ntos( s_aReport[ PAGEY ] - x2 + nBorder ) + " " + hb_ntos( y2 - y1 ) + " -" + hb_ntos( nBorder ) + " re f"
         s_aReport[ PAGEBUFFER ] += CRLF + "0 g " + hb_ntos( y1 ) + " " + hb_ntos( s_aReport[ PAGEY ] - x1 ) + " " + hb_ntos( nBorder ) + " -" + hb_ntos( x2 - x1 ) + " re f"
      ENDIF
   ENDIF

RETURN NIL

/*
 * Function:    pdfBox1
 * Purpose:     Draws a rectangle with customizable border stroke width, border RGB, and fill RGB colors.
 * Parameters:  nTop         (Numeric)   - Top position in PDF points.
 *              nLeft        (Numeric)   - Left position in PDF points.
 *              nBottom      (Numeric)   - Bottom position in PDF points.
 *              nRight       (Numeric)   - Right position in PDF points.
 *              nBorderWidth (Numeric)   - Stroke line width in points (default 0.5).
 *              cBorderColor (Character) - 3-character binary RGB string for border color.
 *              cBoxColor    (Character) - 3-character binary RGB string for fill color.
 * Returns:     NIL
 * Side Effects: Appends path operators directly to s_aReport[ PAGEBUFFER ].
 */
FUNCTION pdfBox1( nTop, nLeft, nBottom, nRight, nBorderWidth, cBorderColor, cBoxColor )

   // Set default border width and RGB black/white parameters
   __defaultNIL( @nBorderWidth, 0.5 )
   __defaultNIL( @cBorderColor, Chr( 0 ) + Chr( 0 ) + Chr( 0 ) )
   __defaultNIL( @cBoxColor, Chr( 255 ) + Chr( 255 ) + Chr( 255 ) )

   // Build PDF path rectangle and color operator stream
   s_aReport[ PAGEBUFFER ] += CRLF + ;
      Chr_RGB( SubStr( cBorderColor, 1, 1 ) ) + " " + ;
      Chr_RGB( SubStr( cBorderColor, 2, 1 ) ) + " " + ;
      Chr_RGB( SubStr( cBorderColor, 3, 1 ) ) + ;
      " RG" + ;
      CRLF + ;
      Chr_RGB( SubStr( cBoxColor, 1, 1 ) ) + " " + ;
      Chr_RGB( SubStr( cBoxColor, 2, 1 ) ) + " " + ;
      Chr_RGB( SubStr( cBoxColor, 3, 1 ) ) + ;
      " rg" + ;
      CRLF + hb_ntos( nBorderWidth ) + " w" + ;
      CRLF + hb_ntos( nLeft + nBorderWidth / 2 ) + " " + ;
      CRLF + hb_ntos( s_aReport[ PAGEY ] - nBottom + nBorderWidth / 2 ) + " " + ;
      CRLF + hb_ntos( nRight - nLeft - nBorderWidth ) + ;
      CRLF + hb_ntos( nBottom - nTop - nBorderWidth ) + " " + ;
      " re" + ;
      CRLF + "B"

RETURN NIL

/*
 * Function:    pdfCenter
 * Purpose:     Displays text horizontally centered at a target column position.
 * Parameters:  cString (Character) - Text string to render.
 *              nRow    (Numeric)   - Row position.
 *              nCol    (Numeric)   - Column origin for center alignment.
 *              cUnits  (Character) - Units identifier ("R"=Rows, "M"=Millimeters).
 *              lExact  (Logical)   - If .T., bypasses auto line checks.
 *              cId     (Character) - Header item identifier for header editing.
 * Returns:     NIL
 * Side Effects: Calls pdfAtSay to output string; updates current line position.
 */
FUNCTION pdfCenter( cString, nRow, nCol, cUnits, lExact, cId )

   LOCAL nLen, nAt

   // Apply defaults to positioning arguments
   __defaultNIL( @nRow, s_aReport[ REPORTLINE ] )
   __defaultNIL( @cUnits, "R" )
   __defaultNIL( @lExact, .F. )
   __defaultNIL( @nCol, iif( cUnits == "R", s_aReport[ REPORTWIDTH ] / 2, s_aReport[ PAGEX ] / 72 * 25.4 / 2 ) )

   // Redirect command if currently editing header template
   IF s_aReport[ HEADEREDIT ]
      RETURN pdfHeader( "PDFCENTER", cId, { cString, nRow, nCol, cUnits, lExact } )
   ENDIF

   // Substitute page number macro tag if present in text
   IF ( nAt := At( "#pagenumber#", cString ) ) > 0
      cString := Left( cString, nAt - 1 ) + hb_ntos( pdfPageNumber() ) + SubStr( cString, nAt + 12 )
   ENDIF

   // Calculate string half-length offset in millimeters
   nLen := pdfLen( cString ) / 2

   IF cUnits == "R"
      IF ! lExact
         pdfCheckLine( nRow )
         nRow := nRow + s_aReport[ PDFTOP ]
      ENDIF
   ENDIF

   // Render text using offset column calculated for center alignment
   pdfAtSay( cString, pdfR2M( nRow ), iif( cUnits == "R", s_aReport[ PDFLEFT ] + ( s_aReport[ PAGEX ] / 72 * 25.4 - 2 * s_aReport[ PDFLEFT ] ) * nCol / s_aReport[ REPORTWIDTH ], nCol ) - nLen, "M", lExact )

RETURN NIL

/*
 * Function:    pdfCheckLine
 * Purpose:     Verifies if a target row exceeds printable page bottom boundary.
 * Parameters:  nRow (Numeric) - Proposed row position.
 * Returns:     NIL
 * Side Effects: Calls pdfNewPage() if boundary is exceeded; updates s_aReport[ REPORTLINE ].
 */
STATIC FUNCTION pdfCheckLine( nRow )
   IF nRow + s_aReport[ PDFTOP ] > s_aReport[ PDFBOTTOM ]
      pdfNewPage()
      nRow := s_aReport[ REPORTLINE ]
   ENDIF
   s_aReport[ REPORTLINE ] := nRow

RETURN NIL

/*
 * Function:    pdfClose
 * Purpose:     Finalizes the PDF document structure, outputs catalog objects, cross-reference table, and trailer.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Closes active low-level file handle and sets s_aReport to NIL.
 */
FUNCTION pdfClose()

   LOCAL nI, cTemp, nCurLevel, nObj1, nLast, nCount, nFirst, nRecno, nBooklen

   // Flush and write active page object content
   pdfClosePage()

   // Write PDF Pages catalog / Kids array object
   s_aReport[ REFS ][ 2 ] := s_aReport[ DOCLEN ]
   cTemp := ;
      "1 0 obj" + CRLF + ;
      "<<" + CRLF + ;
      "/Type /Pages /Count " + hb_ntos( s_aReport[ REPORTPAGE ] ) + CRLF + ;
      "/Kids ["
   FOR nI := 1 TO s_aReport[ REPORTPAGE ]
      cTemp += " " + hb_ntos( s_aReport[ PAGES ][ nI ] ) + " 0 R"
   NEXT
   cTemp += " ]" + CRLF + ;
      ">>" + CRLF + ;
      "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Write PDF Document Information dictionary object
   ++s_aReport[ REPORTOBJ ]
   AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
   cTemp := hb_ntos( s_aReport[ REPORTOBJ ] ) + " 0 obj" + CRLF + ;
      "<<" + CRLF + ;
      "/Producer ()" + CRLF + ;
      "/Title ()" + CRLF + ;
      "/Author ()" + CRLF + ;
      "/Creator ()" + CRLF + ;
      "/Subject ()" + CRLF + ;
      "/Keywords ()" + CRLF + ;
      "/CreationDate (D:" + Str( Year( Date() ), 4 ) + PadL( Month( Date() ), 2, "0" ) + PadL( Day( Date() ), 2, "0" ) + SubStr( Time(), 1, 2 ) + SubStr( Time(), 4, 2 ) + SubStr( Time(), 7, 2 ) + ")" + CRLF + ;
      ">>" + CRLF + ;
      "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Write PDF Document Catalog Root object
   ++s_aReport[ REPORTOBJ ]
   AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
   cTemp := hb_ntos( s_aReport[ REPORTOBJ ] ) + " 0 obj" + CRLF + ;
      "<< /Type /Catalog /Pages 1 0 R /Outlines " + hb_ntos( s_aReport[ REPORTOBJ ] + 1 ) + " 0 R" + iif( ( nBookLen := Len( s_aReport[ BOOKMARK ] ) ) > 0, " /PageMode /UseOutlines", "" ) + " >>" + CRLF + "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   ++s_aReport[ REPORTOBJ ]
   nObj1 := s_aReport[ REPORTOBJ ]

   // Build bookmark outline object tree if bookmarks were added
   IF nBookLen > 0
      nRecno := 1
      nFirst := s_aReport[ REPORTOBJ ] + 1
      nLast := 0
      nCount := 0
      // Resolve tree links (parent, prev, next, first, last, count) for all outline items
      WHILE nRecno <= nBookLen
         nCurLevel := s_aReport[ BOOKMARK ][ nRecno ][ BOOKLEVEL ]
         s_aReport[ BOOKMARK ][ nRecno ][ BOOKPARENT ] := pdfBookParent( nRecno, nCurLevel, s_aReport[ REPORTOBJ ] )
         s_aReport[ BOOKMARK ][ nRecno ][ BOOKPREV ] := pdfBookPrev( nRecno, nCurLevel, s_aReport[ REPORTOBJ ] )
         s_aReport[ BOOKMARK ][ nRecno ][ BOOKNEXT ] := pdfBookNext( nRecno, nCurLevel, s_aReport[ REPORTOBJ ] )
         s_aReport[ BOOKMARK ][ nRecno ][ BOOKFIRST ] := pdfBookFirst( nRecno, nCurLevel, s_aReport[ REPORTOBJ ] )
         s_aReport[ BOOKMARK ][ nRecno ][ BOOKLAST ] := pdfBookLast( nRecno, nCurLevel, s_aReport[ REPORTOBJ ] )
         s_aReport[ BOOKMARK ][ nRecno ][ BOOKCOUNT ] := pdfBookCount( nRecno, nCurLevel )
         IF nCurLevel == 1
            nLast := nRecno
            ++nCount
         ENDIF
         ++nRecno
      ENDDO
      nLast += s_aReport[ REPORTOBJ ]
      cTemp := hb_ntos( s_aReport[ REPORTOBJ ] ) + " 0 obj" + CRLF + "<< /Type /Outlines /Count " + hb_ntos( nCount ) + " /First " + hb_ntos( nFirst ) + " 0 R /Last " + hb_ntos( nLast ) + " 0 R >>" + CRLF + "endobj"
      AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
      s_aReport[ DOCLEN ] += Len( cTemp )
      FWrite( s_aReport[ HANDLE ], cTemp )
      ++s_aReport[ REPORTOBJ ]
      nRecno := 1
      // Output individual outline item objects
      FOR nI := 1 TO nBookLen
         cTemp := CRLF + hb_ntos( s_aReport[ REPORTOBJ ] + nI - 1 ) + " 0 obj" + CRLF + ;
            "<<" + CRLF + ;
            "/Parent " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKPARENT ] ) + " 0 R" + CRLF + ;
            "/Dest [" + hb_ntos( s_aReport[ PAGES ][ s_aReport[ BOOKMARK ][ nRecno ][ BOOKPAGE ] ] ) + " 0 R /XYZ 0 " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKCOORD ] ) + " 0]" + CRLF + ;
            "/Title (" + AllTrim( s_aReport[ BOOKMARK ][ nRecno ][ BOOKTITLE ] ) + ")" + CRLF + ;
            iif( s_aReport[ BOOKMARK ][ nRecno ][ BOOKPREV ] > 0, "/Prev " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKPREV ] ) + " 0 R" + CRLF, "" ) + ;
            iif( s_aReport[ BOOKMARK ][ nRecno ][ BOOKNEXT ] > 0, "/Next " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKNEXT ] ) + " 0 R" + CRLF, "" ) + ;
            iif( s_aReport[ BOOKMARK ][ nRecno ][ BOOKFIRST ] > 0, "/First " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKFIRST ] ) + " 0 R" + CRLF, "" ) + ;
            iif( s_aReport[ BOOKMARK ][ nRecno ][ BOOKLAST ] > 0, "/Last " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKLAST ] ) + " 0 R" + CRLF, "" ) + ;
            iif( s_aReport[ BOOKMARK ][ nRecno ][ BOOKCOUNT ] != 0, "/Count " + hb_ntos( s_aReport[ BOOKMARK ][ nRecno ][ BOOKCOUNT ] ) + CRLF, "" ) + ;
            ">>" + CRLF + "endobj" + CRLF
         AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] + 2 )
         s_aReport[ DOCLEN ] += Len( cTemp )
         FWrite( s_aReport[ HANDLE ], cTemp )
         ++nRecno
      NEXT
      pdfBookClose()
      s_aReport[ REPORTOBJ ] += nBookLen - 1
   ELSE
      cTemp := hb_ntos( s_aReport[ REPORTOBJ ] ) + " 0 obj" + CRLF + "<< /Type /Outlines /Count 0 >>" + CRLF + "endobj" + CRLF
      AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
      s_aReport[ DOCLEN ] += Len( cTemp )
      FWrite( s_aReport[ HANDLE ], cTemp )
   ENDIF

   // Construct cross-reference table (xref) and PDF trailer
   cTemp := CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   ++s_aReport[ REPORTOBJ ]
   cTemp += "xref" + CRLF + ;
      "0 " + hb_ntos( s_aReport[ REPORTOBJ ] ) + CRLF + ;
      PadL( s_aReport[ REFS ][ 1 ], 10, "0" ) + " 65535 f" + CRLF
   FOR nI := 2 TO Len( s_aReport[ REFS ] )
      cTemp += PadL( s_aReport[ REFS ][ nI ], 10, "0" ) + " 00000 n" + CRLF
   NEXT
   cTemp += "trailer << /Size " + hb_ntos( s_aReport[ REPORTOBJ ] ) + " /Root " + hb_ntos( nObj1 - 1 ) + " 0 R /Info " + hb_ntos( nObj1 - 2 ) + " 0 R >>" + CRLF + ;
      "startxref" + CRLF + ;
      hb_ntos( s_aReport[ DOCLEN ] ) + CRLF + ;
      "%%EOF" + CRLF
   FWrite( s_aReport[ HANDLE ], cTemp )

#if 0
   // Reserved block for stream optimization routines
   IF s_aReport[ OPTIMIZE ]
      pdfOptimize() coming !
   ENDIF

#endif

   // Close output file handle and reset report environment
   FClose( s_aReport[ HANDLE ] )
   s_aReport := NIL

RETURN NIL

/*
 * Function:    pdfClosePage
 * Purpose:     Flushes and writes the active page objects (Page, Resources, Stream, Fonts, Images) to file.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Writes data to file handle; resets s_aReport[ PAGEBUFFER ].
 */
STATIC FUNCTION pdfClosePage()

   LOCAL cTemp, cBuffer, nBuffer, nRead, nI, k, nImage, nFont, nImageHandle

   // Store file byte offset references for page dictionary
   AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
   AAdd( s_aReport[ PAGES ], s_aReport[ REPORTOBJ ] + 1 )

   // Emit PDF Page Object
   cTemp := ;
      hb_ntos( ++s_aReport[ REPORTOBJ ] ) + " 0 obj" + CRLF + ;
      "<<" + CRLF + ;
      "/Type /Page /Parent 1 0 R" + CRLF + ;
      "/Resources " + hb_ntos( ++s_aReport[ REPORTOBJ ] ) + " 0 R" + CRLF + ;
      "/MediaBox [ 0 0 " + LTrim( Transform( s_aReport[ PAGEX ], "9999.99" ) ) + " " + ;
      LTrim( Transform( s_aReport[ PAGEY ], "9999.99" ) ) + " ]" + CRLF + ;
      "/Contents " + hb_ntos( ++s_aReport[ REPORTOBJ ] ) + " 0 R" + CRLF + ;
      ">>" + CRLF + ;
      "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Emit PDF Resources Dictionary object
   AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
   cTemp := ;
      hb_ntos( s_aReport[ REPORTOBJ ] - 1 ) + " 0 obj" + CRLF + ;
      "<<" + CRLF + ;
      "/ColorSpace << /DeviceRGB /DeviceGray >>" + CRLF + ;
      "/ProcSet [ /PDF /Text /ImageB /ImageC ]"

   // Add font resource mappings
   IF Len( s_aReport[ PAGEFONTS ] ) > 0
      cTemp += CRLF + ;
         "/Font" + CRLF + ;
         "<<"
      FOR nI := 1 TO Len( s_aReport[ PAGEFONTS ] )
         nFont := AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ PAGEFONTS ][ nI ] } )
         cTemp += CRLF + "/Fo" + hb_ntos( nFont ) + " " + hb_ntos( s_aReport[ FONTS ][ nFont ][ 2 ] ) + " 0 R"
      NEXT
      cTemp += CRLF + ">>"
   ENDIF

   // Add image XObject resource mappings
   IF Len( s_aReport[ PAGEIMAGES ] ) > 0
      cTemp += CRLF + "/XObject" + CRLF + "<<"
      FOR nI := 1 TO Len( s_aReport[ PAGEIMAGES ] )
         nImage := AScan( s_aReport[ IMAGES ], {| arr | arr[ 1 ] == s_aReport[ PAGEIMAGES ][ nI ][ 1 ] } )
         IF nImage == 0
            AAdd( s_aReport[ IMAGES ], { s_aReport[ PAGEIMAGES ][ nI ][ 1 ], ++s_aReport[ NEXTOBJ ], pdfImageInfo( s_aReport[ PAGEIMAGES ][ nI ][ 1 ] ) } )
            nImage := Len( s_aReport[ IMAGES ] )
         ENDIF
         cTemp += CRLF + "/Image" + hb_ntos( nImage ) + " " + hb_ntos( s_aReport[ IMAGES ][ nImage ][ 2 ] ) + " 0 R"
      NEXT
      cTemp += CRLF + ">>"
   ENDIF

   cTemp += CRLF + ">>" + CRLF + "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Write Content Stream Header object
   AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
   cTemp := hb_ntos( s_aReport[ REPORTOBJ ] ) + " 0 obj << /Length " + ;
      hb_ntos( s_aReport[ REPORTOBJ ] + 1 ) + " 0 R >>" + CRLF + ;
      "stream"
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Prepend image placement stream operators to the page buffer
   IF Len( s_aReport[ PAGEIMAGES ] ) > 0
      cTemp := ""
      FOR nI := 1 TO Len( s_aReport[ PAGEIMAGES ] )
         cTemp += CRLF + "q"
         nImage := AScan( s_aReport[ IMAGES ], {| arr | arr[ 1 ] == s_aReport[ PAGEIMAGES ][ nI ][ 1 ] } )
         cTemp += CRLF + hb_ntos( iif( s_aReport[ PAGEIMAGES ][ nI ][ 5 ] == 0, pdfM2X( s_aReport[ IMAGES ][ nImage ][ 3 ][ IMAGE_WIDTH ] / s_aReport[ IMAGES ][ nImage ][ 3 ][ IMAGE_XRES ] * 25.4 ), s_aReport[ PAGEIMAGES ][ nI ][ 5 ] ) ) + ;
            " 0 0 " + ;
            hb_ntos( iif( s_aReport[ PAGEIMAGES ][ nI ][ 4 ] == 0, pdfM2X( s_aReport[ IMAGES ][ nImage ][ 3 ][ IMAGE_HEIGHT ] / s_aReport[ IMAGES ][ nImage ][ 3 ][ IMAGE_YRES ] * 25.4 ), s_aReport[ PAGEIMAGES ][ nI ][ 4 ] ) ) + ;
            " " + hb_ntos( s_aReport[ PAGEIMAGES ][ nI ][ 3 ] ) + ;
            " " + hb_ntos( s_aReport[ PAGEY ] - s_aReport[ PAGEIMAGES ][ nI ][ 2 ] - ;
            iif( s_aReport[ PAGEIMAGES ][ nI ][ 4 ] == 0, pdfM2X( s_aReport[ IMAGES ][ nImage ][ 3 ][ IMAGE_HEIGHT ] / s_aReport[ IMAGES ][ nImage ][ 3 ][ IMAGE_YRES ] * 25.4 ), s_aReport[ PAGEIMAGES ][ nI ][ 4 ] ) ) + " cm"
         cTemp += CRLF + "/Image" + hb_ntos( nImage ) + " Do"
         cTemp += CRLF + "Q"
      NEXT
      s_aReport[ PAGEBUFFER ] := cTemp + s_aReport[ PAGEBUFFER ]
   ENDIF

   // Write Content Stream Body and closing tags
   cTemp := s_aReport[ PAGEBUFFER ]
   cTemp += CRLF + "endstream" + CRLF + ;
      "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Write Content Stream Length object
   AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
   cTemp := hb_ntos( ++s_aReport[ REPORTOBJ ] ) + " 0 obj" + CRLF + ;
      hb_ntos( Len( s_aReport[ PAGEBUFFER ] ) ) + CRLF + ;
      "endobj" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

   // Emit Type1 Font objects referenced on this page
   FOR nI := 1 TO Len( s_aReport[ FONTS ] )
      IF s_aReport[ FONTS ][ nI ][ 2 ] > s_aReport[ REPORTOBJ ]
         AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
         cTemp := ;
            hb_ntos( s_aReport[ FONTS ][ nI ][ 2 ] ) + " 0 obj" + CRLF + ;
            "<<" + CRLF + ;
            "/Type /Font" + CRLF + ;
            "/Subtype /Type1" + CRLF + ;
            "/Name /Fo" + hb_ntos( nI ) + CRLF + ;
            "/BaseFont /" + s_aReport[ TYPE1 ][ s_aReport[ FONTS ][ nI ][ 1 ] ] + CRLF + ;
            "/Encoding /WinAnsiEncoding" + CRLF + ;
            ">>" + CRLF + ;
            "endobj" + CRLF
         s_aReport[ DOCLEN ] += Len( cTemp )
         FWrite( s_aReport[ HANDLE ], cTemp )
      ENDIF
   NEXT

   // Emit Image XObjects and stream binary data
   FOR nI := 1 TO Len( s_aReport[ IMAGES ] )
      IF s_aReport[ IMAGES ][ nI ][ 2 ] > s_aReport[ REPORTOBJ ]
         AAdd( s_aReport[ REFS ], s_aReport[ DOCLEN ] )
         cTemp := ;
            hb_ntos( s_aReport[ IMAGES ][ nI ][ 2 ] ) + " 0 obj" + CRLF + ;
            "<<" + CRLF + ;
            "/Type /XObject" + CRLF + ;
            "/Subtype /Image" + CRLF + ;
            "/Name /Image" + hb_ntos( nI ) + CRLF + ;
            "/Filter [" + iif( At( ".jpg", Lower( s_aReport[ IMAGES ][ nI ][ 1 ] ) ) > 0, " /DCTDecode", "" ) + " ]" + CRLF + ;
            "/Width " + hb_ntos( s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_WIDTH ] ) + CRLF + ;
            "/Height " + hb_ntos( s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_HEIGHT ] ) + CRLF + ;
            "/BitsPerComponent " + hb_ntos( s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_BITS ] ) + CRLF + ;
            "/ColorSpace /" + iif( s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_SPACE ] == 1, "DeviceGray", "DeviceRGB" ) + CRLF + ;
            "/Length " + hb_ntos( s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_LENGTH ] ) + CRLF + ;
            ">>" + CRLF + ;
            "stream" + CRLF
         s_aReport[ DOCLEN ] += Len( cTemp )
         FWrite( s_aReport[ HANDLE ], cTemp )
         // Read image data from disk in chunks and copy to PDF stream
         nImageHandle := FOpen( s_aReport[ IMAGES ][ nI ][ 1 ] )
         FSeek( nImageHandle, s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_FROM ] )
         nBuffer := 8192
         cBuffer := Space( nBuffer )
         k := 0
         WHILE k < s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_LENGTH ]
            IF k + nBuffer <= s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_LENGTH ]
               nRead := nBuffer
            ELSE
               nRead := s_aReport[ IMAGES ][ nI ][ 3 ][ IMAGE_LENGTH ] - k
            ENDIF
            FRead( nImageHandle, @cBuffer, nRead )
            s_aReport[ DOCLEN ] += nRead
            FWrite( s_aReport[ HANDLE ], cBuffer, nRead )
            k += nRead
         ENDDO
         FClose( nImageHandle )
         cTemp := CRLF + "endstream" + CRLF + ;
            "endobj" + CRLF
         s_aReport[ DOCLEN ] += Len( cTemp )
         FWrite( s_aReport[ HANDLE ], cTemp )
      ENDIF
   NEXT

   // Reset tracking state for next page
   s_aReport[ REPORTOBJ ] := s_aReport[ NEXTOBJ ]
   s_aReport[ NEXTOBJ ] := s_aReport[ REPORTOBJ ] + 4
   s_aReport[ PAGEBUFFER ] := ""

RETURN NIL

/*
 * Function:    pdfGetFontInfo
 * Purpose:     Queries font family name or style index offset of active font.
 * Parameters:  cParam (Character) - Query selector ("NAME" or "TYPE").
 * Returns:     String or Numeric - Font family name ("Times", "Helvetica", "Courier")
 *              or style index offset (0..3).
 * Side Effects: None
 */
STATIC FUNCTION pdfGetFontInfo( cParam )

   LOCAL cRet
   IF cParam == "NAME"
      IF Left( s_aReport[ TYPE1 ][ s_aReport[ FONTNAME ] ], 5 ) == "Times"
         cRet := "Times"
      ELSEIF Left( s_aReport[ TYPE1 ][ s_aReport[ FONTNAME ] ], 9 ) == "Helvetica"
         cRet := "Helvetica"
      ELSE
         cRet := "Courier"
      ENDIF
   ELSE // Style index calculation
      cRet := Int( ( s_aReport[ FONTNAME ] - 1 ) % 4 )
   ENDIF

RETURN cRet

/*
 * Function:    pdfImage
 * Purpose:     Adds an image reference (JPEG/TIFF) onto the current page.
 * Parameters:  cFile   (Character) - Image file path.
 *              nRow    (Numeric)   - Vertical position.
 *              nCol    (Numeric)   - Horizontal position.
 *              cUnits  (Character) - Positioning units ("R", "M", or "D").
 *              nHeight (Numeric)   - Image display height override.
 *              nWidth  (Numeric)   - Image display width override.
 *              cId     (Character) - Identifier if editing header.
 * Returns:     NIL
 * Side Effects: Appends image record to s_aReport[ PAGEIMAGES ].
 */
FUNCTION pdfImage( cFile, nRow, nCol, cUnits, nHeight, nWidth, cId )

   // Set default parameters
   __defaultNIL( @nRow, s_aReport[ REPORTLINE ] )
   __defaultNIL( @nCol, 0 )
   __defaultNIL( @nHeight, 0 )
   __defaultNIL( @nWidth, 0 )
   __defaultNIL( @cUnits, "R" )
   __defaultNIL( @cId, "" )

   // Redirect command if editing header template
   IF s_aReport[ HEADEREDIT ]
      RETURN pdfHeader( "PDFIMAGE", cId, { cFile, nRow, nCol, cUnits, nHeight, nWidth } )
   ENDIF

   // Convert unit coordinates to PDF page points based on unit type
   IF cUnits == "M"
      nRow := s_aReport[ PAGEY ] - pdfM2Y( nRow )
      nCol := pdfM2X( nCol )
      nHeight := s_aReport[ PAGEY ] - pdfM2Y( nHeight )
      nWidth := pdfM2X( nWidth )
   ELSEIF cUnits == "R"
      nRow := s_aReport[ PAGEY ] - pdfR2D( nRow )
      nCol := pdfM2X( s_aReport[ PDFLEFT ] ) + ;
         nCol * 100.00 / s_aReport[ REPORTWIDTH ] * ;
         ( s_aReport[ PAGEX ] - pdfM2X( s_aReport[ PDFLEFT ] ) * 2 - 9.0 ) / 100.00
      nHeight := s_aReport[ PAGEY ] - pdfR2D( nHeight )
      nWidth := pdfM2X( s_aReport[ PDFLEFT ] ) + ;
         nWidth * 100.00 / s_aReport[ REPORTWIDTH ] * ;
         ( s_aReport[ PAGEX ] - pdfM2X( s_aReport[ PDFLEFT ] ) * 2 - 9.0 ) / 100.00
   ELSEIF cUnits == "D"
   ENDIF

   // Register image reference on current page
   AAdd( s_aReport[ PAGEIMAGES ], { cFile, nRow, nCol, nHeight, nWidth } )

RETURN NIL

/*
 * Function:    pdfItalic
 * Purpose:     Selects the Italic style variant of the active font family.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Updates FONTNAME, PAGEFONTS, and FONTS in s_aReport.
 */
FUNCTION pdfItalic()
   // Map italic font variant index based on active font family name
   IF pdfGetFontInfo( "NAME" ) == "Times"
      s_aReport[ FONTNAME ] := 3
   ELSEIF pdfGetFontInfo( "NAME" ) == "Helvetica"
      s_aReport[ FONTNAME ] := 7
   ELSE
      s_aReport[ FONTNAME ] := 11
   ENDIF
   AAdd( s_aReport[ PAGEFONTS ], s_aReport[ FONTNAME ] )
   IF AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ FONTNAME ] } ) == 0
      AAdd( s_aReport[ FONTS ], { s_aReport[ FONTNAME ], ++s_aReport[ NEXTOBJ ] } )
   ENDIF

RETURN NIL

/*
 * Function:    pdfLen
 * Purpose:     Calculates physical rendered text length in millimeters using metric tables.
 * Parameters:  cString (Character) - String to measure.
 * Returns:     Numeric - String width in millimeters.
 * Side Effects: None
 */
FUNCTION pdfLen( cString )

   LOCAL nWidth := 0.00, nI, nLen, nArr, nAdd := ( s_aReport[ FONTNAME ] - 1 ) % 4
   nLen := Len( cString )
   // Exclude trailing attribute control bytes if present
   IF Right( cString, 1 ) == Chr( 255 ) .OR. Right( cString, 1 ) == Chr( 254 ) // Reverse video or underline
      --nLen
   ENDIF
   IF pdfGetFontInfo( "NAME" ) == "Times"
      nArr := 1
   ELSEIF pdfGetFontInfo( "NAME" ) == "Helvetica"
      nArr := 2
   ELSE
      nArr := 3
   ENDIF
   // Accumulate character widths from loaded metric table
   IF ! Empty( s_aReport[ FONTWIDTH ] )
      FOR nI := 1 TO nLen
         nWidth += s_aReport[ FONTWIDTH ][ nArr ][ ( Asc( SubStr( cString, nI, 1 ) ) - 32 ) * 4 + 1 + nAdd ] * 25.4 * s_aReport[ FONTSIZE ] / 720.00 / 100.00
      NEXT
   ENDIF

RETURN nWidth

/*
 * Function:    pdfM2R
 * Purpose:     Converts millimeters to equivalent row count based on LPI settings.
 * Parameters:  mm (Numeric) - Value in millimeters.
 * Returns:     Numeric - Equivalent row count.
 * Side Effects: None
 */
STATIC FUNCTION pdfM2R( mm )
RETURN Int( s_aReport[ LPI ] * mm / 25.4 )

/*
 * Function:    pdfM2X
 * Purpose:     Converts millimeters to PDF points (1/72 inch).
 * Parameters:  n (Numeric) - Value in millimeters.
 * Returns:     Numeric - Equivalent points.
 * Side Effects: None
 */
STATIC FUNCTION pdfM2X( n )
RETURN n * 72 / 25.4

/*
 * Function:    pdfM2Y
 * Purpose:     Converts vertical millimeter position to PDF page Y coordinate (points from page bottom).
 * Parameters:  n (Numeric) - Value in millimeters from page top.
 * Returns:     Numeric - Y coordinate in PDF points.
 * Side Effects: None
 */
STATIC FUNCTION pdfM2Y( n )
RETURN s_aReport[ PAGEY ] - n * 72 / 25.4

/*
 * Function:    pdfNewLine
 * Purpose:     Advances current vertical line position, performing page break if needed.
 * Parameters:  n (Numeric) - Number of lines to advance (defaults to 1).
 * Returns:     Numeric - Updated current report line position.
 * Side Effects: May trigger pdfNewPage(); updates s_aReport[ REPORTLINE ].
 */
FUNCTION pdfNewLine( n )
   __defaultNIL( @n, 1 )
   IF s_aReport[ REPORTLINE ] + n + s_aReport[ PDFTOP ] > s_aReport[ PDFBOTTOM ]
      pdfNewPage()
      s_aReport[ REPORTLINE ] += 1
   ELSE
      s_aReport[ REPORTLINE ] += n
   ENDIF

RETURN s_aReport[ REPORTLINE ]

/*
 * Function:    pdfNewPage
 * Purpose:     Instantiates a new page in the document stream with specified or default geometry/font settings.
 * Parameters:  _cPageSize   (Character) - Paper size (e.g. "LETTER", "A4").
 *              _cPageOrient (Character) - Orientation ("P"=Portrait, "L"=Landscape).
 *              _nLpi        (Numeric)   - Lines per inch setting.
 *              _cFontName   (Character) - Active font family name.
 *              _nFontType   (Numeric)   - Font style index.
 *              _nFontSize   (Numeric)   - Font point size.
 * Returns:     NIL
 * Side Effects: Flushes previous page buffer; increments REPORTPAGE; resets PAGEFONTS/PAGEIMAGES.
 */
FUNCTION pdfNewPage( _cPageSize, _cPageOrient, _nLpi, _cFontName, _nFontType, _nFontSize )
   __defaultNIL( @_cPageSize, s_aReport[ PAGESIZE ] )
   __defaultNIL( @_cPageOrient, s_aReport[ PAGEORIENT ] )
   __defaultNIL( @_nLpi, s_aReport[ LPI ] )
   __defaultNIL( @_cFontName, pdfGetFontInfo( "NAME" ) )
   __defaultNIL( @_nFontType, pdfGetFontInfo( "TYPE" ) )
   __defaultNIL( @_nFontSize, s_aReport[ FONTSIZE ] )

   // Close and write previous page object if content exists
   IF ! Empty( s_aReport[ PAGEBUFFER ] )
      pdfClosePage()
   ENDIF

   s_aReport[ PAGEFONTS ] := {}
   s_aReport[ PAGEIMAGES ] := {}
   ++s_aReport[ REPORTPAGE ]
   pdfPageSize( _cPageSize )
   pdfPageOrient( _cPageOrient )
   pdfSetLPI( _nLpi )
   pdfSetFont( _cFontName, _nFontType, _nFontSize )
   pdfDrawHeader()
   s_aReport[ REPORTLINE ] := 0
   s_aReport[ FONTNAMEPREV ] := 0
   s_aReport[ FONTSIZEPREV ] := 0

RETURN NIL

/*
 * Function:    pdfNormal
 * Purpose:     Selects the Normal (Regular) style variant of the active font family.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Updates FONTNAME, PAGEFONTS, and FONTS in s_aReport.
 */
FUNCTION pdfNormal()
   // Map normal font variant index based on active font family name
   IF pdfGetFontInfo( "NAME" ) == "Times"
      s_aReport[ FONTNAME ] := 1
   ELSEIF pdfGetFontInfo( "NAME" ) == "Helvetica"
      s_aReport[ FONTNAME ] := 5
   ELSE
      s_aReport[ FONTNAME ] := 9
   ENDIF
   AAdd( s_aReport[ PAGEFONTS ], s_aReport[ FONTNAME ] )
   IF AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ FONTNAME ] } ) == 0
      AAdd( s_aReport[ FONTS ], { s_aReport[ FONTNAME ], ++s_aReport[ NEXTOBJ ] } )
   ENDIF

RETURN NIL

/*
 * Function:    pdfOpen
 * Purpose:     Creates a new PDF output file and initializes the document environment and metric tables.
 * Parameters:  cFile     (Character) - Target PDF file path to create.
 *              nLen      (Numeric)   - Virtual column grid width (default 200).
 *              lOptimize (Logical)   - Enable output stream optimization.
 * Returns:     NIL
 * Side Effects: Creates physical file on disk; initializes s_aReport structure elements.
 */
FUNCTION pdfOpen( cFile, nLen, lOptimize )

   LOCAL cTemp, nI, nJ, n1, n2 := 896, n12

   // Apply default parameter settings
   __defaultNIL( @nLen, 200 )
   __defaultNIL( @lOptimize, .F. )

   // Initialize report state variables
   s_aReport[ FONTNAME ] := 1
   s_aReport[ FONTSIZE ] := 10
   s_aReport[ LPI ] := 6
   s_aReport[ PAGESIZE ] := "LETTER"
   s_aReport[ PAGEORIENT ] := "P"
   s_aReport[ PAGEX ] := 8.5 * 72
   s_aReport[ PAGEY ] := 11.0 * 72
   s_aReport[ REPORTWIDTH ] := nLen
   s_aReport[ REPORTPAGE ] := 0
   s_aReport[ REPORTLINE ] := 0
   s_aReport[ FONTNAMEPREV ] := 0
   s_aReport[ FONTSIZEPREV ] := 0
   s_aReport[ PAGEBUFFER ] := ""
   s_aReport[ REPORTOBJ ] := 1
   s_aReport[ DOCLEN ] := 0
   s_aReport[ TYPE1 ] := { "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic", "Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique", "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique" }
   s_aReport[ MARGINS ] := .T.
   s_aReport[ HEADEREDIT ] := .F.
   s_aReport[ NEXTOBJ ] := 0
   s_aReport[ PDFTOP ] := 1
   s_aReport[ PDFLEFT ] := 10
   s_aReport[ PDFBOTTOM ] := s_aReport[ PAGEY ] / 72 * s_aReport[ LPI ] - 1
   s_aReport[ HANDLE ] := FCreate( cFile )
   s_aReport[ PAGES ] := {}
   s_aReport[ REFS ] := { 0, 0 }
   s_aReport[ BOOKMARK ] := {}
   s_aReport[ HEADER ] := {}
   s_aReport[ FONTS ] := {}
   s_aReport[ IMAGES ] := {}
   s_aReport[ PAGEIMAGES ] := {}
   s_aReport[ PAGEFONTS ] := {}

   // Unpack binary font character width metric tables
   cTemp := vpdf_FontsDat()
   n1 := Len( cTemp ) / ( 2 * n2 )
   s_aReport[ FONTWIDTH ] := Array( n1, n2 )
   s_aReport[ OPTIMIZE ] := lOptimize
   s_aReport[ NEXTOBJ ] := s_aReport[ REPORTOBJ ] + 4
   n12 := 2 * n2
   FOR nI := 1 TO n1
      FOR nJ := 1 TO n2
         s_aReport[ FONTWIDTH ][ nI ][ nJ ] := Bin2I( SubStr( cTemp, ( nI - 1 ) * n12 + ( nJ - 1 ) * 2 + 1, 2 ) )
      NEXT
   NEXT

   // Write PDF magic header string to file handle
   s_aReport[ DOCLEN ] := 0
   cTemp := "%PDF-1.3" + CRLF
   s_aReport[ DOCLEN ] += Len( cTemp )
   FWrite( s_aReport[ HANDLE ], cTemp )

RETURN NIL

/*
 * Function:    pdfPageSize
 * Purpose:     Sets page dimensions based on standard paper names or explicit width/height dimensions.
 * Parameters:  _cPageSize (Character) - Paper size name (e.g., "LETTER", "A4", "LEGAL").
 *              _nWidth    (Numeric)   - Custom width dimension.
 *              _nHeight   (Numeric)   - Custom height dimension.
 * Returns:     NIL
 * Side Effects: Updates PAGESIZE, PAGEX, and PAGEY elements in s_aReport.
 */
FUNCTION pdfPageSize( _cPageSize, _nWidth, _nHeight )

   LOCAL nSize, aSize, nWidth, nHeight

   // Standard paper dimension table (Name, Width Inches, Height Inches)
   aSize := { ;
      { "LETTER", 8.50, 11.00 }, ;
      { "LEGAL", 8.50, 14.00 }, ;
      { "LEDGER", 11.00, 17.00 }, ;
      { "EXECUTIVE", 7.25, 10.50 }, ;
      { "A4", 8.27, 11.69 }, ;
      { "A3", 11.69, 16.54 }, ;
      { "JIS B4", 10.12, 14.33 }, ;
      { "JIS B5", 7.16, 10.12 }, ;
      { "JPOST", 3.94, 5.83 }, ;
      { "JPOSTD", 5.83, 7.87 }, ;
      { "COM10", 4.12, 9.50 }, ;
      { "MONARCH", 3.87, 7.50 }, ;
      { "C5", 6.38, 9.01 }, ;
      { "DL", 4.33, 8.66 }, ;
      { "B5", 6.93, 9.84 }, ;
      { "USSTDFOLD", 14.87, 11.00 } }

   __defaultNIL( @_cPageSize, "LETTER" )

   // Match paper standard name or locate closest match by custom dimensions
   IF Empty( _nWidth ) .OR. Empty( _nHeight )
      nSize := AScan( aSize, {| arr | arr[ 1 ] == _cPageSize } )
      IF nSize == 0
         nSize := 1
      ENDIF
      s_aReport[ PAGESIZE ] := aSize[ nSize ][ 1 ]
      nWidth := aSize[ nSize ][ 2 ]
      nHeight := aSize[ nSize ][ 3 ]
   ELSE
      _nWidth := Val( Str( _nWidth ) )
      _nHeight := Val( Str( _nHeight ) )
      nSize := AScan( aSize, {| arr | ( arr[ 2 ] == _nWidth ) .AND. ( arr[ 3 ] == _nHeight ) } )
      IF nSize == 0
         nSize := AScan( aSize, {| arr | ( arr[ 3 ] == _nWidth ) .AND. ( arr[ 2 ] == _nHeight ) } )
      ENDIF
      IF nSize == 0
         nSize := 1
      ENDIF
      s_aReport[ PAGESIZE ] := aSize[ nSize ][ 1 ]
      nWidth := _nWidth
      nHeight := _nHeight
   ENDIF

   // Calculate page boundary points based on orientation
   IF s_aReport[ PAGEORIENT ] == "P"
      s_aReport[ PAGEX ] := nWidth * 72
      s_aReport[ PAGEY ] := nHeight * 72
   ELSE
      s_aReport[ PAGEX ] := nHeight * 72
      s_aReport[ PAGEY ] := nWidth * 72
   ENDIF

RETURN NIL

/*
 * Function:    pdfPageOrient
 * Purpose:     Sets page orientation ("P" for Portrait, "L" for Landscape).
 * Parameters:  _cPageOrient (Character) - Orientation code ("P" or "L").
 * Returns:     NIL
 * Side Effects: Updates PAGEORIENT in s_aReport and recalculates page size.
 */
FUNCTION pdfPageOrient( _cPageOrient )
   __defaultNIL( @_cPageOrient, "P" )
   s_aReport[ PAGEORIENT ] := _cPageOrient
   pdfPageSize( s_aReport[ PAGESIZE ] )

RETURN NIL

/*
 * Function:    pdfR2D
 * Purpose:     Converts row number to PDF Y coordinate points.
 * Parameters:  nRow (Numeric) - Row number.
 * Returns:     Numeric - Y coordinate position in PDF points.
 * Side Effects: None
 */
STATIC FUNCTION pdfR2D( nRow )
RETURN s_aReport[ PAGEY ] - nRow * 72 / s_aReport[ LPI ]

/*
 * Function:    pdfR2M
 * Purpose:     Converts row number to millimeter position.
 * Parameters:  nRow (Numeric) - Row number.
 * Returns:     Numeric - Millimeter position.
 * Side Effects: None
 */
STATIC FUNCTION pdfR2M( nRow )
RETURN 25.4 * nRow / s_aReport[ LPI ]

/*
 * Function:    pdfPageNumber
 * Purpose:     Gets or sets current document page number counter.
 * Parameters:  n (Numeric) - Page number to set (optional).
 * Returns:     Numeric - Active page number count.
 * Side Effects: May update REPORTPAGE element in s_aReport if n > 0.
 */
FUNCTION pdfPageNumber( n )
   __defaultNIL( @n, 0 )
   IF n > 0
      s_aReport[ REPORTPAGE ] := n
   ENDIF

RETURN s_aReport[ REPORTPAGE ]

/*
 * Function:    pdfReverse
 * Purpose:     Appends reverse video formatting control character to a string.
 * Parameters:  cString (Character) - Base string.
 * Returns:     Character - String with appended Chr(255) control character.
 * Side Effects: None
 */
FUNCTION pdfReverse( cString )
RETURN cString + Chr( 255 )

/*
 * Function:    pdfRJust
 * Purpose:     Displays text right-justified at a specified target column.
 * Parameters:  cString (Character) - Text string to render.
 *              nRow    (Numeric)   - Row position.
 *              nCol    (Numeric)   - Target column for right boundary alignment.
 *              cUnits  (Character) - Units identifier ("R"=Rows, "M"=Millimeters).
 *              lExact  (Logical)   - If .T., suppresses auto line height check.
 *              cId     (Character) - Header identifier if in header editing mode.
 * Returns:     NIL
 * Side Effects: Calls pdfAtSay to output string; updates current line position.
 */
FUNCTION pdfRJust( cString, nRow, nCol, cUnits, lExact, cId )

   LOCAL nLen, nAdj := 1.0, nAt

   // Apply defaults to parameters
   __defaultNIL( @nRow, s_aReport[ REPORTLINE ] )
   __defaultNIL( @cUnits, "R" )
   __defaultNIL( @lExact, .F. )

   // Intercept call if editing header template
   IF s_aReport[ HEADEREDIT ]
      RETURN pdfHeader( "PDFRJUST", cId, { cString, nRow, nCol, cUnits, lExact } )
   ENDIF

   // Substitute page number macro tag if present
   IF ( nAt := At( "#pagenumber#", cString ) ) > 0
      cString := Left( cString, nAt - 1 ) + hb_ntos( pdfPageNumber() ) + SubStr( cString, nAt + 12 )
   ENDIF

   // Calculate rendered string width
   nLen := pdfLen( cString )

   IF cUnits == "R"
      IF ! lExact
         pdfCheckLine( nRow )
         nRow := nRow + s_aReport[ PDFTOP ]
      ENDIF
   ENDIF

   // Render text using offset column calculated for right alignment
   pdfAtSay( cString, pdfR2M( nRow ), iif( cUnits == "R", s_aReport[ PDFLEFT ] + ( s_aReport[ PAGEX ] / 72 * 25.4 - 2 * s_aReport[ PDFLEFT ] ) * nCol / s_aReport[ REPORTWIDTH ] - nAdj, nCol ) - nLen, "M", lExact )

RETURN NIL

/*
 * Function:    pdfSetFont
 * Purpose:     Sets the active font family, style variant, and point size.
 * Parameters:  _cFont (Character) - Font family name ("Times", "Helvetica", "Courier").
 *              _nType (Numeric)   - Style variant index (0=Normal, 1=Bold, 2=Italic, 3=BoldItalic).
 *              _nSize (Numeric)   - Font point size (default 10).
 *              cId    (Character) - Identifier if editing header.
 * Returns:     NIL
 * Side Effects: Updates FONTSIZE, FONTNAME, PAGEFONTS, and FONTS in s_aReport.
 */
FUNCTION pdfSetFont( _cFont, _nType, _nSize, cId )

   __defaultNIL( @_cFont, "Times" )
   __defaultNIL( @_nType, 0 )
   __defaultNIL( @_nSize, 10 )

   // Intercept call if editing header template
   IF s_aReport[ HEADEREDIT ]
      RETURN pdfHeader( "PDFSETFONT", cId, { _cFont, _nType, _nSize } )
   ENDIF

   _cFont := Upper( _cFont )
   s_aReport[ FONTSIZE ] := _nSize

   // Calculate font index in Type1 font array
   IF _cFont == "TIMES"
      s_aReport[ FONTNAME ] := _nType + 1
   ELSEIF _cFont == "HELVETICA"
      s_aReport[ FONTNAME ] := _nType + 5
   ELSE
      s_aReport[ FONTNAME ] := _nType + 9
   ENDIF

   AAdd( s_aReport[ PAGEFONTS ], s_aReport[ FONTNAME ] )
   IF AScan( s_aReport[ FONTS ], {| arr | arr[ 1 ] == s_aReport[ FONTNAME ] } ) == 0
      AAdd( s_aReport[ FONTS ], { s_aReport[ FONTNAME ], ++s_aReport[ NEXTOBJ ] } )
   ENDIF

RETURN NIL

/*
 * Function:    pdfSetLPI
 * Purpose:     Sets document lines-per-inch (LPI) vertical pitch density.
 * Parameters:  _nLpi (Numeric) - LPI value (1, 2, 3, 4, 6, 8, 12, 16, 24, 48).
 * Returns:     NIL
 * Side Effects: Updates LPI in s_aReport and recalculates page bounds.
 */
FUNCTION pdfSetLPI( _nLpi )

   LOCAL cLpi := hb_ntos( _nLpi )

   __defaultNIL( @_nLpi, 6 )

   cLpi := iif( cLpi $ "1;2;3;4;6;8;12;16;24;48", cLpi, "6" )
   s_aReport[ LPI ] := Val( cLpi )
   pdfPageSize( s_aReport[ PAGESIZE ] )

RETURN NIL

/*
 * Function:    pdfStringB
 * Purpose:     Escapes reserved PDF syntax characters (parentheses) in strings.
 * Parameters:  cString (Character) - Raw input string.
 * Returns:     Character - String with escaped parentheses.
 * Side Effects: None
 */
FUNCTION pdfStringB( cString )
   cString := StrTran( cString, "(", "\(" )
   cString := StrTran( cString, ")", "\)" )

RETURN cString

/*
 * Function:    pdfTextCount
 * Purpose:     Calculates line count required to display formatted paragraph text without outputting it.
 * Parameters:  cString  (Character) - Text string.
 *              nTop     (Numeric)   - Top position.
 *              nLeft    (Numeric)   - Left position.
 *              nLength  (Numeric)   - Line width limit.
 *              nTab     (Numeric)   - First line indent spaces count.
 *              nJustify (Numeric)   - Justification mode (1=Left, 2=Center, 3=Right, 4=Full).
 *              cUnits   (Character) - Units identifier ("R" or "M").
 * Returns:     Numeric - Total line count required for text block.
 * Side Effects: None
 */
FUNCTION pdfTextCount( cString, nTop, nLeft, nLength, nTab, nJustify, cUnits )
RETURN pdfText( cString, nTop, nLeft, nLength, nTab, nJustify, cUnits, .F. )

/*
 * Function:    pdfText
 * Purpose:     Formats and renders a multi-line paragraph block with optional word wrap and justification.
 * Parameters:  cString  (Character) - Text content to format and render.
 *              nTop     (Numeric)   - Starting top line/coordinate.
 *              nLeft    (Numeric)   - Left column/coordinate.
 *              nLength  (Numeric)   - Maximum line length width.
 *              nTab     (Numeric)   - First line paragraph indent tab count (-1 = no indent).
 *              nJustify (Numeric)   - Alignment (1=Left, 2=Center, 3=Right, 4=Full; default 4).
 *              cUnits   (Character) - Positioning units ("R"=Rows, "M"=Millimeters).
 *              cColor   (Character) - RGB color prefix string.
 *              lPrint   (Logical)   - Output flag (.T. = print text, .F. = measure only).
 * Returns:     Numeric - Number of rendered output lines.
 * Side Effects: Appends formatted text streams to s_aReport[ PAGEBUFFER ] if lPrint is .T.
 */
FUNCTION pdfText( cString, nTop, nLeft, nLength, nTab, nJustify, cUnits, cColor, lPrint )

   LOCAL cDelim := Chr( 0 ) + Chr( 9 ) + Chr( 10 ) + Chr( 13 ) + Chr( 26 ) + Chr( 32 ) + Chr( 138 ) + Chr( 141 )
   LOCAL nI, cTemp, cToken, k, nL, nRow, nLines, nLineLen, nStart
   LOCAL lParagraph, nSpace, nNew, nTokenLen, nCRLF, nTokens, nLen

   // Apply parameter defaults
   __defaultNIL( @nTab, - 1 )
   __defaultNIL( @cUnits, "R" )
   __defaultNIL( @nJustify, 4 ) // Default to full justification
   __defaultNIL( @lPrint, .T. )
   __defaultNIL( @cColor, "" )

   // Convert vertical/horizontal offsets based on units
   IF cUnits == "M"
      nTop := pdfM2R( nTop )
   ELSEIF cUnits == "R"
      nLeft := pdfX2M( pdfM2X( s_aReport[ PDFLEFT ] ) + ;
         nLeft * 100.00 / s_aReport[ REPORTWIDTH ] * ;
         ( s_aReport[ PAGEX ] - pdfM2X( s_aReport[ PDFLEFT ] ) * 2 - 9.0 ) / 100.00 )
   ENDIF

   s_aReport[ REPORTLINE ] := nTop - 1
   nSpace := pdfLen( " " )
   nLines := 0
   nCRLF := 0
   nNew := nTab
   cString := AllTrim( cString )
   nTokens := NumToken( cString, cDelim )
   nStart := 1

   // Adjust starting horizontal position based on justification mode
   IF nJustify == 1 .OR. nJustify == 4
      nLeft := nLeft
   ELSEIF nJustify == 2
      nLeft := nLeft - nLength / 2
   ELSEIF nJustify == 3
      nLeft := nLeft - nLength
   ENDIF

   nLineLen := nSpace * nNew - nSpace
   lParagraph := .T.
   nI := 1

   // Tokenize string and wrap words into lines based on width limits
   WHILE nI <= nTokens
      cToken := Token( cString, cDelim, nI )
      nTokenLen := pdfLen( cToken )
      nLen := Len( cToken )

      IF nLineLen + nSpace + nTokenLen > nLength
         IF nStart == nI // Handle oversized single token exceeding line length limit
            k := 1
            WHILE k <= nLen
               cTemp := ""
               nLineLen := 0.00
               nL := nLeft
               IF lParagraph
                  nLineLen += nSpace * nNew
                  IF nJustify != 2
                     nL += nSpace * nNew
                  ENDIF
                  lParagraph := .F.
               ENDIF
               IF nJustify == 2
                  nL := nLeft + ( nLength - pdfLen( cTemp ) ) / 2
               ELSEIF nJustify == 3
                  nL := nLeft + nLength - pdfLen( cTemp )
               ENDIF
               WHILE k <= nLen .AND. ( ( nLineLen += pdfLen( SubStr( cToken, k, 1 ) ) ) <= nLength )
                  nLineLen += pdfLen( SubStr( cToken, k, 1 ) )
                  cTemp += SubStr( cToken, k, 1 )
                  ++k
               ENDDO
               IF Empty( cTemp )
                  cTemp := SubStr( cToken, k, 1 )
                  ++k
               ENDIF
               ++nLines
               IF lPrint
                  nRow := pdfNewLine( 1 )
                  pdfAtSay( cColor + cTemp, pdfR2M( nRow + s_aReport[ PDFTOP ] ), nL, "M" )
               ENDIF
            ENDDO
            ++nI
            nStart := nI
         ELSE
            pdfTextPrint( nI - 1, nLeft, @lParagraph, nJustify, nSpace, nNew, nLength, @nLineLen, @nLines, @nStart, cString, cDelim, cColor, lPrint )
         ENDIF
      ELSEIF ( nI == nTokens ) .OR. ( nI < nTokens .AND. ( nCRLF := pdfTextNextPara( cString, cDelim, nI ) ) > 0 )
         IF nI == nTokens
            nLineLen += nSpace + nTokenLen
         ENDIF
         pdfTextPrint( nI, nLeft, @lParagraph, nJustify, nSpace, nNew, nLength, @nLineLen, @nLines, @nStart, cString, cDelim, cColor, lPrint )
         ++nI
         IF nCRLF > 1
            nLines += nCRLF - 1
         ENDIF
         IF lPrint
            pdfNewLine( nCRLF - 1 )
         ENDIF
      ELSE
         nLineLen += nSpace + nTokenLen
         ++nI
      ENDIF
   ENDDO

RETURN nLines

/*
 * Function:    pdfTextPrint
 * Purpose:     Helper routine to print a single wrapped line of tokens with alignment spacing.
 * Parameters:  nI         (Numeric)   - End token index for current line.
 *              nLeft      (Numeric)   - Base left coordinate.
 *              lParagraph (Logical)   - Paragraph start flag (passed by reference).
 *              nJustify   (Numeric)   - Justification mode code.
 *              nSpace     (Numeric)   - Space character width.
 *              nNew       (Numeric)   - Indent tab space count.
 *              nLength    (Numeric)   - Maximum allowed line length.
 *              nLineLen   (Numeric)   - Calculated line length (passed by reference).
 *              nLines     (Numeric)   - Rendered line counter (passed by reference).
 *              nStart     (Numeric)   - Start token index for current line (passed by reference).
 *              cString    (Character) - Full source text string.
 *              cDelim     (Character) - Word delimiter character set.
 *              cColor     (Character) - Color specification string.
 *              lPrint     (Logical)   - Print execution flag.
 * Returns:     NIL
 * Side Effects: Outputs text via pdfAtSay; advances line counters.
 */
STATIC FUNCTION pdfTextPrint( nI, nLeft, lParagraph, nJustify, nSpace, nNew, nLength, nLineLen, nLines, nStart, cString, cDelim, cColor, lPrint )

   LOCAL nFinish, nL, nB, nJ, cToken, nRow

   nFinish := nI
   nL := nLeft
   IF lParagraph
      IF nJustify != 2
         nL += nSpace * nNew
      ENDIF
   ENDIF
   IF nJustify == 3
      nL += nLength - nLineLen
   ELSEIF nJustify == 2
      nL += ( nLength - nLineLen ) / 2
   ENDIF
   ++nLines
   IF lPrint
      nRow := pdfNewLine( 1 )
   ENDIF
   nB := nSpace
   // Compute inter-word padding space for full justification mode
   IF nJustify == 4
      nB := ( nLength - nLineLen + ( nFinish - nStart ) * nSpace ) / ( nFinish - nStart )
   ENDIF
   // Render each token on the active line
   FOR nJ := nStart TO nFinish
      cToken := Token( cString, cDelim, nJ )
      IF lPrint
         pdfAtSay( cColor + cToken, pdfR2M( nRow + s_aReport[ PDFTOP ] ), nL, "M" )
      ENDIF
      nL += pdfLen ( cToken ) + nB
   NEXT
   nStart := nFinish + 1
   lParagraph := .F.
   nLineLen := 0.00
   nLineLen += nSpace * nNew

RETURN NIL

/*
 * Function:    pdfTextNextPara
 * Purpose:     Determines if subsequent text tokens start a new paragraph (contain line break characters).
 * Parameters:  cString (Character) - Text string.
 *              cDelim  (Character) - Token delimiter set.
 *              nI      (Numeric)   - Current token index.
 * Returns:     Numeric - Count of newline occurrences between current and next token.
 * Side Effects: None
 */
STATIC FUNCTION pdfTextNextPara( cString, cDelim, nI )

   LOCAL nAt, cAt, nCRLF, nNew, nRat, nRet := 0

   // Inspect whitespace gap between tokens for embedded carriage return/line feed bytes
   nAt := AtToken( cString, cDelim, nI ) + Len( Token( cString, cDelim, nI ) )
   cAt := SubStr( cString, nAt, AtToken( cString, cDelim, nI + 1 ) - nAt )
   nCRLF := NumAt( Chr( 13 ) + Chr( 10 ), cAt )
   nRat := RAt( Chr( 13 ) + Chr( 10 ), cAt )
   nNew := Len( cAt ) - nRat - iif( nRat > 0, 1, 0 )
   IF nCRLF > 1 .OR. ( nCRLF == 1 .AND. nNew > 0 )
      nRet := nCRLF
   ENDIF

RETURN nRet

/*
 * Function:    pdfUnderline
 * Purpose:     Appends underline control character to a text string.
 * Parameters:  cString (Character) - Input text string.
 * Returns:     Character - String with appended Chr(254) underline flag.
 * Side Effects: None
 */
FUNCTION pdfUnderline( cString )
RETURN cString + Chr( 254 )

/*
 * Function:    pdfX2M
 * Purpose:     Converts PDF points (1/72 inch) to millimeters.
 * Parameters:  n (Numeric) - Value in points.
 * Returns:     Numeric - Equivalent value in millimeters.
 * Side Effects: None
 */
STATIC FUNCTION pdfX2M( n )
RETURN n * 25.4 / 72

/*
 * Function:    TimeAsAMPM
 * Purpose:     Converts a 24-hour time string ("HH:MM:SS") to 12-hour AM/PM format.
 * Parameters:  cTime (Character) - 24-hour time string.
 * Returns:     Character - Formatted 12-hour AM/PM time string.
 * Side Effects: None
 */
STATIC FUNCTION TimeAsAMPM( cTime )
   IF Val( cTime ) < 12
      cTime += " am"
   ELSEIF Val( cTime ) == 12
      cTime += " pm"
   ELSE
      cTime := Str( Val( cTime ) - 12, 2 ) + SubStr( cTime, 3 ) + " pm"
   ENDIF
   cTime := Left( cTime, 5 ) + SubStr( cTime, 10 )

RETURN cTime

/*
 * Function:    pdfOpenHeader
 * Purpose:     Loads page header definition template entries from an array file.
 * Parameters:  cFile (Character) - Header file path.
 * Returns:     NIL
 * Side Effects: Populates s_aReport[ HEADER ] array; sets s_aReport[ MARGINS ] to .T.
 */
FUNCTION pdfOpenHeader( cFile )

   LOCAL nAt
   __defaultNIL( @cFile, "" )
   IF ! Empty( cFile )
      cFile := AllTrim( cFile )
      // Copy to temporary 8.3 filename if long filename or space present
      IF Len( cFile ) > 12 .OR. ;
            At( " ", cFile ) > 0 .OR. ;
            ( At( " ", cFile ) == 0 .AND. Len( cFile ) > 8 ) .OR. ;
            ( ( nAt := At( ".", cFile ) ) > 0 .AND. Len( SubStr( cFile, nAt + 1 ) ) > 3 )
         COPY FILE ( cFile ) TO temp.tmp
         cFile := "temp.tmp"
      ENDIF
      s_aReport[ HEADER ] := File2Array( cFile )
   ELSE
      s_aReport[ HEADER ] := {}
   ENDIF
   s_aReport[ MARGINS ] := .T.

RETURN NIL

/*
 * Function:    pdfEditOnHeader
 * Purpose:     Enables header template editing mode (intercepts graphics calls into header array).
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Sets HEADEREDIT and MARGINS elements in s_aReport to .T.
 */
FUNCTION pdfEditOnHeader()
   s_aReport[ HEADEREDIT ] := .T.
   s_aReport[ MARGINS ] := .T.

RETURN NIL

/*
 * Function:    pdfEditOffHeader
 * Purpose:     Disables header template editing mode.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Sets HEADEREDIT to .F. and MARGINS to .T. in s_aReport.
 */
FUNCTION pdfEditOffHeader()
   s_aReport[ HEADEREDIT ] := .F.
   s_aReport[ MARGINS ] := .T.

RETURN NIL

/*
 * Function:    pdfCloseHeader
 * Purpose:     Clears current header template definitions.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Resets s_aReport[ HEADER ] to empty array and s_aReport[ MARGINS ] to .F.
 */
FUNCTION pdfCloseHeader()
   s_aReport[ HEADER ] := {}
   s_aReport[ MARGINS ] := .F.

RETURN NIL

/*
 * Function:    pdfDeleteHeader
 * Purpose:     Removes a specific header element by identifier from the template array.
 * Parameters:  cId (Character) - Identifier tag of header element to remove.
 * Returns:     Numeric - Number of remaining header elements, or -1 if ID not found.
 * Side Effects: Modifies s_aReport[ HEADER ] array; sets MARGINS to .T.
 */
FUNCTION pdfDeleteHeader( cId )

   LOCAL nRet := -1, nId
   cId := Upper( cId )
   nId := AScan( s_aReport[ HEADER ], {| arr | arr[ 3 ] == cId } )
   IF nId > 0
      nRet := Len( s_aReport[ HEADER ] ) - 1
      ADel( s_aReport[ HEADER ], nId )
      ASize( s_aReport[ HEADER ], nRet )
      s_aReport[ MARGINS ] := .T.
   ENDIF

RETURN nRet

/*
 * Function:    pdfEnableHeader
 * Purpose:     Enables rendering of a specific identified header element.
 * Parameters:  cId (Character) - Identifier tag of header item.
 * Returns:     NIL
 * Side Effects: Updates element flag in s_aReport[ HEADER ]; sets MARGINS to .T.
 */
FUNCTION pdfEnableHeader( cId )

   LOCAL nId
   cId := Upper( cId )
   nId := AScan( s_aReport[ HEADER ], {| arr | arr[ 3 ] == cId } )
   IF nId > 0
      s_aReport[ HEADER ][ nId ][ 1 ] := .T.
      s_aReport[ MARGINS ] := .T.
   ENDIF

RETURN NIL

/*
 * Function:    pdfDisableHeader
 * Purpose:     Disables rendering of a specific identified header element.
 * Parameters:  cId (Character) - Identifier tag of header item.
 * Returns:     NIL
 * Side Effects: Updates element flag in s_aReport[ HEADER ]; sets MARGINS to .T.
 */
FUNCTION pdfDisableHeader( cId )

   LOCAL nId
   cId := Upper( cId )
   nId := AScan( s_aReport[ HEADER ], {| arr | arr[ 3 ] == cId } )
   IF nId > 0
      s_aReport[ HEADER ][ nId ][ 1 ] := .F.
      s_aReport[ MARGINS ] := .T.
   ENDIF

RETURN NIL

/*
 * Function:    pdfSaveHeader
 * Purpose:     Saves active header template definitions to a disk file.
 * Parameters:  cFile (Character) - Output filename.
 * Returns:     NIL
 * Side Effects: Writes header array to disk file.
 */
FUNCTION pdfSaveHeader( cFile )
   Array2File( "temp.tmp", s_aReport[ HEADER ] )
   COPY FILE temp.tmp TO ( cFile )

RETURN NIL

/*
 * Function:    pdfHeader
 * Purpose:     Appends or updates a drawing command item in the header template structure.
 * Parameters:  cFunction (Character) - Drawing function name ("PDFATSAY", "PDFBOX", etc.).
 *              cId       (Character) - Item unique identifier string.
 *              arr       (Array)     - Parameter array for the drawing command.
 * Returns:     Character - Resolved unique item identifier cId.
 * Side Effects: Appends or updates array element in s_aReport[ HEADER ].
 */
FUNCTION pdfHeader( cFunction, cId, arr )

   LOCAL nId, nI, nLen, nIdLen
   nId := 0
   IF ! Empty( cId )
      cId := Upper( cId )
      nId := AScan( s_aReport[ HEADER ], {| arr | arr[ 3 ] == cId } )
   ENDIF
   // Generate auto-incremented item ID if ID parameter is empty
   IF nId == 0
      nLen := Len( s_aReport[ HEADER ] )
      IF Empty( cId )
         cId := cFunction
         nIdLen := Len( cId )
         FOR nI := 1 TO nLen
            IF s_aReport[ HEADER ][ nI ][ 2 ] == cId
               IF Val( SubStr( s_aReport[ HEADER ][ nI ][ 3 ], nIdLen + 1 ) ) > nId
                  nId := Val( SubStr( s_aReport[ HEADER ][ nI ][ 3 ], nIdLen + 1 ) )
               ENDIF
            ENDIF
         NEXT
         ++nId
         cId += hb_ntos( nId )
      ENDIF
      AAdd( s_aReport[ HEADER ], { .T., cFunction, cId } )
      ++nLen
      FOR nI := 1 TO Len( arr )
         AAdd( s_aReport[ HEADER ][ nLen ], arr[ nI ] )
      NEXT
   ELSE
      ASize( s_aReport[ HEADER ][ nId ], 3 )
      FOR nI := 1 TO Len( arr )
         AAdd( s_aReport[ HEADER ][ nId ], arr[ nI ] )
      NEXT
   ENDIF

RETURN cId

/*
 * Function:    pdfDrawHeader
 * Purpose:     Renders all active header template elements on the top of a newly created page.
 * Parameters:  None
 * Returns:     NIL
 * Side Effects: Re-executes header drawing routines; restores font state; recalculates margins.
 */
FUNCTION pdfDrawHeader()

   LOCAL nI, _nFont, _nSize, nLen := Len( s_aReport[ HEADER ] )

   IF nLen > 0
      _nFont := s_aReport[ FONTNAME ]
      _nSize := s_aReport[ FONTSIZE ]
      // Execute each enabled drawing command in header template table
      FOR nI := 1 TO nLen
         IF s_aReport[ HEADER ][ nI ][ 1 ]
            DO CASE
            CASE s_aReport[ HEADER ][ nI ][ 2 ] == "PDFATSAY"
               pdfAtSay( s_aReport[ HEADER ][ nI ][ 4 ], s_aReport[ HEADER ][ nI ][ 5 ], s_aReport[ HEADER ][ nI ][ 6 ], s_aReport[ HEADER ][ nI ][ 7 ], s_aReport[ HEADER ][ nI ][ 8 ], s_aReport[ HEADER ][ nI ][ 3 ] )
            CASE s_aReport[ HEADER ][ nI ][ 2 ] == "PDFCENTER"
               pdfCenter( s_aReport[ HEADER ][ nI ][ 4 ], s_aReport[ HEADER ][ nI ][ 5 ], s_aReport[ HEADER ][ nI ][ 6 ], s_aReport[ HEADER ][ nI ][ 7 ], s_aReport[ HEADER ][ nI ][ 8 ], s_aReport[ HEADER ][ nI ][ 3 ] )
            CASE s_aReport[ HEADER ][ nI ][ 2 ] == "PDFRJUST"
               pdfRJust( s_aReport[ HEADER ][ nI ][ 4 ], s_aReport[ HEADER ][ nI ][ 5 ], s_aReport[ HEADER ][ nI ][ 6 ], s_aReport[ HEADER ][ nI ][ 7 ], s_aReport[ HEADER ][ nI ][ 8 ], s_aReport[ HEADER ][ nI ][ 3 ] )
            CASE s_aReport[ HEADER ][ nI ][ 2 ] == "PDFBOX"
               pdfBox( s_aReport[ HEADER ][ nI ][ 4 ], s_aReport[ HEADER ][ nI ][ 5 ], s_aReport[ HEADER ][ nI ][ 6 ], s_aReport[ HEADER ][ nI ][ 7 ], s_aReport[ HEADER ][ nI ][ 8 ], s_aReport[ HEADER ][ nI ][ 9 ], s_aReport[ HEADER ][ nI ][ 10 ], s_aReport[ HEADER ][ nI ][ 3 ] )
            CASE s_aReport[ HEADER ][ nI ][ 2 ] == "PDFSETFONT"
               pdfSetFont( s_aReport[ HEADER ][ nI ][ 4 ], s_aReport[ HEADER ][ nI ][ 5 ], s_aReport[ HEADER ][ nI ][ 6 ], s_aReport[ HEADER ][ nI ][ 3 ] )
            CASE s_aReport[ HEADER ][ nI ][ 2 ] == "PDFIMAGE"
               pdfImage( s_aReport[ HEADER ][ nI ][ 4 ], s_aReport[ HEADER ][ nI ][ 5 ], s_aReport[ HEADER ][ nI ][ 6 ], s_aReport[ HEADER ][ nI ][ 7 ], s_aReport[ HEADER ][ nI ][ 8 ], s_aReport[ HEADER ][ nI ][ 9 ], s_aReport[ HEADER ][ nI ][ 3 ] )
            ENDCASE
         ENDIF
      NEXT
      s_aReport[ FONTNAME ] := _nFont
      s_aReport[ FONTSIZE ] := _nSize
      IF s_aReport[ MARGINS ]
         pdfMargins()
      ENDIF
   ELSE
      IF s_aReport[ MARGINS ]
         s_aReport[ PDFTOP ] := 1
         s_aReport[ PDFLEFT ] := 10
         s_aReport[ PDFBOTTOM ] := s_aReport[ PAGEY ] / 72 * s_aReport[ LPI ] - 1
         s_aReport[ MARGINS ] := .F.
      ENDIF
   ENDIF

RETURN NIL

/*
 * Function:    pdfMargins
 * Purpose:     Calculates dynamic printable page top/left/bottom margin bounds based on header element placement.
 * Parameters:  nTop    (Numeric) - Initial top margin limit.
 *              nLeft   (Numeric) - Initial left margin limit.
 *              nBottom (Numeric) - Initial bottom margin limit.
 * Returns:     NIL
 * Side Effects: Updates PDFTOP, PDFLEFT, and PDFBOTTOM elements in s_aReport; sets MARGINS to .F.
 */
FUNCTION pdfMargins( nTop, nLeft, nBottom )

   LOCAL nI, nLen := Len( s_aReport[ HEADER ] ), nTemp, aTemp, nHeight

   // Default margin boundaries based on letter paper at 6 LPI
   __defaultNIL( @nTop, 1 )
   __defaultNIL( @nLeft, 10 )
   __defaultNIL( @nBottom, s_aReport[ PAGEY ] / 72 * s_aReport[ LPI ] - 1 )  // default bottom boundary

   s_aReport[ PDFTOP ] := nTop
   s_aReport[ PDFLEFT ] := nLeft
   s_aReport[ PDFBOTTOM ] := nBottom

   // Adjust margin bounds based on spatial extent of active header commands
   FOR nI := 1 TO nLen
      IF s_aReport[ HEADER ][ nI ][ 1 ]
         IF s_aReport[ HEADER ][ nI ][ 2 ] == "PDFSETFONT"
         ELSEIF s_aReport[ HEADER ][ nI ][ 2 ] == "PDFIMAGE"
            IF s_aReport[ HEADER ][ nI ][ 8 ] == 0
               aTemp := pdfImageInfo( s_aReport[ HEADER ][ nI ][ 4 ] )
               nHeight := aTemp[ IMAGE_HEIGHT ] / aTemp[ IMAGE_YRES ] * 25.4
               IF s_aReport[ HEADER ][ nI ][ 7 ] == "D"
                  nHeight := pdfM2X( nHeight )
               ENDIF
            ELSE
               nHeight := s_aReport[ HEADER ][ nI ][ 8 ]
            ENDIF
            IF s_aReport[ HEADER ][ nI ][ 7 ] == "M"
               nTemp := s_aReport[ PAGEY ] / 72 * 25.4 / 2
               IF s_aReport[ HEADER ][ nI ][ 5 ] < nTemp
                  nTemp := ( s_aReport[ HEADER ][ nI ][ 5 ] + nHeight ) * s_aReport[ LPI ] / 25.4
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ELSE
                  nTemp := s_aReport[ HEADER ][ nI ][ 5 ] * s_aReport[ LPI ] / 25.4
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ENDIF
            ELSEIF s_aReport[ HEADER ][ nI ][ 7 ] == "D"
               nTemp := s_aReport[ PAGEY ] / 2
               IF s_aReport[ HEADER ][ nI ][ 5 ] < nTemp
                  nTemp := ( s_aReport[ HEADER ][ nI ][ 5 ] + nHeight ) * s_aReport[ LPI ] / 72
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ELSE
                  nTemp := s_aReport[ HEADER ][ nI ][ 5 ] * s_aReport[ LPI ] / 72
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ENDIF
            ENDIF
         ELSEIF s_aReport[ HEADER ][ nI ][ 2 ] == "PDFBOX"
            IF s_aReport[ HEADER ][ nI ][ 10 ] == "M"
               nTemp := s_aReport[ PAGEY ] / 72 * 25.4 / 2
               IF s_aReport[ HEADER ][ nI ][ 4 ] < nTemp .AND. ;
                     s_aReport[ HEADER ][ nI ][ 6 ] < nTemp
                  nTemp := s_aReport[ HEADER ][ nI ][ 6 ] * s_aReport[ LPI ] / 25.4
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ELSEIF s_aReport[ HEADER ][ nI ][ 4 ] < nTemp .AND. ;
                     s_aReport[ HEADER ][ nI ][ 6 ] > nTemp
                  nTemp := ( s_aReport[ HEADER ][ nI ][ 4 ] + s_aReport[ HEADER ][ nI ][ 8 ] ) * s_aReport[ LPI ] / 25.4
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
                  nTemp := ( s_aReport[ HEADER ][ nI ][ 6 ] - s_aReport[ HEADER ][ nI ][ 8 ] ) * s_aReport[ LPI ] / 25.4
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ELSEIF s_aReport[ HEADER ][ nI ][ 4 ] > nTemp .AND. ;
                     s_aReport[ HEADER ][ nI ][ 6 ] > nTemp
                  nTemp := s_aReport[ HEADER ][ nI ][ 4 ] * s_aReport[ LPI ] / 25.4
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ENDIF
            ELSEIF s_aReport[ HEADER ][ nI ][ 10 ] == "D"
               nTemp := s_aReport[ PAGEY ] / 2
               IF s_aReport[ HEADER ][ nI ][ 4 ] < nTemp .AND. ;
                     s_aReport[ HEADER ][ nI ][ 6 ] < nTemp
                  nTemp := s_aReport[ HEADER ][ nI ][ 6 ] / s_aReport[ LPI ]
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ELSEIF s_aReport[ HEADER ][ nI ][ 4 ] < nTemp .AND. ;
                     s_aReport[ HEADER ][ nI ][ 6 ] > nTemp
                  nTemp := ( s_aReport[ HEADER ][ nI ][ 4 ] + s_aReport[ HEADER ][ nI ][ 8 ] ) / s_aReport[ LPI ]
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
                  nTemp := ( s_aReport[ HEADER ][ nI ][ 6 ] - s_aReport[ HEADER ][ nI ][ 8 ] ) / s_aReport[ LPI ]
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ELSEIF s_aReport[ HEADER ][ nI ][ 4 ] > nTemp .AND. ;
                     s_aReport[ HEADER ][ nI ][ 6 ] > nTemp
                  nTemp := s_aReport[ HEADER ][ nI ][ 4 ] / s_aReport[ LPI ]
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ENDIF
            ENDIF
         ELSE
            IF s_aReport[ HEADER ][ nI ][ 7 ] == "R"
               nTemp := s_aReport[ HEADER ][ nI ][ 5 ]
               IF s_aReport[ HEADER ][ nI ][ 5 ] > s_aReport[ PAGEY ] / 72 * s_aReport[ LPI ] / 2
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ELSE
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ENDIF
            ELSEIF s_aReport[ HEADER ][ nI ][ 7 ] == "M"
               nTemp := s_aReport[ HEADER ][ nI ][ 5 ] * s_aReport[ LPI ] / 25.4
               IF s_aReport[ HEADER ][ nI ][ 5 ] > s_aReport[ PAGEY ] / 72 * 25.4 / 2
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ELSE
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ENDIF
            ELSEIF s_aReport[ HEADER ][ nI ][ 7 ] == "D"
               nTemp := s_aReport[ HEADER ][ nI ][ 5 ] / s_aReport[ LPI ]
               IF s_aReport[ HEADER ][ nI ][ 5 ] > s_aReport[ PAGEY ] / 2
                  IF nTemp < s_aReport[ PDFBOTTOM ]
                     s_aReport[ PDFBOTTOM ] := nTemp
                  ENDIF
               ELSE
                  IF nTemp > s_aReport[ PDFTOP ]
                     s_aReport[ PDFTOP ] := nTemp
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   NEXT
   s_aReport[ MARGINS ] := .F.

RETURN NIL

/*
 * Function:    pdfCreateHeader
 * Purpose:     Builds a pre-styled template header (with decorative boxes, title lines, and timestamp/page macros) and saves it to file.
 * Parameters:  _file   (Character) - File path to save header template.
 *              _size   (Character) - Page size ("LETTER", "LEGAL").
 *              _orient (Character) - Orientation ("P" or "L").
 *              _lpi    (Numeric)   - Lines per inch (6 or 8).
 *              _width  (Numeric)   - Virtual column width.
 * Returns:     NIL
 * Side Effects: Saves array structure to disk via pdfSaveHeader().
 */
FUNCTION pdfCreateHeader( _file, _size, _orient, _lpi, _width )

   // Pre-configured style positioning matrix based on paper, orientation, and LPI
   LOCAL s_aReportStyle := { ;
      { 1, 2, 3, 4, 5, 6 }, ;
      { 2.475, 4.0, 4.9, 6.4, 7.5, 64.0 }, ;
      { 3.3, 5.4, 6.5, 8.6, 10.0, 85.35 }, ;
      { 2.475, 4.0, 4.9, 6.4, 7.5, 48.9 }, ;
      { 3.3, 5.4, 6.5, 8.6, 10.0, 65.2 }, ;
      { 2.475, 4.0, 4.9, 6.4, 7.5, 82.0 }, ;
      { 3.3, 5.4, 6.5, 8.6, 10.0, 109.35 } }
   LOCAL nStyle := 1, nAdd := 0.00

   __defaultNIL( @_SIZE, s_aReport[ PAGESIZE ] )
   __defaultNIL( @_orient, s_aReport[ PAGEORIENT ] )
   __defaultNIL( @_lpi, s_aReport[ LPI ] )
   __defaultNIL( @_WIDTH, 200 )

   // Select style layout index matching paper size and pitch configuration
   IF _size == "LETTER"
      IF _orient == "P"
         IF _lpi == 6
            nStyle := 2
         ELSEIF _lpi == 8
            nStyle := 3
         ENDIF
      ELSEIF _orient == "L"
         IF _lpi == 6
            nStyle := 4
         ELSEIF _lpi == 8
            nStyle := 5
         ENDIF
      ENDIF
   ELSEIF _size == "LEGAL"
      IF _orient == "P"
         IF _lpi == 6
            nStyle := 6
         ELSEIF _lpi == 8
            nStyle := 7
         ENDIF
      ELSEIF _orient == "L"
         IF _lpi == 6
            nStyle := 4
         ELSEIF _lpi == 8
            nStyle := 5
         ENDIF
      ENDIF
   ENDIF

   pdfEditOnHeader()
   IF _size == "LEGAL"
      nAdd := 76.2
   ENDIF

   // Construct header frame boxes based on orientation
   IF _orient == "P"
      pdfBox( 5.0, 5.0, 274.0 + nAdd, 210.0, 1.0 )
      pdfBox( 6.5, 6.5, 272.5 + nAdd, 208.5, 0.5 )
      pdfBox( 11.5, 9.5, 22.0, 205.5, 0.5, 5 )
      pdfBox( 23.0, 9.5, 33.5, 205.5, 0.5, 5 )
      pdfBox( 34.5, 9.5, 267.5 + nAdd, 205.5, 0.5 )
   ELSE
      pdfBox( 5.0, 5.0, 210.0, 274.0 + nAdd, 1.0 )
      pdfBox( 6.5, 6.5, 208.5, 272.5 + nAdd, 0.5 )
      pdfBox( 11.5, 9.5, 22.0, 269.5 + nAdd, 0.5, 5 )
      pdfBox( 23.0, 9.5, 33.5, 269.5 + nAdd, 0.5, 5 )
      pdfBox( 34.5, 9.5, 203.5, 269.5 + nAdd, 0.5 )
   ENDIF

   // Add default text items and dynamic macro tags
   pdfSetFont( "Helvetica", BOLD, 10 )
   pdfAtSay( "Test Line 1", s_aReportStyle[ nStyle ][ 1 ], 1, "R", .T. )
   pdfSetFont( "Times", BOLD, 18 )
   pdfCenter( "Test Line 2", s_aReportStyle[ nStyle ][ 2 ],, "R", .T. )
   pdfSetFont( "Times", BOLD, 12 )
   pdfCenter( "Test Line 3", s_aReportStyle[ nStyle ][ 3 ],, "R", .T. )
   pdfSetFont( "Helvetica", BOLD, 10 )
   pdfAtSay( "Test Line 4", s_aReportStyle[ nStyle ][ 4 ], 1, "R", .T. )
   pdfSetFont( "Helvetica", BOLD, 10 )
   pdfAtSay( "Test Line 5", s_aReportStyle[ nStyle ][ 5 ], 1, "R", .T. )
   pdfAtSay( DToC( Date() ) + " " + TimeAsAMPM( Time() ), s_aReportStyle[ nStyle ][ 6 ], 1, "R", .T. )
   pdfRJust( "Page: #pagenumber#", s_aReportStyle[ nStyle ][ 6 ], s_aReport[ REPORTWIDTH ], "R", .T. )

   pdfEditOffHeader()
   pdfSaveHeader( _file )

RETURN NIL

/*
 * Function:    pdfImageInfo
 * Purpose:     Extracts image dimensions, resolution, and bit depth metadata by analyzing image file header tags.
 * Parameters:  cFile (Character) - Image file path.
 * Returns:     Array - Image metadata array { Width, Height, XRes, YRes, Bits, StreamOffset, StreamLength, ColorSpace }.
 * Side Effects: Opens image file on disk.
 */
FUNCTION pdfImageInfo( cFile )

   LOCAL cTemp := Upper( SubStr( cFile, RAt( ".", cFile ) + 1 ) ), aTemp := {}

   // Route to extension-specific image parser
   DO CASE
   CASE cTemp == "TIF"
      aTemp := pdfTIFFInfo( cFile )
   CASE cTemp == "JPG"
      aTemp := pdfJPEGInfo( cFile )
   ENDCASE

RETURN aTemp

/*
 * Function:    pdfTIFFInfo
 * Purpose:     Parses Tagged Image File Format (TIFF) headers to extract image tags.
 * Parameters:  cFile (Character) - TIFF file path.
 * Returns:     Array - Metadata array { Width, Height, XRes, YRes, Bits, StreamOffset, StreamLength, ColorSpace }.
 * Side Effects: Reads file directly from disk.
 */
FUNCTION pdfTIFFInfo( cFile )

   LOCAL c40 := Chr( 0 ) + Chr( 0 ) + Chr( 0 ) + Chr( 0 )
   LOCAL aCount := { 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8 }
   LOCAL nTemp, nHandle, cValues, c2, nFieldType, nCount, nPos, nTag, nValues
   LOCAL nOffset, cTemp, cIFDNext, nIFD, nFields, nn
   LOCAL nWidth := 0, nHeight := 0, nBits := 0, nFrom := 0, nLength := 0, xRes := 0, yRes := 0, aTemp := {}, nSpace

   nHandle := FOpen( cFile )
   c2 := "  "
   FRead( nHandle, @c2, 2 )
   FRead( nHandle, @c2, 2 )
   cIFDNext := "    "
   FRead( nHandle, @cIFDNext, 4 )
   cTemp := Space( 12 )

   // Parse Image File Directory (IFD) tag structures
   WHILE !( cIFDNext == c40 )
      nIFD := Bin2L( cIFDNext )
      FSeek( nHandle, nIFD )
      FRead( nHandle, @c2, 2 )
      nFields := Bin2I( c2 )
      FOR nn := 1 TO nFields
         FRead( nHandle, @cTemp, 12 )
         nTag := Bin2W( SubStr( cTemp, 1, 2 ) )
         nFieldType := Bin2W( SubStr( cTemp, 3, 2 ) )
         nCount := Bin2L( SubStr( cTemp, 5, 4 ) )
         nOffset := Bin2L( SubStr( cTemp, 9, 4 ) )

         // Retrieve tag value array if stored at external offset
         IF nCount > 1 .OR. nFieldType == RATIONAL .OR. nFieldType == SRATIONAL
            nPos := filepos( nHandle )
            FSeek( nHandle, nOffset )
            nValues := nCount * aCount[ nFieldType ]
            cValues := Space( nValues )
            FRead( nHandle, @cValues, nValues )
            FSeek( nHandle, nPos )
         ELSE
            cValues := SubStr( cTemp, 9, 4 )
         ENDIF

         IF nFieldType == ASCII
            --nCount
         ENDIF

         // Extract relevant metadata tags
         DO CASE
         CASE nTag == 256 // ImageWidth tag
            IF nFieldType == SHORT
               nWidth := Bin2W( SubStr( cValues, 1, 2 ) )
            ELSEIF nFieldType == LONG
               nWidth := Bin2L( SubStr( cValues, 1, 4 ) )
            ENDIF
         CASE nTag == 257 // ImageLength tag
            IF nFieldType == SHORT
               nHeight := Bin2W( SubStr( cValues, 1, 2 ) )
            ELSEIF nFieldType == LONG
               nHeight := Bin2L( SubStr( cValues, 1, 4 ) )
            ENDIF
         CASE nTag == 258 // BitsPerSample tag
            nTemp := 0
            IF nFieldType == SHORT
               nTemp := Bin2W( cValues )
            ENDIF
            nBits := nTemp
         CASE nTag == 262 // PhotometricInterpretation tag
            nTemp := -1
            IF nFieldType == SHORT
               nTemp := Bin2W( cValues )
            ENDIF
            IF nTemp != 0 .AND. nTemp != 1 .AND. nTemp != 2 .AND. nTemp != 3
            ENDIF
         CASE nTag == 273 // StripOffsets tag
            IF nFieldType == SHORT
               nFrom := Bin2W( SubStr( cValues, 1, 2 ) )
            ELSEIF nFieldType == LONG
               nFrom := Bin2L( SubStr( cValues, 1, 4 ) )
            ENDIF
         CASE nTag == 279 // StripByteCounts tag
            IF nFieldType == SHORT
               nLength := Bin2W( SubStr( cValues, 1, 2 ) )
            ELSEIF nFieldType == LONG
               nLength := Bin2L( SubStr( cValues, 1, 4 ) )
            ENDIF
            nLength *= nCount
         CASE nTag == 282 // XResolution tag
            IF nFieldType == RATIONAL
               xRes := Bin2L( SubStr( cValues, 1, 4 ) )
            ENDIF
         CASE nTag == 283 // YResolution tag
            IF nFieldType == RATIONAL
               yRes := Bin2L( SubStr( cValues, 1, 4 ) )
            ENDIF
         ENDCASE
      NEXT
      FRead( nHandle, @cIFDNext, 4 )
   ENDDO

   FClose( nHandle )
   AAdd( aTemp, nWidth )
   AAdd( aTemp, nHeight )
   AAdd( aTemp, xRes )
   AAdd( aTemp, yRes )
   AAdd( aTemp, nBits )
   AAdd( aTemp, nFrom )
   AAdd( aTemp, nLength )
   nSpace := 0
   AAdd( aTemp, nSpace )

RETURN aTemp

/*
 * Function:    pdfJPEGInfo
 * Purpose:     Parses JPEG JFIF header markers to extract image dimensions, resolution, and color channels.
 * Parameters:  cFile (Character) - JPEG file path.
 * Returns:     Array - Metadata array { Width, Height, XRes, YRes, Bits, StreamOffset, StreamLength, ColorSpace }.
 * Side Effects: Reads file directly from disk.
 */
FUNCTION pdfJPEGInfo( cFile )

   LOCAL c255, nAt, nHandle
   LOCAL nWidth, nHeight, nBits := 8, nFrom := 0, nLength, xRes, yRes, aTemp := {}
   LOCAL nBuffer := 20000
   LOCAL nSpace

   nHandle := FOpen( cFile )
   c255 := Space( nBuffer )
   FRead( nHandle, @c255, nBuffer )
   // Parse JFIF resolution markers
   xRes := Asc( SubStr( c255, 15, 1 ) ) * 256 + Asc( SubStr( c255, 16, 1 ) )
   yRes := Asc( SubStr( c255, 17, 1 ) ) * 256 + Asc( SubStr( c255, 18, 1 ) )
   // Locate Start of Frame 0 (SOF0) marker FF C0
   nAt := RAt( Chr( 255 ) + Chr( 192 ), c255 ) + 5
   nHeight := Asc( SubStr( c255, nAt, 1 ) ) * 256 + Asc( SubStr( c255, nAt + 1, 1 ) )
   nWidth := Asc( SubStr( c255, nAt + 2, 1 ) ) * 256 + Asc( SubStr( c255, nAt + 3, 1 ) )
   nSpace := Asc( SubStr( c255, nAt + 4, 1 ) )
   nLength := FileSize( nHandle )
   FClose( nHandle )

   AAdd( aTemp, nWidth )
   AAdd( aTemp, nHeight )
   AAdd( aTemp, xRes )
   AAdd( aTemp, yRes )
   AAdd( aTemp, nBits )
   AAdd( aTemp, nFrom )
   AAdd( aTemp, nLength )
   AAdd( aTemp, nSpace )

RETURN aTemp

/*
 * Function:    FilePos
 * Purpose:     Returns current byte offset position of an open file handle.
 * Parameters:  nHandle (Numeric) - File handle.
 * Returns:     Numeric - Current file pointer byte offset.
 * Side Effects: None
 */
STATIC FUNCTION FilePos( nHandle )
RETURN FSeek( nHandle, 0, FS_RELATIVE )

/*
 * Function:    Chr_RGB
 * Purpose:     Converts a single byte character value (0..255) to a formatted PDF color intensity string (0.00..1.00).
 * Parameters:  cChar (Character) - Single byte character.
 * Returns:     Character - Formatted decimal intensity string (e.g., "0.50").
 * Side Effects: None
 */
STATIC FUNCTION Chr_RGB( cChar )
RETURN Str( Asc( cChar ) / 255, 4, 2 )

/*
 * Function:    NumToken
 * Purpose:     Counts the number of delimited tokens present in a text string.
 * Parameters:  cString    (Character) - Text string to inspect.
 *              cDelimiter (Character) - Set of delimiter characters.
 * Returns:     Numeric - Token count.
 * Side Effects: None
 */
STATIC FUNCTION NumToken( cString, cDelimiter )
RETURN AllToken( cString, cDelimiter )

/*
 * Function:    Token
 * Purpose:     Extracts the N-th delimited token element from a string.
 * Parameters:  cString    (Character) - Text string.
 *              cDelimiter (Character) - Delimiter characters.
 *              nPointer   (Numeric)   - Token index position (1-based).
 * Returns:     Character - Extracted token string.
 * Side Effects: None
 */
STATIC FUNCTION Token( cString, cDelimiter, nPointer )
RETURN AllToken( cString, cDelimiter, nPointer, 1 )

/*
 * Function:    AtToken
 * Purpose:     Finds starting character index position of the N-th token in a string.
 * Parameters:  cString    (Character) - Text string.
 *              cDelimiter (Character) - Delimiter characters.
 *              nPointer   (Numeric)   - Token index position (1-based).
 * Returns:     Numeric - Starting 1-based character position.
 * Side Effects: None
 */
STATIC FUNCTION AtToken( cString, cDelimiter, nPointer )
RETURN AllToken( cString, cDelimiter, nPointer, 2 )

/*
 * Function:    AllToken
 * Purpose:     Core string parsing engine supporting token counting, token extraction, and position lookup.
 * Parameters:  cString    (Character) - Text string.
 *              cDelimiter (Character) - Delimiter characters.
 *              nPointer   (Numeric)   - Target token index.
 *              nAction    (Numeric)   - Action code (0 = count tokens, 1 = get token text, 2 = get token position).
 * Returns:     Variant - Numeric count/position or Character token text.
 * Side Effects: None
 */
STATIC FUNCTION AllToken( cString, cDelimiter, nPointer, nAction )

   LOCAL nTokens := 0, nPos := 1, nLen := Len( cString ), nStart, cRet

   __defaultNIL( @cDelimiter, Chr( 0 ) + Chr( 9 ) + Chr( 10 ) + Chr( 13 ) + Chr( 26 ) + Chr( 32 ) + Chr( 138 ) + Chr( 141 ) )
   __defaultNIL( @nAction, 0 )
   /*
    * Action selector:
    * nAction == 0 - Return total token count
    * nAction == 1 - Return token substring
    * nAction == 2 - Return starting position offset
    */
   WHILE nPos <= nLen
      IF ! SubStr( cString, nPos, 1 ) $ cDelimiter
         nStart := nPos
         WHILE nPos <= nLen .AND. ! SubStr( cString, nPos, 1 ) $ cDelimiter
            ++nPos
         ENDDO
         ++nTokens
         IF nAction > 0
            IF nPointer == nTokens
               IF nAction == 1
                  cRet := SubStr( cString, nStart, nPos - nStart )
               ELSE
                  cRet := nStart
               ENDIF
               EXIT
            ENDIF
         ENDIF
      ENDIF
      IF SubStr( cString, nPos, 1 ) $ cDelimiter
         WHILE nPos <= nLen .AND. SubStr( cString, nPos, 1 ) $ cDelimiter
            ++nPos
         ENDDO
      ENDIF
      cRet := nTokens
   ENDDO

RETURN cRet

/*
 * Function:    NumAt
 * Purpose:     Counts total non-overlapping occurrences of a substring within a larger text string.
 * Parameters:  cSearch (Character) - Substring to count.
 *              cString (Character) - Text string to scan.
 * Returns:     Numeric - Total occurrence count.
 * Side Effects: None
 */
STATIC FUNCTION NumAt( cSearch, cString )

   LOCAL n := 0, nAt, nPos := 0

   WHILE ( nAt := At( cSearch, SubStr( cString, nPos + 1 ) ) ) > 0
      nPos += nAt
      ++n
   ENDDO

RETURN n

/*
 * Function:    FileSize
 * Purpose:     Measures the total byte size of an open file handle.
 * Parameters:  nHandle (Numeric) - Low-level file handle.
 * Returns:     Numeric - File size in bytes.
 * Side Effects: Temporarily moves and restores file seek pointer position.
 */
STATIC FUNCTION FileSize( nHandle )

   LOCAL nCurrent
   LOCAL nLength

   nCurrent := FilePos( nHandle )
   nLength := FSeek( nHandle, 0, FS_END )
   FSeek( nHandle, nCurrent )

RETURN nLength

/*
 * Function:    Array2File
 * Purpose:     Serializes a multidimensional array structure to a binary data file.
 * Parameters:  cFile  (Character) - Output file path.
 *              aRay   (Array)     - Array structure to serialize.
 *              nDepth (Numeric)   - Recursion depth counter.
 *              hFile  (Numeric)   - Open file handle.
 * Returns:     Numeric - Total bytes written.
 * Side Effects: Writes data to disk file; creates file if hFile is NIL.
 */
STATIC FUNCTION Array2File( cFile, aRay, nDepth, hFile )

   LOCAL nBytes := 0
   LOCAL i

   nDepth := iif( HB_ISNUMERIC( nDepth ), nDepth, 0 )
   IF hFile == NIL
      IF ( hFile := FCreate( cFile, FC_NORMAL ) ) == F_ERROR
         RETURN nBytes
      ENDIF
   ENDIF
   nDepth++
   nBytes += WriteData( hFile, aRay )
   IF HB_ISARRAY( aRay )
      FOR i := 1 TO Len( aRay )
         nBytes += Array2File( cFile, aRay[ i ], nDepth, hFile )
      NEXT
   ENDIF
   nDepth--
   IF nDepth == 0
      FClose( hFile )
   ENDIF

RETURN nBytes

/*
 * Function:    WriteData
 * Purpose:     Helper function that writes typed binary element descriptors and data payloads to file.
 * Parameters:  hFile (Numeric) - Output file handle.
 *              xData (Variant) - Variable value to serialize.
 * Returns:     Numeric - Bytes written to file.
 * Side Effects: Flushes bytes to low-level file handle.
 */
STATIC FUNCTION WriteData( hFile, xData )

   LOCAL cData := ValType( xData )

   // Encode type indicator and length header followed by raw payload
   IF HB_ISSTRING( xData )
      cData += I2Bin( Len( xData ) ) + xData
   ELSEIF HB_ISNUMERIC( xData )
      cData += I2Bin( Len( hb_ntos( xData ) ) ) + hb_ntos( xData )
   ELSEIF HB_ISDATE( xData )
      cData += I2Bin( 8 ) + DToS( xData )
   ELSEIF HB_ISLOGICAL( xData )
      cData += I2Bin( 1 ) + iif( xData, "T", "F" )
   ELSEIF HB_ISARRAY( xData )
      cData += I2Bin( Len( xData ) )
   ELSE
      cData += I2Bin( 0 )
   ENDIF

RETURN FWrite( hFile, cData, Len( cData ) )

/*
 * Function:    File2Array
 * Purpose:     Deserializes an array structure from a previously written binary file.
 * Parameters:  cFile (Character) - Path of file to read.
 *              nLen  (Numeric)   - Expected element count.
 *              hFile (Numeric)   - Active file handle.
 * Returns:     Array - Reconstructed multidimensional array structure.
 * Side Effects: Reads data directly from disk file handle.
 */
STATIC FUNCTION File2Array( cFile, nLen, hFile )

   LOCAL cData, cType, nDataLen, nBytes
   LOCAL nDepth := 0
   LOCAL aRay := {}

   IF hFile == NIL
      IF ( hFile := FOpen( cFile, FO_READ ) ) == F_ERROR
         RETURN aRay
      ENDIF
      cData := Space( 3 )
      FRead( hFile, @cData, 3 )
      IF !( Left( cData, 1 ) == "A" )
         RETURN aRay
      ENDIF
      nLen := Bin2I( Right( cData, 2 ) )
   ENDIF
   // Recursively read typed data elements from file stream
   DO WHILE nDepth < nLen
      cData := Space( 3 )
      nBytes := FRead( hFile, @cData, 3 )
      IF nBytes < 3
         EXIT
      ENDIF
      cType := PadL( cData, 1 )
      nDataLen := Bin2I( Right( cData, 2 ) )
      IF !( cType == "A" )
         cData := Space( nDataLen )
         nBytes := FRead( hFile, @cData, nDataLen )
         IF nBytes < nDataLen
            EXIT
         ENDIF
      ENDIF
      nDepth++
      AAdd( aRay, NIL )
      IF cType == "C"
         aRay[ nDepth ] := cData
      ELSEIF cType == "N"
         aRay[ nDepth ] := Val( cData )
      ELSEIF cType == "D"

#ifdef __XHARBOUR__
         aRay[ nDepth ] := CToD( Left( cData, 4 ) + "/" + SubStr( cData, 5, 2 ) + "/" + SubStr( cData, 7, 2 ) )
#else
         aRay[ nDepth ] := hb_SToD( cData )
#endif
      ELSEIF cType == "L"
         aRay[ nDepth ] := ( cData == "T" )
      ELSEIF cType == "A"
         aRay[ nDepth ] := File2Array(, nDataLen, hFile )
      ENDIF
   ENDDO
   IF cFile != NIL
      FClose( hFile )
   ENDIF

RETURN aRay
