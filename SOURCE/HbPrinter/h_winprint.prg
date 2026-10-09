/*
 * HBPRINTER - Harbour Win32 Printing library source code
 *
 * Copyright 2002-2005 Richard Rylko <rrylko@poczta.onet.pl>
 */

#define __HBPRN__

#include "minigui.ch"
#include "winprint.ch"

#ifdef _DEBUG_
#undef _DEBUG_
#endif

/* Background Modes */
#define TRANSPARENT 1
#define OPAQUE      2
#define BKMODE_LAST 2

MEMVAR page, scale, azoom, ahs, npages
MEMVAR dx, dy, ngroup, ath, Iloscstron
MEMVAR aopisy

#include "SET_COMPILE_HMG_UNICODE.ch"

#include "hbclass.ch"

CLASS HBPrinter

   DATA hDC INIT 0
   PROTECT hDCRef INIT 0
   DATA PrinterName INIT ""

   DATA SaveButtons INIT .T.
   DATA lEscaped INIT .F.
   DATA nFromPage INIT 1
   DATA nToPage INIT 0
   PROTECT CurPage INIT 1
   DATA nCopies INIT 1
   DATA nWhatToPrint INIT 0
   PROTECT PrintOpt INIT 1

   DATA PrinterDefault INIT ""
   DATA Error INIT 0 READONLY
   DATA PaperNames INIT {}
   DATA BINNAMES INIT {}
   DATA DOCNAME INIT "HBPRINTER"
   DATA TextColor INIT 0
   DATA BkColor INIT 0xFFFFFF
   DATA BkMode INIT 1  // TRANSPARENT
   DATA PolyFillMode INIT 1
   DATA Cargo INIT { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
   DATA FONTS INIT { {}, {}, 0, {} }
   DATA BRUSHES INIT { {}, {} }
   DATA PENS INIT { {}, {} }
   DATA REGIONS INIT { {}, {} }
   DATA IMAGELISTS INIT { {}, {} }
   DATA UNITS INIT 0
   DATA DEVCAPS INIT { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 }
   DATA MAXROW INIT 0
   DATA MAXCOL INIT 0
   PROTECT METAFILES INIT {}
   PROTECT BasePageName INIT ""
   DATA PREVIEWMODE INIT .F.
   DATA THUMBNAILS INIT .F.
   DATA CLSPREVIEW INIT .T.
   DATA VIEWPORTORG INIT { 0, 0 }
   DATA PREVIEWRECT INIT { 0, 0, 0, 0 }
   PROTECT PRINTINGEMF INIT .F.

#ifndef __XHARBOUR__
   DATA PRINTING INIT .F.
#endif
   DATA PREVIEWSCALE INIT 1
   DATA Printers INIT {}
   DATA Ports INIT {}
   PROTECT Version INIT 2.60

   METHOD New()
   METHOD SelectPrinter( cPrinter, lPrev )
   METHOD SetDevMode( what, newvalue )
   METHOD SetUserMode( what, value, value2 )
   METHOD Startdoc( ldocname )
   METHOD SetPage( orient, size, fontname )
   METHOD Startpage()
   METHOD Endpage()
   METHOD Enddoc()
   METHOD SetTextColor( clr )
   METHOD GetTextColor() INLINE ::TextColor
   METHOD SetBkColor( clr )
   METHOD GetBkColor() INLINE ::BkColor
   METHOD SetBkMode( nmode )
   METHOD GetBkMode() INLINE ::BkMode
   METHOD DefineImageList( defname, cpicture, nicons )
   METHOD DrawImageList( defname, nicon, row, col, torow, tocol, lstyle, color )
   METHOD DefineBrush( defname, lstyle, lcolor, lhatch )
   METHOD ModifyBrush( defname, lstyle, lcolor, lhatch )
   METHOD SelectBrush( defname )
   METHOD DefinePen( defname, lstyle, lwidth, lcolor )
   METHOD ModifyPen( defname, lstyle, lwidth, lcolor )
   METHOD SelectPen( defname )
   METHOD DefineFont( defname, lfontname, lfontsize, lfontwidth, langle, lweight, litalic, lunderline, lstrikeout )
   METHOD ModifyFont( defname, lfontname, lfontsize, lfontwidth, langle, lweight, lnweight, litalic, lnitalic, lunderline, lnunderline, lstrikeout, lnstrikeout )
   METHOD SelectFont( defname )
   METHOD GetObjByName( defname, what, retpos )
   METHOD DrawText( row, col, torow, tocol, txt, style, defname )
   METHOD TextOut( row, col, txt, defname )
   METHOD Say( row, col, txt, defname, lcolor, lalign )
   METHOD SetCharset( charset ) INLINE rr_setcharset( charset )
   METHOD Rectangle( row, col, torow, tocol, defpen, defbrush )
   METHOD RoundRect( row, col, torow, tocol, widthellipse, heightellipse, defpen, defbrush )
   METHOD FillRect( row, col, torow, tocol, defbrush )
   METHOD FrameRect( row, col, torow, tocol, defbrush )
   METHOD InvertRect( row, col, torow, tocol )
   METHOD Ellipse( row, col, torow, tocol, defpen, defbrush )
   METHOD Arc( row, col, torow, tocol, rowsarc, colsarc, rowearc, colearc, defpen )
   METHOD ArcTo( row, col, torow, tocol, rowrad1, colrad1, rowrad2, colrad2, defpen )
   METHOD Chord( row, col, torow, tocol, rowrad1, colrad1, rowrad2, colrad2, defpen, defbrush )
   METHOD Pie( row, col, torow, tocol, rowrad1, colrad1, rowrad2, colrad2, defpen, defbrush )
   METHOD Polygon( apoints, defpen, defbrush, style )
   METHOD PolyBezier( apoints, defpen )
   METHOD PolyBezierTo( apoints, defpen )
   METHOD SetUnits( newvalue, r, c )
   METHOD Convert( arr, lsize )
   METHOD DefineRectRgn( defname, row, col, torow, tocol )
   METHOD DefinePolygonRgn( defname, apoints, style )
   METHOD DefineEllipticRgn( defname, row, col, torow, tocol )
   METHOD DefineRoundRectRgn( defname, row, col, torow, tocol, widthellipse, heightellipse )
   METHOD CombineRgn( defname, reg1, reg2, style )
   METHOD SelectClipRgn( defname )
   METHOD DeleteClipRgn()
   METHOD SetPolyFillMode( style )
   METHOD GetPolyFillMode() INLINE ::PolyFillMode
   METHOD SetViewPortOrg( row, col )
   METHOD GetViewPortOrg()
   METHOD DxColors( par )
   METHOD SetRGB( red, green, blue )
   METHOD SetTextCharExtra( col )
   METHOD GetTextCharExtra()
   METHOD SetTextJustification( col )
   METHOD GetTextJustification()
   METHOD SetTextAlign( style )
   METHOD GetTextAlign()
   METHOD Picture( row, col, torow, tocol, cpicture, extrow, extcol )
   METHOD Line( row, col, torow, tocol, defpen )
   METHOD LineTo( row, col, defpen )
   METHOD SaveMetaFiles( number, filename )
   METHOD GetTextExtent( ctext, apoint, deffont )
   METHOD GetTextExtent_mm( ctext, apoint, deffont )
   METHOD End()

#ifdef _DEBUG_
   METHOD ReportData( l_x1, l_x2, l_x3, l_x4, l_x5, l_x6 )
#endif
   METHOD Preview()
   METHOD PrevPrint( n1 )
   METHOD PrevShow()
   METHOD PrevThumb( nclick )
   METHOD PrevClose( lEsc )
   METHOD PrintOption()
   METHOD GetVersion() INLINE ::Version

ENDCLASS


/*
 * Routine: New()
 *
 * Purpose:
 * Initializes a new HBPrinter object, discovers available printers and ports, records the default printer, and establishes the base name used for preview metafiles.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The initialized printer object.
 *
 * Side Effects:
 * Updates printer lists, default-printer information, Error when enumeration fails, and the preview metafile base name.
 */
METHOD New() CLASS HBPrinter

   LOCAL aprnport

   aprnport := rr_getprinters()
   IF aprnport <> ",,"
      aprnport := str2arr( aprnport, ",," )
      AEval( aprnport, {| x, xi | aprnport[ xi ] := str2arr( x, ',' ) } )
      AEval( aprnport, {| x | AAdd( ::Printers, x[ 1 ] ), AAdd( ::ports, x[ 2 ] ) } )
      ::PrinterDefault := RR_GETDEFAULTPRINTER()
   ELSE
      ::error := 1
   ENDIF
   ::BasePageName := GetTempFolder() + hb_ps() + StrZero( Seconds() * 100, 8 ) + "_HBP_print_preview_"

RETURN self


/*
 * Routine: SelectPrinter()
 *
 * Purpose:
 * Selects the printer device context used by the object, either from the default printer, a print dialog, or an explicitly named printer. It also initializes device-dependent printing resources when a device context is obtained.
 *
 * Parameters:
 * cPrinter - Harbour value - Value used by the routine as indicated by the source.
 * lPrev - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * NIL - No meaningful return value; printer selection is reflected in object state and Error.
 *
 * Side Effects:
 * Updates the printer device context, printer name, page/copy options from the dialog when used, preview mode when requested, printer capabilities, and registered default GDI objects.
 */
METHOD SelectPrinter( cPrinter, lPrev ) CLASS HBPrinter

#ifndef UNICODE
   LOCAL txtp := "", txtb := ""
#endif
   LOCAL t := { 0, 0, 1, 0 }

   IF cPrinter == NIL
      ::hDCRef := rr_getdc( ::PrinterDefault )
      ::hDC := ::hDCRef
      ::PrinterName := ::PrinterDefault
   ELSEIF Empty( cPrinter )
      ::hDCRef := rr_printdialog( t )
      ::nfrompage := t[ 1 ]
      ::ntopage := t[ 2 ]
      ::ncopies := t[ 3 ]
      ::nwhattoprint := t[ 4 ]
      ::hDC := ::hDCRef
      ::PrinterName := rr_PrinterName()
   ELSE
      ::hDCRef := rr_getdc( cPrinter )
      ::hDC := ::hDCRef
      ::PrinterName := cPrinter
   ENDIF
   IF ValType( lPrev ) == "L"
      IF lprev
         ::PreviewMode := .T.
      ENDIF
   ENDIF
   IF ::hDC == 0
      ::error := 1
      ::PrinterName := ""
   ELSE
#ifndef UNICODE
      rr_devicecapabilities( @txtp, @txtb )
      ::PaperNames := str2arr( txtp, ",," )
      ::BinNames := str2arr( txtb, ",," )
      AEval( ::BinNames, {| x, xi | ::BinNames[ xi ] := str2arr( x, ',' ) } )
      AEval( ::PaperNames, {| x, xi | ::PaperNames[ xi ] := str2arr( x, ',' ) } )
#endif
      AAdd( ::Fonts[ 1 ], rr_getcurrentobject( 1 ) ) ; AAdd( ::Fonts[ 2 ], "*" ) ; AAdd( ::Fonts[ 4 ], {} )
      AAdd( ::Fonts[ 1 ], rr_getcurrentobject( 1 ) ) ; AAdd( ::Fonts[ 2 ], "DEFAULT" ) ; AAdd( ::Fonts[ 4 ], {} )
      AAdd( ::Brushes[ 1 ], rr_getcurrentobject( 2 ) ) ; AAdd( ::Brushes[ 2 ], "*" )
      AAdd( ::Brushes[ 1 ], rr_getcurrentobject( 2 ) ) ; AAdd( ::Brushes[ 2 ], "DEFAULT" )
      AAdd( ::Pens[ 1 ], rr_getcurrentobject( 3 ) ) ; AAdd( ::Pens[ 2 ], "*" )
      AAdd( ::Pens[ 1 ], rr_getcurrentobject( 3 ) ) ; AAdd( ::Pens[ 2 ], "DEFAULT" )
      AAdd( ::Regions[ 1 ], 0 ) ; AAdd( ::Regions[ 2 ], "*" )
      AAdd( ::Regions[ 1 ], 0 ) ; AAdd( ::Regions[ 2 ], "DEFAULT" )
      ::Fonts[ 3 ] := ::Fonts[ 1, 1 ]
      rr_getdevicecaps( ::DEVCAPS, ::Fonts[ 3 ] )
      ::setunits( ::units )
   ENDIF

RETURN NIL


/*
 * Routine: SetDevMode()
 *
 * Purpose:
 * Changes a printer device-mode setting and refreshes device capabilities and coordinate conversion state.
 *
 * Parameters:
 * what - Harbour value - Value used by the routine as indicated by the source.
 * newvalue - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Updates the device context reference and recalculates device capabilities and coordinate units.
 */
METHOD SetDevMode( what, newvalue ) CLASS HBPrinter

   ::hDCRef := rr_setdevmode( what, newvalue )
   rr_getdevicecaps( ::DEVCAPS, ::Fonts[ 3 ] )
   ::setunits( ::units )

RETURN Self


/*
 * Routine: SetUserMode()
 *
 * Purpose:
 * Changes a user-defined printer setting and refreshes device capabilities and coordinate conversion state.
 *
 * Parameters:
 * what - Harbour value - Value used by the routine as indicated by the source.
 * value - Harbour value - Value used by the routine as indicated by the source.
 * value2 - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Updates the device context reference and recalculates device capabilities and coordinate units.
 */
METHOD SetUserMode( what, value, value2 ) CLASS HBPrinter

   ::hDCRef := rr_setusermode( what, value, value2 )
   rr_getdevicecaps( ::DEVCAPS, ::Fonts[ 3 ] )
   ::setunits( ::units )

RETURN Self


/*
 * Routine: StartDoc()
 *
 * Purpose:
 * Starts a print document unless preview mode is active. The optional document name is sanitized and stored before the document is started.
 *
 * Parameters:
 * ldocname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * May start a native print document and changes PRINTING state on supported builds.
 */
METHOD StartDoc( ldocname ) CLASS HBPrinter

#ifndef __XHARBOUR__
   ::Printing := .T.
#endif
   IF ldocname <> NIL
      ldocname := iif( HB_ISSTRING( ldocname ), StrTran( StrTran( ldocname, "\", "_" ), "/", "_" ), "" )
      ::DOCNAME := ldocname
   ENDIF
   IF ! ::PreviewMode
      rr_startdoc( ::DOCNAME )
   ENDIF

RETURN self


/*
 * Routine: SetPage()
 *
 * Purpose:
 * Applies optional paper size and orientation settings, optionally selects a named font, and refreshes device capabilities and units.
 *
 * Parameters:
 * orient - Harbour value - Value used by the routine as indicated by the source.
 * size - Harbour value - Value used by the routine as indicated by the source.
 * fontname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * May change printer device mode, selected font, device capabilities, and coordinate conversion state.
 */
METHOD SetPage( orient, size, fontname ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( fontname, "F" )

   IF size <> NIL
      ::SetDevMode( DM_PAPERSIZE, size )
   ENDIF
   IF orient <> NIL
      ::SetDevMode( DM_ORIENTATION, orient )
   ENDIF
   IF lhand <> 0
      ::Fonts[ 3 ] := lhand
   ENDIF
   rr_getdevicecaps( ::DEVCAPS, ::Fonts[ 3 ] )
   ::setunits( ::units )

RETURN Self


/*
 * Routine: Startpage()
 *
 * Purpose:
 * Starts a physical printer page or creates an Enhanced Metafile page in preview mode, then restores the drawing state used by the printer object.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * May create a preview EMF file or start a physical printer page and restores selected clipping, viewport, colors, brush, pen, and font state.
 */
METHOD Startpage() CLASS HBPrinter

   IF ::PreviewMode
      ::hDC := rr_createmfile( ::BasePageName + StrZero( Len( ::metafiles ) + 1, 4 ) + '.emf' )
   ELSE
      rr_Startpage()
   ENDIF
   IF ! ::Printingemf
      rr_selectcliprgn( ::Regions[ 1, 1 ] )
      rr_setviewportorg( ::ViewPortOrg )
      rr_settextcolor( ::textcolor )
      rr_setbkcolor( ::bkcolor )
      rr_setbkmode( ::bkmode )
      rr_selectbrush( ::Brushes[ 1, 1 ] )
      rr_selectpen( ::Pens[ 1, 1 ] )
      rr_selectfont( ::Fonts[ 1, 1 ] )
   ENDIF

RETURN self


/*
 * Routine: Endpage()
 *
 * Purpose:
 * Ends the current physical page or closes the current preview Enhanced Metafile and records its device information.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Closes the current page/metafile and, in preview mode, appends page metadata to MetaFiles.
 */
METHOD Endpage() CLASS HBPrinter

   IF ::PreviewMode
      rr_closemfile()
      AAdd( ::MetaFiles, { ::BasePageName + StrZero( Len( ::metafiles ) + 1, 4 ) + '.emf', ::DEVCAPS[ 1 ], ::DEVCAPS[ 2 ], ::DEVCAPS[ 3 ], ::DEVCAPS[ 4 ], ::DEVCAPS[ 15 ], ::DEVCAPS[ 17 ] } )
   ELSE
      rr_endpage()
   ENDIF

RETURN self


/*
 * Routine: SaveMetaFiles()
 *
 * Purpose:
 * Converts selected preview Enhanced Metafile pages, or all preview pages, to a PDF file.
 *
 * Parameters:
 * number - Harbour value - Value used by the routine as indicated by the source.
 * filename - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * May create a PDF file from preview EMF files.
 */
METHOD SaveMetaFiles( number, filename ) CLASS HBPrinter

   LOCAL aPages

   IF ::PreviewMode
      DEFAULT filename := ::DOCNAME
      aPages := {}
      IF number == NIL
         AEval( ::metafiles, {| x | AAdd( aPages, x[ 1 ] ) } )
      ELSE
         AAdd( aPages, ::BasePageName + StrZero( number, 4 ) + '.emf' )
         filename += iif( At( ".pdf", filename ) > 0, "", "_" + StrZero( number, 4 ) )
      ENDIF
      filename := hb_FNameExtSetDef( filename, ".pdf" )
      _CreatePdf( ASort( aPages ), filename, .F. )
   ENDIF

RETURN self


/*
 * Routine: EndDoc()
 *
 * Purpose:
 * Ends the current physical print document or opens the preview interface when preview mode is active.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Ends native printing or invokes the preview interface and clears PRINTING state on supported builds.
 */
METHOD EndDoc() CLASS HBPrinter

   IF ::PreviewMode
      ::preview()
   ELSE
      rr_enddoc()
   ENDIF

#ifndef __XHARBOUR__
   ::Printing := .F.
#endif

RETURN self


/*
 * Routine: SetTextColor()
 *
 * Purpose:
 * Sets the current text color, accepting either a numeric color value or an RGB component array, and returns the previous color.
 *
 * Parameters:
 * clr - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The text color that was active before the call.
 *
 * Side Effects:
 * Changes the active text color.
 */
METHOD SetTextColor( clr ) CLASS HBPrinter

   LOCAL lret := ::Textcolor

   IF clr <> NIL
      // BEGIN RL 2003-08-03
      IF ValType ( clr ) == 'N'
         ::TextColor := rr_settextcolor( clr )
      ELSEIF ValType ( clr ) == 'A'
         ::TextColor := rr_settextcolor( RGB ( clr[ 1 ], clr[ 2 ], clr[ 3 ] ) )
      ENDIF
      // END RL
   ENDIF

RETURN lret


/*
 * Routine: SetPolyFillMode()
 *
 * Purpose:
 * Sets the polygon fill mode and returns the previous fill mode.
 *
 * Parameters:
 * style - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The polygon fill mode that was active before the call.
 *
 * Side Effects:
 * Changes the stored and native polygon fill mode.
 */
METHOD SetPolyFillMode( style ) CLASS HBPrinter

   LOCAL lret := ::PolyFillMode
   ::PolyFillMode := rr_setpolyfillmode( style )

RETURN lret


/*
 * Routine: SetBkColor()
 *
 * Purpose:
 * Sets the current background color, accepting either a numeric color value or an RGB component array, and returns the previous color.
 *
 * Parameters:
 * clr - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The background color that was active before the call.
 *
 * Side Effects:
 * Changes the active background color.
 */
METHOD SetBkColor( clr ) CLASS HBPrinter

   LOCAL lret := ::BkColor

   // BEGIN RL 2003-08-03
   IF ValType ( clr ) == 'N'
      ::BkColor := rr_setbkcolor( clr )
   ELSEIF ValType ( clr ) == 'A'
      ::BkColor := rr_setbkcolor( RGB ( clr[ 1 ], clr[ 2 ], clr[ 3 ] ) )
   ENDIF
   // END RL

RETURN lret


/*
 * Routine: SetBkMode()
 *
 * Purpose:
 * Sets the text background mode and returns the previous mode.
 *
 * Parameters:
 * nmode - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The background mode that was active before the call.
 *
 * Side Effects:
 * Changes the active background mode.
 */
METHOD SetBkMode( nmode ) CLASS HBPrinter

   LOCAL lret := ::Bkmode

   ::BkMode := nmode
   rr_setbkmode( nmode )

RETURN lret


/*
 * Routine: DefineBrush()
 *
 * Purpose:
 * Creates and registers a named brush if that name is not already defined.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lstyle - Harbour value - Value used by the routine as indicated by the source.
 * lcolor - Harbour value - Value used by the routine as indicated by the source.
 * lhatch - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates a native brush and stores its handle and name.
 */
METHOD DefineBrush( defname, lstyle, lcolor, lhatch ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "B" )

   IF lhand <> 0
      RETURN self
   ENDIF
   // BEGIN RL 2003-08-03
   IF ISARRAY ( lcolor )
      lcolor := RGB ( lcolor[ 1 ], lcolor[ 2 ], lcolor[ 3 ] )
   ENDIF
   // END RL
   hb_default( @lstyle, BS_NULL )
   hb_default( @lCOLOR, 0xFFFFFF )
   hb_default( @lhatch, HS_HORIZONTAL )
   AAdd( ::Brushes[ 1 ], rr_createbrush( lstyle, lcolor, lhatch ) )
   AAdd( ::Brushes[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: SelectBrush()
 *
 * Purpose:
 * Selects a named registered brush as the current drawing brush.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Changes the currently selected native brush and stored current-brush handle.
 */
METHOD SelectBrush( defname ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "B" )

   IF lhand <> 0
      rr_selectbrush( lhand )
      ::Brushes[ 1, 1 ] := lhand
   ENDIF

RETURN self


/*
 * Routine: ModifyBrush()
 *
 * Purpose:
 * Modifies an existing named brush and reselects it when it was the currently selected brush.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lstyle - Harbour value - Value used by the routine as indicated by the source.
 * lcolor - Harbour value - Value used by the routine as indicated by the source.
 * lhatch - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Recreates/modifies the native brush and may update the currently selected brush.
 */
METHOD ModifyBrush( defname, lstyle, lcolor, lhatch ) CLASS HBPrinter

   LOCAL lhand := 0, lpos

   IF defname == "*"
      lpos := AScan( ::Brushes[ 1 ], ::Brushes[ 1, 1 ], 2 )
      IF lpos > 1
         lhand := ::Brushes[ 1, lpos ]
      ENDIF
   ELSE
      lhand := ::getobjbyname( defname, "B" )
      lpos := ::getobjbyname( defname, "B", .T. )
   ENDIF
   IF lhand == 0 .OR. lpos == 0
      ::error := 1
      RETURN self
   ENDIF
   // BEGIN RL 2003-08-03
   IF ISARRAY ( lcolor )
      lcolor := RGB ( lcolor[ 1 ], lcolor[ 2 ], lcolor[ 3 ] )
   ENDIF
   // END RL
   hb_default( @lstyle, -1 )
   hb_default( @lCOLOR, -1 )
   hb_default( @lhatch, -1 )
   ::Brushes[ 1, lpos ] := rr_modifybrush( lhand, lstyle, lcolor, lhatch )
   IF lhand == ::Brushes[ 1, 1 ]
      ::selectbrush( ::Brushes[ 2, lpos ] )
   ENDIF

RETURN self


/*
 * Routine: DefinePen()
 *
 * Purpose:
 * Creates and registers a named pen if that name is not already defined.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lstyle - Harbour value - Value used by the routine as indicated by the source.
 * lwidth - Harbour value - Value used by the routine as indicated by the source.
 * lcolor - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates a native pen and stores its handle and name.
 */
METHOD DefinePen( defname, lstyle, lwidth, lcolor ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "P" )

   IF lhand <> 0
      RETURN self
   ENDIF
   // BEGIN RL 2003-08-03
   IF ISARRAY ( lcolor )
      lcolor := RGB ( lcolor[ 1 ], lcolor[ 2 ], lcolor[ 3 ] )
   ENDIF
   // END RL
   hb_default( @lstyle, PS_SOLID )
   hb_default( @lCOLOR, 0xFFFFFF )
   hb_default( @lwidth, 0 )
   AAdd( ::Pens[ 1 ], rr_createpen( lstyle, lwidth, lcolor ) )
   AAdd( ::Pens[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: ModifyPen()
 *
 * Purpose:
 * Modifies an existing named pen and reselects it when it was the currently selected pen.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lstyle - Harbour value - Value used by the routine as indicated by the source.
 * lwidth - Harbour value - Value used by the routine as indicated by the source.
 * lcolor - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Recreates/modifies the native pen and may update the currently selected pen.
 */
METHOD ModifyPen( defname, lstyle, lwidth, lcolor ) CLASS HBPrinter

   LOCAL lhand := 0, lpos

   IF defname == "*"
      lpos := AScan( ::Pens[ 1 ], ::Pens[ 1, 1 ], 2 )
      IF lpos > 1
         lhand := ::Pens[ 1, lpos ]
      ENDIF
   ELSE
      lhand := ::getobjbyname( defname, "P" )
      lpos := ::getobjbyname( defname, "P", .T. )
   ENDIF
   IF lhand == 0 .OR. lpos <= 1
      ::error := 1
      RETURN self
   ENDIF
   // BEGIN RL 2003-08-03
   IF ISARRAY ( lcolor )
      lcolor := RGB ( lcolor[ 1 ], lcolor[ 2 ], lcolor[ 3 ] )
   ENDIF
   // END RL
   hb_default( @lstyle, -1 )
   hb_default( @lCOLOR, -1 )
   hb_default( @lwidth, -1 )
   ::Pens[ 1, lpos ] := rr_modifypen( lhand, lstyle, lwidth, lcolor )
   IF lhand == ::Pens[ 1, 1 ]
      ::selectpen( ::Pens[ 2, lpos ] )
   ENDIF

RETURN self


/*
 * Routine: SelectPen()
 *
 * Purpose:
 * Selects a named registered pen as the current drawing pen.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Changes the currently selected native pen and stored current-pen handle.
 */
METHOD SelectPen( defname ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "P" )

   IF lhand <> 0
      rr_selectpen( lhand )
      ::Pens[ 1, 1 ] := lhand
   ENDIF

RETURN self


/*
 * Routine: DefineFont()
 *
 * Purpose:
 * Creates and registers a named font using the supplied font attributes.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lfontname - Harbour value - Value used by the routine as indicated by the source.
 * lfontsize - Harbour value - Value used by the routine as indicated by the source.
 * lfontwidth - Harbour value - Value used by the routine as indicated by the source.
 * langle - Harbour value - Value used by the routine as indicated by the source.
 * lweight - Harbour value - Value used by the routine as indicated by the source.
 * litalic - Harbour value - Value used by the routine as indicated by the source.
 * lunderline - Harbour value - Value used by the routine as indicated by the source.
 * lstrikeout - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates a native font and stores its handle, name, and font attributes.
 */
METHOD DefineFont( defname, lfontname, lfontsize, lfontwidth, langle, lweight, litalic, lunderline, lstrikeout ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( lfontname, "F" )

   IF lhand <> 0
      RETURN self
   ENDIF
   lfontname := if( lfontname == NIL, "", Upper( AllTrim( lfontname ) ) )
   hb_default( @lfontsize, -1 )
   hb_default( @lfontwidth, 0 )
   hb_default( @langle, -1 )
   lweight := if( Empty( lweight ), 0, 1 )
   litalic := if( Empty( litalic ), 0, 1 )
   lunderline := if( Empty( lunderline ), 0, 1 )
   lstrikeout := if( Empty( lstrikeout ), 0, 1 )
   AAdd( ::Fonts[ 1 ], rr_createfont( lfontname, lfontsize, -lfontwidth, langle * 10, lweight, litalic, lunderline, lstrikeout ) )
   AAdd( ::Fonts[ 2 ], Upper( AllTrim( defname ) ) )
   AAdd( ::Fonts[ 4 ], { lfontname, lfontsize, lfontwidth, langle, lweight, litalic, lunderline, lstrikeout } )

RETURN self


/*
 * Routine: ModifyFont()
 *
 * Purpose:
 * Modifies the stored attributes and native font handle of an existing named font, preserving the current selection when applicable.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lfontname - Harbour value - Value used by the routine as indicated by the source.
 * lfontsize - Harbour value - Value used by the routine as indicated by the source.
 * lfontwidth - Harbour value - Value used by the routine as indicated by the source.
 * langle - Harbour value - Value used by the routine as indicated by the source.
 * lweight - Harbour value - Value used by the routine as indicated by the source.
 * lnweight - Harbour value - Value used by the routine as indicated by the source.
 * litalic - Harbour value - Value used by the routine as indicated by the source.
 * lnitalic - Harbour value - Value used by the routine as indicated by the source.
 * lunderline - Harbour value - Value used by the routine as indicated by the source.
 * lnunderline - Harbour value - Value used by the routine as indicated by the source.
 * lstrikeout - Harbour value - Value used by the routine as indicated by the source.
 * lnstrikeout - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Recreates a native font, updates stored attributes, may reselect it, and deletes the previous native font object.
 */
METHOD ModifyFont( defname, lfontname, lfontsize, lfontwidth, langle, lweight, lnweight, litalic, lnitalic, lunderline, lnunderline, lstrikeout, lnstrikeout ) CLASS HBPrinter

   LOCAL lhand := 0, lpos

   IF defname == "*"
      lpos := AScan( ::Fonts[ 1 ], ::Fonts[ 1, 1 ], 2 )
      IF lpos > 1
         lhand := ::Fonts[ 1, lpos ]
      ENDIF
   ELSE
      lhand := ::getobjbyname( defname, "F" )
      lpos := ::getobjbyname( defname, "F", .T. )
   ENDIF
   IF lhand == 0 .OR. lpos <= 1
      ::error := 1
      RETURN self
   ENDIF

   iif( lfontname <> NIL, ::Fonts[ 4, lpos, 1 ] := Upper( AllTrim( lfontname ) ), NIL )
   iif( lfontsize <> NIL, ::Fonts[ 4, lpos, 2 ] := lfontsize, NIL )
   iif( lfontwidth <> NIL, ::Fonts[ 4, lpos, 3 ] := lfontwidth, NIL )
   iif( langle <> NIL, ::Fonts[ 4, lpos, 4 ] := langle, NIL )
   iif( lweight, ::Fonts[ 4, lpos, 5 ] := 1, NIL )
   iif( lnweight, ::Fonts[ 4, lpos, 5 ] := 0, NIL )
   iif( litalic, ::Fonts[ 4, lpos, 6 ] := 1, NIL )
   iif( lnitalic, ::Fonts[ 4, lpos, 6 ] := 0, NIL )
   iif( lunderline, ::Fonts[ 4, lpos, 7 ] := 1, NIL )
   iif( lnunderline, ::Fonts[ 4, lpos, 7 ] := 0, NIL )
   iif( lstrikeout, ::Fonts[ 4, lpos, 8 ] := 1, NIL )
   iif( lnstrikeout, ::Fonts[ 4, lpos, 8 ] := 0, NIL )

   ::Fonts[ 1, lpos ] := rr_createfont( ::Fonts[ 4, lpos, 1 ], ::Fonts[ 4, lpos, 2 ], -::Fonts[ 4, lpos, 3 ], ::Fonts[ 4, lpos, 4 ] * 10, ::Fonts[ 4, lpos, 5 ], ::Fonts[ 4, lpos, 6 ], ::Fonts[ 4, lpos, 7 ], ::Fonts[ 4, lpos, 8 ] )

   IF lhand == ::Fonts[ 1, 1 ]
      ::selectfont( ::Fonts[ 2, lpos ] )
   ENDIF
   rr_deleteobjects( { 0, lhand } )

RETURN self


/*
 * Routine: SelectFont()
 *
 * Purpose:
 * Selects a named registered font as the current drawing font.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Changes the currently selected native font and stored current-font handle.
 */
METHOD SelectFont( defname ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "F" )

   IF lhand <> 0
      rr_selectfont( lhand )
      ::Fonts[ 1, 1 ] := lhand
   ENDIF

RETURN self


/*
 * Routine: SetUnits()
 *
 * Purpose:
 * Changes the coordinate unit system and recalculates the maximum row and column values from the current device capabilities.
 *
 * Parameters:
 * newvalue - Harbour value - Value used by the routine as indicated by the source.
 * r - Harbour value - Value used by the routine as indicated by the source.
 * c - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The unit mode that was active before the call.
 *
 * Side Effects:
 * Changes coordinate interpretation and recalculates MaxRow and MaxCol.
 */
METHOD SetUnits( newvalue, r, c ) CLASS HBPrinter

   LOCAL oldvalue := ::Units

   newvalue := if( ValType( newvalue ) == "N", newvalue, 0 )
   ::Units := if( newvalue < 0 .OR. newvalue > 4, 0, newvalue )
   SWITCH ::Units
   CASE 0 // ROWCOL
      ::MaxRow := ::DevCaps[ 13 ] - 1
      ::MaxCol := ::DevCaps[ 14 ] - 1
      EXIT
   CASE 1 // MM
      ::MaxRow := ::DevCaps[ 1 ] - 1
      ::MaxCol := ::DevCaps[ 2 ] - 1
      EXIT
   CASE 2 // INCHES
      ::MaxRow := ( ::DevCaps[ 1 ] / 25.4 ) - 1
      ::MaxCol := ( ::DevCaps[ 2 ] / 25.4 ) - 1
      EXIT
   CASE 3 // PIXEL
      ::MaxRow := ::DevCaps[ 3 ]
      ::MaxCol := ::DevCaps[ 4 ]
      EXIT
   CASE 4 // ROWS   COLS
      iif( ValType( r ) == "N", ::MaxRow := r - 1, NIL )
      iif( ValType( c ) == "N", ::MaxCol := c - 1, NIL )
   ENDSWITCH

RETURN oldvalue


/*
 * Routine: Convert()
 *
 * Purpose:
 * Converts a two-element coordinate or size array from the current HBPrinter unit system to device coordinates.
 *
 * Parameters:
 * arr - Harbour value - Value used by the routine as indicated by the source.
 * lsize - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Array - A converted copy of the supplied two-element array.
 *
 * Side Effects:
 * Does not modify the input array; returns a converted clone.
 */
METHOD Convert( arr, lsize ) CLASS HBPrinter

   LOCAL aret := AClone( arr )

   SWITCH ::Units
   CASE 0 // ROWCOL
      aret[ 1 ] := ( arr[ 1 ] ) * ::DEVCAPS[ 11 ]
      aret[ 2 ] := ( arr[ 2 ] ) * ::DEVCAPS[ 12 ]
      EXIT
   CASE 3 // PIXEL
      EXIT
   CASE 4 // ROWS   COLS
      aret[ 1 ] := ( arr[ 1 ] ) * ::DEVCAPS[ 3 ] / ( ::maxrow + 1 )
      aret[ 2 ] := ( arr[ 2 ] ) * ::DEVCAPS[ 4 ] / ( ::maxcol + 1 )
      EXIT
   CASE 1 // MM
      aret[ 1 ] := ( arr[ 1 ] ) * ::DEVCAPS[ 5 ] / 25.4 - if( lsize == NIL, ::DEVCAPS[ 9 ], 0 )
      aret[ 2 ] := ( arr[ 2 ] ) * ::DEVCAPS[ 6 ] / 25.4 - if( lsize == NIL, ::DEVCAPS[ 10 ], 0 )
      EXIT
   CASE 2 // INCHES
      aret[ 1 ] := ( arr[ 1 ] ) * ::DEVCAPS[ 5 ] - if( lsize == NIL, ::DEVCAPS[ 9 ], 0 )
      aret[ 2 ] := ( arr[ 2 ] ) * ::DEVCAPS[ 6 ] - if( lsize == NIL, ::DEVCAPS[ 10 ], 0 )
      EXIT
   DEFAULT
      aret[ 1 ] := ( arr[ 1 ] ) * ::DEVCAPS[ 11 ]
      aret[ 2 ] := ( arr[ 2 ] ) * ::DEVCAPS[ 12 ]
   ENDSWITCH

RETURN aret


/*
 * Routine: DrawText()
 *
 * Purpose:
 * Draws text inside the specified rectangle using the selected font definition and drawing style.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * txt - Harbour value - Value used by the routine as indicated by the source.
 * style - Harbour value - Value used by the routine as indicated by the source.
 * defname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders text through the underlying printing subsystem.
 */
METHOD DrawText( row, col, torow, tocol, txt, style, defname ) CLASS HBPrinter

   LOCAL lhf := ::getobjbyname( defname, "F" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   rr_drawtext( ::Convert( { row, col } ), ::Convert( { torow, tocol } ), txt, style, lhf )

RETURN self


/*
 * Routine: TEXTOUT()
 *
 * Purpose:
 * Outputs text at the specified position using the selected font definition.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * txt - Harbour value - Value used by the routine as indicated by the source.
 * defname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders text through the underlying printing subsystem.
 */
METHOD TEXTOUT( row, col, txt, defname ) CLASS HBPrinter

   LOCAL lhf := ::getobjbyname( defname, "F" )

   rr_textout( txt, ::Convert( { row, col } ), lhf, numat( " ", txt ) )

RETURN self


/*
 * Routine: Say()
 *
 * Purpose:
 * Outputs one or more lines of text, converting common Harbour value types to printable text and optionally applying a temporary color and text alignment.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * txt - Harbour value - Value used by the routine as indicated by the source.
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * lcolor - Harbour value - Value used by the routine as indicated by the source.
 * lalign - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders one or more lines and temporarily changes text color/alignment when requested, restoring the stored color/alignment afterward.
 */
METHOD Say( row, col, txt, defname, lcolor, lalign ) CLASS HBPrinter

   LOCAL atxt := {}, i, lhf := ::getobjbyname( defname, "F" ), oldalign
   LOCAL apos

   DO CASE
   CASE ValType( txt ) == "N" ;  AAdd( atxt, Str( txt ) )
   CASE ValType( txt ) == "D" ;  AAdd( atxt, DToC( txt ) )
   CASE ValType( txt ) == "L" ;  AAdd( atxt, if( txt, ".T.", ".F." ) )
   CASE ValType( txt ) == "U" ;  AAdd( atxt, "NIL" )
   CASE ValType( txt ) $ "BO" ;  AAdd( atxt, "" )
   CASE ValType( txt ) == "A" ;  AEval( txt, {| x | AAdd( atxt, sayconvert( x ) ) } )
   CASE ValType( txt ) $ "MC" ;  atxt := str2arr( txt, hb_osNewLine() )
   ENDCASE
   apos := ::convert( { row, col } )
   IF lcolor <> NIL
      // BEGIN RL 2003-08-03
      IF ValType ( lcolor ) == 'N'
         rr_settextcolor( lcolor )
      ELSEIF ValType ( lcolor ) == 'A'
         rr_settextcolor( RGB ( lcolor[ 1 ], lcolor[ 2 ], lcolor[ 3 ] ) )
      ENDIF
      // END RL
   ENDIF
   IF lalign <> NIL
      oldalign := rr_gettextalign()
      rr_settextalign( lalign )
   ENDIF
   FOR i := 1 TO Len( atxt )
      rr_textout( atxt[ i ], apos, lhf, numat( " ", atxt[ i ] ) )
      apos[ 1 ] += ::DEVCAPS[ 11 ]
   NEXT
   IF lalign <> NIL
      rr_settextalign( oldalign )
   ENDIF
   IF lcolor <> NIL
      rr_settextcolor( ::textcolor )
   ENDIF

RETURN self


/*
 * Routine: DefineImageList()
 *
 * Purpose:
 * Creates and registers a named image list from the specified picture resource.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * cpicture - Harbour value - Value used by the routine as indicated by the source.
 * nicons - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates a native image list and stores its handle and dimensions.
 */
METHOD DefineImageList( defname, cpicture, nicons ) CLASS HBPrinter

   LOCAL lhi := ::getobjbyname( defname, "I" ), w := 0, h := 0, hand

   IF lhi <> 0
      RETURN self
   ENDIF
   hand := rr_createimagelist( cpicture, nicons, @w, @h )
   IF hand <> 0 .AND. w > 0 .AND. h > 0
      AAdd( ::imagelists[ 1 ], { hand, nicons, w, h } )
      AAdd( ::imagelists[ 2 ], Upper( AllTrim( defname ) ) )
   ENDIF

RETURN self


/*
 * Routine: DrawImageList()
 *
 * Purpose:
 * Draws an icon from a registered image list in the specified destination area.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * nicon - Harbour value - Value used by the routine as indicated by the source.
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * lstyle - Harbour value - Value used by the routine as indicated by the source.
 * color - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders an icon and updates Error with the underlying operation result.
 */
METHOD DrawImageList( defname, nicon, row, col, torow, tocol, lstyle, color ) CLASS HBPrinter

   LOCAL lhi := ::getobjbyname( defname, "I" )

   IF Empty( lhi )
      RETURN self
   ENDIF
   hb_default( @COLOR, -1 )
   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error := rr_drawimagelist( lhi[ 1 ], nicon, ::convert( { row, col } ), ::convert( { torow - row, tocol - col } ), lhi[ 3 ], lhi[ 4 ], lstyle, color )

RETURN self


/*
 * Routine: Rectangle()
 *
 * Purpose:
 * Sets the viewport origin from the supplied position and leaves the current drawing viewport at that origin.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Changes the viewport origin used by subsequent drawing operations.
 */
METHOD Rectangle( row, col, torow, tocol, defpen, defbrush ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" ), lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_rectangle( ::convert( { row, col } ), ::convert( { torow, tocol } ), lhp, lhb )

RETURN self


/*
 * Routine: FrameRect()
 *
 * Purpose:
 * Draws a rectangular frame using the specified brush.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a rectangular frame.
 */
METHOD FrameRect( row, col, torow, tocol, defbrush ) CLASS HBPrinter

   LOCAL lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_framerect( ::convert( { row, col } ), ::convert( { torow, tocol } ), lhb )

RETURN self


/*
 * Routine: RoundRect()
 *
 * Purpose:
 * Draws a rounded rectangle using the specified pen and brush.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * widthellipse - Harbour value - Value used by the routine as indicated by the source.
 * heightellipse - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a rounded rectangle.
 */
METHOD RoundRect( row, col, torow, tocol, widthellipse, heightellipse, defpen, defbrush ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" ), lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_roundrect( ::convert( { row, col } ), ::convert( { torow, tocol } ), ::convert( { widthellipse, heightellipse } ), lhp, lhb )

RETURN self


/*
 * Routine: FillRect()
 *
 * Purpose:
 * Fills a rectangle using the specified brush.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a filled rectangle.
 */
METHOD FillRect( row, col, torow, tocol, defbrush ) CLASS HBPrinter

   LOCAL lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_fillrect( ::convert( { row, col } ), ::convert( { torow, tocol } ), lhb )

RETURN self


/*
 * Routine: InvertRect()
 *
 * Purpose:
 * Inverts the pixels in the specified rectangle.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Inverts the specified drawing area.
 */
METHOD InvertRect( row, col, torow, tocol ) CLASS HBPrinter

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_invertrect( ::convert( { row, col } ), ::convert( { torow, tocol } ) )

RETURN self


/*
 * Routine: Ellipse()
 *
 * Purpose:
 * Draws an ellipse using the specified pen and brush.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders an ellipse.
 */
METHOD Ellipse( row, col, torow, tocol, defpen, defbrush ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" ), lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_ellipse( ::convert( { row, col } ), ::convert( { torow, tocol } ), lhp, lhb )

RETURN self


/*
 * Routine: Arc()
 *
 * Purpose:
 * Draws an arc defined by a bounding rectangle and two endpoint coordinates.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * rowsarc - Harbour value - Value used by the routine as indicated by the source.
 * colsarc - Harbour value - Value used by the routine as indicated by the source.
 * rowearc - Harbour value - Value used by the routine as indicated by the source.
 * colearc - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders an arc.
 */
METHOD Arc( row, col, torow, tocol, rowsarc, colsarc, rowearc, colearc, defpen ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_arc( ::convert( { row, col } ), ::convert( { torow, tocol } ), ::convert( { rowsarc, colsarc } ), ::convert( { rowearc, colearc } ), lhp )

RETURN self


/*
 * Routine: ArcTo()
 *
 * Purpose:
 * Draws an arc using the specified bounding rectangle and radial endpoint coordinates.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * rowrad1 - Harbour value - Value used by the routine as indicated by the source.
 * colrad1 - Harbour value - Value used by the routine as indicated by the source.
 * rowrad2 - Harbour value - Value used by the routine as indicated by the source.
 * colrad2 - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders an arc from the current drawing context according to the supplied geometry.
 */
METHOD ArcTo( row, col, torow, tocol, rowrad1, colrad1, rowrad2, colrad2, defpen ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_arcto( ::convert( { row, col } ), ::convert( { torow, tocol } ), ::convert( { rowrad1, colrad1 } ), ::convert( { rowrad2, colrad2 } ), lhp )

RETURN self


/*
 * Routine: Chord()
 *
 * Purpose:
 * Draws a chord using the specified bounding rectangle, radial endpoints, pen, and brush.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * rowrad1 - Harbour value - Value used by the routine as indicated by the source.
 * colrad1 - Harbour value - Value used by the routine as indicated by the source.
 * rowrad2 - Harbour value - Value used by the routine as indicated by the source.
 * colrad2 - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a chord.
 */
METHOD Chord( row, col, torow, tocol, rowrad1, colrad1, rowrad2, colrad2, defpen, defbrush ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" ), lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_chord( ::convert( { row, col } ), ::convert( { torow, tocol } ), ::convert( { rowrad1, colrad1 } ), ::convert( { rowrad2, colrad2 } ), lhp, lhb )

RETURN self


/*
 * Routine: Pie()
 *
 * Purpose:
 * Draws a pie-shaped sector using the specified bounding rectangle, radial endpoints, pen, and brush.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * rowrad1 - Harbour value - Value used by the routine as indicated by the source.
 * colrad1 - Harbour value - Value used by the routine as indicated by the source.
 * rowrad2 - Harbour value - Value used by the routine as indicated by the source.
 * colrad2 - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a pie sector.
 */
METHOD Pie( row, col, torow, tocol, rowrad1, colrad1, rowrad2, colrad2, defpen, defbrush ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" ), lhb := ::getobjbyname( defbrush, "B" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_pie( ::convert( { row, col } ), ::convert( { torow, tocol } ), ::convert( { rowrad1, colrad1 } ), ::convert( { rowrad2, colrad2 } ), lhp, lhb )

RETURN self


/*
 * Routine: Polygon()
 *
 * Purpose:
 * Draws a polygon from the supplied point array using the specified pen, brush, and polygon fill style.
 *
 * Parameters:
 * apoints - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 * defbrush - Harbour value - Value used by the routine as indicated by the source.
 * style - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a polygon and updates Error with the native operation result.
 */
METHOD Polygon( apoints, defpen, defbrush, style ) CLASS HBPrinter

   LOCAL apx := {}, apy := {}, temp
   LOCAL lhp := ::getobjbyname( defpen, "P" ), lhb := ::getobjbyname( defbrush, "B" )

   AEval( apoints, {| x | temp := ::convert( x ), AAdd( apx, temp[ 2 ] ), AAdd( apy, temp[ 1 ] ) } )
   ::error := rr_polygon( apx, apy, lhp, lhb, style )

RETURN self


/*
 * Routine: PolyBezier()
 *
 * Purpose:
 * Draws a Bezier curve sequence from the supplied point array using the specified pen.
 *
 * Parameters:
 * apoints - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders Bezier curves and updates Error with the native operation result.
 */
METHOD PolyBezier( apoints, defpen ) CLASS HBPrinter

   LOCAL apx := {}, apy := {}, temp
   LOCAL lhp := ::getobjbyname( defpen, "P" )

   AEval( apoints, {| x | temp := ::convert( x ), AAdd( apx, temp[ 2 ] ), AAdd( apy, temp[ 1 ] ) } )
   ::error := rr_polybezier( apx, apy, lhp )

RETURN self


/*
 * Routine: PolyBezierTo()
 *
 * Purpose:
 * Draws a connected Bezier curve sequence from the current drawing position using the supplied point array and pen.
 *
 * Parameters:
 * apoints - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders connected Bezier curves and updates Error with the native operation result.
 */
METHOD PolyBezierTo( apoints, defpen ) CLASS HBPrinter

   LOCAL apx := {}, apy := {}, temp
   LOCAL lhp := ::getobjbyname( defpen, "P" )

   AEval( apoints, {| x | temp := ::convert( x ), AAdd( apx, temp[ 2 ] ), AAdd( apy, temp[ 1 ] ) } )
   ::error := rr_polybezierto( apx, apy, lhp )

RETURN self


/*
 * Routine: Line()
 *
 * Purpose:
 * Draws a line between two positions using the specified pen.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a line and updates Error with the native operation result.
 */
METHOD Line( row, col, torow, tocol, defpen ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" )

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   ::error = rr_line( ::convert( { row, col } ), ::convert( { torow, tocol } ), lhp )

RETURN self


/*
 * Routine: LineTo()
 *
 * Purpose:
 * Draws a line from the current drawing position to the specified position using the specified pen.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * defpen - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders a line from the current position and updates Error with the native operation result.
 */
METHOD LineTo( row, col, defpen ) CLASS HBPrinter

   LOCAL lhp := ::getobjbyname( defpen, "P" )

   ::error = rr_lineto( ::convert( { row, col } ), lhp )

RETURN self


/*
 * Routine: GetTextExtent()
 *
 * Purpose:
 * Calculates the device-space extent of a text string using the specified font and stores the result in the supplied point array.
 *
 * Parameters:
 * ctext - Harbour value - Value used by the routine as indicated by the source.
 * apoint - Harbour value - Value used by the routine as indicated by the source.
 * deffont - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object; the calculated dimensions are written to apoint.
 *
 * Side Effects:
 * Writes calculated text dimensions into the supplied array and updates Error.
 */
METHOD GetTextExtent( ctext, apoint, deffont ) CLASS HBPrinter

   LOCAL lhf := ::getobjbyname( deffont, "F" )

   ::error = rr_gettextextent( ctext, apoint, lhf )

RETURN self


/*
 * Routine: GetTextExtent_mm()
 *
 * Purpose:
 * Calculates text extent and converts the resulting dimensions to millimetres using the current device capabilities.
 *
 * Parameters:
 * ctext - Harbour value - Value used by the routine as indicated by the source.
 * apoint - Harbour value - Value used by the routine as indicated by the source.
 * deffont - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object; the converted dimensions are written to apoint.
 *
 * Side Effects:
 * Writes calculated text dimensions converted to millimetres into the supplied array and updates Error.
 */
METHOD GetTextExtent_mm( ctext, apoint, deffont ) CLASS HBPrinter

   LOCAL lhf := ::getobjbyname( deffont, "F" )

   ::error = rr_gettextextent( ctext, apoint, lhf )
   apoint[ 1 ] := 25.4 * apoint[ 1 ] / ::DevCaps[ 5 ]
   apoint[ 2 ] := 25.4 * apoint[ 2 ] / ::DevCaps[ 6 ]

RETURN self


/*
 * Routine: GetObjByName()
 *
 * Purpose:
 * Looks up a named registered printer resource by resource type and returns either its handle or its registry position.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * what - Harbour value - Value used by the routine as indicated by the source.
 * retpos - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - A resource handle, or a registry position when retpos is supplied; zero means not found.
 *
 * Side Effects:
 * Reads the object registry without changing it.
 */
METHOD GetObjByName( defname, what, retpos ) CLASS HBPrinter

   LOCAL lfound, lret := 0, aref, ahref

   IF ValType( defname ) == "C"
      DO CASE
      CASE what == "F" ; aref := ::Fonts[ 2 ] ; ahref := ::Fonts[ 1 ]
      CASE what == "B" ; aref := ::Brushes[ 2 ] ; ahref := ::Brushes[ 1 ]
      CASE what == "P" ; aref := ::Pens[ 2 ] ; ahref := ::Pens[ 1 ]
      CASE what == "R" ; aref := ::Regions[ 2 ] ; ahref := ::Regions[ 1 ]
      CASE what == "I" ; aref := ::ImageLists[ 2 ] ; ahref := ::ImageLists[ 1 ]
      ENDCASE
      lfound := AScan( aref, Upper( AllTrim( defname ) ) )
      IF lfound > 0
         IF aref[ lfound ] == Upper( AllTrim( defname ) )
            IF retpos <> NIL
               lret := lfound
            ELSE
               lret := ahref[ lfound ]
            ENDIF
         ENDIF
      ENDIF
   ENDIF

RETURN lret


/*
 * Routine: DefineRectRgn()
 *
 * Purpose:
 * Creates and registers a named rectangular clipping region.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates and registers a native rectangular region.
 */
METHOD DefineRectRgn( defname, row, col, torow, tocol ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "R" )

   IF lhand <> 0
      RETURN self
   ENDIF
   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   AAdd( ::Regions[ 1 ], rr_creatergn( ::convert( { row, col } ), ::convert( { torow, tocol } ), 1 ) )
   AAdd( ::Regions[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: DefineEllipticRgn()
 *
 * Purpose:
 * Creates and registers a named elliptical clipping region.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates and registers a native elliptical region.
 */
METHOD DefineEllipticRgn( defname, row, col, torow, tocol ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "R" )

   IF lhand <> 0
      RETURN self
   ENDIF
   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   AAdd( ::Regions[ 1 ], rr_creatergn( ::convert( { row, col } ), ::convert( { torow, tocol } ), 2 ) )
   AAdd( ::Regions[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: DefineRoundRectRgn()
 *
 * Purpose:
 * Creates and registers a named rounded-rectangle clipping region.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * widthellipse - Harbour value - Value used by the routine as indicated by the source.
 * heightellipse - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates and registers a native rounded region.
 */
METHOD DefineRoundRectRgn( defname, row, col, torow, tocol, widthellipse, heightellipse ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "R" )

   IF lhand <> 0
      RETURN self
   ENDIF
   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   AAdd( ::Regions[ 1 ], rr_creatergn( ::convert( { row, col } ), ::convert( { torow, tocol } ), 3, ::convert( { widthellipse, heightellipse } ) ) )
   AAdd( ::Regions[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: DefinePolygonRgn()
 *
 * Purpose:
 * Creates and registers a named polygon clipping region from the supplied points.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * apoints - Harbour value - Value used by the routine as indicated by the source.
 * style - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates and registers a native polygon region.
 */
METHOD DefinePolygonRgn( defname, apoints, style ) CLASS HBPrinter

   LOCAL apx := {}, apy := {}, temp
   LOCAL lhand := ::getobjbyname( defname, "R" )

   IF lhand <> 0
      RETURN self
   ENDIF
   AEval( apoints, {| x | temp := ::convert( x ), AAdd( apx, temp[ 2 ] ), AAdd( apy, temp[ 1 ] ) } )
   AAdd( ::Regions[ 1 ], rr_createPolygonrgn( apx, apy, style ) )
   AAdd( ::Regions[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: CombineRgn()
 *
 * Purpose:
 * Creates and registers a named region obtained by combining two existing regions with the specified combination style.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 * reg1 - Harbour value - Value used by the routine as indicated by the source.
 * reg2 - Harbour value - Value used by the routine as indicated by the source.
 * style - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Creates and registers a combined native region.
 */
METHOD CombineRgn( defname, reg1, reg2, style ) CLASS HBPrinter

   LOCAL lr1 := ::getobjbyname( reg1, "R" ), lr2 := ::getobjbyname( reg2, "R" )
   LOCAL lhand := ::getobjbyname( defname, "R" )

   IF lhand <> 0 .OR. lr1 == 0 .OR. lr2 == 0
      RETURN self
   ENDIF
   AAdd( ::Regions[ 1 ], rr_combinergn( lr1, lr2, style ) )
   AAdd( ::Regions[ 2 ], Upper( AllTrim( defname ) ) )

RETURN self


/*
 * Routine: SelectClipRgn()
 *
 * Purpose:
 * Selects a named region as the current clipping region.
 *
 * Parameters:
 * defname - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Changes the active clipping region and stored current-region handle.
 */
METHOD SelectClipRgn( defname ) CLASS HBPrinter

   LOCAL lhand := ::getobjbyname( defname, "R" )

   IF lhand <> 0
      rr_selectcliprgn( lhand )
      ::Regions[ 1, 1 ] := lhand
   ENDIF

RETURN self


/*
 * Routine: DeleteClipRgn()
 *
 * Purpose:
 * Removes the current clipping region and resets the stored current-region handle.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Clears the active clipping region and stored current-region handle.
 */
METHOD DeleteClipRgn() CLASS HBPrinter

   ::Regions[ 1, 1 ] := 0
   rr_deletecliprgn()

RETURN self


/*
 * Routine: SetViewPortOrg()
 *
 * Purpose:
 * Sets the viewport origin after converting the supplied coordinates according to the current unit system.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Changes the stored and native viewport origin.
 */
METHOD SetViewPortOrg( row, col ) CLASS HBPrinter

   row := if( row <> NIL, row, 0 )
   col := if( col <> NIL, col, 0 )
   ::ViewPortOrg := ::convert( { row, col } )
   rr_setviewportorg( ::ViewPortOrg )

RETURN self


/*
 * Routine: GetViewPortOrg()
 *
 * Purpose:
 * Retrieves the current viewport origin into the object state.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Updates the stored viewport origin from the printing subsystem.
 */
METHOD GetViewPortOrg() CLASS HBPrinter

   rr_getviewportorg( ::ViewPortOrg )

RETURN self


/*
 * Routine: End()
 *
 * Purpose:
 * Releases preview files, printer device resources, registered GDI objects, image lists, and the underlying printing support.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * NIL - No meaningful return value; printer and associated resources are released.
 *
 * Side Effects:
 * Deletes preview EMF files and native printer/GDI resources and finishes the printing subsystem.
 */
METHOD End() CLASS HBPrinter

   IF ::PreviewMode
      AEval( ::metafiles, {| x | FErase( x[ 1 ] ) } )
      ::MetaFiles := {}
   ENDIF
   IF ::HDCRef != 0
      ef_resetprinter()
      rr_deletedc( ::HDCRef )
   ENDIF
   rr_deleteobjects( ::Fonts[ 1 ] )
   rr_deleteobjects( ::Brushes[ 1 ] )
   rr_deleteobjects( ::Pens[ 1 ] )
   rr_deleteobjects( ::Regions[ 1 ] )
   rr_deleteimagelists( ::ImageLists[ 1 ] )
   rr_finish()

RETURN NIL


/*
 * Routine: DXCOLORS()
 *
 * Purpose:
 * Resolves a named or indexed color from the internal RGB color-name table.
 *
 * Parameters:
 * par - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The native color value, or zero when the supplied name/index is not resolved.
 *
 * Side Effects:
 * May initialize the shared RGB color-name table on first use.
 */
METHOD DXCOLORS( par ) CLASS HBPrinter

   LOCAL ltemp := 0, aColorNames

   IF _SetGetGlobal( "rgbColorNames" ) == NIL
      STATIC rgbColorNames AS GLOBAL VALUE ;
      { { "aliceblue", 0xfffff8f0 }, ;
      { "antiquewhite", 0xffd7ebfa }, ;
      { "aqua", 0xffffff00 }, ;
      { "aquamarine", 0xffd4ff7f }, ;
      { "azure", 0xfffffff0 }, ;
      { "beige", 0xffdcf5f5 }, ;
      { "bisque", 0xffc4e4ff }, ;
      { "black", 0xff000000 }, ;
      { "blanchedalmond", 0xffcdebff }, ;
      { "blue", 0xffff0000 }, ;
      { "blueviolet", 0xffe22b8a }, ;
      { "brown", 0xff2a2aa5 }, ;
      { "burlywood", 0xff87b8de }, ;
      { "cadetblue", 0xffa09e5f }, ;
      { "chartreuse", 0xff00ff7f }, ;
      { "chocolate", 0xff1e69d2 }, ;
      { "coral", 0xff507fff }, ;
      { "cornflowerblue", 0xffed9564 }, ;
      { "cornsilk", 0xffdcf8ff }, ;
      { "crimson", 0xff3c14dc }, ;
      { "cyan", 0xffffff00 }, ;
      { "darkblue", 0xff8b0000 }, ;
      { "darkcyan", 0xff8b8b00 }, ;
      { "darkgoldenrod", 0xff0b86b8 }, ;
      { "darkgray", 0xffa9a9a9 }, ;
      { "darkgreen", 0xff006400 }, ;
      { "darkkhaki", 0xff6bb7bd }, ;
      { "darkmagenta", 0xff8b008b }, ;
      { "darkolivegreen", 0xff2f6b55 }, ;
      { "darkorange", 0xff008cff }, ;
      { "darkorchid", 0xffcc3299 }, ;
      { "darkred", 0xff00008b }, ;
      { "darksalmon", 0xff7a96e9 }, ;
      { "darkseagreen", 0xff8fbc8f }, ;
      { "darkslateblue", 0xff8b3d48 }, ;
      { "darkslategray", 0xff4f4f2f }, ;
      { "darkturquoise", 0xffd1ce00 }, ;
      { "darkviolet", 0xffd30094 }, ;
      { "deeppink", 0xff9314ff }, ;
      { "deepskyblue", 0xffffbf00 }, ;
      { "dimgray", 0xff696969 }, ;
      { "dodgerblue", 0xffff901e }, ;
      { "firebrick", 0xff2222b2 }, ;
      { "floralwhite", 0xfff0faff }, ;
      { "forestgreen", 0xff228b22 }, ;
      { "fuchsia", 0xffff00ff }, ;
      { "gainsboro", 0xffdcdcdc }, ;
      { "ghostwhite", 0xfffff8f8 }, ;
      { "gold", 0xff00d7ff }, ;
      { "goldenrod", 0xff20a5da }, ;
      { "gray", 0xff808080 }, ;
      { "green", 0xff008000 }, ;
      { "greenyellow", 0xff2fffad }, ;
      { "honeydew", 0xfff0fff0 }, ;
      { "hotpink", 0xffb469ff }, ;
      { "indianred", 0xff5c5ccd }, ;
      { "indigo", 0xff82004b }, ;
      { "ivory", 0xfff0ffff }, ;
      { "khaki", 0xff8ce6f0 }, ;
      { "lavender", 0xfffae6e6 }, ;
      { "lavenderblush", 0xfff5f0ff }, ;
      { "lawngreen", 0xff00fc7c }, ;
      { "lemonchiffon", 0xffcdfaff }, ;
      { "lightblue", 0xffe6d8ad }, ;
      { "lightcoral", 0xff8080f0 }, ;
      { "lightcyan", 0xffffffe0 }, ;
      { "lightgoldenrodyellow", 0xffd2fafa }, ;
      { "lightgreen", 0xff90ee90 }, ;
      { "lightgrey", 0xffd3d3d3 }, ;
      { "lightpink", 0xffc1b6ff }, ;
      { "lightsalmon", 0xff7aa0ff }, ;
      { "lightseagreen", 0xffaab220 }, ;
      { "lightskyblue", 0xffface87 }, ;
      { "lightslategray", 0xff998877 }, ;
      { "lightsteelblue", 0xffdec4b0 }, ;
      { "lightyellow", 0xffe0ffff }, ;
      { "lime", 0xff00ff00 }, ;
      { "limegreen", 0xff32cd32 }, ;
      { "linen", 0xffe6f0fa }, ;
      { "magenta", 0xffff00ff }, ;
      { "maroon", 0xff000080 }, ;
      { "mediumaquamarine", 0xffaacd66 }, ;
      { "mediumblue", 0xffcd0000 }, ;
      { "mediumorchid", 0xffd355ba }, ;
      { "mediumpurple", 0xffdb7093 }, ;
      { "mediumseagreen", 0xff71b33c }, ;
      { "mediumslateblue", 0xffee687b }, ;
      { "mediumspringgreen", 0xff9afa00 }, ;
      { "mediumturquoise", 0xffccd148 }, ;
      { "mediumvioletred", 0xff8515c7 }, ;
      { "midnightblue", 0xff701919 }, ;
      { "mintcream", 0xfffafff5 }, ;
      { "mistyrose", 0xffe1e4ff }, ;
      { "moccasin", 0xffb5e4ff }, ;
      { "navajowhite", 0xffaddeff }, ;
      { "navy", 0xff800000 }, ;
      { "oldlace", 0xffe6f5fd }, ;
      { "olive", 0xff008080 }, ;
      { "olivedrab", 0xff238e6b }, ;
      { "orange", 0xff00a5ff }, ;
      { "orangered", 0xff0045ff }, ;
      { "orchid", 0xffd670da }, ;
      { "palegoldenrod", 0xffaae8ee }, ;
      { "palegreen", 0xff98fb98 }, ;
      { "paleturquoise", 0xffeeeeaf }, ;
      { "palevioletred", 0xff9370db }, ;
      { "papayawhip", 0xffd5efff }, ;
      { "peachpuff", 0xffb9daff }, ;
      { "peru", 0xff3f85cd }, ;
      { "pink", 0xffcbc0ff }, ;
      { "plum", 0xffdda0dd }, ;
      { "powderblue", 0xffe6e0b0 }, ;
      { "purple", 0xff800080 }, ;
      { "red", 0xff0000ff }, ;
      { "rosybrown", 0xff8f8fbc }, ;
      { "royalblue", 0xffe16941 }, ;
      { "saddlebrown", 0xff13458b }, ;
      { "salmon", 0xff7280fa }, ;
      { "sandybrown", 0xff60a4f4 }, ;
      { "seagreen", 0xff578b2e }, ;
      { "seashell", 0xffeef5ff }, ;
      { "sienna", 0xff2d52a0 }, ;
      { "silver", 0xffc0c0c0 }, ;
      { "skyblue", 0xffebce87 }, ;
      { "slateblue", 0xffcd5a6a }, ;
      { "slategray", 0xff908070 }, ;
      { "snow", 0xfffafaff }, ;
      { "springgreen", 0xff7fff00 }, ;
      { "steelblue", 0xffb48246 }, ;
      { "tan", 0xff8cb4d2 }, ;
      { "teal", 0xff808000 }, ;
      { "thistle", 0xffd8bfd8 }, ;
      { "tomato", 0xff4763ff }, ;
      { "turquoise", 0xffd0e040 }, ;
      { "violet", 0xffee82ee }, ;
      { "wheat", 0xffb3def5 }, ;
      { "white", 0xffffffff }, ;
      { "whitesmoke", 0xfff5f5f5 }, ;
      { "yellow", 0xff00ffff }, ;
      { "yellowgreen", 0xff32cd9a } }
   ENDIF

   aColorNames := _SetGetGlobal( "rgbcolornames" )
   IF ValType( par ) == "C"
      par := Lower( AllTrim( par ) )
      AEval( aColorNames, {| x | if( x[ 1 ] == par, ltemp := x[ 2 ], '' ) } )
   ELSEIF ValType( par ) == "N"
      ltemp := if( par <= Len( aColorNames ), aColorNames[ par, 2 ], 0 )
   ENDIF

RETURN ltemp


/*
 * Routine: SetRGB()
 *
 * Purpose:
 * Builds a native RGB color value from the supplied red, green, and blue components.
 *
 * Parameters:
 * red - Harbour value - Value used by the routine as indicated by the source.
 * green - Harbour value - Value used by the routine as indicated by the source.
 * blue - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The native RGB color value returned by the printing subsystem.
 *
 * Side Effects:
 * No object state is changed; the native subsystem constructs the color value.
 */
METHOD SetRGB( red, green, blue ) CLASS HBPrinter

RETURN rr_setrgb( red, green, blue )


/*
 * Routine: SetTextCharExtra()
 *
 * Purpose:
 * Sets the extra character spacing after converting the requested spacing to device units.
 *
 * Parameters:
 * col - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The result returned by the underlying character-spacing operation.
 *
 * Side Effects:
 * Changes character spacing in the printing subsystem.
 */
METHOD SetTextCharExtra( col ) CLASS HBPrinter

   LOCAL p1 := ::convert( { 0, 0 } ), p2 := ::convert( { 0, col } )

RETURN rr_SetTextCharExtra( p2[ 2 ] - p1[ 2 ] )


/*
 * Routine: GetTextCharExtra()
 *
 * Purpose:
 * Returns the current extra character spacing from the printing subsystem.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Numeric - The current character-spacing value.
 *
 * Side Effects:
 * Reads the current character-spacing setting.
 */
METHOD GetTextCharExtra() CLASS HBPrinter

RETURN rr_GetTextCharExtra()


/*
 * Routine: SetTextJustification()
 *
 * Purpose:
 * Sets text justification spacing after converting the requested value to device units.
 *
 * Parameters:
 * col - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The result returned by the underlying text-justification operation.
 *
 * Side Effects:
 * Changes text justification in the printing subsystem.
 */
METHOD SetTextJustification( col ) CLASS HBPrinter

   LOCAL p1 := ::convert( { 0, 0 } ), p2 := ::convert( { 0, col } )

RETURN rr_SetTextJustification( p2[ 2 ] - p1[ 2 ] )


/*
 * Routine: GetTextJustification()
 *
 * Purpose:
 * Returns the current text justification value from the printing subsystem.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Numeric - The current text-justification value.
 *
 * Side Effects:
 * Reads the current text-justification setting.
 */
METHOD GetTextJustification() CLASS HBPrinter

RETURN rr_GetTextJustification()


/*
 * Routine: SetTextAlign()
 *
 * Purpose:
 * Sets the text alignment mode in the printing subsystem.
 *
 * Parameters:
 * style - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The result returned by the underlying text-alignment operation.
 *
 * Side Effects:
 * Changes text alignment in the printing subsystem.
 */
METHOD SetTextAlign( style ) CLASS HBPrinter

RETURN rr_settextalign( style )


/*
 * Routine: GetTextAlign()
 *
 * Purpose:
 * Returns the current text alignment mode.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Numeric - The current text-alignment value.
 *
 * Side Effects:
 * Reads the current text-alignment setting.
 */
METHOD GetTextAlign() CLASS HBPrinter

RETURN rr_gettextalign()


/*
 * Routine: Picture()
 *
 * Purpose:
 * Draws a picture in the specified destination area with optional extension offsets.
 *
 * Parameters:
 * row - Harbour value - Value used by the routine as indicated by the source.
 * col - Harbour value - Value used by the routine as indicated by the source.
 * torow - Harbour value - Value used by the routine as indicated by the source.
 * tocol - Harbour value - Value used by the routine as indicated by the source.
 * cpicture - Harbour value - Value used by the routine as indicated by the source.
 * extrow - Harbour value - Value used by the routine as indicated by the source.
 * extcol - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Renders the supplied picture through the printing subsystem.
 */
METHOD Picture( row, col, torow, tocol, cpicture, extrow, extcol ) CLASS HBPrinter

   LOCAL lp1 := ::convert( { row, col } ), lp2, lp3

   hb_default( @torow, ::maxrow )
   hb_default( @tocol, ::maxcol )
   lp2 := ::convert( { torow, tocol }, 1 )
   hb_default( @extrow, 0 )
   hb_default( @extcol, 0 )
   lp3 := ::convert( { extrow, extcol } )
   rr_drawpicture( cpicture, lp1, lp2, lp3 )

RETURN self


/*
 * Routine: sayconvert()
 *
 * Purpose:
 * Converts a single Harbour value to the character representation used by Say().
 *
 * Parameters:
 * ltxt - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Character - The printable character representation of the supplied value; an unsupported type produces an empty string.
 *
 * Side Effects:
 * Does not change external state.
 */
STATIC FUNCTION sayconvert( ltxt )

   DO CASE
   CASE ValType( ltxt ) $ "MC" ;  RETURN ltxt
   CASE ValType( ltxt ) == "N" ;  RETURN Str( ltxt )
   CASE ValType( ltxt ) == "D" ;  RETURN DToC( ltxt )
   CASE ValType( ltxt ) == "L" ;  RETURN IF( ltxt, ".T.", ".F." )
   ENDCASE

RETURN ""


/*
 * Routine: str2arr()
 *
 * Purpose:
 * Splits a character list into an array using a character, numeric, or array delimiter specification.
 *
 * Parameters:
 * cList - Harbour value - Value used by the routine as indicated by the source.
 * cDelimiter - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Array - The array produced from the supplied list.
 *
 * Side Effects:
 * Does not change external state other than its local parsing variables.
 */
STATIC FUNCTION str2arr( cList, cDelimiter )

   LOCAL nPos
   LOCAL aList := {}
   LOCAL nlencd := 0
   LOCAL asub
   DO CASE
   CASE ValType( cDelimiter ) == 'C'
      cDelimiter := if( cDelimiter == NIL, ",", cDelimiter )
      nlencd := Len( cdelimiter )
      DO WHILE ( nPos := At( cDelimiter, cList ) ) != 0
         AAdd( aList, SubStr( cList, 1, nPos - 1 ) )
         cList := SubStr( cList, nPos + nlencd )
      ENDDO
      AAdd( aList, cList )
   CASE ValType( cDelimiter ) == 'N'
      DO WHILE Len( ( nPos := Left( cList, cDelimiter ) ) ) == cDelimiter
         AAdd( aList, nPos )
         cList := SubStr( cList, cDelimiter + 1 )
      ENDDO
   CASE ValType( cDelimiter ) == 'A'
      AEval( cDelimiter, {| x | nlencd += x } )
      DO WHILE Len( ( nPos := Left( cList, nlencd ) ) ) == nlencd
         asub := {}
         AEval( cDelimiter, {| x | AAdd( asub, Left( nPos, x ) ), nPos := SubStr( nPos, x + 1 ) } )
         AAdd( aList, asub )
         cList := SubStr( cList, nlencd + 1 )
      ENDDO
   ENDCASE

RETURN ( aList )

#ifdef HB_DYNLIB
/*
 * Routine: NumAt()
 *
 * Purpose:
 * Counts the occurrences of a search string within a larger string, using successive substring searches.
 *
 * Parameters:
 * cSearch - Harbour value - Value used by the routine as indicated by the source.
 * cString - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * Numeric - The number of occurrences found.
 *
 * Side Effects:
 * Does not change external state.
 */
STATIC FUNCTION NumAt( cSearch, cString )

   LOCAL n := 0, nAt, nPos := 0

   DO WHILE ( nAt := At( cSearch, SubStr( cString, nPos + 1 ) ) ) > 0
      nPos += nAt
      ++n
   ENDDO

RETURN n

#endif

/*
 * Routine: PrevThumb()
 *
 * Purpose:
 * Updates the preview thumbnail page group or selects a thumbnail page when a thumbnail index is supplied.
 *
 * Parameters:
 * nclick - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Updates preview thumbnail controls and the current preview page when applicable.
 */
METHOD PrevThumb( nclick ) CLASS HBPrinter

   LOCAL i, spage

   IF iloscstron == 1
      RETURN self
   ENDIF
   IF nclick <> NIL
      page := ngroup * 15 + nclick
      ::prevshow()
      SetProperty ( 'hbpreview', 'combo_1', 'value', Page )
      RETURN self
   ENDIF
   IF Int( ( page - 1 ) / 15 ) <> ngroup
      ngroup := Int( ( page - 1 ) / 15 )
   ELSE
      RETURN self
   ENDIF
   spage := ngroup * 15

   FOR i := 1 TO 15
      IF i + spage > iloscstron
         HideWindow( ath[ i, 5 ] )
      ELSE
         IF ::Metafiles[ i + spage, 2 ] >= ::Metafiles[ i + spage, 3 ]
            ath[ i, 3 ] := dy - 5
            ath[ i, 4 ] := dx * ::Metafiles[ i + spage, 3 ] / ::Metafiles[ i + spage, 2 ] - 5
         ELSE
            ath[ i, 4 ] := dx - 5
            ath[ i, 3 ] := dy * ::Metafiles[ i + spage, 2 ] / ::Metafiles[ i + spage, 3 ] - 5
         ENDIF
         rr_playthumb( ath[ i ], ::Metafiles[ i + spage, 1 ], AllTrim( Str( i + spage ) ), i )
         CShowControl( ath[ i, 5 ] )
      ENDIF
   NEXT

RETURN self


/*
 * Routine: PrevShow()
 *
 * Purpose:
 * Refreshes the displayed preview page, including zoom, scroll ranges, thumbnail state, and metafile rendering.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Updates preview image dimensions, scroll ranges, status text, and rendered metafile content.
 */
METHOD PrevShow() CLASS HBPrinter

   LOCAL spos := { 0, 0 }

   IF ::Thumbnails
      ::Prevthumb()
   ENDIF
   IF ! Empty( azoom[ 3 ] ) .AND. ! Empty( azoom[ 4 ] )
      spos[ 1 ] := GetScrollpos( ahs[ 5, 7 ], SB_HORZ ) / azoom[ 4 ]
      spos[ 2 ] := GetScrollpos( ahs[ 5, 7 ], SB_VERT ) / ( azoom[ 3 ] )
   ENDIF
   IF ::MetaFiles[ page, 2 ] >= ::MetaFiles[ page, 3 ]
      azoom[ 3 ] := ( ahs[ 5, 3 ] ) * scale - 60
      azoom[ 4 ] := ( ahs[ 5, 3 ] * ::MetaFiles[ page, 3 ] / ::MetaFiles[ page, 2 ] ) * scale - 60
   ELSE
      azoom[ 3 ] := ( ahs[ 5, 4 ] * ::MetaFiles[ page, 2 ] / ::MetaFiles[ page, 3 ] ) * scale - 60
      azoom[ 4 ] := ( ahs[ 5, 4 ] ) * scale - 60
   ENDIF
   _SetItem ( "StatusBar", "hbpreview", 1, aopisy[ 15 ] + " " + AllTrim( Str( page ) ) )

   IF azoom[ 3 ] < 30
      scale := scale * 1.25
      ::prevshow()
      MsgExclamation( aopisy[ 18 ] + " -", aopisy[ 1 ], , .F., .F. )
   ENDIF
   HideWindow( ahs[ 6, 7 ] )
   _SetControlHeight( "i1", "hbpreview1", azoom[ 3 ] + 20 )
   _SetControlWidth ( "i1", "hbpreview1", azoom[ 4 ] )
   SetScrollRange( ahs[ 5, 7 ], SB_VERT, 0, azoom[ 3 ] + 20, .T. )
   SetScrollRange( ahs[ 5, 7 ], SB_HORZ, 0, azoom[ 4 ], .T. )

   IF ! rr_previewplay( ahs[ 6, 7 ], ::METAFILES[ page, 1 ], azoom )
      scale := scale / 1.25
      ::PrevShow()
      MsgExclamation( aopisy[ 18 ] + " +", aopisy[ 1 ], , .F., .F. )
   ENDIF
   rr_scrollwindow( ahs[ 5, 7 ], -spos[ 1 ] * azoom[ 4 ], -spos[ 2 ] * azoom[ 3 ] )
   CShowControl( ahs[ 6, 7 ] )

RETURN self


/*
 * Routine: PrevPrint()
 *
 * Purpose:
 * Prints either a selected preview page or the configured page range and copies, including the configured odd/even page options.
 *
 * Parameters:
 * n1 - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Switches from preview to printing state and renders the selected page or configured page range/copies to the printer.
 */
METHOD PrevPrint( n1 ) CLASS HBPrinter

   LOCAL i, ilkop, toprint := .T.

   ::Previewmode := .F.
   ::Printingemf := .T.
   rr_lalabye( 1 )
   IF n1 <> NIL
      ::startdoc()
      ::setpage( ::MetaFiles[ n1, 6 ], ::MetaFiles[ n1, 7 ] )
      ::startpage()
      rr_PlayEnhMetaFile( ::MetaFiles[ n1 ], ::hDCRef )
      ::endpage()
      ::enddoc()
   ELSE
      FOR ilkop = 1 TO ::nCopies
         ::startdoc()
         FOR i := Max( 1, ::nFromPage ) TO Min( iloscstron, ::nToPage )
            DO CASE
            CASE ::PrintOpt == 1 ; toprint := .T.
            CASE ::PrintOpt == 2 .OR. ::PrintOpt == 4 ; toprint := !( i % 2 == 0 )
            CASE ::PrintOpt == 3 .OR. ::PrintOpt == 5 ; toprint := ( i % 2 == 0 )
            ENDCASE
            IF toprint
               toprint := .F.
               ::setpage( ::MetaFiles[ i, 6 ], ::MetaFiles[ i, 7 ] )
               ::startpage()
               rr_PlayEnhMetaFile( ::MetaFiles[ i ], ::hDCRef )
               ::endpage()
            ENDIF
         NEXT i
         ::enddoc()

         IF ::PrintOpt == 4 .OR. ::PrintOpt == 5
            MsgBox( aopisy[ 30 ], aopisy[ 29 ], .F., .F. )
            ::startdoc()
            FOR i := Max( 1, ::nFromPage ) TO Min( iloscstron, ::nToPage )
               DO CASE
               CASE ::PrintOpt == 4 ; toprint := ( i % 2 == 0 )
               CASE ::PrintOpt == 5 ; toprint := !( i % 2 == 0 )
               ENDCASE
               IF toprint
                  toprint := .F.
                  ::setpage( ::MetaFiles[ i, 6 ], ::MetaFiles[ i, 7 ] )
                  ::startpage()
                  rr_PlayEnhMetaFile( ::MetaFiles[ i ], ::hDCRef )
                  ::endpage()
               ENDIF
            NEXT i
            ::enddoc()
         ENDIF
      NEXT ilkop
   ENDIF
   rr_lalabye( 0 )
   ::printingemf := .F.
   ::Previewmode := .T.

RETURN self


/*
 * Routine: LangInit()
 *
 * Purpose:
 * Builds the language-dependent text table used by the printer preview and print-options interface.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Array - The language text table used by the preview and printing dialogs.
 *
 * Side Effects:
 * May initialize language-specific text according to the active compilation and runtime settings.
 */

STATIC FUNCTION LangInit

#ifdef _MULTILINGUAL_
   LOCAL cLang
#endif
   LOCAL aLang := { 'Preview', ; // 01
      '&Cancel', ; // 02
      '&Print', ;  // 03
      '&Save', ;   // 04
      '&First', ;  // 05
      'P&revious', ;  // 06
      '&Next', ;      // 07
      '&Last', ; // 08
      'Zoom &In', ; // 09
      '&Zoom Out', ;  // 10
      '&Options', ;   // 11
      'Go To Page:', ; // 12
      'Page preview ', ; // 13
      'Thumbnails preview', ; // 14
      'Page', ;               // 15
      'Print only current page', ; // 16
      'Pages:', ;        // 17
      'No more zoom', ;  // 18
      'Print options', ; // 19
      'Print from', ;    // 20
      'to', ; // 21
      'Copies', ;    // 22
      'Print Range', ; // 23
      'All from range', ; // 24
      'Odd only', ;      // 25
      'Even only', ; // 26
      'All but odd first', ; // 27
      'All but even first', ; // 28
      'Printing ....', ;  // 29
      'Waiting for paper change...', ; // 30
      'Sa&ve as...', ; // 31
      'Save &All', ; // 32
      'PDF Files', ; // 33
      'All Files', ; // 34
      'Ok' ; // 35
   }

#ifdef _MULTILINGUAL_
   cLang := Upper( Left( Set ( _SET_LANGUAGE ), 2 ) )

   // LANGUAGE IS NOT SUPPORTED BY hb_langSelect() FUNCTION
   IF ( _HMG_LANG_ID == 'FI' ) // FINNISH
      cLang := 'FI'
   ENDIF

   DO CASE
      // Russian
   CASE cLang == 'RU'
      aLang := { 'œÓÒÏÓÚ', ;
         '¬˚ıÓ‰', ;
         'œÂ˜‡Ú¸', ;
         '—Óı‡ÌËÚ¸', ;
         'Õ‡˜‡ÎÓ', ;
         'Õ‡Á‡‰', ;
         '¬ÔÂÂ‰', ;
         ' ÓÌÂˆ', ;
         '”‚ÂÎË˜ËÚ¸', ;
         '”ÏÂÌ¸¯ËÚ¸', ;
         'ŒÔˆËË', ;
         '—Ú‡ÌËˆ‡:', ;
         'œÓÒÏÓÚ ÒÚ‡ÌËˆ˚ ', ;
         'ÃËÌË‡Ú˛˚', ;
         '—Ú‡ÌËˆ‡', ;
         'œÂ˜‡Ú‡Ú¸ ÚÂÍÛ˘Û˛', ;
         '—Ú‡ÌËˆ:', ;
         'ƒÓÒÚË„ÌÛÚ ÔÂ‰ÂÎ Ï‡Ò¯Ú‡·ËÓ‚‡ÌËˇ!', ;
         'œ‡‡ÏÂÚ˚ ÔÂ˜‡ÚË', ;
         '—Ú‡ÌËˆ˚ Ò', ;
         'ÔÓ', ;
         ' ÓÔËÈ', ;
         'Õ‡ÔÂ˜‡Ú‡Ú¸', ;
         '¬ÒÂ ÒÚ‡ÌËˆ˚', ;
         'ÕÂ˜∏ÚÌ˚Â', ;
         '◊∏ÚÌ˚Â', ;
         '¬ÒÂ, ÌÓ ‚Ì‡˜‡ÎÂ ÌÂ˜∏ÚÌ˚Â', ;
         '¬ÒÂ, ÌÓ ‚Ì‡˜‡ÎÂ ˜∏ÚÌ˚Â', ;
         'œÂ˜‡Ú¸ ....', ;
         '¬ÒÚ‡‚¸ÚÂ ·ÛÏ‡„Û...', ;
         '—Óı‡ÌËÚ¸ Í‡Í...', ;
         '—Óı‡ÌËÚ¸ ‚ÒÂ', ;
         '‘‡ÈÎ˚ PDF', ;
         '¬ÒÂ Ù‡ÈÎ˚', ;
         'Ok' ;
         }

      // Ukrainian
   CASE cLang == 'UK' .OR. cLang == 'UA'
      aLang := { 'œÂÂ„Îˇ‰', ;
         '¬Ëıi‰', ;
         'ƒÛÍ', ;
         '«·ÂÂ„ÚË', ;
         'œÓ˜‡ÚÓÍ', ;
         'Õ‡Á‡‰', ;
         '¬ÔÂÂ‰', ;
         ' iÌÂˆ¸', ;
         '«·iÎ¸¯ËÚË', ;
         '«ÏÂÌ¯ËÚË', ;
         'ŒÔˆiø', ;
         '—ÚÓiÌÍ‡:', ;
         'œÂÂ„Îˇ‰ ÒÚÓiÌÍË ', ;
         'ÃiÌi‡Ú˛Ë', ;
         '—ÚÓiÌÍ‡', ;
         'ƒÛÍÛ‚‡ÚË ÔÓÚÓ˜ÌÛ', ;
         '—ÚÓiÌÓÍ:', ;
         'ƒÓÒˇ„ÌÛÚ‡ ÏÂÊ‡ Ï‡Ò¯Ú‡·Û‚‡ÌÌˇ!', ;
         'œ‡‡ÏÂÚË ‰ÛÍÛ', ;
         '—ÚÓiÌÍË Á', ;
         'ÔÓ', ;
         ' ÓÔiÈ', ;
         'Õ‡‰ÛÍÛ‚‡ÚË', ;
         '”Òi ÒÚiÌÍË', ;
         'ÕÂÔ‡Ìi', ;
         'œ‡Ìi', ;
         '”Òi, ‡ÎÂ ÒÔÂ¯Û ÌÂÔ‡Ìi', ;
         '”Òi, ‡ÎÂ ÒÔÂ¯Û Ô‡Ìi', ;
         'ƒÛÍ ....', ;
         '«‡ÏiÌiÚ¸ Ô‡Ôi...', ;
         '«·ÂÂ„ÚË ˇÍ...', ;
         '«·ÂÂ„ÚË ‚ÒÂ', ;
         '‘‡ÈÎË PDF', ;
         '”Òi Ù‡ÈÎË', ;
         'Ok' ;
         }

      // Italian
   CASE cLang == 'IT'
      aLang := { 'Anteprima', ;
         '&Cancella', ;
         'S&tampa', ;
         '&Salva', ;
         '&Primo', ;
         '&Indietro', ;
         '&Avanti', ;
         '&Ultimo', ;
         'Zoom In', ;
         'Zoom Out', ;
         '&Opzioni', ;
         'Pagina:', ;
         'Pagina anteprima ', ;
         'Miniatura Anteprima', ;
         'Pagina', ;
         'Stampa solo pagina attuale', ;
         'Pagine:', ;
         'Limite zoom !', ;
         'Opzioni Stampa', ;
         'Stampa da', ;
         'a', ;
         'Copie', ;
         'Range Stampa', ;
         'Tutte', ;
         'Solo dispari', ;
         'Solo pari', ;
         'Tutte iniziando dispari', ;
         'Tutte iniziando pari', ;
         'Stampa in corso ....', ;
         'Attendere cambio carta...', ;
         'Sa&ve as...', ;
         'Save &All', ;
         'PDF Files', ;
         'All Files', ;
         'Ok' ;
         }

      // Spanish
   CASE cLang == 'ES'
      aLang := { 'Vista Previa', ;
         '&Cancelar', ;
         '&Imprimir', ;
         '&Guardar', ;
         '&Primera', ;
         '&Anterior', ;
         '&Siguiente', ;
         '&Ultima', ;
         'Zoom +', ;
         'Zoom -', ;
         '&Opciones', ;
         'Pag.:', ;
         'Pagina ', ;
         'Miniaturas', ;
         'Pag.', ;
         'Imprimir solo pag. actual', ;
         'Paginas:', ;
         'Zoom Maximo/Minimo', ;
         'Opciones de Impresion', ;
         'Imprimir Desde', ;
         'Hasta', ;
         'Copias', ;
         'Imprimir rango', ;
         'Todo a partir de desde', ;
         'Solo impares', ;
         'Solo pares', ;
         'Todo (impares primero)', ;
         'Todo (pares primero)', ;
         'Imprimiendo ....', ;
         'Esperando cambio de papel...', ;
         'Sa&ve as...', ;
         'Save &All', ;
         'PDF Files', ;
         'All Files', ;
         'Ok' ;
         }

      // Polish
   CASE cLang == 'PL'
      aLang := { 'Podglπd', ;
         '&Rezygnuj', ;
         '&Drukuj', ;
         '&Zapisz', ;
         '&Pierwsza', ;
         'Poprz&ednia', ;
         '&NastÍpna', ;
         '&Ostatnia', ;
         'Po&wiÍksz', ;
         'Po&mniejsz', ;
         'Opc&je', ;
         'Idü do strony:', ;
         'Podglπd strony', ;
         'Podglπd miniaturek', ;
         'Strona', ;
         'Drukuj aktualnπ stronÍ', ;
         'Stron:', ;
         'Nie moøna wiÍcej !', ;
         'Opcje drukowania', ;
         'Drukuj od', ;
         'do', ;
         'Kopii', ;
         'Zakres', ;
         'Wszystkie z zakresu', ;
         'Tylko nieparzyste', ;
         'Tylko parzyste', ;
         'Najpierw nieparzyste', ;
         'Najpierw parzyste', ;
         'Drukowanie ....', ;
         'Czekam na zmiane papieru...', ;
         'Zapisz jako..', ;
         'Zapisz wszystko', ;
         'Pliki PDF', ;
         'Wszystkie pliki', ;
         'Ok' ;
         }

      // Portuguese
   CASE cLang == 'PT'
      aLang := { 'PrÈvisualizaÁ„o', ;
         '&Cancelar', ;
         '&Imprimir', ;
         '&Salvar', ;
         '&Primeira', ;
         '&Anterior', ;
         'PrÛximo', ;
         '&⁄ltimo', ;
         'Zoom +', ;
         'Zoom -', ;
         '&OpÁıes', ;
         'Pag.:', ;
         'P·gina ', ;
         'Miniaturas', ;
         'Pag.', ;
         'Imprimir somente a pag. atual', ;
         'P·ginas:', ;
         'Zoom M·ximo/Minimo', ;
         'OpÁıes de Impress„o', ;
         'Imprimir de', ;
         'a', ;
         'CÛpias', ;
         'Imprimir rango', ;
         'Tudo a partir desta', ;
         'SÛ Õmpares', ;
         'SÛ Pares', ;
         'Todas as Õmpares Primeiro', ;
         'Todas Pares primeiro', ;
         'Imprimindo ....', ;
         'Esperando por papel...', ;
         'Sa&lvar Como...', ;
         'Salvar &Tudo', ;
         'Arquivos PDF', ;
         'Todos Arquivos', ;
         'Ok' ;
         }

      // German
   CASE cLang == 'DE'
      aLang := { 'Vorschau', ;
         '&Abbruch', ;
         '&Drucken', ;
         '&Speichern', ;
         '&Erste', ;
         '&Vorige', ;
         '&N‰chste', ;
         '&Letzte', ;
         'Ver&grˆﬂern', ;
         'Ver&kleinern', ;
         '&Optionen', ;
         'Seite:', ;
         'Seitenvorschau', ;
         '‹berblick', ;
         'Seite', ;
         'Aktuelle Seite drucken', ;
         'Seiten:', ;
         'Maximum erreicht!', ;
         'Druckeroptionen', ;
         'Drucke von', ;
         'bis', ;
         'Anzahl', ;
         'Bereich', ;
         'Alle Seiten', ;
         'Ungerade Seiten', ;
         'Gerade Seiten', ;
         'Alles, ungerade Seiten zuerst', ;
         'Alles, gerade Seiten zuerst', ;
         'Druckt ....', ;
         'Bitte Papier nachlegen...', ;
         'Sa&ve as...', ;
         'Save &All', ;
         'PDF Files', ;
         'All Files', ;
         'Ok' ;
         }

      // French
   CASE cLang == 'FR'
      aLang := { 'PrÈvisualisation', ;
         '&Abandonner', ;
         '&Imprimer', ;
         '&Sauver', ;
         '&Premier', ;
         'P&rÈcÈdent', ;
         '&Suivant', ;
         '&Dernier', ;
         'Zoom +', ;
         'Zoom -', ;
         '&Options', ;
         'Aller ‡ la page:', ;
         'AperÁu de la page', ;
         'AperÁu affichettes', ;
         'Page', ;
         'Imprimer la page en cours', ;
         'Pages:', ;
         'Plus de zoom !', ;
         "Options d'impression", ;
         'Imprimer de', ;
         '‡', ;
         'Copies', ;
         "Intervalle d'impression", ;
         "Tout dans l'intervalle", ;
         'Impair seulement', ;
         'Pair seulement', ;
         "Tout mais impair d'abord", ;
         "Tout mais pair d'abord", ;
         'Impression ....', ;
         'Attente de changement de papier...', ;
         'Sa&ve as...', ;
         'Save &All', ;
         'PDF Files', ;
         'All Files', ;
         'Ok' ;
         }

      // Finnish
   CASE cLang == 'FI'
      aLang := { 'Esikatsele', ;
         '&Keskeyt‰', ;
         '&Tulosta', ;
         'T&allenna', ;
         '&Ensimm‰inen', ;
         'E&dellinen', ;
         '&Seuraava', ;
         '&Viimeinen', ;
         'Suurenna', ;
         'Pienenn‰', ;
         '&Optiot', ;
         'Mene sivulle:', ;
         'Esikatsele sivu ', ;
         'Esikatsele miniatyyrit', ;
         'Sivu', ;
         'Tulosta t‰m‰ sivu', ;
         'Sivuja:', ;
         'Ei voi suurentaa !', ;
         'Tulostus optiot', ;
         'Alkaen', ;
         '->', ;
         'Kopiot', ;
         'Tulostus alue', ;
         'Kaikki alueelta', ;
         'Vain parittomat', ;
         'Vain parilleset', ;
         'Kaikki paitsi ensim. pariton', ;
         'Kaikki paitsi ensim. parillinen', ;
         'Tulostan ....', ;
         'Odotan paperin vaihtoa...', ;
         'Tallenna nimell‰...', ;
         'Tallenna kaikki', ;
         'PDF Tiedostot', ;
         'Kaikki Tiedostot', ;
         'Ok' ;
         }

      // Dutch
   CASE cLang == 'NL'
      aLang := { 'Afdrukvoorbeeld', ;
         'Annuleer', ;
         'Print', ;
         'Opslaan', ;
         'Eerste', ;
         'Vorige', ;
         'Volgende', ;
         'Laatste', ;
         'Inzoomen', ;
         'Uitzoomen', ;
         'Opties', ;
         'Ga naar pagina:', ;
         'Pagina voorbeeld ', ;
         'Thumbnails voorbeeld', ;
         'Pagina', ;
         'Print alleen huidige pagina', ;
         "Pagina's:", ;
         'Geen zoom meer !', ;
         'Print opties', ;
         'Print van', ;
         'tot', ;
         'Aantal exemplaren', ;
         "Pagina's", ;
         "Alle pagina's", ;
         'Alleen oneven', ;
         'Alleen even', ;
         'Alles maar oneven eerst', ;
         'Alles maar even eerst', ;
         'Printen ....', ;
         'Wacht op papier wissel...', ;
         'Be&waar als...', ;
         'Bewaar &Alles', ;
         'PDF-bestanden', ;
         'Alle bestanden', ;
         'Ok' ;
         }

      // Czech
   CASE cLang == 'CS'
      aLang := { "N·hled", ;
         "&Storno", ;
         "&Tisk", ;
         "&Uloûit", ;
         "&PrvnÌ", ;
         "P&¯edchozÌ", ;
         "&DalöÌ", ;
         "P&oslednÌ", ;
         "Z&vÏtöit", ;
         "&Zmenöit", ;
         "&Moûnosti", ;
         "Ukaû stranu:", ;
         "N·hled strany ", ;
         "N·hled vÌce str·n", ;
         "Strana", ;
         "Tisk aktu·lnÌ strany", ;
         "Str·n:", ;
         "Nemoûno d·le mÏnit velikost!", ;
         "Moûnosti tisku", ;
         "Tisk od", ;
         "po", ;
         "KÛpiÌ", ;
         "Tisk stran", ;
         "Vöechny stran", ;
         "Jenom lichÈ", ;
         "Jenom sudÈ", ;
         "Vöechny kromÏ prvnÌ lichÈ", ;
         "Vöechny kromÏ prvnÌ sudÈj", ;
         "Tisknu ...", ;
         "»ek·m na papÌr ...", ;
         "Uloûit &jako...", ;
         "Uloûit &vöechno", ;
         "PDF soubor", ;
         "Vöechny soubory", ;
         'Ok' ;
         }

      // Slovak
   CASE cLang == 'SK'
      aLang := { "N·hæad", ;
         "&Storno", ;
         "&TlaË", ;
         "&Uloûiù", ;
         "&Prv·", ;
         "P&redch·zaj˙ca", ;
         "&œalöia", ;
         "Po&sledn·", ;
         "Z&v‰Ëöiù", ;
         "&Zmenöiù", ;
         "&Moûnosti", ;
         "Uk·û stranu:", ;
         "N·hæad strany ", ;
         "N·hæad viacer˝ch str·nok", ;
         "Strana", ;
         "TlaË aktu·lnej strany", ;
         "Strana:", ;
         "Veækosù Ôalej nie je moûnÈ meniù!", ;
         "Moûnosti tlaËe", ;
         "TlaË od", ;
         "po", ;
         "KÛpiÌ", ;
         "TlaË str·n", ;
         "Vöetky strany", ;
         "Len nep·rne", ;
         "Len p·rne", ;
         "Vöetko okrem prvej nep·rnej", ;
         "Vöetko okrem prvej p·rnej", ;
         "TlaËÌm ...", ;
         "»ak·m na papier ...", ;
         "Uloûiù &ako...", ;
         "Uloûiù &vöetko", ;
         "PDF s˙bor", ;
         "Vöetky s˙bory", ;
         'Ok' ;
         }

      // Slovenian
   CASE cLang == 'SL'
      aLang := { 'Predgled', ;
         'Prekini', ;
         'Natisni', ;
         'Shrani', ;
         'Prva', ;
         'Prejönja', ;
         'Naslednja', ;
         'Zadnja', ;
         'PoveËaj', ;
         'Pomanjöaj', ;
         'Moûnosti', ;
         'Skok na stran:', ;
         'Predgled', ;
         'Mini predgled', ;
         'Stran', ;
         'Samo trenutna stran', ;
         'Strani:', ;
         'Ni veË poveËave!', ;
         'Moûnosti tiskanja', ;
         'Tiskaj od', ;
         'do', ;
         'Kopij', ;
         'Tiskanje', ;
         'Vse iz izbora', ;
         'Samo neparne strani', ;
         'Samo parne strani', ;
         'Vse - le brez prve neparne strani', ;
         'Vse - le brez prve parne strani', ;
         'Tiskanje ....', ;
         '»akanje na zamenjavo papirja...', ;
         'Shrani kot...', ;
         'Shrani vse', ;
         'PDF datoteke', ;
         'Vse datoteke', ;
         'Ok' ;
         }

      // Hungarian
   CASE cLang == 'HU'
      aLang := { "ElınÈzet", ;
         "&MÈgse", ;
         "Nyo&mtat·s", ;
         "&MentÈs", ;
         "&Elsı", ;
         "E&lızı", ;
         "&Kˆvetkezı", ;
         "&UtolsÛ", ;
         "&NagyÌt·s", ;
         "K&icsinyÌtÈs", ;
         "&OpciÛk", ;
         "Oldalt mutasd:", ;
         "Oldal elınÈzete ", ;
         "Tˆbb oldal elınÈzete", ;
         "Oldal", ;
         "Aktu·lis oldal nyomtat·sa", ;
         "Oldal:", ;
         "A nagys·g tov·bb nem v·ltoztathatÛ!", ;
         "Nyomtat·si lehetısÈgek", ;
         "Nyomtat·s ettıl", ;
         "eddig", ;
         "M·solat", ;
         "Oldalak nyomtat·sa", ;
         "Minden oldalt", ;
         "Csak a p·ratlan", ;
         "Csak a p·ros", ;
         "Mindet kivÈve az elsı p·ratlant", ;
         "Mindet kivÈve az elsı p·rost", ;
         "Nyomtatom ...", ;
         "PapÌrra v·rok ...", ;
         "MentÈs m·skÈnt ...", ;
         "Mindet mentsd", ;
         "PDF ·llom·ny", ;
         "Minden ·llom·ny", ;
         'Ok' ;
         }

      // Greek - Ellinika
   CASE cLang == 'EL'
      aLang := { '–ÒÔ‚ÔÎﬁ', ;
         '∏&ÓÔ‰ÔÚ', ;
         '&≈ÍÙ˝˘ÛÁ', ;
         '&¡ÔËﬁÍÂıÛÁ ÛÂÎﬂ‰·Ú', ;
         '&1Á ÛÂÎﬂ‰·', ;
         '–&ÒÔÁ„.”ÂÎ.', ;
         '&≈¸ÏÂÌÁ', ;
         '&‘ÂÎÂıÙ·ﬂ·', ;
         'Zoom +', ;
         'Zoom -', ;
         '&≈ÈÎÔ„›Ú', ;
         '–ÒÔ‚ÔÎﬁ ÛÂÎﬂ‰·Ú:', ;
         '–ÒÔ‚ÔÎﬁ ', ;
         'ÃÈÍÒÔ„Ò·ˆﬂÂÚ', ;
         '”ÂÎ.', ;
         '‘˝˘ÛÂ Ï¸ÌÔ ÙÁÌ ·ÒÔ˝Û·', ;
         '”ÂÎﬂ‰ÂÚ:', ;
         '‘›ÎÔÚ zoom', ;
         '≈ÈÎÔ„›Ú', ;
         '‘˝˘ÛÂ ·¸ ÛÂÎﬂ‰·', ;
         '∏˘Ú ÛÂÎﬂ‰·', ;
         '¡ÌÙﬂ„Ò·ˆ·', ;
         '≈˝ÒÔÚ ÂÍÙ˝˘ÛÁÚ', ;
         'œÎÂÚ ÙÈÚ ÛÂÎﬂ‰ÂÚ', ;
         'Ã¸ÌÔ ÙÈÚ ÏÔÌ›Ú ÛÂÎﬂ‰ÂÚ ', ;
         'Ã¸ÌÔ ÙÈÚ Êı„›Ú ÛÂÎﬂ‰ÂÚ', ;
         'œÎÂÚ ÂÍÙÔÚ ·Ô ÙÁÌ 1Á ÏÔÌﬁ', ;
         'œÎÂÚ ÂÍÙÔÚ ·Ô ÙÁÌ 1Á Êı„ﬁ', ;
         '≈ÍÙı˛Ì˘ ....', ;
         '¡Ì·ÏÔÌﬁ „È· ·ÎÎ·„ﬁ ˜·ÒÙÈÔ˝...', ;
         '¡ÔËﬁÍÂıÛÁ ÛÂÎﬂ‰·Ú ˘Ú..', ;
         '¡ÔËﬁÍÂıÛÁ ¸Î˘Ì Ù˘Ì ÛÂÎﬂ‰˘Ì', ;
         '¡Ò˜Âﬂ· PDF', ;
         'ºÎ· Ù· ·Ò˜Âﬂ·', ;
         '≈ÌÙ‹ÓÂÈ' ;
         }

      // Bulgarian
   CASE cLang == 'BG'
      aLang := { 'œÂ„ÎÂ‰', ;
         '»ÁıÓ‰', ;
         'œÂ˜‡Ú', ;
         '—˙ı‡ÌË', ;
         'Õ‡˜‡ÎÓ', ;
         'Õ‡Á‡‰', ;
         'Õ‡ÔÂ‰', ;
         ' ‡È', ;
         '”‚ÂÎË˜Ë', ;
         'Õ‡Ï‡ÎË', ;
         'ŒÔˆËË', ;
         '—Ú‡ÌËˆ‡:', ;
         'œÂ„ÎÂ‰ Ì‡ ÒÚ‡ÌËˆ‡Ú‡ ', ;
         'ÃËÌË‡Ú˛Ë', ;
         '—Ú‡ÌËˆ‡', ;
         'œÂ˜‡Ú‡ÌÂ Ì‡ ÚÂÍÛ˘‡', ;
         '—Ú‡ÌËˆË:', ;
         'ƒÓÒÚË„Ì‡Ú e ÔÂ‰ÂÎ‡ Ì‡ Ï‡˘‡·Ë‡ÌÂ!', ;
         'œ‡‡ÏÂÚË Á‡ ÔÂ˜‡Ú', ;
         '—Ú‡ÌËˆË ÓÚ', ;
         '‰Ó', ;
         ' ÓÔËˇ', ;
         'Õ‡ÔÂ˜‡Ú‡È', ;
         '¬ÒË˜ÍË ÒÚ‡ÌËˆË', ;
         'ÕÂ˜ÂÚÌËÚÂ', ;
         '◊ÂÚÌËÚÂ', ;
         '¬ÒË˜ÍË, ÌÓ Ô˙‚Ó ÌÂ˜ÂÚÌËÚÂ', ;
         '¬ÒË˜ÍË, ÌÓ Ô˙‚Ó ˜ÂÚÌËÚÂ', ;
         'œÂ˜‡Ú ....', ;
         'œÓÒÚ‡‚ÂÚÂ ı‡ÚËˇ...', ;
         '—˙ı‡ÌË Í‡ÚÓ...', ;
         '—˙ı‡ÌË ‚ÒË˜ÍÓ', ;
         '‘‡ÈÎÓ‚Â PDF', ;
         '¬ÒË˜ÍË Ù‡ÈÎÓ‚Â', ;
         'Ok' ;
         }
   ENDCASE
#endif

RETURN aLang


/*
 * Routine: Preview()
 *
 * Purpose:
 * Creates and activates the HMG Extended preview interface for the generated preview metafiles.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * NIL - No meaningful return value; the preview interface is created and activated when preview data is available.
 *
 * Side Effects:
 * Creates HMG Extended preview windows, controls, hotkeys, and thumbnail controls as configured, then activates the preview window.
 */
METHOD Preview() CLASS HBPrinter

   LOCAL i, pi := 1

   PRIVATE page := 1, scale := ::PREVIEWSCALE, azoom := { 0, 0, 0, 0 }, ahs := {}, npages := {}
   PRIVATE dx, dy, ngroup := -1, ath := {}, iloscstron := Len( ::metafiles )
   PRIVATE aOpisy := LangInit()
   ::nFromPage := Min( ::nFromPage, iloscstron )
   IF ::nwhattoprint < 2
      ::nTopage := iloscstron
   ELSE
      ::nToPage := Min( iloscstron, ::nToPage )
   ENDIF

   IF ! ::PreviewMode .OR. Empty( ::metafiles )
      RETURN self
   ENDIF

   IF ::DEVCAPS[ 15 ] == 2 .AND. GetDesktopWidth() / GetDesktopHeight() > 1.4 // widescreen display
      scale *= .7
   ENDIF

   FOR pi = 1 TO iloscstron
      AAdd( npages, PadL( pi, 4 ) )
   NEXT pi

   AAdd( ahs, { 0, 0, 0, 0, 0, 0, 0 } )

   IF ::Previewrect[ 3 ] == -1 .AND. ::Previewrect[ 4 ] == -1
      ::Previewrect := rr_getdesktoparea()
   ENDIF
   IF ::PreviewRect[ 3 ] > 0 .AND. ::PreviewRect[ 4 ] > 0
      ahs[ 1, 1 ] := ::Previewrect[ 1 ]
      ahs[ 1, 2 ] := ::Previewrect[ 2 ]
      ahs[ 1, 3 ] := ::Previewrect[ 3 ]
      ahs[ 1, 4 ] := ::Previewrect[ 4 ]
      ahs[ 1, 5 ] := ::Previewrect[ 3 ] - ::Previewrect[ 1 ] + 1
      ahs[ 1, 6 ] := ::Previewrect[ 4 ] - ::Previewrect[ 2 ] + 1
   ELSE
      pi := rr_getdesktoparea()
      ahs[ 1, 1 ] := pi[ 1 ] + 10
      ahs[ 1, 2 ] := pi[ 2 ] + 10
      ahs[ 1, 3 ] := pi[ 3 ] - 10
      ahs[ 1, 4 ] := pi[ 4 ] - 10
      ahs[ 1, 5 ] := ahs[ 1, 3 ] - ahs[ 1, 1 ] + 1
      ahs[ 1, 6 ] := ahs[ 1, 4 ] - ahs[ 1, 2 ] + 1
   ENDIF

   // Main modal preview window: toolbar, status bar, page selector, and preview panes are hosted here.
   DEFINE WINDOW HBPREVIEW ;
         AT ahs[ 1, 1 ], ahs[ 1, 2 ] ;
         WIDTH ahs[ 1, 6 ] HEIGHT ahs[ 1, 5 ] ;
         TITLE aopisy[ 1 ] ICON 'zzz_Printicon' ;
         MODAL NOSIZE ;
         FONT 'Arial' SIZE 9

      _DefineHotKey( "HBPREVIEW", 0, VK_ESCAPE, {|| ::PrevClose( .T. ) } ) // Escape
      _DefineHotKey( "HBPREVIEW", 0, VK_ADD, {|| scale := scale * 1.25, ::PrevShow() } ) // zoom in
      _DefineHotKey( "HBPREVIEW", 0, VK_SUBTRACT, {|| scale := scale / 1.25, ::PrevShow() } ) // zoom out
      _definehotkey( "HBPREVIEW", MOD_CONTROL, VK_P, {|| ::prevprint(), if( ::CLSPREVIEW, ::PrevClose( .F. ), NIL ) } ) // Print
      _DefineHotKey( "HBPREVIEW", 0, VK_PRIOR, {|| page := ::CurPage := if( page == 1, 1, page - 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // back
      _DefineHotKey( "HBPREVIEW", 0, VK_NEXT, {|| page := ::CurPage := if( page == iloscstron, page, page + 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // next

      DEFINE STATUSBAR
      STATUSITEM aopisy[ 15 ] + " " + hb_ntos( page ) WIDTH 100
      STATUSITEM aopisy[ 16 ] WIDTH 200 ICON 'zzz_Printicon' ACTION ::PREVPRINT( page ) RAISED
      STATUSITEM aopisy[ 17 ] + " " + hb_ntos( iloscstron ) WIDTH 100
   END STATUSBAR

   IF iloscstron > 1
      @ 16, ahs[ 1, 6 ] -  77 COMBOBOX combo_1 ITEMS npages VALUE 1  WIDTH 48  FONT 'Arial' SIZE 8 NOTABSTOP ON CHANGE {|| page := ::CurPage := HBPREVIEW.combo_1.VALUE, ::PrevShow() }
      @ 20, ahs[ 1, 6 ] - 184 LABEL prl VALUE aopisy[ 12 ] WIDTH 100 HEIGHT 18 FONT 'Arial' SIZE 8 BACKCOLOR iif( IsAppXPThemed(), iif( isseven(), { 211, 218, 237 }, iif( _HMG_IsXP, { 239, 235, 219 }, nRGB2Arr( GetSysColor( 5 ) ) ) ), NIL ) RIGHTALIGN
   ENDIF

   DEFINE SPLITBOX
   DEFINE TOOLBAR TB1 BUTTONSIZE 75, 40 FONT _HMG_DefaultFontName SIZE 8 FLAT BREAK
      BUTTON B2 CAPTION aopisy[ 3 ] PICTURE 'hbprint_print' ACTION {|| ::prevprint(), iif( ::CLSPREVIEW, ::PrevClose( .F. ), nil ) }
      IF ::SaveButtons
         BUTTON B3 CAPTION aopisy[ 4 ] PICTURE 'hbprint_save' WHOLEDROPDOWN
         DEFINE DROPDOWN MENU BUTTON B3
                ITEM aopisy[ 4 ] ACTION {|| ::savemetafiles( ::CurPage ) }
                ITEM aopisy[ 31 ] ACTION {|| pi := Putfile ( { { aopisy[ 33 ], '*.pdf' }, { aopisy[ 34 ], '*.*' } }, , GetCurrentFolder(), .T., ::DOCNAME ), iif( Empty( pi ), NIL, ::savemetafiles( NIL, pi ) ) }
                ITEM aopisy[ 32 ] ACTION {|| ::savemetafiles() }
         END MENU
      ENDIF
      BUTTON B1 CAPTION aopisy[ 2 ] PICTURE 'hbprint_close' ACTION {|| ::PrevClose( .T. ) } SEPARATOR
      BUTTON B10 CAPTION aopisy[ 11 ] PICTURE 'hbprint_option' ACTION {|| ::PrintOption() } SEPARATOR
      BUTTON B8 CAPTION aopisy[ 9 ] PICTURE 'hbprint_zoomin' ACTION {|| scale := scale * 1.25, ::PrevShow() }
      BUTTON B9 CAPTION aopisy[ 10 ] PICTURE 'hbprint_zoomout' ACTION {|| scale := scale / 1.25, ::PrevShow() } SEPARATOR
   IF iloscstron > 1
      BUTTON B4 CAPTION aopisy[ 5 ] PICTURE 'hbprint_top' ACTION {|| page := ::CurPage := 1, HBPREVIEW.combo_1.VALUE := page, ::PrevShow() }
      BUTTON B5 CAPTION aopisy[ 6 ] PICTURE 'hbprint_back' ACTION {|| page := ::CurPage := iif( page == 1, 1, page - 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() }
      BUTTON B6 CAPTION aopisy[ 7 ] PICTURE 'hbprint_next' ACTION {|| page := ::CurPage := iif( page == iloscstron, page, page + 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() }
      BUTTON B7 CAPTION aopisy[ 8 ] PICTURE 'hbprint_end' ACTION {|| page := ::CurPage := iloscstron, HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } SEPARATOR
   ENDIF

   END TOOLBAR

   AAdd( ahs, { 0, 0, 0, 0, 0, 0, GetFormHandle( "hbpreview" ) } )
   rr_getclientrect( ahs[ 2 ] )
   AAdd( ahs, { 0, 0, 0, 0, 0, 0, GetControlHandle( "Tb1", "hbpreview" ) } )
   rr_getclientrect( ahs[ 3 ] )
   AAdd( ahs, { 0, 0, 0, 0, 0, 0, GetControlHandle( "StatusBar", "hbpreview" ) } )
   rr_getclientrect( ahs[ 4 ] )

#ifdef __XHARBOUR__
   IF IsWindowDefined( HBPREVIEW1 )
      _ReleaseWindow ( "HBPREVIEW1" )
      _ReleaseControl( "i1", "hbpreview1" )
      _HMG_aFormDeleted[ GetFormIndex( "hbpreview1" ) ] := .T.
   ENDIF
#endif

   // Preview child window containing the scrollable page image.
   DEFINE WINDOW HBPREVIEW1 ;
         WIDTH ahs[ 2, 6 ] - 15 HEIGHT ahs[ 2, 5 ] - ahs[ 3, 5 ] - ahs[ 4, 5 ] - 10 ;
         VIRTUAL WIDTH ahs[ 2, 6 ] - 5 ;
         VIRTUAL HEIGHT ahs[ 2, 5 ] - ahs[ 3, 5 ] - ahs[ 4, 5 ] ;
         TITLE aopisy[ 13 ] SPLITCHILD GRIPPERTEXT ".."

      AAdd( ahs, { 0, 0, 0, 0, 0, 0, GetFormHandle( "hbpreview1" ) } )
      rr_getclientrect( ahs[ 5 ] )
      @ ahs[ 5, 2 ] + 10, ahs[ 5, 1 ] + 10 IMAGE I1 PICTURE "" WIDTH ahs[ 5, 6 ] - 10 HEIGHT ahs[ 5, 5 ] - 10
      AAdd( ahs, { 0, 0, 0, 0, 0, 0, GetControlHandle( "i1", "hbpreview1" ) } )
      rr_getclientrect( ahs[ 6 ] )

      _DefineHotKey( "HBPREVIEW1", 0, VK_ESCAPE, {|| _ReleaseWindow( "HBPREVIEW" ) } )
      _DefineHotKey( "HBPREVIEW1", 0, VK_ADD, {|| scale := scale * 1.25, :: PrevShow () } )
      _DefineHotKey( "HBPREVIEW1", 0, VK_SUBTRACT, {|| scale := scale / 1.25, :: PrevShow () } )
      _definehotkey( "HBPREVIEW1", MOD_CONTROL, VK_P, {|| ::prevprint(), iif( ::CLSPREVIEW, ::PrevClose( .F. ), NIL ) } ) // Print

      IF iloscstron > 1
         _DefineHotKey( "HBPREVIEW1", 0, VK_PRIOR, {|| page := ::CurPage := iif( page == 1, 1, page - 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // back
         _DefineHotKey( "HBPREVIEW1", 0, VK_NEXT, {|| page := ::CurPage := iif( page == iloscstron, page, page + 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // next
         _DefineHotKey( "HBPREVIEW1", 0, VK_END, {|| page := ::CurPage := iloscstron, HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // end
         _DefineHotKey( "HBPREVIEW1", 0, VK_HOME, {|| page := ::CurPage := 1, HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // home
         _DefineHotKey( "HBPREVIEW1", 0, VK_LEFT, {|| page := ::CurPage := iif( page == 1, 1, page - 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // Left
         _DefineHotKey( "HBPREVIEW1", 0, VK_UP, {|| page := ::CurPage := iif( page == 1, 1, page - 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // up
         _DefineHotKey( "HBPREVIEW1", 0, VK_RIGHT, {|| page := ::CurPage := iif( page == iloscstron, page, page + 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // right
         _DefineHotKey( "HBPREVIEW1", 0, VK_DOWN, {|| page := ::CurPage := iif( page == iloscstron, page, page + 1 ), HBPREVIEW.combo_1.VALUE := page, ::PrevShow() } ) // down
      ENDIF
      END WINDOW

      IF ::thumbnails .AND. iloscstron > 1
         // Optional thumbnail pane; each thumbnail action selects the corresponding page.
         DEFINE WINDOW HBPREVIEW2 ;
               WIDTH ahs[ 2, 6 ] - 15 HEIGHT ahs[ 2, 5 ] - ahs[ 3, 5 ] - ahs[ 4, 5 ] - 10 ;
               TITLE aopisy[ 14 ] SPLITCHILD GRIPPERTEXT ".."

            AAdd( ahs, { 0, 0, 0, 0, 0, 0, GetFormHandle( "hbpreview2" ) } )
            rr_getClientRect( ahs[ 7 ] )
            dx := ( ahs[ 5, 6 ] - 20 ) / 5 - 5
            dy := ahs[ 5, 5 ] / 3 - 5
            FOR i := 1 TO 15
               AAdd( ath, { 0, 0, 0, 0, 0 } )
               IF ::Metafiles[ 1, 2 ] >= ::Metafiles[ 1, 3 ]
                  ath[ i, 3 ] := dy - 5
                  ath[ i, 4 ] := dx * ::Metafiles[ 1, 3 ] / ::Metafiles[ 1, 2 ] - 5
               ELSE
                  ath[ i, 4 ] := dx - 5
                  ath[ i, 3 ] := dy * ::Metafiles[ 1, 2 ] / ::Metafiles[ 1, 3 ] - 5
               ENDIF
               ath[ i, 1 ] := Int( ( i - 1 ) / 5 ) * dy + 5
               ath[ i, 2 ] := ( ( i - 1 ) % 5 ) * dx + 5
            NEXT
            @ ath[ 1, 1 ], ath[ 1, 2 ] image it1 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 1 ) } width ath[ 1, 4 ] height ath[ 1, 3 ]
            @ ath[ 2, 1 ], ath[ 2, 2 ] image it2 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 2 ) } width ath[ 2, 4 ] height ath[ 2, 3 ]
            @ ath[ 3, 1 ], ath[ 3, 2 ] image it3 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 3 ) } width ath[ 3, 4 ] height ath[ 3, 3 ]
            @ ath[ 4, 1 ], ath[ 4, 2 ] image it4 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 4 ) } width ath[ 4, 4 ] height ath[ 4, 3 ]
            @ ath[ 5, 1 ], ath[ 5, 2 ] image it5 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 5 ) } width ath[ 5, 4 ] height ath[ 5, 3 ]
            @ ath[ 6, 1 ], ath[ 6, 2 ] image it6 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 6 ) } width ath[ 6, 4 ] height ath[ 6, 3 ]
            @ ath[ 7, 1 ], ath[ 7, 2 ] image it7 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 7 ) } width ath[ 7, 4 ] height ath[ 7, 3 ]
            @ ath[ 8, 1 ], ath[ 8, 2 ] image it8 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 8 ) } width ath[ 8, 4 ] height ath[ 8, 3 ]
            @ ath[ 9, 1 ], ath[ 9, 2 ] image it9 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 9 ) } width ath[ 9, 4 ] height ath[ 9, 3 ]
            @ ath[ 10, 1 ], ath[ 10, 2 ] image it10 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 10 ) } width ath[ 10, 4 ] height ath[ 10, 3 ]
            @ ath[ 11, 1 ], ath[ 11, 2 ] image it11 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 11 ) } width ath[ 11, 4 ] height ath[ 11, 3 ]
            @ ath[ 12, 1 ], ath[ 12, 2 ] image it12 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 12 ) } width ath[ 12, 4 ] height ath[ 12, 3 ]
            @ ath[ 13, 1 ], ath[ 13, 2 ] image it13 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 13 ) } width ath[ 13, 4 ] height ath[ 13, 3 ]
            @ ath[ 14, 1 ], ath[ 14, 2 ] image it14 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 14 ) } width ath[ 14, 4 ] height ath[ 14, 3 ]
            @ ath[ 15, 1 ], ath[ 15, 2 ] image it15 OF hbpreview2 PICTURE "" action {|| ::Prevthumb( 15 ) } width ath[ 15, 4 ] height ath[ 15, 3 ]

            FOR i := 1 TO 15
               ath[ i, 5 ] := GetControlHandle( "it" + hb_ntos( i ), "hbpreview2" )
               rr_playthumb( ath[ i ], ::Metafiles[ i ], hb_ntos( i ), i )
               IF i >= iloscstron
                  EXIT
               ENDIF
            NEXT

         END WINDOW
      ENDIF
   END SPLITBOX
   END WINDOW
   ::PrevShow()
   ACTIVATE WINDOW HBPREVIEW

RETURN NIL


/*
 * Routine: PrevClose()
 *
 * Purpose:
 * Closes the preview window and records whether preview was cancelled through the supplied flag.
 *
 * Parameters:
 * lEsc - Harbour value - Value used by the routine as indicated by the source.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Records the escape/cancel state and releases the preview window.
 */
METHOD PrevClose( lEsc ) CLASS HBPrinter

   ::lEscaped := lEsc
   _ReleaseWindow ( "HBPREVIEW" )

#ifdef __XHARBOUR__
   DoEvents()
#endif

RETURN self


/*
 * Routine: PrintOption()
 *
 * Purpose:
 * Displays the print-options dialog when it is not already open and, when accepted, updates the selected page range, copy count, and print option.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Logical - True when the print-options dialog was accepted; false when it was cancelled or not opened.
 *
 * Side Effects:
 * Creates and activates the modal print-options window when needed and updates print settings when accepted.
 */
METHOD PrintOption() CLASS HBPrinter

   LOCAL OKprint := .F.

   IF IsWindowDefined( PrOpt ) == .F.

      // Modal print-options dialog used to validate and update the selected page range and copy count.
      DEFINE WINDOW PrOpt ;
         WIDTH 355 HEIGHT 168 ;
         TITLE aopisy[ 19 ] ;
         ICON 'zzz_Printicon' ;
         MODAL ;
         NOSIZE NOSYSMENU ;
         FONT 'Arial' SIZE 9

         @ 2, 2    FRAME   PrOptFrame WIDTH 345 - Iif( _HMG_IsXP, GetBorderWidth(), 0 ) HEIGHT 136 - iif( _HMG_IsXP, GetBorderHeight(), 0 )

         @ 10,  10 LABEL     label_11 VALUE aopisy[ 20 ] WIDTH 120 HEIGHT 24 VCENTERALIGN
         @ 10, 135 TEXTBOX   textFrom                    WIDTH 30  HEIGHT 24 NUMERIC MAXLENGTH 3 RIGHTALIGN ;
            ON LOSTFOCUS {|| iif(This.Value > 0 .AND. This.Value <= PrOpt.textTo.Value, NIL, This.setfocus)} ;
            ON ENTER PrOpt.TextTo.setfocus

         @ 40,  10 LABEL     label_12 VALUE aopisy[ 21 ] WIDTH 120 HEIGHT 24 VCENTERALIGN
         @ 40, 135 TEXTBOX   textTo                      WIDTH 30  HEIGHT 24 NUMERIC MAXLENGTH 3 RIGHTALIGN ;
            ON LOSTFOCUS {|| iif(This.Value >= Getproperty( 'PrOpt', 'textFrom', 'Value' ) .AND. ;
            This.Value <= iif( ::nwhattoprint < 2, iloscstron, ::ntopage ), NIL, This.setfocus)} ;
            ON ENTER PrOpt.TextCopies.setfocus

         @ 70,  10 LABEL     label_18 VALUE aopisy[ 22 ] WIDTH 120 HEIGHT 24 VCENTERALIGN
         @ 70, 135 TEXTBOX   textCopies                  WIDTH 30  HEIGHT 24 NUMERIC MAXLENGTH 3 RIGHTALIGN ;
            ON ENTER PrOpt.prnCombo.setfocus

         @ 100,  10 LABEL    label_13 VALUE aopisy[ 23 ] WIDTH 120 HEIGHT 24 VCENTERALIGN
         @ 100, 135 COMBOBOX prnCombo VALUE ::PrintOpt ;
            ITEMS { aopisy[ 24 ], aopisy[ 25 ], aopisy[ 26 ], aopisy[ 27 ], aopisy[ 28 ] } ;
            WIDTH 200 ;
            ON ENTER PrOpt.Button_14.setfocus

         @ 10, 248 BUTTON button_14 CAPTION aopisy[ 35 ] ;
            ACTION {|| OKprint := .T., ::nFromPage := PrOpt.textFrom.Value, ::nToPage := PrOpt.textTo.Value, ;
            ::nCopies := Max( PrOpt.textCopies.Value, 1 ), ::PrintOpt := PrOpt.prnCombo.Value, PrOpt.Release } ;
            WIDTH 90 HEIGHT 24

         @ 40, 248 BUTTON button_15 CAPTION aopisy[ 2 ] ;
            ACTION PrOpt.Release ;
            WIDTH 90 HEIGHT 24

      END WINDOW

      _DefineHotKey( "PrOpt", 0, VK_ESCAPE, {|| _ReleaseWindow( "PrOpt" ) } )

      PrOpt.textFrom.VALUE := Max( ::nfrompage, 1 )
      PrOpt.textTo.VALUE := ::ntopage
      PrOpt.textCopies.VALUE := ::nCopies

      PrOpt.CENTER
      PrOpt.ACTIVATE

   ENDIF

RETURN OKPrint

#ifdef _DEBUG_
/*
 * Routine: ReportData()
 *
 * Purpose:
 * Writes the supplied diagnostic values to the debug report printer output.
 *
 * Parameters:
 * l_x1 \ldots l_x6 - Any - Optional diagnostic values printed to the report.
 *
 * Returns:
 * HBPrinter - The current printer object.
 *
 * Side Effects:
 * Writes diagnostic output to hbprinter.rep and changes the Harbour printer/console state for that diagnostic operation.
 */
METHOD ReportData( l_x1, l_x2, l_x3, l_x4, l_x5, l_x6 ) CLASS HBPrinter

   SET PRINTER TO "hbprinter.rep" ADDITIVE
   SET DEVICE TO PRINT
   SET PRINTER ON
   SET CONSOLE OFF
   ? '-----------------', Date(), Time()
   ?
   ?? if( ValType( l_x1 ) <> "U", l_x1, "," )
   ?? if( ValType( l_x2 ) <> "U", l_x2, "," )
   ?? if( ValType( l_x3 ) <> "U", l_x3, "," )
   ?? if( ValType( l_x4 ) <> "U", l_x4, "," )
   ?? if( ValType( l_x5 ) <> "U", l_x5, "," )
   ?? if( ValType( l_x6 ) <> "U", l_x6, "," )
   ? 'HDC            :', ::HDC
   ? 'HDCREF         :', ::HDCREF
   ? 'PRINTERNAME    :', ::PRINTERNAME
   ? 'PRINTEDEFAULT  :', ::PRINTERDEFAULT
   ? 'VERT X HORZ SIZE         :', ::DEVCAPS[ 1 ], "x", ::DEVCAPS[ 2 ]
   ? 'VERT X HORZ RES          :', ::DEVCAPS[ 3 ], "x", ::DEVCAPS[ 4 ]
   ? 'VERT X HORZ LOGPIX       :', ::DEVCAPS[ 5 ], "x", ::DEVCAPS[ 6 ]
   ? 'VERT X HORZ PHYS. SIZE   :', ::DEVCAPS[ 7 ], "x", ::DEVCAPS[ 8 ]
   ? 'VERT X HORZ PHYS. OFFSET :', ::DEVCAPS[ 9 ], "x", ::DEVCAPS[ 10 ]
   ? 'VERT X HORZ FONT SIZE    :', ::DEVCAPS[ 11 ], "x", ::DEVCAPS[ 12 ]
   ? 'VERT X HORZ ROWS COLS    :', ::DEVCAPS[ 13 ], "x", ::DEVCAPS[ 14 ]
   ? 'ORIENTATION              :', ::DEVCAPS[ 15 ]
   ? 'PAPER SIZE               :', ::DEVCAPS[ 17 ]
   SET PRINTER OFF
   SET PRINTER TO
   SET CONSOLE ON
   SET DEVICE TO SCREEN

RETURN self

#endif /* _DEBUG_ */


#ifdef __XHARBOUR__
#xtranslate hb_eol() => hb_OsNewLine()
#xtranslate WAPI_SHELLEXECUTE( [<x,...>] ) => SHELLEXECUTE( <x> )

#pragma BEGINDUMP

#include "hbapi.h"
#include "hbapifs.h"

/*
 * Routine: HB_FNAMENAME()
 *
 * Purpose:
 * Returns the file-name component of a Harbour path.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Character - The file-name component returned by the Harbour file-name API.
 *
 * Side Effects:
 * Allocates Harbour file-name parsing state internally and releases it before returning.
 */

HB_FUNC( HB_FNAMENAME )
{
   PHB_FNAME pFilepath = hb_fsFNameSplit( hb_parcx( 1 ) );

   hb_retc( pFilepath->szName );
   hb_xfree( pFilepath );
}

/*
 * Routine: HB_FNAMEEXT()
 *
 * Purpose:
 * Returns the extension component of a Harbour path.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Character - The extension returned by the Harbour file-name API.
 *
 * Side Effects:
 * Allocates Harbour file-name parsing state internally and releases it before returning.
 */

HB_FUNC( HB_FNAMEEXT )
{
   PHB_FNAME pFilepath = hb_fsFNameSplit( hb_parcx( 1 ) );

   hb_retc( pFilepath->szExtension );
   hb_xfree( pFilepath );
}

/*
 * Routine: HB_FNAMEEXTSET()
 *
 * Purpose:
 * Returns a path with its extension replaced by the supplied extension.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Character - The merged path with the requested extension.
 *
 * Side Effects:
 * Allocates Harbour file-name parsing state internally and releases it before returning.
 */

HB_FUNC( HB_FNAMEEXTSET )
{
   char szPath[ HB_PATH_MAX ];
   PHB_FNAME pFilepath = hb_fsFNameSplit( hb_parcx( 1 ) );

   pFilepath->szExtension = hb_parc( 2 );
   hb_retc( hb_fsFNameMerge( szPath, pFilepath ) );
   hb_xfree( pFilepath );
}

/*
 * Routine: HB_FNAMEEXTSETDEF()
 *
 * Purpose:
 * Returns a path with a default extension applied only when the path has no extension.
 *
 * Parameters:
 * None.
 *
 * Returns:
 * Character - The merged path with the default extension when required.
 *
 * Side Effects:
 * Allocates Harbour file-name parsing state internally and releases it before returning.
 */

HB_FUNC( HB_FNAMEEXTSETDEF )
{
   char szPath[ HB_PATH_MAX ];
   PHB_FNAME pFilepath = hb_fsFNameSplit( hb_parcx( 1 ) );

   if( ! pFilepath->szExtension )
      pFilepath->szExtension = hb_parc( 2 );
   hb_retc( hb_fsFNameMerge( szPath, pFilepath ) );
   hb_xfree( pFilepath );
}

#pragma ENDDUMP

#endif /* __XHARBOUR__ */