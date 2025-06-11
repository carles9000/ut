#xcommand ? [<explist,...>] => UWrite( '<br>' [,<explist>] )
#xcommand ?? <cText> => UWrite( <cText> )

#xcommand DEFINE WEB <oWeb> [ TITLE <cTitle>] [ ICON <cIcon>] [<lTables: TABLES>] [ CHARSET <cCharSet>]  ;
	=> ;
		<oWeb> := TWeb():New( [<cTitle>], [<cIcon>], [<.lTables.>], [<cCharSet>] )
		
#xcommand INIT WEB <oWeb>  => <oWeb>:Activate()
#xcommand INIT WEB <oWeb> RETURN =>  return <oWeb>:Activate()
#xcommand ACTIVATE WEB <oWeb> =>  return <oWeb>:Activate()

#xcommand DEFINE DIALOG <oDlg> => <oDlg> := TWebDialog():New()
#xcommand INIT DIALOG <oDlg> => <oDlg>:Activate()
#xcommand INIT DIALOG <oDlg> RETURN => return <oDlg>:Activate()
#xcommand ACTIVATE DIALOG <oDlg> RETURN => return <oDlg>:Activate()


#xcommand CSS <oForm> => #pragma __cstream| <oForm>:Html( '<style>' + %s + '</style>' )

#xcommand TEXT TO <var> => #pragma __stream|<var> += %s
#xcommand TEXT TO <var> PARAMS [<v1>] [,<vn>] => #pragma __cstream|<var> += UInlinePrg( UReplaceBlocks( %s, '<$', "$>" [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) )

#xcommand CODE TO <var> => #pragma __stream|<var> += %s

#xcommand HTML <o> => #pragma __cstream| <o>:Html( %s )
#xcommand HTML <o> INLINE <cHtml> => <o>:Html( <cHtml> )
#xcommand HTML <o> [ PARAMS [<v1>] [,<vn>] ] ;
=> ;
	#pragma __cstream |<o>:Html( UInlinePrg( UReplaceBlocks( %s, '<$', "$>" [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) ) )

#xcommand HTML <oForm> FILE <cFile> [ <prm: PARAMS, VARS> <cValues,...> ]  => <oForm>:Html( TWebHtmlInline( <cFile>, [<cValues>]  ) )
#xcommand TEMPLATE <oForm> FILE <cFile> [ <prm: PARAMS, VARS> <cValues,...> ]  => <oForm>:Html( TWebHtmlInline( <cFile>, [<cValues>]  ) )
//#xcommand JAVASCRIPT <o>  => #pragma __cstream|<o>:Html( '<script>' + %s + '</script>' )



#xcommand DEFINE FORM <oForm> [ID <cId> ] [ACTION <cAction>] [METHOD <cMethod>] ;
	[API <cApi>] [<chg: ONINIT,ON INIT> <cProc>] OF <oWeb> ;
=> <oForm> := TWebForm():New( <oWeb>, [<cId>], [<cAction>], [<cMethod>], [<cApi>], [<cProc>] )

#xcommand INIT FORM <oForm> [ CLASS <cClass>] => <oForm>:InitForm( [<cClass> ] )
#xcommand ENDFORM <oForm>  => <oForm>:End()
#xcommand ACTIVATE FORM <oForm>  => <oForm>:End()



#xcommand COL <oForm> [ ID <cId> ] [GRID <nGrid>] [TYPE <cType>]  [ CLASS <cClass> ] [ STYLE <cStyle> ] [ <hi: HIDE, HIDDEN> ];
=> ;
	<oForm>:Col( [<cId>], [<nGrid>], [<cType>], [<cClass>], [<cStyle>], [<.hi.>] )
	
#xcommand ROW <oForm> [ ID <cId> ] [ VALIGN <cVAlign> ] [ HALIGN <cHAlign> ] [ CLASS <cClass> ] [ TOP <cTop> ] [ BOTTOM <cBottom>] [ <hi: HIDE, HIDDEN> ] ;
=> ;
	<oForm>:Row( [<cId>], [<cVAlign>], [<cHAlign>], [<cClass>], [<cTop>], [<cBottom>], [<.hi.>] )
	
#xcommand ROWGROUP <oForm> [ ID <cId> ] [ VALIGN <cVAlign> ] [ HALIGN <cHAlign> ] [ CLASS <cClass> ] [ STYLE <cStyle> ] [ <hi: HIDE, HIDDEN> ] ;
=> ;
	<oForm>:RowGroup( [<cId>], <cVAlign>, <cHAlign>, <cClass>, [<cStyle>], [<.hi.>] )
	
#xcommand DIV <oForm> [ ID <cId> ] [ CLASS <cClass> ] [ <hi: HIDE, HIDDEN> ];
	[ STYLE <cStyle> ] [ PROP <cProp> ] [ CODE <cCode> ] ;
=> ;
	<oForm>:Div( [<cId>], [<cClass>], [<cStyle>], [<cProp>], [<cCode>], [<.hi.>])
	
#xcommand DIV [<oDiv>] [ ID <cId> ] [ CLASS <cClass> ] ;
	[ STYLE <cStyle> ] [ PROP <cProp> ] [ CODE <cCode> ] OF <oForm> ;
=> ;
	[<oDiv> := ] <oForm>:Div( [<cId>], [<cClass>], [<cStyle>], [<cProp>], [<cCode>] )
	
#xcommand PANEL [<oPanel>] [ ID <cId> ] [ CLASS <cClass> ] ;
	[ STYLE <cStyle> ] [ PROP <cProp> ] [ <hi: HIDE, HIDDEN> ] OF <oForm> ;
=> ;
	[<oPanel> := ] TWebPanel():New( <oForm>, [<cId>], [<cClass>], [<cStyle>], [<cProp>], [<.hi.>] )	

#xcommand ENDPANEL <oPanel> => <oPanel>:End()	

#xcommand ENDROW <oForm> => <oForm>:End()
#xcommand ENDCOL <oForm> => <oForm>:End()
#xcommand ENDDIV <oForm> => <oForm>:End()	

	
#xcommand CAPTION <oForm> LABEL <cLabel> [ GRID <nGrid> ]  [ CLASS <cClass> ] => <oForm>:Caption( <cLabel>, <nGrid>, [<cClass>] )
#xcommand SEPARATOR <oForm>  [ ID <cId> ] LABEL <cLabel> [ CLASS <cClass> ] => <oForm>:Separator( [<cId>], <cLabel>, [<cClass>] )
#xcommand SMALL <oForm> [ ID <cId> ] [ LABEL <cLabel> ] [ GRID <nGrid> ] [ CLASS <cClass> ] => <oForm>:Small( <cId>, <cLabel>, <nGrid>, [<cClass>] )



#xcommand SAY [<oSay>] [ ID <cId> ] [ <prm: VALUE,PROMPT,LABEL> <uValue> ] [ ALIGN <cAlign> ] ;
	[GRID <nGrid>] [ CLASS <cClass> ] [ FONT <cFont> ] [ LINK <cLink> ] [ STYLE <cStyle>] [ ACTION <cAction> ] OF <oForm> ;
=> ;
	[<oSay> := ] TWebSay():New( <oForm>, [<cId>], [<uValue>], [<nGrid>], [<cAlign>], [<cClass>], [<cFont>], [<cLink>], [<cStyle>],  [<cAction>] )
	
#xcommand DEFINE FONT [<oFont>] NAME <cId> ;
	[ COLOR <cColor> ] [ BACKGROUND <cBackGround> ] [ SIZE <nSize> ] ;
	[ <bold: BOLD> ] [ <italic: ITALIC> ] [ FAMILY <cFamily> ] ;
	OF <oForm> ;
=> ;
	[<oFont> := ] TWebFont():New( <oForm>, <cId>, <cColor>, <cBackGround>, <nSize>, [<.bold.>], [<.italic.>], [<cFamily>] )

#xcommand GET [<oGet>] [ ID <cId> ] [ VALUE <uValue> ] [ <prm: PROMPT,LABEL> <cLabel> ] [ ALIGN <cAlign> ] [ <col:GRID, COL> <nGrid>] ;
	[ <ro: READONLY, DISABLED> ] [TYPE <cType>] [ PLACEHOLDER <cPlaceHolder>] ;
	[ <btn: BUTTON, BUTTONS> <cButton,...> ] [ <act: ACTION, ACTIONS> <cAction,...> ] [ <bid: BTNID, BTNIDS> <cBtnId,...> ] [ BTNCLASS <cBtnClass> ];
	[ <rq: REQUIRED> ] [ AUTOCOMPLETE <uSource> [ SELECT <cSelect>] [CONFIG <aConfig>] [ PARAM <hParam> ] ] ;
	[ <chg: ONCHANGE,VALID> <cChange> ];
	[ CLASS <cClass> ] [ FONT <cFont> ] [ FONTLABEL <cFontLabel> ] ;
	[ LINK <cLink> ] [ GROUP <cGroup> ] [ DEFAULT <cDefault>] ;
	[ <spn: SPAN> <cSpan,...> ] [ <spnid: SPANID> <cSpanId,...> ] ;
	[ STYLE <cStyle> ] [ PROP <cProp> ] [ <hi: HIDE, HIDDEN> ] [ <rt: RETURN, INTRO, ENTER>] [ CONFIRM <cConfirm> ];
	OF <oForm> ;
=> ;
	[<oGet> := ] TWebGet():New( <oForm>, [<cId>], [<uValue>], [<nGrid>], [<cLabel>], [<cAlign>], [<.ro.>], [<cType>], [<cPlaceHolder>], [\{<cButton>\}], [\{<cAction>\}], [\{<cBtnId>\}], [<.rq.>], [<uSource>], [<cSelect>], [<cChange>], [<cClass>], [<cFont>], [<cFontLabel>],[<cLink>], [<cGroup>], [<cDefault>], [\{<cSpan>\}], [\{<cSpanId>\}], [<cStyle>], [<cProp>], [<.hi.>], [<aConfig>], [<hParam>], [<cBtnClass>], [<.rt.>], [<cConfirm>] )
	
#xcommand GET [<oGetMemo>] MEMO [ ID <cId> ] [ VALUE <uValue> ] [ LABEL <cLabel> ] [ ALIGN <cAlign> ] [GRID <nGrid>] [ STYLE <cStyle>] ;
	[ <ro: READONLY, DISABLED> ] [ ROWS <nRows> ] ;	
	[ CLASS <cClass> ] [ FONT <cFont> ] ;
	[ <chg: ONCHANGE,VALID> <cChange> ];
	[ STYLE <cStyle> ] [ PROP <hProp> ];
	[ <hi: HIDE, HIDDEN> ];	
	OF <oForm> ;
=> ;
	[<oGetMemo> := ] TWebGetMemo():New( <oForm>, [<cId>], [<uValue>], [<nGrid>], [<cLabel>], [<cAlign>], [<.ro.>], [<nRows>], [<cClass>], [<cFont>], [<cChange>], [<cStyle>], [<hProp>], [<.hi.>] )
	
#xcommand GETNUMBER [<oGet>] [ ID <cId> ] [ VALUE <uValue> ] [ LABEL <cLabel> ] [ ALIGN <cAlign> ] [ <col:GRID, COL> <nGrid>] ;
	[ <ro: READONLY, DISABLED> ] [ PLACEHOLDER <cPlaceHolder>] ;	
	[ <rq: REQUIRED> ]  ;
	[ <chg: ONCHANGE,VALID> <cChange> ];
	[ CLASS <cClass> ] [ FONT <cFont> ] [ STYLE <cStyle> ] ;	
	OF <oForm> ;
=> ;
	[<oGet> := ] TWebGetNumber():New( <oForm>, [<cId>], [<uValue>], [<nGrid>], [<cLabel>], [<cAlign>], [<.ro.>], [<cPlaceHolder>], [<.rq.>], [<cChange>], [<cClass>], [<cFont>], [<cStyle>] )



	
#xcommand BUTTON [<oBtn>] [ ID <cId> ] [ <prm: PROMPT,LABEL> <cLabel> ] [ ACTION <cAction> ] [ NAME <cName> ] [ VALUE <cValue> ] ;
    [ GRID <nGrid> ] [ ALIGN <cAlign> ]  ;
	[ ICON <cIcon> ] [ <ds: DISABLED> ] [ <sb: SUBMIT> ] [ LINK <cLink> ] ;
	[ CLASS <cClass> ] [ FONT <cFont> ] ;
	[ UPLOAD <cId_Btn_Files> ] ;
	[ WIDTH <cWidth> ] ;
	[ CONFIRM <cConfirm> ] ;
	[ STYLE <cStyle> ] [ PROP <hProp> ];
	[ <hi: HIDE, HIDDEN> ];
	[ PBS <cPBS> ];
	OF <oForm> ;
=> ;
	[ <oBtn> := ] TWebButton():New( <oForm>, [<cId>], <cLabel>, <cAction>, <cName>, <cValue>, <nGrid>, <cAlign>, <cIcon>, [<.ds.>], [<.sb.>], [<cLink>], [<cClass>], [<cFont>], [<cId_Btn_Files>], [<cWidth>], [<cConfirm>], [<cStyle>], [<hProp>], [<.hi.>], [<cPBS>] )	
	
#xcommand BUTTON FILE [<oBtn>] [ ID <cId> ] [ <prm: PROMPT,LABEL> <cLabel> ] [ ACTION <cAction> ] [ NAME <cName> ] [ VALUE <cValue> ] ;
    [ GRID <nGrid> ] [ ALIGN <cAlign> ]  ;
	[ ICON <cIcon> ] [ <sb: SUBMIT> ] ;
	[ CLASS <cClass> ] [ FONT <cFont> ] ;	
	[ WIDTH <cWidth> ] ;
	[ CONFIRM <cConfirm> ] ;
	[ <ro: READONLY, DISABLED> ];
	[ STYLE <cStyle> ] [ PROP <hProp> ] [ <mu: MULTIPLE> ];	
	OF <oForm> ;
=> ;
	[ <oBtn> := ] TWebButtonFile():New( <oForm>, [<cId>], <cLabel>, <cName>, <cAction>, <cValue>, <nGrid>, <cAlign>, <cIcon>, [<.ro.>], [<.sb.>], [<cClass>], [<cFont>], [<cWidth>], [<cConfirm>], [<cStyle>], [<hProp>], [<.mu.>] )	

#xcommand DEFINE BUTTON GROUP [ CLASS <cClass>] OF <o> => <o>:Html( '<div class="btn-group ' + [<cClass>] + '">' )

#xcommand BUTTON GROUP [<oBtn>] [ ID <cId> ] [ <prm: PROMPT,LABEL> <cLabel> ] [ ACTION <cAction> ] [ NAME <cName> ] [ VALUE <cValue> ] ;
    [ GRID <nGrid> ] [ ALIGN <cAlign> ]  ;
	[ ICON <cIcon> ] [ <ds: DISABLED> ] [ <sb: SUBMIT> ] [ LINK <cLink> ] ;
	[ CLASS <cClass> ] [ FONT <cFont> ] ;
	[ UPLOAD <cId_Btn_Files> ] ;
	[ WIDTH <cWidth> ] ;
	[ CONFIRM <cConfirm> ] ;
	[ STYLE <cStyle> ] [ PROP <hProp> ];
	[ <hi: HIDE, HIDDEN> ];
	[ PBS <cPBS> ];
	OF <oForm> ;
=> ;
	[ <oBtn> := ] TWebButton():New( <oForm>, [<cId>], <cLabel>, <cAction>, <cName>, <cValue>,    0  , <cAlign>, <cIcon>, [<.ds.>], [<.sb.>], [<cLink>], [<cClass>], [<cFont>], [<cId_Btn_Files>], [<cWidth>], [<cConfirm>], [<cStyle>], [<hProp>], [<.hi.>], [<cPBS>] )
	
//	[ <oBtn> := ] TWebButton():New( <oForm>, [<cId>], <cLabel>, <cAction>,[<cName>],<cValue>, <nGrid>,<cAlign>, <cIcon>, [<.ds.>], [<.sb.>], [<cLink>], [<cClass>], [<cFont>], [<cId_Btn_Files>], [<cWidth>], [<cConfirm>], [<cStyle>], [<hProp>], [<.hi.>], [<cPBS>] )	


#xcommand ENDGROUP OF <o> => <o>:Html( '</div>' )

	
	
#xcommand IMAGE [<oImg>] [ ID <cId> ] [ FILE <cFile> ] [ BIGFILE <cBigFile> ] [ ALIGN <cAlign> ] ;
	[GRID <nGrid>] [ CLASS <cClass> ] [ WIDTH <nWidth>] [ GALLERY <cGallery> ] ;
	[ <nozoom: NOZOOM> ] [ STYLE <cStyle> ] [ PROP <cProp> ] [ <hi: HIDE, HIDDEN> ] OF <oForm> ;
=> ;
	[<oImg> := ] TWebImage():New( <oForm>, [<cId>], [<cFile>], [<cBigFile>], [<nGrid>], [<cAlign>], [<cClass>], [<nWidth>], [<cGallery>], [<.nozoom.>], [<cStyle>], [<cProp>], [<.hi.>] )
	
	
#xcommand SWITCH [<oSwitch>] [ ID <cId> ] [ <lValue: ON> ] [ VALUE <lValue> ] [ LABEL <cLabel> ] ;
	[GRID <nGrid>] [ <act:ACTION,ONCHANGE> <cAction> ];
	[ <ro: READONLY, DISABLED> ] [ <hi: HIDE, HIDDEN> ] [ CLASS <cClass> ] OF <oForm> ;
=> ;
	[ <oSwitch> := ] TWebSwitch():New( <oForm>, [<cId>], [<lValue>], [<cLabel>], [<nGrid>], [<cAction>], [<.ro.>], [<.hi.>], [<cClass>] ) 	

#xcommand RADIO [<oRadio>] [ ID <cId> ] [ LABEL <cLabel> ] [ <chk: VALUE, CHECKED> <uValue> ] ;
		[ <prm: PROMPT, PROMPTS, ITEMS> <cPrompt,...> ] ;
		[ <tabs: VALUES, KEYS> <cValue,...> ] ;	
		[ <ro: READONLY, DISABLED> ] ;
		[ GRID <nGrid> ] ;
		[ ONCHANGE  <cAction> ] ;
		[ <inline: INLINE> ] ;
		[ CLASS <cClass> ] [ FONT <cFont> ] [ STYLE <cStyle>] [ PROP <hProp> ] [ <hi: HIDE, HIDDEN> ];		
		OF <oForm> ;
=> ;
	[ <oRadio> := ] TWebRadio():New( <oForm>, [<cId>], [<cLabel>], [<uValue>], [\{<cPrompt>\}], [\{<cValue>\}], [<.ro.>], [<nGrid>], [<cAction>], [<.inline.>], [<cClass>], [<cFont>], [<cStyle>], [<hProp>], [<.hi.>] )
		 

//#xcommand CHECKBOX [<oCheckbox>] [ ID <cId> ] [ <lValue: ON> ] [ LABEL <cLabel> ] [GRID <nGrid>] [ ACTION  <cAction> ] ;
#xcommand CHECKBOX [<oCheckbox>] [ ID <cId> ] [ <chk: VALUE, CHECKED> <lValue>  ] [ LABEL <cLabel> ] [GRID <nGrid>] [ ACTION  <cAction> ] ;
	[ CLASS <cClass> ] [ FONT <cFont> ] [ STYLE <cStyle> ] [ PROP <hProp> ] [ <ro: READONLY, DISABLED> ] [ <hi: HIDE, HIDDEN> ];
	OF <oForm> ;
=> ;
	[ <oCheckbox> := ] TWebCheckbox():New( <oForm>, [<cId>], [<lValue>], [<cLabel>], [<nGrid>], [<cAction>], [<cClass>], [<cFont>], [<cStyle>], [<hProp>], [<.ro.>], [<.hi.>] ) 	
	

	
#xcommand BOX [<oBox>] [ ID <cId> ]  ;
	[GRID <nGrid>] [ HEIGHT <nHeight> ] [ CLASS <cClass> ] OF <oContainer> ;
=> ;
	[<oBox> := ] TWebBox():New( <oContainer>, [<cId>], [<nGrid>], [<nHeight>], [<cClass>] )
	
#xcommand ENDBOX <oBox> => <oBox>:End()	

	 
#xcommand SELECT [<oSelect>] [ ID <cId> ] [ VALUE <uValue> ] [ LABEL <cLabel> ] [ KEYVALUE <aKeyValue> ] ;
		[ <prm: PROMPT, PROMPTS, ITEMS> <cPrompt,...> ] ;
		[ <tabs: VALUES> <cValue,...> ] ;		
		[ GRID <nGrid> ] ;
		[ ONCHANGE  <cAction> ] ;
		[ CLASS <cClass> ] [ FONT <cFont> ]  [ GROUP <cGroup> ] [ STYLE <cStyle>] [ PROP <cProp> ] ;
		[ <ro: READONLY, DISABLED> ] [ <hi: HIDE, HIDDEN> ] [ WIDTH <nWidth> ];	
		OF <oForm> ;
=> ;
	[ <oSelect> := ] TWebSelect():New( <oForm>, [<cId>], [<uValue>], [\{<cPrompt>\}], [\{<cValue>\}], [<aKeyValue>], [<nGrid>], [<cAction>], [<cLabel>], [<cClass>], [<cFont>], [<cGroup>], [<cStyle>], [<cProp>], [<.ro.>], [<.hi.>], [<nWidth>] )

#xcommand ICON [<oIcon>] [ ID <cId> ] [ <prm: IMAGE,SRC> <cSrc> ] [ ALIGN <cAlign> ] ;
	[GRID <nGrid>] [ CLASS <cClass> ] [ FONT <cFont> ] [ LINK <cLink> ] [ STYLE <cStyle>] OF <oForm> ;
=> ;
	[<oIcon> := ] TWebIcon():New( <oForm>, [<cId>], [<cSrc>], [<nGrid>], [<cAlign>], [<cClass>], [<cFont>], [<cLink>], [<cStyle>] )

	
#xCommand PROGRESS [<oProgress>] [ ID <cId> ] [ VALUE <uValue> ] [ LABEL <cLabel> ] [ <pr: PERCENTAGE> ] ;
	[GRID <nGrid>] [ CLASS <cClass> ] [ FONT <cFont> ] [ STYLE <cStyle>] [ PROP <cProp> ] [ <hi: HIDE, HIDDEN> ] ;
	[ HEIGHT <nHeight> ] OF <oForm> ;
=> ;
	[<oProgress> := ] TWebProgress():New( <oForm>, [<cId>], [<uValue>], [<cLabel>], [<.pr.>], [<nGrid>], [<cClass>], [<cFont>], [<cStyle>], [<cProp>], [<.hi.>], [<nHeight>] )
	
	
//	WEBSOCKETS -----------------------------------


#xCommand DEFINE WEBSOCKETS [ SCOPE <cScope> ] [ TOKEN <cToken> ] [ <tr: LOG, TRACE> ] ;
	[ ONOPEN <cOnOpen> ] [ ONMESSAGE <cOnMessage> ] [ ONCLOSE <cOnClose> ] [ ONERROR <cOnError> ] OF <oForm> ;
=> ;
	<oForm>:Html(  UWS_Define( [<cScope>], [<cToken>], [<cOnOpen>], [<cOnMessage>], [<cOnClose>], [<cOnError>], [<.tr.>] ) )	


//	NAV Menu -------------------------------------
	
#xcommand NAV [<oNav>] [ ID <cId> ] [ TITLE <cTitle> ] [ LOGO <cLogo> [ WIDTH <nWidth>] ;
	[ ROUTE <cRoute>] [HEIGHT <nHeight> ] ] [ <bl: BURGUERLEFT> ] [ <sd: SIDEBAR> [ SIDE <cSide> ] ]  [ CLASS <cClass>] OF <oWeb> ;	
=> ;
	[<oNav> := ] TWebNav():New( <oWeb>, [<cId>], [<cTitle>], [<cLogo>], [<nWidth>], [<nHeight>], [<cRoute>], [<.bl.>], [<.sd.>], [<cSide>], [<cClass>] )

//	SIDEBAR --------------------------------------

#xcommand MENU GROUP <cItem> OF <oNav>  			=> <oNav>:AddMenuItem( <cItem>, nil, nil      , nil, .t., .f., .t. )
#xcommand MENU <cItem> [ ICON <cIcon> ] OF <oNav>  	=> <oNav>:AddMenuItem( <cItem>, nil, [<cIcon>], nil, .t., .f., .f. )
#xcommand ENDMENU GROUP OF <oNav>  					=> <oNav>:AddMenuItem( nil    , nil, nil      , nil, .t., .t., .t. )
#xcommand ENDMENU OF <oNav>  						=> <oNav>:AddMenuItem( nil    , nil, nil      , nil, .t., .t., .f. )

#xcommand MENUITEM <cItem> [ ICON <cIcon> ] [ ROUTE <cRoute> ] [ ACTION <cAction> ] [ <ac: ACTIVE>  ] [ CONFIRM <cConfirm>] OF <oNav>  ;
=> ;
	<oNav>:AddMenuItem( <cItem>, [<cRoute>], [<cIcon>], [<cAction>], .f.  , .f.     , .f.   ,.f.        ,[<.ac.>], [<cConfirm>], .t.      , .f.    )
	
#xcommand MENUITEM <cItem> [ ICON <cIcon> ] [ ROUTE <cRoute> ] [ ACTION <cAction> ] [ ACTIVE <lActive>  ] [ CONFIRM <cConfirm>] OF <oNav>  ;
=> ;
	<oNav>:AddMenuItem( <cItem>, [<cRoute>], [<cIcon>], [<cAction>], .f.  , .f.     , .f.   ,.f.        ,[<lActive>], [<cConfirm>], .t.   , .f.    )


#xcommand MENUITEM HEADER <cItem> OF <oNav> => <oNav>:AddMenuItemHeader( <cItem> )

#xcommand MENUITEM SEPARATOR OF <oNav>  => <oNav>:AddMenuItemSeparator()

#xcommand HTML MENUITEM OF <oNav> ;
=> ;
	#pragma __cstream |<oNav>:AddSidebarCode( %s )

#xcommand HTML SIDEBAR OF <oNav> => #pragma __cstream| <oNav>:SideBar( %s )

#xcommand HTML SIDEBAR OF <oNav> PARAMS [<v1>] [,<vn>] ;
=> ;
	#pragma __cstream |<oNav>:Sidebar( UInlinePrg( UReplaceBlocks( %s, '<$', "$>" [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) ) )

// NAVBAR -------------------------------------------

#xcommand NAVBAR NAVITEM [ ID <cId> ] [ <prm: PROMPT,LABEL> <cLabel> ] [ <act: ACTION,LINK> <cAction> ]  ;
        [ CLASS <cClass> ] [ <ac: ACTIVE, ACTIVED> ] [ <ds: DISABLE, DISABLED> ] ;
        [ CONFIRM <cConfirm>] [ CUSTOM <cCustom> ] [ <menu: MENU> ] [ <sm: SUBMENU> ] [ ICON <cIcon> ];
        OF <oNav> ;
=> ; 
	<oNav>:AddMenuNav( 'navitem', .F.   , [<cId>], [<cLabel>], [<cAction>], [<cClass>], [<.ac.>], [<.ds.>] , [<cConfirm>], [<cCustom>], [<.menu.>], [<.sm.>], [<cIcon>] )

#xcommand NAVBAR MENUITEM [ ID <cId> ] [ <prm: PROMPT,LABEL> <cLabel> ] [ <act: ACTION,LINK> <cAction> ]  ;
        [ CLASS <cClass> ] [ <ac: ACTIVE, ACTIVED> ] [ <ds: DISABLE, DISABLED> ] ;
        [ CONFIRM <cConfirm>] [ CUSTOM <cCustom> ] [ <menu: MENU> ] [ <sm: SUBMENU> ] [ ICON <cIcon> ];
        OF <oNav> ;
=> ; 
	<oNav>:AddMenuNav( 'menuitem', .F.  , [<cId>], [<cLabel>], [<cAction>], [<cClass>], [<.ac.>], [<.ds.>] , [<cConfirm>], [<cCustom>], [<.menu.>], [<.sm.>], [<cIcon>] )

		
#xcommand NAVBAR MENU CLOSE OF <oNav>    => <oNav>:AddMenuNav( 'navitem', .t. , , , , , , , , , .t., .f. )	
#xcommand NAVBAR SUBMENU CLOSE OF <oNav> => <oNav>:AddMenuNav( 'menuitem', .t., , , , , , , , , .f., .t. )	

#xcommand NAVBAR MENUITEM SEPARATOR OF <oNav> => <oNav>:AddMenuNav( 'separator' )


#xcommand HTML NAVBAR OF <oNav> ;
=> ;
	#pragma __cstream |<oNav>:AddNavBarCode( %s )		
//	-------------------------------------------------------------

// FOLDER --------------------------------------------- //
		 
#xcommand FOLDER [<oFolder>] [ ID <cId> ] ;
		[ <tabs: TABS> <cTab,...> ] ;		
		[ <prm: PROMPT, PROMPTS, ITEMS> <cPrompt,...> ] ;		
		[ GRID <nGrid> ] ;
		[ OPTION <cOption> ] ;
		[ <lAdjust: ADJUST> ] ;
		[ CLASS <cClass> ] [ FONT <cFont> ] ;	
		OF <oForm> ;
=> ;
	[ <oFolder> := ] TWebFolder():New( <oForm>, [<cId>], [\{<cTab>\}], [\{<cPrompt>\}], [<nGrid>], [<cOption>], [<.lAdjust.>] , [<cClass>], [<cFont>]) 

#xcommand DEFINE TAB <cId> [ <lFocus: FOCUS> ] [ CLASS <cClass> ] OF <oFld> => <oFld>:AddTab( <cId>, [<.lFocus.>], [<cClass>] )
#xcommand ENDTAB <oFld> => <oFld>:End()
#xcommand ENDFOLDER <oFld> => <oFld>:End()	

//	BROWSE ------------------------------------------	//

#xcommand DEFINE BROWSE [<oBrw>] [ ID <cId> ] [OPTIONS <hOptions>] [ EVENTS <aEvents>]  ;
	[ FILTER <aFilter> ] [ FILTER_ID <cFilter_id> ] [ TITLE <cTitle> ] [ <lAll: ALL> ] ; 
	[ CLASS <cClass> ] [ STYLE <cStyle> ] [ <hi: HIDE, HIDDEN> ] ;	
	OF <oForm> ;
=> ;
	[ <oBrw> := ] TWebBrowse():New( <oForm>, [<cId>], <hOptions>, [<aEvents>], [<aFilter>], [<cFilter_id>], [<cTitle>], [<.lAll.>], [<cClass>], [<cStyle>], [<.hi.>] )
	

#xcommand COL <oCol> TO <oBrw> CONFIG <hConfig> ;
=> ;						
	<oCol> := <oBrw>:AddCol( <hConfig> )
	

#xcommand INIT BROWSE <oBrw> [ DATA <aRows> ] ;
=> ;
	<oBrw>:Init( [<aRows>] )

//	CARD ------------------------------------------	//

#xcommand DEFINE CARD <oCard> [ ID <cId> ] [ CLASS <cClass> ] [ STYLE <cStyle> ] OF <oForm> ;
=> ;
	<oCard> := TWebCard():New( <oForm>, [<cId>], [<cClass>], [<cStyle>] )
	
#xcommand ENDCARD <oCard> => <oCard>:EndCard()
	
	
#xcommand HEADER <oHeader> [ CLASS <cClass> ] [ STYLE <cStyle>] OF CARD <oCard> ;
=> ;
	<oHeader> := <oCard>:AddHeader( nil ,  [<cClass>], [<cStyle>])
	
#xcommand HEADER [ CODE <cCode> ]  OF CARD <oCard> ;
=> ;
	<oCard>:AddHeader( [<cCode>] )

#xcommand CARD ENDHEADER <oHeader> => <oHeader>:End()

#xcommand BODY <oBody> [ CLASS <cClass> ] [ STYLE <cStyle>] OF CARD <oCard> ;
=> ;
	<oBody> := <oCard>:AddBody( nil ,  [<cClass>], [<cStyle>])
	
#xcommand BODY [ CODE <cCode> ]OF CARD <oCard> ;
=> ;
	<oCard>:AddBody( [<cCode>])

#xcommand CARD ENDBODY <oBody> => <oBody>:End()

#xcommand FOOTER <oFooter> [ CLASS <cClass> ] [ STYLE <cStyle>] OF CARD <oCard> ;
=> ;
	<oFooter> := <oCard>:AddFooter( nil ,  [<cClass>], [<cStyle>])
	
#xcommand FOOTER [ CODE <cCode> ] OF CARD <oCard> ;
=> ;
	<oCard>:AddFooter( [<cCode>] )
	
#xcommand CARD ENDFOOTER <oFooter> => <oFooter>:End()	

//	ACCORDION -------------------------------------	//

#xcommand DEFINE ACCORDION <oAccordion> [ ID <cId> ] [ CLASS <cClass> ] [ STYLE <cStyle> ] ;
	[ <u: UNIQUE> ] OF <oForm> ;
=> ;
	<oAccordion> := TWebAccordion():New( <oForm>, [<cId>], [<cClass>], [<cStyle>], [<.u.>] )
	
#xcommand ENDACCORDION <oAccordion> => <oAccordion>:End()

#xcommand ADDSECTION <oSection> [ ID HEADER <cId_Header> ] [ ID BODY <cId_Body> ] [ CLASS <cClass> ] OF ACCORDION <oAccordion> ;
=> ;
	<oSection> := <oAccordion>:AddSection( [<cId_Header>], [<cId_Body>], [<cClass>] )
	
#xcommand ENDSECTION <oSection> => <oSection>:End()

#xcommand HEADER [ <oHeader> ] [ <prm: CODE,PROMPT,LABEL> <cCode> ] [ CLASS <cClass> ] OF SECTION <oSection> ;
=> ;
	[ <oHeader> := ] <oSection>:Header( [<cCode>], [<cClass>] )

#xcommand SECTION ENDHEADER <oHeader> => <oHeader>:End()

#xcommand BODY [ <oBody> ] [ <prm: CODE,PROMPT,LABEL> <cCode> ] [ CLASS <cClass> ] [ STYLE <cStyle> ] [ <ls: SHOW> ] OF SECTION <oSection> ;
=> ;
	[ <oBody> := ] <oSection>:Body( [<cCode>], [<cClass>], [<cStyle>], [<.ls.>]  )

#xcommand SECTION ENDBODY <oBody> => <oBody>:End()