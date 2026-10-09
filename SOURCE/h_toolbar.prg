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
#include "i_winuser.ch"

#if defined( __XHARBOUR__ ) .OR. ( __HARBOUR__ - 0 < 0x030200 )
#  xtranslate hb_UAt( <c>, <n> ) => At( <c>, <n> )
#endif

/*
 * Routine: _DefineToolBar
 * Purpose: Creates and initializes a Win32 toolbar control within a parent window or container.
 *
 * Parameters:
 *   ControlName   (Character) Name of the toolbar control to create.
 *   ParentForm    (Character|Numeric) Form name or handle hosting the toolbar.
 *   x             (Numeric) X-coordinate position relative to parent window.
 *   y             (Numeric) Y-coordinate position relative to parent window.
 *   caption       (Character) Caption or title text associated with the toolbar.
 *   ProcedureName (Character|Block) Associated event handler or action procedure.
 *   w             (Numeric) Default width for toolbar items/buttons.
 *   h             (Numeric) Default height for toolbar items/buttons.
 *   fontname      (Character) Name of the font applied to toolbar text labels.
 *   fontsize      (Numeric) Size of the font in points.
 *   tooltip       (Character) Tooltip text assigned to the toolbar control.
 *   flat          (Logical) Enables flat visual style without raised borders when .T.
 *   bottom        (Logical) Places text captions below icons when .T.
 *   righttext     (Logical) Places text captions to the right of icons when .T.
 *   break         (Logical) Forces a new band/row inside a ReBar/SplitBox container when .T.
 *   bold          (Logical) Applies bold font weight when .T.
 *   italic        (Logical) Applies italic font slant when .T.
 *   underline     (Logical) Applies underline font attribute when .T.
 *   strikeout     (Logical) Applies strikeout font attribute when .T.
 *   border        (Logical) Displays a window border around the toolbar control when .T.
 *   mixedbuttons  (Logical) Allows mixing buttons with text and without text (Extended style).
 *   rows          (Numeric) Number of button rows when using vertical or multi-row layouts.
 *   tbsize        (Numeric) Minimum size constraint stored for ReBar band calculations.
 *   imagelst      (Numeric|Character) Handle or name of the normal image list.
 *   hotimagelst   (Numeric|Character) Handle or name of the hot/hover image list.
 *   wrap          (Logical) Enables text/button wrapping across multiple lines when .T.
 *   custom        (Logical) Enables custom toolbar configuration options when .T.
 *
 * Return Value:
 *   Numeric - Windows handle (HWND) of the newly created toolbar control.
 *
 * Side Effects:
 *   Registers the toolbar in internal HMG control tracking arrays (_HMG_aControl*).
 *   Creates a dynamic public reference variable named '_<ParentForm>_<ControlName>'.
 *   Updates active global state variables (_HMG_ActiveToolBarCaption, _HMG_ActiveToolBarBreak, etc.).
 */
FUNCTION _DefineToolBar ( ControlName, ParentForm, x, y, caption, ProcedureName, w, h, fontname, fontsize, tooltip, flat, bottom, righttext, break, bold, italic, underline, strikeout, border, mixedbuttons, rows, tbsize, imagelst, hotimagelst, wrap, custom )
   LOCAL FontHandle , ControlHandle
   LOCAL cParentForm
   LOCAL mVar
   LOCAL id
   LOCAL k

   // Ensure the parent form exists before attaching the toolbar control
   IF .NOT. _IsWindowDefined ( ParentForm )
      MsgMiniGuiError ( "Window: " + ParentForm + " is not defined." )
   ENDIF

   // Prevent duplicate control definitions under the same parent window
   IF _IsControlDefined ( ControlName, ParentForm )
      MsgMiniGuiError ( "Control: " + ControlName + " Of " + ParentForm + " Already defined." )
   ENDIF

   // Retrieve existing font attributes if a valid font name/handle is supplied
   IF ( FontHandle := GetFontHandle( FontName ) ) != 0
      GetFontParamByRef( FontHandle, @FontName, @FontSize, @bold, @italic, @underline, @strikeout )
   ENDIF

   // Store break state for container layout band formatting
   _HMG_ActiveToolBarBreak := break

   // Generate dynamic variable name for global scope access
   mVar := '_' + ParentForm + '_' + ControlName

   cParentForm := ParentForm

   // Resolve parent handle based on active Pager state or window handle
   ParentForm := iif( _HMG_BeginPagerActive, _HMG_ActivePagerForm, GetFormHandle ( ParentForm ) )

   Id := _GetId()

   // Track toolbar type when embedded within a SplitBox container
   IF _HMG_ActiveSplitBox
      _HMG_SplitLastControl := 'TOOLBAR'
   ENDIF

   _HMG_ActiveToolBarCaption := Caption

   // Instantiate native Windows toolbar using extended or standard initializer
   IF _HMG_ActiveToolBarExtend
      ControlHandle := InitToolBarEx ( ParentForm, Caption, id, 0, 0, w, h, "" , 0 , flat , bottom , righttext , _HMG_ActiveSplitBox , border , mixedbuttons , wrap, custom )
   ELSE
      ControlHandle := InitToolBar ( ParentForm, Caption, id, 0, 0, w, h, "" , 0 , flat , bottom , righttext , _HMG_ActiveSplitBox , border , wrap, custom )
   ENDIF

   // Apply existing font handle or construct a new font object
   IF FontHandle != 0
      _SetFontHandle( ControlHandle, FontHandle )
   ELSE
      __defaultNIL( @FontName, _HMG_DefaultFontName )
      __defaultNIL( @FontSize, _HMG_DefaultFontSize )
      FontHandle := _SetFont ( ControlHandle, FontName, FontSize, bold, italic, underline, strikeout )
   ENDIF

   // Attach tooltip control if text was provided
   IF tooltip != NIL
      SetToolTip ( ControlHandle , tooltip , GetFormToolTipHandle ( cParentForm ) )
   ENDIF

   // Allocate new index in internal control registry
   k := _GetControlFree()

#ifdef _NAMES_LIST_
   _SetNameList( mVar , k )
#else
   Public &mVar. := k
#endif

   // Store complete metadata in HMG global control arrays
   _HMG_aControlType  [k] := "TOOLBAR"
   _HMG_aControlNames   [k] := ControlName
   _HMG_aControlHandles  [k] :=  ControlHandle
   _HMG_aControlParenthandles  [k] :=  ParentForm
   _HMG_aControlIds  [k] :=  id
   _HMG_aControlProcedures  [k] :=  ProcedureName
   _HMG_aControlPageMap  [k] :=  {}
   _HMG_aControlValue  [k] :=  { imagelst, hotimagelst }
   _HMG_aControlInputMask   [k] := ""
   _HMG_aControllostFocusProcedure  [k] :=  ""
   _HMG_aControlGotFocusProcedure  [k] :=  ""
   _HMG_aControlChangeProcedure  [k] :=  ""
   _HMG_aControlDeleted  [k] :=  .F.
   _HMG_aControlBkColor   [k] := Nil
   _HMG_aControlFontColor  [k] :=  Nil
   _HMG_aControlDblClick   [k] := ""
   _HMG_aControlHeadClick  [k] :=  {}
   _HMG_aControlRow  [k] :=  y
   _HMG_aControlCol  [k] :=  x
   _HMG_aControlWidth   [k] := w
   _HMG_aControlHeight   [k] := h
   _HMG_aControlSpacing   [k] := rows
   _HMG_aControlContainerRow  [k] :=  -1
   _HMG_aControlContainerCol  [k] :=  -1
   _HMG_aControlPicture   [k] := ""
   _HMG_aControlContainerHandle  [k] :=  0
   _HMG_aControlFontName  [k] :=  ''
   _HMG_aControlFontSize   [k] := 0
   _HMG_aControlFontAttributes  [k] :=  { .F. , .F. , .F. , .F. }
   _HMG_aControlToolTip  [k] :=  ''
   _HMG_aControlRangeMin [k] :=  tbsize
   _HMG_aControlRangeMax [k] :=  iif( wrap, 1, 0 )
   _HMG_aControlCaption  [k] :=  Caption
   _HMG_aControlVisible  [k] :=  .T.
   _HMG_aControlHelpId   [k] :=  0
   _HMG_aControlFontHandle  [k] :=  FontHandle
   _HMG_aControlBrushHandle [k] :=  0
   _HMG_aControlEnabled  [k] :=  .T.
   _HMG_aControlMiscData1 [k] :=  0
   _HMG_aControlMiscData2 [k] :=  ''

   // Trigger Object-Oriented initialization callback if OOP framework is active
   IF _HMG_lOOPEnabled
      Eval ( _HMG_bOnControlInit, k, mVar )
   ENDIF

RETURN ControlHandle

/*
 * Routine: _EndToolBar
 * Purpose: Concludes a toolbar definition block, inserting it into parent containers and recalculating metrics.
 *
 * Parameters:
 *   None.
 *
 * Return Value:
 *   NIL
 *
 * Side Effects:
 *   Inserts toolbar into active Pager or SplitBox container if active.
 *   Recalculates multi-row band boundaries for SplitBox controls.
 *   Resets global active toolbar state flags (_HMG_ActiveToolBarName, _HMG_ToolBarActive, etc.).
 */
FUNCTION _EndToolBar()
   LOCAL ParentForm, h
   LOCAL aSize
   LOCAL nRow, nBand
   LOCAL ix, i

   // Resolve active parent form name and toolbar window handle
   ParentForm := iif ( _HMG_BeginWindowActive, _HMG_ActiveFormName, _HMG_ActiveToolBarFormName )
   h := GetControlHandle ( _HMG_ActiveToolBarName , ParentForm )

   // Embed toolbar in active Pager or SplitBox ReBar container
   IF _HMG_BeginPagerActive
#ifdef _PAGER_
      _AddChildToPager ( _HMG_ActiveToolBarName , ParentForm )
#endif
   ELSE
      IF _HMG_ActiveSplitBox
         _AddToolBarToSplitBox ( _HMG_ActiveToolBarName , _HMG_ActiveToolBarBreak , _HMG_ActiveToolBarCaption , ParentForm )
         ix     := GetControlIndex ( _HMG_ActiveToolBarName, ParentForm )
         i      := GetFormIndex ( _HMG_ActiveSplitBoxParentFormName )
         nBand  := GetBandCount ( _HMG_aFormReBarHandle [i] )
         _HMG_aControlMiscData1 [ix] := nBand
         nRow   := _HMG_aControlSpacing [ix]
         // Resize parent ReBar band for multi-row toolbar configurations
         IF nRow > 1
            aSize := SetRowsButton ( h , nRow , .T. )
            ResizeSplitBoxItem ( _HMG_aFormReBarHandle [i], nBand - 1, aSize [1], aSize [2], aSize [1] )
         ENDIF
      ELSE
         // Adjust text button metrics on standard standalone toolbars
         MaxTextBtnToolBar ( h, _GetControlWidth ( _HMG_ActiveToolBarName, ParentForm ), _GetControlHeight ( _HMG_ActiveToolBarName, ParentForm ) )
      ENDIF
   ENDIF

   // Clear active toolbar definition global variables
   _HMG_ActiveToolBarBreak    := .F.
   _HMG_ActiveToolBarExtend   := .F.

   _HMG_ActiveToolBarName     := ""
   _HMG_ActiveToolBarFormName := ""

   _HMG_ToolBarActive         := .F.

RETURN Nil

/*
 * Routine: _DefineToolButton
 * Purpose: Defines and appends an individual button or visual separator to an active toolbar control.
 *
 * Parameters:
 *   ControlName    (Character) Unique name for the tool button control.
 *   ParentControl  (Character) Name of the parent toolbar control hosting this button.
 *   x              (Numeric) X-coordinate position relative to container.
 *   y              (Numeric) Y-coordinate position relative to container.
 *   Caption        (Character) Text label displayed on or beside the button.
 *   ProcedureName  (Character|Block) Callback action executed when the button is clicked.
 *   w              (Numeric) Button width (defaults to active toolbar width).
 *   h              (Numeric) Button height (defaults to active toolbar height).
 *   image          (Character) Bitmap resource name or image file path.
 *   tooltip        (Character) Tooltip text displayed on mouse hover.
 *   gotfocus       (Character|Block) Focus arrival event handler.
 *   lostfocus      (Character|Block) Focus loss event handler.
 *   flat           (Logical) Unused visual flag maintained for interface symmetry.
 *   separator      (Logical) Creates a spacing separator instead of an interactive button when .T.
 *   autosize       (Logical) Automatically sizes button to fit caption and icon dimensions when .T.
 *   check          (Logical) Enables toggle/check state behavior when .T.
 *   group          (Logical) Enables radio-group check behavior when .T.
 *   dropdown       (Logical) Adds a dropdown arrow menu trigger to the button when .T.
 *   WholeDropDown  (Logical) Whole button acts exclusively as a dropdown menu trigger when .T.
 *   adjust         (Logical) Stretches/adjusts image to fit button bounds when .T.
 *   imageindex     (Numeric) Zero-based index of image within associated image list.
 *   notrans        (Logical) Disables transparent image background rendering when .T.
 *
 * Return Value:
 *   NIL
 *
 * Side Effects:
 *   Appends a new button element to the Win32 toolbar control.
 *   Registers control entry in internal HMG tracking structures (_HMG_aControl*).
 *   Registers dynamic keyboard access key (e.g., '&File') if defined in caption.
 */
FUNCTION _DefineToolButton ( ControlName, ParentControl, x, y, Caption, ProcedureName, w, h, image , tooltip , gotfocus , lostfocus , flat , separator , autosize , check , group , dropdown , WholeDropDown, adjust , imageindex, notrans )
   LOCAL ParentForm
   LOCAL hParentForm
   LOCAL cParentForm
   LOCAL mVar
   LOCAL ControlHandle
   LOCAL aImage
   LOCAL imagelst, hotimagelst
   LOCAL id
   LOCAL npos, nToolBarIndex
   LOCAL i , k

   HB_SYMBOL_UNUSED( Flat )

   // Enforce rule that dropdown buttons must have actions unless WholeDropDown style is used
   IF ProcedureName == NIL .AND. Dropdown
      MsgMiniGuiError ( "ToolBar DropDown buttons must have an associated action (Use WholeDropDown style for no action)." )
   ENDIF

   // Enforce rule that WholeDropDown buttons cannot have a direct click procedure
   IF ProcedureName != NIL .AND. WholeDropDown
      MsgMiniGuiError ( "ToolBar Action and WholeDropDown clauses can't be used simultaneously." )
   ENDIF

   // Identify active parent form name and handle
   ParentForm := iif( _HMG_BeginWindowActive, _HMG_ActiveFormName, _HMG_ActiveToolBarFormName )

   cParentForm := ParentForm
   hParentForm := GetFormHandle ( ParentForm )

   mVar := '_' + ParentForm + '_' + ControlName

   // Resolve parent toolbar handle
   ParentForm := GetControlHandle ( ParentControl, ParentForm )

   id := _GetId()

   hb_default( @Caption, "" )
   hb_default( @image, "" )

   // Fall back to default active toolbar dimensions when width or height are omitted
   hb_default( @w, _GetControlWidth ( _HMG_ActiveToolBarName, cParentForm ) )
   hb_default( @h, _GetControlHeight ( _HMG_ActiveToolBarName, cParentForm ) )

   __defaultNIL( @gotfocus, "" )
   __defaultNIL( @lostfocus, "" )
   __defaultNIL( @tooltip, "" )
   hb_default( @notrans, .F. )

   // Generate blank placeholder image if image file/resource is invalid
   IF ! Empty ( image ) .AND. Empty ( BmpSize( image ) [1] )
      image := _GetDummyImage()
   ENDIF

   // Retrieve dynamic image list references when image index is specified
   IF imageindex != NIL
      aImage      := GetControlValue ( _HMG_ActiveToolBarName, cParentForm )
      imagelst    := aImage [1]
      hotimagelst := aImage [2]
   ELSE
      imageindex := -1
   ENDIF

   // Initialize low-level tool button using extended or standard native API
   IF _HMG_ActiveToolBarExtend
      ControlHandle := InitToolButtonEx ( ParentForm, Caption, id, 0, 0, w, h, image, notrans, separator, autosize, check, group, dropdown, WholeDropDown, adjust, imageindex, imagelst, hotimagelst )
   ELSE
      ControlHandle := InitToolButton ( ParentForm, Caption, id, 0, 0, w, h, image, notrans, separator, autosize, check, group, dropdown, WholeDropDown, adjust )
   ENDIF

   // Determine zero-based button position index on parent toolbar
   nPos := GetButtonBarCount ( ParentForm ) - iif( separator, 1, 0 )

   // Reserve next available slot in control tables
   k := _GetControlFree()

#ifdef _NAMES_LIST_
   _SetNameList( mVar , k )
#else
   Public &mVar. := k
#endif

   // Store tool button state in HMG control arrays
   _HMG_aControlType [k] := "TOOLBUTTON"
   _HMG_aControlNames  [k] :=  ControlName
   _HMG_aControlHandles  [k] :=  ControlHandle
   _HMG_aControlParenthandles [k] :=  hParentForm
   _HMG_aControlIds  [k] :=  id
   _HMG_aControlProcedures  [k] :=  ProcedureName
   _HMG_aControlPageMap  [k] :=  {}
   _HMG_aControlValue  [k] :=  nPos
   _HMG_aControlInputMask  [k] :=  ""
   _HMG_aControllostFocusProcedure [k] :=  lostfocus
   _HMG_aControlGotFocusProcedure  [k] :=  gotfocus
   _HMG_aControlChangeProcedure  [k] :=  ""
   _HMG_aControlDeleted  [k] :=  .F.
   _HMG_aControlBkColor  [k] :=  Nil
   _HMG_aControlFontColor  [k] :=  Nil
   _HMG_aControlDblClick  [k] :=  ""
   _HMG_aControlHeadClick  [k] :=  {}
   _HMG_aControlRow  [k] :=  y
   _HMG_aControlCol  [k] :=  x
   _HMG_aControlWidth   [k] := w
   _HMG_aControlHeight   [k] := h
   _HMG_aControlSpacing  [k] :=  0
   _HMG_aControlContainerRow  [k] :=  -1
   _HMG_aControlContainerCol  [k] :=  -1
   _HMG_aControlPicture  [k] := image
   _HMG_aControlContainerHandle  [k] :=  ParentForm
   _HMG_aControlFontName  [k] :=  ''
   _HMG_aControlFontSize   [k] :=  0
   _HMG_aControlFontAttributes  [k] :=  { .F. , .F. , .F. , .F. }
   _HMG_aControlToolTip  [k] :=  tooltip
   _HMG_aControlRangeMin [k] :=  0
   _HMG_aControlRangeMax [k] :=  0
   _HMG_aControlCaption  [k] :=  Caption
   _HMG_aControlVisible  [k] :=  .T.
   _HMG_aControlHelpId   [k] :=  0
   _HMG_aControlFontHandle   [k] :=  0
   _HMG_aControlBrushHandle  [k] :=  0
   _HMG_aControlEnabled  [k] :=  .T.
   _HMG_aControlMiscData1 [k] :=  iif( _HMG_ActiveToolBarExtend, 1, 0 )
   _HMG_aControlMiscData2 [k] :=  ''

   // Invoke OOP initialization delegate if enabled
   IF _HMG_lOOPEnabled
      Eval ( _HMG_bOnControlInit, k, mVar )
   ENDIF

   Caption := Upper ( Caption )

   // Register mnemonic hotkey shortcut if caption contains an ampersand (&)
   IF ( i := hb_UAt ( '&', Caption ) ) > 0

      IF WholeDropDown
         nToolBarIndex := AScan ( _HMG_aControlHandles, ParentForm )
         ProcedureName := { || _DropDownShortcut ( Id, hParentForm, nToolBarIndex, nPos ) }
      ENDIF

      _DefineLetterOrDigitHotKey ( Caption, i, cParentForm, ProcedureName )

   ENDIF

RETURN Nil

/*
 * Routine: _AddToolBarToSplitBox
 * Purpose: Internal helper routine that inserts a toolbar control into a SplitBox ReBar container band.
 *
 * Parameters:
 *   ControlName (Character) Name of the toolbar control to add.
 *   break       (Logical) Forces a new band line when .T.
 *   Caption     (Character) Title text displayed on the ReBar band header.
 *   ParentForm  (Character|Numeric) Form containing the toolbar control.
 *
 * Return Value:
 *   NIL
 *
 * Side Effects:
 *   Modifies the ReBar structure of the parent SplitBox form.
 *   Calculates minimum size boundaries for vertical or horizontal orientation.
 */
STATIC FUNCTION _AddToolBarToSplitBox ( ControlName, break, Caption, ParentForm )
   LOCAL MinWidth, MinHeight
   LOCAL i, c, w, ix

   i := GetFormIndex ( _HMG_ActiveSplitBoxParentFormName )
   c := GetControlHandle ( ControlName, _HMG_ActiveSplitBoxParentFormName )

   // Optimize button layout on standard non-extended toolbars
   IF ! _HMG_ActiveToolBarExtend
      MaxTextBtnToolBar ( c, _GetControlWidth ( ControlName, ParentForm ), _GetControlHeight ( ControlName, ParentForm ) )
   ENDIF

   w := GetSizeToolBar ( c )

   MinWidth  := HiWord ( w )
   MinHeight := LoWord ( w )

   w := GetWindowWidth ( c )

   ix := GetControlIndex ( ControlName, ParentForm )
   
   // Handle WRAP style orientation adjustments in vertical ReBar containers
   IF ( _HMG_aControlRangeMax [ix] == 1 ) .AND. ;
      ( And( GetWindowLong ( _HMG_aFormReBarHandle [i] , GWL_STYLE ) , CCS_VERT ) == CCS_VERT )
      MinWidth  := _HMG_aControlWidth [ix]
      MinHeight := HiWord ( w )
   ENDIF

   // Attach toolbar band item into active ReBar container control
   IF i > 0
      AddSplitBoxItem ( c , _HMG_aFormReBarHandle [i] , w , break , Caption , MinWidth , MinHeight , _HMG_ActiveSplitBoxInverted , _HMG_aControlRangeMin [ix] )
   ENDIF

RETURN Nil

/*
 * Routine: _BeginToolBar
 * Purpose: Initiates a standard toolbar definition block in command syntax.
 *
 * Parameters:
 *   name          (Character) Control name assigned to the toolbar.
 *   parent        (Character) Host window name (defaults to active window).
 *   row           (Numeric) Y position coordinate relative to container.
 *   col           (Numeric) X position coordinate relative to container.
 *   w             (Numeric) Toolbar control width.
 *   h             (Numeric) Toolbar control height.
 *   caption       (Character) Caption text associated with toolbar band.
 *   ProcedureName (Character|Block) Action event handler for toolbar.
 *   fontname      (Character) Font name string.
 *   fontsize      (Numeric) Font point size.
 *   tooltip       (Character) Tooltip text assigned to toolbar.
 *   flat          (Logical) Enables flat toolbar style without borders when .T.
 *   bottom        (Logical) Displays text below button icons when .T.
 *   righttext     (Logical) Displays text to the right of button icons when .T.
 *   break         (Logical) Forces new band row in SplitBox container when .T.
 *   bold          (Logical) Applies bold font attribute when .T.
 *   italic        (Logical) Applies italic font attribute when .T.
 *   underline     (Logical) Applies underline font attribute when .T.
 *   strikeout     (Logical) Applies strikeout font attribute when .T.
 *   border        (Logical) Displays window border around toolbar when .T.
 *   wrap          (Logical) Enables multi-line button wrapping when .T.
 *   custom        (Logical) Enables interactive customization features when .T.
 *
 * Return Value:
 *   NIL
 *
 * Side Effects:
 *   Sets active toolbar state flag _HMG_ToolBarActive to .T.
 *   Delegates toolbar instantiation to _DefineToolBar().
 */
FUNCTION _BeginToolBar ( name, parent, row, col, w, h, caption, ProcedureName, fontname, fontsize, tooltip, flat, bottom, righttext, break, bold, italic, underline, strikeout, border, wrap, custom )

   _HMG_ToolBarActive       := .T.
   _HMG_ActiveToolBarExtend := .F.

   // Prevent defining toolbars within SplitChild window components
   IF _HMG_SplitChildActive
      MsgMiniGuiError( "ToolBars Can't Be Defined Inside SplitChild Windows." )
   ENDIF

   // Inherit active window font parameters if omitted
   IF _HMG_BeginWindowActive
      __defaultNIL( @FontName, _HMG_ActiveFontName )
      __defaultNIL( @FontSize, _HMG_ActiveFontSize )
   ENDIF

   IF parent == NIL
      parent := _HMG_ActiveFormName
   ENDIF

   _HMG_ActiveToolBarFormName := parent

   hb_default( @caption, "" )
   hb_default( @w, 0 )
   hb_default( @h, 0 )
   hb_default( @wrap, .F. )

   // Break by default unless placed inside a SplitBox container
   IF break == NIL
      break := ! _HMG_ActiveSplitBox
   ENDIF

   // Assign unique generated name if default "0" placeholder name is passed
   IF ISCHAR ( name ) .AND. name == "0"
      name := HMG_GetUniqueName()
   ENDIF

   _HMG_ActiveToolBarName := name

   _DefineToolBar ( name , parent , col , row , caption , ProcedureName , w , h , fontname , fontsize , tooltip , flat , bottom , righttext , break , bold , italic , underline , strikeout , border , .F. , 0 , 0 , , , wrap, custom )

RETURN Nil

/*
 * Routine: _BeginToolBarEx
 * Purpose: Initiates an extended toolbar definition block supporting image lists and multi-row buttons.
 *
 * Parameters:
 *   name          (Character) Control name assigned to the toolbar.
 *   parent        (Character) Host window name (defaults to active window).
 *   row           (Numeric) Y position coordinate relative to container.
 *   col           (Numeric) X position coordinate relative to container.
 *   w             (Numeric) Toolbar control width.
 *   h             (Numeric) Toolbar control height.
 *   caption       (Character) Caption text associated with toolbar band.
 *   ProcedureName (Character|Block) Action event handler for toolbar.
 *   fontname      (Character) Font name string.
 *   fontsize      (Numeric) Font point size.
 *   tooltip       (Character) Tooltip text assigned to toolbar.
 *   flat          (Logical) Enables flat toolbar style without borders when .T.
 *   bottom        (Logical) Displays text below button icons when .T.
 *   righttext     (Logical) Displays text to the right of button icons when .T.
 *   break         (Logical) Forces new band row in SplitBox container when .T.
 *   bold          (Logical) Applies bold font attribute when .T.
 *   italic        (Logical) Applies italic font attribute when .T.
 *   underline     (Logical) Applies underline font attribute when .T.
 *   strikeout     (Logical) Applies strikeout font attribute when .T.
 *   border        (Logical) Displays window border around toolbar when .T.
 *   mixedbuttons  (Logical) Allows mixing text and non-text buttons on toolbar.
 *   rows          (Numeric) Number of vertical button rows.
 *   tbsize        (Numeric) Minimum size constraint for toolbar band calculations.
 *   imagelst      (Numeric|Character) Standard image list handle or control name.
 *   hotimagelst   (Numeric|Character) Hot/hover image list handle or control name.
 *   wrap          (Logical) Enables multi-line button wrapping when .T.
 *   custom        (Logical) Enables interactive customization features when .T.
 *
 * Return Value:
 *   NIL
 *
 * Side Effects:
 *   Sets global toolbar state flags _HMG_ToolBarActive and _HMG_ActiveToolBarExtend to .T.
 *   Delegates toolbar instantiation to _DefineToolBar().
 */
FUNCTION _BeginToolBarEx( name, parent, row, col, w, h, caption, ProcedureName, fontname, fontsize, tooltip, flat, bottom, righttext, break, bold, italic, underline, strikeout, border , mixedbuttons , rows , tbsize, imagelst , hotimagelst , wrap, custom )

   _HMG_ToolBarActive       := .T.
   _HMG_ActiveToolBarExtend := .T.

   // Prevent defining toolbars within SplitChild window components
   IF _HMG_SplitChildActive
      MsgMiniGuiError( "ToolBars Can't Be Defined Inside SplitChild Windows." )
   ENDIF

   // Inherit active window font parameters if omitted
   IF _HMG_BeginWindowActive
      __defaultNIL( @FontName, _HMG_ActiveFontName )
      __defaultNIL( @FontSize, _HMG_ActiveFontSize )
   ENDIF

   IF parent == NIL
      parent := _HMG_ActiveFormName
   ENDIF

   _HMG_ActiveToolBarFormName := parent

   hb_default( @caption, "" )
   hb_default( @w, 0 )
   hb_default( @h, 0 )
   hb_default( @rows, 1 )
   hb_default( @tbsize, 0 )
   hb_default( @wrap, .F. )

   // Resolve image list handle if passed by control name string
   IF imagelst != NIL
      IF ISCHARACTER( imagelst )
         imagelst := GetControlHandle ( imagelst , parent )
      ENDIF
   ENDIF

   // Resolve hot image list handle if passed by control name string
   IF hotimagelst != NIL
      IF ISCHARACTER( hotimagelst )
         hotimagelst := GetControlHandle ( hotimagelst , parent )
      ENDIF
   ENDIF

   // Break by default unless placed inside a SplitBox container
   IF break == NIL
      break := ! _HMG_ActiveSplitBox
   ENDIF

   // Assign unique generated name if default "0" placeholder name is passed
   IF ISCHAR ( name ) .AND. name == "0"
      name := HMG_GetUniqueName()
   ENDIF

   _HMG_ActiveToolBarName := name

   _DefineToolBar ( name , parent , col , row , caption , ProcedureName , w , h , fontname , fontsize , tooltip , flat , bottom , righttext , break , bold , italic , underline , strikeout , border , mixedbuttons , rows , tbsize, imagelst , hotimagelst , wrap, custom )

RETURN Nil

/*
 * Routine: _CreatePopUpChevron
 * Purpose: Dynamically builds and tracks a popup menu containing hidden toolbar items when a ReBar chevron is clicked.
 *
 * Parameters:
 *   hWnd    (Numeric) Handle of the form window receiving notification messages.
 *   wParam  (Numeric) Message parameter passed from Win32 notification system.
 *   lParam  (Numeric) Pointer to NMREBARCHEVRON notification structure.
 *
 * Return Value:
 *   NIL
 *
 * Side Effects:
 *   Displays an interactive context menu displaying clipped toolbar buttons.
 *   Frees dynamically assigned GDI bitmap handles after menu closes.
 *   Invokes default window procedure for RBN_CHEVRONPUSHED processing.
 */
FUNCTION _CreatePopUpChevron ( hWnd, wParam, lParam )
   LOCAL hMenu, hImage, TbHwnd
   LOCAL aChevronInfo, aBtnInfo, aBitmaps := {}, aPos
   LOCAL cMenu
   LOCAL image
   LOCAL lEnable
   LOCAL i, k, n

   // Locate host form entry in global window registry
   IF ( i := AScan ( _HMG_aFormhandles, hWnd ) ) > 0

      // Extract chevron geometry and hidden button indices from ReBar structure
      aChevronInfo := CreatePopUpChevron ( _HMG_aFormReBarHandle [i], lParam )

      TbHwnd := aChevronInfo [5]
      hMenu := CreatePopupMenu()

      // Populate popup menu with items clipped out of visible toolbar area
      FOR n := aChevronInfo [6] TO aChevronInfo [7] - 1

         aBtnInfo := GetButtonBar ( TbHwnd, n )
         lEnable  := IsButtonEnabled ( TbHwnd, n )
         hImage := GetImageList ( tbhwnd, aBtnInfo [1] )
         AAdd ( aBitmaps, hImage )

         IF ( k := AScan ( _HMG_aControlIds, aBtnInfo [2] ) ) > 0 .AND. ! aBtnInfo [3]

            // Resolve menu label text prioritizing tooltip, caption, or fallback string
            IF ! Empty ( _HMG_aControlToolTip [k] )
               cMenu := _HMG_aControlToolTip [k]
            ELSEIF ! Empty ( _HMG_aControlCaption [k] )
               cMenu := _HMG_aControlCaption [k]
            ELSE
               cMenu := 'Button ' + hb_ntos( n )
            ENDIF

            AppendMenuString ( hMenu, aBtnInfo [2], cMenu )

            // Assign bitmap image or image list icon to popup menu item
            image := _HMG_aControlPicture  [k]
            IF Len( image ) != 0
               MenuItem_SetBitMaps ( hMenu, aBtnInfo [2], image, NIL )
            ELSE
               SetChevronImage ( hMenu, aBtnInfo [2], hImage )
            ENDIF

            // Gray out disabled toolbar buttons in popup menu
            IF ! lEnable
               xDisableMenuItem ( hMenu, aBtnInfo [2] )
            ENDIF

         ENDIF

      NEXT

      aPos := { 0, 0, 0, 0 }
      GetWindowRect ( _HMG_aFormReBarHandle [i], aPos )

      // Display context popup menu directly aligned under chevron button
      TrackPopupMenu ( hMenu , aPos [1] + aChevronInfo [1] , aPos [2] + aChevronInfo [4] + 3 , hWnd )

      // Clean up temporary bitmap handles
      AEval ( aBitmaps, {| x | DeleteObject ( x ) } )

   ENDIF

   // Forward notification message to default Win32 window procedure
   DefWindowProc ( hWnd, RBN_CHEVRONPUSHED, wParam, lParam )

   DestroyMenu ( hMenu )

RETURN Nil

/*
 * Routine: _DropDownShortcut
 * Purpose: Handles keyboard shortcut activation for WholeDropDown buttons by opening associated menu options.
 *
 * Parameters:
 *   nToolButtonId       (Numeric) HMG control ID assigned to target tool button.
 *   nParentWindowHandle (Numeric) HWND handle of host window receiving menu commands.
 *   i                   (Numeric) Index of parent toolbar in _HMG_aControlHandles.
 *   nButtonPos          (Numeric) Ordinal position index of button on toolbar.
 *
 * Return Value:
 *   None (PROCEDURE).
 *
 * Side Effects:
 *   Temporarily updates active hot item state via TB_SETHOTITEM window message.
 *   Displays interactive popup menu stored in _HMG_aControlRangeMax.
 */
STATIC PROCEDURE _DropDownShortcut ( nToolButtonId, nParentWindowHandle, i, nButtonPos )
   LOCAL aPos, aSize
   LOCAL x

   // Verify button exists in control structures and is configured as TOOLBUTTON
   IF ( x := AScan ( _HMG_aControlIds, nToolButtonId ) ) > 0 .AND. _HMG_aControlType [x] == "TOOLBUTTON"
      aPos := { 0, 0, 0, 0 }
      GetWindowRect ( _HMG_aControlHandles [i] , aPos )

      // Highlight target button item visually
      SendMessage ( _HMG_aControlHandles [i] , TB_SETHOTITEM , nButtonPos - 1 , 0 )

      aSize := GetButtonBarRect ( _HMG_aControlHandles [i] , nButtonPos - 1 )

      // Track popup menu attached to dropdown tool button
      TrackPopupMenu ( _HMG_aControlRangeMax [x] , aPos [1] + LoWord( aSize ) , aPos [2] + HiWord( aSize ) + ;
         iif( _HMG_ActiveSplitBoxInverted, 0, ( aPos [4] - aPos [2] - HiWord( aSize ) ) / 2 ), nParentWindowHandle )

      // Remove hot item highlight state
      SendMessage ( _HMG_aControlHandles [i] , TB_SETHOTITEM , -1 , 0 )
   ENDIF

RETURN

/*
 * Routine: _GetDummyImage
 * Purpose: Generates a temporary 16x16 or specified size blank bitmap matching system button face color.
 *
 * Parameters:
 *   nWidth  (Numeric) Width of temporary bitmap image in pixels (defaults to 16).
 *   nHeight (Numeric) Height of temporary bitmap image in pixels (defaults to 16).
 *
 * Return Value:
 *   Character - Full file path to temporary bitmap file created on disk.
 *
 * Side Effects:
 *   Creates a temporary file on disk in system temp folder.
 */
FUNCTION _GetDummyImage ( nWidth, nHeight )
   LOCAL TempName := TempFile ( GetTempFolder(), 'BMP' )
   LOCAL hBitmap

   DEFAULT nWidth := 16, nHeight := 16

   // Construct new bitmap matching current Win32 button face color scheme
   hBitmap := BT_BitmapCreateNew ( nWidth, nHeight, nRGB2Arr( GetSysColor( COLOR_BTNFACE ) ) )

   BT_BitmapSaveFile ( hBitmap, TempName )

   BT_BitmapRelease ( hBitmap )

RETURN TempName
