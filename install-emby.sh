#!/bin/bash
#===================================================================#
# Simple Emby Server Installer - by dougiefresh                     #
#===================================================================#
# DISCLAIMER: This is a script by dougiefresh to install Emby       #
# Server to OSMC.  I am not responsible for any harm done to        #
# your system.  Using this script is done at your own risk.         #
#===================================================================#
VERSION=0.8
EMBY_HOME=/opt/mediabrowser
EMBY_NEW=/opt/mediabrowser.new
EMBY_OLD=/opt/mediabrowser.old
PID_FILE=$EMBY_HOME/mediabrowser.pid
MONO_DIR=/usr/bin
URL_SCRIPT=https://raw.githubusercontent.com/KiLMaN/osmc_install_emby/master/install-emby.sh


# ==================================================================
# First function of script!  DO NOT CHANGE PLACEMENT!!
# ==================================================================
function update_script()
{
	# ==================================================================
	title "Upgrading Emby installation script..."
	# ==================================================================
	# retrieve the latest version of the script from GitHub:
	wget --no-check-certificate -w 4 -O $HOME_DIR/install-emby.sh.1 $URL_SCRIPT 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading latest version of Emby Server script" --gauge "\nPlease wait...\n"  11 70
	chmod +x $HOME_DIR/install-emby.sh.1
	mv $HOME_DIR/install-emby.sh.1 $HOME_DIR/install-emby.sh
	if [[ -f $EMBY_HOME/install-emby.sh ]]; then
		cp $HOME_DIR/install-emby.sh $EMBY_HOME/install-emby.sh
	fi

	# restart script
	exec $HOME_DIR/install-emby.sh
}

# ==================================================================
# Sub-Functions required by this script:
# ==================================================================
function title()
{
	echo -ne "\033]0;$1\007"
}

function fix_config()
{
	# ==================================================================
	title "Fixing Emby configuration files and environment"
	# ==================================================================
	# Determine where the files that we need:
	dpkg-query -f '${binary:Package}\n' -W > /tmp/packages.list
	sqlite=$(basename $(dpkg -L $(cat /tmp/packages.list | grep 'sqlite3') | grep '/arm-linux-gnueabihf/' | sort | grep -m 1 'sq'))
	media=$(basename $(dpkg -L $(cat /tmp/packages.list | grep 'mediainfo') | grep '/arm-linux-gnueabihf/' | sort | grep -m 1 'media'))
	magic=$(basename $(dpkg -L $(cat /tmp/packages.list | grep 'libmagickwand') | grep '/arm-linux-gnueabihf/' | sort | grep -m 1 '.so'))
	rm /tmp/packages.list

	# Here we fix the Emby configuration files:
	echo "<configuration>" > /tmp/ImageMagickSharp.dll.config
	echo "  <dllmap dll=\"CORE_RL_Wand_.dll\" target=\"$magic\" os=\"linux\"/>" >> /tmp/ImageMagickSharp.dll.config
	echo "</configuration>" >> /tmp/ImageMagickSharp.dll.config
	sudo mv /tmp/ImageMagickSharp.dll.config $EMBY_NEW/ImageMagickSharp.dll.config

	echo "<configuration>" > /tmp/System.Data.SQLite.dll.config
	echo "  <dllmap dll=\"sqlite3\" target=\"$sqlite\" os=\"linux\"/>" >> /tmp/System.Data.SQLite.dll.config
	echo "</configuration>" >> /tmp/System.Data.SQLite.dll.config
	sudo mv /tmp/System.Data.SQLite.dll.config $EMBY_NEW/System.Data.SQLite.dll.config

	echo "<configuration>" > /tmp/MediaBrowser.media.dll.config
	echo "  <dllmap dll=\"media\" target=\"$media\" os=\"linux\"/>" >> /tmp/MediaBrowser.media.dll.config
	echo "</configuration>" >> /tmp/MediaBrowser.media.dll.config
	sudo mv /tmp/MediaBrowser.media.dll.config $EMBY_NEW/MediaBrowser.media.dll.config
	
	# Timezone fix for Mono issue (found by Toast on OSMC discussion board)
	sudo sh -c "echo export TZ='\$(cat /etc/timezone)' >> /etc/profile"
}

function find_latest_stable()
{
	file=$(curl -s https://github.com/MediaBrowser/Emby/releases/latest | sed -n 's/.*href="\([^"]*\).*/\1/p')
	LATEST_VER=$(basename $file)
	file=$(curl -s $file | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "Emby.Mono.zip")
}

function find_latest_beta()
{
	list=$(curl -s https://github.com/MediaBrowser/Emby/releases | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep '/download/' | grep "Emby.Mono.zip")
	file=''
	for item in $list
	do
		if [[ $item > $file ]]; then
			file=$item
		fi
	done
	LATEST_VER=$(basename $(dirname $file))
}

# ==================================================================
# Functions performing major tasks in this script:
# ==================================================================
function make_choice()
{
	find_latest_stable
	VER_STABLE=$LATEST_VER
	find_latest_beta
	VER_BETA=$LATEST_VER
	version=$(test "$INSTALLED" == "" && echo "" || echo "Installed Version: $INSTALLED\n")
	cmd=(dialog --ascii-lines --cancel-label "Abort" --backtitle "Simple Emby Server Installer - Version $VERSION" --menu "${version}Select a branch of Emby Server:" 10 40 16)
	options=(
		1 "Stable Version: $VER_STABLE"
		2 "Beta Version  : $VER_BETA"
	)
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	if [[ "$choices" == "1" ]]; then
		BRANCH=stable
	elif [[ "$choices" == "2" ]]; then
		BRANCH=beta
	else
		exec $HOME_DIR/install-emby.sh
	fi
}

function install_prerequisites()
{
	# ==================================================================
	title "Installing prerequisites..."
	# ==================================================================
	sudo apt-get --show-progress -y --force-yes install unzip git build-essential dialog cron-app-osmc lsb-release 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Installing prerequisite programs if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function install_dependencies()
{
	# ==================================================================
	title "Installing Dependencies...."
	#=============================================================================================
	sudo apt-get --show-progress -y --force-yes install imagemagick imagemagick-6.q16 imagemagick-common libimage-magick-perl libimage-magick-q16-perl libmagickcore-6-arch-config libmagickcore-6-headers libmagickcore-6.q16-2 libmagickcore-6.q16-2-extra libmagickcore-6.q16-dev libmagickwand-6-headers libmagickwand-6.q16-2 libmagickwand-6.q16-dev libmagickwand-dev webp mediainfo sqlite3 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Installing dependencies if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function build_ffmpeg()
{
	#=============================================================================================
	title "Building and installing FFmpeg...."
	#=============================================================================================
	sudo apt-get --show-progress -y --force-yes remove ffmpeg 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Installing dependencies if they are not present" --gauge "\nPlease wait...\n" 11 70
	cd /usr/src
	if [[ -d /usr/src/ffmpeg ]]; then
		sudo rm -R /usr/src/ffmpeg
	fi
	sudo mkdir ffmpeg
	sudo chown `whoami`:users ffmpeg
	git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
	cd ffmpeg
	./configure
	make -j`nproc` && sudo make install
	cd ~
	sudo rm -R /usr/src/ffmpeg
}

function install_mono()
{
	# ==================================================================
	title "Installing Mono libraries..."
	# ==================================================================
	OS=$(lsb_release -si)
	Release=$(lsb_release -sr)
	#sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	echo "deb http://download.mono-project.com/repo/debian wheezy main" > /tmp/mono-xamarin.list
	if [ $OS == "Ubuntu" ]; then
		if [ $(lsb_release -sr) > 12.99999 ]; then
			echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main" >> /tmp/mono-xamarin.list
		else
			echo "deb http://download.mono-project.com/repo/debian wheezy-libtiff-compat main"  >> /tmp/mono-xamarin.list/etc/apt/sources.list.d/mono-xamarin.list
		fi
	elif [ $OS == "Debian" ]; then
		if [ $(lsb_release -sr) > 7.99999 ]; then
			echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main" >> /tmp/mono-xamarin.list
			echo "deb http://download.mono-project.com/repo/debian wheezy-libjpeg62-compat main" >> /tmp/mono-xamarin.list
		fi
	fi
	sudo mv /tmp/mono-xamarin.list /etc/apt/sources.list.d/mono-xamarin.list
	sudo apt-get update 2>&1 | dialog --ascii-lines --title "Updating package database..." --infobox "\nPlease wait...\n" 11 70
	sudo apt-get --show-progress -y --force-yes install mono-complete 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Installing Mono libraries if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function install_emby()
{
	# ==================================================================
	title "Getting latest version of Emby from GitHub..."
	# ==================================================================
	if [ "$BRANCH" == "beta" ]; then
		find_latest_beta
	else
		find_latest_stable
	fi
	wget --no-check-certificate -w 4 http://github.com$file -O /tmp/Emby.Mono.zip 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading Emby Server v$LATEST_VER" --gauge "\nPlease wait...\n"  11 70
	sudo unzip -o /tmp/Emby.Mono.zip -d $EMBY_NEW
	rm /tmp/Emby.Mono.zip
	BRANCH=$(sudo echo $BRANCH | sudo tee $EMBY_NEW/mediabrowser.branch)
	fix_config
}

function create_service()
{
	# ==================================================================
	title "Adding Emby Service..."
	# ==================================================================

	echo "#! /bin/bash" > /tmp/emby
	echo "### BEGIN INIT INFO" >> /tmp/emby
	echo "# Provides:          emby" >> /tmp/emby
	echo "# Required-Start:    \$local_fs \$network" >> /tmp/emby
	echo "# Required-Stop:     \$local_fs" >> /tmp/emby
	echo "# Default-Start:     2 3 4 5" >> /tmp/emby
	echo "# Default-Stop:      0 1 6" >> /tmp/emby
	echo "# Short-Description: emby" >> /tmp/emby
	echo "# Description:       Emby server" >> /tmp/emby
	echo "### END INIT INFO" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "PIDFILE=\"$PID_FILE\"" >> /tmp/emby
	echo "EXEC=\"$EMBY_HOME/MediaBrowser.Server.Mono.exe -ffmpeg /usr/local/share/man/man1/ffmpeg.1 -ffprobe /usr/local/share/man/man1/ffprobe.1\"" >> /tmp/emby
	echo "USER=root" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "if [[ -d $EMBY_NEW ]]; then" >> /tmp/emby
	echo "  sudo rm -R $EMBY_OLD" >> /tmp/emby
	echo "	sudo mv $EMBY_HOME $EMBY_OLD" >> /tmp/emby
	echo "	sudo mv $EMBY_NEW $EMBY_HOME" >> /tmp/emby
	echo "	sudo mv $EMBY_OLD/ProgramData-Server $EMBY_HOME/" >> /tmp/emby
	echo "fi" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "case \"\$1\" in" >> /tmp/emby
	echo "	start)" >> /tmp/emby
	echo "		echo \"Starting Emby server...\"" >> /tmp/emby
	echo "		sudo start-stop-daemon --chuid $USER -S -m -p \$PIDFILE -b -x $MONO_DIR/mono -- \${EXEC}" >> /tmp/emby
	echo "		;;" >> /tmp/emby
	echo "  stop)" >> /tmp/emby
	echo "		echo \"Stopping Emby server...\"" >> /tmp/emby
	echo "	  	sudo start-stop-daemon --chuid $USER -K -p \${PIDFILE} && sudo rm $PID_FILE" >> /tmp/emby
	echo "		;;" >> /tmp/emby
	echo "  restart|force_reload)" >> /tmp/emby
	echo "		echo \"Stopping Emby server...\"" >> /tmp/emby
	echo "		sudo start-stop-daemon --chuid $USER -K -p \${PIDFILE} && sudo rm $PID_FILE" >> /tmp/emby
	echo "		sleep 3" >> /tmp/emby
	echo "		echo \"Starting Emby server...\"" >> /tmp/emby
	echo "		sudo start-stop-daemon --chuid $USER -S -m -p \$PIDFILE -b -x $MONO_DIR/mono -- \${EXEC}" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "  *)" >> /tmp/emby
	echo "    echo \"Usage: /etc/init.d/emby {start|stop|restart|force_reload}\"" >> /tmp/emby
	echo "    exit 1" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "esac" >> /tmp/emby
	sudo echo "exit 0" >> /tmp/emby

	# Move the new service file into position and activate it:
	sudo rm /etc/init.d/emby
	sudo mv /tmp/emby /etc/init.d/emby
	sudo chmod 755 /etc/init.d/emby
	sudo update-rc.d emby defaults
	sudo /etc/init.d/emby start

	# Add cron task to remove "mediabrowser-server.pid" after reboot:
	crontab -l | { cat | grep -v "$PID_FILE"; echo "@reboot sudo rm $PID_FILE"; } | crontab -
}

function get_addon()
{
	# ==================================================================
	# Get the addon, unzip, then move the zip to the package store of OSMC
	# ==================================================================
    file=$(curl -s $1 | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "$2")
    wget --no-check-certificate -w 4 $1/$file -O /tmp/$file 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading Addon" --gauge "\nPlease wait...\n" 11 70
    unzip -o /tmp/$file -d $HOME_DIR/.kodi/addons
    mv /tmp/$file $HOME_DIR/.kodi/addons/packages/$file
}

function install_addons()
{
	# ==================================================================
	title "Installing Emby for Kodi repository and addons..."
	# ==================================================================
	# get the repository for Emby for Kodi:
	get_addon http://kodi.emby.media repository.emby.kodi

	# figure out where to pull the Kodi addons:
	dir='<datadir>http'$(cat $HOME_DIR/.kodi/addons/repository.emby.kodi/addon.xml | grep "</datadir>" | sed -n 's/.*http//p')
	dir=$(echo $dir | grep -oPm1 "(?<=<datadir>)[^<]+")

	# pull the rest of the addons from the Emby repository:
	get_addon $dir/plugin.video.emby/ plugin.video.emby
	get_addon $dir/plugin.video.emby.movies/ plugin.video.emby.movies
	get_addon $dir/plugin.video.emby.musicvideos/ plugin.video.emby.musicvideos
	get_addon $dir/plugin.video.emby.tvshows/ plugin.video.emby.tvshows
	
	# need to shutdown Kodi, then restart so that Kodi sees the new add-ons:
	sudo service mediacenter stop
	sleep 1
	sudo service mediacenter start
}

function done_installing()
{
	dialog --ascii-lines --title "FINISHED!" --msgbox "\nYour Emby Server should now be available for you at http://$(hostname -I):8096\nPress OK to return to the menu.\n" 11 70
	exec $HOME_DIR/install-emby.sh
}

function upgrade_emby()
{
	upgraded=0
	if [[ "$BRANCH" == "beta" ]]; then
		find_latest_beta
	else
		find_latest_stable
	fi
	if [[ $LATEST_VER > $INSTALLED ]]; then
		EMBY_HOME=$EMBY_NEW
		install_emby
		create_service
		#reboot
		upgraded=1
	fi
}

function toggle_cron_job()
{
	#=============================================================================================
	title "Toggling Cron Job status for OSMC..."
	#=============================================================================================
	if [[ $(crontab -l | grep "install-emby.sh") == "" ]]; then
		# put a copy of this script in Emby folder and create the cron job:
		sudo cp $HOME_DIR/install-emby.sh $EMBY_HOME/install-emby.sh
		crontab -l | { cat | grep -v "install-emby.sh"; echo "@daily $EMBY_HOME/install-emby.sh cron"; } | crontab -
		dialog --ascii-lines --title "Creating Cron Job for OSMC" --msgbox "\nThe Emby Server Update cron job has been created.\nThe job will run at midnight (12am) on Sunday each week.\nPress OK to return to the menu.\n" 11 70
	else
		# put a copy of this script in Emby folder and create the cron job
		sudo rm $EMBY_HOME/install-emby.sh
		crontab -l | { cat | grep -v "install-emby.sh"; } | crontab -
		dialog --ascii-lines --title "Removing Cron Job for OSMC" --msgbox "\nThe Emby Server Update cron job has been removed.\nPress OK to return to the menu.\n" 11 70
	fi	

	# restart script
	exec $HOME_DIR/install-emby.sh
}

# ==================================================================
# Functions that deal with moving Emby data to a USB stick:
# ==================================================================
function select_usbkey()
{
	#==============================================================================================
	# Code Source: http://unix.stackexchange.com/questions/60299/how-to-determine-which-sd-is-usb
	#==============================================================================================	
	# Figure out which USB stick we're going to use:
	#==============================================================================================
	USBKEYS=($(
		grep -Hv ^0$ /sys/block/*/removable |
		sed s/removable:.*$/device\\/uevent/ |
		xargs grep -H ^DRIVER=sd |
		sed s/device.uevent.*$/size/ |
		xargs grep -Hv ^0$ |
		cut -d / -f 4
	))
	case ${#USBKEYS[@]} in
		0) # No USB sticks found:
			dialog --ascii-lines --title "Simple Emby Server Installer" --msgbox "\nNo USB sticks were found.\nPress OK to return to the menu.\n" 8 40
			return
			;;
		1) # Use the only USB stick we found:
			STICK=$USBKEYS 
			;;
		*)	# Let user choose between the USB sticks we found:
			STICK=$(
				bash -c "$(
					echo -n  dialog --menu \"Choose which USB stick to copy to:\" 22 76 17;
					for dev in ${USBKEYS[@]} ;do
						echo -n \ $dev \"$(sed -e s/\ *$//g </sys/block/$dev/device/model)\" ;
					done
				)" 2>&1 >/dev/tty
			)
			;;
	esac
	[ "$STICK" ] || return

	# Figure out which partition on selected USB stick we're going to use:
	#==============================================================================================
	df --output=source,target /dev/$STICK* | grep "/dev/$STICK" > /tmp/partitions.txt
	case $(wc -l < /tmp/partitions.txt) in
		0) # No USB sticks found:
			dialog --ascii-lines --title "Simple Emby Server Installer" --msgbox "\nNo USB partitions were found.\nPress OK to return to the menu.\n" 8 40
			return
			;;
		1) # Use the only USB stick we found:
			STICK=$(cat /tmp/partitions.txt | cut -d" " -f1)
			;;

		*)	# Let user choose between the USB partitions we found:
			STICK=$(
				bash -c "$(
					echo -n  dialog --menu \"Choose which USB partition to copy to:\" 22 76 17;
					cat /tmp/partitions.txt
				)" 2>&1 >/dev/tty
			)
			;;
	esac
	rm /tmp/partitions.txt
	[ "$STICK" ] || return
}
#move_to_usbkey; exit;

# ==================================================================
# Function to retrieve & process file for ImagesByName project...
# ==================================================================
function get_imagesbyname()
{
	#=============================================================================================
	title "Retrieving file for ImagesByName project..."
	#=============================================================================================
	TMP=/opt/mediabrowser/ProgramData-Server/temp
	#sudo mkdir -p $TMP >& /dev/null
	#sudo wget --no-check-certificate -w 4 -O $TMP/IBN_People_Wave_1.7z https://dl.dropbox.com/s/ip3zvo3uxy5knp0/IBN_People_Wave_1.7z?dl=1 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading \"IBN_People_Wave_1.7z\"" --gauge "\nPlease wait...\n" 11 70
	#sudo 7za x -y -o$TMP $TMP/IBN_People_Wave_1.7z

	#=============================================================================================
	title "Resetting file permissions on metadata folder..."
	#=============================================================================================
	LINE=$(sudo ls -l /opt/mediabrowser/ProgramData-Server/ | grep 'metadata')
	sudo chown -R $(echo $LINE | cut -d' ' -f 4):$(echo $LINE | cut -d' ' -f 5) $TMP

	#=============================================================================================
	title "Move images of people around..."
	#=============================================================================================
	TMP=$TMP/People
	PPL=/opt/mediabrowser/ProgramData-Server/metadata/People
	TOTAL=$(sudo ls -1 $TMP | tee /tmp/filelist.txt | wc -l)
	COUNT=0
	cat /tmp/filelist.txt | (while read -r line
	do
		DST=$(echo $line | tr "'" " " | tr "  " " ")
		DST="${DST// mc/ mc }"
		DST="${DST//\./\.\ }"7
		DST="$(echo $DST | sed -e 's/^./\U&/g; s/ ./\U&/g')"
		DST="${DST// Mc / Mc}"
		DST="${DST//\.\ \ /\.\ }"
		echo $(( $COUNT*100/$TOTAL ))\%: Processing "$DST"...
		COUNT=$(( $COUNT+1 ))
		LTR=$(echo $DST | cut -c 1 | sed -e 's/^./\U&/g; s/ ./\U&/g')
		sudo mkdir -p $PPL/$LTR/"$DST" >& /dev/null
		sudo mv $TMP/"$line"/*.jpg $PPL/$LTR/"$DST"/poster.jpg && sudo rm -R $TMP/"$line"
	done)
	#done) | dialog --title "Moving images into correct folders..." --gauge "\nPlease wait...\n" 11 70
	sudo rm -R /opt/mediabrowser/ProgramData-Server/temp
}

# ==================================================================
# Set up some variables for the script:
# ==================================================================
# Determine home folder:
cd ~
HOME_DIR=$(pwd)

# What version of Emby are we running?
INSTALLED=
if [[ -f $EMBY_HOME/ProgramData-Server/config/system.xml ]]; then
	url=http://$(echo $(hostname -I)):$(echo $(cat $EMBY_HOME/ProgramData-Server/config/system.xml | grep "HttpServerPortNumber" | sed -e 's/<[a-zA-Z\/][^>]*>//g'))
	INSTALLED=$(curl -s $url/web/login.html | sed -n 's/.*window.dashboardVersion=\([^"]*\).*/\1/p' | cut -d";" -f1)
	INSTALLED=$(echo ${INSTALLED//\'/} | tee /tmp/mediabrowser.current)
	sudo mv /tmp/mediabrowser.current $EMBY_HOME/mediabrowser.current
fi

# Which branch are we running?  Assume Stable if not specified:
BRANCH=$(test -f $EMBY_HOME/mediabrowser.branch && cat $EMBY_HOME/mediabrowser.branch || echo 'stable')

# ==================================================================
# Are we requesting a CRON job to be done?
# ==================================================================
if [[ "$1" == "cron" ]]; then
	upgrade_emby
	exit $upgraded
fi

# ==================================================================
# Display the menu, then execute selected option:
# ==================================================================
title "Emby Server installation - Version $VERSION"
cmd=(dialog --ascii-lines --cancel-label "Exit" --backtitle "Simple Emby Server Installer - Version $VERSION" --menu "Welcome to the Simple Emby Server Installer.\nWhat would you like to do?\n " 18 50 17)
opt1=
if [ "$INSTALLED" == "" ]]; then
	options=(
		1 "Install Emby Server"
		2 "Update this script to latest version"
	)
else
	options=(
		1 "Install Emby Server and support packages"
		2 "Update this script to latest version"
		3 "Toggle Cron job for automatic Emby Updates"
		4 "Update Emby Server to latest version"
		5 "Restore old copy of Emby Server (if available)"
		6 "Install Emby for Kodi add-ons"
		7 "Change Emby Server installation branch"
		8 "Rebuild FFmpeg from Git repository"
	)
fi
choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
case $choice in
	1)	# Install Emby Server and support packages:
		make_choice
		install_prerequisites
		install_dependencies
		build_ffmpeg
		install_mono
		install_emby
		create_service
		if [[ -d $HOME_DIR/.kodi ]]; then
			install_addons
		fi
		done_installing
		;;

	2)	# Update this script to latest version
		update_script
		;;

	3)	# Toggle Cron job for automatic Emby Updates
		toggle_cron_job
		;;

	4)	# Update Emby Server to latest version
		upgrade_emby
		if [[ $upgraded == 0 ]]; then
			dialog --ascii-lines --title "Update Emby Server" --msgbox "\nYour Emby Server is up to date!.\nPress OK to return to the menu.\n" 11 70
		fi
		if [[ $upgraded == 1 ]]; then
			dialog --ascii-lines --title "Update Emby Server" --msgbox "\nYour Emby Server has been upgraded to v$LATEST_VER.\nPress OK to return to the menu.\n" 11 70
		fi
		exec $HOME_DIR/install-emby.sh
		;;

	6)	# Install Emby for Kodi add-ons
		if [[ -d $HOME_DIR/.kodi ]]; then
			install_addons
		else
			dialog --ascii-lines --title "Install Emby for Kodi Addons" --msgbox "\nYour Kodi install could not be found at \"$EMBY_HOME\".\nThe add-ons were not installed.\nPress OK to return to the menu.\n" 11 70
		fi
		exec $HOME_DIR/install-emby.sh
		;;
		
	7)	# Change Emby Server installation branch:
		make_choice
		install_emby
		create_service
		done_installing
		;;
		
	8)  # Rebuild FFmpeg from Git repository
		build_ffmpeg
		exec $HOME_DIR/install-emby.sh
		;;
esac
clear
