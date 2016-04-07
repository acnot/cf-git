<cfcomponent>

	<cfsetting requesttimeout="600">

	<cfscript>
		this.version = 5; // last change 4-07-2016, created 2-22-2016 by Max Kuklin

		this.master_server = ["example.com", "127.0.0.1"];

		this.server_ip = CreateObject("java", "java.net.InetAddress").getLocalHost().getHostAddress();

		this.script_location = "gitbot.cfc";

		this.credentials = { username = "enter your username", password = "enter your password" };
		this.CheckAuthentication();

		this.sites = {
			/*
			1 = {
				"name" = "site prod",
				"host" = "example.com",
				"servers" = [["127.0.0.1", "c:\webserver\example.com"], ["127.0.0.2", "c:\webserver\example.com"]],
				"branch" = "master"
			}
			*/
		};
	</cfscript>

	<cffunction name="page" access="remote" returnformat="plain">
		<cftry>

		<cfif not arrayContains(this.master_server, this.server_ip) and not arrayContains(this.master_server, cgi.http_host)>
			<cflocation url="http://#this.master_server[1]#/#this.script_location#?method=page">
		</cfif>

		<cfoutput>
		<style>
			body { font: 1em Arial, Helvetica, sans-serif; }
			.command { font: 1em Tahoma; margin-top: 15px; }
			pre { margin: 5px; }
			input, select { padding: 5px 10px; margin: 10px 2px; font-size: 15px; }
			option.prod { color: red; }
		</style>

		<cfparam name="form.site_id" default="">
		<cfparam name="form.branch" default="">
		<cfparam name="form.commit" default="">

		<form action="" method="post" onsubmit="setTimeout(function(){ document.getElementById('update').disabled = true }, 50)">
			<select name="site_id" onchange="this.selectedOptions[0].dataset.branch && (document.getElementById('branch').value = this.selectedOptions[0].dataset.branch)" required>
				<option value="">Choose a site</option>
				<cfset local.keys = StructKeyArray(this.sites)>
				<cfset keys.sort("numeric", "asc")>
				<cfloop array="#keys#" index="site_id">
					<option value="#site_id#" data-branch="#this.sites[site_id].branch#" <cfif form.site_id eq site_id>selected</cfif> <cfif find("prod", this.sites[site_id].name)>class="prod"</cfif>>#this.sites[site_id].host#</option>
				</cfloop>
			</select>
			<input type="text" name="branch" id="branch" value="#form.branch#" placeholder="branch name" required>
			<input type="text" name="commit" value="#form.commit#" placeholder="commit SHA hash or tag name (optional)" style="width:350px">
			<input type="submit" name="update" id="update" value="Update">
		</form>

		<cfif structKeyExists(form, "update")>
			<cfinvoke method="update" argumentCollection="#structCopy(form)#">
		</cfif>

		</cfoutput>

		<cfcatch type="any">
			<cfcontent reset="true">
			<cfdump var="#cfcatch#">
		</cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="update">
		<cfargument name="site_id" type="string" required="true">
		<cfargument name="branch" type="string" required="true">
		<cfargument name="commit" type="string" default="">

		<cfoutput>
		<cfset local.site = this.sites[arguments.site_id]>

		<cfsavecontent variable="local.commands">
			fetch origin #arguments.branch# --verbose
			checkout -f --track -B #arguments.branch# remotes/origin/#arguments.branch#
			<cfif arguments.commit neq "">
				fetch origin tag #arguments.commit# --verbose
				reset --hard #arguments.commit#
			</cfif>
			show -s
			status --branch --untracked-files=all --verbose
		</cfsavecontent>

		<cfloop array="#site.servers#" index="config">
			<div class="server" style="font-weight: bold">#config[1]# #config[2]#</div>
			<cfloop list="#commands#" delimiters="#chr(10)#" index="command">
				<cfset command = trim(command)><cfif command eq ""><cfcontinue></cfif>
				<div class="command">#command#</div>
				<cfinvoke method="execute" server="#config[1]#" directory="#config[2]#" command="#command#" returnvariable="local.result">
				<cfif local.result[1] neq ""><pre class="output1">#local.result[1]#</pre></cfif>
				<cfif local.result[2] neq ""><pre class="output2">#local.result[2]#</pre></cfif>
			</cfloop>
		</cfloop>
		</cfoutput>

	</cffunction>

	<cffunction name="execute" access="remote" returnformat="JSON">
		<cfargument name="server" type="string" required="true">
		<cfargument name="directory" type="string" required="true">
		<cfargument name="command" type="string" required="true">

		<cfif this.server_ip eq arguments.server or cgi.http_host eq arguments.server>
			<cfexecute name = "C:\Windows\System32\cmd.exe"
			    arguments = '/C cd "#arguments.directory#" && "c:\Program Files\Git\cmd\git.exe" #arguments.command#'
			    timeout = "600" variable="message" errorVariable="error_message">
			</cfexecute>
			<cfreturn [message, error_message]>
		</cfif>

		<cfhttp method="post" url="http://#server#/#this.script_location#?method=execute" timeout="700" result="local.result" username="#this.credentials.username#" password="#this.credentials.password#">
			<cfhttpparam type="formfield" name="server" value="#arguments.server#">
			<cfhttpparam type="formfield" name="directory" value="#arguments.directory#">
			<cfhttpparam type="formfield" name="command" value="#arguments.command#">
		</cfhttp>

		<cfif not isJSON(local.result.Filecontent)>
			<cfdump var="#local.result#"><cfabort>
			<cfthrow message="Execute error.">
		</cfif>

		<cfreturn deserializeJSON(local.result.Filecontent)>
	</cffunction>


	<!--- code below is from http://www.bennadel.com/blog/1574-ask-ben-manually-enforcing-basic-http-authorization-in-coldfusion.htm --->
	<cffunction
		name="CheckAuthentication"
		access="public"
		returntype="void"
		output="false"
		hint="I check to see if the request is authenticated. If not, then I return a 401 Unauthorized header and abort the page request.">

		<!---
			Check to see if user is authorized. If NOT, then
			return a 401 header and abort the page request.
		--->
		<cfif NOT THIS.CheckAuthorization()>

			<!--- Set status code. --->
			<cfheader
				statuscode="401"
				statustext="Unauthorized"
				/>

			<!--- Set authorization header. --->
			<cfheader
				name="WWW-Authenticate"
				value="basic realm=""API"""
				/>

			<!--- Stop the page from loading. --->
			<cfabort />

		</cfif>

		<!--- Return out. --->
		<cfreturn />
	</cffunction>


	<cffunction
		name="CheckAuthorization"
		access="public"
		returntype="boolean"
		output="false"
		hint="I check to see if the given request credentials match the required credentials.">

		<!--- Define the local scope. --->
		<cfset var LOCAL = {} />

		<!---
			Wrap this whole thing in a try/catch. If any of it
			goes wrong, then the credentials were either non-
			existent or were not in the proper format.
		--->
		<cftry>

			<!---
				Get the authorization key out of the header. It
				will be in the form of:

				Basic XXXXXXXX

				... where XXXX is a base64 encoded value of the
				users credentials in the form of:

				username:password
			--->
			<cfset LOCAL.EncodedCredentials = ListLast(
				GetHTTPRequestData().Headers.Authorization,
				" "
				) />

			<!---
				Convert the encoded credentials from base64 to
				binary and back to string.
			--->
			<cfset LOCAL.Credentials = ToString(
				ToBinary( LOCAL.EncodedCredentials )
				) />

			<!--- Break up the credentials. --->
			<cfset LOCAL.Username = ListFirst( LOCAL.Credentials, ":" ) />
			<cfset LOCAL.Password = ListLast( LOCAL.Credentials, ":" ) />

			<!---
				Check the users request credentials against the
				known ones on file.
			--->
			<cfif (
				(LOCAL.Username EQ THIS.Credentials.Username) AND
				(LOCAL.Password EQ THIS.Credentials.Password)
				)>

				<!--- The user credentials are correct. --->
				<cfreturn true />

			<cfelse>

				<!--- The user credentials are not correct. --->
				<cfreturn false />

			</cfif>


			<!--- Catch any errors. --->
			<cfcatch>

				<!---
					Something went wrong somewhere with the
					credentials, so we have to assume user is
					not authorized.
				--->
				<cfreturn false />

			</cfcatch>

		</cftry>
	</cffunction>

</cfcomponent>