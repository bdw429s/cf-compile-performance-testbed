<cfscript>
	variables.webRoot = expandPath( "/" );
	// Get a recursive list of all the file to parse and compile
	srcToCompile = directoryList( expandPath("srcToCompile"), true, 'array', '*.cfm|*.cfc' )

	if( isBoxLang() ) {
		writeoutput( "<h1>BoxLang</h1>" )
		// use this one when comparing to Lucee  (parse/compile only)
		compiler = compilerBoxLang;
		// Use this one when comparing to Adobe (parse/compile + instanatiation)
		compiler = compilerManualInclude;
		prep = prepBoxlang;
	} else if( isLucee() ) {
		writeoutput( "<h1>Lucee</h1>" )
		// Lucee will only do parse/compile
		compiler = compilerLucee;
		prep = prepLucee;
	} else {
		writeoutput( "<h1>Adobe</h1>" )
		// Adobe actually instantiates the CFCs in order to compile them
		compiler = compilerManualInclude;
		prep = prepAdobe;
	}

	// Setup the test
	prep();
	results = [];

	start = getTickCount();	
	// Loop over all the files to parse/compile them
	srcToCompile.each( (path)=>{
		results.append( {
			path : path,
			time : compiler( path )
		} );
	}, true, 20 ) // parallel, 20 threads
	
	totalTime = getTickCount() - start;

	// Output stats
	writeoutput( "Compiled #srcToCompile.len()# files in #totalTime# ms<br>" );
	writeoutput( "Average time per file: #round( totalTime/srcToCompile.len() )# ms" );

	results.sort( (a,b) => b.time - a.time );
	writeoutput( "<table>" )
		results.each( ( result )=>{
			writeoutput( "<tr><td>#result.path#</td><td>#result.time# ms</td></tr>" );
		} );
	writeoutput( "</table>" )

	/**
	 * Approach used for Adobe and BoxLang when testing against Adobe.  It just manually includes or instnantiates the file to force compilation
	 */
	function compilerManualInclude( path ) {
		var start = getTickCount();
		if( path.endsWith( '.cfm' ) ) {
			path = path.replace( webRoot, "" ).replace( "\", "/" );
			try {
				if( not path contains 'Application.cfm' ) {
					cfsavecontent( variable="local.dummy" ){
						cfinclude( template="#path#" );
					}
				}
			} catch( any e ) {
				//writeoutput( encodeForHTML( e.message ) & "<br>" );
			}	
		} else if( path.endsWith( '.cfc' ) ) {
			path = path.replace( webRoot, "" ).replace( "\", "." ).replace( ".cfc", "" );
			try {
				var obj = createObject( "component", path );
			} catch( any e ) {
				//writeoutput( e.message & "<br>" );
			}
			
		}
		return getTickCount() - start;
	}

	/**
	 * Setup for Adobe ColdFusion
	 */
	function prepAdobe() {
		var dir = getCanonicalPath( server.coldfusion.rootdir & '/../cfclasses' );
		if( directoryExists( dir ) ) {
			directoryDelete( dir, true );
			directoryCreate( dir );
		}
		var adminObj = createObject("Component", "cfide.adminapi.administrator");
		adminObj.login( "password" ); // default password for my local CommandBox servers
		var rtService = createObject("component", "cfide.adminapi.runtime");
		rtService.clearTrustedCache();
		
	}

	/**
	 * Force parse/compile for BoxLang
	 */
	function compilerBoxLang( path ) {
		var rfp = jResolvedFilePath.ofReal( "", "", path, createObject( 'java', 'java.nio.file.Paths' ).get( path ) )
		var start = getTickCount();	
		if( path.endsWith( '.cfm' ) ) {
			rl.loadTemplateAbsolute( getBoxContext(), rfp );
		} else if( path.endsWith( '.cfc' ) ) {
			rl.loadClass( rfp,  getBoxContext() );
		}
		return getTickCount() - start;
	}

	/**
	 * Setup for BoxLang
	 */
	function prepBoxlang() {
		var dir = server.boxlang.runtimeHome & '/classes';
		if( directoryExists( dir ) ) directoryDelete( dir, true );
		pagePoolClear()
		variables.rl = createObject( 'java', 'ortus.boxlang.runtime.runnables.RunnableLoader' ).getInstance();
		variables.jResolvedFilePath = createObject( 'java', 'ortus.boxlang.runtime.util.ResolvedFilePath' );
	}

	/**
	 * Force parse/compile for Lucee
	 */
	function compilerLucee( path ) {
		var start = getTickCount();	
		PageSourceImpl
					.best( getPageContext().getPageSources( makePathRelative( path ) ) )
					.loadPage( getPageContext(), true );
		return getTickCount() - start;
	}

	/**
	 * Setup for Lucee
	 */
	function prepLucee() {
		var dir = expandPath( getDirectoryFromPath( server.lucee.loaderPath ) & '../lucee-server/context/cfclasses' );
		if( directoryExists( dir ) ) directoryDelete( dir, true );
		pagePoolClear()
		variables.PageSourceImpl = createObject( "java", "lucee.runtime.PageSourceImpl" );
	}

	/**
	 * Detect if running on Lucee
	 */
	function isLucee() {
		return server.keyExists( "lucee" );
	}

	/**
	 * Detect if running on BoxLang
	 */
	function isBoxLang() {
		return server.keyExists( "boxlang" );
	}

	// ***********************************************************************************
	// ****** These are all just utility methods, ultimatley copied from CommandBox ******
	// ****** and used to force an absolute path to a relative path                 ******
	// ***********************************************************************************
	
	/**
	 * Accepts an absolute path and returns a relative path
	 * Does NOT apply any canonicalization
	 */
	string function makePathRelative( required string absolutePath ){
		// If one of the folders has a period, we've got to do something special.
		// C:/users/brad.development/foo.cfc turns into /C__users_brad_development/foo.cfc
		if ( getDirectoryFromPath( arguments.absolutePath ) contains "." ) {
			var leadingSlash = arguments.absolutePath.startsWith( "/" );
			var UNC          = arguments.absolutePath.startsWith( "\\" );
			var mappingPath  = getDirectoryFromPath( arguments.absolutePath );
			mappingPath      = mappingPath.replace( "\", "/", "all" );
			mappingPath      = mappingPath.listChangeDelims( "/", "/" );

			var mappingName = mappingPath.replace( ":", "_", "all" );
			mappingName     = mappingName.replace( ".", "_", "all" );
			mappingName     = mappingName.replace( "/", "_", "all" );
			mappingName     = "/" & mappingName;

			// *nix needs this
			if ( leadingSlash ) {
				mappingPath = "/" & mappingPath;
			}

			// UNC network paths
			if ( UNC ) {
				var mapping = locateUNCMapping( mappingPath );
				return mapping & "/" & getFileFromPath( arguments.absolutePath );
			} else {
				createMapping( mappingName, mappingPath );
				return mappingName & "/" & getFileFromPath( arguments.absolutePath );
			}
		}

		// *nix needs to include first folder due to Lucee bug.
		// So /usr/brad/foo.cfc becomes /usr
		if ( !isWindows() ) {
			var firstFolder = listFirst( arguments.absolutePath, "/" );
			var path        = listRest( arguments.absolutePath, "/" );
			var mapping     = locateUnixDriveMapping( firstFolder );
			return mapping & "/" & path;
		}

		// UNC network path.
		if ( arguments.absolutePath.left( 2 ) == "\\" ) {
			// Strip the \\
			arguments.absolutePath = arguments.absolutePath.right( -2 );
			if ( arguments.absolutePath.listLen( "/\" ) < 2 ) {
				throw(
					"Can't make relative path for [#absolutePath#].  A mapping must point ot a share name, not the root of the server name."
				);
			}

			// server/share
			var UNCShare = listFirst( arguments.absolutePath, "/\" ) & "/" & listGetAt(
				arguments.absolutePath,
				2,
				"/\"
			);
			// everything after server/share
			var path    = arguments.absolutePath.listDeleteAt( 1, "/\" ).listDeleteAt( 1, "/\" );
			var mapping = locateUNCMapping( UNCShare );
			return mapping & "/" & path;

			// Otherwise, do the "normal" way that re-uses top level drive mappings
			// C:/users/brad/foo.cfc turns into /C_Drive/users/brad/foo.cfc
		} else {
			var driveLetter = listFirst( arguments.absolutePath, ":" );
			var path        = listRest( arguments.absolutePath, ":" );
			var mapping     = locateDriveMapping( driveLetter );
			return mapping & path;
		}
	}

	/**
	 * Accepts a Windows drive letter and returns a CF Mapping
	 * Creates the mapping if it doesn't exist
	 */
	string function locateDriveMapping( required string driveLetter ){
		var mappingName = "/" & arguments.driveLetter & "_drive";
		var mappingPath = arguments.driveLetter & ":/";
		createMapping( mappingName, mappingPath );
		return mappingName;
	}

	/**
	 * Accepts a Unix root folder and returns a CF Mapping
	 * Creates the mapping if it doesn't exist
	 */
	string function locateUnixDriveMapping( required string rootFolder ){
		var mappingName = "/" & arguments.rootFolder & "_root";
		var mappingPath = "/" & arguments.rootFolder & "/";
		createMapping( mappingName, mappingPath );
		return mappingName;
	}

	/**
	 * Accepts a Windows UNC network share and returns a CF Mapping
	 * Creates the mapping if it doesn't exist
	 */
	string function locateUNCMapping( required string UNCShare ){
		var mappingName = "/" & arguments.UNCShare.replace( "/", "_" ).replace( ".", "_", "all" ) & "_UNC";
		var mappingPath = "\\" & arguments.UNCShare & "/";
		createMapping( mappingName, mappingPath );
		return mappingName;
	}

	function createMapping( mappingName, mappingPath ){
		var mappings = getApplicationSettings().mappings;
		if ( !structKeyExists( mappings, mappingName ) || mappings[ mappingName ] != mappingPath ) {
			mappings[ mappingName ]= mappingPath;
			application action     ="update" mappings="#mappings#";
		}
	}

	/*
	 * Turns all slashes in a path to forward slashes except for \\ in a Windows UNC network share
	 * Also changes double slashes to a single slash
	 */
	function normalizeSlashes( string path ){
		if ( path.left( 2 ) == "\\" ) {
			return "\\" & path.replace( "\", "/", "all" ).right( -2 );
		} else {
			return path.replace( "\", "/", "all" ).replace( "//", "/", "all" );
		}
	}

	/**
	 * Detect if OS is Windows
	 */
	private boolean function isWindows(){
		return createObject( "java", "java.lang.System" )
			.getProperty( "os.name" )
			.toLowerCase()
			.contains( "win" );
	}
</cfscript>