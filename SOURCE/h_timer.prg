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

/*
 * Routine: _DefineTimer
 *
 * Purpose:
 *    Registers and initializes a GUI timer control within an HMG window context,
 *    setting up its interval, firing behavior, and associated callback event handler.
 *
 * Parameters:
 *    ControlName   [Character] - Unique identifier for the timer control. If "0", an
 *                                automatic unique name is generated.
 *    ParentForm    [Character] - Name of the parent window. Defaults to the active form
 *                                name if a window definition block is active.
 *    Interval      [Numeric]   - Timer elapse interval in milliseconds. Defaults to 1000 ms.
 *                                Enforced to a minimum of 10 ms during programmatic changes.
 *    ProcedureName [Char/Block]- Action/callback codeblock or procedure name executed on timer event.
 *    Once          [Logical]   - If .T., the timer fires only once; if .F., it repeats. Defaults to .F.
 *    bInit         [Char/Block]- Optional initialization codeblock or event procedure executed
 *                                after control registration.
 *
 * Returns:
 *    Logical - Returns .T. if the Windows timer creation succeeded via InitTimer(); .F. otherwise.
 *
 * Side Effects:
 *    - Updates HMG internal global control registration arrays (_HMG_aControl*).
 *    - Registers a dynamic global variable or name list entry for control reference.
 *    - Registers a Windows timer event associated with the parent window handle.
 *    - Triggers runtime OOP callbacks and initialization procedures if defined.
 */
FUNCTION _DefineTimer( ControlName, ParentForm, ;
      Interval, ProcedureName, Once, bInit )

   LOCAL nParentHandle
   LOCAL cVarName
   LOCAL nId
   LOCAL nControl

   LOCAL lSuccess

   LOCAL nContainerRow := -1
   LOCAL nContainerCol := -1

   // Resolve active parent form if executed within a DEFINE WINDOW block
   IF _HMG_BeginWindowActive
      ParentForm := _HMG_ActiveFormName
   ENDIF

   // Validate existence of the specified parent window
   IF .NOT. _IsWindowDefined( ParentForm )

      MsgMiniGuiError( ;
         "Window: " + ;
         IFNIL( ParentForm, "Parent", ParentForm ) + ;
         " is not defined." )

   ENDIF

   // Generate an automatic unique control identifier if "0" was passed
   IF ISCHAR( ControlName ) .AND. ControlName == "0"

      ControlName := HMG_GetUniqueName()

   ENDIF

   // Ensure control name is unique within the context of the parent form
   IF _IsControlDefined( ControlName, ParentForm )

      MsgMiniGuiError( ;
         "Control: " + ;
         ControlName + ;
         " Of " + ;
         ParentForm + ;
         " Already defined." )

   ENDIF

   // Apply default values for timer interval (1000ms) and single-shot flag (.F.)
   hb_default( @Interval, 1000 )
   hb_default( @Once, .F. )

   // Enforce a minimum safety threshold for timer interval during programmatic updates
   IF _HMG_ProgrammaticChange
      Interval := Max( Interval, 10 )
   ENDIF

   // Retrieve offset coordinates if timer is declared within an active FRAME container
   IF _HMG_FrameLevel > 0

      nContainerRow := ;
         _HMG_ActiveFrameRow[ _HMG_FrameLevel ]

      nContainerCol := ;
         _HMG_ActiveFrameCol[ _HMG_FrameLevel ]

   ENDIF

   // Build internal variable name for runtime reference: _<ParentForm>_<ControlName>
   cVarName := "_" + ParentForm + "_" + ControlName

   // Obtain Win32 handle of parent window and assign a novel internal control ID
   nParentHandle := GetFormHandle( ParentForm )

   nId := _GetId()

   // Initialize low-level Win32 timer via C API bridge
   lSuccess := ;
      InitTimer( ;
         nParentHandle, ;
         nId, ;
         Interval )

   // Allocate next free slot index in HMG global control arrays
   nControl := _GetControlFree()

   // Register dynamic global control reference variable
#ifdef _NAMES_LIST_

   _SetNameList( cVarName, nControl )

#else

   PUBLIC &cVarName. := nControl

#endif

   // Register control identity and handle associations in global tables
   _HMG_aControlType[ nControl ]          := "TIMER"
   _HMG_aControlNames[ nControl ]         := ControlName

   _HMG_aControlHandles[ nControl ]       := 0
   _HMG_aControlParentHandles[ nControl ] := nParentHandle

   _HMG_aControlIds[ nControl ] := nId

   // Bind timer event procedure (timers do not process focus or change events)
   _HMG_aControlProcedures[ nControl ] := ProcedureName

   _HMG_aControlLostFocusProcedure[ nControl ] := ""
   _HMG_aControlGotFocusProcedure[ nControl ]  := ""
   _HMG_aControlChangeProcedure[ nControl ]    := ""

   // Initialize internal state properties and store timer interval value
   _HMG_aControlPageMap[ nControl ]   := {}
   _HMG_aControlValue[ nControl ]     := Interval
   _HMG_aControlInputMask[ nControl ] := ""

   _HMG_aControlDeleted[ nControl ] := .F.
   _HMG_aControlEnabled[ nControl ] := .T.
   _HMG_aControlVisible[ nControl ] := .T.

   // Timers are non-visual components; zero out screen positioning and dimensions
   _HMG_aControlRow[ nControl ]    := 0
   _HMG_aControlCol[ nControl ]    := 0

   _HMG_aControlWidth[ nControl ]  := 0
   _HMG_aControlHeight[ nControl ] := 0

   _HMG_aControlSpacing[ nControl ] := 0

   _HMG_aControlContainerRow[ nControl ] := ;
      nContainerRow

   _HMG_aControlContainerCol[ nControl ] := ;
      nContainerCol

   _HMG_aControlContainerHandle[ nControl ] := 0

   // Reset visual appearance properties
   _HMG_aControlBkColor[ nControl ]   := NIL
   _HMG_aControlFontColor[ nControl ] := NIL

   // Repurpose Picture attribute slot to store single-shot state (ONCE mode)
   _HMG_aControlPicture[ nControl ] := Once

   _HMG_aControlFontName[ nControl ] := ""
   _HMG_aControlFontSize[ nControl ] := 0

   _HMG_aControlFontAttributes[ nControl ] := ;
      { .F., .F., .F., .F. }

   _HMG_aControlToolTip[ nControl ] := ""
   _HMG_aControlCaption[ nControl ] := ""

   _HMG_aControlFontHandle[ nControl ]  := 0
   _HMG_aControlBrushHandle[ nControl ] := 0

   // Initialize unused interactive metadata slots to standard initial state
   _HMG_aControlRangeMin[ nControl ] := 0
   _HMG_aControlRangeMax[ nControl ] := 0

   _HMG_aControlHelpId[ nControl ] := 0

   _HMG_aControlDblClick[ nControl ] := ""
   _HMG_aControlHeadClick[ nControl ] := {}

   _HMG_aControlMiscData1[ nControl ] := 0
   _HMG_aControlMiscData2[ nControl ] := ""

   // Notify OOP engine if object-oriented framework extensions are active
   IF _HMG_lOOPEnabled
      Eval( _HMG_bOnControlInit, nControl, cVarName )
   ENDIF

   // Execute custom initialization codeblock or procedure if provided
   Do_ControlEventProcedure( bInit, nControl )

RETURN lSuccess