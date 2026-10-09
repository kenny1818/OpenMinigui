/*
 * MINIGUI - Harbour Win32 GUI library source code
 *
 */

#include "minigui.ch"
#include "dbinfo.ch"
#include "error.ch"

// Locking strategy constant definitions for RDD operations
#define NET_LOCK_RECORD  1
#define NET_LOCK_FILE    2
#define NET_LOCK_APPEND  3

STATIC nNetDelay := 1  // Default timeout interval in seconds for locking attempts
STATIC lNetOk := .F.   // Global success status flag for the most recent network operation

/*
 * Routine: NetLock
 *
 * Purpose:
 *   Attempts to acquire or release a database network lock (record lock, file lock,
 *   or append record) using an automated retry loop until success or timeout.
 *
 * Parameters:
 *   nLockingType  (NUMERIC) - Lock mode constant (NET_LOCK_RECORD, NET_LOCK_FILE, or NET_LOCK_APPEND).
 *   lReleaseLocks (LOGICAL) - Optional. Defaults to .F.
 *                            For NET_LOCK_RECORD: when .T., passes NIL to clear single record targeting.
 *                            For NET_LOCK_APPEND: controls unlock flag parameter passed to dbAppend().
 *   nTimeout      (NUMERIC) - Optional. Maximum retry duration in seconds. Defaults to nNetDelay.
 *
 * Return Value:
 *   LOGICAL - Returns .T. if lock operation succeeded within timeout period, .F. otherwise.
 *
 * Side Effects:
 *   - Modifies static state variable 'lNetOk' to indicate operation outcome.
 *   - Calls RDD functions dbRLock(), FLock(), or dbAppend().
 *   - Calls HMG_SysWait() during retries, yielding CPU time to system message loop.
 */
STATIC FUNCTION NetLock( nLockingType, lReleaseLocks, nTimeout )

   LOCAL lSuccess := .F.
   LOCAL bLockOperation  // Evaluation codeblock executing the RDD lock/append call
   LOCAL xLockIdentifier // Identifier/flag passed to lock execution codeblock
   LOCAL nStartTime   // Start timestamp in seconds for elapsed timeout tracking

   DEFAULT lReleaseLocks TO .F.
   DEFAULT nTimeout TO nNetDelay

   nStartTime := Seconds() // Store start timestamp for elapsed time calculation

   DO CASE
   CASE nLockingType == NET_LOCK_RECORD
      // Set target record number or pass NIL for unconstrained lock evaluation
      xLockIdentifier := iif( lReleaseLocks, NIL, RecNo() )
      bLockOperation := {| x | dbRLock( x ) }
   CASE nLockingType == NET_LOCK_FILE
      // Execute full table lock on active workarea
      bLockOperation := {|| FLock() }
   CASE nLockingType == NET_LOCK_APPEND
      // Perform record append and evaluate RDD network status
      xLockIdentifier := lReleaseLocks
      bLockOperation := {| x | dbAppend( x ), ! NetErr() }
   OTHERWISE
      // Fail immediately if lock type constant is unhandled
      RETURN .F.
   ENDCASE

   // Poll lock execution until lock succeeds or timeout period expires
   WHILE ( Seconds() - nStartTime ) < nTimeout

      IF Eval( bLockOperation, xLockIdentifier )
         lSuccess := .T.
         EXIT
      ELSE
         // Pause execution briefly to reduce CPU load and process GUI events
         HMG_SysWait( .25 )
      ENDIF

   ENDDO

   lNetOk := lSuccess // Store operation result for NetError() queries

RETURN lSuccess

/*
 * Routine: NetModifyRecord
 *
 * Purpose:
 *   Encapsulates database record updates (such as record deletion or recall) within a
 *   network-safe record lock context, ensuring error verification and commit flushing.
 *
 * Parameters:
 *   bOperation     (CODEBLOCK) - Database operation block to execute once lock is held.
 *   cOperationName (CHARACTER) - Descriptive name of the operation used in user alerts upon failure.
 *
 * Return Value:
 *   LOGICAL - Returns .T. if record lock was secured and modification succeeded, .F. otherwise.
 *
 * Side Effects:
 *   - Secures record lock on active workarea.
 *   - Calls dbSkip(0) and dbCommit() to flush database buffers to disk.
 *   - Displays an HMG_Alert dialog box if an RDD network error occurs.
 */
STATIC FUNCTION NetModifyRecord( bOperation, cOperationName )

   LOCAL lSuccess := .F.

   // Attempt record lock acquisition before executing modification codeblock
   IF NetLock( NET_LOCK_RECORD )
      Eval( bOperation )
      lSuccess := .T.
   ENDIF

   // Verify network integrity before committing changes to physical storage
   IF ! NetErr()
      dbSkip( 0 ) // Flush current workarea record buffer
      dbCommit()  // Write buffer updates to disk
   ELSE
      // Display modal alert dialog informing user of failure
      HMG_Alert( "Failed to " + cOperationName + " Record -> " + hb_ntos( RecNo() ) )
   ENDIF

RETURN lSuccess

/*
 * Routine: NetDelete
 *
 * Purpose:
 *   Deletes the current database record safely in a multi-user network environment.
 *
 * Parameters:
 *   None
 *
 * Return Value:
 *   LOGICAL - Returns .T. if record was successfully locked and marked for deletion, .F. otherwise.
 *
 * Side Effects:
 *   - Locks active record, calls dbDelete(), and flushes changes to disk.
 *   - Displays alert message if a network error is detected.
 */
FUNCTION NetDelete()

RETURN NetModifyRecord( {|| dbDelete() }, "DELETE" )

/*
 * Routine: NetRecall
 *
 * Purpose:
 *   Recalls (un-deletes) the current database record safely in a multi-user network environment.
 *
 * Parameters:
 *   None
 *
 * Return Value:
 *   LOGICAL - Returns .T. if record was successfully locked and recalled, .F. otherwise.
 *
 * Side Effects:
 *   - Locks active record, calls dbRecall(), and flushes changes to disk.
 *   - Displays alert message if a network error is detected.
 */
FUNCTION NetRecall()

RETURN NetModifyRecord( {|| dbRecall() }, "RECALL" )

/*
 * Routine: NetRecLock
 *
 * Purpose:
 *   Acquires a record lock on the current database record with timeout handling.
 *
 * Parameters:
 *   nTimeout (NUMERIC) - Optional. Maximum wait duration in seconds. Defaults to nNetDelay.
 *
 * Return Value:
 *   LOGICAL - Returns .T. if record lock was granted within timeout, .F. otherwise.
 *
 * Side Effects:
 *   - Modifies static state variable 'lNetOk'.
 *   - Applies record lock on active database workarea via dbRLock().
 */
FUNCTION NetRecLock( nTimeout )

   DEFAULT nTimeout TO nNetDelay

RETURN NetLock( NET_LOCK_RECORD, , nTimeout )

/*
 * Routine: NetFileLock
 *
 * Purpose:
 *   Acquires an exclusive file lock on the active database table with timeout handling.
 *
 * Parameters:
 *   nTimeout (NUMERIC) - Optional. Maximum wait duration in seconds. Defaults to nNetDelay.
 *
 * Return Value:
 *   LOGICAL - Returns .T. if file lock was granted within timeout, .F. otherwise.
 *
 * Side Effects:
 *   - Modifies static state variable 'lNetOk'.
 *   - Locks active database table via FLock().
 */
FUNCTION NetFileLock( nTimeout )

   DEFAULT nTimeout TO nNetDelay

RETURN NetLock( NET_LOCK_FILE, , nTimeout )

/*
 * Routine: NetAppend
 *
 * Purpose:
 *   Appends a new blank record to the current database table in a network-safe manner.
 *
 * Parameters:
 *   nTimeout      (NUMERIC) - Optional. Maximum wait duration in seconds. Defaults to nNetDelay.
 *   lReleaseLocks (LOGICAL) - Optional. Defaults to .T.
 *                            If .T., unlocks existing locks during append.
 *                            If .F., retains existing locks during append.
 *
 * Return Value:
 *   LOGICAL - Returns .T. if record append succeeded within timeout, .F. otherwise.
 *
 * Side Effects:
 *   - Temporarily sets index controlling order to 0 during append to avoid key collision overhead,
 *     restoring original index order afterwards.
 *   - Modifies static state variable 'lNetOk'.
 *   - Modifies database workarea state via dbAppend().
 */
FUNCTION NetAppend( nTimeout, lReleaseLocks )

   LOCAL cOrd
   LOCAL lSuccess

   DEFAULT nTimeout TO nNetDelay
   DEFAULT lReleaseLocks TO .T.

   // Temporarily clear controlling index order to optimize append performance
   cOrd := ordSetFocus( 0 )

   lSuccess := NetLock( NET_LOCK_APPEND, lReleaseLocks, nTimeout )

   // Restore controlling index order if one was previously active
   IF ! Empty( cOrd )
      ordSetFocus( cOrd )
   ENDIF

RETURN lSuccess

/*
 * Routine: IsLocked
 *
 * Purpose:
 *   Determines whether a specific record (or current record) is locked in active workarea.
 *
 * Parameters:
 *   nRecId (NUMERIC) - Optional. Record number to inspect. Defaults to RecNo().
 *
 * Return Value:
 *   LOGICAL - Returns .T. if record is present in active workarea lock list, .F. otherwise.
 *
 * Side Effects:
 *   None.
 */
FUNCTION IsLocked( nRecId )

   DEFAULT nRecID TO RecNo()

// Search active record lock list array retrieved from database driver
RETURN AScan( dbRLockList(), {| n | n == nRecID } ) > 0

/*
 * Routine: NetError
 *
 * Purpose:
 *   Queries the failure status of the most recent network locking or append operation.
 *
 * Parameters:
 *   None
 *
 * Return Value:
 *   LOGICAL - Returns .T. if last network operation failed, .F. if it succeeded.
 *
 * Side Effects:
 *   None.
 */
FUNCTION NetError()

RETURN ! lNetOk

/*
 * Routine: SetNetDelay
 *
 * Purpose:
 *   Configures or queries default network locking retry delay duration.
 *
 * Parameters:
 *   nSeconds (NUMERIC) - Optional. New delay duration in seconds. If omitted, value is unchanged.
 *
 * Return Value:
 *   NUMERIC - Returns previous network delay duration setting in seconds.
 *
 * Side Effects:
 *   - Updates static variable 'nNetDelay' when nSeconds is supplied.
 */
FUNCTION SetNetDelay( nSeconds )

   LOCAL nOldDelay := nNetDelay

   // Assign new timeout value if argument was passed
   IF nSeconds != NIL
      nNetDelay := nSeconds
   ENDIF

RETURN nOldDelay