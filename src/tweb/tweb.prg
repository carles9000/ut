/*
**  tweb.prg -- TWeb library form mod harbour
**
** (c) Carles Aubia, 2019-2025
** Developed by Carles Aubia Floresvi carles9000@gmail.com
** MIT license https://github.com/carles9000/tweb.uhttpd2/blob/master/LICENSE
*/

#define TWEB_VERSION    '1.4a'

#include 'hbclass.ch'
#include 'common.ch'
#include 'error.ch'

// ----------------------------------------------------------

#define CRLF      Chr(13)+Chr(10)

#xcommand TRY  => BEGIN SEQUENCE WITH {| oErr | Break( oErr ) }
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS

#xcommand DEFAULT <uVar1> := <uVal1> ;
      [, <uVarN> := <uValN> ] => ;
      If( < uVar1 > == NIL, < uVar1 > := < uVal1 >, ) ;;
      [ If( <uVarN> == nil, <uVarN> := <uValN>, ); ]

// ----------------------------------------------------------
#include 'twebcontrol.prg'
#include 'twebform.prg'
#include 'twebsay.prg'
#include 'twebfont.prg'
#include 'twebget.prg'
#include 'twebgetnumber.prg'
#include 'twebgetmemo.prg'
#include 'twebimage.prg'
#include 'twebcheckbox.prg'
#include 'twebbutton.prg'
#include 'twebbuttonfile.prg'
#include 'twebswitch.prg'
#include 'twebradio.prg'
#include 'twebbox.prg'
#include 'twebselect.prg'
#include 'twebicon.prg'
#include 'twebfolder.prg'
#include 'twebnav.prg'
#include 'twebcommon.prg'
#include 'twebbrowse.prg'
#include 'twebdialog.prg'
#include 'twebcard.prg'
#include 'twebaccordion.prg'
#include 'twebpanel.prg'
#include 'twebprogress.prg'

// #include 'twebunicode.prg'
// ----------------------------------------------------------


FUNCTION TWebVersion() ; RETU TWEB_VERSION

CLASS TWeb

   DATA lTables     INIT .F.
   DATA cTitle
   DATA cIcon
   DATA cLang      INIT 'en'
   DATA cPathTpl       INIT ''
   DATA cRootRelative    INIT ''
   DATA cCharset     INIT 'UTF-8' // 'ISO-8859-1'
   DATA lActivated    INIT .F.
   DATA lHeader     INIT .T.
   DATA aInclude     INIT {}
   DATA aControls     INIT {}

   METHOD New()      CONSTRUCTOR
   METHOD Activate()
   METHOD AddControl( uValue )  INLINE AAdd( ::aControls, uValue )
   METHOD Html( cCode )     INLINE AAdd( ::aControls, cCode )
   METHOD AddJs( cFile, lAbsolute )
   METHOD AddCss( cFile, lAbsolute )

ENDCLASS

METHOD New( cTitle, cIcon, lTables, cCharset,  cPathTpl ) CLASS TWeb

   DEFAULT cTitle   TO 'TWeb'
   DEFAULT lTables  TO .F.
   DEFAULT cCharSet  TO 'UTF-8'   // 'ISO-8859-1'


   DEFAULT cIcon    TO 'files/images/ut_ico.png'
   DEFAULT cPathTpl   TO hb_DirBase() + 'files/tweb/tpl/'

   ::cTitle  := cTitle
   ::cIcon  := cIcon
   ::lTables := lTables
   ::cCharSet := cCharset
   ::cPathTpl  := cPathTpl

   RETU SELF

METHOD Activate() CLASS TWeb

   LOCAL cHtml  := ''
   LOCAL cTpl  := ''
   LOCAL nI

   IF ::lActivated
      RETU NIL
   ENDIF

   IF ::lHeader

      cHtml   := '<!DOCTYPE html>' + CRLF
      cHtml  += '<html lang="' + ::cLang + '">' + CRLF
      cHtml  += '<head>' + CRLF
      cHtml  += '<title>' + ::cTitle + '</title>' + CRLF
      cHtml  += '<meta charset="' + ::cCharset + '">' + CRLF
      cHtml  += '<meta http-equiv="X-UA-Compatible" content="IE=edge">' + CRLF
      cHtml  += '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0">' + CRLF
      cHtml  += '<link rel="shortcut icon" type="image/png" href="{{ hb_GetEnv( "ROOTRELATIVE") }}' + ::cIcon + '"/>' + CRLF

      cHtml  += hb_MemoRead( ::cPathTpl + 'libs.tpl' ) + CRLF

      FOR nI := 1 TO Len( ::aInclude )
         cHtml += ::aInclude[ nI ] + CRLF
      NEXT

      hb_SetEnv( "ROOTRELATIVE", ::cRootRelative )

      UReplaceBlocks( @cHtml, "{{", "}}" )

   ENDIF


   ::lActivated := .T.

   FOR nI := 1 TO Len( ::aControls )

      IF ValType( ::aControls[ nI ] ) == 'O'
         cHtml += ::aControls[ nI ]:Activate()
      ELSE
         cHtml += ::aControls[ nI ]
      ENDIF

   NEXT

   cHtml += JSReady( 'SetTWeb()' )

   RETU cHtml

METHOD AddJs( cFile, lAbsolute ) CLASS TWeb

   hb_default( @lAbsolute, .F. )

   IF lAbsolute
      AAdd( ::aInclude, '<script src="' + cFile + '"></script>' )
   ELSE
      AAdd( ::aInclude, '<script src="{{ hb_GetEnv( "ROOTRELATIVE") }}' + cFile + '"></script>' )
   ENDIF

   RETU NIL

METHOD AddCss( cFile, lAbsolute ) CLASS TWeb

   hb_default( @lAbsolute, .F. )

   IF lAbsolute
      AAdd( ::aInclude, '<link rel="stylesheet" href="' + cFile + '">' )
   ELSE
      AAdd( ::aInclude, '<link rel="stylesheet" href="{{ hb_GetEnv( "ROOTRELATIVE") }}' + cFile + '">' )
   ENDIF

   RETU NIL

FUNCTION JS( cCode )

   LOCAL cHtml := ''

   DEFAULT cCode TO ''

   cHtml  += "<script type='text/javascript'>"
   cHtml  +=   cCode
   cHtml  += "</script>"

   RETU cHtml

FUNCTION JSReady( cCode, cLog )

   LOCAL cEcho := ''

   DEFAULT cCode TO ''
   DEFAULT cLog TO ''

   cEcho  = "<script type='text/javascript'>"
   cEcho += "  $( document ).ready(function() {"

   IF !Empty( cLog )
      cEcho += "console.info( 'info', '" + cLog + "' );"
   ENDIF

   cEcho +=   cCode  + ';'
   cEcho += "  })"
   cEcho += "</script>"

   RETU cEcho

// ------------------------------------------------------------------------------

FUNCTION TWebHtmlInline( cFile, ... )

   LOCAL cCode := ''

   cCode := ULoadHtml( cFile, ... )

   RETU cCode



// ------------------------------------------------------------------------------

FUNCTION TWebParameter( uValue )

   LOCAL cType := ValType( uValue )

THREAD STATIC aParam

DO CASE

CASE cType == 'A'

IF ValType( uValue[ 1 ] ) == 'H'
aParam := uValue[ 1 ]
ELSE
aParam := uValue
ENDIF

CASE cType == 'N'  // Buscar elemento de array

IF ValType( aParam ) == 'A'

IF uValue > 0  .AND. uValue <= Len( aParam )
RETU aParam[ uValue ]
ELSE
RETU '*** Index error ' + LTrim( Str( uValue ) ) + ' ***'
ENDIF

ENDIF

CASE cType == 'C'  // Buscar key in Hash

hb_HCaseMatch( aParam, .F. )

IF hb_HHasKey( aParam, uValue )
RETU aParam[ uValue ]
ELSE
RETU '*** Index hash error: ' + uValue + ' ***'
ENDIF

OTHERWISE

// retu _w( aParam )

ENDCASE

RETU ''

// ------------------------------------------- //
// Get id FORM

FUNCTION UIdFormParent( oParent, lReturnObject )

   LOCAL cId_Dialog  := ''
   LOCAL lFound   := .F.
   LOCAL o

   hb_default( @lReturnObject, .F. )

   IF ValType( oParent ) != 'O'
      IF lReturnObject
         RETU NIL
      ELSE
         RETU cId_Dialog
      ENDIF
   ENDIF

   IF oParent:classname() == 'TWEBFORM'
      IF lReturnObject
         RETU oParent
      ELSE
         RETU oParent:cId_Dialog
      ENDIF
   ENDIF


// aData := __objGetMsgList( o, .T. )

// We're looking for a TWEBFORM. We need cId_Dialog

   o := oParent

   WHILE __objHasData( o, 'OPARENT' ) .AND. !lFound

      o := o:oParent

      IF ValType( o ) == 'O' .AND. o:ClassName() == 'TWEBFORM'

         lFound    := .T.
         cId_Dialog  := o:cId_Dialog

      ENDIF

   END


   RETU if( lReturnObject, if( lFound, o, NIL ), cId_Dialog )

// ------------------------------------------- //
// Get Object FORM

FUNCTION UOFormParent( oParent )

   RETU UIdFormParent( oParent, .T. )



// ------------------------------------------------------------------------------

FUNCTION mh_valtochar( u )

   RETU hb_ValToStr( u )
// retu _w( u )
