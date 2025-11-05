/*
 * HTTPD2
 *
 * Copyright 2007 Mindaugas Kavaliauskas <dbtopas at dbtopas.lt>
 * Adapted 2022-2025 Carles Aubia <carles9000 at gmail.com> for UT Project
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file LICENSE.txt.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA (or visit https://www.gnu.org/licenses/).
 *
 * As a special exception, the Harbour Project gives permission for
 * additional uses of the text contained in its release of Harbour.
 *
 * The exception is that, if you link the Harbour libraries with other
 * files to produce an executable, this does not by itself cause the
 * resulting executable to be covered by the GNU General Public License.
 * Your use of that executable is in no way restricted on account of
 * linking the Harbour library code into it.
 *
 * This exception does not however invalidate any other reasons why
 * the executable file might be covered by the GNU General Public License.
 *
 * This exception applies only to the code released by the Harbour
 * Project under the name Harbour.  If you copy code from other
 * Harbour Project or Free Software Foundation releases into a copy of
 * Harbour, as the General Public License permits, the exception does
 * not apply to the code that you add in this way.  To avoid misleading
 * anyone as to the status of such modified files, you must delete
 * this exception notice from them.
 *
 * If you write modifications of your own for Harbour, it is your choice
 * whether to permit this exception to apply to your modifications.
 * If you do not wish that, delete this exception notice.
 *
 */
REQUEST hb_threadId
REQUEST __vmCountThreads

#include "hbclass.ch"
#include "common.ch"
#include "fileio.ch"
#include "error.ch"
#include "hbsocket.ch"
#include "hbthread.ch"

#ifndef NO_SSL
#include "hbssl.ch"
#endif

#pragma -kM+

/*
  Docs:

  RFC 1945 - Hypertext Transfer Protocol -- HTTP/1.0
  RFC 2616 - Hypertext Transfer Protocol -- HTTP/1.1
  HTTP Made Really Easy (http://www.jmarshall.com/easy/http/)
*/

#define HTTPD2_VERSION     '2.4a'

#define THREAD_COUNT_PREALLOC     10
#define THREAD_COUNT_MAX         200
#define TIME_KEEP_ALIVE          60

#define SESSION_NAME      'USESSID'
#define SESSION_PREFIX     'sess_'
#define SESSION_DURATION    3600

#define CR_LF                       (CHR(13)+CHR(10))

#xcommand TEXT <into:TO,INTO> <v> => #pragma __cstream|<v>+=%s


// _d esta definit al meu modul...
// #xcommand ? [<explist,...>] => _d( [,<explist>] )
// #xcommand ? [<explist,...>] => if( lDebug, _d( [,<explist>] ), nil )
// --------------------------------

// No debug
// #xtranslate QOUT([<x,...>]) =>

STATIC oServer
STATIC hCfg
STATIC nFiles_Size := 0

// THREAD STATIC s_aSessionData
THREAD STATIC s_cResult, s_nStatusCode, s_aHeader
THREAD STATIC cProcError
THREAD STATIC cFilePrg, cFileHtml


// THREAD STATIC s_oSession

MEMVAR server, GET, post, files, cookie, session, httpd

FUNCTION Httpd2()

   oServer := UHttpd2():New()

   RETURN oServer

FUNCTION UHttpd2New()

   oServer := UHttpd2():New()

   RETURN oServer

FUNCTION UVersion() ; RETURN HTTPD2_VERSION

CLASS UHttpd2 MODULE FRIENDLY

   EXPORTED:
   METHOD New()        CONSTRUCTOR
   METHOD Run( aConfig )
   METHOD Stop()

   METHOD SetPort( nPort )  INLINE ::aConfig[ 'Port' ] := if( ValType( nPort ) == 'N', nPort, 80 )
   METHOD SetSSL( lSSL )  INLINE ::aConfig[ 'SSL' ] := if( ValType( lSSL ) == 'L', lSSL, .F. )
   METHOD Route( cRoute, bAction, cMethod )
   METHOD RouteDelete( cRoute )
   METHOD SetDirFiles( cRoute )
   METHOD SetTrace()
   METHOD SetFolderPublic( cFolder )
   METHOD SetCertificate( PrivateKeyFilename, CertificateFilename )
   METHOD SetErrorStatus( nStatus, cPage, cAjax )
   METHOD SetFirewallFilter( uIPs, cFirewallType )
   


   METHOD Statistics()
   METHOD SetInfo( cKey, uValue )

   METHOD Dbg( ... )        INLINE if( ::lDebug, _d( ... ), NIL )
   METHOD Time()        INLINE Time()
   METHOD IsInit()        INLINE ::lInit



   DATA  cError             INIT ""
   DATA  cPathHtml           INIT ""
   DATA  cPathLog            INIT ""
   DATA  cPathTmp       INIT ""

   DATA  nTime_Keep_Alive     INIT TIME_KEEP_ALIVE

   // Sessions
   DATA  cSessionPath        INIT ""
   DATA  cSessionName        INIT SESSION_NAME
   DATA  cSessionPrefix      INIT SESSION_PREFIX
   DATA  cSessionSeed        INIT 'UhHttPPd2@2022!'
   DATA  nSessionDuration       INIT SESSION_DURATION
   DATA  nSessionLifeDays     	INIT 3
   DATA  nSessionGarbage     	INIT 1000
   DATA  lSessionCrypt      	INIT .F.
   DATA  lTrace      			INIT .F.



   // Files Upload
   DATA  nfiles_size_garbage_inspector  INIT 2000000 // kb.
   DATA  nfiles_lifeDays     INIT 1
   DATA  nfile_max_size      INIT 100000  // kb.
   DATA  aFilesAllowed      INIT {}


   DATA  bInit
   DATA  lDebug         INIT .F.
   DATA  lDbfAutoClose      INIT .T.

   DATA  lUtf8        INIT .F.

   DATA  bRX         INIT {|| 'RX not exist' }
   DATA  bPostRun
   DATA  aInfo        INIT { => }
   DATA lInit       INIT .F.





   HIDDEN:
   DATA aConfig     INIT { => }
   DATA aErrorRoutes    INIT {}

   DATA aFirewallFilter

   DATA hAccessLog
   DATA hErrorLog
   DATA hReq
   // DATA hSession


   DATA hmtxQueue
   DATA hmtxLog
   DATA hmtxSession  // Necesary?
   DATA hmtxReq
   DATA hmtxFiles

   DATA hListen
   DATA hSSLCtx
// DATA aSession

   DATA lStop
   DATA lFirewallType 			INIT 'blacklist'	//	'whitelist'

   METHOD LogAccess()
   METHOD LogError( cError )

ENDCLASS




METHOD New() CLASS UHttpd2

   ::aConfig := { "SSL"                  => .F., ;
      "Port"                 => 80, ;
      "BindAddress"          => "0.0.0.0", ;
      "AccessLogFilename"    => "access.log", ;
      "ErrorLogFilename"     => "error.log", ;
      "ErrorBloc"            => {|| NIL }, ;
      "Idle"                 => {|| NIL }, ;
      "Mount"                => { => }, ;
      "ErrorStatus"          => {}, ;
      "PrivateKeyFilename"   => "", ;
      "CertificateFilename"  => "", ;
      "FirewallFilter"    => "" ;   // "192.168.0.0/16";  //  "FirewallFilter"       => "0.0.0.0/0" ;
      }

   ::aConfig[ 'Mount' ][ '/api' ]  := { 'action' => {| hSrv | UWebApi( hSrv, self ) }, 'method' => 'POST', 'regexp' => NIL, 'cargo' => '' }
   ::aConfig[ 'Mount' ][ '/files/*' ] := { 'action' => {| hSrv | UProcFiles( hb_DirBase() + "/files/" + hSrv[ 'path' ], .F. ) }, 'method' => 'GET,POST,PUT,DELETE,OPTIONS', 'regexp' => NIL, 'cargo' => '' }



   ::cPathHtml  := hb_DirBase() + 'html'
   ::cPathLog   := hb_DirBase() + '.log'
   ::cSessionPath := hb_DirBase() + '.sessions'
   ::cPathTmp  := hb_DirBase() + '.tmp'

   ::bInit   := {|| QOut( 'HTTPD2 Vrs. ' +  HTTPD2_VERSION + ' - ' + hb_Compiler() + CR_LF + 'Escape for exit...' ) }

   s_cResult := ''

   cFilePrg := ''

   RETU SELF

METHOD SetDirFiles( cRoute, lIndex ) CLASS UHttpd2

   hb_default( @cRoute, '' )
   hb_default( @lIndex, .F. )

   IF Empty( cRoute )
      RETU NIL
   ENDIF

   IF SubStr( cRoute, 1, 1 ) != '/'
      cRoute := '/' + cRoute
   ENDIF

   ::aConfig[ 'Mount' ][ cRoute + '/*' ] := { 'action' => {| hSrv | UProcFiles( hb_DirBase() + cRoute + "/" + hSrv[ 'path' ], lIndex ) }, 'method' => 'GET,POST,PUT,DELETE,OPTIONS', 'regexp' => NIL, 'cargo' => ''  }

   RETU cRoute

METHOD SetCertificate( PrivateKeyFilename, CertificateFilename ) CLASS UHttpd2

   hb_default( @PrivateKeyFilename, '' )
   hb_default( @CertificateFilename, '' )

   ::aConfig[ 'PrivateKeyFilename' ]  := PrivateKeyFilename
   ::aConfig[ 'CertificateFilename' ]  := CertificateFilename

   RETU NIL
   
METHOD SetFirewallFilter( uFilter, cFirewallType ) CLASS UHttpd2

   LOCAL cIps := ''
   LOCAL nLen, nI   
   
   hb_default( @cFirewallType, 'blacklist' )
   
   cFirewallType := lower( cFirewallType )
   
   IF cFirewallType == 'blacklist' .OR. cFirewallType == 'whitelist'
	  ::lFirewallType := lower( cFirewallType )
   ENDIF
   
   DO CASE 
   
      CASE Valtype( uFilter ) == 'C' 
	  
  	    ::aConfig[ 'FirewallFilter' ]  := uFilter
		
      CASE Valtype( uFilter ) == 'A' 
	  
		nLen := len( uFilter ) - 1
		
		FOR nI := 1 TO nLen 
			cIps += uFilter[ nI ] + ' ' 
		NEXT
		
		cIps += uFilter[ nI ]

		::aConfig[ 'FirewallFilter' ]  := cIps
   ENDCASE               
   
   RETU NIL 

METHOD SetErrorStatus( nStatus, cPage, cAjax ) CLASS UHttpd2

   hb_default( @nStatus, 0 )  // 404
   hb_default( @cPage, '' )  // error/404.html
   hb_default( @cAjax, '' )  // 'page not found !'

   AAdd( ::aConfig[ 'ErrorStatus' ], { 'status' => nStatus, 'page' => cPage, 'ajax' => cAjax } )

   RETU NIL

METHOD Route( cRoute, bAction, cMethod, uCargo ) CLASS UHttpd2

   LOCAL cHtml, cExt, pRoute

   hb_default( @cRoute, '' )
   hb_default( @cMethod, 'GET,POST,PUT,DELETE,OPTIONS' )
   hb_default( @uCargo, '' )

   IF At( 'OPTIONS', cMethod ) == 0
      cMethod += ',OPTIONS'
   ENDIF

   IF Empty( cRoute )
      RETU NIL
   ENDIF

// Valid route
  /* Bug
   '^' --> Init string
   '$' --> End string

   if not specify '^' expresion regular is true for example with 'wndhello' and 'hello'
  */

   pRoute := hb_regexComp( '^' + cRoute + '$' )

   IF pRoute == NIL
      AAdd( ::aErrorRoutes, cRoute )
      RETURN NIL
   ENDIF

// -----------------------------

   IF ValType( bAction ) == 'C'

      cHtml  := bAction
      cExt  := Lower( hb_FNameExt( cHtml ) )

      DO CASE
      CASE cExt == '.html' .OR. cExt == '.htm'

         bAction := {| hSrv | ULoadPage( hSrv, cHtml ) }

      CASE cExt == '.prg'

         bAction := {| hSrv | ULoadPrg( hSrv, cHtml ) }

      CASE cExt == '.rx'

         uCargo  := cHtml
         bAction := ::bRX

//
// if hb_isfunction( 'rx_testcode' )
// bAction := &( "{|o,oSrv| rx_testcode(o,oSrv) }" )
// endif

      CASE cExt == ''

         IF hb_IsFunction( cHtml )

            bAction := &( "{|o,oSrv| " + cHtml + "(o,oSrv) }" )

         ELSE

// For example if you define Route( 'examples' , 'examples/*' )
// Objetivo, listar indice del directorio

            IF SubStr( cHtml, Len( cHtml ), 1 ) == '*'
               bAction := {|| URedirect( cHtml ) }
            ELSE
               bAction := {|| UDo_Error( "Api function doesn't exist. => " + cHtml, NIL, 100 ) }
            ENDIF

         ENDIF

      ENDCASE

   ELSEIF ValType( bAction ) == 'B'
// at moment nothing....
   ELSE
      RETU NIL
   ENDIF

   IF !( cRoute == '/' )
      IF SubStr( cRoute, 1, 1 ) != '/'
         cRoute := '/' + cRoute
      ENDIF
   ENDIF

   ::aConfig[ 'Mount' ][ cRoute ] := { 'action' => bAction, 'method' => cMethod, 'regexp' => pRoute, 'cargo' => uCargo }

   RETU NIL

METHOD RouteDelete( cRoute ) CLASS UHttpd2

   hb_default( @cRoute, '' )

   IF !Empty( cRoute )

      cRoute := '/' + cRoute

      IF hb_HHasKey( ::aConfig[ 'Mount' ], cRoute )

         hb_HDel( ::aConfig[ 'Mount' ], cRoute )
      ENDIF

   ENDIF

   RETU NIL

METHOD SetInfo( cKey, uValue ) CLASS UHttpd2

   WHILE ! ::lInit
      hb_idleSleep( 0.1 )
   END

   ::aInfo[ cKey ] := uValue

   RETU NIL

METHOD Run( aConfig ) CLASS UHttpd2

   LOCAL hSocket, nI, aI, xValue, aThreads, nJobs, nWorkers
   

   hb_default( @aConfig, {=>} )

   IF ! hb_mtvm()
      Self:cError := "Multithread support required"
      RETURN .F.
   ENDIF

   IF Len( ::aErrorRoutes ) > 0
      _t( 'Warning: Error config routes' )
      FOR nI := 1 TO Len( ::aErrorRoutes )
         _t( '  => ' + ::aErrorRoutes[ nI ] )
      NEXT
      _t( '----------------------------' )
   ENDIF

   IF !hb_DirExists( ::cPathHtml )
      hb_DirBuild( ::cPathHtml )
   ENDIF

   IF !hb_DirExists( ::cPathLog )
      hb_DirBuild( ::cPathLog )
   ENDIF
   
   IF hb_DirExists( ::cPathTmp )
	  UFilesTmpCollector( .T. )  // Del temporally files...
   ENDIF


   FOR EACH xValue IN aConfig
      IF ! hb_HHasKey( Self:aConfig, xValue:__enumKey ) .OR. ValType( xValue ) != ValType( Self:aConfig[ xValue:__enumKey ] )
         Self:cError := "Invalid config option '" + xValue:__enumKey + "'"
         RETURN .F.
      ENDIF
      Self:aConfig[ xValue:__enumKey ] := xValue
   NEXT

   IF Self:aConfig[ "SSL" ]
#ifndef NO_SSL

      IF ! File( Self:aConfig[ "PrivateKeyFilename" ] )
         Self:cError := "Certificate - Privetekey is missing !"
         _t( Self:cError )
         RETURN .F.
      ENDIF

      IF ! File( Self:aConfig[ "CertificateFilename" ] )
         Self:cError := "Certificate is missing !"
         _t( Self:cError )
         RETURN .F.
      ENDIF



      SSL_INIT()
      DO WHILE RAND_STATUS() != 1
         RAND_add( Str( hb_Random(), 18, 15 ) + Str( hb_MilliSeconds(), 20 ), 1 )
      ENDDO

      Self:hSSLCtx := SSL_CTX_NEW( HB_SSL_CTX_NEW_METHOD_SSLV23_SERVER )
      SSL_CTX_SET_OPTIONS( Self:hSSLCtx, HB_SSL_OP_NO_TLSv1 )

      IF SSL_CTX_USE_PRIVATEKEY_FILE( Self:hSSLCtx, Self:aConfig[ "PrivateKeyFilename" ], HB_SSL_FILETYPE_PEM ) != 1
         Self:cError := "Invalid private key file"
         RETURN .F.
      ENDIF

      IF SSL_CTX_USE_CERTIFICATE_FILE( Self:hSSLCtx, Self:aConfig[ "CertificateFilename" ], HB_SSL_FILETYPE_PEM ) != 1
         Self:cError := "Invalid certificate file"
         RETURN .F.
      ENDIF
#else
      Self:cError := "SSL not supported"
      RETURN .F.
#endif
   ENDIF



   IF Self:aConfig[ "Port" ] < 1 .OR. Self:aConfig[ "Port" ] > 65535
      Self:cError := "Invalid port number"
      RETURN .F.
   ENDIF

   IF ParseFirewallFilter( Self:aConfig[ "FirewallFilter" ], @aI )
      Self:aFirewallFilter := aI
   ELSE
      Self:cError := "Invalid firewall filter"
      RETURN .F.
   ENDIF


   Self:hReq   := { 'ip' => { => }, 'proc' => { => }, 'func' => { => } }

  /*
  hCfg := { 'sessionpath'   => Self:cSessionPath ,;
    'sessionduration'  => Self:nSessionDuration ,;
    'sessionlifedays'  => Self:nSessionLifeDays ,;
    'sessiongarbage'  => Self:nSessionGarbage ;
   }
 */

   IF ( Self:hAccessLog := FOpen( Self:cPathLog + '/' + Self:aConfig[ "AccessLogFilename" ], FO_CREAT + FO_WRITE ) ) == -1
      Self:cError :=  "Access log file open error " + LTrim( Str( FError() ) )
      RETURN .F.
   ENDIF
   FSeek( Self:hAccessLog, 0, FS_END )

   IF ( Self:hErrorLog := FOpen( Self:cPathLog + '/' + Self:aConfig[ "ErrorLogFilename" ], FO_CREAT + FO_WRITE ) ) == -1
      Self:cError :=  "Error log file open error " + LTrim( Str( FError() ) )
      FClose( Self:hAccessLog )
      RETURN .F.
   ENDIF
   FSeek( Self:hErrorLog, 0, FS_END )

   Self:hmtxQueue    := hb_mutexCreate()
   Self:hmtxLog      := hb_mutexCreate()
   Self:hmtxSession  := hb_mutexCreate() // NEcesary?
   Self:hmtxReq   := hb_mutexCreate()
   Self:hmtxFiles   := hb_mutexCreate()

   IF Empty( Self:hListen := hb_socketOpen() ) == NIL
      Self:cError :=  "Socket create error: " + hb_socketErrorString()
      FClose( Self:hErrorLog )
      FClose( Self:hAccessLog )
      RETURN .F.
   ENDIF

   IF ! hb_socketBind( Self:hListen, { HB_SOCKET_AF_INET, Self:aConfig[ "BindAddress" ], Self:aConfig[ "Port" ] } )
      Self:cError :=  "Bind error: " + hb_socketErrorString()
      hb_socketClose( Self:hListen )
      FClose( Self:hErrorLog )
      FClose( Self:hAccessLog )
      RETURN .F.
   ENDIF

   IF ! hb_socketListen( Self:hListen )
      Self:cError :=  "Listen error: " + hb_socketErrorString()
      hb_socketClose( Self:hListen )
      FClose( Self:hErrorLog )
      FClose( Self:hAccessLog )
      RETURN .F.
   ENDIF


   aThreads := {}
   FOR nI := 1 TO THREAD_COUNT_PREALLOC
      AAdd( aThreads, hb_threadStart( HB_THREAD_INHERIT_PUBLIC, @ProcessConnection(), Self ) )
   NEXT

   _t( '================' )
   _t( 'HTTPD2 Vrs. ' +  HTTPD2_VERSION )
   _t( '================' )

   ::aInfo[ 'sessionpath' ]   := Self:cSessionPath
   ::aInfo[ 'sessionduration' ]  :=  Self:nSessionDuration
   ::aInfo[ 'sessionlifedays' ]  :=  Self:nSessionLifeDays
   ::aInfo[ 'sessiongarbage' ]  :=  Self:nSessionGarbage
   ::aInfo[ 'port' ]    := ::aConfig[ 'Port' ]
   ::aInfo[ 'ssl' ]     := ::aConfig[ 'SSL' ]
   ::aInfo[ 'version' ]    := HTTPD2_VERSION
   ::aInfo[ 'start' ]     := DToC( Date() ) + ' ' + Time()
   ::aInfo[ 'debug' ]     := ::lDebug
   ::aInfo[ 'utf8' ]     := ::lUtf8
   ::aInfo[ 'errorstatus' ]   := ::aConfig[ 'ErrorStatus' ]
   ::aInfo[ 'websocket' ]    := .F.
   ::aInfo[ 'PrivateKeyFilename' ] := ::aConfig[ 'PrivateKeyFilename' ]
   ::aInfo[ 'CertificateFilename' ] := ::aConfig[ 'CertificateFilename' ]

   // ::aInfo := hCfg

   IF ValType( Self:bInit ) == 'B'
      Eval( Self:bInit, ::aInfo )
   ENDIF

   ::lInit := .T.


   Self:lStop := .F.
// Self:aSession := {=>}

   DO WHILE .T.


      IF Empty( hSocket := hb_socketAccept( Self:hListen,, 1000 ) )
         IF hb_socketGetError() == HB_SOCKET_ERR_TIMEOUT
            Eval( Self:aConfig[ "Idle" ], Self )
            IF Self:lStop
               EXIT
            ENDIF
         ELSE
            Self:LogError( "[error] Accept error: " + hb_socketErrorString() )
         ENDIF
      ELSE

         Self:Dbg( "New connection => " + hb_NumToHex( hSocket ) )

         IF hb_mutexQueueInfo( Self:hmtxQueue, @nWorkers, @nJobs ) .AND. ;
               Len( aThreads ) < THREAD_COUNT_MAX .AND. ;
               nJobs >= nWorkers

            AAdd( aThreads, hb_threadStart( HB_THREAD_INHERIT_PUBLIC, @ProcessConnection(), Self ) )
         ENDIF

         hb_mutexNotify( Self:hmtxQueue, hSocket )
      ENDIF
   ENDDO
   hb_socketClose( Self:hListen )

   // End child threads
   AEval( aThreads, {|| hb_mutexNotify( Self:hmtxQueue, NIL ) } )
   AEval( aThreads, {| h | hb_threadJoin( h ) } )

   FClose( Self:hErrorLog )
   FClose( Self:hAccessLog )

   RETURN .T.


METHOD Stop() CLASS UHttpd2

   ::Dbg( "stopping" )
   Self:lStop := .T.

   RETURN NIL

METHOD SetTrace() CLASS UHttpd2

	::lTrace := .T.
	
	::SetFolderPublic( '.trace' )	

RETU NIL 

METHOD SetFolderPublic( cFolder, lIndex ) CLASS UHttpd2
	
	hb_default( @cFolder, '' )
	hb_default( @lIndex, .f. )
	
	IF empty( cFolder ) 
		RETU .F.
    ENDIF

	IF !hb_DirExists( cFolder )	  
		hb_DirBuild( cFolder )
		IF !hb_DirExists( cFolder )
			_t( "ERROR creating " + cFolder + " folder " )
			RETU .F.
		ENDIF
	ENDIF
   
	::SetDirFiles( cFolder, lIndex )      //	 

RETU .T.

METHOD LogError( cError ) CLASS UHttpd2

   hb_mutexLock( Self:hmtxLog )
   FWrite( Self:hErrorLog, ">>> " + DToS( Date() ) + " " + Time() + " " + cError + " " + hb_osNewLine() )
   hb_mutexUnlock( Self:hmtxLog )

   RETURN NIL


METHOD LogAccess() CLASS UHttpd2

   LOCAL cDate := DToS( Date() ), cTime := Time()

   hb_mutexLock( Self:hmtxLog )
   FWrite( Self:hAccessLog, ;
      server[ "REMOTE_ADDR" ] + " - - [" + Right( cDate, 2 ) + "/" + ;
      { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }[ Val( SubStr( cDate, 5, 2 ) ) ] + ;
      "/" + Left( cDate, 4 ) + ":" + cTime + ' +0000] "' + server[ "REQUEST_ALL" ] + '" ' + ;
      LTrim( Str( s_nStatusCode ) ) + " " + LTrim( Str( Len( s_cResult ) ) ) + ;
      ' "' + server[ "HTTP_REFERER" ] + '" "' + server[ "HTTP_USER_AGENT" ] + ;
      '"' + hb_osNewLine() )
   hb_mutexUnlock( Self:hmtxLog )

   RETURN NIL

METHOD Statistics() CLASS UHttpd2

   LOCAL hReq := { => }

   hb_mutexLock( Self:hmtxReq )

   hReq := Self:hReq

// _d( 'STATISTICS' )
// _d( Self:hReq )
// _d( Self:hReqIP )

   hb_mutexUnlock( Self:hmtxReq )

   RETURN hReq


STATIC FUNCTION IPAddr2Num( cIP )

   LOCAL aA, n1, n2, n3, n4

   aA := hb_regex( "^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$", cIP )
   IF Len( aA ) == 5 .AND. ( n1 := Val( aA[ 2 ] ) ) <= 255 .AND. ( n2 := Val( aA[ 3 ] ) ) <= 255 .AND. ;
         ( n3 := Val( aA[ 4 ] ) ) <= 255 .AND. ( n4 := Val( aA[ 5 ] ) ) <= 255
      RETURN ( ( ( n1 * 256 ) + n2 ) * 256 + n3 ) * 256 + n4
   ENDIF

   RETURN NIL


STATIC FUNCTION ParseFirewallFilter( cFilter, aFilter )

   LOCAL cExpr, nI, cI, nPrefix, nAddr, nAddr2, nPos, nPos2, lDeny, aDeny, aI

   aFilter := { => }
   aDeny := {}
   FOR EACH cExpr IN hb_ATokens( cFilter, " " )
      IF ! Empty( cExpr )
         IF lDeny := ( Left( cExpr, 1 ) == "!" )
            cExpr := SubStr( cExpr, 2 )
         ENDIF
         IF ( nI := At( "/", cExpr ) ) > 0
            cI := SubStr( cExpr, nI + 1 )
            cExpr := Left( cExpr, nI - 1 )
            IF "." $ cI
               IF ( nI := IPAddr2Num( cI ) ) == NIL
                  RETURN .F.
               ENDIF
               nPrefix := 32
               DO WHILE hb_bitAnd( nI, 1 ) == 0
                  nPrefix--
                  nI := hb_bitShift( nI, - 1 )
               ENDDO
               IF nI + 1 != hb_bitShift( 1, nPrefix )
                  RETURN .F.
               ENDIF
            ELSE
               nPrefix := Val( cI )
               IF nPrefix < 0 .OR. nPrefix > 32 .OR. !( hb_ntos( nPrefix ) == cI )
                  RETURN .F.
               ENDIF
            ENDIF
         ELSE
            nPrefix := 32
         ENDIF
         IF ( nAddr := IPAddr2Num( cExpr ) ) == NIL
            RETURN .F.
         ENDIF
         nPrefix := 0x100000000 - hb_bitShift( 1, 32 - nPrefix )

         // Remove unnecessary network address part
         nAddr := hb_bitAnd( nAddr, nPrefix )
         nAddr2 := hb_bitOr( nAddr, hb_bitXor( nPrefix, 0xFFFFFFFF ) )

         IF lDeny
            AAdd( aDeny, { nAddr, nAddr2 } )
         ELSE
            // Add to filter
            hb_HHasKey( aFilter, nAddr, @nPos )
            IF nPos == 0 .OR. hb_HValueAt( aFilter, nPos ) + 1 < nAddr
               // Does not overlap/glue with nPos
               // So, add new interval
               aFilter[ nAddr ] := nAddr2
               nPos++
            ENDIF
            hb_HHasKey( aFilter, nAddr2 + 1, @nPos2 )
            // Merge and delete inner subintervals
            aFilter[ hb_HKeyAt( aFilter, nPos ) ] := Max( hb_HValueAt( aFilter, nPos2 ), nAddr2 )
            DO WHILE nPos2-->nPos
               hb_HDelAt( aFilter, nPos + 1 )
            ENDDO
         ENDIF
      ENDIF
   NEXT

   FOR EACH aI IN aDeny
      nAddr := aI[ 1 ]
      nAddr2 := aI[ 2 ]

      // Delete from filter
      hb_HHasKey( aFilter, nAddr, @nPos )
      IF nPos == 0 .OR. hb_HValueAt( aFilter, nPos ) < nAddr
         nPos++
      ENDIF
      IF nPos > Len( aFilter )
         LOOP
      ENDIF

      hb_HHasKey( aFilter, nAddr2, @nPos2 )
      IF nPos2 > 0 .AND. hb_HValueAt( aFilter, nPos2 ) > nAddr2
         aFilter[ nAddr2 + 1 ] := hb_HValueAt( aFilter, nPos2 )
      ENDIF
      IF nAddr > hb_HKeyAt( aFilter, nPos )
         aFilter[ hb_HKeyAt( aFilter, nPos ) ] := nAddr - 1
         nPos++
      ENDIF
      DO WHILE nPos2-- >= nPos
         hb_HDelAt( aFilter, nPos )
      ENDDO
   NEXT

   RETURN .T.



#ifndef NO_SSL

// STATIC FUNCTION MY_SSL_READ(hSSL, hSocket, cBuf, nTimeout, nError)
FUNCTION MY_SSL_READ( hSSL, hSocket, cBuf, nTimeout, nError )

   LOCAL nErr, nLen

   nLen := SSL_READ( hSSL, @cBuf )
   IF nLen < 0
      nErr := SSL_GET_ERROR( hSSL, nLen )
      IF nErr == HB_SSL_ERROR_WANT_READ
         nErr := hb_socketSelectRead( hSocket, nTimeout )
         IF nErr < 0
            nError := hb_socketGetError()
         ELSE  // Both cases: data received and timeout
            nError := HB_SOCKET_ERR_TIMEOUT
         ENDIF
         RETURN -1
      ELSEIF nErr == HB_SSL_ERROR_WANT_WRITE
         nErr := hb_socketSelectWrite( hSocket, nTimeout )
         IF nErr < 0
            nError := hb_socketGetError()
         ELSE  // Both cases: data sent and timeout
            nError := HB_SOCKET_ERR_TIMEOUT
         ENDIF
         RETURN -1
      ELSE
         // ? "SSL_READ() error", nErr
         nError := 1000 + nErr
         RETURN -1
      ENDIF
   ENDIF

   RETURN nLen


// STATIC FUNCTION MY_SSL_WRITE(hSSL, hSocket, cBuf, nTimeout, nError)
FUNCTION MY_SSL_WRITE( hSSL, hSocket, cBuf, nTimeout, nError )

   LOCAL nErr, nLen

   nLen := SSL_WRITE( hSSL, cBuf )
   IF nLen <= 0
      nErr := SSL_GET_ERROR( hSSL, nLen )
      IF nErr == HB_SSL_ERROR_WANT_READ
         nErr := hb_socketSelectRead( hSocket, nTimeout )
         IF nErr < 0
            nError := hb_socketGetError()
            RETURN -1
         ELSE  // Both cases: data received and timeout
            RETURN 0
         ENDIF
      ELSEIF nErr == HB_SSL_ERROR_WANT_WRITE
         nErr := hb_socketSelectWrite( hSocket, nTimeout )
         IF nErr < 0
            nError := hb_socketGetError()
            RETURN -1
         ELSE  // Both cases: data sent and timeout
            RETURN 0
         ENDIF
      ELSE
         // ? "SSL_WRITE() error", nErr
         nError := 1000 + nErr
         RETURN -1
      ENDIF
   ENDIF

   RETURN nLen


STATIC FUNCTION MY_SSL_ACCEPT( hSSL, hSocket, nTimeout )

   LOCAL nErr

   nErr := SSL_ACCEPT( hSSL )
   IF nErr > 0
      RETURN 0
   ELSEIF nErr < 0
      nErr := SSL_GET_ERROR( hSSL, nErr )
      IF nErr == HB_SSL_ERROR_WANT_READ
         nErr := hb_socketSelectRead( hSocket, nTimeout )
         IF nErr < 0
            nErr := hb_socketGetError()
         ELSE
            nErr := HB_SOCKET_ERR_TIMEOUT
         ENDIF
      ELSEIF nErr == HB_SSL_ERROR_WANT_WRITE
         nErr := hb_socketSelectWrite( hSocket, nTimeout )
         IF nErr < 0
            nErr := hb_socketGetError()
         ELSE
            nErr := HB_SOCKET_ERR_TIMEOUT
         ENDIF
      ELSE
         // ? "SSL_ACCEPT() error", nErr
         nErr := 1000 + nErr
      ENDIF
   ELSE /* nErr == 0 */
      nErr := SSL_GET_ERROR( hSSL, nErr )
      // ? "SSL_ACCEPT() shutdown error", nErr
      nErr := 1000 + nErr
   ENDIF

   RETURN nErr

#endif

STATIC FUNC ProcessConnection( oServer )

   LOCAL hSocket, cRequest, aI, nLen, nErr, nTime, nReqLen, cBuf, aServer
   LOCAL aMount, cMount, aMethods, lPassMethod, n, nRoutes, aPair, aRoute, aMatch, cMethod, nIPBin
#ifndef NO_SSL
   LOCAL hSSL
#endif

   ErrorBlock( {| o | UErrorHandler( o, oServer ) } )

   PRIVATE server, GET, post, files, cookie, session, httpd

   httpd := oServer

   /* main worker thread loop */
   DO WHILE .T.
      hb_mutexSubscribe( oServer:hmtxQueue,, @hSocket )
      IF hSocket == NIL
         EXIT
      ENDIF

    /* Prepare server variable and clone it for every query,
       because request handler script can ruin variable value */
      aServer := { => }
      aServer[ "HTTPS" ] := oServer:aConfig[ "SSL" ]
	  
      IF ! Empty( aI := hb_socketGetPeerName( hSocket ) )
         aServer[ "REMOTE_ADDR" ] := aI[ 2 ]
         aServer[ "REMOTE_HOST" ] := aServer[ "REMOTE_ADDR" ]  // no reverse DNS
         aServer[ "REMOTE_PORT" ] := aI[ 3 ]
      ENDIF	  
	  
      IF ! Empty( aI := hb_socketGetSockName( hSocket ) )
         aServer[ "SERVER_ADDR" ] := aI[ 2 ]
         aServer[ "SERVER_PORT" ] := aI[ 3 ]
      ENDIF



      /* Firewall */
      nIpBin := IPAddr2Num( aServer[ "REMOTE_ADDR" ] )
	  
	  DO CASE 
	  
		CASE oServer:lFirewallType == 'blacklist' 
		
			hb_HHasKey( oServer:aFirewallFilter, nIpBin, @nErr )
			
			IF nErr > 0 .AND. nIpBin <= hb_HValueAt( oServer:aFirewallFilter, nErr )
				oServer:Dbg( "Firewall denied (blacklist)", aServer[ "REMOTE_ADDR" ] )
				hb_socketShutdown( hSocket )
				hb_socketClose( hSocket )
				LOOP
			ENDIF
			
		CASE oServer:lFirewallType == 'whitelist' 
		
			hb_HHasKey( oServer:aFirewallFilter, nIpBin, @nErr )
			
			IF nErr > 0 .AND. nIpBin <= hb_HValueAt( oServer:aFirewallFilter, nErr )
			
				//	WhiteList => IP OK
				
			ELSE
				oServer:Dbg( "Firewall denied (whitelist)", aServer[ "REMOTE_ADDR" ] )
				hb_socketShutdown( hSocket )
				hb_socketClose( hSocket )
				LOOP
			ENDIF		
		
		OTHERWISE 
			hb_socketShutdown( hSocket )
			hb_socketClose( hSocket )	
			LOOP 
	  ENDCASE

#ifndef NO_SSL
      IF oServer:aConfig[ "SSL" ]
         hSSL := SSL_NEW( oServer:hSSLCtx )
         SSL_SET_MODE( hSSL, hb_bitOr( SSL_GET_MODE( hSSL ), HB_SSL_MODE_ENABLE_PARTIAL_WRITE ) )
         hb_socketSetBlockingIO( hSocket, .F. )
         SSL_SET_FD( hSSL, hb_socketGetFD( hSocket ) )

         nTime := hb_MilliSeconds()
         DO WHILE .T.
            IF ( nErr := MY_SSL_ACCEPT( hSSL, hSocket, 1000 ) ) == 0
               EXIT
            ELSE
               IF nErr == HB_SOCKET_ERR_TIMEOUT
                  // IF (hb_milliseconds() - nTime) > 1000 * 30 .OR. oServer:lStop
                  // IF (hb_milliseconds() - nTime) > 1000 * SESSION_TIMEOUT .OR. oServer:lStop
                  IF ( hb_MilliSeconds() - nTime ) > ( 1000 * oServer:nTime_Keep_Alive ) .OR. oServer:lStop
                     oServer:Dbg( "SSL accept timeout", hSocket )
                     EXIT
                  ENDIF
               ELSE
                  oServer:Dbg( "SSL accept error:", nErr, hb_socketErrorString( nErr ) )
                  EXIT
               ENDIF
            ENDIF
         ENDDO

         IF nErr != 0
            oServer:Dbg( "Close connection.. => " + hb_NumToHex( hSocket ) )

            dbCloseAll() // CAF

            hb_socketShutdown( hSocket )
            hb_socketClose( hSocket )
            LOOP
         ENDIF

         aServer[ "SSL_CIPHER" ]    := SSL_GET_CIPHER( hSSL )
         aServer[ "SSL_PROTOCOL" ]    := SSL_GET_VERSION( hSSL )
         aServer[ "SSL_CIPHER_USEKEYSIZE" ] := SSL_GET_CIPHER_BITS( hSSL, @nErr )
         aServer[ "SSL_CIPHER_ALGKEYSIZE" ] := nErr
         aServer[ "SSL_VERSION_LIBRARY" ]  := SSLEAY_VERSION( HB_SSLEAY_VERSION )
         aServer[ "SSL_SERVER_I_DN" ]   := X509_NAME_ONELINE( X509_GET_ISSUER_NAME( SSL_GET_CERTIFICATE( hSSL ) ) )
         aServer[ "SSL_SERVER_S_DN" ]   := X509_NAME_ONELINE( X509_GET_SUBJECT_NAME( SSL_GET_CERTIFICATE( hSSL ) ) )
      ENDIF
#endif

      /* loop for processing connection */

      /* Set cRequest to empty string here. This enables request pipelining */
      cRequest := ""
      DO WHILE ! oServer:lStop

         /* receive query header */
         nLen := 1
         nTime := hb_MilliSeconds()
         cBuf := Space( 4096 )
         DO WHILE At( CR_LF + CR_LF, cRequest ) == 0
#ifndef NO_SSL
            IF oServer:aConfig[ "SSL" ]
               nLen := MY_SSL_READ( hSSL, hSocket, @cBuf, 1000, @nErr )
            ELSE
#endif
               nLen := hb_socketRecv( hSocket, @cBuf,,, 1000 )
               IF nLen < 0
                  nErr := hb_socketGetError()
               ENDIF
#ifndef NO_SSL
            ENDIF
#endif
            IF nLen > 0
               cRequest += Left( cBuf, nLen )
            ELSEIF nLen == 0
               /* connection closed */		   
               EXIT
            ELSE
               /* nLen == -1  socket error */
               IF nErr == HB_SOCKET_ERR_TIMEOUT

                  IF ( hb_MilliSeconds() - nTime ) > ( 1000 * oServer:nTime_Keep_Alive ) .OR. oServer:lStop
                     oServer:Dbg( "Receive timeout => " + hb_NumToHex( hSocket ) )
                     EXIT
                  ENDIF
               ELSE
                  oServer:Dbg( "Receive error: " + LTrim( Str( nErr ) ) + ' ' + hb_socketErrorString( nErr ) )
                  EXIT
               ENDIF
            ENDIF
         ENDDO

         IF nLen <= 0 .OR. oServer:lStop		 
            EXIT
         ENDIF

         // PRIVATE
         server := hb_HClone( aServer )
         GET := { => }
         post := { => }
         files := {}
         cookie := { => }
         session := NIL
         s_cResult := ''
         s_aHeader := {}
         s_nStatusCode := 200
// s_aSessionData := NIL  // Necesary ?

         nReqLen := ParseRequestHeader( @cRequest )

         IF nReqLen == NIL
            USetStatusCode( 400 )
            UAddHeader( "Connection", "close" )
         ELSE

            /* receive query body */

// Search Route

            cMount  := server[ "SCRIPT_NAME" ]
            aMount   := oServer:aConfig[ "Mount" ]
            nRoutes  := Len( aMount )
            aRoute   := {}
            lPassMethod := .T.

            IF cMount == '/api'

               lPassMethod := .T.
               AAdd( aRoute, { 'route' => '/api', 'config' => aMount[ '/api' ], 'match' => {} } )

            ELSE

               FOR n :=  1 TO nRoutes

                  aPair := hb_HPairAt( aMount, n )

                  IF ( aPair[ 2 ][ 'regexp' ] != NIL )


                     IF Left( cMount, 1 ) == '/' .AND. Len( cMount ) > 1
                        cMount := SubStr( cMount, 2 )
                     ENDIF


                     aMatch := hb_regex( aPair[ 2 ][ 'regexp' ], cMount )

                     IF !Empty( aMatch )

// Check Method

                        cMethod  := aPair[ 2 ][ 'method' ]
                        aMethods  := hb_ATokens( cMethod, ',' )

                        IF AScan( aMethods, {| x | Upper( x ) ==  server[ "REQUEST_METHOD" ] } ) > 0
                           lPassMethod := .T.
                           AAdd( aRoute, { 'route' => aPair[ 1 ], 'config' => aPair[ 2 ], 'match' => aMatch } )
                        ENDIF

                     ENDIF

                  ENDIF

               NEXT

            ENDIF

// Validate Route

            IF Len( aRoute ) == 1     // Perfect. match Route
// _d( 'Perfect. We execute: ' + aRoute[1]['route'] )
            ELSEIF Len( aRoute ) > 1    // More than 1 casuistic.
// At the moment in this case, we can select First coincidence and show warning for dbg
               _t( 'Warning! More than 1 route' )
               FOR n = 1 TO Len( aRoute )
                  _t( '  >> ' + aRoute[ n ][ 'route' ] )
               NEXT
               _t( '--------------------------' )
            ELSE
// _d( 'Ni idea...' )
            ENDIF

            nLen := 1
            nTime := hb_MilliSeconds()
            cBuf := Space( 4096 )

            DO WHILE Len( cRequest ) < nReqLen
#ifndef NO_SSL
               IF oServer:aConfig[ "SSL" ]
                  nLen := MY_SSL_READ( hSSL, hSocket, @cBuf, 1000, @nErr )
               ELSE
#endif
                  nLen := hb_socketRecv( hSocket, @cBuf,,, 1000 )
                  IF nLen < 0
                     nErr := hb_socketGetError()
                  ENDIF
#ifndef NO_SSL
               ENDIF
#endif
               IF nLen > 0
                  cRequest += Left( cBuf, nLen )
               ELSEIF nLen == 0
                  /* connection closed */				  
                  EXIT
               ELSE
                  /* nLen == -1  socket error */
                  IF nErr == HB_SOCKET_ERR_TIMEOUT
                     IF ( hb_MilliSeconds() - nTime ) > 1000 * 120 .OR. oServer:lStop
                        oServer:Dbg( "Receive timeout => " + hb_NumToHex( hSocket ) )				
                        EXIT
                     ENDIF
                  ELSE
                     oServer:Dbg( "Receive error: " + LTrim( Str( nErr ) ) + ' ' + hb_socketErrorString( nErr ) )
			         EXIT
                  ENDIF
               ENDIF
            ENDDO

            IF nLen <= 0 .OR. oServer:lStop		
               EXIT
            ENDIF

            // ? cRequest
            ParseRequestBody( Left( cRequest, nReqLen ), oServer )
            cRequest := SubStr( cRequest, nReqLen + 1 )

            /* Deal with supported protocols and methods */
            IF !( Left( server[ "SERVER_PROTOCOL" ], 5 ) == "HTTP/" )
               USetStatusCode( 400 ) /* Bad request */
               UAddHeader( "Connection", "close" )
            ELSEIF !( SubStr( server[ "SERVER_PROTOCOL" ], 6 ) $ "1.0 1.1" )
               USetStatusCode( 505 ) /* HTTP version not supported */
// ELSEIF !(server["REQUEST_METHOD"] $ "GET POST")    // Check for Lautaro. Check method ! only GET POST
            ELSEIF ! lPassMethod
               USetStatusCode( 404 ) /* Not implemented */
            ELSE
               IF server[ "SERVER_PROTOCOL" ] == "HTTP/1.1"
                  IF Lower( server[ "HTTP_CONNECTION" ] ) == "close"
                     UAddHeader( "Connection", "close" )
                  ELSE
                     UAddHeader( "Connection", "keep-alive" )
                  ENDIF
               ENDIF

               /* Do the job */

               ProcessRequest( oServer, aRoute )

            ENDIF
         ENDIF /* request header ok */

         // Send response
         cBuf := MakeResponse()

         DO WHILE Len( cBuf ) > 0 .AND. ! oServer:lStop
#ifndef NO_SSL
            IF oServer:aConfig[ "SSL" ]
               nLen := MY_SSL_WRITE( hSSL, hSocket, cBuf, 1000, @nErr )
            ELSE
#endif
               nLen := hb_socketSend( hSocket, cBuf,,, 1000 )
               IF nLen < 0
                  nErr := hb_socketGetError()
               ENDIF
#ifndef NO_SSL
            ENDIF
#endif
            IF nLen < 0
               oServer:Dbg( "send error:", nErr, hb_socketErrorString( nErr ) )
               EXIT
            ELSEIF nLen > 0
               cBuf := SubStr( cBuf, nLen + 1 )
            ENDIF
         ENDDO

         IF oServer:lStop
            EXIT
         ENDIF

         oServer:LogAccess()

         IF HB_ISSTRING( UGetHeader( "Connection" ) ) .AND. Lower( UGetHeader( "Connection" ) ) == "close" .OR. server[ "SERVER_PROTOCOL" ] == "HTTP/1.0"
            EXIT
         ENDIF
      ENDDO

#ifndef NO_SSL
      hSSL := NIL
#endif
      oServer:Dbg( "Close connection. => " + hb_NumToHex( hSocket )  )  
      hb_socketShutdown( hSocket )
      hb_socketClose( hSocket )

      dbCloseAll() // CAF

   ENDDO

   RETURN 0

FUNCTION USetFilePrg( cFile )

   cFilePrg := cFile
   RETU NIL

FUNCTION UGetFilePrg(); RETU cFilePrg

FUNCTION UGetFileHtml(); RETU cFileHtml

STATIC FUNCTION ProcessRequest( oServer, aRoute )

   LOCAL nI, aMount, cMount, cPath, bEval, xRet, nT := hb_MilliSeconds()
   LOCAL h := { => }
   LOCAL aMethods
   LOCAL cError := '',  cDbg
   LOCAL nIni, oError, n, aParams
   LOCAL cInfoCode := ''
   LOCAL lIsRoute := .T.
   LOCAL hMtr   := { => }

// local oUDom
// * Error vars


   oError := NIL

   // Search mounting table
   aMount := oServer:aConfig[ "Mount" ]


   IF Len( aRoute ) > 0
      cPath  := ''
      cMount := aRoute[ 1 ][ 'route' ]

   ELSE

      cMount := server[ "SCRIPT_NAME" ]


      nI := Len( cMount )
      DO WHILE ( nI := hb_RAt( "/", cMount,, nI ) ) > 0
         IF hb_HHasKey( aMount, Left( cMount, nI ) + "*" )
// ? "HAS", LEFT(cMount, nI) + "*"
            cMount := Left( cMount, nI ) + "*"
            cPath := SubStr( server[ "SCRIPT_NAME" ], nI + 1 )
            EXIT
         ENDIF
         IF --nI == 0
            EXIT
         ENDIF
      ENDDO

   ENDIF


   IF cPath != NIL .OR. server[ "REQUEST_METHOD" ] == 'OPTIONS'

      server[ 'route' ] := cMount

      h[ 'path' ]   := cPath     // Request file like .../proto.dos/files/favicon.ico
      h[ 'pathhtml' ]   := oServer:cPathHtml  // Root path where will be html files
      h[ 'pathlog' ]   := oServer:cPathLog
      h[ 'debug' ]   := oServer:lDebug
      h[ 'server' ]   := server     // Environment files server
      h[ 'get' ]    := GET      //
      h[ 'post' ]   := post      //
      h[ 'files' ]   := files
      h[ 'route' ]   := if( Len( aRoute ) > 0, aRoute[ 1 ], {} )


// Parameters if you used friendly url

      IF Len( aRoute ) > 0 .AND. ValType( h[ 'get' ] ) == 'H'  // Sure!

         aParams := aRoute[ 1 ][ 'match' ]

         FOR n := 2 TO Len( aParams )

            h[ 'get' ][ '_value' + LTrim( Str( n - 1 ) ) ] := aParams[ n ]

         NEXT

      ENDIF

// ----------------------------------------

      IF ValType( aMount[ cMount ] ) == 'B'

         bEval := aMount[ cMount ]

      ELSEIF ValType( aMount[ cMount ] ) == 'H'

         IF hb_HHasKey( aMount[ cMount ], 'action' )


            bEval := aMount[ cMount ][ 'action' ]

         ENDIF

         IF hb_HHasKey( aMount[ cMount ], 'method' )

            aMethods := hb_ATokens( aMount[ cMount ][ 'method' ], ',' )


            IF server[ "REQUEST_METHOD" ] != 'OPTIONS' .AND. AScan( aMethods, {| x | Upper( x ) ==  server[ "REQUEST_METHOD" ] } ) == 0

               IF UIsAjax()

                  UAddHeader( "Content-Type", "application/json" )

                  xRet := { => }
                  xRet[ 'success' ] := .F.
                  xRet[ 'html' ] := ''
                  xRet[ 'msg' ] := 'Error route...' +  cMount + ', dont declarated method ' + server[ "REQUEST_METHOD" ]


                  UWrite( hb_jsonEncode( xRet ) )

               ELSE
                  USetStatusCode( 404 )
                  _t( '>> Error route: ' +  cMount + ', dont declarated method ' + server[ "REQUEST_METHOD" ] )
               ENDIF

               RETU ''
            ENDIF

         ENDIF

      ENDIF


      nIni := hb_MilliSeconds()  // CAF

      // BEGIN SEQUENCE WITH {|oErr| UErrorHandler( oErr, oServer, @cError )}
      BEGIN SEQUENCE WITH {| oErr | oError := oErr, Break( oErr ) }



  /* Hem d'explorar aquesta opció de pasar primer el oDoms
     Ho vaig porbar però no xutava bé. Això és el que fem
     a UWebApi

   oUDom := UDom():New( h[ 'post' ], h[ 'files' ] )
   xRet := EVAL(bEval, oUDom, h )
  */

         xRet := Eval( bEval, h )

// If exist session, we can save data values...

// Charly -> Pendiente de chequear por que a veces
// se evalua UWebApi y realiza el USessionWrite() y despues le USessionDelte().
// y viene aqui y lo vuelve a ejecutar. no pasa nada
// porque como oSession == NIL ni escribe ni nada.
// Pero pendiente de revisar

         USessionWrite()
         UsessionDelete()

// -------------------------------------------------



         IF ValType( xRet ) == "C"

            UWrite( xRet )

         ELSEIF ValType( xRet ) == "H"

            IF UIsAjax()

               UAddHeader( "Content-Type", "application/json" )

               UWrite( hb_jsonEncode( xRet ) )

            ELSE

               IF xRet[ 'success' ]
                  UWrite( xRet[ 'html' ] )
               ELSE
// UWrite( UMsgError(  xRet[ 'msg' ] ) )
                  UDo_ErrorMsg( xRet[ 'msg' ] )
               ENDIF

            ENDIF



// Hauriem de mir de fer un hb_jsondecode(xRet)
// Despres ... no de som agafar-ho
         ENDIF

// Quizas tendriamos de meter el cierre de session en
// este punto...


         // RECOVER
      RECOVER USING oError

         cInfoCode  := UGetInfoCode( oError )

         cError   += UErrorWeb()

         cError   += UErrorGetDescription( oError, cInfoCode )

         cError   += UErrorGetSys()

         IF UIsAjax()
            UWrite( cError )
         ELSE
            UWrite( UMsgError( cError ) )
         ENDIF

         RETU ''


      END SEQUENCE

      // oServer:Dbg( 'Lap. ' + ltrim(str(hb_milliseconds()-nIni )) + 'ms.' )  //CAF

      IF oServer:lDbfAutoClose // CAF
// oServer:Dbg( 'DbCloseAll(1)' )
         dbCloseAll()
      ENDIF

      // Unlock session     // Necesary?
 /*
    IF s_aSessionData != NIL
      session := NIL
      hb_mutexUnlock(s_aSessionData[1])
      s_aSessionData := NIL
    ENDIF
 */
   ELSE

      USetStatusCode( 404 )


 /*No chuta
 if UIsAjax()
  UWrite( "Route don't exist => " +  cMount )
 endif
 */
   ENDIF

   cDbg := server[ "REMOTE_HOST" ] + ':' + LTrim( Str( server[ "REMOTE_PORT" ] ) )


// Metrics... <<-----------------------------------

   hMtr[ 'key' ] := ''
   hMtr[ 'run' ] := 0
   hMtr[ 'time' ] := 0
   hMtr[ 'max' ] := 0
   hMtr[ 'min' ] := 999999
   hMtr[ 'lapsus' ] := hb_MilliSeconds() - nT

   hMtr[ 'metric' ]  := ''


   IF hb_HHasKey( h, 'post' ) .AND. hb_HHasKey( h[ 'post' ], 'api' )

      cDbg += ' >> Api ' + h[ 'post' ][ 'api' ] + ' => ' + h[ 'post' ][ 'proc' ] + ' : ' + LTrim( Str( hMtr[ 'lapsus' ] ) ) +  "ms"

      hMtr[ 'key' ] := h[ 'post' ][ 'api' ] + ':' + h[ 'post' ][ 'proc' ]

      hb_mutexLock( oServer:hmtxReq )

      IF hb_HHasKey( oServer:hReq[ 'ip' ], server[ "REMOTE_ADDR" ] )
         hMtr[ 'run' ]  :=  oServer:hReq[ 'ip' ][ server[ "REMOTE_ADDR" ]  ][ 'run' ] + 1
         oServer:hReq[ 'ip' ][ server[ "REMOTE_ADDR" ] ] := { 'run' => hMtr[ 'run' ], 'last' => DToC( Date() ) + ' ' + Time() }
      ELSE
         oServer:hReq[ 'ip' ][ server[ "REMOTE_ADDR" ] ] := { 'run' => 1, 'last' => DToC( Date() ) + ' ' + Time() }
      ENDIF

      IF hb_HHasKey( oServer:hReq[ 'proc' ], hMtr[ 'key' ] )

         hMtr[ 'run' ]  := oServer:hReq[ 'proc' ][ hMtr[ 'key' ] ][ 'run' ] + 1
         hMtr[ 'time' ]  := oServer:hReq[ 'proc' ][ hMtr[ 'key' ] ][ 'time' ] + hMtr[ 'lapsus' ]
         hMtr[ 'max' ]  := Max( oServer:hReq[ 'proc' ][ hMtr[ 'key' ] ][ 'max' ], hMtr[ 'lapsus' ] )
         hMtr[ 'min' ]  := Min( oServer:hReq[ 'proc' ][ hMtr[ 'key' ] ][ 'min' ], hMtr[ 'lapsus' ] )

         oServer:hReq[ 'proc' ][ hMtr[ 'key' ] ] := { 'run' => hMtr[ 'run' ], 'time' => hMtr[ 'time' ], 'min' => hMtr[ 'min' ], 'max' => hMtr[ 'max' ] }
      ELSE
         oServer:hReq[ 'proc' ][ hMtr[ 'key' ] ] := { 'run' => 1, 'time' => hMtr[ 'lapsus' ], 'min' => hMtr[ 'lapsus' ], 'max' => hMtr[ 'lapsus' ] }
      ENDIF

      hb_mutexUnlock( oServer:hmtxReq )


   ELSE

      cDbg += ' >> ' + cMount + " : " + LTrim( Str( hMtr[ 'lapsus' ] ) ) + "ms"

      IF cMount != '/files/*' .AND. !( cMount == '/' ) .AND. lisRoute

         hb_mutexLock( oServer:hmtxReq )

         IF hb_HHasKey( oServer:hReq[ 'ip' ], server[ "REMOTE_ADDR" ] )
            hMtr[ 'run' ]  :=  oServer:hReq[ 'ip' ][ server[ "REMOTE_ADDR" ]  ][ 'run' ] + 1
            oServer:hReq[ 'ip' ][ server[ "REMOTE_ADDR" ] ] := { 'run' => hMtr[ 'run' ], 'last' => DToC( Date() ) + ' ' + Time() }
         ELSE
            oServer:hReq[ 'ip' ][ server[ "REMOTE_ADDR" ] ] := { 'run' => 1, 'last' => DToC( Date() ) + ' ' + Time() }
         ENDIF

         IF hb_HHasKey( oServer:hReq[ 'func' ], cMount )

            hMtr[ 'run' ]  := oServer:hReq[ 'func' ][ cMount ][ 'run' ] + 1
            hMtr[ 'time' ]  := oServer:hReq[ 'func' ][ cMount ][ 'time' ] + hMtr[ 'lapsus' ]
            hMtr[ 'max' ]  := Max( oServer:hReq[ 'func' ][ cMount ][ 'max' ], hMtr[ 'lapsus' ] )
            hMtr[ 'min' ]  := Min( oServer:hReq[ 'func' ][ cMount ][ 'min' ], hMtr[ 'lapsus' ] )

            oServer:hReq[ 'func' ][ cMount ] := { 'run' => hMtr[ 'run' ], 'time' => hMtr[ 'time' ], 'min' => hMtr[ 'min' ], 'max' => hMtr[ 'max' ] }
         ELSE
            oServer:hReq[ 'func' ][ cMount ] := { 'run' => 1, 'time' => hMtr[ 'lapsus' ], 'min' => hMtr[ 'lapsus' ], 'max' => hMtr[ 'lapsus' ] }
         ENDIF

         hb_mutexUnlock( oServer:hmtxReq )

      ENDIF

      oServer:Dbg( cDbg )

   ENDIF

   RETURN ''

FUNCTION DoMetric()

   RETU NIL

FUNCTION UGetInfoCode( oError, cCode, cCodePP )

   LOCAL n, nL, nLineError, nOffset, nLin, nPos, cLine
   LOCAL aTagLine := {}
   LOCAL aLines := {}
   LOCAL cText := ''
   LOCAL cInfoCode := ''

   hb_default( @cCode, '' )
   hb_default( @cCodePP, '' )

// En el código preprocesado, buscamos tags #line (#includes,#commands,...)

   aLines = hb_ATokens( cCodePP, Chr( 10 ) )

   FOR n = 1 TO Len( aLines )

      cLine := aLines[ n ]

      IF SubStr( cLine, 1, 5 ) == '#line'

         nLin := Val( SubStr( cLine, 6 ) )

         AAdd( aTagLine, { n, ( nLin - n - 1 ) } )


      ENDIF

   NEXT


// Buscamos si oError nos da Linea

   nL    := 0

   IF ! Empty( oError:operation )

      nPos := At(  'line:', oError:operation )

      IF nPos > 0
         nL := Val( SubStr( oError:operation, nPos + 5 ) )
      ENDIF

   ENDIF


// Procesamos Offset segun linea error

   nLineError := nL

   IF nL > 0

// Xec vectors
// { nLine, nOffset }
// { 1, 5 }, { 39, 8 }

      FOR n := 1  TO Len( aTagLine )

         IF aTagLine[ n ][ 1 ] < nL
            nOffset  := aTagLine[ n ][ 2 ]
            nLineError := nL + nOffset
         ENDIF

      NEXT

      nLineError -= 1 // __Inline() + CRLF

   ELSE



   ENDIF


   IF At(  'line:', oError:operation ) > 0
      oError:operation := 'Line: ' + LTrim( Str( nLineError ) )
   ENDIF

   IF ! Empty( cCode )
      cInfoCode += UErrorGetCode( cCode, nLineError )
   ENDIF


   RETU cInfoCode

FUNCTION UIsAjax()

   LOCAL lIsAjax := .F.

   IF hb_HHasKey( server, 'HTTP_X_REQUESTED_WITH' )
      lIsAjax := Lower( server[ 'HTTP_X_REQUESTED_WITH' ] ) == 'xmlhttprequest'
   ENDIF

   RETU lIsAjax

FUNCTION USetErrorStatus( nStatus, cPage, cAjax )

   oServer:SetErrorStatus( nStatus, cPage, cAjax )
   RETU NIL

STATIC FUNCTION ParseRequestHeader( cRequest )

   LOCAL aRequest, aLine, nI, nJ, cI, nK, nL, nContentLength := 0
   LOCAL aCookies

   nI := At( CR_LF + CR_LF, cRequest )
   aRequest := hb_ATokens( Left( cRequest, nI - 1 ), CR_LF )
   cRequest := SubStr( cRequest, nI + 4 )

   aLine := hb_ATokens( aRequest[ 1 ], " " )

   server[ "REQUEST_ALL" ] := aRequest[ 1 ]
   
   IF Len( aLine ) == 3 .AND. Left( aLine[ 3 ], 5 ) == "HTTP/"
      server[ "REQUEST_METHOD" ] := aLine[ 1 ]
      server[ "REQUEST_URI" ] := aLine[ 2 ]
      server[ "SERVER_PROTOCOL" ] := aLine[ 3 ]
   ELSE
      server[ "REQUEST_METHOD" ] := aLine[ 1 ]
      server[ "REQUEST_URI" ] := iif( Len( aLine ) >= 2, aLine[ 2 ], "" )
      server[ "SERVER_PROTOCOL" ] := iif( Len( aLine ) >= 3, aLine[ 3 ], "" )
      RETURN NIL
   ENDIF

   // Fix invalid queries: bind to root
   IF !( Left( server[ "REQUEST_URI" ], 1 ) == "/" )
      server[ "REQUEST_URI" ] := "/" + server[ "REQUEST_URI" ]
   ENDIF

   IF ( nI := At( "?", server[ "REQUEST_URI" ] ) ) > 0
      server[ "SCRIPT_NAME" ] := Left( server[ "REQUEST_URI" ], nI - 1 )
      server[ "QUERY_STRING" ] := SubStr( server[ "REQUEST_URI" ], nI + 1 )
   ELSE
      server[ "SCRIPT_NAME" ] := server[ "REQUEST_URI" ]
      server[ "QUERY_STRING" ] := ""
   ENDIF

   server[ "HTTP_ACCEPT" ] := ""
   server[ "HTTP_ACCEPT_CHARSET" ] := ""
   server[ "HTTP_ACCEPT_ENCODING" ] := ""
   server[ "HTTP_ACCEPT_LANGUAGE" ] := ""
   server[ "HTTP_CONNECTION" ] := ""
   server[ "HTTP_HOST" ] := ""
   server[ "HTTP_KEEP_ALIVE" ] := ""
   server[ "HTTP_REFERER" ] := ""
   server[ "HTTP_USER_AGENT" ] := ""


   FOR nI := 2 TO Len( aRequest )
      IF aRequest[ nI ] == "";  EXIT
      ELSEIF ( nJ := At( ":", aRequest[ nI ] ) ) > 0
         cI := AllTrim( SubStr( aRequest[ nI ], nJ + 1 ) )
         SWITCH Upper( Left( aRequest[ nI ], nJ - 1 ) )
         CASE "COOKIE"

            server[ "HTTP_COOKIE" ] := cI

            aCookies = hb_ATokens( cI, ';' )

            FOR nL = 1 TO Len( aCookies )
               nK := At( '=', aCookies[ nL ] )

               IF nK > 0
                  cookie[ AllTrim( Upper( Left( aCookies[ nL ], nK - 1 ) ) ) ] := AllTrim( SubStr( aCookies[ nL ], nK + 1 ) )
               ENDIF
            NEXT

            EXIT
         CASE "CONTENT-LENGTH"
            nContentLength := Val( cI )
            EXIT
         CASE "CONTENT-TYPE"
            server[ "CONTENT_TYPE" ] := cI
            EXIT

         OTHERWISE
            server[ "HTTP_" + StrTran( Upper( Left( aRequest[ nI ], nJ - 1 ) ), "-", "_" ) ] := cI
            EXIT
         ENDSWITCH
      ENDIF
   NEXT
   
   IF !( server[ "QUERY_STRING" ] == "" )
      FOR EACH cI IN hb_ATokens( server[ "QUERY_STRING" ], "&" )
         IF ( nI := At( "=", cI ) ) > 0
            GET[ UUrlDecode( Left( cI, nI - 1 ) ) ] := UUrlDecode( SubStr( cI, nI + 1 ) )
         ELSE
            GET[ UUrlDecode( cI ) ] := NIL
         ENDIF
      NEXT
   ENDIF
   
	/* Check IP Real, for si use invers proxy... */
	
	server[ "REMOTE_ADDR" ] := UGetIpClient( server )	       

   RETURN nContentLength



STATIC FUNCTION ParseRequestBody( cRequest, oServer )

   LOCAL nI, cPart
   LOCAL cEncoding := ''

   IF hb_HHasKey( server, "CONTENT_TYPE" )

      IF ( nI := At( "CHARSET=", Upper( server[ "CONTENT_TYPE" ] ) ) ) > 0
         cEncoding := Upper( SubStr( server[ "CONTENT_TYPE" ], nI + 8 ) )
      ENDIF

      DO CASE

      CASE Left( server[ "CONTENT_TYPE" ], 33 ) == "application/x-www-form-urlencoded"

         IF !( cRequest == "" )
            IF cEncoding == "UTF-8" .AND. oServer:lUtf8 == .F.   // Transform UTF8toStr
               FOR EACH cPart IN hb_ATokens( cRequest, "&" )
                  IF ( nI := At( "=", cPart ) ) > 0
                     post[ hb_UTF8ToStr( UUrlDecode( Left( cPart, nI - 1 ) ) ) ] := hb_UTF8ToStr( UUrlDecode( SubStr( cPart, nI + 1 ) ) )
                  ELSE
                     post[ hb_UTF8ToStr( UUrlDecode( cPart ) ) ] := NIL
                  ENDIF
               NEXT
            ELSE
               FOR EACH cPart IN hb_ATokens( cRequest, "&" )
                  IF ( nI := At( "=", cPart ) ) > 0
                     post[ UUrlDecode( Left( cPart, nI - 1 ) ) ] := UUrlDecode( SubStr( cPart, nI + 1 ) )
                  ELSE
                     post[ UUrlDecode( cPart ) ] := NIL
                  ENDIF
               NEXT
            ENDIF

         ENDIF

      CASE Left( server[ "CONTENT_TYPE" ], 16 ) == "application/json" // Workaround of Quim

         IF hb_jsonDecode( cRequest, @post ) == 0
            post := { => }
         ENDIF

      CASE Left( server[ "CONTENT_TYPE" ], 19 ) == "multipart/form-data"

         post  := { => }
         files := {}

         UParseMultipart( @cRequest, @Post, @files )

      OTHERWISE

         IF oServer:lUtf8
            post[ "RAW" ] := hb_UTF8ToStr( UUrlDecode( cRequest ) )
         ELSE
            post[ "RAW" ] := UUrlDecode( cRequest )
         ENDIF

      ENDCASE

   ELSE

// Workaround of Rafa

      IF !Empty( cRequest )

         IF oServer:lUtf8
            post[ "RAW" ] := hb_UTF8ToStr( UUrlDecode( cRequest ) )
         ELSE
            post[ "RAW" ] := UUrlDecode( cRequest )
         ENDIF
      ENDIF

   ENDIF

   RETURN NIL

// Check--> https://www.geeksforgeeks.org/how-to-upload-files-asynchronously-using-jquery/

// ------------------------------------------------------------------- //

FUNCTION UGetServer(); RETU oServer

FUNCTION UGetServerInfo(); RETU oServer:aInfo

FUNCTION USetServerInfo( cKey, uValue ); RETU  oServer:SetInfo( cKey, uValue )

FUNCTION UGetParams(); RETU server

FUNCTION UIsRunning(); RETU oServer:lInit

FUNCTION UGetInfoSSL()

   LOCAL hInfo := { => }

   IF hb_HGetDef( server, 'HTTPS', .F. )

      hInfo[ 'SSL_CIPHER'  ] := hb_HGetDef( server, 'SSL_CIPHER', '' )
      hInfo[ 'SSL_PROTOCOL'  ] := hb_HGetDef( server, 'SSL_PROTOCOL', '' )
      hInfo[ 'SSL_CIPHER_USEKEYSIZE'  ] := hb_HGetDef( server, 'SSL_CIPHER_USEKEYSIZE', '' )
      hInfo[ 'SSL_CIPHER_ALGKEYSIZE'  ] := hb_HGetDef( server, 'SSL_CIPHER_ALGKEYSIZE', '' )
      hInfo[ 'SSL_VERSION_LIBRARY'  ] := hb_HGetDef( server, 'SSL_VERSION_LIBRARY', '' )
      hInfo[ 'SSL_SERVER_I_DN'  ] := hb_HGetDef( server, 'SSL_SERVER_I_DN', '' )
      hInfo[ 'SSL_SERVER_S_DN'  ] := hb_HGetDef( server, 'SSL_SERVER_S_DN', '' )
      hInfo[ 'SSL_SERVER_S_DN'  ] := hb_HGetDef( server, 'SSL_SERVER_S_DN', '' )
      hInfo[ 'SSL_SERVER_S_DN'  ] := hb_HGetDef( server, 'SSL_SERVER_S_DN', '' )

   ENDIF

   RETU hInfo

// FUNCTION UGetStatistics(); RETU oServer

FUNCTION UGetRoutes(); RETU oServer:aConfig[ 'Mount' ]

FUNCTION UGetMethod(); RETU server[ 'REQUEST_METHOD' ]

FUNCTION UGetMethodsRoute() // Methods defined in route:  GET, POST

   LOCAL cMethods := ''
   LOCAL c   := ''
   LOCAL aRoutes  := UGetRoutes()
   LOCAL cRoute := UGetParams()[ 'route' ]
   LOCAL nI, nLen
   LOCAL aMethods

   IF hb_HHasKey( aRoutes, cRoute )

      c  := aRoutes[ cRoute ][ 'method' ]

      aMethods  := hb_ATokens( c, ',' )
      nLen   := Len( aMethods )

      FOR nI := 1 TO nLen

         IF aMethods[ nI ] != '*'
            IF ! Empty( cMethods )
               cMethods += ', '
            ENDIF
            cMethods += aMethods[ nI ]
         ENDIF

      NEXT

   ENDIF

   RETU cMethods

FUNCTION UGetRoutesList( uCargo )

   LOCAL hRoutes  := UGetRoutes()
   LOCAL aRoutes := {}
   LOCAL nLen   := Len( hRoutes )
   LOCAL nI, cId, aPair, hData

   hb_default( @uCargo, '' )

   IF Empty( uCargo )
      FOR nI := 1 TO nLen
         AAdd( aRoutes, hb_HKeyAt( hRoutes, nI ) )
      NEXT
   ELSE
      FOR nI := 1 TO nLen
         aPair   := hb_HPairAt( hRoutes, nI )
         cId  := aPair[ 1 ]
         hData := aPair[ 2 ]
         IF hData[ 'cargo' ] == uCargo
            AAdd( aRoutes, cId )
         ENDIF
      NEXT
   ENDIF

   RETU aRoutes

FUNCTION UIsRoute( cKey )

   LOCAL nPos

   hb_default( @cKey, '' )

   cKey := Lower( cKey )

   nPos := AScan( oServer:aConfig[ 'Mount' ], {| x | Lower( x ) == cKey } )

   RETU nPos > 0


// ------------------------------------------------------------------- //

FUNCTION UGet( cKey, uDefault )

   hb_default( @cKey, '' )
   hb_default( @uDefault, '' )

   IF Empty( cKey )
      RETU GET
   ENDIF

   hb_HCaseMatch( GET, .F. )

   RETU hb_HGetDef( GET, cKey, uDefault )

// ------------------------------------------------------------------- //

FUNCTION UPost( cKey, uDefault )

   hb_default( @cKey, '' )
   hb_default( @uDefault, '' )

   IF Empty( cKey )
      RETU post
   ENDIF

   hb_HCaseMatch( post, .F. )

   RETU hb_HGetDef( post, cKey, uDefault )

// ------------------------------------------------------------------- //

FUNCTION UCookie( cKey, uDefault )

   hb_default( @cKey, '' )
   hb_default( @uDefault, '' )

   IF Empty( cKey )
      RETU cookie
   ENDIF

   hb_HCaseMatch( cookie, .F. )

   RETU hb_HGetDef( cookie, cKey, uDefault )

// ------------------------------------------------------------------- //

FUNCTION UFiles()

   RETU files

// ------------------------------------------------------------------- //

FUNCTION UServer( cKey, uDefault )

   hb_default( @cKey, '' )
   hb_default( @uDefault, '' )

   IF Empty( cKey )
      RETU server
   ENDIF

   hb_HCaseMatch( server, .F. )

   RETU hb_HGetDef( server, cKey, uDefault )

// ------------------------------------------------------------------- //

STATIC FUNCTION MakeResponse()

   LOCAL cRet, cStatus
   LOCAL  aErrorStatus, nPos, cFile

   IF UGetHeader( "Content-Type" ) == NIL
      UAddHeader( "Content-Type", "text/html" )
   ENDIF
   UAddHeader( "Date", HttpDateFormat( hb_DateTime() ) )

   cRet := iif( server[ "SERVER_PROTOCOL" ] == "HTTP/1.0", "HTTP/1.0 ", "HTTP/1.1 " )
   SWITCH s_nStatusCode
   CASE 100 ;  cStatus := "100 Continue"                        ;  EXIT
   CASE 101 ;  cStatus := "101 Switching Protocols"             ;  EXIT
   CASE 200 ;  cStatus := "200 OK"                              ;  EXIT
   CASE 201 ;  cStatus := "201 Created"                         ;  EXIT
   CASE 202 ;  cStatus := "202 Accepted"                        ;  EXIT
   CASE 203 ;  cStatus := "203 Non-Authoritative Information"   ;  EXIT
   CASE 204 ;  cStatus := "204 No Content"                      ;  EXIT
   CASE 205 ;  cStatus := "205 Reset Content"                   ;  EXIT
   CASE 206 ;  cStatus := "206 Partial Content"                 ;  EXIT
   CASE 300 ;  cStatus := "300 Multiple Choices"                ;  EXIT
   CASE 301 ;  cStatus := "301 Moved Permanently"               ;  EXIT
   CASE 302 ;  cStatus := "302 Found"                           ;  EXIT
   CASE 303 ;  cStatus := "303 See Other"                       ;  EXIT
   CASE 304 ;  cStatus := "304 Not Modified"                    ;  EXIT
   CASE 305 ;  cStatus := "305 Use Proxy"                       ;  EXIT
   CASE 307 ;  cStatus := "307 Temporary Redirect"              ;  EXIT
   CASE 400 ;  cStatus := "400 Bad Request"                     ;  EXIT
   CASE 401 ;  cStatus := "401 Unauthorized"                    ;  EXIT
   CASE 402 ;  cStatus := "402 Payment Required"                ;  EXIT
   CASE 403 ;  cStatus := "403 Forbidden"                       ;  EXIT
   CASE 404 ;  cStatus := "404 Not Found"                       ;  EXIT
   CASE 405 ;  cStatus := "405 Method Not Allowed"              ;  EXIT
   CASE 406 ;  cStatus := "406 Not Acceptable"                  ;  EXIT
   CASE 407 ;  cStatus := "407 Proxy Authentication Required"   ;  EXIT
   CASE 408 ;  cStatus := "408 Request Timeout"                 ;  EXIT
   CASE 409 ;  cStatus := "409 Conflict"                        ;  EXIT
   CASE 410 ;  cStatus := "410 Gone"                            ;  EXIT
   CASE 411 ;  cStatus := "411 Length Required"                 ;  EXIT
   CASE 412 ;  cStatus := "412 Precondition Failed"             ;  EXIT
   CASE 413 ;  cStatus := "413 Request Entity Too Large"        ;  EXIT
   CASE 414 ;  cStatus := "414 Request-URI Too Long"            ;  EXIT
   CASE 415 ;  cStatus := "415 Unsupprted Media Type"           ;  EXIT
   CASE 416 ;  cStatus := "416 Requested Range Not Satisfiable" ;  EXIT
   CASE 417 ;  cStatus := "417 Expectation Failed"              ;  EXIT
   CASE 500 ;  cStatus := "500 Internal Server Error"           ;  EXIT
   CASE 501 ;  cStatus := "501 Not Implemented"                 ;  EXIT
   CASE 502 ;  cStatus := "502 Bad Gateway"                     ;  EXIT
   CASE 503 ;  cStatus := "503 Service Unavailable"             ;  EXIT
   CASE 504 ;  cStatus := "504 Gateway Timeout"                 ;  EXIT
   CASE 505 ;  cStatus := "505 HTTP Version Not Supported"      ;  EXIT
   OTHERWISE
      cStatus := "500 Internal Server Error"
   ENDSWITCH

   cRet += cStatus + CR_LF

   IF s_nStatusCode != 200

      aErrorStatus := uGetServerInfo()[ 'errorstatus' ]

      nPos := AScan( aErrorStatus, {| u | u[ 'status' ] == s_nStatusCode } )

      IF nPos > 0

         s_cResult := ''
         cFile := ''

         IF UIsAjax()
            cFile := aErrorStatus[ nPos ][ 'ajax' ]
         ELSE
            cFile := aErrorStatus[ nPos ][ 'page' ]
         ENDIF

         IF File( UGetServer():cPathHtml + '/'  + cFile )
            s_cResult := ULoadHtml( cFile )
         ELSE
            s_cResult := cFile
         ENDIF

      ELSE
         s_cResult := "<html><body><h1>" + cStatus + "</h1></body></html>"
      ENDIF
   ENDIF
   UAddHeader( "Content-Length", LTrim( Str( Len( s_cResult ) ) ) )
   AEval( s_aHeader, {| x | cRet += x[ 1 ] + ": " + x[ 2 ] + CR_LF } )



   cRet += CR_LF
   // ? cRet
   cRet += s_cResult

   RETURN cRet


STATIC FUNCTION HttpDateFormat( tDate )

   tDate -= hb_UTCOffset() / ( 3600 * 24 )

   RETURN { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }[ DoW( tDate ) ] + ", " + ;
      PadL( Day( tDate ), 2, "0" ) + " " + ;
      { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }[ Month( tDate ) ] + ;
      " " + PadL( Year( tDate ), 4, "0" ) + " " + hb_TToC( tDate, "", "HH:MM:SS" ) + " GMT" // TOFIX: time zone


STATIC FUNCTION HttpDateUnformat( cDate, tDate )

   LOCAL nMonth, tI

   // TODO: support outdated compatibility format RFC2616
   IF Len( cDate ) == 29 .AND. Right( cDate, 4 ) == " GMT" .AND. SubStr( cDate, 4, 2 ) == ", "
      nMonth := AScan( { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", ;
         "Oct", "Nov", "Dec" }, SubStr( cDate, 9, 3 ) )
      IF nMonth > 0
         tI := hb_SToT( SubStr( cDate, 13, 4 ) + PadL( nMonth, 2, "0" ) + SubStr( cDate, 6, 2 ) + StrTran( SubStr( cDate, 18, 8 ), ":", "" ) )
         IF ! Empty( tI )
            tDate := tI + hb_UTCOffset() / ( 3600 * 24 )
            RETURN .T.
         ENDIF
      ENDIF
   ENDIF

   RETURN .F.


/********************************************************************
  Public functions
********************************************************************/
PROC USetStatusCode( nStatusCode )

   s_nStatusCode := nStatusCode

   RETURN



FUNCTION UGetHeader( cType )

   LOCAL nI

   hb_default( @cType, '' )

   IF !Empty( cType )
      IF ( nI := AScan( s_aHeader, {| x | Upper( x[ 1 ] ) == Upper( cType ) } ) ) > 0
         RETURN s_aHeader[ nI, 2 ]
      ENDIF
   ELSE
      RETU s_aHeader
   ENDIF

   RETURN NIL


FUNCTION UAddHeader( cType, cValue )

   LOCAL nI

   IF PCount() == 0
      RETU s_aHeader
   ENDIF

   IF ( nI := AScan( s_aHeader, {| x | Upper( x[ 1 ] ) == Upper( cType ) } ) ) > 0
      s_aHeader[ nI, 2 ] := cValue
   ELSE
      AAdd( s_aHeader, { cType, cValue } )
   ENDIF

   RETURN NIL


PROC URedirect( cURL, nCode )

   LOCAL xRet

   IF nCode == NIL;  nCode := 303
   ENDIF


   IF UIsAjax()

      UAddHeader( "Content-Type", "application/json" )

      xRet := { => }

      xRet[ 'url' ] := cURL
      xRet[ 'target' ] := '_self'

      UWrite( hb_jsonEncode( { 'url' => xRet } ) )

   ELSE

      USetStatusCode( nCode )
      UAddHeader( "Location", cURL )

   ENDIF

   RETURN

FUNCTION UWrite( ... )

   LOCAL aParams  := hb_AParams()
   LOCAL n      := Len( aParams )
   LOCAL i

   IF n == 0
      RETURN NIL
   ENDIF

   FOR i = 1 TO n - 1
      s_cResult += UValtoChar( aParams[ i ] ) + ' '

   NEXT

   s_cResult += UValtoChar( aParams[ n ] )


   RETU NIL

FUNCTION UOsFileName( cFileName )

   IF hb_osPathSeparator() != "/"
      RETURN StrTran( cFileName, "/", hb_osPathSeparator() )
   ENDIF

   RETURN cFileName


FUNCTION UHtmlEncode( cString )

   LOCAL cChar, cResult := ""

   FOR EACH cChar in cString
      DO CASE
      CASE cChar == "<"
         cChar = "&lt;"

      CASE cChar == '>'
         cChar = "&gt;"

      CASE cChar == "&"
         cChar = "&amp;"

      CASE cChar == '"'
         cChar = "&quot;"

      CASE cChar == " "
         cChar = "&nbsp;"
      ENDCASE
      cResult += cChar
   NEXT

   RETURN cResult


FUNCTION UUrlEncode( cString )

   LOCAL nI, cI, cRet := ""

   FOR nI := 1 TO Len( cString )
      cI := SubStr( cString, nI, 1 )
      IF cI == " "
         cRet += "+"
      ELSEIF Asc( cI ) >= 127 .OR. Asc( cI ) <= 31 .OR. cI $ '=&%+'
         cRet += "%" + hb_StrToHex( cI )
      ELSE
         cRet += cI
      ENDIF
   NEXT

   RETURN cRet


FUNCTION UUrlDecode( cString )

   LOCAL nI

   cString := StrTran( cString, "+", " " )
   nI := 1
   DO WHILE nI <= Len( cString )
      nI := hb_At( "%", cString, nI )
      IF nI == 0;  EXIT
      ENDIF
      IF Upper( SubStr( cString, nI + 1, 1 ) ) $ "0123456789ABCDEF" .AND. ;
            Upper( SubStr( cString, nI + 2, 1 ) ) $ "0123456789ABCDEF"
         cString := Stuff( cString, nI, 3, hb_HexToStr( SubStr( cString, nI + 1, 2 ) ) )
      ENDIF
      nI++
   ENDDO

   RETURN cString


FUNCTION ULink( cText, cUrl )
   RETURN '<a href="' + cUrl + '">' + UHtmlEncode( cText ) + '</a>'


FUNCTION UUrlCheckSum( cUrl )
   RETURN cUrl + iif( "?" $ cUrl, "&", "?" ) + "_ucs=" + hb_MD5( session[ "_unique" ] + cUrl + session[ "_unique" ] )


FUNCTION UUrlValidate( cUrl )

   LOCAL nI

   IF cUrl == NIL;  cUrl := server[ "REQUEST_URI" ]
   ENDIF
   IF ( nI := At( "?_ucs=", cUrl ) ) == 0
      nI := At( "&_ucs=", cUrl )
   ENDIF

   RETURN hb_MD5( session[ "_unique" ] + Left( cUrl, nI - 1 ) + session[ "_unique" ] ) == SubStr( cUrl, nI + 6 )




PROC UProcFiles( cFileName, lIndex )

   LOCAL aDir, aF, nI, cI, tDate, tHDate

   IF lIndex == NIL;  lIndex := .F.
   ENDIF


   cFileName := StrTran( cFileName, "//", "/" )


   IF Right( cFilename, 1 ) == '*'
      cFileName := SubStr( cFilename, 1, Len( cFilename ) - 1 )
   ENDIF




   // Security
   IF "/../" $ cFileName
      USetStatusCode( 403 )
      RETURN
   ENDIF



   IF hb_FileExists( uOSFileName( cFileName ) )

      IF hb_HHasKey( server, "HTTP_IF_MODIFIED_SINCE" ) .AND. ;
            HttpDateUnformat( server[ "HTTP_IF_MODIFIED_SINCE" ], @tHDate ) .AND. ;
            hb_FGetDateTime( UOsFileName( cFileName ), @tDate ) .AND. ;
            ( tDate <= tHDate )
         USetStatusCode( 304 )

      ELSEIF hb_HHasKey( server, "HTTP_IF_UNMODIFIED_SINCE" ) .AND. ;
            HttpDateUnformat( server[ "HTTP_IF_UNMODIFIED_SINCE" ], @tHDate ) .AND. ;
            hb_FGetDateTime( UOsFileName( cFileName ), @tDate ) .AND. ;
            ( tDate > tHDate )

         USetStatusCode( 412 )
      ELSE


         IF ( nI := RAt( ".", cFileName ) ) > 0


            SWITCH Lower( SubStr( cFileName, nI + 1 ) )

            CASE "prg"

               UExecutePrg( cFileName )
               RETU

            CASE "htm";   CASE "html"

               UExecuteHtml( cFileName )
               RETU

            CASE "css";                                 cI := "text/css";  EXIT
               // CASE "htm";   CASE "html";                  cI := "text/html";  EXIT
            CASE "txt";   CASE "text";  CASE "asc"
            CASE "c";     CASE "h";     CASE "cpp"
            CASE "hpp";   CASE "log";                   cI := "text/plain";  EXIT
            CASE "rtf";                                 cI := "text/rtf";  EXIT
            CASE "xml";                                 cI := "text/xml";  EXIT
            CASE "bmp";                                 cI := "image/bmp";  EXIT
            CASE "gif";                                 cI := "image/gif";  EXIT
            CASE "jpg";   CASE "jpe";   CASE "jpeg";    cI := "image/jpeg";  EXIT
            CASE "png";                                 cI := "image/png";   EXIT
            CASE "tif";   CASE "tiff";                  cI := "image/tiff";  EXIT
            CASE "djv";   CASE "djvu";                  cI := "image/vnd.djvu";  EXIT
            CASE "ico";                                 cI := "image/x-icon";  EXIT
            CASE "xls";                                 cI := "application/excel";  EXIT
            CASE "doc";                                 cI := "application/msword";  EXIT
            CASE "pdf";                                 cI := "application/pdf";  EXIT
            CASE "ps";    CASE "eps";                   cI := "application/postscript";  EXIT
            CASE "ppt";                                 cI := "application/powerpoint";  EXIT
            CASE "bz2";                                 cI := "application/x-bzip2";  EXIT
            CASE "gz";                                  cI := "application/x-gzip";  EXIT
            CASE "tgz";                                 cI := "application/x-gtar";  EXIT
            CASE "js";                                  cI := "application/x-javascript";  EXIT
            CASE "tar";                                 cI := "application/x-tar";  EXIT
            CASE "tex";                                 cI := "application/x-tex";  EXIT
            CASE "zip";                                 cI := "application/zip";  EXIT
            CASE "midi";                                cI := "audio/midi";  EXIT
            CASE "mp3";                                 cI := "audio/mpeg";  EXIT
            CASE "wav";                                 cI := "audio/x-wav";  EXIT
            CASE "qt";    CASE "mov";                   cI := "video/quicktime";  EXIT
            CASE "avi";                                 cI := "video/x-msvideo";  EXIT
            OTHERWISE
               cI := "application/octet-stream"
            ENDSWITCH
         ELSE

            cI := "application/octet-stream"
         ENDIF
         UAddHeader( "Content-Type", cI )

         IF hb_FGetDateTime( UOsFileName( cFileName ), @tDate )
            UAddHeader( "Last-Modified", HttpDateFormat( tDate ) )
         ENDIF

         UWrite( hb_MemoRead( UOsFileName( cFileName ) ) )


      ENDIF

   ELSEIF hb_DirExists( UOsFileName( cFileName ) )


      IF Right( cFileName, 1 ) != "/"
         URedirect( "http://" + server[ "HTTP_HOST" ] + server[ "SCRIPT_NAME" ] + "/" )
         RETURN
      ENDIF

      IF AScan( { "index.html", "index.htm" }, ;
            {| x | iif( hb_FileExists( UOSFileName( cFileName + X ) ), ( cFileName += X, .T. ), .F. ) } ) > 0
         UAddHeader( "Content-Type", "text/html" )
         UWrite( hb_MemoRead( UOsFileName( cFileName ) ) )
         RETURN
      ENDIF

      IF ! lIndex
         USetStatusCode( 403 )
         RETURN
      ENDIF

      UAddHeader( "Content-Type", "text/html" )

      aDir := Directory( UOsFileName( cFileName ), "D" )



      IF hb_HHasKey( GET, "s" )
         IF GET[ "s" ] == "s"
            ASort( aDir,,, {| X, Y | IF( X[ 5 ] == "D", IF( Y[ 5 ] == "D", X[ 1 ] < Y[ 1 ], .T. ), ;
               IF( Y[ 5 ] == "D", .F., X[ 2 ] < Y[ 2 ] ) ) } )
         ELSEIF GET[ "s" ] == "m"
            ASort( aDir,,, {| X, Y | IF( X[ 5 ] == "D", IF( Y[ 5 ] == "D", X[ 1 ] < Y[ 1 ], .T. ), ;
               IF( Y[ 5 ] == "D", .F., DToS( X[ 3 ] ) + X[ 4 ] < DToS( Y[ 3 ] ) + Y[ 4 ] ) ) } )
         ELSE
            ASort( aDir,,, {| X, Y | IF( X[ 5 ] == "D", IF( Y[ 5 ] == "D", X[ 1 ] < Y[ 1 ], .T. ), ;
               IF( Y[ 5 ] == "D", .F., X[ 1 ] < Y[ 1 ] ) ) } )
         ENDIF
      ELSE
         ASort( aDir,,, {| X, Y | IF( X[ 5 ] == "D", IF( Y[ 5 ] == "D", X[ 1 ] < Y[ 1 ], .T. ), ;
            IF( Y[ 5 ] == "D", .F., X[ 1 ] < Y[ 1 ] ) ) } )
      ENDIF

      UWrite( '<html><body><h1>Index of ' + server[ "SCRIPT_NAME" ] + '</h1><pre>      ' )
      UWrite( '<a href="?s=n">Name</a>                                                  ' )
      UWrite( '<a href="?s=m">Modified</a>             ' )
      UWrite( '<a href="?s=s">Size</a>' + CR_LF + '<hr>' )
      FOR EACH aF IN aDir
         IF Left( aF[ 1 ], 1 ) == "."
         ELSEIF "D" $ aF[ 5 ]
            UWrite( '[DIR] <a href="' + aF[ 1 ] + '/">' + aF[ 1 ] + '</a>' + Space( 50 - Len( aF[ 1 ] ) ) + ;
               DToC( aF[ 3 ] ) + ' ' + aF[ 4 ] + CR_LF )
         ELSE
            UWrite( '      <a href="' + aF[ 1 ] + '">' + aF[ 1 ] + '</a>' + Space( 50 - Len( aF[ 1 ] ) ) + ;
               DToC( aF[ 3 ] ) + ' ' + aF[ 4 ] + Str( aF[ 2 ], 12 ) + CR_LF )
         ENDIF
      NEXT
      UWrite( "<hr></pre></body></html>" )
   ELSE

      USetStatusCode( 404 )
   ENDIF

   RETURN

// Difference between UExecuteHtml and ULoadHtml is:
// UExecuteHtml cFileName is with all path
// ULoadHtml cFileName is only filename and path is UGetServer():cPathHtml

FUNCTION UExecuteHtml( cFileName )

   LOCAL cCode

   IF !File( cFileName )
      RETU NIL
   ENDIF

   cCode :=  hb_MemoRead( UOsFileName( cFileName ) )

   UReplaceBlocks( @cCode, "{{", "}}", NIL )

   cFilePrg := hb_FNameNameExt( cFileName )

   UInlinePRG( @cCode )

   UWrite( cCode )

   RETU NIL

FUNCTION UExecutePrg( cFileName, lWrite, cCode, cCodePP )

   LOCAL oHrb, pSym
   LOCAL cResult := ''

   hb_default( @lWrite, .T. )
   hb_default( @cCode, '' )
   hb_default( @cCodePP, '' )


   IF !File( cFileName )
      RETU NIL
   ENDIF

   cCode :=  hb_MemoRead( UOsFileName( cFileName ) )

   oHrb := UCompile( cCode, @cCodePP )


   IF ! Empty( oHrb )

// mh_startmutex()

// pSym := hb_hrbLoad( HB_HRB_BIND_OVERLOAD, oHrb )
      pSym := hb_hrbLoad( 0x1, oHrb )     // HB_HRB_BIND_LOCAL

// mh_endmutex()

      cResult := hb_hrbDo( pSym )

   ENDIF

   IF lWrite
      UWrite( cResult )
   ENDIF

   RETU if( lWrite, NIL, cResult )

PROC UProcInfo()

   LOCAL cI

   UWrite( '<h1>Info</h1>' )

   UWrite( '<h2>Platform</h2>' )
   UWrite( '<table border=1 cellspacing=0>' )
   UWrite( '<tr><td>OS</td><td>' + UHtmlEncode( OS() ) + '</td></tr>' )
   UWrite( '<tr><td>Harbour</td><td>' + UHtmlEncode( Version() ) + '</td></tr>' )
   UWrite( '<tr><td>Build date</td><td>' + UHtmlEncode( hb_BuildDate() ) + '</td></tr>' )
   UWrite( '<tr><td>Compiler</td><td>' + UHtmlEncode( hb_Compiler() ) + '</td></tr>' )
   UWrite( '</table>' )

   UWrite( '<h2>Capabilities</h2>' )
   UWrite( '<table border=1 cellspacing=0>' )
   cI := ""
   AEval( rddList(), {| X | cI += iif( Empty( cI ), "", ", " ) + X } )
   UWrite( '<tr><td>RDD</td><td>' + UHtmlEncode( cI ) + '</td></tr>' )
   UWrite( '</table>' )

   UWrite( '<h2>Variables</h2>' )

   UWrite( '<h3>server</h3>' )
   UWrite( '<table border=1 cellspacing=0>' )
   AEval( ASort( hb_HKeys( server ) ), {| X | UWrite( '<tr><td>' + X + '</td><td>' + UHtmlEncode( hb_CStr( server[ X ] ) ) + '</td></tr>' ) } )
   UWrite( '</table>' )

   IF !Empty( get )
      UWrite( '<h3>get</h3>' )
      UWrite( '<table border=1 cellspacing=0>' )
      AEval( ASort( hb_HKeys( get ) ), {| X | UWrite( '<tr><td>' + X + '</td><td>' + UHtmlEncode( hb_CStr( GET[ X ] ) ) + '</td></tr>' ) } )
      UWrite( '</table>' )
   ENDIF

   IF !Empty( post )
      UWrite( '<h3>post</h3>' )
      UWrite( '<table border=1 cellspacing=0>' )
      AEval( ASort( hb_HKeys( post ) ), {| X | UWrite( '<tr><td>' + X + '</td><td>' + UHtmlEncode( hb_CStr( post[ X ] ) ) + '</td></tr>' ) } )
      UWrite( '</table>' )
   ENDIF

   RETURN


// ----------------------------------------------------------------------------//
/*
 nSecs = -1 Delete cookie
 nSecs =  0 Cookie live during session browse
 nSecs >  0 Seconds of cookie
*/


FUNCTION USetCookie( cKey, cValue, nSecs, cPath, cDomain, lHttps, lOnlyHttp, cSameSite )

   LOCAL cCookie := ''

   hb_default( @cKey, 'SESSID' )
   hb_default( @cValue, '' )
   hb_default( @nSecs, 0 )   // Session will expire in Seconds 60 * 60 = 3600 1hour
   hb_default( @cPath, '/' )
   hb_default( @cDomain, '' )
   hb_default( @lHttps, .F. )
   hb_default( @lOnlyHttp, .T. )
   hb_default( @cSameSite, 'Lax' )  // none, Strict


   // we build the cookie
   cCookie += cKey + '=' + cValue + ';'

   DO CASE
   CASE nSecs == -1
      cCookie += 'expires=' + 'Thu, 01 Jan 1970 00:00:00 GMT;'
   CASE nSecs == 0
// cCookie -> No existe tiempo
   OTHERWISE
// cCookie += 'expires=' + 'Thu, 10 Oct 2023 13:00:00 GMT;'
      cCookie += 'expires=' + UCookieExpires( nSecs ) + ' GMT;'
   ENDCASE

   cCookie += 'path=' + cPath + ';'

   IF ! Empty( cDomain )
      cCookie += 'domain=' + cDomain + ';'
   ENDIF

   IF lOnlyHttp
      cCookie += 'HttpOnly;'
   ENDIF

   cCookie += 'SameSite=' + cSameSite + ';'


   IF UServer()[ 'HTTPS' ]
      cCookie += 'Secure'
   ENDIF

// cCookie += 'Secure'


   UAddHeader( "Set-Cookie", cCookie )

   RETU NIL

FUNCTION UGetCookie( cKey )

   LOCAL cSID := ''

   hb_default( @cKey, 'SESSID' )

   cSID := hb_HGetDef( cookie, cKey, ''  )


   RETU cSID

// ----------------------------------------------------------------//

FUNCTION UGetIP()

   RETU if( ValType( server ) == 'H', server[ "REMOTE_ADDR" ], '' )

// ----------------------------------------------------------------//
// CookieExpire( nSecs ) builds the time format for the cookie
// Using this model: 'Sun, 09 Jun 2019 16:14:00'

FUNCTION UCookieExpires( nSecs )

   LOCAL tNow := hb_DateTime()
   LOCAL tExpire   // TimeStampp
   LOCAL cExpire   // TimeStamp to String

   hb_default( @nSecs, 60 ) // 60 seconds for this test

   tExpire = hb_NToT( ( hb_TToN( tNow ) * 86400 - hb_UTCOffset() + nSecs ) / 86400 )

   cExpire = CDoW( tExpire ) + ', '
   cExpire += AllTrim( Str( Day( hb_TToD( tExpire ) ) ) ) + ;
      ' ' + CMonth( tExpire ) + ' ' + AllTrim( Str( Year( hb_TToD( tExpire ) ) ) ) + ' '
   cExpire += AllTrim( Str( hb_Hour( tExpire ) ) ) + ':' + AllTrim( Str( hb_Minute( tExpire ) ) ) + ;
      ':' + AllTrim( Str( hb_Sec( tExpire ) ) )

   RETURN cExpire


// ----------------------------------------------------------------------------//

FUNCTION UMsgError( cMsg )

   LOCAL cHtml := '<h2 class="uerrortitletop" >=> System Error</h2><hr>'

   RETU cMsg

// ----------------------------------------------------------------------------//

FUNCTION ULoadPrg( hSrv, cPrg )

   LOCAL cFile  := hSrv[ 'pathhtml' ] + '/'  + cPrg
   LOCAL aRequest := { => }
   LOCAL cResponse := ''
   LOCAL oError
   LOCAL lError  := .F.
   LOCAL cInfoCode := ''
   LOCAL cError := ''
   LOCAL cCode := ''
   LOCAL cCodePP := ''
   LOCAL cArgs

   cFileHtml := cPrg

   IF File( cFile )

      BEGIN SEQUENCE WITH {| oErr | oError := oErr, Break( oErr ) }

         cResponse := UExecutePrg( cFile, .F., @cCode, @cCodePP )

      RECOVER USING oError

         lError := .T.

         cError      := '<b>File: </b>' + hb_FNameNameExt( cPrg )
         cError      += '<br><b>Error: </b>' + oError:description

         IF !Empty( oError:operation )
            cError += '<br><b>Operation: </b>' + oError:operation
         ENDIF

         cArgs := ''

         IF ValType( oError:args ) == "A"
            AEval( oError:args, {| X, Y | cArgs += LTrim( Str( Y ) ) + ": " + AllTrim( hb_CStr( X ) ) + '<br>' } )
            cError += '<br><b>Arguments: </b><br>' +  cArgs
         ENDIF

      END SEQUENCE

      IF ! lError

         aRequest[ 'success' ]  := .T.
         aRequest[ 'html' ]  := cResponse
         aRequest[ 'msg' ]   := ''

      ELSE

         aRequest[ 'success' ]  := .F.
         aRequest[ 'html' ]  := ''
         aRequest[ 'msg' ]   := cError

      ENDIF

   ELSE

      aRequest[ 'success' ]  := .F.
      aRequest[ 'html' ]  := ''
      aRequest[ 'msg' ]   := "Don't exist prg file => " + cPrg


   ENDIF

   cFileHtml := ''

// retu cHtml

   RETU aRequest

// ----------------------------------------------------------------------------//

FUNCTION ULoadPage( hSrv, cHtml )

   LOCAL cFile  := hSrv[ 'pathhtml' ] + '/'  + cHtml
   LOCAL aRequest := { => }
   LOCAL cCode  := ''

   cFileHtml := cHtml

   IF File( cFile )

      cCode := hb_MemoRead( cFile )

      UReplaceBlocks( @cCode, "{{", "}}" )

      cFilePrg := hb_FNameNameExt( cFile )

      UInlinePrg( @cCode )

      aRequest[ 'success' ]  := .T.
      aRequest[ 'html' ]  := cCode
      aRequest[ 'msg' ]   := ''

   ELSE

      aRequest[ 'success' ]  := .F.
      aRequest[ 'html' ]  := ''
      aRequest[ 'msg' ]   := "Don't exist html file => " + cHtml


   ENDIF

   cFileHtml := ''



// retu cHtml

   RETU aRequest

// ----------------------------------------------------------------------------//

FUNCTION ULoadHtml( cFileHtml, ... )

   LOCAL cFile
   LOCAL aRequest := { => }
   LOCAL cCode  := ''

// hb_default( @lPathRelative, .T. )



#ifdef __PLATFORM__WINDOWS
   cFile  := UGetServer():cPathHtml + '/'  + cFileHtml
#else 
   cFile  := StrTran( cFileHtml, '\',  '/' )
   cFile  := UGetServer():cPathHtml + '/' + cFile
#endif


   IF File( cFile )

      UDefError()

      cCode := hb_MemoRead( cFile )

      UReplaceBlocks( @cCode, "{{", "}}", NIL, ... )

      cFilePrg := hb_FNameNameExt( cFile )

      UInlinePrg( @cCode, NIL, ... )


      IF !Empty( UGetError() )

         cCode := ''

      ENDIF


   ELSE

      UDo_Error( 'ULoadHtml() File not found... ' + cFileHtml, NIL, 100 )

   ENDIF

   RETU cCode

// ----------------------------------------------------------------------------//

FUNCTION UDefError( u )

   hb_default( @u, '' )
   cProcError := u
   RETU NIL

FUNCTION UGetError() ; RETU cProcError

// ----------------------------------------------------------------------------//

FUNCTION UGetCfg() ; RETU hCfg

// ----------------------------------------------------------------------------//
// --- ERROR SYSTEM
// ----------------------------------------------------------------------------//

FUNCTION UDo_ErrorMsg( cDescription, cSubsystem )

   UDo_Error( cDescription, cSubsystem, 666 )
   RETU NIL

FUNCTION UDo_Error( cDescription, cSubsystem, nSubCode )

   LOCAL oError := ErrorNew()

   hb_default( @cSubsystem, "httpd2" )
   hb_default( @nSubCode, 0 )

   oError:Subsystem     := cSubsystem
   oError:SubCode    := nSubCode
   oError:Severity      := 2 // ES_ERROR
   oError:Description  := cDescription
   Eval( ErrorBlock(), oError )

   RETURN NIL

// ----------------------------------------------------------------------------//



FUNCTION UErrorHandler( oErr, oServer, cError )

   cError := ''



   IF     oErr:genCode == EG_ZERODIV;  RETURN 0
   ELSEIF oErr:genCode == EG_LOCK;     RETURN .T.
   ELSEIF ( oErr:genCode == EG_OPEN .AND. oErr:osCode == 32 .OR. ;
         oErr:genCode == EG_APPENDLOCK ) .AND. oErr:canDefault
      NetErr( .T. )
      RETURN .F.
   ENDIF
   cError := UErrorWeb()

   cError += UErrorGetDescription( oErr )

   cError += UErrorGetSys()


   oServer:LogError( UGetErrorLog( oErr ) )


   IF ValType( oServer:aConfig[ 'ErrorBloc' ] ) == 'B'


      Eval( oServer:aConfig[ 'ErrorBloc' ], oErr, UGetErrorLog( oErr ) )

   ENDIF

   IF oErr != NIL  // Dummy check to avoid unreachable code warning for RETURN NIL

      Break( oErr )

   ENDIF

   RETURN ''


// ----------------------------------------------------------------------------//

STATIC FUNCTION UGetErrorLog( oErr, lWeb )

   LOCAL cRet, nI, cNewLine

// LOCAL ci, apar,nj, xi

   hb_default( @cNewLine, hb_osNewLine() )
   hb_default( @lWeb, .F. )

   cNewLine := if( lWeb, '<br>', hb_osNewLine() )


   cRet := "ERRORLOG =========================================" + cNewLine
   cRet += "Error: " + oErr:subsystem + "/" + ErrDescCode( oErr:genCode ) + "(" + LTrim( Str( oErr:genCode ) ) + ") " + ;
      LTrim( Str( oErr:subcode ) ) + cNewLine

   IF !Empty( oErr:filename );      cRet += "File: " + oErr:filename + cNewLine
   ENDIF

   IF !Empty( oErr:description );   cRet += "Description: " + oErr:description + cNewLine
   ENDIF

   IF !Empty( oErr:operation );     cRet += "Operation: " + oErr:operation + cNewLine
   ENDIF

   IF !Empty( oErr:osCode );        cRet += "OS error: " + LTrim( Str( oErr:osCode ) ) + cNewLine
   ENDIF

   IF ValType( oErr:args ) == "A"
      cRet += "Arguments:" + cNewLine
      AEval( oErr:args, {| X, Y | cRet += Str( Y, 5 ) + ": " + hb_CStr( X ) + cNewLine } )
      cRet += cNewLine
   ENDIF

   cRet += "Stack:" + cNewLine

   nI := 2

// #if 0
   DO WHILE ! Empty( ProcName( ++nI ) )
      cRet += "    " + ProcName( nI ) + "(" + LTrim( Str( ProcLine( nI ) ) ) + ")" + cNewLine
   ENDDO
/*
#else
  DO WHILE ! EMPTY(PROCNAME(++nI))
    cI := "    " + PROCNAME(nI) + "(" + LTRIM(STR(PROCLINE(nI))) + ")"
    cI := PADR(cI, MAX(32, LEN(cI) + 1))
    cI += "("
    aPar := __dbgvmParLList(nI)
    FOR nJ := 1 TO LEN(aPar)
      cI += cvt2str(aPar[nJ])
      IF nJ < LEN(aPar);  cI += ", "
      ENDIF
    NEXT
    cI += ")"
    nJ := LEN(aPar)
    DO WHILE VALTYPE(xI := __dbgvmVarLGet(nI, ++nJ)) != "S"
      cI += ", " + cvt2str(xI)
    ENDDO
    xI := NIL
    cRet += cI + cNewLine
  ENDDO
#endif
*/

   cRet += cNewLine

   // cRet += "Executable:  " + HB_PROGNAME() + cNewLine
   cRet += "Versions:" + cNewLine
   cRet += "  OS: " + OS() + cNewLine
   cRet += "  Harbour: " + Version() + ", " + hb_BuildDate() + cNewLine
   cRet += "  UHttpd2: " + UVersion()   + cNewLine

   IF hb_IsFunction( 'TWebVersion' )
      cRet += '<br><b>TWeb: </b>' + Eval( &( '{|| TWebVersion()}' ) ) + cNewLine
   ENDIF


   cRet += cNewLine

   IF oErr:genCode != EG_MEM
      cRet += "Database areas:" + cNewLine
      cRet += "    Current: " + LTrim( Str( Select() ) ) + "  " + Alias() + cNewLine

      BEGIN SEQUENCE WITH {| o | Break( o ) }
         IF Used()
            cRet += "    Filter: " + dbFilter() + cNewLine
            cRet += "    Relation: " + dbRelation() + cNewLine
            cRet += "    Index expression: " + ordKey( ordSetFocus() ) + cNewLine
            cRet += cNewLine
            BEGIN SEQUENCE WITH {| o | Break( o ) }
               FOR nI := 1 TO FCount()
                  cRet += Str( nI, 6 ) + " " + PadR( FieldName( nI ), 14 ) + ": " + hb_ValToExp( FieldGet( nI ) ) + cNewLine
               NEXT
            RECOVER
               cRet += "!!! Error reading database fields !!!" + cNewLine
            END SEQUENCE
            cRet += cNewLine
         ENDIF
      RECOVER
         cRet += "!!! Error accessing current workarea !!!" + cNewLine
      END SEQUENCE

      FOR nI := 1 TO 250
         BEGIN SEQUENCE WITH {| o | Break( o ) }
            IF Used()
               dbSelectArea( nI )
               cRet += Str( nI, 6 ) + " " + rddName() + " " + PadR( Alias(), 15 ) + ;
                  Str( RecNo() ) + "/" + Str( LastRec() ) + ;
                  iif( Empty( ordSetFocus() ), "", " Index " + ordSetFocus() + "(" + LTrim( Str( ordNumber() ) ) + ")" ) + cNewLine
               dbCloseArea()
            ENDIF
         RECOVER
            cRet += "!!! Error accessing workarea number: " + Str( nI, 4 ) + "!!!" + cNewLine
         END SEQUENCE
      NEXT
      cRet += cNewLine
   ENDIF

   RETURN cRet

// ----------------------------------------------------------------------------//

FUNCTION UErrorWeb()

   LOCAL cStyle := ''

   TEXT TO cStyle
   <html>
   <head>
     <title> UT Error </title>
     <link rel="icon" type="image/x-icon" href="files/uhttpd2/images/favicon.ico" >
     <link href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css" rel="stylesheet" >
   </head>
   <style>

   body { margin:20px }
   
   .uerrorcontent {
      padding: 5px;
      padding-top: 0;
    }

   .uerrorcontent pre {
	  margin-top: 0px;
    }



   .uerrorcode {
      border: 1px solid black;
      overflow:auto;
      box-shadow: 5px 5px 5px gray;
    }

   .uerrortable {
      width:100 % ;
    }

   .uerrortablelabel {
      width: 0;
      min-width: fit-content;
      padding-right: 10px;
      font-weight: bold !important;
    }

   .uerrortablefont {
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", "Liberation Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
      font-size: 1rem;
      font-weight: 400;
    }

   .uerrortitle {
      padding-left: 5px;
      background-color: gray;
      color: white;
      border-bottom: 1px solid black;
      font-family: arial;
      font-size: 14px;
    }

   .uerrorsource {
      position: relative;
      bottom: 10px;
      top: 0px;
      height: 100% ;
      padding: 5px;
      left: 0;
      right: 0;
    }

   .uerrorsource pre {
      margin-top:0;
      margin-bottom:0;
    }


   .uerrorsys {
      bottom: 0;
      border-top: 1px solid gray;
      width: 100% ;
      padding: 5px;
      font-size: small;
      box-sizing: border-box;
      background-color: white;
      left: 0;
    }

   .uerrortitletop {
      font-family: Verdana;
      margin-bottom:5px;
    }
	
   .uerrortitletop span {
		margin-left: 10px;
		line-height: 30px;	
	}

   .uerrorimg {
      width: 30px;
      margin - top: - 4px;
      margin - right: 5px;
      float: left;
    }

   </style>
   <body>
   ENDTEXT


   IF ! UIsAjax()
      cStyle += '<h3 class="uerrortitletop"><img class="uerrorimg" src="data:image/png;base64, ' + UImgAlert() + '"><span>System Error</span></h3><hr>'
      cStyle += '<div class="uerrorcontent" style="padding:5px;">'
   ELSE
      cStyle += '<div class="uerrorcontent" style="padding:0px;">'
   ENDIF
   
   RETU cStyle

FUNCTION UErrorLin( cLabel, cValue )

   RETU '<tr><td class="uerrortablelabel uerrortablefont">' + cLabel + '</td><td class="uerrortablefont">' + cValue + '</td></tr>'

FUNCTION UErrorGetDescription( oErr, cInfoCode, cCargo )

   LOCAL cRet := ''
   LOCAL cNewLine := '<br>'
   LOCAL nI
   LOCAL cStack := ''
   LOCAL cI := ''
   LOCAL cProc := ''
   LOCAL lExit := .F.
   LOCAL cArgs := ''

   hb_default( @cCargo, '' )

   IF oErr:subcode == 666

      cRet += '<table class="uerrortable">'

      IF !Empty( oErr:description );   cRet += UErrorLin( 'Description', oErr:description )
      ENDIF

      cRet += '</table>'
      cRet += '</div>'

      RETU cRet
   ENDIF

   cRet += '<table class="uerrortable">'

   IF !Empty( cFilePrg );         cRet += UErrorLin( 'Execute', cFilePrg  )
   ENDIF

   IF !Empty( cCargo )
      cRet += '<tr><td colspan="2">' + cCargo + '</td></tr>'
   ENDIF

   cRet += UErrorLin( 'Error', oErr:subsystem + "/" + ErrDescCode( oErr:genCode ) + "(" + LTrim( Str( oErr:genCode ) ) + ") " + LTrim( Str( oErr:subcode ) ) )

   IF !Empty( oErr:filename );      cRet += UErrorLin( 'File', oErr:filename )
   ENDIF

   IF !Empty( oErr:description );   cRet += UErrorLin( 'Description', oErr:description )
   ENDIF

   IF !Empty( oErr:operation );     cRet += UErrorLin( 'Operation', oErr:operation )
   ENDIF


   IF ValType( oErr:args ) == "A"
      AEval( oErr:args, {| X, Y | cArgs += LTrim( Str( Y ) ) + ": " + AllTrim( hb_CStr( X ) ) + cNewLine } )
      cRet += UErrorLin( 'Arguments', cArgs )
   ENDIF

   IF !Empty( oErr:osCode );        cRet += UErrorLin( 'OS Error',  LTrim( Str( oErr:osCode ) ) )
   ENDIF

   nI := 2


   DO WHILE ! Empty( ProcName( ++nI ) ) .AND. !lExit

      cProc := ProcName( nI )

      IF At( '(b)UWEBAPI', cProc ) > 0 .OR. ;
            At( '(b)UHTTPD2_ROUTE', cProc ) > 0
         lExit := .T.
      ELSE
         cStack += cProc + "(" + LTrim( Str( ProcLine( nI ) ) ) + ")" + cNewLine
      ENDIF

   ENDDO

   //IF !Empty( cStack ) .AND. oErr:subcode != 100
   //   cRet += UErrorLin( 'Stack', cStack )
   //ENDIF

// ---------------------------------------------------

   IF !Empty( cInfoCode )
      cRet += '<tr><td colspan="2">' + cInfoCode + '</td></tr>'
   ENDIF

   cRet += '</table>'
   cRet += '</div>'

   IF oErr:subcode == 100
      cRet += '<hr>'
   ENDIF

   RETU cRet


// ----------------------------------------------------------------------------//

FUNCTION UErrorGetSys()

   LOCAL cRet := ''

   cRet += '</div>'
   cRet += '<div class="uerrorsys" '
   cRet += 'style="position:' + IF( UIsAjax(), 'unset;', 'fixed;' ) + '" '
   cRet += '>'
// cRet += '<b>OS: </b>' + OS()
   cRet += '<b>Harbour: </b>' + Version() // + ", " + HB_BUILDDATE()
   cRet += '<br><b>UHttpd2: </b>' + UVersion()

   IF hb_IsFunction( 'TWebVersion' )
      cRet += '<br><b>TWeb: </b>' + Eval( &( '{|| TWebVersion()}' ) )
   ENDIF


   cRet += '</div>'

   RETU cRet

// ----------------------------------------------------------------------------//

FUNCTION UErrorGetCode( cCode, nLineError )

   LOCAL cRet := ''
   LOCAL aLines :=  hb_ATokens( cCode, Chr( 10 ) )
   LOCAL cInfo  := ''
   LOCAL cLine  := ''
   LOCAL n

   FOR n = 1 TO Len( aLines )

      cLine := aLines[ n ]

      cLine := UHtmlEncode( cLine )
      cLine := StrTran( cLine, Chr( 9 ), '&nbsp;&nbsp;&nbsp;' )

      IF nLineError == n
         cInfo += '<b>' + StrZero( n, 4 ) + ' <span class="mc_line_error"  style="background-color:#e15959;color:white;">' + cLine + '</span></b>'
      ELSE
         cInfo += StrZero( n, 4 ) + ' ' + cLine
      ENDIF

   NEXT

   cRet += '<div class="uerrorcode">'
   cRet += ' <div class="uerrortitle">' + 'Source Code' + '</div>'
   cRet += ' <div class="uerrorsource"><pre>' + cInfo + '</pre></div>'
   cRet += '</div>'

   RETU cRet


// ----------------------------------------------------------------------------//

STATIC FUNCTION ErrDescCode( nCode )

   LOCAL cI := NIL

   IF nCode > 0 .AND. nCode <= 41
      cI := { "ARG", "BOUND", "STROVERFLOW", "NUMOVERFLOW", "ZERODIV", "NUMERR", "SYNTAX", "COMPLEXITY", ; // 1,  2,  3,  4,  5,  6,  7,  8
         NIL, NIL, "MEM", "NOFUNC", "NOMETHOD", "NOVAR", "NOALIAS", "NOVARMETHOD", ; // 9, 10, 11, 12, 13, 14, 15, 16
         "BADALIAS", "DUPALIAS", NIL, "CREATE", "OPEN", "CLOSE", "READ", "WRITE", ; // 17, 18, 19, 20, 21, 22, 23, 24
         "PRINT", NIL, NIL, NIL, NIL, "UNSUPPORTED", "LIMIT", "CORRUPTION", ; // 25, 26 - 29, 30, 31, 32
         "DATATYPE", "DATAWIDTH", "NOTABLE", "NOORDER", "SHARED", "UNLOCKED", "READONLY", "APPENDLOCK", ; // 33, 34, 35, 36, 37, 38, 39, 40
         "LOCK"    }[ nCode ]                                                                                            // 41
   ENDIF

   RETURN IF( cI == NIL, "", "EG_" + cI )

// ----------------------------------------------------------------------------//


STATIC FUNCTION cvt2str( xI, lLong )

   LOCAL cValtype, cI, xJ

   cValtype := ValType( xI )
   lLong := ! Empty( lLong )
   IF     cValtype == "U"
      RETURN IF( lLong, "[U]:NIL", "NIL" )
   ELSEIF cValtype == "N"
      RETURN IF( lLong, "[N]:" + Str( xI ), LTrim( Str( xI ) ) )
   ELSEIF cValtype $ "CM"
      IF Len( xI ) <= 260
         RETURN IF( lLong, "[" + cValtype + LTrim( Str( Len( xI ) ) ) + "]:", "" ) + '"' + xI + '"'
      ELSE
         RETURN IF( lLong, "[" + cValtype + LTrim( Str( Len( xI ) ) ) + "]:", "" ) + '"' + Left( xI, 100 ) + '"...'
      ENDIF
   ELSEIF cValtype == "A"
      RETURN "[A" + LTrim( Str( Len( xI ) ) ) + "]"
   ELSEIF cValtype == "H"
      RETURN "[H" + LTrim( Str( Len( xI ) ) ) + "]"
   ELSEIF cValtype == "O"
      cI := ""
      IF __objHasMsg( xI, "ID" )
         xJ := xI:ID
         IF ValType( xJ ) != "O";  cI += ",ID=" + cvt2str( xJ )
         ENDIF
      ENDIF
      IF __objHasMsg( xI, "nID" )
         xJ := xI:nID
         IF ValType( xJ ) != "O";  cI += ",NID=" + cvt2str( xJ )
         ENDIF
      ENDIF
      IF __objHasMsg( xI, "xValue" )
         xJ := xI:xValue
         IF ValType( xJ ) != "O";  cI += ",XVALUE=" + cvt2str( xJ )
         ENDIF
      ENDIF
      RETURN "[O:" + xI:ClassName + cI + "]"
   ELSEIF cValtype == "D"
      RETURN IF( lLong, "[D]:", "" ) + DToC( xI )
   ELSEIF cValtype == "L"
      RETURN IF( lLong, "[L]:", "" ) + IF( xI, ".T.", ".F." )
   ELSEIF cValtype == "P"
      RETURN IF( lLong, "[P]:", "" ) + "0p" + hb_NumToHex( xI )
   ELSE
      RETURN  "[" + cValtype + "]"   // BS,etc
   ENDIF

   RETURN NIL

// --- MULTIPART -------------------------------------------------------------- //
// https://developer.mozilla.org/es/docs/Web/HTTP/Basics_of_HTTP/MIME_types#multipartform-data

STATIC FUNCTION UParseMultipart( cRaw, hPost, aFiles )

   LOCAL nStart  := 0
   LOCAL hServer  := UServer()
   LOCAL lExit  := .F.
   LOCAL cBoundary, nPos, cBlock, cTag, nBoundary, nIni, nEnd, nOffset

   hPost  := { => }
   aFiles  := {}

// Buscaremos la bandera

   IF ! hb_HHasKey( hServer, "CONTENT_TYPE" )
      RETU NIL
   ENDIF

   cTag := 'multipart/form-data; boundary='

   IF ( nPos := At( cTag, hServer[ 'CONTENT_TYPE' ]  ) ) == 0
      RETU NIL
   ENDIF

   nPos := nPos + Len( cTag )

   cBoundary := '--' + SubStr( hServer[ 'CONTENT_TYPE' ], nPos )
   nBoundary := Len( cBoundary )

// Procesamos todo el RAW y buscamos la/s bandera/s


   WHILE ( nStart := hb_At( cBoundary, cRaw ) ) != 0 .AND. !lExit

      nIni := nStart + nBoundary
      nEnd := hb_At( cBoundary, cRaw, nIni )

      IF nEnd > 0

         nOffset := nEnd - nIni
         cBlock  := SubStr( cRaw, nIni, nOffSet )

// Cada Bloque del multipart lo procesaremos

         UParseMultipartItem( cBlock, @hPost, @aFiles )

         cRaw := SubStr( cRaw, nEnd )

      ELSE

         lExit := .T.

      ENDIF

   END


   RETU NIL

STATIC FUNCTION UParseMultipartItem( cBlock, hPost, aFiles )

   LOCAL cTag   := 'Content-Type:'
   LOCAL lIsFile

// Chequearemos los tags del bloque. Si tiene el tag Content-Type: es que se
// trata de una fichero.
// Cada bloque podra contener un valor dato o un valor de tipo fichero.
// Los datos los pondremos en el Hash UPost y el fichero en un array UFiles

   cBlock  := AllTrim( cBlock )
   lIsFile := hb_At( cTag, cBlock ) > 0

   IF lIsFile
      UParseMultiPartFile( @cBlock, @aFiles )  // Aqui pasarem de param aFiles
   ELSE
      UParseMultiPartData( @cBlock, @hPost )  // Aqui pasarem de param hPost
   ENDIF


   RETU NIL


/* Block example to parse.... */
/*
Content-Disposition: form-data; name="file"; filename="readme2.txt"

Content-Type: text/plain

Hi readme [2].

*/

STATIC FUNCTION UParseMultiPartFile( cBlock, aFiles )

   LOCAL nEnd := hb_At( Chr( 13 ), cBlock )
   LOCAL uValue
   LOCAL cInfo, cMime, aInfo, nPos, nHandle
   LOCAL hFile := { => }
   LOCAL oServer
   LOCAL lError := .F.
   
   IF !hb_DirExists( UGetServer():cPathTmp )	  
      hb_DirBuild( UGetServer():cPathTmp )
	  IF !hb_DirExists( UGetServer():cPathTmp )
		   _t( "ERROR creating .tmp folder " + UGetServer():cPathTmp )
           RETU .F.
	  ENDIF
   ENDIF

   IF nEnd > 0

// Separamos la parte de cabecera de tags y la de valor

      cInfo := SubStr( cBlock, 1, nEnd - 1 )

      aInfo := hb_ATokens( cInfo, ';' )

// hFile[ 'Content-Disposition' ]  := UInfo2Tag( aInfo, 'Content-Disposition:' )
// hFile[ 'name' ]   := UInfo2Tag( aInfo, ' name=' )   // Alert space
      hFile[ 'success' ]   := .F.
      hFile[ 'filename' ]  := UInfo2Tag( aInfo, ' filename=' )  // Alert space
      hFile[ 'ext' ]    := Lower( hb_FNameExt( hFile[ 'filename' ] ) )
      hFile[ 'tmp_name' ]  := ''
      hFile[ 'error' ]   := ''
      hFile[ 'size' ]   := 0

      IF ( nPos := At( '.', hFile[ 'ext' ] ) ) > 0
         hFile[ 'ext' ] := SubStr( hFile[ 'ext' ], nPos + 1 )
      ENDIF



// Recuperamos MIME y valor

      cMime := SubStr( cBlock, nEnd + 1 )

      nEnd := hb_At( Chr( 13 ), cMime )

      IF nEnd > 0

// Recupera info tags

         cInfo := AllTrim( SubStr( cMime, 1, nEnd - 1 ) )

         hFile[ 'Content-Type' ] := UInfo2Tag( cInfo, 'Content-Type:' )



// Recupera value raw

         uValue := AllTrim( SubStr( cMime, nEnd + 1 ) )

         IF Right( uValue, 2 ) == Chr( 13 ) + Chr( 10 )
            uValue := SubStr( uValue, 1, Len( uValue ) - 2 )
         ENDIF

// Valid files ------------------------------------------

// Es un fichero permitido ? /

         IF !Empty(  UGetServer():aFilesAllowed )
            IF AScan( UGetServer():aFilesAllowed, {| x | Lower( x ) == hFile[ 'ext' ] } ) == 0
               hFile[ 'error' ] := 'Forbidden file type: ' +  hFile[ 'ext' ]
               lError := .T.
            ENDIF
         ENDIF

// Exceded Size ?

         IF  ! lError .AND. ( Len( uValue ) /  1024 ) > UGetServer():nfile_max_size
            hFile[ 'size' ]  := Len( uValue )
            hFile[ 'error' ] := 'File exceeds the maximum allowed: ' + LTrim( Str( Len( uValue ) ) )
            lError := .T.
         ENDIF

// ------------------------------------------------------

         IF ! lError

            hFile[ 'tmp_name' ] := TempFile( UGetServer():cPathTmp, hFile[ 'ext' ] )


// Save to tmp folder --------------------

            nHandle := FCreate( hFile[ 'tmp_name' ]  )

            FWrite( nHandle, uValue )

            hFile[ 'size' ] := FSeek( nHandle, 0, FS_END )

            FClose( nHandle )

            hFile[ 'success' ]   := .T.


// Check for Garbage Collector -----------

            oServer := UGetServer()

            hb_mutexLock( oServer:hmtxFiles )


            nFiles_Size += ( hFile[ 'size' ] / 1024 )

            IF nFiles_Size > oServer:nfiles_size_garbage_inspector

               UFilesTmpCollector()
               nFiles_Size := 0

            ENDIF

            hb_mutexUnlock( oServer:hmtxFiles )

// ---------------------------------------

         ENDIF

      ENDIF

      AAdd( aFiles, hFile )

   ENDIF

   RETU NIL



/* Block example to parse.... */
/*
Content-Disposition: form-data; name="name"

Charly Brown

*/

STATIC FUNCTION UParseMultiPartData( cBlock, hPost )

   LOCAL nEnd := hb_At( Chr( 13 ), cBlock )
   LOCAL uValue
   LOCAL cInfo, aInfo, cKey, nPos
   LOCAL hFile := { => }

   IF nEnd > 0

      cInfo  := SubStr( cBlock, 1, nEnd - 1 )

      aInfo  := hb_ATokens( cInfo, ';' )

      cKey  := UInfo2Tag( aInfo, ' name=' )

      IF !Empty( cKey )

         uValue  := AllTrim( SubStr( cBlock, nEnd + 1 ) )
         nPos  := At( Chr( 13 ), uValue )

         IF nPos > 0
            uValue := SubStr( uValue, 1, nPos - 1 )
         ENDIF

         hPost[ cKey ]  := uValue

      ENDIF

   ENDIF

   RETU NIL

STATIC FUNCTION UInfo2Tag( uInfo, cTag )

   LOCAL n, nPos, nLen
   LOCAL cValue := ''

   IF ValType( uInfo ) == 'A'

      nLen := Len( uInfo )

      FOR n := 1 TO nLen

         nPos := At( cTag, uInfo[ n ] )

         IF nPos > 0

            cValue := SubStr( uInfo[ n ], nPos + Len( cTag ) )

            IF Left( cValue, 1 ) == '"'
               cValue := SubStr( cValue, 2 )
            ENDIF

            IF Right( cValue, 1 ) == '"'
               cValue := SubStr( cValue, 1, Len( cValue ) - 1 )
            ENDIF

         ENDIF

      NEXT

   ELSE

      nPos := At( cTag, uInfo )

      IF nPos > 0

         cValue := SubStr( uInfo, nPos + Len( cTag ) )

         IF Left( cValue, 1 ) == '"'
            cValue := SubStr( cValue, 2 )
         ENDIF

         IF Right( cValue, 1 ) == '"'
            cValue := SubStr( cValue, 1, Len( cValue ) - 1 )
         ENDIF

      ENDIF

   ENDIF

   RETU cValue

STATIC FUNCTION UFilesTmpCollector( lDelAll )

   LOCAL cPath  := UGetServer():cPathTmp
   LOCAL aFiles  := Directory( cPath + '/*.*' )
   LOCAL nFiles  := Len( aFiles )
   LOCAL nSFiles  := 0
   LOCAL nSize  := 0
   LOCAL nTime  := hb_MilliSeconds()
   LOCAL nLifeDays := UGetServer():nfiles_lifeDays
   LOCAL nI, dMaxDate
   
   

   hb_default( @lDelAll, .F. ) // .T. when start server

   dMaxDate := Date() - nLifeDays

   IF lDelAll
      oServer:Dbg( 'Init Garbage Tmp Files Procces!' )
   ELSE
      oServer:Dbg( 'Init Garbage Tmp Files Procces! => ' + DToC( dMaxDate ) )
   ENDIF

   FOR nI := 1 TO nFiles

      IF aFiles[ nI ][ 3 ] <= dMaxDate .OR. lDelAll

         IF FErase( cPath + '/' + aFiles[ nI ][ 1 ] ) == 0
            nSFiles++
            nSize  += aFiles[ nI ][ 2 ]
         ENDIF

      ENDIF
   NEXT

   oServer:Dbg( '=====================================' )
   oServer:Dbg( 'Tmp files deleted: ' + LTrim( Str( nSFiles ) ) )
   oServer:Dbg( 'Tmp size deleted: ' + LTrim( Str( nSize ) ) + ' kb.' )
   oServer:Dbg( 'Time proccess for garbage: ' + LTrim( Str( hb_MilliSeconds() - nTime ) ) + ' ms.' )
   oServer:Dbg( '=====================================' )


   RETU NIL
   
FUNCTION UImgAlert()

	LOCAL cImg := ''

    TEXT TO cImg	
iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAACKJJREFUeF7tm3WsHFUUxn/FneLursU1uAV3d9fgWry4e9ECxT04xYMTijsUDU5xlyL5NWeayWT37czuzL6y5fzzmvd2Z+797pHvfOe2ByO49RjB9093AjASMDrgz5+76yC6C4BJgIWBGYG/gbeAN4FP2g1EdwAwAbAhcAAwM/AHMAi4EugHfNVOENoNwBjAysBRwLTAK+EBcwBfA8cBNwJ/tQuEdgMwC9AbWB+4HTgtNrs9sAnwEHA48E4nAjBObNzT/xw4CHg0NroocHyExDnA+e1KjO3yAN+zQLj+4sB5wJGpUx4f2DxO/43wkqfb4QXtAmAiYGvgYOB5YD/gtcwGzQOHASsClwKnAN9UDUI7ABgVWBboA0wFnA6cWWNjowHrxMZNiEcAd3YCAGb7vYAdgduA/YEv6mxsGmBPYCvglgDtsypBqNoDxgTWAI4GhkQOcGNd2TJRHcYFTgauAP6sCoSqAUjiWhAkOQcGEF3tZ2LAsrgP8GTkhdf/iwB4ghvFqX8UZe+xnBuxYpgz5ouSeDbwY87vFvpYVR4wcnB9XX/BGmWv0SLlDBsDxwDvA4ekOEOj7xb6e1UATArsAOwLWM/l/db3IiZrlCytBfQHTqqiT6gCAMuZtVwXnjDKmsyuqI0CrB4J0XZZb2qUQIu+oxI9YIYoddsAN8e/v8ysTOAFyiqh/RJdYXYDUwK7Rgm9K9jjx4V32cUXyvaAsYC147R+jQXfmnm/xEiQ5P8SI00d4MXQBWyP07ZEuP8UQaJkib+VBULZAMwdDG4V4OIoewoeidkOm9klRbK+8aIb1AMGRMZ/KlMq1Q8kRtLo56IsClYpViYAbmazaGjejYbm8dQqdXnLm0xwzcjuzwL/RKWYDLg3cofqUNrmSTVSFwFnAN+XgUBZAJiwdFVb3TmBs4ATMgu0MuwWJylANjvmCPPABhHrPWNz9gtpM7T8jC2z4aKm8ODwBIDxabLaA3gk6nb2FC1ruvF6ER6Hpiju1MH87ANuCKCyJ2zesKxKrq4NMLLJtTAmZXiAcW3MW/Y8TU/+shor0Y3VAASiVklTD7gKeCAaoixvkFytFP2BSrLy2fUhqRXeePKFMgBQ2PRkNwWuC/JSS9hsFQDXbJ4wge4eIWDL/F7Tu4eWecDY4dKe6LeAbm02r2VlAOBzFwn3nwmwR7gweERTOLTiAX7XkqZbLweYne32zOpVApDIZ4Jtl+jPZ5rafYsekK7Pxqtylu1rPSvLA3x+0mavEG32qeGBhXFo1gNkc0tHMps+GFq2dGUXUyYAJluJlAlX+Uzw7ym8+xY8wLJlyTIhmbV1w7cbLKBMAHxVIp9tEU2SrbNyeyFrxgNEf7Uoe37/WOCaHG8tGwBLofKZspniy4nA1UXls2YAmC1OfN3YuKxMN2xkZQPg+xyybhei6xMRCg5ac1tRAETawab199N4oeOsPFYFAL43kc96hfJ0LvBTngX5mSIA6HILBd+3FmenO43eWRUANmHOFRNSpHymN+SyIgAkaq183OmOQ0y7ubw2V3xn/ojXNF2WTm8L9A0iZU9hw5TXEvlM9Vn5zLyQJyxze4Ct7PKR+Iw7664eUMRkbmp8NjNq/QKYNDw2OpIo5XD5vVT3hwIP96aJm7csqi1IzhzCNLS8HjBdzPOc790d7ualhiLmfNCEZcn8ADBWZXC/A0tFB6iXOTK3nS5qqkt2pL7DkZqtuXmqS8sDgL24AoZ8X7nKBzcjTppDdH9PWganzv9CJCx/7wbs8fWMbCvdaB/J35cM+cymSS+9PACu+/08AChwmGBWjWss/rvZqa2xbtZWMLV/MJw0539Oi43fO/Lutsbn9CC91DxlfpIhegulaQCSDOuDvLXh6eTOsF28VxbnVZlZo3l6NRJrGSOweSMHLBadopPouvmkKw9QgPAhur5e4IPMrsO7JSM5162Ebll8uN6iuwLAONolMrKnbmZ9uaTdqyPYT9hR2j4roFi2vivp+VYcxVcbJuUzq8PgWs+uB4BlRRdV5nKx9WSuZtZrNXByZD9hJ+mNMGu+krfDDweprZplW5lOEVWzUbqplnxWDwAvMCYyl8qtmd/S1aoZ+0rnW8ZwxIsSAmDyMk5VdxRWyrgrqFC7c3Ss94cHf5jdQC0APHEbHV1el3TznkyrpuRtjfa5ymf2EPIAL044QdYjnCap+UuGyggHKbveK9Eyhzms8R3DrBYAZlE3reDhGEo3KmMxblIl15pvfVZASa7K6BnODMw5VgK5QhnVxuGsUyWn05ZDSZihVhcAT0l5Wve3NFnzB7Z69PF9c4rsT/rrQu7LPFc2KHlR8xN06XIZ5rjO8u2BXhJMc9iBpj3A6Y6LsHx4scnFuOCyzIzsAtQPPZHsPUCHpbqr+afMdxvSTpVMhHqcnMYR3FBLAyAVtQnZKWQuY7WQuNAAKa/K6fYqSoaCQ5DEZIhOlT157wI0S7frLcEcsHdoGSZ1Vayh4ZcA4AKkupY9Obs/TURlWtINOkBxdmDra8mzCtgqe6NEicty5W2QMu8L6932HwJvb6OnyQ+GJABISWVMzu2c7ngCZd/PU0l2tCW49u/e/ZGvewXOBKlgosDq38vKO+kDnDxKoh2j80vz2yAB8EKSMWJs2D66+bwyV1EPMR49ZcNMCUtSlDBBs785IlcfX/TF8XkVLb1g9shvfQXAXxrvnsIFEae5NbUmFmKPYTjoDcn/GFFbsDWu4uTTS5R6K6Pr7ea33gLgxWXbR1+uW5TF95vApi1fsbFTyVbh6i8A0kQ5uYlB4tPpltxjsiwOFgA5viNmr6a+1Om7j/0lCnUvATAb24pag72glL7U1Il4WPKVzuQFPQXAcZIcwNO3OansZvZwgqYql0KPFHmAAHgnVx3ehkR0Ot30cO8ZWnn6CYAdkyXQ2ig6nW623zZkTrMH5lGFOxqQ/wHo6OPNsbl/Aa2y86hAqj7XAAAAAElFTkSuQmCC
    ENDTEXT 

    RETU cImg 

// --------------------------------------------- //
// Recover IP Real
// Xec for invers proxy, cloudfare,...
// --------------------------------------------- //

STATIC FUNCTION UGetIpClient( hServer )

    local aIP 	:= {;
					'HTTP_X_FORWARDED_FOR',;
					'HTTP_X_REAL_IP',;
					'HTTP_CLIENT_IP',;
					'HTTP_CF_CONNECTING_IP',;		//	Cloudflare header
					'REMOTE_ADDR';
				}
				
	local nLen := len( aIP )
	local nI, cValue, aForward, cKey, cIp 
	
	for nI := 1 to nLen 
	
		cKey := aIP[ nI ]
	
		if HB_HHasKey( hServer, cKey )
		
			cValue := hServer[ cKey ]
			
			if cKey == 'HTTP_X_FORWARDED_FOR'
				aForward := hb_ATokens( cValue, " " )
				
				if valtype( aForward ) == 'A' .and. len( aForward ) > 0 
					cIp := aForward[1]
				endif
				
			else 
				cIP := cValue 
			endif	

			if UValidIP( cIP )
				retu cIp 
			endif 
		
		endif 	
		
	next 
	
retu '127.0.0.1'
	
// --------------------------------------------- //

FUNCTION UValidIP(cIP)

	LOCAL lValid := .F.
	LOCAL cPatron

	// Patrón de expresión regular para validar IP (IPv4)
	// Formato: xxx.xxx.xxx.xxx donde xxx va de 0 a 255
	cPatron = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

	IF HB_RegExMatch(cPatron, ALLTRIM(cIP))
		lValid := .T.
	ENDIF

RETURN lValid