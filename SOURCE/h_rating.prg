/*
 * MINIGUI - Harbour Win32 GUI library source
 *
 * Copyright 2014-2026 Grigory Filatov <gfilatov@gmail.com>
 */

#include "minigui.ch"

/*
 * Routine: _RatingImageName
 * Purpose: Generates a unique sub-control name string for a specific rating star item.
 *
 * Parameters:
 *   cWindow  (C) - Name of the parent window.
 *   cControl (C) - Base name of the rating control.
 *   nIndex   (N) - 1-based index of the rating star element.
 *
 * Return:
 *   (C) Standardized sub-control name formatted as "<Window>_<Control>_<Index>".
 *
 * Side Effects:
 *   None.
 */
STATIC FUNCTION _RatingImageName( cWindow, cControl, nIndex )
RETURN cWindow + "_" + cControl + "_" + hb_ntos( nIndex )

/*
 * Routine: _ApplyRatingImage
 * Purpose: Applies either the empty or full state picture to an individual star element.
 *
 * Parameters:
 *   cWindow   (C) - Name of the parent window.
 *   cControl  (C) - Name of the parent rating control.
 *   nIndex    (N) - Index of the target star item.
 *   nImagePos (N) - Image array index (1 = empty state, 2 = full state).
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   Updates the Picture property of the specified star image control.
 */
STATIC FUNCTION _ApplyRatingImage( cWindow, cControl, nIndex, nImagePos )
   LOCAL cImageName := _RatingImageName( cWindow, cControl, nIndex )
   // Retrieve the two-element image pair [empty, full] saved in the image control's Cargo property
   LOCAL aImages := GetProperty( cWindow, cImageName, "Cargo" )
   SetProperty( cWindow, cImageName, "Picture", aImages[ nImagePos ] )
RETURN NIL

/*
 * Routine: _PaintRating
 * Purpose: Visually paints stars up to the active selection level.
 *
 * Parameters:
 *   cWindow   (C) - Name of the parent window.
 *   cControl  (C) - Name of the rating control.
 *   nSelected (N) - Number of stars to render in active/full state.
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   Clears all stars to empty state, then updates stars 1 through nSelected to full state.
 */
STATIC FUNCTION _PaintRating( cWindow, cControl, nSelected )
   LOCAL i
   ClearRating( cWindow, cControl )
   // Highlight star elements up to current selected position
   FOR i := 1 TO nSelected
      _ApplyRatingImage( cWindow, cControl, i, 2 )
   NEXT
RETURN NIL

/*
 * Routine: _DefineRating
 * Purpose: Defines and registers a composite star Rating GUI control in the HMG architecture.
 *
 * Parameters:
 *   ControlName (C) - Unique name of the rating control.
 *   ParentForm  (C) - Parent window name.
 *   x           (N) - X-coordinate position (column).
 *   y           (N) - Y-coordinate position (row).
 *   w           (N) - Width of individual star images (default 100).
 *   h           (N) - Height of individual star images (default 20).
 *   nValue      (N) - Initial rating value (default 0).
 *   aImages     (A) - Array of two image filenames/resources {empty, full}.
 *   nCount      (N) - Total number of rating stars (default 5).
 *   nSpace      (N) - Spacing between stars in pixels.
 *   cToolTip    (C) - Tooltip text for rating items.
 *   bOnChange   (B) - Code block executed when rating selection changes.
 *   lBorder     (L) - Draws framing rectangle around control if .T.
 *   lResource   (L) - Specifies if image names are embedded resource IDs.
 *   lReadOnly   (L) - Disables interactive mouse handling if .T.
 *   lInvisible  (L) - Initial visibility state (.T. = hidden).
 *   lVertical   (L) - Layout direction (.T. = vertical, .F. = horizontal).
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   - Resolves active form/frame coordinates and parent context.
 *   - Validates existence of form and checks for duplicate control name.
 *   - Creates dynamic global public variable for the control ID.
 *   - Instantiates child IMAGE sub-controls via _InitRating.
 *   - Appends control properties to HMG internal global state arrays (_HMG_aControl*).
 */
FUNCTION _DefineRating( ControlName, ParentForm, x, y, w, h, nValue, ;
      aImages, nCount, nSpace, cToolTip, bOnChange, lBorder, ;
      lResource, lReadOnly, lInvisible, lVertical )

   LOCAL cParentForm, cPublicVar, hControl

   // Set default parameter values for control dimension and options
   DEFAULT h TO 20
   DEFAULT w TO 100
   DEFAULT nValue TO 0
   DEFAULT aImages TO { "empty.png", "full.png" }
   DEFAULT nCount TO 5
   DEFAULT lBorder TO .F.
   DEFAULT lReadOnly TO .F.
   DEFAULT lInvisible TO .F.
   DEFAULT lVertical TO .F.

   // Inherit parent window context when executing inside standard DEFINE WINDOW block
   IF _HMG_BeginWindowActive
      ParentForm := _HMG_ActiveFormName
   ENDIF

   // Adjust coordinates relative to parent FRAME container if nested
   IF _HMG_FrameLevel > 0
      x += _HMG_ActiveFrameCol[ _HMG_FrameLevel ]
      y += _HMG_ActiveFrameRow[ _HMG_FrameLevel ]
      ParentForm := _HMG_ActiveFrameParentFormName[ _HMG_FrameLevel ]
   ENDIF

   // Verify window existence and control name uniqueness
   IF ! _IsWindowDefined( ParentForm )
      MsgMiniGuiError( "Window: " + ParentForm + " is not defined." )
   ENDIF
   IF _IsControlDefined( ControlName, ParentForm )
      MsgMiniGuiError( "Control: " + ControlName + " Of " + ParentForm + " Already defined." )
   ENDIF

   // Use built-in resource identifiers if resource flag is enabled
   IF lResource
      aImages := { "_empty", "_full" }
   ENDIF

   cPublicVar := "_" + ParentForm + "_" + ControlName

#ifdef _NAMES_LIST_

   _SetNameList( cPublicVar, Len( _HMG_aControlNames ) + 1 )

#else

   // Dynamically declare global variable to store HMG control registration index
   PUBLIC &cPublicVar. := Len( _HMG_aControlNames ) + 1

#endif

   cParentForm := ParentForm
   ParentForm := GetFormHandle( ParentForm )

   // Initialize constituent star image sub-controls
   hControl := _InitRating( cParentForm, ControlName, x, y, w, h, nValue, ;
      aImages, nCount, nSpace, cToolTip, bOnChange, lBorder, ;
      lReadOnly, lInvisible, lVertical )

   // Register sub-control handle into parent TAB page array if inside TAB context
   IF _HMG_BeginTabActive
      AAdd( _HMG_ActiveTabCurrentPageMap, hControl )
   ENDIF

   // Register control properties into HMG system arrays
   AAdd( _HMG_aControlType, "RATING" )
   AAdd( _HMG_aControlNames, ControlName )
   AAdd( _HMG_aControlHandles, hControl )
   AAdd( _HMG_aControlParentHandles, ParentForm )
   AAdd( _HMG_aControlIds, nCount )
   AAdd( _HMG_aControlProcedures, "" )
   AAdd( _HMG_aControlPageMap, {} )
   AAdd( _HMG_aControlValue, nValue )
   AAdd( _HMG_aControlInputMask, "" )
   AAdd( _HMG_aControllostFocusProcedure, "" )
   AAdd( _HMG_aControlGotFocusProcedure, "" )
   AAdd( _HMG_aControlChangeProcedure, bOnChange )
   AAdd( _HMG_aControlDeleted, .F. )
   AAdd( _HMG_aControlBkColor, {} )
   AAdd( _HMG_aControlFontColor, {} )
   AAdd( _HMG_aControlDblClick, "" )
   AAdd( _HMG_aControlHeadClick, {} )
   AAdd( _HMG_aControlRow, y )
   AAdd( _HMG_aControlCol, x )
   AAdd( _HMG_aControlWidth, w )
   AAdd( _HMG_aControlHeight, h )
   AAdd( _HMG_aControlSpacing, 0 )
   AAdd( _HMG_aControlContainerRow, iif( _HMG_FrameLevel > 0, _HMG_ActiveFrameRow[ _HMG_FrameLevel ], -1 ) )
   AAdd( _HMG_aControlContainerCol, iif( _HMG_FrameLevel > 0, _HMG_ActiveFrameCol[ _HMG_FrameLevel ], -1 ) )
   AAdd( _HMG_aControlPicture, "" )
   AAdd( _HMG_aControlContainerHandle, 0 )
   AAdd( _HMG_aControlFontName, "" )
   AAdd( _HMG_aControlFontSize, 0 )
   AAdd( _HMG_aControlFontAttributes, { .F., .F., .F., .F. } )
   AAdd( _HMG_aControlToolTip, cToolTip )
   AAdd( _HMG_aControlRangeMin, 0 )
   AAdd( _HMG_aControlRangeMax, 0 )
   AAdd( _HMG_aControlCaption, "" )
   AAdd( _HMG_aControlVisible, ! lInvisible )
   AAdd( _HMG_aControlHelpId, 0 )
   AAdd( _HMG_aControlFontHandle, 0 )
   AAdd( _HMG_aControlBrushHandle, 0 )
   AAdd( _HMG_aControlEnabled, .T. )
   AAdd( _HMG_aControlMiscData1, 0 )
   AAdd( _HMG_aControlMiscData2, "" )
RETURN NIL

/*
 * Routine: _ReleaseRating
 * Purpose: Releases and destroys all child image controls associated with a rating control.
 *
 * Parameters:
 *   cWindow  (C) - Name of parent window.
 *   cControl (C) - Name of target rating control.
 *
 * Return:
 *   None
 *
 * Side Effects:
 *   - Releases each individual image sub-control.
 *   - Removes control metadata via _ReleaseControl.
 *   - Erases window region to trigger redrawing.
 */
PROCEDURE _ReleaseRating( cWindow, cControl )
   LOCAL i, nCount, cImageName

   // Ensure control is defined prior to attempting release
   IF ! _IsControlDefined( cControl, cWindow )
      RETURN
   ENDIF

   // Iterate over each star sub-control and invoke destruction method
   nCount := GetControlId( cControl, cWindow )
   FOR i := 1 TO nCount
      cImageName := _RatingImageName( cWindow, cControl, i )
      DoMethod( cWindow, cImageName, "Release" )
   NEXT

   // Unregister main control from HMG control registry and refresh window area
   _ReleaseControl( cControl, cWindow )
   EraseWindow( cWindow )
RETURN

/*
 * Routine: _InitRating
 * Purpose: Creates individual IMAGE controls for each star and sets up event handlers.
 *
 * Parameters:
 *   ParentForm  (C) - Parent window name.
 *   ControlName (C) - Rating control name.
 *   x           (N) - Horizontal position.
 *   y           (N) - Vertical position.
 *   w           (N) - Item width.
 *   h           (N) - Item height.
 *   nValue      (N) - Initial rating value.
 *   aImages     (A) - Array containing empty and full picture resources/files.
 *   nCount      (N) - Total star count.
 *   nSpace      (N) - Pixel spacing between items.
 *   cToolTip    (C) - Tooltip text.
 *   bOnChange   (B) - Change callback codeblock.
 *   lBorder     (L) - Border rectangle flag.
 *   lReadOnly   (L) - Read-only state flag.
 *   lInvisible  (L) - Initial hidden state flag.
 *   lVertical   (L) - Layout orientation flag.
 *
 * Return:
 *   (N) Generated unique handle/ID for the composite rating control sequence.
 *
 * Side Effects:
 *   - Dynamically defines multiple IMAGE GUI controls in the target window.
 *   - Configures interactive hover, leave, and click events for each star.
 *   - Populates image reference and callback data in internal HMG arrays.
 *   - Draws surrounding frame graphics if requested.
 */
FUNCTION _InitRating( ParentForm, ControlName, x, y, w, h, nValue, ;
      aImages, nCount, nSpace, cToolTip, bOnChange, lBorder, ;
      lReadOnly, lInvisible, lVertical )

   LOCAL i, cImageName, nCol := x, nRow := y, nIndex

   DEFAULT nSpace TO 0

   // Generate individual IMAGE controls for each rating step
   FOR i := 1 TO nCount
      cImageName := _RatingImageName( ParentForm, ControlName, i )

      DEFINE IMAGE ( cImageName )
         PARENT ( ParentForm )
         ROW y
         COL nCol
         WIDTH w
         HEIGHT h
         PICTURE aImages[ 1 ]
         TOOLTIP cToolTip
         ONMOUSEHOVER iif( lReadOnly, NIL, OnHoverRate( ParentForm, ControlName ) )
         ONMOUSELEAVE iif( lReadOnly, NIL, OnLeaveRate( ParentForm, ControlName, bOnChange ) )
         ONCLICK iif( lReadOnly, NIL, ;
            ( nIndex := Val( SubStr( This.NAME, RAt( "_", This.Name ) + 1 ) ), ;
            SetProperty( ParentForm, ControlName, "Value", nIndex ), ;
            OnSelectRate( ParentForm, ControlName, bOnChange ) ) )
         INVISIBLE lInvisible
      END IMAGE

      // Map sub-control metadata into HMG runtime structures
      nIndex := GetControlIndex( cImageName, ParentForm )
      _HMG_aControlIds[ nIndex ] := nCount
      _HMG_aControlMiscData2[ nIndex ] := aImages
      _HMG_aControlChangeProcedure[ nIndex ] := bOnChange
      IF nValue > 0
         _HMG_aControlValue[ nIndex ] := nValue
      ENDIF

      // Advance layout coordinate based on orientation
      IF lVertical
         y += h + nSpace
      ELSE
         nCol += w + nSpace
      ENDIF
   NEXT

   // Draw bounding border frame if requested
   IF lBorder
      _DrawRatingBorder( ParentForm, lVertical, nRow, x, y, nCol, w, h, nSpace )
   ENDIF

   // Apply initial value visualization if greater than zero
   IF nValue > 0
      OnLeaveRate( ParentForm, ControlName, bOnChange )
   ENDIF
RETURN _GetId()

/*
 * Routine: _DrawRatingBorder
 * Purpose: Draws a light gray frame rectangle surrounding the rating elements.
 *
 * Parameters:
 *   cWindow   (C) - Parent window identifier.
 *   lVertical (L) - True if vertical orientation, false if horizontal.
 *   nRow      (N) - Initial top coordinate.
 *   x         (N) - Initial left coordinate.
 *   y         (N) - Final bottom coordinate.
 *   nCol      (N) - Final right coordinate.
 *   w         (N) - Width of item.
 *   h         (N) - Height of item.
 *   nSpace    (N) - Inter-item spacing.
 *
 * Return:
 *   None
 *
 * Side Effects:
 *   Executes DRAW RECTANGLE graphics command on parent window.
 */
STATIC PROCEDURE _DrawRatingBorder( cWindow, lVertical, nRow, x, y, nCol, w, h, nSpace )
   IF lVertical
      DRAW RECTANGLE IN WINDOW &cWindow AT nRow - 1, x - 1 TO y - nSpace + 1, nCol + w + 1 PENCOLOR { 192, 192, 192 }
   ELSE
      DRAW RECTANGLE IN WINDOW &cWindow AT nRow - 1, x - 1 TO nRow + h + 1, nCol - nSpace + 1 PENCOLOR { 192, 192, 192 }
   ENDIF
RETURN

/*
 * Routine: OnHoverRate
 * Purpose: Handles mouse hover over a star image to highlight potential rating selection.
 *
 * Parameters:
 *   cWindow  (C) - Parent window name.
 *   cControl (C) - Parent rating control name.
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   Paints stars up to hovered element index extracted from `This.Name`.
 */
STATIC FUNCTION OnHoverRate( cWindow, cControl )
   // Extract 1-based star index from suffix of hovered control name (e.g. "Form_Ctrl_3" -> 3)
   LOCAL nSelected := Val( SubStr( This.NAME, RAt( "_", This.Name ) + 1 ) )
   _PaintRating( cWindow, cControl, nSelected )
RETURN NIL

/*
 * Routine: OnLeaveRate
 * Purpose: Handles mouse leave from star images, resetting display to stored value.
 *
 * Parameters:
 *   cWindow   (C) - Parent window name.
 *   cControl  (C) - Parent rating control name.
 *   bOnChange (B) - Change notification callback block.
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   - Clears stars if current stored value is 0 and fires bOnChange.
 *   - Otherwise repaints control to match actual selected rating value.
 */
STATIC FUNCTION OnLeaveRate( cWindow, cControl, bOnChange )
   LOCAL nSelected := GetProperty( cWindow, cControl, "Value" )
   IF nSelected == 0
      ClearRating( cWindow, cControl )
      IF ISBLOCK( bOnChange )
         Eval( bOnChange, nSelected )
      ENDIF
   ELSE
      OnSelectRate( cWindow, cControl, bOnChange )
   ENDIF
RETURN NIL

/*
 * Routine: OnSelectRate
 * Purpose: Processes star selection click event, updating display and invoking change callback.
 *
 * Parameters:
 *   cWindow   (C) - Parent window name.
 *   cControl  (C) - Target rating control name.
 *   bOnChange (B) - User-defined change callback codeblock.
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   - Updates visual star state to current control value.
 *   - Executes bOnChange callback passing new rating value.
 */
STATIC FUNCTION OnSelectRate( cWindow, cControl, bOnChange )
   LOCAL nSelected := GetProperty( cWindow, cControl, "Value" )
   IF nSelected <= 0
      RETURN NIL
   ENDIF
   _PaintRating( cWindow, cControl, nSelected )
   IF ISBLOCK( bOnChange )
      Eval( bOnChange, nSelected )
   ENDIF
RETURN NIL

/*
 * Routine: ClearRating
 * Purpose: Resets all star elements in a rating control to empty state.
 *
 * Parameters:
 *   cWindow  (C) - Parent window name.
 *   cControl (C) - Target rating control name.
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   Sets Picture property of all star image items to empty image.
 */
FUNCTION ClearRating( cWindow, cControl )
   LOCAL i, nCount := GetControlId( cControl, cWindow )
   FOR i := 1 TO nCount
      _ApplyRatingImage( cWindow, cControl, i, 1 )
   NEXT
RETURN NIL

/*
 * Routine: RefreshRating
 * Purpose: Refresh the visual display and fire callbacks for a rating control.
 *
 * Parameters:
 *   ParentForm  (C) - Parent window name.
 *   ControlName (C) - Target rating control name.
 *
 * Return:
 *   (NIL)
 *
 * Side Effects:
 *   Triggers OnLeaveRate logic to re-apply stored control rating value.
 */
FUNCTION RefreshRating( ParentForm, ControlName )
   LOCAL bOnChange := _GetControlAction( ControlName, ParentForm, "ONCHANGE" )
RETURN OnLeaveRate( ParentForm, ControlName, bOnChange )

/*
 * Routine: ToggleRatingReadOnly
 * Purpose: Enables or disables interactive hover/focus handlers for read-only toggling.
 *
 * Parameters:
 *   cWindow   (C) - Parent window name.
 *   cControl  (C) - Target rating control name.
 *   lReadOnly (L) - Set .T. to make read-only, .F. to restore interactivity.
 *
 * Return:
 *   None
 *
 * Side Effects:
 *   - Overrides or restores ONGOTFOCUS / ONLOSTFOCUS properties on image sub-controls.
 *   - Stores original event handlers in HMG spacing array _HMG_aControlSpacing when making read-only.
 */
PROCEDURE ToggleRatingReadOnly( cWindow, cControl, lReadOnly )
   LOCAL i, k, nCount, cImageName
   k := GetControlIndex( cControl, cWindow )
   nCount := GetControlId( cControl, cWindow )
   FOR i := 1 TO nCount
      cImageName := _RatingImageName( cWindow, cControl, i )
      IF lReadOnly
         // Save original focus/hover handlers into HMG internal array if not already backed up
         IF ! ISARRAY( _HMG_aControlSpacing[ k ] )
            _HMG_aControlSpacing[ k ] := { ;
               GetProperty( cWindow, cImageName, "ONGOTFOCUS" ), ;
               GetProperty( cWindow, cImageName, "ONLOSTFOCUS" ) }
         ENDIF
         // Clear event handlers to disable interactive hovering/clicking feedback
         SetProperty( cWindow, cImageName, "ONGOTFOCUS", {|| NIL } )
         SetProperty( cWindow, cImageName, "ONLOSTFOCUS", {|| NIL } )
      ELSE
         // Restore original focus/hover handlers from backup array
         IF ISARRAY( _HMG_aControlSpacing[ k ] )
            SetProperty( cWindow, cImageName, "ONGOTFOCUS", _HMG_aControlSpacing[ k ][ 1 ] )
            SetProperty( cWindow, cImageName, "ONLOSTFOCUS", _HMG_aControlSpacing[ k ][ 2 ] )
         ENDIF
      ENDIF
   NEXT
RETURN