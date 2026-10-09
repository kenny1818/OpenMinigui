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

// Compatibility layer for xHarbour and older Harbour compilers lacking Unicode string functions
#if defined( __XHARBOUR__ ) .OR. ( __HARBOUR__ - 0 < 0x030200 )
  #xtranslate hb_UAt( <c>, <n> ) => At( <c>, <n> )
  #xtranslate hb_ULeft( <c>, <n> ) => Left( <c>, <n> )
#endif

/*
 * Routine: _DefineRichEditBox
 * Purpose:
 *   Creates and initializes a Win32 RichEdit control (RichEditBox) within an HMG parent
 *   window or container, applying specified coordinates, fonts, formatting, event handlers,
 *   and database/file data bindings.
 *
 * Parameters:
 *   ControlName - Character: Name identifying the control, or "0" to auto-generate a unique name.
 *   ParentForm  - Character/Numeric: Name or handle of parent window/form container.
 *   x           - Numeric: Horizontal X-coordinate in pixels relative to parent window/frame.
 *   y           - Numeric: Vertical Y-coordinate in pixels relative to parent window/frame.
 *   w           - Numeric: Width in pixels (defaults to 120).
 *   h           - Numeric: Height in pixels (defaults to 240).
 *   value       - Character: Initial text content or RTF markup stream (defaults to "").
 *   fontname    - Character: Font face family name.
 *   fontsize    - Numeric: Font point size.
 *   tooltip     - Character: Tooltip text displayed on mouse hover.
 *   maxlength   - Numeric: Character capacity limit (defaults to 64738).
 *   gotfocus    - Block/Character: Event callback routine executed when control gains focus.
 *   change      - Block/Character: Event callback routine executed on text content change.
 *   lostfocus   - Block/Character: Event callback routine executed when control loses focus.
 *   readonly    - Logical: If .T., user editing is prohibited.
 *   break       - Logical: Forces a row break when placed inside a SplitBox.
 *   HelpId      - Numeric: Context Help identifier for Windows Help system.
 *   invisible   - Logical: If .T., control is initially hidden (defaults to .F.).
 *   notabstop   - Logical: If .T., skips control during Tab keyboard navigation (defaults to .F.).
 *   bold        - Logical: Applies bold font attribute.
 *   italic      - Logical: Applies italic font attribute.
 *   underline   - Logical: Applies underline font attribute.
 *   strikeout   - Logical: Applies strikeout font attribute.
 *   file        - Character: Path to a plain text or RTF file to stream into control.
 *   field       - Character: Qualified database field name ("ALIAS->FIELD") for data binding.
 *   backcolor   - Array: Background RGB color vector {Red, Green, Blue}.
 *   fontcolor   - Array/Numeric: Font RGB color vector {Red, Green, Blue} or color handle.
 *   plaintext   - Logical: If .T., file content is streamed as plain text; otherwise RTF (defaults to .F.).
 *   nohscroll   - Logical: If .T., disables horizontal scroll bar (defaults to .F.).
 *   novscroll   - Logical: If .T., disables vertical scroll bar.
 *   select      - Block/Character: Callback event executed on double-click selection.
 *   vscroll     - Block/Character: Custom scroll/notification callback procedure.
 *
 * Return Value:
 *   Nil
 *
 * Side Effects:
 *   - Registers control in global HMG tracking arrays (`_HMG_aControl*`).
 *   - Creates Win32 RichEdit window handle via `InitRichEditBox()`.
 *   - Declares public runtime variable identifier `_<ParentForm>_<ControlName>`.
 *   - Loads file stream or database memo field contents if specified.
 */
FUNCTION _DefineRichEditBox( ControlName, ParentForm, x, y, w, h, value, ;
      fontname, fontsize, tooltip, maxlength, gotfocus, change, lostfocus, readonly, ;
      break, HelpId, invisible, notabstop, bold, italic, underline, strikeout, file, ;
      field, backcolor, fontcolor, plaintext, nohscroll, novscroll, select, vscroll )
   LOCAL ControlHandle, FontHandle
   LOCAL cParentForm, mVar, k, ContainerHandle := 0
   LOCAL WorkArea, i

   // Set default parameters for uninitialized optional arguments
   hb_default( @w, 120 )
   hb_default( @h, 240 )
   hb_default( @file, "" )
   hb_default( @field, "" )
   hb_default( @value, "" )
   hb_default( @maxlength, 64738 )
   hb_default( @invisible, .F. )
   hb_default( @notabstop, .F. )
   hb_default( @nohscroll, .F. )
   hb_default( @plaintext, .F. )

   // Normalize callback procedure parameters to empty string when NIL
   __defaultNIL( @change, "" )
   __defaultNIL( @lostfocus, "" )
   __defaultNIL( @gotfocus, "" )

   // Retrieve existing font parameters if font name is a valid HMG font handle
   IF ( FontHandle := GetFontHandle( fontname ) ) != 0
      GetFontParamByRef( FontHandle, @fontname, @fontsize, @bold, @italic, @underline, @strikeout )
   ENDIF

   // Bind to active workarea field value if qualified field name ("ALIAS->FIELD") is supplied
   IF !Empty( field )
      IF hb_UAt( '>', field ) == 0
         MsgMiniGuiError( "Control: " + ControlName + " Of " + ParentForm + " : You must specify a fully qualified field name." )
      ELSE
         WorkArea := hb_ULeft( field, hb_UAt( '>', field ) - 2 )
         IF Select( WorkArea ) != 0
            value := &( field )
         ENDIF
      ENDIF
   ENDIF

   // Inherit context settings when control is created within active window block
   IF _HMG_BeginWindowActive
      ParentForm := _HMG_ActiveFormName
      __defaultNIL( @fontname, _HMG_ActiveFontName )
      __defaultNIL( @fontsize, _HMG_ActiveFontSize )
   ENDIF

   // Adjust coordinates relative to parent FRAME container if nested
   IF _HMG_FrameLevel > 0 .AND. !_HMG_ParentWindowActive
      x += _HMG_ActiveFrameCol[ _HMG_FrameLevel ]
      y += _HMG_ActiveFrameRow[ _HMG_FrameLevel ]
      ParentForm := _HMG_ActiveFrameParentFormName[ _HMG_FrameLevel ]
   ENDIF

   // Validate existence of parent form
   IF ! _IsWindowDefined( ParentForm )
      MsgMiniGuiError( "Window: " + IFNIL( ParentForm, "Parent", ParentForm ) + " is not defined." )
   ENDIF

   // Auto-generate control name if placeholder name "0" is provided
   IF ISCHAR( ControlName ) .AND. ControlName == "0"
      ControlName := HMG_GetUniqueName()
   ENDIF

   // Ensure control name uniqueness within target parent window scope
   IF _IsControlDefined( ControlName, ParentForm )
      MsgMiniGuiError( "Control: " + ControlName + " Of " + ParentForm + " Already defined." )
   ENDIF

   // Build global symbol name for indexing control reference
   mVar := '_' + ParentForm + '_' + ControlName
   cParentForm := ParentForm
   ParentForm := GetFormHandle( ParentForm )

   // Position control: dynamic SplitBox insertion (x/y NIL) vs absolute coordinate placement
   IF x == NIL .OR. y == NIL
      IF _HMG_SplitLastControl == 'TOOLBAR'
         break := .T.
      ENDIF
      _HMG_SplitLastControl := 'RICHEDIT'

      i := GetFormIndex( cParentForm )
      IF i > 0
         ControlHandle := InitRichEditBox( _HMG_aFormReBarHandle[i], 0, x, y, w, h, '', 0, maxlength, ;
            readonly, invisible, notabstop, nohscroll, novscroll )

         IF FontHandle != 0
            _SetFontHandle( ControlHandle, FontHandle )
         ELSE
            __defaultNIL( @fontname, _HMG_DefaultFontName )
            __defaultNIL( @fontsize, _HMG_DefaultFontSize )
            FontHandle := _SetFont( ControlHandle, fontname, fontsize, bold, italic, underline, strikeout )
         ENDIF

         AddSplitBoxItem( ControlHandle, _HMG_aFormReBarHandle[i], w, break, , , , _HMG_ActiveSplitBoxInverted )
         ContainerHandle := _HMG_aFormReBarHandle[i]
      ENDIF
   ELSE
      // Standard window control creation
      ControlHandle := InitRichEditBox( ParentForm, 0, x, y, w, h, '', 0, maxlength, ;
         readonly, invisible, notabstop, nohscroll, novscroll )

      IF FontHandle != 0
         _SetFontHandle( ControlHandle, FontHandle )
      ELSE
         __defaultNIL( @fontname, _HMG_DefaultFontName )
         __defaultNIL( @fontsize, _HMG_DefaultFontSize )
         FontHandle := _SetFont( ControlHandle, fontname, fontsize, bold, italic, underline, strikeout )
      ENDIF

      // Configure Win32 RichEdit character format attributes
      SetFontRTF( ControlHandle, IFARRAY( fontcolor, -1, 0 ), fontname, fontsize, bold, italic, ;
         iif( IsArrayRGB( fontcolor ), RGB( fontcolor[1], fontcolor[2], fontcolor[3] ), NIL ), underline, strikeout )
   ENDIF

   // Attach control handle to current page container when defined inside TAB block
   IF _HMG_BeginTabActive
      AAdd( _HMG_ActiveTabCurrentPageMap, ControlHandle )
   ENDIF

   // Set hover tooltip for control handle
   IF tooltip != NIL
      SetToolTip( ControlHandle, tooltip, GetFormToolTipHandle( cParentForm ) )
   ENDIF

   // Apply background RGB color to Win32 control
   IF IsArrayRGB( backcolor )
      SetBkgndColor( ControlHandle, .T., backcolor[1], backcolor[2], backcolor[3] )
   ENDIF

   // Stream initial document contents from specified file if available
   IF File( file )
      StreamIn( ControlHandle, file, iif( plaintext, 1, 2 ) )
   ELSE
      file := ""
   ENDIF

   // Find next available slot in HMG global control registry
   k := _GetControlFree()
#ifdef _NAMES_LIST_
   _SetNameList( mVar, k )
#else
   Public &mVar. := k
#endif

   // Store control attributes in global internal tracking arrays
   _HMG_aControlType[k] := "RICHEDIT"
   _HMG_aControlNames[k] := ControlName
   _HMG_aControlHandles[k] := ControlHandle
   _HMG_aControlParenthandles[k] := ParentForm
   _HMG_aControlIds[k] := 0
   _HMG_aControlProcedures[k] := vscroll
   _HMG_aControlPageMap[k] := field
   _HMG_aControlValue[k] := Nil
   _HMG_aControlInputMask[k] := ""
   _HMG_aControllostFocusProcedure[k] := lostfocus
   _HMG_aControlGotFocusProcedure[k] := gotfocus
   _HMG_aControlChangeProcedure[k] := change
   _HMG_aControlDeleted[k] := .F.
   _HMG_aControlBkColor[k] := backcolor
   _HMG_aControlFontColor[k] := fontcolor
   _HMG_aControlDblClick[k] := select
   _HMG_aControlHeadClick[k] := {}
   _HMG_aControlRow[k] := y
   _HMG_aControlCol[k] := x
   _HMG_aControlWidth[k] := w
   _HMG_aControlHeight[k] := h
   _HMG_aControlSpacing[k] := 0
   _HMG_aControlContainerRow[k] := iif( _HMG_FrameLevel > 0, _HMG_ActiveFrameRow[_HMG_FrameLevel], -1 )
   _HMG_aControlContainerCol[k] := iif( _HMG_FrameLevel > 0, _HMG_ActiveFrameCol[_HMG_FrameLevel], -1 )
   _HMG_aControlPicture[k] := ""
   _HMG_aControlContainerHandle[k] := ContainerHandle
   _HMG_aControlFontName[k] := fontname
   _HMG_aControlFontSize[k] := fontsize
   _HMG_aControlFontAttributes[k] := { bold, italic, underline, strikeout }
   _HMG_aControlToolTip[k] := tooltip
   _HMG_aControlRangeMin[k] := 0
   _HMG_aControlRangeMax[k] := 0
   _HMG_aControlCaption[k] := file
   _HMG_aControlVisible[k] := !invisible
   _HMG_aControlHelpId[k] := HelpId
   _HMG_aControlFontHandle[k] := FontHandle
   _HMG_aControlBrushHandle[k] := 0
   _HMG_aControlEnabled[k] := .T.
   _HMG_aControlMiscData1[k] := 0
   _HMG_aControlMiscData2[k] := ''

   // Invoke object initializer block if Object-Oriented framework mode is enabled
   IF _HMG_lOOPEnabled
      Eval( _HMG_bOnControlInit, k, mVar )
   ENDIF

   // Set initial content value if non-empty string was provided
   IF Len( value ) > 0
      _SetValue( , , value, k )
   ENDIF

RETURN Nil


/*
 * Routine: _DataBaseRichEditBoxSave
 * Purpose:
 *   Saves the contents of a RichEditBox control directly to its bound database memo field.
 *
 * Parameters:
 *   ControlName - Character: Name of the RichEdit control.
 *   ParentForm  - Character: Name of the parent window/form containing the control.
 *   typ         - Numeric: Content format indicator (1 = Plain Text, 2 = Rich Text Format).
 *
 * Return Value:
 *   Nil
 *
 * Side Effects:
 *   - Streams control content to a temporary file on disk.
 *   - Updates active database table field using dynamic macro REPLACE assignment.
 *   - Deletes temporary disk file after transfer.
 */
PROCEDURE _DataBaseRichEditBoxSave( ControlName, ParentForm, typ )
   LOCAL cTempFile := TempFile( GetTempFolder(), 'txt' )
   LOCAL Field, i

   // Exit immediately if temporary file creation fails
   IF Empty( cTempFile )
      RETURN
   ENDIF

   // Look up control index and retrieve mapped field expression
   i := GetControlIndex( ControlName, ParentForm )
   Field := _HMG_aControlPageMap[i]

   // Stream control text out to temporary file
   _DataRichEditBoxSave( ControlName, ParentForm, cTempFile, typ )

   // Perform REPLACE on target database field if field is valid
   IF _IsFieldExists( Field )
      REPLACE &Field WITH MemoRead( cTempFile )
   ENDIF

   // Clean up temporary disk file
   FErase( cTempFile )

RETURN

/*
 * Routine: _DataRichEditBoxSetValue
 * Purpose:
 *   Loads string-based document data (plain text or RTF) into a RichEditBox control.
 *
 * Parameters:
 *   ControlName - Character: Name of the target RichEdit control.
 *   ParentForm  - Character: Name of parent window containing the control.
 *   cRichValue  - Character: Raw string buffer (text or RTF) to stream into control.
 *   typ         - Numeric: Format stream type indicator (1 = Plain Text, 2 = Rich Text Format).
 *
 * Return Value:
 *   Character: Returns the input string `cRichValue`.
 *
 * Side Effects:
 *   - Writes string buffer to a temporary disk file.
 *   - Triggers `_DataRichEditBoxOpen()` to stream file contents into Win32 RichEdit control.
 *   - Erases temporary file upon completion.
 */
FUNCTION _DataRichEditBoxSetValue( ControlName, ParentForm, cRichValue, typ )
   LOCAL cTempFile := TempFile( GetTempFolder(), 'txt' )

   IF !Empty( cTempFile )
      // Write memory contents to disk temporary file for streaming into Win32 control
      hb_MemoWrit( cTempFile, cRichValue )
      _DataRichEditBoxOpen( ControlName, ParentForm, cTempFile, typ )
      FErase( cTempFile )
   ENDIF

RETURN cRichValue

/*
 * Routine: _DataRichEditBoxGetValue
 * Purpose:
 *   Retrieves text or RTF content from a RichEditBox control as a character string.
 *
 * Parameters:
 *   ControlName - Character: Name of target RichEdit control.
 *   ParentForm  - Character: Name of parent window containing the control.
 *   typ         - Numeric: Format stream type indicator (1 = Plain Text, 2 = Rich Text Format).
 *
 * Return Value:
 *   Character: String buffer containing current control content, or "" on failure.
 *
 * Side Effects:
 *   - Streams RichEdit control data to a temporary disk file.
 *   - Reads file into memory via `MemoRead()` and erases temporary file.
 */
FUNCTION _DataRichEditBoxGetValue( ControlName, ParentForm, typ )
   LOCAL cTempFile := TempFile( GetTempFolder(), 'txt' )
   LOCAL cRichValue := ""

   IF !Empty( cTempFile )
      // Stream control content into temporary file and read back as character string
      _DataRichEditBoxSave( ControlName, ParentForm, cTempFile, typ )
      cRichValue := MemoRead( cTempFile )
      FErase( cTempFile )
   ENDIF

RETURN cRichValue

/*
 * Routine: _DataRichEditBoxOpen
 * Purpose:
 *   Streams text or RTF document contents from a disk file into a RichEditBox control.
 *
 * Parameters:
 *   ControlName - Character: Name of target RichEdit control.
 *   ParentForm  - Character: Name of parent window containing the control.
 *   cFile       - Character: Path of file to stream into control.
 *   typ         - Numeric (Optional): Format type (1 = Plain Text, 2 = RTF). Defaults to 2.
 *
 * Return Value:
 *   Nil
 *
 * Side Effects:
 *   - Updates stored control caption array (`_HMG_aControlCaption`) with file path.
 *   - Performs Win32 StreamIn API operation to replace current control content.
 */
PROCEDURE _DataRichEditBoxOpen( ControlName, ParentForm, cFile, typ )
   LOCAL i := GetControlIndex( ControlName, ParentForm )

   IF i > 0
      // Update internal file reference caption and stream file content into Win32 control
      _HMG_aControlCaption[i] := cFile
      StreamIn( GetControlHandle( ControlName, ParentForm ), cFile, hb_defaultValue( typ, 2 ) )
   ENDIF

RETURN

/*
 * Routine: _DataRichEditBoxSave
 * Purpose:
 *   Streams current content from a RichEditBox control into a target file on disk.
 *
 * Parameters:
 *   ControlName - Character: Name of target RichEdit control.
 *   ParentForm  - Character: Name of parent window containing the control.
 *   cFile       - Character (Optional): Destination file path. Defaults to stored caption path if NIL.
 *   typ         - Numeric (Optional): Format type (1 = Plain Text, 2 = RTF). Defaults to 2.
 *
 * Return Value:
 *   Nil
 *
 * Side Effects:
 *   - Executes Win32 StreamOut API operation, creating or overwriting target disk file.
 */
PROCEDURE _DataRichEditBoxSave( ControlName, ParentForm, cFile, typ )
   LOCAL i := GetControlIndex( ControlName, ParentForm )

   IF i > 0
      // Default to registered file caption if destination filename is not provided
      IF cFile == NIL
         cFile := _HMG_aControlCaption[i]
      ENDIF
      StreamOut( GetControlHandle( ControlName, ParentForm ), cFile, hb_defaultValue( typ, 2 ) )
   ENDIF

RETURN