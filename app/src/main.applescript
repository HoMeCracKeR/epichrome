(*
 * 
 *  main.applescript: An AppleScript GUI for creating Epichrome apps.
 *  Copyright (C) 2018  David Marmor
 *
 *  https://github.com/dmarmor/epichrome
 *
 *  Full license at: http://www.gnu.org/licenses/ (V3,6/29/2007)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *)


-- PLACEHOLDER FOR LATER UPDATE FUNCTIONALITY
-- on open these_items
--   display dialog "Update functionality goes here. " & these_items
-- end open

-- MISC CONSTANTS
set ssbPrompt to "Select name and location for the app."
set ssbDefaultURL to "https://www.google.com/mail/"
set iconPrompt to "Select an image to use as an icon."
set iconTypes to {"public.jpeg", "public.png", "public.tiff", "com.apple.icns"}


-- GET MY ICON FOR DIALOG BOXES
set myIcon to path to resource "applet.icns"

-- GET PATHS TO USEFUL RESOURCES IN THIS APP
set chromeSSBScript to quoted form of (POSIX path of (path to resource "build.sh" in directory "Scripts"))
set pathInfoScript to quoted form of (POSIX path of (path to resource "pathinfo.sh" in directory "Scripts"))
set updateCheckScript to quoted form of (POSIX path of (path to resource "updatecheck.sh" in directory "Scripts"))
set versionScript to quoted form of (POSIX path of (path to resource "version.sh" in directory "Scripts"))

-- PERSISTENT PROPERTIES
property lastIconPath : ""
property lastSSBPath : ""
property doRegisterBrowser : "No"
property doCustomIcon : "Yes"
property updateCheckDate : (current date) - (1 * days)
property updateCheckVersion : false

-- NUMBER OF STEPS IN THE PROCESS
property numSteps : 7
global curStep
set curStep to 1
on step()
	return "Step " & curStep & " of " & numSteps
end step

-- HAVE WE AUTHENTICATED?
set isAuthenticated to false

-- BUILD REPRESENTATION OF BROWSER TABS
on tablist(tabs, tabnum)
	local ttext
	if (count of tabs) is 0 then
		return "No tabs specified.

Click \"Add\" to add a tab. If you click \"Done (Don't Add)\" now, the app will determine which tabs to open on startup using its preferences, just as Chrome would."
	else
		local t
		set ttext to (count of tabs) as text
		if ttext is "1" then
			set ttext to ttext & " tab"
		else
			set ttext to ttext & " tabs"
		end if
		set ttext to ttext & " specified:
"
		
		-- add tabs themselves to the text
		local ti
		set ti to 1
		repeat with t in tabs
			if ti is tabnum then
				set ttext to ttext & "
  *  [the tab you are editing]"
			else
				set ttext to ttext & "
  -  " & t
			end if
			set ti to ti + 1
		end repeat
		if ti is tabnum then
			set ttext to ttext & "
  *  [new tab will be added here]"
		end if
		return ttext
	end if
end tablist


-- INITIALIZE IMPORTANT VARIABLES
set ssbBase to "My Epichrome App"
set ssbURLs to {}


-- CHECK FOR UPDATES TO EPICHROME

set curDate to current date
if updateCheckDate < curDate then
	-- set next update for 1 week from now
	set updateCheckDate to (curDate + (7 * days))
	
	-- if updateCheckVersion isn't set, set it to the current version of Epichrome
	if updateCheckVersion is false then
		set updateCheckVersion to do shell script "source " & versionScript & " ; echo $mcssbVersion"
	end if
	
	-- run the actual update check script
	try
		set updateCheckResult to do shell script updateCheckScript & " " & (quoted form of updateCheckVersion)
	on error errStr number errNum
		set updateCheckResult to false
		display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
	end try
	
	-- parse update check results
	if updateCheckResult is not false then
		if updateCheckResult is not "" then
			set newVersion to paragraph 1 of updateCheckResult
			set updateURL to paragraph 2 of updateCheckResult
			try
				set dlgResult to button returned of (display dialog "A new version of Epichrome (" & newVersion & ") is available on GitHub." with title "Update Available" buttons {"Download", "Later", "Ignore This Version"} default button "Download" cancel button "Later" with icon myIcon)
			on error number -128
				-- Later: do nothing
				set dlgResult to false
			end try
			
			-- Download or Ignore
			if dlgResult is "Download" then
				open location updateURL
			else if dlgResult is "Ignore This Version" then
				set updateCheckVersion to newVersion
			end if
		end if
	end if
end if


-- BUILD THE APP

repeat
	-- FIRST STEP: SELECT APPLICATION NAME & LOCATION
	repeat
		try
			display dialog "Click OK to select a name and location for the app." with title step() with icon myIcon buttons {"OK", "Quit"} default button "OK" cancel button "Quit"
			exit repeat
		on error number -128
			try
				display dialog "The app has not been created. Are you sure you want to quit?" with title "Confirm" with icon myIcon buttons {"No", "Yes"} default button "Yes" cancel button "No"
				return
			on error number -128
			end try
		end try
	end repeat
	
	
	-- APPLICATION FILE SAVE DIALOGUE
	repeat
		-- CHOOSE WHERE TO SAVE THE SSB
		
		set ssbPath to false
		set tryAgain to true
		
		repeat while tryAgain
			set tryAgain to false -- assume we'll succeed
			
			-- show file selection dialog
			try
				set lastSSBPath to (lastSSBPath as alias)
			on error
				set lastSSBPath to false
			end try
			try
				if lastSSBPath is not false then
					set ssbPath to (choose file name with prompt ssbPrompt default name ssbBase default location lastSSBPath) as text
				else
					set ssbPath to (choose file name with prompt ssbPrompt default name ssbBase) as text
				end if
			on error number -128
				exit repeat
			end try
			
			-- break down the path & canonicalize app name
			try
				set ssbInfo to do shell script pathInfoScript & " app " & quoted form of (POSIX path of ssbPath)
			on error errStr number errNum
				display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
				return
			end try
			
			set ssbDir to (paragraph 1 of ssbInfo)
			set ssbBase to (paragraph 2 of ssbInfo)
			set ssbShortName to (paragraph 3 of ssbInfo)
			set ssbName to (paragraph 4 of ssbInfo)
			set ssbPath to (paragraph 5 of ssbInfo)
			set ssbExtAdded to (paragraph 6 of ssbInfo)
			
			-- update the last path info
			set lastSSBPath to (((POSIX file ssbDir) as alias) as text)
			
			-- if no ".app" extension was given, check if they accidentally chose an existing app without confirming
			if ssbExtAdded is "TRUE" then
				-- see if an app with the given base name exists
				tell application "Finder"
					set appExists to false
					try
						if exists ((POSIX file ssbPath) as alias) then set appExists to true
					end try
				end tell
				if appExists then
					try
						display dialog "A file or folder named �" & ssbName & "� already exists. Do you want to replace it?" with icon caution buttons {"Cancel", "Replace"} default button "Cancel" cancel button "Cancel" with title "File Exists"
					on error number -128
						set tryAgain to true
					end try
				end if
			end if
		end repeat
		
		if ssbPath is false then
			exit repeat
		end if
		
		set curStep to curStep + 1
		
		repeat
			
			-- NEXT STEP: SHORT APP NAME
			
			set ssbShortNamePrompt to "Enter the app name that should appear in the menu bar (16 characters or less)."
			
			set tryAgain to true
			
			repeat while tryAgain
				set tryAgain to false
				set ssbShortNameCanceled to false
				set ssbShortNamePrev to ssbShortName
				try
					set ssbShortName to text returned of (display dialog ssbShortNamePrompt with title step() with icon myIcon default answer ssbShortName buttons {"OK", "Back"} default button "OK" cancel button "Back")
				on error number -128 -- Back button
					set ssbShortNameCanceled to true
					set curStep to curStep - 1
					exit repeat
				end try
				
				if (count of ssbShortName) > 16 then
					set tryAgain to true
					set ssbShortNamePrompt to "That name is too long. Please limit the name to 16 characters or less."
					set ssbShortName to ((characters 1 thru 16 of ssbShortName) as text)
				else if (count of ssbShortName) < 1 then
					set tryAgain to true
					set ssbShortNamePrompt to "No name entered. Please try again."
					set ssbShortName to ssbShortNamePrev
				end if
			end repeat
			
			if ssbShortNameCanceled then
				exit repeat
			end if
			
			-- NEXT STEP: CHOOSE SSB STYLE
			set curStep to curStep + 1
			
			repeat
				try
					set ssbStyle to button returned of (display dialog "Choose App Style:

APP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)

BROWSER TABS - The app will display a full browser window with the given tabs." with title step() with icon myIcon buttons {"App Window", "Browser Tabs", "Back"} default button "App Window" cancel button "Back")
					
				on error number -128 -- Back button
					set curStep to curStep - 1
					exit repeat
				end try
				
				-- NEXT STEP: CHOOSE URLS
				set curStep to curStep + 1
				
				-- initialize URL list
				if (ssbURLs is {}) and (ssbStyle is "App Window") then
					set ssbURLs to {ssbDefaultURL}
				end if
				
				repeat
					if ssbStyle is "App Window" then
						-- APP WINDOW STYLE
						try
							set (item 1 of ssbURLs) to text returned of (display dialog "Choose URL:" with title step() with icon myIcon default answer (item 1 of ssbURLs) buttons {"OK", "Back"} default button "OK" cancel button "Back")
						on error number -128 -- Back button
							set curStep to curStep - 1
							exit repeat
						end try
					else
						-- BROWSER TABS
						set curTab to 1
						repeat
							if curTab > (count of ssbURLs) then
								try
									set dlgResult to display dialog tablist(ssbURLs, curTab) with title step() with icon myIcon default answer ssbDefaultURL buttons {"Add", "Done (Don't Add)", "Back"} default button "Add" cancel button "Back"
								on error number -128 -- Back button
									set dlgResult to "Back"
								end try
								
								if dlgResult is "Back" then
									if curTab is 1 then
										set curTab to 0
										exit repeat
									else
										set curTab to curTab - 1
									end if
								else if (button returned of dlgResult) is "Add" then
									-- add the current text to the end of the list of URLs
									set (end of ssbURLs) to text returned of dlgResult
									set curTab to curTab + 1
								else -- "Done (Don't Add)"
									-- we're done, don't add the current text to the list
									exit repeat
								end if
							else
								set backButton to 0
								if curTab is 1 then
									try
										set dlgResult to display dialog tablist(ssbURLs, curTab) with title step() with icon myIcon default answer (item curTab of ssbURLs) buttons {"Next", "Remove", "Back"} default button "Next" cancel button "Back"
									on error number -128
										set backButton to 1
									end try
								else
									set dlgResult to display dialog tablist(ssbURLs, curTab) with title step() with icon myIcon default answer (item curTab of ssbURLs) buttons {"Next", "Remove", "Previous"} default button "Next"
								end if
								
								if (backButton is 1) or ((button returned of dlgResult) is "Previous") then
									if backButton is 1 then
										set curTab to 0
										exit repeat
									else
										set (item curTab of ssbURLs) to text returned of dlgResult
										set curTab to curTab - 1
									end if
								else if (button returned of dlgResult) is "Next" then
									set (item curTab of ssbURLs) to text returned of dlgResult
									set curTab to curTab + 1
								else -- "Remove"
									if curTab is 1 then
										set ssbURLs to rest of ssbURLs
									else if curTab is (count of ssbURLs) then
										set ssbURLs to (items 1 thru -2 of ssbURLs)
										set curTab to curTab - 1
									else
										set ssbURLs to ((items 1 thru (curTab - 1) of ssbURLs)) & ((items (curTab + 1) thru -1 of ssbURLs))
									end if
								end if
							end if
						end repeat
						
						if curTab is 0 then
							-- we hit the back button
							set curStep to curStep - 1
							exit repeat
						end if
					end if
					
					-- NEXT STEP: REGISTER AS BROWSER?
					set curStep to curStep + 1
					
					repeat
						try
							set doRegisterBrowser to button returned of (display dialog "Register app as a browser?" with title step() with icon myIcon buttons {"No", "Yes", "Back"} default button doRegisterBrowser cancel button "Back")
						on error number -128 -- Back button
							set curStep to curStep - 1
							exit repeat
						end try
						
						-- NEXT STEP: SELECT ICON FILE
						set curStep to curStep + 1
						
						repeat
							try
								set doCustomIcon to button returned of (display dialog "Do you want to provide a custom icon?" with title step() with icon myIcon buttons {"Yes", "No", "Back"} default button doCustomIcon cancel button "Back")
							on error number -128 -- Back button
								set curStep to curStep - 1
								exit repeat
							end try
							
							repeat
								if doCustomIcon is "Yes" then
									
									-- CHOOSE AN APP ICON
									
									-- show file selection dialog
									try
										set lastIconPath to (lastIconPath as alias)
									on error
										set lastIconPath to false
									end try
									try
										if lastIconPath is not false then
											
											set ssbIconSrc to choose file with prompt iconPrompt of type iconTypes default location lastIconPath without invisibles
										else
											set ssbIconSrc to choose file with prompt iconPrompt of type iconTypes without invisibles
										end if
										
									on error number -128
										exit repeat
									end try
									
									-- get icon path info
									set ssbIconSrc to (POSIX path of ssbIconSrc)
									-- break down the path & canonicalize icon name
									try
										set ssbInfo to do shell script pathInfoScript & " icon " & quoted form of ssbIconSrc
									on error errStr number errNum
										display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
										return
									end try
									
									set lastIconPath to (((POSIX file (paragraph 1 of ssbInfo)) as alias) as text)
									set ssbIconName to (paragraph 2 of ssbInfo)
									
								else
									set ssbIconSrc to ""
								end if
								
								-- NEXT STEP: CREATE APPLICATION
								set curStep to curStep + 1
								
								-- create summary of the app
								set ssbSummary to "Ready to create!

App: " & ssbName & "

Menubar Name: " & ssbShortName & "

Path: " & ssbDir & "

"
								if ssbStyle is "App Window" then
									set ssbSummary to ssbSummary & "Style: App Window

URL: " & (item 1 of ssbURLs)
								else
									set ssbSummary to ssbSummary & "Style: Browser Tabs

Tabs: "
									if (count of ssbURLs) is 0 then
										set ssbSummary to ssbSummary & "<none>"
									else
										repeat with t in ssbURLs
											set ssbSummary to ssbSummary & "
  -  " & t
										end repeat
									end if
								end if
								set ssbSummary to ssbSummary & "
								
Register as Browser: " & doRegisterBrowser & "

Icon: "
								if ssbIconSrc is "" then
									set ssbSummary to ssbSummary & "<default>"
								else
									set ssbSummary to ssbSummary & ssbIconName
								end if
								
								-- set up Chrome command line
								set ssbCmdLine to ""
								if ssbStyle is "App Window" then
									set ssbCmdLine to quoted form of ("--app=" & (item 1 of ssbURLs))
								else if (count of ssbURLs) > 0 then
									repeat with t in ssbURLs
										set ssbCmdLine to ssbCmdLine & " " & quoted form of t
									end repeat
								end if
								
								repeat
									try
										display dialog ssbSummary with title step() with icon myIcon buttons {"Create", "Back"} default button "Create" cancel button "Back"
									on error number -128 -- Back button
										set curStep to curStep - 1
										exit repeat
									end try
									
									
									-- CREATE THE SSB
									
									repeat
										set creationSuccess to false
										try
											do shell script chromeSSBScript & " " & �
												(quoted form of ssbPath) & " " & �
												(quoted form of ssbBase) & " " & �
												(quoted form of ssbShortName) & " " & �
												(quoted form of ssbIconSrc) & " " & �
												(quoted form of doRegisterBrowser) & " " & �
												ssbCmdLine
											set creationSuccess to true
										on error errStr number errNum
											
											-- if we couldn't create the app, try with admin privileges
											if errStr is "PERMISSION" then
												try
													if not isAuthenticated then
														display dialog "Creating an app in \"" & ssbDir & "\" requires an administrator name and password." with icon myIcon buttons {"Authenticate", "Cancel"} default button "Cancel" cancel button "Cancel" with title "Authentication Required"
														set isAuthenticated to true
													end if
													
													try
														do shell script chromeSSBScript & " " & �
															(quoted form of ssbPath) & " " & �
															(quoted form of ssbBase) & " " & �
															(quoted form of ssbShortName) & " " & �
															(quoted form of ssbIconSrc) & " " & �
															(quoted form of doRegisterBrowser) & " " & �
															ssbCmdLine with administrator privileges
														set creationSuccess to true
													on error errStr number errNum
														if errNum is -128 then
															exit repeat
														else if errStr is "PERMISSION" then
															set errStr to "Permission denied."
														end if
													end try
												on error number -128 -- authentication Cancel button
													exit repeat
												end try
												
											end if
											
											if not creationSuccess then
												try
													display dialog "Creation failed: " & errStr with icon stop buttons {"Quit", "Back"} default button "Quit" cancel button "Back" with title "Application Not Created"
													return -- Quit button
												on error number -128 -- Back button
													exit repeat
												end try
											end if
										end try
										
										-- SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH
										try
											set dlgResult to button returned of (display dialog "Created Epichrome app \"" & ssbBase & "\".

IMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched.

HOWEVER, it will almost certainly be installed DISABLED. You'll need to go to the Window menu, choose Extensions and enable it manually. Once successfully enabled, its options page will open and display a welcome message." with title "Success!" buttons {"Launch Now", "Reveal in Finder", "Quit"} default button "Launch Now" cancel button "Quit" with icon myIcon)
										on error number -128
											return -- "Quit" button
										end try
										
										-- launch or reveal
										if dlgResult is "Launch Now" then
											delay 1
											try
												do shell script "open " & quoted form of (POSIX path of ssbPath)
												--tell application ssbName to activate
											on error
												return
											end try
										else
											--if (button returned of dlgResult) is "Reveal in Finder" then
											tell application "Finder" to reveal ((POSIX file ssbPath) as alias)
											tell application "Finder" to activate
										end if
										
										return -- We're done!
										
									end repeat
									
								end repeat
								
								exit repeat -- We always kick back to the question of whether to use a custom icon
							end repeat
							
						end repeat
						
					end repeat
					
				end repeat
				
			end repeat
			
		end repeat
		
		exit repeat -- always kick back to the first dialogue (instead of the file save dialog)
		
	end repeat
	
end repeat
