#!/bin/bash
# Author by Wibowo Leksono

# Notes:	This script is based on scripts provided by user Pico (https://github.com/PicoMitchell) on the Mac Admins Slack channel. 
# Notes:	This script is based on scripts provided by user Itjimbo (https://github.com/itjimbo). 


#Variables
# Insert desired macOS minimum version for script to run. example is 14 for macOS 14 Sonoma and later.
desiredmacOSVersion=14

# This is the base64 value of the Photo Screen Saver (iLifeSlideshows.appex) in MacOS 14 Sonoma.
screenSaverBase64='YnBsaXN0MDDRAQJWbW9kdWxl0QMEWHJlbGF0aXZlXxBEZmlsZTovLy9TeXN0ZW0vTGlicmFyeS9FeHRlbnNpb25LaXQvRXh0ZW5zaW9ucy9pTGlmZVNsaWRlc2hvd3MuYXBwZXgICxIVHgAAAAAAAAEBAAAAAAAAAAUAAAAAAAAAAAAAAAAAAABl'

#Set local path of slideshow images 
photoloc="/Users/Shared/SSaver" 

#Main
scr_path="/System/Library/ExtensionKit/Extensions/iLifeSlideshows.appex" #OSX14+

# Function to apply screensaver settings
apply_screensaver_settings() {
    local Cuser=$1
    sudo -u "$Cuser" defaults -currentHost write com.apple.ScreenSaverPhotoChooser CustomFolderDict -dict identifier "$photoloc" name "SSSaver"
    sudo -u "$Cuser" defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedFolderPath "$photoloc"
    sudo -u "$Cuser" defaults -currentHost write com.apple.ScreenSaverPhotoChooser SelectedSource -int 4
    sudo -u "$Cuser" defaults -currentHost write com.apple.ScreenSaverPhotoChooser ShufflesPhotos -bool false
    sudo -u "$Cuser" defaults -currentHost write com.apple.ScreenSaver.iLifeSlideShows styleKey -string "Classic"
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver CleanExit -bool true
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver idleTime -int 300
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver showClock -bool true
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver tokenRemovalAction -int 0
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver moduleDict -dict-add moduleName "iLifeSlideshows"
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver moduleDict -dict-add path "$scr_path"
    sudo -u "$Cuser" defaults -currentHost write com.apple.screensaver moduleDict -dict-add type -int 0
}

do_we_need_to_run(){
	local Cuser=$1
	if (!(test -d $photoloc)); then
		echo "Package not installed yet. Skipping."
		exit 0
	fi
	
	local selectedFolder="`sudo -u $Cuser defaults -currentHost read com.apple.ScreenSaverPhotoChooser SelectedFolderPath`"

	if [[ "{$selectedFolder}" == "{$photoloc}" ]]; then
		echo "Already configured. No need to run."
		exit 0
	fi
}

current_user=$(stat -f "%Su" /dev/console)

do_we_need_to_run "$current_user"

# Remove old SS config
sudo -u "$current_user" defaults -currentHost delete com.apple.ScreenSaverPhotoChooser > /dev/null 2>&1
sudo -u "$current_user" defaults -currentHost delete com.apple.ScreenSaver.iLifeSlideShows > /dev/null 2>&1

function getStarterVariables() {
	# Do not edit these variables.
	echo "$(date) - Script will only run on macOS version ${desiredmacOSVersion} or later (macOS ${desiredmacOSVersion} - Present)."
	currentRFC3339UTCDate="$(date -u '+%FT%TZ')"
	echo "$(date) - currentRFC3339UTCDate: ${currentRFC3339UTCDate}"
	loggedInUser=$(/usr/bin/stat -f%Su /dev/console)
	echo "$(date) - Logged in user: ${loggedInUser}"
	macOSFullProductVersion=$(sw_vers -productVersion)
	echo "$(date) - macOS Full Product Version: ${macOSFullProductVersion}"
	macOSMainProductVersion="${macOSFullProductVersion:0:2}"
	echo "$(date) - macOS Main Product Version: ${macOSMainProductVersion}"
	wallpaperStoreDirectory="/Users/${loggedInUser}/Library/Application Support/com.apple.wallpaper/Store"
	echo "$(date) - wallpaperStoreDirectory: ${wallpaperStoreDirectory}"
	wallpaperStoreFile="Index.plist"
	echo "$(date) - wallpaperStoreFile: ${wallpaperStoreFile}"
	wallpaperStoreFullPath="${wallpaperStoreDirectory}/${wallpaperStoreFile}"
	echo "$(date) - wallpaperStoreFullPath: ${wallpaperStoreFullPath}"
	wallpaperBase64=$(plutil -extract AllSpacesAndDisplays xml1 -o - "${wallpaperStoreFullPath}" | awk '/<data>/,/<\/data>/' | xargs | tr -d " " | tr "<" "\n" | head -2 | tail -1 | cut -c6-)
	wallpaperLocation=$(plutil -extract AllSpacesAndDisplays xml1 -o - "${wallpaperStoreFullPath}" | grep -A 2 "relative" | head -2 | tail -1 | xargs | cut -c9- | rev | cut -c10- | rev)
	echo "$(date) - wallpaperLocation: ${wallpaperLocation}"
	wallpaperProvider=$(plutil -extract AllSpacesAndDisplays xml1 -o - "${wallpaperStoreFullPath}" | grep -A 2 "Provider" | head -2 | tail -1 | xargs | cut -c9- | rev | cut -c10- | rev)
	echo "$(date) - wallpaperProvider: ${wallpaperProvider}"
	checkmacOSVersion
}

function checkmacOSVersion() {
	echo "$(date) - Checking macOS version..."
    if [[ "${macOSMainProductVersion}" == "" ]]; then
        echo "$(date) - Could not determine macOSMainProductVersion variable."
        exitCode='1'
		finalize
    elif [[ "${macOSMainProductVersion}" -ge "${desiredmacOSVersion}" ]]; then
        checkUser
    else
        echo "$(date) - macOS is on version $macOSFullProductVersion; do not run."
        exitCode='0'
		finalize
    fi
}

function checkUser() {
	echo "$(date) - Checking valid user..."
	if [[ "${loggedInUser}" == "root" ]]; then
		echo "$(date) - Script should not be run as root user."
		exitCode='1'
		finalize
	elif [[ "${loggedInUser}" == "" ]]; then
		echo "$(date) - User cannot be defined."
		exitCode='1'
		finalize
	else
		setScreenSaverSettings
	fi
}

function setScreenSaverSettings() {
	echo "$(date) - Setting screen saver settings..."
	if [[ "${wallpaperLocation}" == "" ]]; then
		# Index.plist contents.
		aerialDesktopAndScreenSaverSettingsPlist="$(plutil -create xml1 - |
			plutil -insert 'Desktop' -dictionary -o - - |
			plutil -insert 'Desktop.Content' -dictionary -o - - |
			plutil -insert 'Desktop.Content.Choices' -array -o - - |
			plutil -insert 'Desktop.Content.Choices' -dictionary -append -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Configuration' -data "${wallpaperBase64}" -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Files' -array -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Provider' -string "${wallpaperProvider}" -o - - |
			plutil -insert 'Desktop.Content.Shuffle' -string '$null' -o - - |
			plutil -insert 'Desktop.LastSet' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Desktop.LastUse' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Idle' -dictionary -o - - |
			plutil -insert 'Idle.Content' -dictionary -o - - |
			plutil -insert 'Idle.Content.Choices' -array -o - - |
			plutil -insert 'Idle.Content.Choices' -dictionary -append -o - - |
			plutil -insert 'Idle.Content.Choices.0.Configuration' -data "${screenSaverBase64}" -o - - |
			plutil -insert 'Idle.Content.Choices.0.Files' -array -o - - |
			plutil -insert 'Idle.Content.Choices.0.Provider' -string 'com.apple.wallpaper.choice.screen-saver' -o - - |
			plutil -insert 'Idle.Content.Shuffle' -string '$null' -o - - |
			plutil -insert 'Idle.LastSet' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Idle.LastUse' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Type' -string 'individual' -o - -)"
	else
		# Index.plist contents.
		aerialDesktopAndScreenSaverSettingsPlist="$(plutil -create xml1 - |
			plutil -insert 'Desktop' -dictionary -o - - |
			plutil -insert 'Desktop.Content' -dictionary -o - - |
			plutil -insert 'Desktop.Content.Choices' -array -o - - |
			plutil -insert 'Desktop.Content.Choices' -dictionary -append -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Configuration' -data "${wallpaperBase64}" -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Files' -array -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Files' -dictionary -append -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Files.0.relative' -string "${wallpaperLocation}" -o - - |
			plutil -insert 'Desktop.Content.Choices.0.Provider' -string "${wallpaperProvider}" -o - - |
			plutil -insert 'Desktop.Content.Shuffle' -string '$null' -o - - |
			plutil -insert 'Desktop.LastSet' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Desktop.LastUse' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Idle' -dictionary -o - - |
			plutil -insert 'Idle.Content' -dictionary -o - - |
			plutil -insert 'Idle.Content.Choices' -array -o - - |
			plutil -insert 'Idle.Content.Choices' -dictionary -append -o - - |
			plutil -insert 'Idle.Content.Choices.0.Configuration' -data "${screenSaverBase64}" -o - - |
			plutil -insert 'Idle.Content.Choices.0.Files' -array -o - - |
			plutil -insert 'Idle.Content.Choices.0.Provider' -string 'com.apple.wallpaper.choice.screen-saver' -o - - |
			plutil -insert 'Idle.Content.Shuffle' -string '$null' -o - - |
			plutil -insert 'Idle.LastSet' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Idle.LastUse' -date "${currentRFC3339UTCDate}" -o - - |
			plutil -insert 'Type' -string 'individual' -o - -)"
	fi
	makeScreenSaverDirectory
}

function makeScreenSaverDirectory() {
	# Create the path to the screen saver/wallpaper Index.plist.
	echo "$(date) - Creating screen saver directory..."
	mkdir -p "${wallpaperStoreDirectory}"
	createIndexPlist
}

function createIndexPlist() {
	# Create the Index.plist
	echo "$(date) - Creating screen saver Index.plist..."
	plutil -create binary1 - |
		plutil -insert 'AllSpacesAndDisplays' -xml "${aerialDesktopAndScreenSaverSettingsPlist}" -o - - |
		plutil -insert 'Displays' -dictionary -o - - |
		plutil -insert 'Spaces' -dictionary -o - - |
		plutil -insert 'SystemDefault' -xml "${aerialDesktopAndScreenSaverSettingsPlist}" -o "${wallpaperStoreFullPath}" -
	killWallpaperAgent
}

function killWallpaperAgent() {
	# Kill the wallpaperAgent to refresh and apply the screen saver/wallpaper settings.
	echo "$(date) - Restarting wallpaper agent..."
	killall WallpaperAgent
	exitCode='0'
	finalize
}

function finalize() {
    echo ""
    if [[ "${exitCode}" == "0" ]]; then
        echo "$(date) - Preference Updated!"
    else
        echo "$(date) - Preference Failed!"
        exit 1
    fi    
}

killall "System Settings"

echo ""
getStarterVariables

# Apply new SS config
apply_screensaver_settings "$current_user"

# Refresh preferences daemon
killall -hup cfprefsd
Echo "ScreenSaver succesfully updated"

exit 0
