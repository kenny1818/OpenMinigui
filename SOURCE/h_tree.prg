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

/*
 * FUNCTION: _DefineTree
 *
 * Purpose:
 *    Initializes and creates a TreeView GUI control (SysTreeView32) within a form or dialog,
 *    registering all control properties, event callbacks, styles, and image lists into HMG extended arrays.
 *
 * Parameters:
 *    ControlName     (Character/Numeric) Name or ID of the tree control.
 *    ParentFormName  (Character)         Name of the parent window or dialog containing the control.
 *    row             (Numeric)           Vertical position in pixels relative to the parent.
 *    col             (Numeric)           Horizontal position in pixels relative to the parent.
 *    width           (Numeric)           Control width in pixels (default: 120).
 *    height          (Numeric)           Control height in pixels (default: 120).
 *    change          (Character/Block)   Procedure name or code block executed when selected item changes.
 *    tooltip         (Character)         Tooltip text string associated with the control.
 *    fontname        (Character)         Font family name.
 *    fontsize        (Numeric)           Font size in points.
 *    gotfocus        (Character/Block)   OnGotFocus event procedure or block.
 *    lostfocus       (Character/Block)   OnLostFocus event procedure or block.
 *    dblclick        (Character/Block)   OnDblClick event procedure or block.
 *    break           (Logical)           Break flag when placed inside a SplitBox container.
 *    value           (Numeric)           Initial selected item index or item ID.
 *    HelpId          (Numeric)           Context Help ID assigned to the control.
 *    aImgNode        (Array)             Array of bitmap resources/files for node icons {normal, selected}.
 *    aImgItem        (Array)             Array of bitmap resources/files for item icons {normal, selected}.
 *    noBot           (Logical)           If .T., suppresses lines at the root level (TVS_LINESATROOT).
 *    bold            (Logical)           Font bold weight attribute.
 *    italic          (Logical)           Font italic style attribute.
 *    underline       (Logical)           Font underline attribute.
 *    strikeout       (Logical)           Font strikeout attribute.
 *    itemids         (Logical)           If .T., tree value property references custom numeric item IDs instead of 1-based array positions.
 *    backcolor       (Array)             RGB color array for control background {r, g, b}.
 *    fontcolor       (Array)             RGB color array for item text {r, g, b}.
 *    linecolor       (Array)             RGB color array for tree structure lines {r, g, b}.
 *    indent          (Numeric)           Indent width between parent and child nodes in pixels.
 *    itemheight      (Numeric)           Explicit height of tree items in pixels.
 *    nId             (Numeric)           Windows control ID.
 *    bInit           (Block/Character)   Initialization code block executed upon creation.
 *    NoTrans         (Logical)           If .T., disables bitmap background transparency (default: .F.).
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Allocates control slot in HMG global tracking arrays (_HMG_aControlType, etc.).
 *    Updates global active tree state context (_HMG_ActiveTreeHandle, _HMG_ActiveTreeIndex).
 *    Creates a public global variable representing the control.
 *    Modifies Win32 visual tree control attributes and styles.
 */
FUNCTION _DefineTree ( ControlName, ParentFormName, row, col, width, height, ;
      change, tooltip, fontname, fontsize, gotfocus, lostfocus, dblclick, break, ;
      value, HelpId, aImgNode, aImgItem, noBot, bold, italic, underline, strikeout, ;
      itemids, backcolor, fontcolor, linecolor, indent, itemheight, nId, bInit, NoTrans )
   LOCAL ParentFormHandle, Controlhandle, FontHandle
   LOCAL ImgDefNode, ImgDefItem
   LOCAL aBitmaps := Array( 4 )
   LOCAL mVar
   LOCAL k
   LOCAL Mask
   LOCAL Style
   LOCAL blInit
   LOCAL i
   LOCAL oc := NIL, ow := NIL

#ifdef _OBJECT_
   // Fetch dialog unit to pixel conversion object reference when OOP is active
   ow := oDlu2Pixel()
#endif

   // Reset global active tree tracking variables prior to building nodes
   _HMG_ActiveTreeHandle := 0
   _HMG_NodeIndex := 1
   _HMG_NodeHandle[ 1 ] := 0
   _HMG_aTreeMap := {}
   _HMG_aTreeIdMap := {}
   _HMG_ActiveTreeItemIds := itemids

   // Resolve font attributes if a valid font handle is provided
   IF ( FontHandle := GetFontHandle( FontName ) ) != 0
      GetFontParamByRef( FontHandle, @FontName, @FontSize, @bold, @italic, @underline, @strikeout )
   ENDIF

   // Inherit parent window/dialog context attributes during active construction
   IF _HMG_BeginWindowActive .OR. _HMG_BeginDialogActive
      ParentFormName := iif( _HMG_BeginDialogActive, _HMG_ActiveDialogName, _HMG_ActiveFormName )
      __defaultNIL( @FontName, _HMG_ActiveFontName )
      __defaultNIL( @FontSize, _HMG_ActiveFontSize )
   ENDIF

   // Adjust coordinates if control resides inside a frame container
   IF _HMG_FrameLevel > 0 .AND. !_HMG_ParentWindowActive
      col := col + _HMG_ActiveFrameCol[ _HMG_FrameLevel ]
      row := row + _HMG_ActiveFrameRow[ _HMG_FrameLevel ]
      ParentFormName := _HMG_ActiveFrameParentFormName[ _HMG_FrameLevel ]
   ENDIF

   // Initialize static global array storing custom cargo associated with tree nodes
   IF _SetGetGlobal( "_HMG_aNodeItemCargo" ) == NIL
      STATIC _HMG_aNodeItemCargo AS GLOBAL VALUE {}
   ENDIF

   STATIC _HMG_lDialogInMemory AS GLOBAL VALUE _HMG_DialogInMemory

   // Validate existence of parent window
   IF .NOT. _IsWindowDefined ( ParentFormName ) .AND. .NOT. _HMG_DialogInMemory
      MsgMiniGuiError( "Window: " + IFNIL( ParentFormName, "Parent", ParentFormName ) + " is not defined." )
   ENDIF

   // Auto-generate control name if placeholder string "0" is passed
   IF ISCHAR ( ControlName ) .AND. ControlName == "0"
      ControlName := HMG_GetUniqueName()
   ENDIF

   // Prevent duplicate control definitions under the same parent
   IF _IsControlDefined ( ControlName, ParentFormName ) .AND. .NOT. _HMG_DialogInMemory
      MsgMiniGuiError ( "Control: " + ControlName + " Of " + ParentFormName + " Already defined." )
   ENDIF

   _HMG_ActiveTreeValue := IFNUMERIC ( Value, Value, 0 )

   // Set standard defaults for optional parameters
   hb_default( @Width, 120 )
   hb_default( @Height, 120 )
   __defaultNIL( @change, "" )
   __defaultNIL( @gotfocus, "" )
   __defaultNIL( @lostfocus, "" )
   __defaultNIL( @dblclick, "" )
   hb_default( @NoTrans, .F. )

   mVar := '_' + ParentFormName + '_' + ControlName
   k := _GetControlFree()

   IF _HMG_BeginDialogActive

      ParentFormHandle := _HMG_ActiveDialogHandle

      IF ISLOGICAL( nobot )
         mask := iif( nobot, 0, TVS_LINESATROOT )
      ENDIF

      Style := WS_BORDER + WS_VISIBLE + WS_TABSTOP + WS_CHILD + TVS_HASLINES + TVS_HASBUTTONS + mask + TVS_SHOWSELALWAYS

      IF Len( _HMG_aDialogTemplate ) > 0        // Dialog Template

         // Register tree control entry into dialog template item list for deferred creation
         blInit := {| x, y, z| InitDialogTree( x, y, z ) }
         _HMG_aDialogTreeItem := {}
         AAdd( _HMG_aDialogItems, { nId, k, "SysTreeView32", style, 0, col, row, width, height, "", HelpId, tooltip, FontName, FontSize, bold, italic, underline, strikeout, blInit, _HMG_BeginTabActive, .F., _HMG_ActiveTabPage } )

      ELSE

         ControlHandle := GetDialogItemHandle( ParentFormHandle, nId )

         SetWindowStyle ( ControlHandle, Style, .T. )

         col := GetWindowCol ( Controlhandle )
         row := GetWindowRow ( Controlhandle )
         Width := GetWindowWidth  ( Controlhandle )
         Height := GetWindowHeight ( Controlhandle )

         ImgDefNode := iif( ISARRAY( aImgNode ), Len( aImgNode ), 0 )
         ImgDefItem := iif( ISARRAY( aImgItem ), Len( aImgItem ), 0 )

         IF ImgDefNode > 0

            aBitmaps[ 1 ] := aImgNode[ 1 ]             // Default node image (unselected)
            aBitmaps[ 2 ] := aImgNode[ ImgDefNode ]    // Node image (selected)

            IF ImgDefItem > 0

               aBitmaps[ 3 ] := aImgItem[ 1 ]          // Default item image (unselected)
               aBitmaps[ 4 ] := aImgItem[ ImgDefItem ]    // Item image (selected)

            ELSE

               aBitmaps[ 3 ] := aImgNode[ 1 ]          // Fallback to node images if item images are absent
               aBitmaps[ 4 ] := aImgNode[ ImgDefNode ]

            ENDIF

            InitTreeViewBitmap( ControlHandle, aBitmaps, NoTrans ) // Initialize native Win32 TreeView ImageList

         ENDIF

         _HMG_ActiveTreeHandle := ControlHandle

      ENDIF

   ELSE

      ParentFormHandle := GetFormHandle ( ParentFormName )

      IF Row == NIL .OR. Col == NIL

         // Auto-position control inside ReBar/SplitBox container
         IF _HMG_SplitLastControl == 'TOOLBAR'
            Break := .T.
         ENDIF

         i := GetFormIndex ( ParentFormName )

         IF i > 0

            ControlHandle := InitTree ( _HMG_aFormReBarHandle [i], col, row, width, height, 0, '', 0, iif( noBot, 1, 0 ) )

            AddSplitBoxItem ( Controlhandle, _HMG_aFormReBarHandle [i], Width, break, , , , _HMG_ActiveSplitBoxInverted )

            _HMG_SplitLastControl := 'TREE'

         ENDIF

      ELSE

         // Standard Win32 TreeView control initialization
         ControlHandle := InitTree ( ParentFormHandle, col, row, width, height, 0, '', 0, iif( noBot, 1, 0 ) )

      ENDIF

      ImgDefNode := iif( ISARRAY( aImgNode ), Len( aImgNode ), 0 )
      ImgDefItem := iif( ISARRAY( aImgItem ), Len( aImgItem ), 0 )

      IF ImgDefNode > 0

         aBitmaps[ 1 ] := aImgNode[ 1 ]             // Default node image (unselected)
         aBitmaps[ 2 ] := aImgNode[ ImgDefNode ]    // Node image (selected)

         IF ImgDefItem > 0

            aBitmaps[ 3 ] := aImgItem[ 1 ]          // Default item image (unselected)
            aBitmaps[ 4 ] := aImgItem[ ImgDefItem ]    // Item image (selected)

         ELSE

            aBitmaps[ 3 ] := aImgNode[ 1 ]          // Fallback to node images if item images are absent
            aBitmaps[ 4 ] := aImgNode[ ImgDefNode ]

         ENDIF

         InitTreeViewBitmap ( ControlHandle, aBitmaps, NoTrans ) // Initialize native Win32 TreeView ImageList

      ENDIF

      _HMG_ActiveTreeHandle := ControlHandle

   ENDIF

   IF .NOT. _HMG_DialogInMemory

      // Apply font settings
      IF FontHandle != 0
         _SetFontHandle ( ControlHandle, FontHandle )
      ELSE
         __defaultNIL( @FontName, _HMG_DefaultFontName )
         __defaultNIL( @FontSize, _HMG_DefaultFontSize )
         FontHandle := _SetFont ( ControlHandle, FontName, FontSize, bold, italic, underline, strikeout )
      ENDIF

      // Bind control handle to active parent Tab page if inside a Tab control
      IF _HMG_BeginTabActive
         AAdd ( _HMG_ActiveTabCurrentPageMap, ControlHandle )
      ENDIF

      IF tooltip != NIL
         SetToolTip ( ControlHandle, tooltip, GetFormToolTipHandle ( ParentFormName ) )
      ENDIF

      // Configure visual custom properties
      IF ISARRAY( backcolor )
         TreeView_SetBkColor( ControlHandle, backcolor )
      ENDIF

      IF ISARRAY( fontcolor )
         TreeView_SetTextColor( ControlHandle, fontcolor )
      ENDIF

      IF ISARRAY( linecolor )
         TreeView_SetLineColor( ControlHandle, linecolor )
      ENDIF

      IF ISNUMERIC( indent )
         TreeView_SetIndent( ControlHandle, indent )
      ENDIF

      IF ISNUMERIC( itemheight )
         TreeView_SetItemHeight( ControlHandle, itemheight )
      ENDIF

   ENDIF
   
#ifdef _NAMES_LIST_
   _SetNameList( mVar , k )
#else
   Public &mVar. := k
#endif

   // Populate global control data array slots
   _HMG_ActiveTreeIndex := k

   _HMG_aControlType[ k ] := "TREE"
   _HMG_aControlNames[ k ] :=   ControlName
   _HMG_aControlHandles[ k ] :=   ControlHandle
   _HMG_aControlParentHandles[ k ] :=   ParentFormHandle
   _HMG_aControlIds[ k ] :=   nId
   _HMG_aControlProcedures[ k ] :=   ""
   _HMG_aControlPageMap[ k ] :=  {}
   _HMG_aControlValue[ k ] :=  Nil
   _HMG_aControlInputMask[ k ] :=  itemids
   _HMG_aControllostFocusProcedure[ k ] :=  lostfocus
   _HMG_aControlGotFocusProcedure[ k ] :=  gotfocus
   _HMG_aControlChangeProcedure[ k ] :=  change
   _HMG_aControlDeleted[ k ] :=  .F.
   _HMG_aControlBkColor[ k ] :=  backcolor
   _HMG_aControlFontColor[ k ] :=  fontcolor
   _HMG_aControlDblClick[ k ] := dblclick
   _HMG_aControlHeadClick[ k ] := {}
   _HMG_aControlRow[ k ] := Row
   _HMG_aControlCol[ k ] := Col
   _HMG_aControlWidth[ k ] := Width
   _HMG_aControlHeight[ k ] := Height
   _HMG_aControlSpacing[ k ] := 0
   _HMG_aControlContainerRow[ k ] :=  iif ( _HMG_FrameLevel > 0, _HMG_ActiveFrameRow[ _HMG_FrameLevel ], -1 )
   _HMG_aControlContainerCol[ k ] :=  iif ( _HMG_FrameLevel > 0, _HMG_ActiveFrameCol[ _HMG_FrameLevel ], -1 )
   _HMG_aControlPicture[ k ] :=  {}
   _HMG_aControlContainerHandle[ k ] :=  0
   _HMG_aControlFontName[ k ] :=  fontname
   _HMG_aControlFontSize[ k ] :=  fontsize
   _HMG_aControlFontAttributes[ k ] := { bold, italic, underline, strikeout }
   _HMG_aControlToolTip[ k ] :=  tooltip
   _HMG_aControlRangeMin[ k ] :=  0
   _HMG_aControlRangeMax[ k ] :=  0
   _HMG_aControlCaption[ k ] :=  ''
   _HMG_aControlVisible[ k ] :=   .T.
   _HMG_aControlHelpId[ k ] :=   HelpId
   _HMG_aControlFontHandle[ k ] :=  FontHandle
   _HMG_aControlBrushHandle[ k ] :=  0
   _HMG_aControlEnabled[ k ] :=  .T.
   _HMG_aControlMiscData1[ k ] := { 0, aImgNode, aImgItem, NoTrans }
   _HMG_aControlMiscData2[ k ] := ''

   // Trigger object-oriented initialization bindings and init block call
   IF _HMG_lOOPEnabled
      Eval ( _HMG_bOnControlInit, k, mVar )
#ifdef _OBJECT_
      ow := _WindowObj ( ParentFormHandle )
      oc := _ControlObj( ControlHandle )
#endif
   ENDIF

   Do_ControlEventProcedure ( bInit, k, ow, oc )

RETURN NIL

/*
 * FUNCTION: InitDialogTree
 *
 * Purpose:
 *    Deferred initialization handler for TreeView controls generated from dialog resource templates.
 *    Populates queued nodes/items into the Win32 TreeView control upon dialog activation.
 *
 * Parameters:
 *    ParentName     (Character) Name of the parent dialog window.
 *    ControlHandle  (Numeric)   Win32 HWND handle of the tree view control.
 *    k              (Numeric)   Internal control index in HMG registration arrays.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Inserts TreeView items into Win32 HWND handle.
 *    Populates HMG tree mapping arrays (_HMG_aControlPageMap, _HMG_aControlPicture, _HMG_aControlHeadClick).
 *    Sets initial selected item state.
 */
FUNCTION InitDialogTree( ParentName, ControlHandle, k )
   LOCAL aBitmaps := Array( 4 ), aImgNode, aImgItem, aImage
   LOCAL ImgDefNode, ImgDefItem
   LOCAL NoTrans
   LOCAL NodeHandle, Handle
   LOCAL TEXT
   LOCAL ImgDef
   LOCAL Id
   LOCAL iUnsel, iSel
   LOCAL NodeIndex
   LOCAL n
   LOCAL Cargo

   HB_SYMBOL_UNUSED( ParentName )

   // Extract image list options from control metadata cache
   aImgNode := _HMG_aControlMiscData1[ k, 2 ]
   aImgItem := _HMG_aControlMiscData1[ k, 3 ]
   NoTrans  := _HMG_aControlMiscData1[ k, 4 ]

   ImgDefNode := iif( ISARRAY( aImgNode ), Len( aImgNode ), 0 )
   ImgDefItem := iif( ISARRAY( aImgItem ), Len( aImgItem ), 0 )

   // Initialize bitmap image list for dialog tree
   IF ImgDefNode > 0
      aBitmaps[ 1 ] := aImgNode[ 1 ]             // Default node image
      aBitmaps[ 2 ] := aImgNode[ ImgDefNode ]
      IF ImgDefItem > 0
         aBitmaps[ 3 ] := aImgItem[ 1 ]          // Default item image
         aBitmaps[ 4 ] := aImgItem[ ImgDefItem ]
      ELSE
         aBitmaps[ 3 ] := aImgNode[ 1 ]          // Fallback to node images
         aBitmaps[ 4 ] := aImgNode[ ImgDefNode ]
      ENDIF
      InitTreeViewBitmap( ControlHandle, aBitmaps, NoTrans )
   ENDIF

   _HMG_ActiveTreeHandle := ControlHandle

   // Process queued dialog tree items and add them to Win32 control
   FOR n := 1 TO Len( _HMG_aDialogTreeItem )
      aImage     := _HMG_aDialogTreeItem[ n, 2 ]
      text       := _HMG_aDialogTreeItem[ n, 1 ]
      id         := _HMG_aDialogTreeItem[ n, 3 ]
      NodeIndex  := _HMG_aDialogTreeItem[ n, 4 ]
      Cargo      := _HMG_aDialogTreeItem[ n, 6 ]
      ImgDef     := iif( ISARRAY( aImage ), Len( aImage ), 0 )
      NodeHandle := _HMG_NodeHandle[ NodeIndex ]

      AAdd( _SetGetGlobal( "_HMG_aNodeItemCargo" ), Cargo )

      // Determine bitmap image indices for tree item state
      IF ImgDef == 0
         IF _HMG_aDialogTreeItem[ n, 5 ] == 'NODE'
            iUnsel := 0   // Default node bitmap pointer
            iSel   := 1
         ELSE
            iUnsel := 2   // Default item bitmap pointer
            iSel   := 3
         ENDIF
      ELSE
         iUnSel := AddTreeViewBitmap( _HMG_ActiveTreeHandle, aImage[ 1 ], NoTrans ) - 1
         iSel := iif( ImgDef == 1, iUnSel, AddTreeViewBitmap( _HMG_ActiveTreeHandle, aImage[ 2 ], NoTrans ) - 1 )
      ENDIF

      // Insert node or leaf item into TreeView control
      IF _HMG_aDialogTreeItem[ n, 5 ] == 'NODE'
         _HMG_NodeHandle[ NodeIndex ] := AddTreeItem ( _HMG_ActiveTreeHandle, _HMG_NodeHandle[ NodeIndex - 1 ], text, iUnsel, iSel, Id, .T. )
         AAdd ( _HMG_aTreeMap, _HMG_NodeHandle[ NodeIndex ] )
         AAdd ( _HMG_aTreeIdMap, Id )
      ELSE
         handle := AddTreeItem ( _HMG_ActiveTreeHandle, NodeHandle, text, iUnSel, iSel, Id, .F. )
         AAdd ( _HMG_aTreeMap, Handle )
         AAdd ( _HMG_aTreeIdMap, Id )
      ENDIF
   NEXT

   // Bind temporary tree structure maps to global control index arrays
   _HMG_aControlPageMap  [ _HMG_ActiveTreeIndex ] := _HMG_aTreeMap
   _HMG_aControlPicture  [ _HMG_ActiveTreeIndex ] := _HMG_aTreeIdMap
   _HMG_aControlHeadClick[ _HMG_ActiveTreeIndex ] := AClone ( _SetGetGlobal( "_HMG_aNodeItemCargo" ) )

   // Restore initial selection state
   IF _HMG_ActiveTreeValue > 0

      IF _HMG_ActiveTreeItemIds == .F.
         TreeView_SelectItem ( _HMG_ActiveTreeHandle, _HMG_aTreeMap[ _HMG_ActiveTreeValue ] )
      ELSE
         TreeView_SelectItem ( _HMG_ActiveTreeHandle, _HMG_aTreeMap[ AScan ( _HMG_aTreeIdMap, _HMG_ActiveTreeValue ) ] )
      ENDIF
   ENDIF

   // Mark control as deleted if template belongs to a modal dialog
   IF Len( _HMG_aDialogTemplate ) != 0 .AND. _HMG_aDialogTemplate[ 3 ]
      _HMG_aControlDeleted[ k ] := .T.
   ENDIF

RETURN NIL

/*
 * FUNCTION: _DefineTreeNode
 *
 * Purpose:
 *    Defines a parent node in the active tree context (NODE block construct).
 *    Increments node level depth and appends item to tree hierarchy or dialog template buffer.
 *
 * Parameters:
 *    text    (Character) Display text label of the tree node.
 *    aImage  (Array)     Array of bitmap resource names/files {unselected, selected}.
 *    Id      (Numeric)   Custom identifier for the node (default: 0).
 *    Cargo   (Any)       Arbitrary user data attached to the node.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Increments global _HMG_NodeIndex depth.
 *    Updates _HMG_NodeHandle, _HMG_aTreeMap, _HMG_aTreeIdMap, and _HMG_aNodeItemCargo.
 */
FUNCTION _DefineTreeNode ( text, aImage, Id, Cargo )
   LOCAL ImgDef, k
   LOCAL iUnSel, iSel

   hb_default( @Id, 0 )

   IF _SetGetGlobal( "_HMG_lDialogInMemory" )

      // Queue node definition into dialog template structure
      _HMG_NodeIndex++
      AAdd ( _HMG_aDialogTreeItem, { text, aImage, Id, _HMG_NodeIndex, 'NODE', Cargo } )

   ELSE

      ImgDef := iif( ISARRAY( aImage ), Len( aImage ), 0 )

      IF ImgDef == 0
         iUnsel := 0   // Default unselected node bitmap index
         iSel   := 1   // Default selected node bitmap index
      ELSE
         k := _HMG_ActiveTreeIndex
         iUnSel := AddTreeViewBitmap( _HMG_ActiveTreeHandle, aImage[ 1 ], _HMG_aControlMiscData1[ k, 4 ] ) - 1
         iSel := iif( ImgDef == 1, iUnSel, AddTreeViewBitmap( _HMG_ActiveTreeHandle, aImage[ 2 ], _HMG_aControlMiscData1[ k, 4 ] ) - 1 )
      ENDIF

      // Advance node level and insert node item into active Win32 TreeView control
      _HMG_NodeIndex++
      _HMG_NodeHandle[ _HMG_NodeIndex ] := AddTreeItem ( _HMG_ActiveTreeHandle, _HMG_NodeHandle[ _HMG_NodeIndex - 1 ], text, iUnsel, iSel, Id, .T. )
      AAdd ( _HMG_aTreeMap, _HMG_NodeHandle[ _HMG_NodeIndex ] )
      AAdd ( _HMG_aTreeIdMap, Id )
      AAdd ( _SetGetGlobal( "_HMG_aNodeItemCargo" ), Cargo )

   ENDIF

RETURN NIL

/*
 * FUNCTION: _EndTreeNode
 *
 * Purpose:
 *    Closes current tree node definition block (END NODE) and steps up one level in tree depth.
 *
 * Parameters:
 *    None
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Decrements global _HMG_NodeIndex.
 */
FUNCTION _EndTreeNode()

   _HMG_NodeIndex--

RETURN NIL

/*
 * FUNCTION: _DefineTreeItem
 *
 * Purpose:
 *    Defines a leaf item under the current active tree node context.
 *
 * Parameters:
 *    text    (Character) Display text label of the tree item.
 *    aImage  (Array)     Array of bitmap resource names/files {unselected, selected}.
 *    Id      (Numeric)   Custom identifier for the item (default: 0).
 *    Cargo   (Any)       Arbitrary user data attached to the leaf item.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Adds TVITEM handle under active node handle (_HMG_NodeHandle[_HMG_NodeIndex]).
 *    Updates _HMG_aTreeMap, _HMG_aTreeIdMap, and _HMG_aNodeItemCargo arrays.
 */
FUNCTION _DefineTreeItem ( text, aImage, Id, Cargo )
   LOCAL handle
   LOCAL ImgDef, k
   LOCAL iUnSel, iSel

   hb_default( @Id, 0 )

   IF _SetGetGlobal( "_HMG_lDialogInMemory" )

      // Queue item definition into dialog template structure
      AAdd ( _HMG_aDialogTreeItem, { text, aImage, Id, _HMG_NodeIndex, 'ITEM', Cargo } )

   ELSE

      ImgDef := iif( ISARRAY( aImage ), Len( aImage ), 0 )

      IF ImgDef == 0
         iUnsel := 2   // Default unselected item bitmap index
         iSel   := 3   // Default selected item bitmap index
      ELSE
         k := _HMG_ActiveTreeIndex
         iUnSel := AddTreeViewBitmap( _HMG_ActiveTreeHandle, aImage[ 1 ], _HMG_aControlMiscData1[ k, 4 ] ) - 1
         iSel := iif( ImgDef == 1, iUnSel, AddTreeViewBitmap( _HMG_ActiveTreeHandle, aImage[ 2 ], _HMG_aControlMiscData1[ k, 4 ] ) - 1 )
      ENDIF

      // Insert leaf item under current parent node handle
      handle := AddTreeItem ( _HMG_ActiveTreeHandle, _HMG_NodeHandle[ _HMG_NodeIndex ], text, iUnSel, iSel, Id, .F. )
      AAdd ( _HMG_aTreeMap, Handle )
      AAdd ( _HMG_aTreeIdMap, Id )
      AAdd ( _SetGetGlobal( "_HMG_aNodeItemCargo" ), Cargo )

   ENDIF

RETURN NIL

/*
 * FUNCTION: _EndTree
 *
 * Purpose:
 *    Finalizes tree control definition block (END TREE), committing internal item mapping
 *    arrays and selecting initial value property item if defined.
 *
 * Parameters:
 *    None
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Stores accumulated tree mapping arrays into global control registration slots.
 *    Triggers TreeView item selection via TreeView_SelectItem.
 *    Resets static global _HMG_aNodeItemCargo buffer.
 */
FUNCTION _EndTree()
   LOCAL aPos

   IF .NOT. _SetGetGlobal( "_HMG_lDialogInMemory" )

      // Copy collected node mappings into master control arrays
      _HMG_aControlPageMap  [ _HMG_ActiveTreeIndex ] := _HMG_aTreeMap
      _HMG_aControlPicture  [ _HMG_ActiveTreeIndex ] := _HMG_aTreeIdMap
      _HMG_aControlHeadClick[ _HMG_ActiveTreeIndex ] := AClone( _SetGetGlobal( "_HMG_aNodeItemCargo" ) )

      // Select initial tree item if value parameter was specified
      IF _HMG_ActiveTreeValue > 0

         IF _HMG_ActiveTreeItemIds == .F.
            IF _HMG_ActiveTreeValue <= TreeView_GetCount ( _HMG_ActiveTreeHandle )
               TreeView_SelectItem ( _HMG_ActiveTreeHandle, _HMG_aTreeMap[ _HMG_ActiveTreeValue ] )
            ENDIF
         ELSE
            aPos := AScan ( _HMG_aTreeIdMap, _HMG_ActiveTreeValue )
            IF aPos == 0
               MsgMiniGuiError ( "Value Property: Invalid TreeItem Reference." )
            ENDIF
            TreeView_SelectItem ( _HMG_ActiveTreeHandle, _HMG_aTreeMap[ aPos ] )
         ENDIF

      ENDIF

   ENDIF

   // Clear global temporary cargo array buffer
   ASSIGN GLOBAL _HMG_aNodeItemCargo := {}

RETURN NIL

/*
 * PROCEDURE: _Collapse
 *
 * Purpose:
 *    Collapses a target node item in a specified TreeView control, hiding its child elements.
 *
 * Parameters:
 *    ControlName  (Character) Name of the target tree control.
 *    ParentForm   (Character) Name of the parent window or dialog.
 *    nItem        (Numeric)   Sequential index or custom ID of the item to collapse.
 *    lRecurse     (Logical)   If .T., recursively collapses all child subtrees (default: .F.).
 *
 * Return Value:
 *    None
 *
 * Side Effects:
 *    Sends TVM_EXPAND Win32 message with TVE_COLLAPSE flag to update visual UI state.
 */
PROCEDURE _Collapse ( ControlName, ParentForm, nItem, lRecurse )   // Dr. Claudio Soto (November 2013)
   LOCAL i, ItemHandle

   IF ( i := GetControlIndex( ControlName, ParentForm ) ) > 0
      ItemHandle := TreeItemGetHandle ( ControlName, ParentForm, nItem )
      IF ItemHandle <> 0
         TreeView_ExpandChildrenRecursive ( _HMG_aControlHandles [i], ItemHandle, TVE_COLLAPSE, hb_defaultValue( lRecurse, .F. ) )
      ENDIF
   ENDIF

RETURN

/*
 * PROCEDURE: _Expand
 *
 * Purpose:
 *    Expands a target node item in a specified TreeView control, displaying its child elements.
 *
 * Parameters:
 *    ControlName  (Character) Name of the target tree control.
 *    ParentForm   (Character) Name of the parent window or dialog.
 *    nItem        (Numeric)   Sequential index or custom ID of the item to expand.
 *    lRecurse     (Logical)   If .T., recursively expands all child subtrees (default: .F.).
 *
 * Return Value:
 *    None
 *
 * Side Effects:
 *    Sends TVM_EXPAND Win32 message with TVE_EXPAND flag to update visual UI state.
 */
PROCEDURE _Expand ( ControlName, ParentForm, nItem, lRecurse )   // Dr. Claudio Soto (November 2013)
   LOCAL i, ItemHandle

   IF ( i := GetControlIndex( ControlName, ParentForm ) ) > 0
      ItemHandle := TreeItemGetHandle ( ControlName, ParentForm, nItem )
      IF ItemHandle <> 0
         TreeView_ExpandChildrenRecursive ( _HMG_aControlHandles [i], ItemHandle, TVE_EXPAND, hb_defaultValue( lRecurse, .F. ) )
      ENDIF
   ENDIF

RETURN

/*
 * FUNCTION: TreeItemGetHandle
 *
 * Purpose:
 *    Resolves the internal Win32 HTREEITEM handle corresponding to a logical item index or item ID.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    Item         (Numeric)   Logical index position or custom item ID.
 *
 * Return Value:
 *    Numeric/Handle - Win32 HTREEITEM handle, or 0 if item is not found.
 *
 * Side Effects:
 *    None.
 */
FUNCTION TreeItemGetHandle ( ControlName, ParentForm, Item )
   LOCAL ItemHandle := 0
   LOCAL Pos
   LOCAL i

   IF ( i := GetControlIndex( ControlName, ParentForm ) ) > 0

      // Lookup handle by positional index vs custom ID key mapping
      IF _HMG_aControlInputMask [i] == .F.
         IF Item <= Len ( _HMG_aControlPageMap[ i ] )
            ItemHandle := _HMG_aControlPageMap[ i ][ Item ]
         ENDIF
      ELSE
         Pos := AScan ( _HMG_aControlPicture[ i ], Item )
         IF Pos > 0
            ItemHandle := _HMG_aControlPageMap[ i ][ Pos ]
         ENDIF
      ENDIF

   ENDIF

RETURN ItemHandle

/*
 * FUNCTION: TreeItemGetRootValue
 *
 * Purpose:
 *    Retrieves the positional index or custom ID of the root item in a TreeView control.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *
 * Return Value:
 *    Numeric - Positional index or custom ID of root item, or NIL if control/root does not exist.
 *
 * Side Effects:
 *    Queries root HTREEITEM handle via TreeView_GetRoot.
 */
FUNCTION TreeItemGetRootValue ( ControlName, ParentForm )
   LOCAL nControlHandle := GetControlHandle ( ControlName, ParentForm )
   LOCAL ItemHandle := TreeView_GetRoot ( nControlHandle )
   LOCAL nPos
   LOCAL nID
   LOCAL i

   IF ( i := GetControlIndex ( ControlName, ParentForm ) ) > 0 .AND. ItemHandle <> 0
      IF _HMG_aControlInputMask [i] == .F.
         nPos := AScan ( _HMG_aControlPageMap [i], ItemHandle )
         RETURN nPos
      ELSE
         nID := TREEITEM_GETID ( nControlHandle, ItemHandle )
         RETURN nID
      ENDIF
   ENDIF

RETURN NIL

/*
 * FUNCTION: TreeItemGetParentValue
 *
 * Purpose:
 *    Retrieves the positional index or custom ID of the parent node for a given tree item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of target child item.
 *
 * Return Value:
 *    Numeric - Positional index or custom ID of parent item, or NIL if target is root or not found.
 *
 * Side Effects:
 *    Queries parent HTREEITEM handle via TreeView_GetParent.
 */
FUNCTION TreeItemGetParentValue ( ControlName , ParentForm , nItem )
   LOCAL nControlHandle := GetControlHandle  ( ControlName, ParentForm )
   LOCAL ItemHandle := TreeView_GetParent ( nControlHandle, TreeItemGetHandle ( ControlName, ParentForm, nItem ) )
   LOCAL nPos
   LOCAL nID
   LOCAL i

   IF ( i := GetControlIndex ( ControlName, ParentForm ) ) > 0 .AND. ItemHandle <> 0
      IF _HMG_aControlInputMask [i] == .F.
         nPos := AScan ( _HMG_aControlPageMap [i], ItemHandle )
         RETURN nPos
      ELSE
         nID := TREEITEM_GETID ( nControlHandle, ItemHandle )
         RETURN nID
      ENDIF
   ENDIF

RETURN NIL

/*
 * FUNCTION: TreeItemGetAllValues
 *
 * Purpose:
 *    Returns an array containing all item indices or custom IDs present in a tree control.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *
 * Return Value:
 *    Array - List of all item position numbers or custom IDs, or NIL if tree is empty.
 *
 * Side Effects:
 *    Queries total item count via TreeView_GetCount.
 */
FUNCTION TreeItemGetAllValues ( ControlName, ParentForm )
   LOCAL aAllValues := {}
   LOCAL k := 1
   LOCAL i
   LOCAL nItemCount := TreeView_GetCount ( GetControlHandle ( ControlName, ParentForm ) )

   IF ( i := GetControlIndex ( ControlName, ParentForm ) ) > 0 .AND. nItemCount > 0
      IF _HMG_aControlInputMask[ i ] == .F.
         aAllValues := Array( nItemCount )
         AEval ( aAllValues, {| x, i | aAllValues[ i ] := k++, x := NIL } )
      ELSE
         aAllValues := _HMG_aControlPicture[ i ]
      ENDIF
   ENDIF

RETURN iif ( Empty( aAllValues ), NIL, aAllValues )

/*
 * FUNCTION: TreeItemGetChildValues
 *
 * Purpose:
 *    Returns an array of positional indices or custom IDs for immediate children of a tree node.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of target parent node.
 *
 * Return Value:
 *    Array - List of child item values, or NIL if target node has no child items.
 *
 * Side Effects:
 *    Iterates child sibling chain via TreeView_GetChild and TreeView_GetNextSibling.
 */
FUNCTION TreeItemGetChildValues ( ControlName, ParentForm, nItem )
   LOCAL ChildItem, aChildValues := {}
   LOCAL nControlHandle := GetControlHandle ( ControlName, ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName, ParentForm, nItem )
   LOCAL i := GetControlIndex ( ControlName, ParentForm )

   ChildItem := TreeView_GetChild ( nControlHandle, ItemHandle )
   WHILE ChildItem <> 0
      IF _HMG_aControlInputMask[ i ] == .F.
         AAdd ( aChildValues, AScan ( _HMG_aControlPageMap[ i ], ChildItem ) )
      ELSE
         AAdd ( aChildValues, TREEITEM_GETID ( nControlHandle, ChildItem ) )
      ENDIF
      ChildItem := TreeView_GetNextSibling ( nControlHandle, ChildItem )
   ENDDO

RETURN iif ( Empty( aChildValues ), NIL, aChildValues )

/*
 * FUNCTION: TreeItemGetSiblingValues
 *
 * Purpose:
 *    Returns an array of positional indices or custom IDs for all siblings sharing the same parent as target item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of target tree item.
 *
 * Return Value:
 *    Array - List of sibling item values, or NIL if target item is root or has no siblings.
 *
 * Side Effects:
 *    Traverses backward to first sibling and forward through TreeView sibling chain.
 */
FUNCTION TreeItemGetSiblingValues ( ControlName, ParentForm, nItem )
   LOCAL SiblingItem, FirstItem, aSiblingValues := {}
   LOCAL nControlHandle := GetControlHandle ( ControlName, ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName, ParentForm, nItem )
   LOCAL i := GetControlIndex ( ControlName, ParentForm )

   IF ItemHandle <> TreeView_GetRoot ( nControlHandle )
      FirstItem := SiblingItem := ItemHandle
      // Traverse backwards to locate head sibling
      WHILE SiblingItem <> 0
         SiblingItem := TreeView_GetPrevSibling ( nControlHandle, FirstItem )
         IF SiblingItem <> 0
            FirstItem := SiblingItem
         ENDIF
      ENDDO
      // Collect all sibling handles forward
      SiblingItem := FirstItem
      WHILE SiblingItem <> 0
         IF _HMG_aControlInputMask[ i ] == .F.
            AAdd ( aSiblingValues, AScan ( _HMG_aControlPageMap[ i ], SiblingItem ) )
         ELSE
            AAdd ( aSiblingValues, TREEITEM_GETID ( nControlHandle, SiblingItem ) )
         ENDIF
         SiblingItem := TreeView_GetNextSibling ( nControlHandle, SiblingItem )
      ENDDO
   ENDIF

RETURN iif ( Empty( aSiblingValues ), NIL, aSiblingValues )

/*
 * FUNCTION: TreeItemGetFirstItemValue
 *
 * Purpose:
 *    Retrieves the positional index or custom ID of the very first item defined in the tree control.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *
 * Return Value:
 *    Numeric - Value of first item (1 or first custom ID), or NIL if tree is empty.
 *
 * Side Effects:
 *    None.
 */
FUNCTION TreeItemGetFirstItemValue ( ControlName, ParentForm )
   LOCAL nIndex := GetControlIndex ( ControlName, ParentForm )
   LOCAL nPos := 1
   LOCAL nID

   IF GetProperty ( ParentForm, ControlName, "ItemCount" ) > 0
      IF _HMG_aControlInputMask [nIndex] == .F.
         RETURN nPos
      ELSE
         nID := _HMG_aControlPicture [nIndex][nPos]
         RETURN nID
      ENDIF
   ENDIF

RETURN NIL

/*
 * PROCEDURE: TreeItemSort
 *
 * Purpose:
 *    Sorts child nodes under a given tree item using custom comparison criteria.
 *
 * Parameters:
 *    cTreeName        (Character) Name of the tree control.
 *    cFormName        (Character) Name of the parent window.
 *    nItem            (Numeric)   Positional index or ID of target parent node (NIL sorts root).
 *    lRecurse         (Logical)   If .T., recursively sorts subtrees (default: .T.).
 *    lCaseSensitive   (Logical)   If .T., performs case-sensitive sorting (default: .F.).
 *    lAscendingOrder  (Logical)   If .T., sorts ascending; if .F., descending (default: .T.).
 *    nNodePosition    (Numeric)   Node placement flag (e.g., TREESORTNODE_MIX, TREESORTNODE_TOP, TREESORTNODE_FIRST).
 *
 * Return Value:
 *    None
 *
 * Side Effects:
 *    Visually rearranges TreeView nodes via C callback comparison TreeView_SortChildrenRecursiveCB.
 */
PROCEDURE TreeItemSort ( cTreeName, cFormName, nItem, lRecurse, lCaseSensitive, lAscendingOrder, nNodePosition )
   LOCAL nControlHandle, nItemHandle

   nControlHandle := GetControlHandle ( cTreeName, cFormName )

   IF nItem == NIL
      nItemHandle := TreeView_GetRoot ( nControlHandle )
   ELSE
      nItemHandle := TreeItemGetHandle( cTreeName, cFormName, nItem )
   ENDIF

   hb_default( @lRecurse, .T. )
   hb_default( @lCaseSensitive, .F. )
   hb_default( @lAscendingOrder, .T. )
   hb_default( @nNodePosition, TREESORTNODE_MIX )

   TreeView_SortChildrenRecursiveCB ( nControlHandle, nItemHandle, lRecurse, lCaseSensitive, lAscendingOrder, nNodePosition )

RETURN

/*
 * FUNCTION: TreeItemIsTrueNode
 *
 * Purpose:
 *    Checks whether a specific tree item currently contains child nodes.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of tree item.
 *
 * Return Value:
 *    Logical - .T. if item has one or more child nodes, .F. if leaf item or empty.
 *
 * Side Effects:
 *    Calls TreeView_GetChild API.
 */
FUNCTION TreeItemIsTrueNode ( ControlName , ParentForm , nItem )
   LOCAL nControlHandle := GetControlHandle ( ControlName , ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName , ParentForm , nItem )

RETURN ! Empty( TreeView_GetChild ( nControlHandle, ItemHandle ) )

/*
 * FUNCTION: TreeItemSetNodeFlag
 *
 * Purpose:
 *    Sets or clears the internal node flag state on a specified tree item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of target item.
 *    lNodeFlag    (Logical)   .T. to flag as node, .F. as leaf.
 *
 * Return Value:
 *    Logical/Numeric - Status code returned by C-level TREEITEM_SETNODEFLAG.
 *
 * Side Effects:
 *    Modifies internal TVITEM state flags.
 */
FUNCTION TreeItemSetNodeFlag ( ControlName , ParentForm , nItem , lNodeFlag )
   LOCAL nControlHandle := GetControlHandle ( ControlName , ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName , ParentForm , nItem )

RETURN TREEITEM_SETNODEFLAG ( nControlHandle, ItemHandle, lNodeFlag )

/*
 * FUNCTION: TreeItemGetNodeFlag
 *
 * Purpose:
 *    Retrieves the internal node flag state for a specified tree item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of target item.
 *
 * Return Value:
 *    Logical - .T. if node flag is set, .F. otherwise.
 *
 * Side Effects:
 *    Queries internal TVITEM state via C-level TREEITEM_GETNODEFLAG.
 */
FUNCTION TreeItemGetNodeFlag ( ControlName , ParentForm , nItem )
   LOCAL nControlHandle := GetControlHandle ( ControlName , ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName , ParentForm , nItem )

RETURN TREEITEM_GETNODEFLAG ( nControlHandle, ItemHandle )

/*
 * FUNCTION: TreeItemSetImageIndex
 *
 * Purpose:
 *    Updates unselected and selected image list indices associated with a specific tree item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of tree item.
 *    aSel         (Array)     Array containing image indices {nUnselectedImage, nSelectedImage}.
 *
 * Return Value:
 *    Logical/Numeric - Status result of C-level TREEITEM_SETIMAGEINDEX function.
 *
 * Side Effects:
 *    Modifies visual icons displayed for target item in TreeView control.
 */
FUNCTION TreeItemSetImageIndex ( ControlName , ParentForm , nItem , aSel )
   LOCAL nControlHandle := GetControlHandle ( ControlName , ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName , ParentForm , nItem )

RETURN TREEITEM_SETIMAGEINDEX ( nControlHandle , ItemHandle , aSel[1] , aSel[2] )

/*
 * FUNCTION: TreeItemGetImageIndex
 *
 * Purpose:
 *    Retrieves current image list indices for unselected and selected states of a tree item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of tree item.
 *
 * Return Value:
 *    Array/Numeric - Image index structure returned by C-level TREEITEM_GETIMAGEINDEX.
 *
 * Side Effects:
 *    None.
 */
FUNCTION TreeItemGetImageIndex ( ControlName , ParentForm , nItem )
   LOCAL nControlHandle := GetControlHandle ( ControlName , ParentForm )
   LOCAL ItemHandle := TreeItemGetHandle ( ControlName , ParentForm , nItem )

RETURN TREEITEM_GETIMAGEINDEX ( nControlHandle , ItemHandle )

#define TVIS_EXPANDED   32
/*
 * FUNCTION: TreeItemIsExpand
 *
 * Purpose:
 *    Determines whether a tree node is currently expanded.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    nItem        (Numeric)   Positional index or custom ID of target item.
 *
 * Return Value:
 *    Logical - .T. if node is expanded (TVIS_EXPANDED state present), .F. if collapsed.
 *
 * Side Effects:
 *    Queries item state mask via TreeView_GetItemState.
 */
FUNCTION TreeItemIsExpand ( ControlName , ParentForm , nItem )
   LOCAL nControlHandle := GetControlHandle  ( ControlName , ParentForm )
   LOCAL ItemHandle     := TreeItemGetHandle ( ControlName , ParentForm , nItem )

RETURN ( AND ( TreeView_GetItemState ( nControlHandle, ItemHandle, TVIS_EXPANDED ), TVIS_EXPANDED ) == TVIS_EXPANDED )

/*
 * FUNCTION: TreeNodeItemCargo
 *
 * Purpose:
 *    Gets or sets custom user data (cargo) stored with a specific tree item.
 *
 * Parameters:
 *    ControlName  (Character) Name of the tree control.
 *    ParentForm   (Character) Name of the parent window.
 *    Item         (Numeric)   Positional index or custom ID of tree item.
 *    Value        (Any)       Optional new cargo value to assign.
 *
 * Return Value:
 *    Any - Existing (or previous) cargo value assigned to the item.
 *
 * Side Effects:
 *    Updates internal data array _HMG_aControlHeadClick for the given control index when Value is passed.
 */
FUNCTION TreeNodeItemCargo( ControlName, ParentForm, Item, Value )
   LOCAL xData
   LOCAL Pos
   LOCAL i

   IF ( i := GetControlIndex( ControlName, ParentForm ) ) > 0

      // Retrieve/update cargo entry by positional index vs custom ID mapping
      IF _HMG_aControlInputMask [i] == .F.

         IF Item > 0 .AND. Item <= Len ( _HMG_aControlHeadClick[ i ] )
            xData := _HMG_aControlHeadClick[ i ][ Item ]
            IF PCount() > 3
               _HMG_aControlHeadClick[ i ][ Item ] := Value
            ENDIF
         ENDIF

      ELSE

         IF ( Pos := AScan ( _HMG_aControlPicture[ i ], Item ) ) > 0 .AND. Pos <= Len ( _HMG_aControlHeadClick[ i ] )
            xData := _HMG_aControlHeadClick[ i ][ Pos ]
            IF PCount() > 3
               _HMG_aControlHeadClick[ i ][ Pos ] := Value
            ENDIF
         ENDIF

      ENDIF

   ENDIF
   
RETURN xData

/*
 * FUNCTION: TreeBuildFromArray
 *
 * Purpose:
 *    Builds a TREE control hierarchy dynamically from a multi-column parent-child data array.
 *
 * Parameters:
 *    aData       (Array)     Two-dimensional source array containing tree records.
 *    nIdCol      (Numeric)   Column index containing unique item ID (default: 1).
 *    nTextCol    (Numeric)   Column index containing display text string (default: 2).
 *    nParentCol  (Numeric)   Column index containing parent item ID (default: 3).
 *    nImageCol   (Numeric)   Optional column index containing image array {cNode, cSel} (default: 0).
 *    nCargoCol   (Numeric)   Optional column index containing cargo value (default: 0).
 *    bIsNode     (Block)     Optional code block {|aRow, lHasChildren| ... } returning .T. for NODE, .F. for ITEM.
 *                            If NIL, records with children default to NODEs.
 *
 * Return Value:
 *    NIL
 *
 * Side Effects:
 *    Invokes __TreeBuildBranch to populate active tree construct, calls _EndTree() to store item cargo.
 */
FUNCTION TreeBuildFromArray( aData, ;
                             nIdCol, ;
                             nTextCol, ;
                             nParentCol, ;
                             nImageCol, ;
                             nCargoCol, ;
                             bIsNode )

   LOCAL hChildren := {=>}
   LOCAL hParents  := {=>}
   LOCAL cParent
   LOCAL i

   hb_default( @nIdCol,     1 )
   hb_default( @nTextCol,   2 )
   hb_default( @nParentCol, 3 )
   hb_default( @nImageCol,  0 )
   hb_default( @nCargoCol,  0 )
   hb_default( @bIsNode,    NIL )

   /* Index parent-child relationships into fast Hash tables */

   FOR i := 1 TO Len( aData )

      cParent := AllTrim( hb_ValToStr( aData[ i ][ nParentCol ] ) )

      IF ! hb_HHasKey( hChildren, cParent )
         hChildren[ cParent ] := {}
      ENDIF

      AAdd( hChildren[ cParent ], i )

      IF ! Empty( cParent )
         hParents[ cParent ] := .T.
      ENDIF

   NEXT

   // Recursively construct tree branches starting from root parent ""
   __TreeBuildBranch( ;
      "", ;
      aData, ;
      hChildren, ;
      hParents, ;
      nIdCol, ;
      nTextCol, ;
      nImageCol, ;
      nCargoCol, ;
      bIsNode )

   IF nCargoCol > 0 .AND. ! _HMG_BeginWindowActive
      _EndTree()
   ENDIF

RETURN NIL

/*
 * STATIC PROCEDURE: __TreeBuildBranch
 *
 * Purpose:
 *    Internal recursive helper procedure that traverses child hash structures and issues
 *    _DefineTreeNode and _DefineTreeItem calls to build hierarchical tree levels.
 *
 * Parameters:
 *    cParentID   (Character) Parent ID key currently being processed.
 *    aData       (Array)     Two-dimensional source array.
 *    hChildren   (Hash)      Hash index mapping parent IDs to array row numbers.
 *    hParents    (Hash)      Hash set tracking all parent ID occurrences.
 *    nIdCol      (Numeric)   Column index for ID value.
 *    nTextCol    (Numeric)   Column index for display text.
 *    nImageCol   (Numeric)   Column index for image definitions.
 *    nCargoCol   (Numeric)   Column index for item cargo.
 *    bIsNode     (Block)     Code block evaluating whether row is treated as node or leaf.
 *
 * Return Value:
 *    None
 *
 * Side Effects:
 *    Calls _DefineTreeNode, __TreeBuildBranch recursively, _EndTreeNode, and _DefineTreeItem.
 */
STATIC PROCEDURE __TreeBuildBranch( ;
      cParentID, ;
      aData, ;
      hChildren, ;
      hParents, ;
      nIdCol, ;
      nTextCol, ;
      nImageCol, ;
      nCargoCol, ;
      bIsNode )

   LOCAL aList
   LOCAL nRow
   LOCAL cID
   LOCAL aImage
   LOCAL Cargo
   LOCAL lHasChildren
   LOCAL lNode

   aList := hb_HGetDef( hChildren, cParentID, {} )

   FOR EACH nRow IN aList

      cID := AllTrim( hb_ValToStr( aData[ nRow ][ nIdCol ] ) )

      lHasChildren := hb_HHasKey( hParents, cID )

      // Determine node vs leaf item classification
      IF HB_ISBLOCK( bIsNode )
         lNode := Eval( bIsNode, aData[ nRow ], lHasChildren )
      ELSE
         lNode := lHasChildren
      ENDIF

      aImage := iif( nImageCol > 0, ;
                     aData[ nRow ][ nImageCol ], ;
                     NIL )

      Cargo := iif( nCargoCol > 0, ;
                    aData[ nRow ][ nCargoCol ], ;
                    NIL )

      IF lNode

         _DefineTreeNode( ;
            aData[ nRow ][ nTextCol ], ;
            aImage, ;
            nRow, ;
            Cargo )

         // Process nested sub-branches recursively
         __TreeBuildBranch( ;
            cID, ;
            aData, ;
            hChildren, ;
            hParents, ;
            nIdCol, ;
            nTextCol, ;
            nImageCol, ;
            nCargoCol, ;
            bIsNode )

         _EndTreeNode()

      ELSE

         _DefineTreeItem( ;
            aData[ nRow ][ nTextCol ], ;
            aImage, ;
            nRow, ;
            Cargo )

      ENDIF

   NEXT

RETURN