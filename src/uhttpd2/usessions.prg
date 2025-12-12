#include 'hbclass.ch'
#include 'common.ch'

STATIC nSessions_Executed := 1
STATIC hmtxSession

THREAD STATIC oSession 

// ---------------------------------------------------------------------- //

FUNCTION USessionValid()

   RETU ValType( oSession ) == 'O' .AND. oSession:ClassName() == 'USESSIONS'

// ---------------------------------------------------------------------- //

FUNCTION USessionStart()

   IF USessionValid()
      RETU .T.
   ENDIF

   oSession   := USessions():New()

   oSession:Init()

   RETU NIL

// ---------------------------------------------------------------------- //

FUNCTION USessionReady()

   LOCAL lValidate := .F.

   IF USessionValid()
      RETU .T.
   ENDIF

   oSession := USessions():New()

   lValidate := oSession:ReadCookie()

   IF ! lValidate
      oSession:End()
      oSession := NIL
   ENDIF

   RETU lValidate

// ---------------------------------------------------------------------- //

FUNCTION USessionEnd()

   LOCAL oServer

   IF USessionReady()
      oSession:End()
   ELSE

// If exist a cookie, we'll delete it

      oServer  := UGetServer()

      IF ! Empty( oServer:cSessionName )
         USetCookie( oServer:cSessionName, '', - 1 )
      ENDIF

   ENDIF

   oSession := NIL

   RETU NIL

// ---------------------------------------------------------------------- //

FUNCTION USessionWrite()

   IF USessionValid()
      oSession:Write()
   ENDIF

   RETU NIL

// ---------------------------------------------------------------------- //

FUNCTION USession( cKey, uValue )

   IF USessionValid()
      RETU oSession:Data( cKey, uValue )
   ENDIF

   RETU ''

// ---------------------------------------------------------------------- //

FUNCTION USessionAll()

   IF USessionValid()
      RETU oSession:AllData()
   ENDIF

   RETU NIL

// ---------------------------------------------------------------------- //

FUNCTION USessionEmpty()

   IF USessionValid()
      RETU Empty( oSession:AllData() )
   ENDIF

   UDo_Error( 'System Sessions not created!', NIL, 100 )

   RETU NIL

// ---------------------------------------------------------------------- //

FUNCTION UGetSession()

   LOCAL hInfo := { => }

   IF USessionValid()

      hInfo[ 'path' ]   := oSession:cPath
      hInfo[ 'name' ]   := oSession:cName
      hInfo[ 'prefix' ]   := oSession:cPrefix

// hInfo[ 'seed' ]   := oSession:cSeed

      hInfo[ 'duration' ]  := oSession:nDuration
      hInfo[ 'expired' ]  := oSession:hSession[ 'expired' ]    
      hInfo[ 'sid' ]   := oSession:hSession[ 'sid' ]
// hInfo[ 'sid' ]    := oSession:cSID
      hInfo[ 'garbage' ]   := oSession:nGarbage
      hInfo[ 'lifedays' ]  := oSession:nLifeDays
      hInfo[ 'crypt' ]   := oSession:lCrypt

   ENDIF

   RETU hInfo

// ---------------------------------------------------------------------- //

FUNCTION USessionDelete()

   oSession := NIL

   RETU NIL

// ---------------------------------------------------------------------- //


// ---------------------------------------------------------------------- //
// Sessions Class for UHttpd2
// ---------------------------------------------------------------------- //

CLASS USessions

   DATA cPath
   DATA cName
   DATA cPrefix
   DATA nDuration
   DATA nGarbage
   DATA nLifeDays
   DATA hSession      INIT { => }
   DATA cSID      INIT ''

   DATA cSeed
   DATA lCrypt      INIT .F.

   METHOD New()

   METHOD Init()
   METHOD InitData( cSID )

   METHOD ReadCookie()
   METHOD Validate()
   METHOD Write()
   METHOD Data( cKey, uValue )
   METHOD AllData()    INLINE if( hb_HHasKey( ::hSession, 'data' ), ::hSession[ 'data'   ], { => } )

   METHOD NewId()     INLINE hb_MD5( DToS( Date() ) + Time() + Str( hb_Random(), 15, 12 ) )
   METHOD SessionFile()   INLINE if( Empty( ::cSID ), '', ::cPath + '/' + ::cPrefix + ::cSID )

   METHOD Garbage()

   METHOD End()

ENDCLASS

// ---------------------------------------------------------------------- //

METHOD New() CLASS USessions

   LOCAL oServer  := UGetServer()

   ::cPath   := oServer:cSessionPath   // Default path session ./sessions
   ::cName   := oServer:cSessionName   // Default session name USESSID
   ::cPrefix   := oServer:cSessionPrefix   // Default prefix sess_
   ::cSeed   := oServer:cSessionSeed   // Password

   ::nDuration  := oServer:nSessionDuration  // Default duration session time 3600
   ::nGarbage  := oServer:nSessionGarbage  // Default totals sessions executed for garbage 1000
   ::nLifeDays  := oServer:nSessionLifeDays  // Default days stored for garbage 3
   ::lCrypt  := oServer:lSessionCrypt   // Default crypt session .F.
   ::cSID   := ''

   IF !hb_DirExists( ::cPath )
      hb_DirBuild( ::cPath )
   ENDIF

   IF hmtxSession == NIL
      hmtxSession := hb_mutexCreate()
   ENDIF

   RETU Self

// ---------------------------------------------------------------------- //

METHOD Init() CLASS USessions

   LOCAL lNew   := .T.
   LOCAL cFile

   ::cSID := UGetCookie( ::cName )

   IF ! Empty( ::cSID )

      cFile := ::cPath + '/' + ::cPrefix + ::cSID

      lNew := if( ::Validate(), .F., .T. )

      IF lNew  // Try to delte old session

         IF File( cFile )
            FErase( cFile )
         ENDIF

      ENDIF

   ENDIF

   IF lNew

      ::InitData()

   ENDIF

   RETU NIL

// ---------------------------------------------------------------------- //

METHOD ReadCookie() CLASS USessions

   ::cSID := UGetCookie( ::cName )

   IF Empty( ::cSID )
      RETU .F.
   ENDIF

   RETU ::Validate()

// ---------------------------------------------------------------------- //

METHOD Validate() CLASS USessions

   LOCAL lValidate := .F.
   LOCAL cFile, cSession

   cFile := ::SessionFile()

   IF ! File( cFile )
      RETU .F.
   ENDIF

   cSession := hb_base64Decode( hb_MemoRead( cFile ) )

   IF Empty( cSession )
      RETU .F.
   ENDIF

   IF ::lCrypt
      cSession := hb_blowfishDecrypt( hb_blowfishKey( ::cSeed ), cSession )
   ENDIF

   ::hSession := hb_Deserialize( cSession )

   IF ValType( ::hSession ) == 'H'

// Validaremos estructura


      IF (  hb_HHasKey( ::hSession, 'sid'   ) .AND. ;
            hb_HHasKey( ::hSession, 'expired' ) .AND. ;
            hb_HHasKey( ::hSession, 'data'  ) )                        
			   
         IF  ::hSession[ 'expired' ] >= Seconds() 

            lValidate  := .T.

         ENDIF

      ENDIF

   ENDIF

   RETU lValidate

// ---------------------------------------------------------------------- //

METHOD InitData( cSID ) CLASS USessions

   hb_default( @cSID, ::NewId() )

   ::hSession := { => }


   ::hSession[ 'sid'    ] := cSID
   ::hSession[ 'expired' ] := Seconds() + ::nDuration
   ::hSession[ 'data'   ] := { => }

   ::cSID := cSID

   RETU NIL

// ---------------------------------------------------------------------- //

METHOD End() CLASS USessions

   LOCAL cFile

   IF ! Empty( ::cName )
      USetCookie( ::cName, '', - 1 )
   ENDIF

   IF Empty( ::cSID )
      RETU .F.
   ENDIF

   cFile := ::SessionFile()


   IF File( cFile )
      FErase( cFile )
   ENDIF

   ::hSession   := { => }
   ::cSID   := ''
   ::cName   := ''

   RETU NIL

// ---------------------------------------------------------------------- //

METHOD Write() CLASS USessions

   LOCAL cData, cKey, lSave
   LOCAL lGarbage := .F.

   ::hSession[ 'expired' ]  := Seconds() + ::nDuration

   cData  := hb_Serialize( ::hSession )

   IF ::lCrypt
      cKey   := hb_blowfishKey( ::cSeed )
      cData   := hb_blowfishEncrypt( cKey, cData )
   ENDIF

   lSave := hb_MemoWrit( ::SessionFile(), hb_base64Encode( cData ) )



// GARBAGE

   hb_mutexLock( hmtxSession )

   nSessions_Executed++

   IF nSessions_Executed > ::nGarbage
      nSessions_Executed  := 0
      lGarbage    := .T.
   ENDIF

   hb_mutexUnlock( hmtxSession )

   IF lGarbage
      ::Garbage()
   ENDIF

// -------------------------

   USetCookie( ::cName, ::cSID, 0 ) // Session live like browser

   RETU NIL

// ---------------------------------------------------------------------- //

METHOD Garbage() CLASS USessions

   LOCAL aFiles  := Directory( ::cPath + '/*.*' )
   LOCAL nFiles  := Len( aFiles )
   LOCAL nSFiles  := 0
   LOCAL nSize  := 0
   LOCAL nTime  := hb_MilliSeconds()
   LOCAL nI, dMaxDate

   dMaxDate := Date() - ::nLifeDays

   _d( 'Init Garbage Procces! => ' + DToC( dMaxDate ) )

   FOR nI := 1 TO nFiles

      IF aFiles[ nI ][ 3 ] <= dMaxDate

         IF FErase( ::cPath + '/' + aFiles[ nI ][ 1 ] ) == 0
            nSFiles++
            nSize  += aFiles[ nI ][ 2 ]
         ENDIF

      ENDIF
   NEXT

   _d( '=====================================' )
   _d( 'Session files deleted: '   + LTrim( Str( nSFiles ) ) )
   _d( 'Session size deleted: '   + LTrim( Str( nSize ) ) + ' kb.' )
   _d( 'Time proccess for garbage: '  + LTrim( Str( hb_MilliSeconds() - nTime ) ) + ' ms.' )
   _d( '=====================================' )


   RETU NIL

// ---------------------------------------------------------------------- //

METHOD Data( cKey, uValue )  CLASS USessions

   hb_default( @cKey, '' )

   cKey := Lower( cKey )

   IF ValType( uValue ) <> 'U'   // SETTER

      IF !Empty( cKey )

         ::hSession[ 'data' ][ cKey ] := uValue

      ENDIF

   ELSE        // GETTER

      IF ( hb_HHasKey( ::hSession[ 'data' ], cKey  ) )
         RETU ::hSession[ 'data' ][ cKey ]
      ELSE
         RETU ''
      ENDIF

   ENDIF

   RETU NIL

// ---------------------------------------------------------------------- //
