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

 Parts of this code is contributed and used here under permission of his author:
 (C)2005 Janusz Pora <januszpora@onet.eu>
---------------------------------------------------------------------------*/

#include "minigui.ch"

#define NOFOUND        -1
#define NOMRUS          0

// Symbolic indices mapping into the module static configuration state array (asMRU)
#define cFileIni        asMRU[1]
#define cSectionIni     asMRU[2]
#define MRUParentForm   asMRU[3]
#define MRUCount        asMRU[4]
#define cMRU_Id         asMRU[5]
#define maxMRU_Files    asMRU[6]

// Symbolic indices mapping into individual MRU file detail arrays within aMRU_File
#define MRU_CAPTION     1
#define MRU_FILENAME    2
#define MRU_MENU_ID     3
#define MRU_ACTION      4
#define MRU_INDEX       5

// Static array holding module-wide MRU settings and parent window state
STATIC asMRU := { Nil, Nil, Nil, Nil, Nil, Nil }
// Static array storing active MRU file entry records
STATIC aMRU_File

/*
 * Routine: AddMRUItem
 * Purpose: Adds a new file item to the MRU list or moves an existing duplicate item to the top of the list.
 * Parameters:
 *   - cNewItem (Character): The target file path or name to add to the MRU list.
 *   - cAction  (Character): Function or procedure call template string associated with selecting this menu item.
 * Return:
 *   - Nil
 * Side Effects:
 *   - Reorders or adds entries in internal tracking arrays and updates parent GUI menu controls.
 */
FUNCTION AddMRUItem( cNewItem, cAction )
   LOCAL nDuplicate

   // Check if the item already exists in the current MRU list
   nDuplicate := CheckForDuplicateMRU( cNewItem )

   // If a duplicate exists, remove its menu entry before re-inserting at the top
   IF nDuplicate <> NOFOUND
      ReorderMRUList( nDuplicate )
   ENDIF

   // Add new menu item if it was not already the first entry, or if the list is currently empty
   IF nDuplicate <> 1 .OR. MRUCount == 0
      AddMenuElement( cNewItem, cAction )
   ENDIF

RETURN Nil

/*
 * Routine: CheckForDuplicateMRU
 * Purpose: Searches the MRU file list for a matching file path using case-insensitive comparison.
 * Parameters:
 *   - cNewItem (Character): The file path string to search for.
 * Return:
 *   - Numeric: 1-based array index of the duplicate entry, or NOFOUND (-1) if empty or not found.
 * Side Effects:
 *   - None.
 */
STATIC FUNCTION CheckForDuplicateMRU( cNewItem )
   LOCAL nDuplicate := NOFOUND
   LOCAL cCompare

   // Early exit if an empty file string was passed
   IF Empty( cNewItem )
      RETURN nDuplicate
   ENDIF

   // Convert path to uppercase for case-insensitive matching
   cCompare := Upper( cNewItem )

   // Search aMRU_File array using Harbour AScan with a codeblock condition
   nDuplicate := AScan( ;
      aMRU_File, ;
      {|aItem| Upper( aItem[MRU_FILENAME] ) == cCompare } )

   // Normalize 0 (not found result from AScan) to NOFOUND (-1)
   IF nDuplicate == 0
      nDuplicate := NOFOUND
   ENDIF

RETURN nDuplicate

/*
 * Routine: BuildMRUCaption
 * Purpose: Formats a file path into a displayable menu caption, truncating long paths with an ellipsis.
 * Parameters:
 *   - cFileName (Character): Full file path to format.
 * Return:
 *   - Character: Formatted caption string suitable for menu display (max ~40 characters).
 * Side Effects:
 *   - None.
 */
STATIC FUNCTION BuildMRUCaption( cFileName )
   LOCAL cCaption

   // Truncate path if longer than 39 chars: keep drive/prefix (3 chars) and trailing path (35 chars)
   cCaption := iif( ;
      Len( cFileName ) < 40, ;
      cFileName, ;
      SubStr( cFileName, 1, 3 ) + "..." + ;
      SubStr( cFileName, Len( cFileName ) - 34 ) )

RETURN cCaption

/*
 * Routine: BuildMRUAction
 * Purpose: Dynamically constructs an executable code block callback for a menu item event handler.
 * Parameters:
 *   - cFileName (Character): Target file path parameter to pass to the action callback.
 *   - cAction   (Character): Function or procedure invocation template string (e.g. "OpenFile()").
 * Return:
 *   - Block: Dynamic code block callback that invokes the target function passing cFileName as parameter.
 * Side Effects:
 *   - Uses the Harbour macro compiler operator (&) to evaluate and create the dynamic code block.
 */
STATIC FUNCTION BuildMRUAction( cFileName, cAction )
   LOCAL bAction
   LOCAL cProcName

   // Return dummy empty codeblock if no action handler string is specified
   IF Empty( cAction )
      RETURN {|| Nil }
   ENDIF

   // Extract function name prior to opening parenthesis
   cProcName := Left( cAction, At( "(", cAction ) )

   // Dynamically compile codeblock string: {|| ProcName( "cFileName" ) }
   bAction := &( ;
      '{|| ' + cProcName + ' "' + cFileName + '" ) }' )

RETURN bAction

/*
 * Routine: RefreshMRUMenuCaptions
 * Purpose: Updates and re-indexes all visible MRU menu captions (&1, &2, etc.) and handlers in the window menu.
 * Parameters:
 *   - None.
 * Return:
 *   - Nil
 * Side Effects:
 *   - Modifies Win32 menu items on the parent form via HMG internal _ModifyMenuItem API calls.
 */
STATIC FUNCTION RefreshMRUMenuCaptions()
   LOCAL n
   LOCAL cMenuId
   LOCAL cCaption

   // Iterate through active MRU entries to re-assign accelerator shortcut prefixes (&1 .. &N)
   FOR n := 1 TO Len( aMRU_File )

      cMenuId := aMRU_File[n, MRU_MENU_ID]

      // Format caption string with numeric menu accelerator prefix using hb_ntos
      cCaption := ;
         "&" + hb_ntos( n ) + " " + ;
         aMRU_File[n, MRU_CAPTION]

      // Update win32 menu item text and action callback
      _ModifyMenuItem( ;
         cMenuId, ;
         MRUParentForm, ;
         cCaption, ;
         aMRU_File[n, MRU_ACTION] )

   NEXT

RETURN Nil

/*
 * Routine: AddMenuElement
 * Purpose: Inserts a new file entry at the top of the MRU menu and internal array, creating dynamic GUI
 *          menu items and removing old entries if the total count exceeds the maximum limit.
 * Parameters:
 *   - cNewItem (Character): File path to insert into the MRU list.
 *   - cAction  (Character): Procedure string to execute on menu selection.
 * Return:
 *   - Nil
 * Side Effects:
 *   - Alters internal MRU arrays and modifies, inserts, or removes parent window GUI menu controls.
 */
FUNCTION AddMenuElement( cNewItem, cAction )
   LOCAL bAction
   LOCAL cCaption
   LOCAL cMenuId
   LOCAL cNewMenuId
   LOCAL n
   LOCAL nFreeIndex
   LOCAL nPos

   // Build display caption and dynamic callback code block
   cCaption := BuildMRUCaption( cNewItem )
   bAction  := BuildMRUAction( cNewItem, cAction )

   IF MRUCount == 0

      // First item: modify the base menu item control established during initialization
      cMenuId := cMRU_Id

      _ModifyMenuItem( ;
         cMenuId, ;
         MRUParentForm, ;
         "&1 " + cCaption, ;
         bAction )

      // Add initial record to active files array
      AAdd( aMRU_File, ;
         { cCaption, cNewItem, cMenuId, bAction, 1 } )

   ELSE

      nFreeIndex := 1

      // Search for the lowest available numeric index for menu item control naming
      FOR n := 1 TO Len( aMRU_File ) + 1

         nPos := AScan( ;
            aMRU_File, ;
            {|aItem| aItem[MRU_INDEX] == n } )

         IF nPos == 0
            nFreeIndex := n
            EXIT
         ENDIF

      NEXT

      // Construct a unique menu control identifier name
      cNewMenuId := cMRU_Id + "_" + hb_ntos( nFreeIndex )
      cMenuId    := aMRU_File[1, MRU_MENU_ID]

      // Dynamically insert new menu item before current first menu item
      _InsertMenuItem( ;
         cMenuId, ;
         MRUParentForm, ;
         "&1 " + cCaption, ;
         bAction, ;
         cNewMenuId )

      // Insert new record at array index 1, growing array size automatically
      AIns( ;
         aMRU_File, ;
         1, ;
         { ;
            cCaption, ;
            cNewItem, ;
            cNewMenuId, ;
            bAction, ;
            nFreeIndex ;
         }, ;
         .T. )

      // Re-number menu item accelerator shortcuts
      RefreshMRUMenuCaptions()

      // Enforce max MRU item limit by removing overflow item from array and GUI menu
      IF Len( aMRU_File ) > maxMRU_Files

         cMenuId := aMRU_File[Len( aMRU_File ), MRU_MENU_ID]

         ASize( aMRU_File, maxMRU_Files )

         _RemoveMenuItem( cMenuId, MRUParentForm )

      ENDIF

   ENDIF

   // Increment total MRU item counter
   MRUCount++

RETURN Nil

/*
 * Routine: ReorderMRUList
 * Purpose: Removes an existing duplicate MRU entry from its current position before re-inserting at top.
 * Parameters:
 *   - nDuplicateLocation (Numeric): 1-based index in aMRU_File array where duplicate resides.
 * Return:
 *   - Nil
 * Side Effects:
 *   - Deletes entry from aMRU_File array and removes corresponding GUI menu control via _RemoveMenuItem.
 */
STATIC FUNCTION ReorderMRUList( nDuplicateLocation )
   LOCAL cMenuId

   // Do nothing if item is already at top or index is invalid
   IF nDuplicateLocation <= 1
      RETURN Nil
   ENDIF

   cMenuId := aMRU_File[nDuplicateLocation, MRU_MENU_ID]

   // Delete existing menu item control from parent form menu bar
   _RemoveMenuItem( cMenuId, MRUParentForm )

   // Remove array element and shrink array size using Harbour extension hb_ADel
   hb_ADel( aMRU_File, nDuplicateLocation, .T. )

RETURN Nil

/*
 * Routine: SaveMRUFileList
 * Purpose: Writes current active MRU file paths to the specified INI configuration file and section.
 * Parameters:
 *   - None.
 * Return:
 *   - Nil
 * Side Effects:
 *   - Performs disk file I/O to update INI file section entries.
 */
FUNCTION SaveMRUFileList()
   LOCAL cFile
   LOCAL n

   // Open INI storage file using HMG preprocessor directives
   BEGIN INI FILE cFileIni

      // Save entries up to maxMRU_Files limit (clearing unused entries)
      FOR n := 1 TO maxMRU_Files

         cFile := iif( ;
            n <= Len( aMRU_File ), ;
            aMRU_File[n, MRU_FILENAME], ;
            "" )

         SET SECTION cSectionIni ;
            ENTRY hb_ntos( n ) ;
            TO cFile

      NEXT

   END INI

RETURN Nil

/*
 * Routine: _DefineMruItem
 * Purpose: Initializes the MRU system, loads saved MRU file entries from an INI file, and populates the parent window menu.
 * Parameters:
 *   - cCaption  (Character, Optional): Display caption text when list is empty. Default: " (Empty) ".
 *   - cIniFile  (Character, Optional): Path to INI storage file. Default: "mru.ini".
 *   - cSection  (Character, Optional): INI section header name. Default: "MRU".
 *   - nMaxItems (Numeric, Optional)  : Maximum allowed MRU items. Default: 10.
 *   - cAction   (Character, Optional): Action procedure string to invoke on selection. Default: Nil.
 *   - cName     (Character, Optional): Base HMG control identifier name for menu items. Default: "MRU".
 * Return:
 *   - Nil
 * Side Effects:
 *   - Reads INI storage, creates initial GUI MENUITEM control, and initializes global static state variables.
 */
FUNCTION _DefineMruItem( ;
   cCaption, ;
   cIniFile, ;
   cSection, ;
   nMaxItems, ;
   cAction, ;
   cName )
   LOCAL aTmp := {}
   LOCAL cValue := ""
   LOCAL lExist := .F.
   LOCAL n

   // Supply default values for missing optional arguments
   DEFAULT ;
      cCaption  := " (Empty) ", ;
      nMaxItems := 10, ;
      cName     := "MRU", ;
      cIniFile  := "mru.ini", ;
      cSection  := "MRU"

   // Set global static configuration values
   cFileIni      := cIniFile
   cSectionIni   := cSection
   MRUParentForm := _HMG_xMainMenuParentName
   MRUCount      := 0
   aMRU_File     := {}
   cMRU_Id       := cName
   maxMRU_Files  := nMaxItems

   // Read stored MRU entries from INI file
   BEGIN INI FILENAME cIniFile

      FOR n := 1 TO nMaxItems

         GET cValue ;
            SECTION cSection ;
            ENTRY hb_ntos( n ) ;
            DEFAULT ""

         IF Empty( cValue )
            EXIT
         ENDIF

         lExist := .T.

         AAdd( aTmp, cValue )

         // Create primary placeholder MENUITEM control on first iteration
         IF n == 1
            MENUITEM cCaption NAME &cName
         ENDIF

      NEXT

   END INI

   IF lExist

      IF Empty( cAction )
         cAction := Nil
      ENDIF

      // Populate MRU items in reverse order so item 1 ends up at the top
      FOR EACH n IN aTmp DESCEND
         AddMRUItem( n, cAction )
      NEXT

   ELSE

      // Define disabled placeholder menu item if no stored history exists
      MENUITEM cCaption NAME &cName DISABLED

   ENDIF

RETURN Nil

/*
 * Routine: ClearMRUList
 * Purpose: Removes all dynamic MRU entries, resets the primary menu item to disabled empty state, and clears internal tracking.
 * Parameters:
 *   - None.
 * Return:
 *   - Nil
 * Side Effects:
 *   - Removes Win32 menu controls via _RemoveMenuItem, updates primary menu control via _ModifyMenuItem/SetProperty, and resets state arrays.
 */
FUNCTION ClearMRUList()
   LOCAL cMenuId
   LOCAL n

   // Iterate backwards through active MRU items to remove dynamic menu controls
   FOR n := Len( aMRU_File ) TO 1 STEP -1

      cMenuId := aMRU_File[n, MRU_MENU_ID]

      IF n > 1

         // Delete dynamic menu item controls beyond item 1
         _RemoveMenuItem( cMenuId, MRUParentForm )

      ELSE

         // Reset primary base menu item text and action callback to default empty state
         _ModifyMenuItem( ;
            cMenuId, ;
            MRUParentForm, ;
            " (Empty) ", ;
            {|| Nil } )

         // Disable base menu item control
         SetProperty( ;
            MRUParentForm, ;
            cMenuId, ;
            "Enabled", ;
            .F. )

         // Reset state tracking variables
         cMRU_Id   := cMenuId
         aMRU_File := {}
         MRUCount  := 0

      ENDIF

   NEXT

RETURN Nil