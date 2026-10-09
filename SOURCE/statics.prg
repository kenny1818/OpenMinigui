/*
 * MINIGUI - Harbour Win32 GUI library source code
 *
 * Copyright 2021 Grigory Filatov <gfilatov@gmail.com>
 */

#include "minigui.ch"

#ifdef _NAMES_LIST_
/*-----------------------------------------------------------------------------*
 * FUNCTION _SetGetNamesList( cName, nIndex, lDelete )
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Manages an internal key-value collection of HMG Extended control names using
 *   a persistent dynamic data object dictionary.
 *
 * Parameters:
 *   cName   (C) Symbol name string to query, insert, or remove from registry.
 *   nIndex  (N) Associated numeric index or control identifier to register.
 *   lDelete (L) Flag indicating deletion action (.T. deletes key, .F. clears value).
 *
 * Return Value:
 *   (U) When PCount() == 1, returns the value stored for cName (0 if not found).
 *   (O) Otherwise, returns the internal static _HMG_NAMESLIST oHmgData object.
 *
 * Side Effects:
 *   Initializes and mutates static state variable _HMG_NAMESLIST.
 *-----------------------------------------------------------------------------*/
FUNCTION _SetGetNamesList( cName, nIndex, lDelete )
   STATIC _HMG_NAMESLIST

   // Lazy-initialize static dictionary object on first call
   IF HB_ISNIL( _HMG_NAMESLIST )
      _HMG_NAMESLIST := oHmgData()
   ENDIF

   IF PCount() == 1

      // Getter mode: Retrieve stored numeric ID associated with name key
      RETURN _HMG_NAMESLIST:Get( cName, 0 )

   ELSEIF PCount() == 2

      // Setter mode: Map control name key to numeric index
      _HMG_NAMESLIST:Set( cName, nIndex )

   ELSEIF PCount() == 3

      // Deletion mode: Conditionally remove key or clear payload to NIL
      IF lDelete
         _HMG_NAMESLIST:Del( cName )
      ELSE
         _HMG_NAMESLIST:Set( cName, NIL )
      ENDIF

   ENDIF 

RETURN _HMG_NAMESLIST

#endif

/*-----------------------------------------------------------------------------*
 * FUNCTION _SetGetGlobal( cVarName, xNewValue, ... )
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Provides dynamic runtime access to application-wide pseudo-global variables
 *   encapsulated within a persistent static data dictionary.
 *
 * Parameters:
 *   cVarName  (C) Variable identifier string to access, modify, or remove.
 *   xNewValue (U) New value payload to store in pseudo-global space.
 *   ...       (U) Variadic arguments parameter list (for compiler portability).
 *
 * Return Value:
 *   (U) PCount() == 0: Returns the internal static container instance (_HMG_STATIC).
 *   (U) PCount() == 1: Returns current variable value stored under cVarName (NIL if missing).
 *   (U) PCount() >= 2: Returns the previous value stored prior to modification.
 *
 * Side Effects:
 *   Mutates internal static state variable _HMG_STATIC.
 *-----------------------------------------------------------------------------*/
#ifndef __XHARBOUR__
FUNCTION _SetGetGlobal( cVarName, xNewValue, ... )
#else
FUNCTION _SetGetGlobal( ... )
#endif
   LOCAL xOldValue

#ifdef __XHARBOUR__
   // Unpack variadic parameter list under xHarbour compiler architecture
   LOCAL cVarName, xNewValue
   LOCAL aParams := hb_AParams()
   LOCAL nParams := Len( aParams )
#endif

   STATIC _HMG_STATIC

#ifdef __XHARBOUR__
   // Extract target variable name and value from xHarbour parameter array
   IF nParams > 1
      cVarName := aParams[ 1 ]
      xNewValue := aParams[ 2 ]
   ELSEIF nParams == 1
      cVarName := aParams[ 1 ]
   ENDIF
#endif
   // Lazy-initialize dynamic memory object container
   IF HB_ISNIL( _HMG_STATIC )
      _HMG_STATIC := oHmgData()
   ENDIF

   // Perform operational action based on passed argument count
   SWITCH PCount()
   CASE 0
      // Return container instance reference
      RETURN _HMG_STATIC
   CASE 1
      // Retrieve stored global value (or NIL if undefined)
      RETURN _HMG_STATIC:Get( cVarName, NIL )
   CASE 2
      // Save current value and assign new value
      xOldValue := _HMG_STATIC:Get( cVarName, NIL )
      _HMG_STATIC:Set( cVarName, xNewValue )
      EXIT
   CASE 3
      // Remove named pseudo-global entry from dictionary
      _HMG_STATIC:Del( cVarName )
      EXIT
   ENDSWITCH

RETURN xOldValue

/*-----------------------------------------------------------------------------*
 * FUNCTION _AddNewGlobal( cVarName, xValue )
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Dynamically registers a new pseudo-global variable in application scope if
 *   it has not already been created in the dynamic global container.
 *
 * Parameters:
 *   cVarName (C) Symbol identifier of the new global variable to register.
 *   xValue   (U) Initial value assignment for the variable.
 *
 * Return Value:
 *   (U) Value of the variable retrieved from _SetGetGlobal().
 *
 * Side Effects:
 *   Executes dynamic macro compilation statement registering static variable scope.
 *-----------------------------------------------------------------------------*/
FUNCTION _AddNewGlobal( cVarName, xValue )
   // Verify whether specified global symbol already exists in runtime memory
   IF _SetGetGlobal( cVarName ) == NIL
      // Macro-expand dynamic static variable declaration into static scope
      STATIC &cVarName AS GLOBAL VALUE xValue
   ENDIF

RETURN _SetGetGlobal( cVarName )

/*-----------------------------------------------------------------------------*
 * FUNCTION CheckStatic()
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Diagnostic utility that inspects all active HVM static variable slots and
 *   outputs their structure and values to a text log file ("checkstatic.txt").
 *
 * Parameters:
 *   None
 *
 * Return Value:
 *   (U) NIL
 *
 * Side Effects:
 *   Creates or overwrites log file "checkstatic.txt" in startup directory.
 *   Iterates through low-level Harbour Virtual Machine static variable table.
 *-----------------------------------------------------------------------------*/
FUNCTION CheckStatic()
   LOCAL cInfo := ""
   LOCAL nCnt := 0
   LOCAL n

   // Initialize log file target path in current startup folder
   _SetGetLogFile( GetStartUpFolder() + hb_ps() + "checkstatic.txt" )
   FErase( _SetGetLogFile() )

   // Write diagnostic report header block
   cInfo += "Statics variables:" + CRLF
   cInfo += "=================="
   _LogFile( .F., cInfo )

   // Scan active static slots exposed by Harbour Virtual Machine debug interface
   FOR n = 1 TO nStatics()
      if ! Empty( Static( n ) )
         cInfo := CRLF
         cInfo += hb_ntos( n ) + Replicate( "-", 55 ) + "> "
         _LogFile( .F., cInfo )
         // Recursively inspect elements contained in active static variable
         Scan( Static( n ) )
         nCnt++
      ENDIF
   NEXT

   // Format summary footer output with total active count and binary path
   cInfo := CRLF
   cInfo += Replicate( "-", 59 ) + "> "
   _LogFile( .F., cInfo )

   _LogFile( .T., "Amount = " + hb_ntos( nCnt ) )
   _LogFile( .T., Replicate( "=", 60 ) )
   _LogFile( .T., GetExeFileName() )

RETURN NIL

/*-----------------------------------------------------------------------------*
 * STATIC FUNCTION Scan( u, cData )
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Recursively traverses variable contents (primitives, arrays, objects) and
 *   writes type descriptions and values to the diagnostic log file.
 *
 * Parameters:
 *   u     (U) Variable instance or element to inspect and format.
 *   cData (C) Optional prefix string describing context/label (default: "").
 *
 * Return Value:
 *   (U) NIL
 *
 * Side Effects:
 *   Outputs diagnostic strings to log file via _LogFile().
 *   Calls DoEvents() to pump Win32 message queue during deep traversal.
 *-----------------------------------------------------------------------------*/
STATIC FUNCTION Scan( u, cData )
   LOCAL cType := ValType( u )
   LOCAL n
   LOCAL cInfo := ""

   STATIC nNested := 0

   DEFAULT cData := ""

   // Process pending GUI events to maintain UI responsiveness during inspection
   DoEvents()

   // Abort deep recursion to prevent application stack overflow
   IF nNested > 50
      cInfo += CRLF
      cInfo += Space( nNested ) + "Break on 50 nested loops"
      cInfo += CRLF
      _LogFile( .T., cInfo )
   ELSE
      // Log data type character and contextual description tag
      _LogFile( .F., CRLF + Space( nNested ) + cType + " " + cData )
      // Output scalar variable values directly
      IF .NOT. cType $ "UAO"
         _LogFile( .F., " " + cValToChar( u ) )
      ENDIF

      // Output size metadata for composite structures (Arrays/Objects)
      IF cType $ "AO"
         _LogFile( .F., " (Len = " + hb_ntos( Len( u ) ) + ")" )
      ENDIF

      // Traversal logic for array structures
      IF cType == "A"

         FOR n := 1 TO Len( u )

            DoEvents()

            // Guard against circular self-references within arrays
            IF ValType( u[ n ] ) == ValType( u ) .AND. u[ n ] == u
               _LogFile( .T., " Direct reference to its container" )
            ELSE
               nNested++
               Scan( u[ n ], cData )
               nNested--
            ENDIF

         NEXT n

      ENDIF

   ENDIF

RETURN NIL

// Map low-level HVM VM variable debug functions for non-xHarbour environment
#ifndef __XHARBOUR__
#translate HB_DBG_VMVARSLEN   =>  __dbgVMVarSLen
#translate HB_DBG_VMVARSLIST  =>  __dbgVMVarSList
#translate HB_DBG_VMVARSGET   =>  __dbgVMVarSGet
#endif

/*-----------------------------------------------------------------------------*
 * STATIC FUNCTION nStatics()
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Queries the Harbour Virtual Machine debug API to get total static variable count.
 *
 * Parameters:
 *   None
 *
 * Return Value:
 *   (N) Total number of static variable slots allocated in the current HVM state.
 *
 * Side Effects:
 *   Reads internal HVM execution engine state.
 *-----------------------------------------------------------------------------*/
STATIC FUNCTION nStatics()

RETURN HB_DBG_VMVARSLEN()

/*-----------------------------------------------------------------------------*
 * STATIC FUNCTION Static( n )
 *-----------------------------------------------------------------------------*
 * Purpose:
 *   Accesses a specific static variable slot in the Harbour VM static memory table.
 *
 * Parameters:
 *   n (N) 1-based index of the static variable entry to retrieve.
 *
 * Return Value:
 *   (U) Value contained within the target static variable slot.
 *
 * Side Effects:
 *   Reads internal HVM execution engine state.
 *-----------------------------------------------------------------------------*/
STATIC FUNCTION Static( n )

RETURN HB_DBG_VMVARSGET( HB_DBG_VMVARSLIST(), n )