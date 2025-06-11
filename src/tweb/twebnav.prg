#xcommand TEXT TO <var> => #pragma __stream|<var> += %s

CLASS TWebNav FROM TWebControl

	DATA cTitle					INIT 'App'
	DATA cLogo 						INIT '' 
	DATA cRoute					INIT '' 
	DATA nLogoWidth 				INIT 30
	DATA nLogoHeight				INIT 30 
	DATA aMenuItem 				INIT {}
	DATA aMenuNav 					INIT {}
	DATA lBurguerLeft				INIT .T.
	DATA lSideBar					INIT .F.
	DATA cSideBarCode				INIT ''
	DATA cSide						INIT 'left'


	METHOD New() 					CONSTRUCTOR
	METHOD Activate()
	METHOD AddMenuNav( cType, lClose, cId, cLabel, cAction, cClass, lActive, lDisabled, cConfirm, cCustom )	
	METHOD AddMenuItem( cItem, cLink, cAction, cIcon  )
	METHOD AddMenuItemSeparator()
	METHOD AddMenuItemHeader( cCaption )
	
	METHOD AddSidebarCode( cCode )
	METHOD AddNavBarCode( cCode )
	
	METHOD DrawMenuNav()

	METHOD DrawMenuItem()
	

	METHOD SideBar( cCode )		INLINE  ( ::lSideBar := .t., ::cSideBarCode += cCode )


ENDCLASS 

METHOD New( oParent, cId, cCaption, cLogo, nLogoWidth, nLogoHeight, cRoute, lBurguerLeft, lSidebar, cSide, cClass ) CLASS TWebNav

	DEFAULT cId TO ''
	DEFAULT cCaption TO ''
	DEFAULT cLogo TO ''
	DEFAULT nLogoWidth TO 30
	DEFAULT nLogoHeight TO 30
	DEFAULT cRoute TO ''
	DEFAULT lBurguerLeft TO .T.
	DEFAULT lSideBar TO .F.
	DEFAULT cSide TO 'left'
	DEFAULT cClass TO ''
	
	
	::oParent 		:= oParent
	::cId			:= cId
	::cTitle		:= cCaption
	::cLogo			:= cLogo
	::nLogoWidth	:= nLogoWidth
	::nLogoHeight	:= nLogoHeight
	::cRoute		:= cRoute
	::lBurguerLeft := lBurguerLeft 
	::lSideBar 	:= lSideBar
	::cSide 		:= lower(cSide)
	::cClass 		:= cClass
	
	

	IF Valtype( oParent ) == 'O'	
		oParent:AddControl( SELF )	
	ENDIF

RETU SELF

METHOD Activate() CLASS TWebNav

	LOCAL cHtml := ''
	local  nLen
	

	nLen := len( ::aMenuItem ) 
	
	
	//	Amb la versio 2.0 dels menus la clausula SIDEBAR sempre serà .T. 
	// si existeix al menys 1 menuitem. 
	// Per temes de compatibilitat en el PREPRO deixarem el concepte SIDEBAR 
	// per q no tindrà cap efecte...
		
	if nLen > 0		
		::lSideBar := .t.
	endif
	
	//	------------------------------------------------------------
	
	
	


	//cHtml := '<nav class="navbar navbar-dark bg-dark ">' + CRLF
	cHtml := '<nav class="navbar navbar-expand navbar-dark bg-dark ">' + CRLF
	
	IF ::lBurguerLeft .and. ::lSideBar
		cHtml += '<button class="navbar-toggler btnsidebar" type="button" style="margin-right: 10px;display:block;" data-action="toggle" data-side="' + ::cSide + '" >' + CRLF
		cHtml += ' <span class="navbar-toggler-icon"></span>' + CRLF
		cHtml += '</button>' + CRLF
	ELSEIF ::lBurguerLeft .and. nLen > 0
		cHtml += '<button class="navbar-toggler" type="button" style="margin-right: 10px;display:block;" data-toggle="collapse" data-target="#navbar-list" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">' + CRLF
		cHtml += ' <span class="navbar-toggler-icon"></span>' + CRLF
		cHtml += '</button>' + CRLF
	ENDIF
	
	
	cHtml += '<a class="navbar-brand mr-auto" href="' + ::cRoute + '">' + CRLF
	
	if !empty( ::cLogo ) 
		cHtml += '<img id="nav_logo" src="' + ::cLogo + '" width="' + ltrim(str(::nLogoWidth)) + '" height="' + ltrim(str(::nLogoHeight)) + '" alt="logo">' + CRLF
	endif
	
	//cHtml += '<span id="nav_title" style="vertical-align: middle;" >' + ::cTitle + '</span>' + CRLF
	cHtml += '<span id="nav_title" >' + ::cTitle + '</span>' + CRLF

	cHtml += '</a>' + CRLF
	
	IF ! ::lBurguerLeft .and. ::lSideBar
		cHtml += '<button class="navbar-toggler btnsidebar" type="button" data-action="toggle" data-side="' + ::cSide + '" style="display:block;">' + CRLF
		cHtml += ' <span class="navbar-toggler-icon"></span>' + CRLF
		cHtml += '</button>' + CRLF
	ELSEIF 	! ::lBurguerLeft .and. nLen > 0			
		cHtml += '<button class="navbar-toggler" style="display:block;" type="button" data-toggle="collapse" data-target="#navbar-list" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">' + CRLF
		cHtml += ' <span class="navbar-toggler-icon"></span>' + CRLF
		cHtml += '</button>' + CRLF
	ENDIF
	
	
	cHtml += ::DrawMenuNav()
	
		
	
	IF ::lSideBar
	
		cHtml += '<div class="sidebars">'  + CRLF
		
		do case
			case ::cSide == 'left'
				cHtml += '  <div class="sidebar left" style="left: -99999px;">'  + CRLF
			case ::cSide == 'right'
				cHtml += '  <div class="sidebar right" style="right: -99999px;">' + CRLF		
			otherwise
				cHtml += '  <div class="sidebar left" style="left: -99999px;">'  + CRLF
		endcase
		
		
		cHtml += ::cSideBarCode
		
		cHtml += '<div class="menu-items ' + ::cClass + '">' + CRLF
		cHtml += '<ul>' + CRLF
		cHtml += ::DrawMenuItem()	 + CRLF
		cHtml += '</ul>' + CRLF
		cHtml += '</div>' + CRLF
		
		cHtml += '  </div>' + CRLF
		cHtml += '</div>' + CRLF
		
	ELSE  
	
		cHtml += '<div class="collapse navbar-collapse" id="navbar-list">' + CRLF
		cHtml += '<ul class="navbar-nav">'	 + CRLF
		cHtml += ::DrawMenuItem()	 + CRLF
		cHtml += '</ul>' + CRLF
		cHtml += '</div>' + CRLF				
		
	ENDIF		

	cHtml += '</nav>' + CRLF
	
	IF ::lSideBar
		cHtml += '</div>' + CRLF
	ENDIF
	
	cHtml += '<script>' + CRLF
	cHtml += '$( document ).ready(function() {'	 + CRLF
	cHtml += ' _SidebarInit();' + CRLF
	cHtml += '}) ' + CRLF
	cHtml += '</script>'	 + CRLF
	

RETU cHtml

//	-----------------------------------------------------	//

METHOD DrawMenuNav() CLASS TWebNav
	local nLen 	:= len( ::aMenuNav )
	local cHtml 	:= ''
	local oItem, n  	
	
	if nLen == 0
		retu ''
	endif	
	
	//	NavBar			
	
	cHtml += '<div class="collapse navbar-collapse" id="navbarNavDropdown">' + CRLF
	cHtml += '  <ul class="navbar-nav">' + CRLF

	for n := 1 to nLen 	
	
		oItem := ::aMenuNav[n]

		do case		
			
			case oItem[ 'navitem' ] .and. !oItem[ 'menu' ] .and. ! oItem[ 'close' ]	//	NavItem

				cHtml += '<li '
				
				if !empty( oItem[ 'id' ] )
					cHtml += 'id="' + oItem[ 'id' ] + '" '
				endif				
				
				cHtml += ' class="nav-item '
				
					if oItem[ 'active' ]
						cHtml += ' active'
					elseif oItem[ 'disabled' ]
						cHtml += ' disabled'					
					endif	

					if !empty( oItem[ 'class' ] )
						cHtml += ' ' + oItem[ 'class' ] 
					endif
				
				cHtml += '">' + CRLF
				cHtml += '  <a class="nav-link" ' 
			
					if !empty( oItem[ 'action' ] )
						if At( '(', oItem[ 'action' ] ) > 0
							cHtml += 'href="#" onclick="' + oItem[ 'action' ] + '" '
						else
							cHtml += 'href="' + oItem[ 'action' ] + '" '
						endif
					else
						cHtml += 'href="#"'
					endif				
				
				cHtml += '>' 
				
				if !empty( oItem[ 'icon' ] )
					cHtml += oItem[ 'icon' ] + '&nbsp;' 
				endif								
				
				cHtml += oItem[ 'label' ] + '</a>' + CRLF
				
				cHtml += '</li>' + CRLF			
			
			case oItem[ 'navitem' ] .and. oItem[ 'menu' ]	.and. !oItem[ 'close' ]		//	NavItem Menu			
			
				cHtml += '<li '
				
				if !empty( oItem[ 'id' ] )
					cHtml += 'id="' + oItem[ 'id' ] + '" '
				endif					
				
				cHtml += 'class="nav-item dropdown'
				
				if !empty( oItem[ 'class' ] )
					cHtml += ' ' + oItem[ 'class' ] 
				endif
				
				cHtml += '">' + CRLF
				
				cHtml += '<a class="nav-link dropdown-toggle" '	 
				cHtml += 'href="#" id="navbarDropdownMenuLink" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">'
				
				if !empty( oItem[ 'icon' ] )
					cHtml += oItem[ 'icon' ] + '&nbsp;' 
				endif				
				
				cHtml += oItem[ 'label' ]
				cHtml += '</a>' + CRLF
				
				cHtml += '<ul class="dropdown-menu" aria-labelledby="navbarDropdownMenuLink">' + CRLF
			
			case oItem[ 'menuitem' ] .and. !oItem[ 'submenu' ]	//	NavItem 
						
				cHtml += '<li '
				
				if !empty( oItem[ 'id' ] )
					cHtml += 'id="' + oItem[ 'id' ] + '" '
				endif					
				
				if !empty( oItem[ 'class' ] )
					cHtml += ' class="' + oItem[ 'class' ] + '" '
				endif				
				
				cHtml += '><a class="dropdown-item" '								
				
					if !empty( oItem[ 'action' ] )
						if At( '(', oItem[ 'action' ] ) > 0
							cHtml += 'href="#" onclick="' + oItem[ 'action' ] + '" '
						else
							cHtml += 'href="' + oItem[ 'action' ] + '" '
						endif
					else
						cHtml += 'href="#"'
					endif				
				
				cHtml += '>' 
				
				if !empty( oItem[ 'icon' ] )
					cHtml += '      ' + oItem[ 'icon' ] + '&nbsp;' 
				endif				
				
				cHtml += oItem[ 'label' ] + '</a>' + CRLF
				cHtml += '</li>' + CRLF
						
			case oItem[ 'menuitem' ] .and. oItem[ 'submenu' ]	.and. ! oItem[ 'close' ]	//	NavItem Submenu
							
				cHtml += '<li '
				
				if !empty( oItem[ 'id' ] )
					cHtml += 'id="' + oItem[ 'id' ] + '" '
				endif					
				
				cHtml += 'class="dropdown-submenu'
				
				if !empty( oItem[ 'class' ] )
					cHtml += ' ' + oItem[ 'class' ] 
				endif
				
				cHtml += '">' + CRLF
				
				cHtml += '     <a class="dropdown-item dropdown-toggle '
				
					if oItem[ 'disabled' ]
						cHtml += ' disabled'					
					endif
					
					cHtml += '" '						
					
					if !empty( oItem[ 'action' ] )
						if At( '(', oItem[ 'action' ] ) > 0
							cHtml += 'href="#" onclick="' + oItem[ 'action' ] + '" '
						else
							cHtml += 'href="' + oItem[ 'action' ] + '" '
						endif
					else
						cHtml += 'href="#"'
					endif						
				
				
				cHtml += '>'
				
				if !empty( oItem[ 'icon' ] )
					cHtml += '      ' + oItem[ 'icon' ] + '&nbsp;' 
				endif
				
				cHtml += oItem[ 'label' ] + '</a>' + CRLF
				cHtml += '    <ul class="dropdown-menu">' + CRLF
				
			case oItem[ 'menuitem' ] .and. oItem[ 'submenu' ]	.and. oItem[ 'close' ] 	//	End NavItem Submenu
				
				cHtml += '  </ul>' + CRLF 
				cHtml += '</li>' + CRLF 
			
			case oItem[ 'menuitem' ] .and. oItem[ 'separator' ]			
				
				cHtml += '<div class="dropdown-divider"></div>' + CRLF
				
			case oItem[ 'navitem' ] .and. oItem[ 'menu' ] .and. oItem[ 'close' ]		//	End NavItem
			
				
				cHtml += '  </ul>' + CRLF
				cHtml += '</li>' + CRLF
			
			case !empty( oItem[ 'separator' ] )
				
				cHtml += '<div class="dropdown-divider"></div>' + CRLF
			

				
			otherwise								
			
		endcase
	next
	
	//	End NavBar	
	
	cHtml += '  </ul>' + CRLF
	cHtml += '</div>' + CRLF	
	
	if !empty( oItem[ 'custom' ] )							
		cHtml += oItem[ 'custom' ]	
	endif
	
	
	
	//cHtml += '  </div>' + CRLF	
	//cHtml += '</div>' + CRLF	
	
	

	
	TEXT TO cHtml 
<script>
	$('.dropdown-menu a.dropdown-toggle').on('click', function(e) {
	  if (!$(this).next().hasClass('show')) {
		$(this).parents('.dropdown-menu').first().find('.show').removeClass('show');
	  }
	  var $subMenu = $(this).next('.dropdown-menu');
	  $subMenu.toggleClass('show');


	  $(this).parents('li.nav-item.dropdown.show').on('hidden.bs.dropdown', function(e) {
		$('.dropdown-submenu .show').removeClass('show');
	  });


	  return false;
	});
</script>	
	ENDTEXT			

retu cHtml

//	-----------------------------------------------------	//


METHOD DrawMenuItem() CLASS TWebNav

	local nLen 	:= len( ::aMenuItem )
	local cHtml 	:= ''
	local oItem, n  
	local lOpenMenu := .f. 

	if nLen == 0
		retu ''
	endif
	
	for n := 1 to nLen 	
	
		oItem := ::aMenuItem[n]		
	
		do case
		
			case oItem[ 'menu' ] .and. oItem[ 'group' ] .and. !oItem[ 'endmenu' ]
	
				cHtml += '<div class="menu-items sidebar-menu-items">' + CRLF
				cHtml += '  <ul>' + CRLF
				
				if !empty( oItem[ 'item' ] )												
					cHtml += '<li class="header-menu">' + CRLF
					cHtml += '  <span>' + oItem[ 'item' ] + '</span>' + CRLF
					cHtml += '</li>' + CRLF
				endif						
				
		
			case oItem[ 'menuitem' ] .and. !oItem[ 'header' ]
				
				if ! lOpenMenu
					cHtml += '<li class="nav-item sidebar-nav-item">' + CRLF 
					cHtml += '	<a class="nav-link sidebar-nav-menu '
				else
					cHtml += '	<a class="dropdown-item sidebar-dropdown-item  '
				endif
				
				
				cHtml += if( oItem[ 'active'], 'sidebar-item-active', '') + '" '

				if !empty( oItem[ 'action' ] )
			
					if At( '(', oItem[ 'action' ] ) > 0
						cHtml += 'href="#" onclick="' + oItem[ 'action' ] + '" >'
					else
						cHtml += 'href="' + oItem[ 'action' ] + '" >'
					endif
				else
					cHtml += ' href="' + oItem[ 'link' ] + '" >' + CRLF 
				endif				
			
				if !empty( oItem[ 'icon' ] )
					cHtml += '      ' + oItem[ 'icon' ] + '&nbsp;' 
				endif
				
				cHtml += oItem[ 'item' ] + CRLF
				
				cHtml += '	</a>' + CRLF 
				if ! lOpenMenu
					cHtml += '</li>' + CRLF 	
				endif
				
			case oItem[ 'menuitem' ] .and. oItem[ 'header' ]
			
				if !empty( oItem[ 'item' ] )
					cHtml += '<div class="dropdown-header">' + oItem[ 'item' ] + '</div>' + CRLF
				endif				
				

			case oItem[ 'menu' ] .and. ! oItem[ 'endmenu' ] .and. ! oItem[ 'group' ]				
			
				cHtml += '<li class="nav-item dropdown sidebar-nav-item">' + CRLF 
				cHtml += '  <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">' + CRLF
				
				if !empty( oItem[ 'icon' ] )
					cHtml += '    ' + oItem[ 'icon' ] + '&nbsp;' 			
				endif	

				cHtml += oItem[ 'item' ] + CRLF				
				cHtml += '</a>' + CRLF				
				
				cHtml += '  <div class="dropdown-menu sidebar-dropdown-menu" aria-labelledby="navbarDropdown">' + CRLF
			
				lOpenMenu := .t.
		
			case oItem[ 'menu' ] .and. oItem[ 'endmenu' ] .and. !oItem[ 'group' ]
			
				cHtml += '    </div>' + CRLF 
				cHtml += '  </li>' + CRLF 	

				lOpenMenu := .f.				
				
			
			case oItem[ 'menu' ] .and. oItem[ 'endmenu' ] .and. oItem[ 'group' ]						
			
				cHtml += '	</ul>' + CRLF 
				cHtml += '</div>' + CRLF
				
		
			case oItem[ 'separator' ]
			
				cHtml += '<div class="dropdown-divider"></div>' + CRLF	
				

			case !empty( oItem[ 'code' ] )
		
				cHtml += oItem[ 'code' ]				
				
			otherwise 
				
		endcase	
	
	next

RETU cHtml 


METHOD AddMenuItem( cMenu, cLink, cIcon, cAction, lMenu, lEndMenu, lGroup, lSeparator, lActive, cConfirm, lMenuItem, lHeader ) CLASS TWebNav

	hb_default( @cMenu, '' )
	hb_default( @cLink, '' )
	hb_default( @cIcon, '' )
	hb_default( @cAction, '' )
	hb_default( @lMenuItem, .F. )
	hb_default( @lMenu, .F. )
	hb_default( @lEndMenu, .F. )
	hb_default( @lGroup, .F. )	
	hb_default( @lSeparator, .F. )	
	hb_default( @lActive, .f. )	
	hb_default( @cConfirm, '' )	
	hb_default( @lHeader, .f. )	

	Aadd( ::aMenuItem, { 'item' => cMenu,;
						   'link' => cLink,;
						   'action' => cAction,;
						   'icon' => cIcon,;
						   'menuitem' => lMenuItem,;
						   'menu' => lMenu,;
						   'endmenu' => lEndMenu,;
						   'group' => lGroup,;
						   'separator' => lSeparator,;
						   'active' => lActive,;
						   'header' => lHeader,;
						   'code' => '',;
						   'confirm' => cConfirm } )
	
RETU NIL 

METHOD AddMenuItemSeparator() CLASS TWebNav	


	Aadd( ::aMenuItem, {  'item' => '',;
							'link' => '',;
							'action' => '',;
							'icon' => '',;
							'menuitem' => .f.,;
							'menu' => .f.,;
							'endmenu' => .f.,;
							'group' => .f.,;
							'separator' => .T.,;
							'active' => .f.,;
						    'header' => .f.,;
							'code' => '',;
							'confirm' => '' } )
	
RETU NIL 

METHOD AddMenuItemHeader( cCaption ) CLASS TWebNav	

	hb_default( @cCaption, '' )
	
	Aadd( ::aMenuItem, {  'item' => cCaption,;
							'link' => '',;
							'action' => '',;
							'icon' => '',;
							'menuitem' => .t.,;
							'menu' => .f.,;
							'endmenu' => .f.,;
							'group' => .f.,;
							'separator' => .f.,;
							'active' => .f.,;
						    'header' => .T.,;
						    'code' => '',;
							'confirm' =>''} )
	
RETU NIL 

METHOD AddSidebarCode( cCode ) CLASS TWebNav	

	hb_default( @cCode, '' )
	
	Aadd( ::aMenuItem, {  'item' => '',;
							'link' => '',;
							'action' => '',;
							'icon' => '',;
							'menuitem' => .f.,;
							'menu' => .f.,;
							'endmenu' => .f.,;
							'group' => .f.,;
							'separator' => .f.,;
							'active' => .f.,;
						    'header' => .f.,;
						    'code' => cCode,;
							'confirm' => '' } )
	
RETU NIL 

//	NAVBAR -------------------------------------------------------

METHOD AddMenuNav( cType, lClose, cId, cLabel, cAction, cClass, lActive, lDisabled, cConfirm, cCustom, lMenu, lSubMenu, cIcon ) CLASS TWebNav

	hb_default( @cType, '' )
	hb_default( @lClose, .F. )
	hb_default( @cId, '' )
	hb_default( @cLabel, '' )
	hb_default( @cAction, '' )
	hb_default( @cClass, '' )
	hb_default( @lActive, .F. )
	hb_default( @lDisabled, .F. )
	hb_default( @cConfirm, '' )	
	hb_default( @cCustom, '' )	
	hb_default( @lMenu, .F. )	
	hb_default( @lSubMenu, .F. )	
	hb_default( @cIcon, '' )	
	
	
	cType := lower( cType )

	Aadd( ::aMenuNav, { 'close' => lClose,;
						  'id' => cId,;
						  'label' => cLabel,;
						  'action' => cAction,;
						  'class' => cClass,;
						  'active' => lActive,;
						  'disabled' => lDisabled,;
						  'confirmed' => cConfirm,;
						  'navitem' => ( cType == 'navitem' ) ,;
						  'menuitem' => ( cType == 'menuitem' ) ,;
						  'menu' => lMenu,;
						  'submenu' => lSubMenu,;
						  'separator' => ( cType == 'separator' ),;
						  'icon' => cIcon ,;
						  'custom' => cCustom ;
						})
	
RETU NIL 

METHOD AddNavBarCode( cCustom ) CLASS TWebNav	

	hb_default( @cCustom, '' )
	
	Aadd( ::aMenuNav, { 'close' => .f.,;
						  'id' => '',;
						  'label' => '',;
						  'action' => '',;
						  'class' => '',;
						  'active' => .f.,;
						  'disabled' => .f.,;
						  'confirmed' => '',;
						  'navitem' => .f.,;
						  'menuitem' => .f.,;
						  'menu' => .f.,;
						  'submenu' => .f.,;
						  'separator' => .f.,;
						  'icon' => '' ,;
						  'custom' => cCustom ;
						})
	
RETU NIL 
