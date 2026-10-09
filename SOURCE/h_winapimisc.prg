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

#ifdef __XHARBOUR__
#define __SYSDATA__
#endif

#include 'minigui.ch'

/*-----------------------------------------------------------------------------*
   FUNCTION WindowsVersion()

   Purpose:
      Retrieves detailed Windows Operating System version information, bypassing
      API version spoofing/manifest issues on Windows 10 and 11 by inspecting
      the system registry directly, or falling back to standard system API calls
      on legacy OS versions.

   Parameters:
      None.

   Returns:
      Array: A 3-element array formatted as { cProductName, cVersion, cBuildString }:
         - [1] Character: Product name (e.g., "Windows 11 Pro").
         - [2] Character: OS Release/Display ID (e.g., "22H2" or "1909").
         - [3] Character: Formatted build string (e.g., "Build 22621.1702").

   Side Effects:
      Queries HKEY_LOCAL_MACHINE registry keys. Performs no GUI updates or
      global state modifications.
 *------------------------------------------------------------------------------*/
FUNCTION WindowsVersion()

   // HKLM registry path containing NT OS identification and build metrics
   LOCAL cKey := "SOFTWARE\Microsoft\Windows NT\CurrentVersion"
   LOCAL cProd, cVer, cBuild, cExtra := ""
   LOCAL aWin

   // Direct registry querying for modern OS releases (Windows 10 / Windows 11)
   IF IsWin10OrLater()

      // Retrieve descriptive product name from registry
      cProd  := GetRegistryValue( HKEY_LOCAL_MACHINE, cKey, "ProductName" )

      // Correct Windows 11 branding and read modern 'DisplayVersion' key
      IF hb_osisWin11()
         cProd := StrTran( cProd, "10", "11" )
         cVer  := GetRegistryValue( HKEY_LOCAL_MACHINE, cKey, "DisplayVersion" )
      ELSE
         // Query legacy 'ReleaseId' for Windows 10 release tracking (e.g., 2004, 20H2)
         cVer  := GetRegistryValue( HKEY_LOCAL_MACHINE, cKey, "ReleaseId" )
      ENDIF

      // Construct build string combining base build number and Update Build Revision (UBR)
      cBuild := ;
         GetRegistryValue( HKEY_LOCAL_MACHINE, cKey, "CurrentBuild" ) + "." + ;
         hb_ntos( GetRegistryValue( HKEY_LOCAL_MACHINE, cKey, "UBR", "N" ) )

   ELSE

      // Fallback for pre-Windows 10 OS using standard HMG WinVersion() API call
      aWin := WinVersion()

      cProd  := aWin[1]
      cVer   := aWin[2]
      cBuild := aWin[3]

      // Extract optional Service Pack or extra version information if present
      IF Len( aWin ) >= 4
         cExtra := aWin[4]
      ENDIF

   ENDIF

   // Return formatted 3-element OS details array
   RETURN { cProd + cExtra, cVer, "Build " + cBuild }

/*-----------------------------------------------------------------------------*
   FUNCTION _Execute( hWnd, cOperation, cFile, cParameters, cDirectory, nState )

   Purpose:
      Provides a high-level HMG wrapper around the Windows ShellExecute API
      to launch external applications, open documents, or access URLs.

   Parameters:
      - hWnd        : Handle (HWND) - Parent window handle. Defaults to active window if NIL.
      - cOperation  : Character   - Action to perform ("open", "print", "explore", "runas").
      - cFile       : Character   - Target executable, document file, directory, or URL.
      - cParameters : Character   - Command-line arguments passed to executable.
      - cDirectory  : Character   - Default working directory for process.
      - nState      : Numeric     - Initial window display mode (e.g., SW_SHOWNORMAL, SW_HIDE).

   Returns:
      Numeric: Return status code from ShellExecute API (> 32 indicates success;
               <= 32 represents Win32 Shell error code).

   Side Effects:
      Launches external system processes or triggers default OS file/protocol handlers.
 *------------------------------------------------------------------------------*/
FUNCTION _Execute( hWnd , cOperation , cFile , cParameters , cDirectory , nState )
   // Default unassigned parameters and execute underlying Win32 ShellExecute API
   RETURN ShellExecute( hb_defaultValue( hWnd, GetActiveWindow() ), cOperation, ;
      hb_defaultValue( cFile, "" ), cParameters, cDirectory, hb_defaultValue( nState, SW_SHOWNORMAL ) )

/*-----------------------------------------------------------------------------*
   PROCEDURE ShellAbout( cTitle, cMsg, hIcon )

   Purpose:
      Displays the system modal Windows "About" dialog box while enforcing
      a re-entrancy guard to prevent multiple concurrent dialogs.

   Parameters:
      - cTitle : Character   - Caption for dialog title bar and application title.
      - cMsg   : Character   - Additional message content, copyright notice, or version info.
      - hIcon  : Handle      - Optional Win32 GDI icon handle to display in dialog.

   Returns:
      NIL

   Side Effects:
      - Displays a modal system dialog, halting user input to parent window until closed.
      - Mutates global static variable `_HMG_ShellAbout` to prevent redundant invocations.
      - Explicitly destroys `hIcon` GDI resource handle upon dialog exit to prevent leaks.
 *------------------------------------------------------------------------------*/
PROCEDURE ShellAbout( cTitle , cMsg , hIcon )
   LOCAL nCount

   // Initialize global tracking variable if not previously defined in HMG runtime environment
   IF _SetGetGlobal( "_HMG_ShellAbout" ) == NIL
      STATIC _HMG_ShellAbout AS GLOBAL VALUE 0
   ENDIF

   // Single-instance check: proceed only if no ShellAbout dialog is active
   IF ( nCount := _SetGetGlobal( "_HMG_ShellAbout" ) ) == 0

      // Lock global counter to prevent concurrent dialog displays
      ASSIGN GLOBAL _HMG_ShellAbout := ++nCount

      // Invoke Win32 ShellAbout C API wrapper
      IF C_ShellAbout( GetActiveWindow() , cTitle , cMsg , hIcon )
         
         // Destroy custom icon resource handle post-execution to avoid GDI memory leaks
         IF hIcon != NIL .AND. IsHIcon( hIcon )
            DestroyIcon ( hIcon )
         ENDIF
         
         // Release lock on global state variable after dialog terminates
         ASSIGN GLOBAL _HMG_ShellAbout := --nCount
      ENDIF

   ENDIF

RETURN