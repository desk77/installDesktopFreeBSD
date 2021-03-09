#!/bin/sh

# DarkMate Desktop for FreeBSD
# by Felix Caffier
# http://www.trisymphony.com
# rev. 2021-03-10 with dialog UI

# ----------------------------------------------------------------------
# ------------------------------------ Notes
# ----------------------------------------------------------------------

# One themed desktop (MATE)
# Basic software selection

# ": not found :" error is caused by wrong line endings! If you edit
# this script, make sure to save LF only, not CR or CR/LF!

# startup options:
# -x  Do not explicitly install XORG
# -u  Run "freebsd-update" before installation
# -d  Do not use dialog, instead use the classic CLI

# ----------------------------------------------------------------------
# ------------------------------------ globals & setup
# ----------------------------------------------------------------------

VER='13.0'
REPO="https://raw.githubusercontent.com/broozar/installDesktopFreeBSD/DarkMate${VER}/files/"

# ------------------------------------ control vars and strings

INST_PKG=1			# assume a fresh install
MIRR_PKG=''			# mirrors for PKG: 0 "", 1 "eu.", 2 "us-east.", 3 "us-west."
FBSD_UPD=0			# fetch security patches only if requested
INST_XORG=1			# needed for every desktop
INST_MATE=1			# nice desktop environment

KBD_LANG='US'		# keyboard layout (language)
KBD_VAR=''			# keyboard layout (variant)

INST_Firefox=0		# free browser
INST_Chromium=0		# google browser
INST_Thunderbird=0	# mail client
INST_Office=0		# libreoffice
INST_VLC=0			# media playback
INST_CPP=0			# C++ and IDE
INST_Java=0			# Java and IDE

INST_VIDEO_NVIDIA_CUR=0			# current NVIDIA driver
INST_VIDEO_NVIDIA_390=0			# legacy NVIDIA driver
INST_VIDEO_NVIDIA_340=0			# even older NVIDIA driver
INST_VIDEO_NVIDIA_304=0			# decade old NVIDIA driver
INST_VIDEO_AMDGPU=0				# modern AMD video driver
INST_VIDEO_RADEON=0				# alternative AMD video driver
INST_VIDEO_RADEONHD=0			# another alternative AMD video driver # UNUSED
INST_VIDEO_INTEL_CURRENT=0		# Intel video driver >Sandy Bridge
INST_VIDEO_INTEL_LEGACY=0		# Intel video driver <Sandy Bridge

USERGROUPS="wheel,video"		# default groups for new users. CUPS added later if office is installed

# ------------------------------------ pretty colors!

CR='\033[0;31m'		# color red
CG='\033[0;32m'		# color green
CC='\033[0;36m'		# color cyan
CY='\033[1;33m'		# color yellow
NC='\033[0m' 		# no color

# ------------------------------------ dialog

DIA_ON=1			# dialog UI is ON by default

DIA_OPT_HEIGHT=15
DIA_OPT_WIDTH=60
DIA_CHOICE_HEIGHT=7
DIA_MSG_HEIGHT=7
DIA_MSG_WIDTH=60
DIA_RESULT=''	# results for menu, radiolist, checklist
DIA_BACKTITLE="Backtitle here"
DIA_OPTIONS="1 Option1
				2 Option2 "

# ------------------------------------ templates

# yes/no question function - default NO
# return variable
# $1 question
_n () {
	read -p "$1" response
	if echo "$response" | grep -iq "^y" ; then
		return 1
	else
		return 0
	fi
}
# the same with dialog
# $1 question, $2 title
_dn () {
	dialog --clear --title "$2" --backtitle "$DIA_BACKTITLE" --yesno "$1" $DIA_MSG_HEIGHT $DIA_MSG_WIDTH
	if [ $? -eq 0 ] ; then
		return 1
	else
		return 0
	fi
}

# radio selection with dialog
# $1 question, $2 title
_dr () {
	DIA_RESULT=''
	DIA_RESULT=$(dialog --clear --title "$2" --backtitle "$DIA_BACKTITLE" --radiolist "$1" $DIA_OPT_HEIGHT $DIA_OPT_WIDTH $DIA_CHOICE_HEIGHT $DIA_OPTIONS 2>&1 > /dev/tty)
}

# checklist selection with dialog
# $1 question, $2 title
_dc () {
	DIA_RESULT=''
	DIA_RESULT=$(dialog --clear --title "$2" --backtitle "$DIA_BACKTITLE" --checklist "$1" $DIA_OPT_HEIGHT $DIA_OPT_WIDTH $DIA_CHOICE_HEIGHT $DIA_OPTIONS 2>&1 > /dev/tty)
}

# menu selection with dialog
# $1 question, $2 title
_dm () {
	DIA_RESULT=''
	DIA_RESULT=$(dialog --clear --title "$2" --backtitle "$DIA_BACKTITLE" --menu "$1" $DIA_OPT_HEIGHT $DIA_OPT_WIDTH $DIA_CHOICE_HEIGHT $DIA_OPTIONS 2>&1 > /dev/tty)
}

# form input with dialog
# $1 question, $2 title
_df () {
	DIA_RESULT=''
	DIA_RESULT=$(dialog --clear --ok-label "Submit" --title "$2" --backtitle "$DIA_BACKTITLE" --form "$1" $DIA_OPT_HEIGHT $DIA_OPT_WIDTH $DIA_CHOICE_HEIGHT $DIA_OPTIONS 2>&1 > /dev/tty)
}

# ------------------------------------ other functions

_abort () {
	clear
	printf "Installation aborted.\n"
	exit 1
}

_abortmsg () {
	clear
	printf "$1\n"
	printf "Installation aborted.\n"
	exit 1
}

_anykey () {
	echo ""
	read -p "Press any key to continue..." disregard
	clear
}

# ----------------------------------------------------------------------
# ------------------------------------ user interaction
# ----------------------------------------------------------------------

# ------------------------------------ welcome message

clear
printf "${CC}DarkMate setup script for FreeBSD ${VER}\nby Felix Caffier (http://www.trisymphony.com)${NC}\n\n"
printf "This script will install PKG, X, the MATE desktop with theming, some optional\n"
printf "Desktop software, SLiM, and set up users.\n\n"
printf "If you made a mistake answering the questions, you can quit out\n"
printf "of the installer by pressing ${CC}CTRL+C${NC} and then start again.\n\n"

# ------------------------------------ checks

c_root () {
	MY_ID=$(id -u)
	if [ "$MY_ID" -ne 0 ]; then
		_abortmsg "[ ${CR}ERROR${NC} ]  This script needs to be run as ${CC}root user${NC}."
	fi
	printf "[ ${CG}INFO${NC} ]  Running as root\n"
}

c_arch () {
	MY_ARCH=$(uname -m)
	printf "[ ${CG}INFO${NC} ]  Processor architecture: $MY_ARCH\n"
}

c_pkg () {
	case "$(/usr/sbin/pkg -N 2>&1)" in
		*" not "*) 
			printf "[ ${CG}INFO${NC} ]  PKG will be bootstrapped\n"
			INST_PKG=1
			;;
		*) 
			printf "[ ${CY}NOTE${NC} ]  PKG was bootstrapped before\n"
			INST_PKG=0
			;;
	esac
}

c_overrides () {
	while getopts ":xud" opt; do
		case $opt in
			x)
				INST_XORG=0
				printf "[ ${CY}NOTE${NC} ]  -x: Xorg will not be explicitly installed!\n"
				;;
			u)
				FBSD_UPD=1
				printf "[ ${CY}NOTE${NC} ]  -u: Installing FreeBSD updates! [ ${CC}:q${NC} ] to continue after updates.\n"
				;;
			d)
				DIA_ON=0
				printf "[ ${CY}NOTE${NC} ]  -d: Dialog UI is disabled! Using traditional CLI.\n"
				;;
		esac
	done
}

c_network () {
	if nc -zw1 8.8.8.8 443 > /dev/null 2>&1 ; then
		printf "[ ${CG}INFO${NC} ]  Internet connection detected\n"
	else
		printf "[ ${CY}NOTE${NC} ]  Could not verify internet connection!\n"
		printf "[ ${CY}NOTE${NC} ]  You must be online for this script to work!\n"
		printf "[ ${CY}NOTE${NC} ]  Proceed with caution...\n\n"
	fi
}

c_root
c_arch
c_pkg
c_overrides
c_network

_anykey

# ------------------------------------ ask PKG mirror location

## CLI

pkg_mirror () {
	read -p "PKG Mirror: What is your location? 1:EU, 2:US-East, 3:US-West, 0:Other [0] " response
	if [ "$response" = "1" ] ; then
		MIRR_PKG='eu.'
	elif [ "$response" = "2" ] ; then
		MIRR_PKG='us-east.'
	elif [ "$response" = "3" ] ; then
		MIRR_PKG='us-west.'
	else
		echo "Choosing the default mirror."
	fi
}

## DIALOG

dia_pkg_mirror () {
		DIA_OPTIONS="1 EU
        2 US-East
        3 US-West
        4 Other/Default/Unknown"
	
	_dm "Please select your nearest download server:"	
	case $DIA_RESULT in
		0) _abort ;;
		1) MIRR_PKG='eu.' ;;
		2) MIRR_PKG='us-east.' ;;
		3) MIRR_PKG='us-west.' ;;
		*) MIRR_PKG='' ;;
	esac
}

## RUN

if [ $DIA_ON -eq 1 ] ; then
	dia_pkg_mirror
else
	pkg_mirror
fi

# ------------------------------------ keyboard selection

## CLI

kbd_read () {
	printf "[ ${CG}INFO${NC} ]  The default keymap for MATE and the login is '${CC}us${NC}' (English).\n"
	printf "You can change this now using your 2-letter languange code like '${CC}de${NC}' (German),\n"
	printf "'${CC}fr${NC}' (French), '${CC}dk${NC}' (Danish) etc., and a variant like '${CC}oss${NC}' or '${CC}dvorak${NC}' if\n"
	printf "needed in the 2nd step. You can change your keyboard mapping later at any point.\n\n"
	
	read -p "Which language does your keyboard have? [us] " response
	if [ -z "$response" ] ; then
		printf "Choosing the default US layout.\n\n"
	else
		KBD_LANG="$response"
	fi

	read -p "Which language variant does your keyboard use? [] " response
	if [ -z "$response" ] ; then
		printf "Choosing no special layout variant.\n\n"
	else
		KBD_VAR="$response"
	fi
}

## DIALOG

DIA_BACKTITLE="Keyboard Layout"

dia_kbd () {
	cd /tmp
	if fetch --no-verify-peer ${REPO}include/kbd_str.sh ; then
		. /tmp/kbd_str.sh
		
		DIA_OPTIONS="$DIA_KBD_LANG"
		_dm "Please select your keyboard layout:"
		if [ -z $DIA_RESULT ] ; then
			_abortmsg "Keymap selection is required."
		fi
		# make upper case
		KBD_LANG=$(echo $DIA_RESULT | tr '[a-z]' '[A-Z]')

		# only display variants if there are any
		DIA_OPTIONS=$(eval "echo \$DIA_KBD_VAR_${KBD_LANG}")
		if [ ! -z "$DIA_OPTIONS" ] ; then
			_dn "Would you like to add a special variant of your keyboard (e.g. dvorak, nodeadkeys etc.)?"
			if [ $? -eq 1 ] ; then
				_dm "Please select your keyboard variant:"
				KBD_VAR="$DIA_RESULT"
			fi
		fi
		
	else
		_abortmsg "Unable to download keyboard definition file from github."
	fi
}

## RUN 

if [ $DIA_ON -eq 1 ] ; then
	dia_kbd
else
	kbd_read
fi

# ------------------------------------ X software

## CLI

inst_xsoft () {
	# only install X software if X is being installed too
	if [ "$INST_XORG" -eq 0 ] ; then
		return 0
	fi
	
	printf "[ ${CG}INFO${NC} ]  Software selection\n\n"

	_n "Install Firefox (Mozilla web browser)? [y/N] "
	INST_Firefox=$?

	_n "Install Chromium (Chrome web browser)? [y/N] "
	INST_Chromium=$?

	_n "Install Thunderbird (E-Mail Client)? [y/N] "
	INST_Thunderbird=$?

	_n "Install Office (LibreOffice, SANE, CUPS)? [y/N] "
	INST_Office=$?

	_n "Install VLC media player (video & audio)? [y/N] "
	INST_VLC=$?

	_n "Install C++ and IDE (CodeLite)? [y/N] "
	INST_CPP=$?

	_n "Install Java and IDE (Netbeans)? [y/N] "
	INST_Java=$?

	echo ""
}

## DIALOG

DIA_BACKTITLE="Application selection"

dia_inst_xsoft () {
	# only install X software if X is being installed too
	if [ "$INST_XORG" -eq 0 ] ; then
		return 0
	fi
	
	DIA_OPTIONS="1 Firefox on
        2 Chromium on
        3 Thunderbird off
        4 Libreoffice/SANE/CUPS off
        5 VLC on
        6 CodeLite/C++ on
        7 Netbeans/Java off"
	
	_dc "Please choose your X applications:"
	case $DIA_RESULT in *1*) INST_Firefox=1 ;; esac
	case $DIA_RESULT in *2*) INST_Chromium=1 ;; esac
	case $DIA_RESULT in *3*) INST_Thunderbird=1 ;; esac
	case $DIA_RESULT in *4*) INST_Office=1 ;; esac
	case $DIA_RESULT in *5*) INST_VLC=1 ;; esac
	case $DIA_RESULT in *6*) INST_CPP=1 ;; esac
	case $DIA_RESULT in *7*) INST_Java=1 ;; esac
}

## RUN

if [ $DIA_ON -eq 1 ] ; then
	dia_inst_xsoft
else
	inst_xsoft
fi

# ------------------------------------ graphics driver

## CLI

video_nvidia () {
	_n "Install NVidia-current drivers (GeForce 600 and later)? [y/N] "
	INST_VIDEO_NVIDIA_CUR=$?

	if [ "$INST_VIDEO_NVIDIA_CUR" -eq 0 ] ; then
		_n "Install NVidia-legacy drivers instead (v390)? [y/N] "
		INST_VIDEO_NVIDIA_390=$?
	fi
	if [ "$INST_VIDEO_NVIDIA_CUR" -eq 0 -a "$INST_VIDEO_NVIDIA_390" -eq 0 ] ; then
		_n "Install NVidia-old drivers instead (v340)? [y/N] "
		INST_VIDEO_NVIDIA_340=$?
	fi
	if [ "$INST_VIDEO_NVIDIA_CUR" -eq 0 -a "$INST_VIDEO_NVIDIA_390" -eq 0 -a "$INST_VIDEO_NVIDIA_340" -eq 0 ] ; then
		_n "Install NVidia-ancient drivers instead (v304)? [y/N] "
		INST_VIDEO_NVIDIA_304=$?
	fi
}

video_amd () {
	_n "Install AMDGPU drivers? [y/N] "
	INST_VIDEO_AMDGPU=$?

	if [ "$INST_VIDEO_AMDGPU" -eq 0 ] ; then
		_n "Install RADEON drivers instead ()? [y/N] "
		INST_VIDEO_RADEON=$?
	fi
}

video_intel () {
	_n "Install INTEL drivers (Sandy Bridge and later)? [y/N] "
	INST_VIDEO_INTEL_CURRENT=$?

	if [ "$INST_VIDEO_INTEL_CURRENT" -eq 0 ] ; then
		_n "Install INTEL-legacy drivers instead? [y/N] "
		INST_VIDEO_INTEL_LEGACY=$?
	fi
}

## DIALOG

DIA_BACKTITLE="Video driver"

dia_video_select () {
	DIA_OPTIONS="1 nVidia_current_GeForce600+
				2 nVidia_legacy_v390
				3 nVidia_old_v340
				4 nVidia_ancient_304
				5 AMDGPU_current
				6 RADEON/ATI_old
				7 Intel_current_SandyBridge+
				8 Intel_old
				9 Unknown/Default/Auto"
	
	_dm "Please select your graphics hardware:"
	case $DIA_RESULT in
		1) INST_VIDEO_NVIDIA_CUR=1 ;;
		2) INST_VIDEO_NVIDIA_390=1 ;;
		3) INST_VIDEO_NVIDIA_340=1 ;;
		4) INST_VIDEO_NVIDIA_304=1 ;;
		5) INST_VIDEO_AMDGPU=1 ;;
		6) INST_VIDEO_RADEON=1 ;;
		7) INST_VIDEO_INTEL_CURRENT=1 ;;
		8) INST_VIDEO_INTEL_LEGACY=1 ;;
		9) ;;
		*) _abort;;
	esac
}

## RUN

if [ $DIA_ON -eq 1 ] ; then
	dia_video_select
else
	printf "[ ${CG}INFO${NC} ]  Graphics drivers ${CY}(experimental)${NC} - Select a driver based on the\n"
	printf "model of your card. Only the latest drivers support auto configuration!\n\n"
	
	_n "Do you want to install drivers for nVidia GPUs? [y/N] "
	if [ "$?" -eq 1 ] ; then
		video_nvidia
		return 0
	fi

	_n "Do you want to install drivers for AMD GPUs? [y/N] "
	if [ "$?" -eq 1 ] ; then
		video_amd
		return 0
	fi

	_n "Do you want to install drivers for Intel GPUs? [y/N] "
	if [ "$?" -eq 1 ] ; then
		video_intel
		return 0
	fi
fi

# ------------------------------------ confirmation

## CLI

lastchance () {
	echo ""

	printf "[ ${CY}NOTE${NC} ]  Last chance to turn back!\n"
	read -p "Is everything above correct? Start installation now? [y/N] " response
	if echo "$response" | grep -iq "^y" ; then
		echo "" # starting installation now
	else
		_abort
	fi
}

## DIALOG

DIA_BACKTITLE="Confirmation"

dia_lastchance () {
	DIA_MSG_HEIGHT=15
	
	SEL_MIRROR="Mirror: pkg.${MIRR_PKG}FreeBSD.org"
	SEL_KBD="Keyboard: $KBD_LANG"
	SEL_VIDEO="Video driver:"
	SEL_XSOFT="X Software:"
	
	if [ ! -z $KBD_VAR ] ; then
		SEL_KBD="Keyboard: $KBD_LANG (variant: $KBD_VAR)"
	fi
	
	if [ $INST_VIDEO_NVIDIA_CUR -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO nVidia (current)"
	elif [ $INST_VIDEO_NVIDIA_390 -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO nVidia (legacy v390)"
	elif [ $INST_VIDEO_NVIDIA_340 -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO nVidia (old v340)"
	elif [ $INST_VIDEO_NVIDIA_304 -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO nVidia (ancient v304)"
	elif [ $INST_VIDEO_AMDGPU -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO AMDGPU (current)"
	elif [ $INST_VIDEO_RADEON -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO RADEON (legacy)"
	elif [ $INST_VIDEO_INTEL_CURRENT -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO INTEL (current)"
	elif [ $INST_VIDEO_INTEL_LEGACY -eq 1 ] ; then
		SEL_VIDEO="$SEL_VIDEO INTEL (legacy)"
	fi

	if [ $INST_Firefox -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} Firefox"
	fi
	if [ $INST_Chromium -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} Chromium"
	fi
	if [ $INST_Thunderbird -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} Thunderbird"
	fi
	if [ $INST_Office -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} LibreOffice SANE CUPS"
	fi
	if [ $INST_VLC -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} VLC"
	fi
	if [ $INST_CPP -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} CodeLite C++"
	fi
	if [ $INST_Java -eq 1 ] ; then
		SEL_XSOFT="${SEL_XSOFT} Netbeans Java"
	fi
	
	_dn "Please confirm your selection:\n\n${SEL_MIRROR}\n${SEL_KBD}\n${SEL_VIDEO}\n\n${SEL_XSOFT}\n"
	if [ $? -eq 0 ] ; then
		_abort
	fi
	
	DIA_MSG_HEIGHT=7
}

## RUN

if [ $DIA_ON -eq 1 ] ; then
	dia_lastchance
else
	lastchance
fi

# ----------------------------------------------------------------------
# ------------------------------------ user setup
# ----------------------------------------------------------------------

## UNIVERSAL

s_skel () {
	# home subfolders
	mkdir /usr/share/skel/Documents
	mkdir /usr/share/skel/Downloads
	mkdir /usr/share/skel/Media
	mkdir /usr/share/skel/Programming

	# MATE startup
	touch /usr/share/skel/dot.xinitrc
	echo "exec mate-session" > /usr/share/skel/dot.xinitrc

	# separators
	mkdir -p /usr/share/skel/dot.config/gtk-3.0
	touch /usr/share/skel/dot.config/gtk-3.0/gtk.css
	echo "PanelSeparator {
		color: transparent;
	}
	" > /usr/share/skel/dot.config/gtk-3.0/gtk.css

	# rights
	chown -R root:wheel /usr/share/skel 
}

## CLI

s_user () {
	printf "[ ${CG}INFO${NC} ]  Creating new user account. Please follow the instructions.\n"
	if [ "$INST_Office" -eq 1 ] ; then
		printf "on screen, and remember to invite yourself to the '${CC}wheel video cups${NC}'\n"
	else
		printf "on screen, and remember to invite yourself to the '${CC}wheel video${NC}'\n"
	fi
	printf "groups and give yourself a proper ${CY}password${NC}!\n"
	printf "The installer also assumes your home folder is located in ${CC}/home${NC}.\n\n"

	if [ "$INST_Office" -eq 1 ] ; then
		groupadd cups
	fi

	if adduser ; then
		echo ""	# continue
	else
		printf "[ ${CR}ERROR${NC} ]  User creation failed!\n"
		exit 1
	fi
}

## DIALOG

DIA_BACKTITLE="User accounts"

dia_s_user () {
	DIA_OPTIONS="Username: 1 1 username 1 11 15 0
	Password: 2 1 pass1234 2 11 15 0
	UID: 3 1 auto 3 11 15 0
	GID: 4 1 auto 4 11 15 0
	HomeDir: 5 1 auto 5 11 15 0"
	
	_df "Enter data for a new user. You can leave UID, GID and HOMEDIR (/home/...) on auto if you wish to use the defaults."
	dia_account $DIA_RESULT
}

# $1 username $2 password $3 uid $4 gid $5 home
dia_account () {
	if [ "$#" -ne 5 ] ; then
		_dn "Input error. Try again?"
		if [ $? -eq 1 ] ; then
			dia_s_user
			return 0
		else
			_abortmsg "User creation failed."
		fi
	fi
	
	if [ "$5" = "auto" ] ; then
		echo "$2" | pw user add -n "$1" -G "$USERGROUPS" -m -h 0
		if [ ! -d "/home/$1" ] ; then
			_dn "User account creation failed. Try again?"
			if [ $? -eq 1 ] ; then
				dia_s_user
				return 0
			else
				_abortmsg "User creation failed."
			fi
		fi
		
	else
		echo "$2" | pw user add -n "$1" -G "$USERGROUPS" -m -d "$5" -h 0
		if [ ! -d "$5" ] ; then
			_dn "User account creation failed. Try again?"
			if [ $? -eq 1 ] ; then
				dia_s_user
				return 0
			else
				_abortmsg "User creation failed."
			fi
		fi
	fi	
	
	if [ "$3" != "auto" ] ; then
		pw user mod -n "$1" -u "$3"
		if [ ! $? ] ; then
			_dn "UID modification failed. Try again?"
			if [ $? -eq 1 ] ; then
				dia_s_user
				return 0
			else
				_abortmsg "User creation failed."
			fi
		fi
	fi
	
	if [ "$4" != "auto" ] ; then
		pw user mod -n "$1" -g "$4"
		if [ ! $? ] ; then
			_dn "GID modification failed. Try again?"
			if [ $? -eq 1 ] ; then
				dia_s_user
				return 0
			else
				_abortmsg "User creation failed."
			fi
		fi
	fi
	
	_dn "User account creation was successful. Create another user?"
	if [ $? -eq 1 ] ; then
		dia_s_user
		return 0
	fi
}

## RUN

s_skel

if [ $DIA_ON -eq 1 ] ; then
	if [ "$INST_Office" -eq 1 ] ; then
		groupadd cups
		$USERGROUPS="${USERGROUPS},cups"
	fi

	_dn "Do you want to add new users to the system?"
	if [ $? -eq 1 ] ; then
		dia_s_user
	fi
else
	s_user
fi

# ----------------------------------------------------------------------
# ------------------------------------ installation
# ----------------------------------------------------------------------

# ------------------------------------ base

i_patches () {
	if [ "$FBSD_UPD" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Applying latest FreeBSD security patches\n\n"
		freebsd-update fetch install
		echo ""
	else
		printf "[ ${CY}NOTE${NC} ]  Skipping FreeBSD security patches\n"
	fi
}

i_pkg () {
	if [ "$INST_PKG" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Bootstrapping PKG\n\n"
		env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg
		echo ""
	else
		printf "[ ${CY}NOTE${NC} ]  Skipping PKG bootstrap\n"
	fi

	mkdir -p /usr/local/etc/pkg/repos
	touch /usr/local/etc/pkg/repos/FreeBSD.conf

	echo 'FreeBSD: {
	  url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest",
	  mirror_type: "srv",
	  enabled: yes
	}' > /usr/local/etc/pkg/repos/FreeBSD.conf

	sed -i ".bak" "s/pkg.FreeBSD.org/pkg.${MIRR_PKG}FreeBSD.org/" /usr/local/etc/pkg/repos/FreeBSD.conf
	rm /usr/local/etc/pkg/repos/FreeBSD.conf.bak

	if pkg update -f ; then
		echo "" # pkg was updated, we can continue
	else
		printf "[ ${CR}ERROR${NC} ]  PKG update failed\n"
		exit 1
	fi
}

i_xorg () {
	if [ "$INST_XORG" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing XORG\n\n"
		pkg install -y xorg
		echo ""
		
		pkg install -y urwfonts
		echo ""

		pkg install -y mesa-demos
		echo ""
	fi
}

clear
i_patches
i_pkg
i_xorg

# ------------------------------------ MATE

i_mate () {
	printf "[ ${CG}NOTE${NC} ]  Installing MATE Desktop\n\n"
	pkg install -y mate
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Brisk Menu\n\n"
	pkg install -y brisk-menu
	echo ""

	printf "[ ${CG}NOTE${NC} ]  Installing Arc Themes\n\n"
	pkg install -y gtk-arc-themes
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Arc Dark Grey\n\n"
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/Arc-Dark-Grey.tar.xz ; then
		tar xf Arc-Dark-Grey.tar.xz -C /usr/local/share/themes
		chmod -R 755 /usr/local/share/themes/Arc-Dark-Grey
		rm Arc-Dark-Grey.tar.xz
	fi
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Mint-Y-Dark-Aqua\n\n"
	THEME="Mint-Y-Dark-Aqua"
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/${THEME}.zip ; then
		tar xf ${THEME}.zip -C /usr/local/share/themes
		chmod -R 755 /usr/local/share/themes/${THEME}
		rm ${THEME}.zip
	fi
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Mint-Y-Dark-Grey\n\n"
	THEME="Mint-Y-Dark-Grey"
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/${THEME}.zip ; then
		tar xf ${THEME}.zip -C /usr/local/share/themes
		chmod -R 755 /usr/local/share/themes/${THEME}
		rm ${THEME}.zip
	fi
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Mint-Y-Dark-Red\n\n"
	THEME="Mint-Y-Dark-Red"
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/${THEME}.zip ; then
		tar xf ${THEME}.zip -C /usr/local/share/themes
		chmod -R 755 /usr/local/share/themes/${THEME}
		rm ${THEME}.zip
	fi
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Mint-Y-Dark-Teal\n\n"
	THEME="Mint-Y-Dark-Teal"
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/${THEME}.zip ; then
		tar xf ${THEME}.zip -C /usr/local/share/themes
		chmod -R 755 /usr/local/share/themes/${THEME}
		rm ${THEME}.zip
	fi
	echo ""
	
	printf "[ ${CG}NOTE${NC} ]  Installing Papirus icons\n\n"
	pkg install -y papirus-icon-theme
	echo ""

	printf "[ ${CG}NOTE${NC} ]  Adding PolicyKit rules\n\n"	
	cd /usr/local/share/polkit-1/rules.d
	fetch --no-verify-peer ${REPO}polkit/shutdown-reboot.rules
	chmod 755 shutdown-reboot.rules
	cd /tmp
	echo ""
}

s_procfs () {
	printf "[ ${CG}NOTE${NC} ]  Declaring procfs in /etc/fstab\n\n"
	if grep -q procfs /etc/fstab ; then
		printf "procfs entry already exists\n\n"
	else
		echo "proc		/proc	procfs	rw	0	0" >> /etc/fstab
	fi
}

s_tmpfs () {
	printf "[ ${CG}NOTE${NC} ]  Declaring tmpfs in /etc/fstab\n\n"
	if grep -q tmpfs /etc/fstab ; then
		printf "tmpfs entry already exists\n\n"
	else
		mkdir /ramdisk && chmod 777 /ramdisk && ln -s /ramdisk /usr/share/skel && echo "tmpfs		/ramdisk		tmpfs	rw	0	0" >> /etc/fstab
	fi	
}

i_slim () {
	printf "[ ${CG}NOTE${NC} ]  Installing SLiM\n\n"
	pkg install -y slim
	echo ""
	
	cd /tmp
	if fetch --no-verify-peer ${REPO}config/10-keyboard.conf ; then
		chmod 775 ./10-keyboard.conf
		if [ -z "$KBD_VAR" ] ; then
			sed -i ".bak" "s/#####KBD/Option \"XkbLayout\" \"${KBD_LANG}\"\n\tOption \"XkbVariant\" \"\"/" ./10-keyboard.conf
		else
			sed -i ".bak" "s/#####KBD/Option \"XkbLayout\" \"${KBD_LANG}\"\n\tOption \"XkbVariant\" \"${KBD_VAR}\"/" ./10-keyboard.conf
		fi
		
		mkdir -p /etc/X11/xorg.conf.d
		chmod 755 /etc/X11/xorg.conf.d
		mv ./10-keyboard.conf /etc/X11/xorg.conf.d/
	fi
}

t_slim () {
	printf "[ ${CG}NOTE${NC} ]  Installing SLiM theme\n\n"
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/darkslim.tar.xz ; then
		tar xf darkslim.tar.xz -C /usr/local/share/slim/themes
		sed -i ".bak" "s/current_theme.*/current_theme		darkslim/" /usr/local/etc/slim.conf
		rm darkslim.tar.xz
	fi
	echo ""
}

s_rcconf () {
	printf "[ ${CG}NOTE${NC} ]  Configuring rc.conf\n\n"
	
	cp /etc/rc.conf /etc/rc.conf.bak
	sysrc moused_enable="NO" # fix mouse scrolling conflict in MATE
	sysrc dbus_enable="YES"
	sysrc slim_enable="YES"
	sysrc hald_enable="YES"	# DEPRECATED
	
	if [ "$INST_Office" -eq 1 ] ; then
		sysrc cupsd_enable="YES"
	fi
}

t_mate () {
	printf "[ ${CG}NOTE${NC} ]  Installing MATE theme\n\n"
	mkdir -p /usr/local/share/backgrounds/fbsd
	chown root:wheel /usr/local/share/backgrounds/fbsd
	chmod 775 /usr/local/share/backgrounds/fbsd
	
	cd /usr/local/share/backgrounds/fbsd
	fetch --no-verify-peer ${REPO}wallpaper/centerFlat_grey-1080.png
	fetch --no-verify-peer ${REPO}wallpaper/centerFlat_grey-4k.png
	fetch --no-verify-peer ${REPO}wallpaper/centerFlat_red-1080.png
	fetch --no-verify-peer ${REPO}wallpaper/centerFlat_red-4k.png
	chmod 775 center*.png
	
	mkdir -p /usr/local/etc/dconf/profile
	cd /usr/local/etc/dconf/profile
	echo "user-db:user
system-db:mate
" > user
	chmod 755 user
	
	cd /tmp
	if fetch --no-verify-peer ${REPO}themes/darkmate-settings ; then
		chmod 775 darkmate-settings
		if [ -z "$KBD_VAR" ] ; then
			sed -i ".bak" "s/#####KBD/layouts=['${KBD_LANG}']/" darkmate-settings
		else
			sed -i ".bak" "s/#####KBD/layouts=['${KBD_LANG}\\\t${KBD_VAR}']/" darkmate-settings
		fi
		
		mkdir -p /usr/local/etc/dconf/db/mate.d
		mv darkmate-settings /usr/local/etc/dconf/db/mate.d
		
		dconf update
	fi
	
	echo ""
}

if [ "$INST_MATE" -eq 1 ] ; then
	clear
	i_mate		# install MATE & related pkgs
	s_procfs	# setup procfs
	s_tmpfs		# setup tmpfs
	i_slim		# install SLiM pkg
	t_slim		# theme SLiM
	s_rcconf	# modifying rc.conf
	t_mate		# theme mate
fi

# ------------------------------------ user selected software

i_firefox () {
	if [ "$INST_Firefox" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing Firefox Browser\n\n"
		pkg install -y firefox
		echo ""
	fi
}
i_firefox

i_chrome () {
	if [ "$INST_Chromium" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing Chromium Browser\n\n"
		pkg install -y chromium
		if grep -q kern.ipc.shm_allow_removed /etc/sysctl.conf ; then
			sed -i ".bak" "s/kern.ipc.shm_allow_removed.*/kern.ipc.shm_allow_removed=1/" /etc/sysctl.conf
		else
			echo "
# ---- for Chromium browser
kern.ipc.shm_allow_removed=1" >> /etc/sysctl.conf
		fi
		echo ""
	fi
}
i_chrome

i_mail () {
	if [ "$INST_Thunderbird" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing Thunderbird\n\n"
		pkg install -y thunderbird
		echo ""
		pkg install -y thunderbird-dictionaries
		echo ""
	fi
}
i_mail

i_vlc () {
	if [ "$INST_VLC" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing VLC Media Player\n\n"
		pkg install -y vlc
		echo ""
	fi
}
i_vlc

i_office () {
	if [ "$INST_Office" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing LibreOffice\n\n"
		pkg install -y libreoffice
		echo ""
		
		printf "[ ${CG}NOTE${NC} ]  Installing Xsane\n\n"
		pkg install -y xsane
		echo ""

		printf "[ ${CG}NOTE${NC} ]  Installing CUPS\n\n"
		pkg install -y cups
		echo ""
		pkg install -y cups-pdf
		echo ""
		pkg install -y gutenprint
		echo ""
	fi
}
i_office

i_cpp () {
	if [ "$INST_CPP" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing CodeLite IDE\n\n"
		pkg install -y codelite
		echo ""
	fi
}
i_cpp

i_java () {
	if [ "$INST_Java" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing Netbeans IDE\n\n"
		pkg install -y netbeans
		cd /usr/local/netbeans*/etc
		sed -i ".bak" 's/.*netbeans_jdkhome.*/netbeans_jdkhome=\"\/usr\/local\/openjdk8\"/' netbeans.conf
		echo ""
	fi
}
i_java

# ------------------------------------ automatically selected software

i_tools () {
	printf "[ ${CG}NOTE${NC} ]  Installing additional tools\n\n----- NANO\n"
	pkg install -y nano
	
	echo ""
	echo "----- VIM"
	pkg install -y vim

	echo ""
	echo "----- UNAR"
	pkg install -y unar

	echo ""
	echo "----- SYSINFO"
	pkg install -y sysinfo

	echo ""
	echo "----- HTOP"
	pkg install -y htop

	cd /usr/local/bin
	echo ""
	echo "----- INXI"
	fetch --no-verify-peer https://raw.githubusercontent.com/smxi/inxi/master/inxi
	chmod 755 inxi
	
	echo ""
	echo "----- custom"
	#fetch --no-verify-peer ${REPO}tools/cputemp.sh
	#chmod 755 cputemp.sh
	fetch --no-verify-peer ${REPO}tools/mate-dumpsettings.sh
	chmod 755 mate-dumpsettings.sh
	
	if [ "$INST_XORG" -eq 1 ] ; then
		echo ""
		echo "----- GEANY"
		pkg install -y geany
	fi
	
	echo ""
}
i_tools

# ------------------------------------ drivers and boot

pkg install -y drm-kmod

i_nvidia () {
	if [ "$INST_VIDEO_NVIDIA_CUR" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing NVIDIA (current)\n\n"
		pkg install -y nvidia-driver
		echo ""
		pkg install -y nvidia-xconfig
		echo ""
		pkg install -y nvidia-settings
		echo ""
		
		# run autoconfig
		nvidia-xconfig
		echo ""

	elif [ "$INST_VIDEO_NVIDIA_390" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing NVIDIA (legacy)\n\n"
		pkg install -y nvidia-driver-390
		echo ""
	
	elif [ "$INST_VIDEO_NVIDIA_340" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing NVIDIA (old)\n\n"
		pkg install -y nvidia-driver-340
		echo ""
	
	elif [ "$INST_VIDEO_NVIDIA_304" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing NVIDIA (ancient)\n\n"
		pkg install -y nvidia-driver-304
		echo ""
	fi
	
	# modify rc.conf for nvidia drivers
	
	if [ "$INST_VIDEO_NVIDIA_CUR" -eq 1 -o "$INST_VIDEO_NVIDIA_390" -eq 1 ] ; then
		sysrc kld_list+="nvidia-modeset"
		sysrc kld_list+="nvidia"
				
	elif [ "$INST_VIDEO_NVIDIA_340" -eq 1 -o "$INST_VIDEO_NVIDIA_304" -eq 1 ] ; then
		sysrc kld_list+="nvidia"
	fi	
}
i_nvidia

i_amd () {
	cd /etc/X11/xorg.conf.d/
	
	if [ "$INST_VIDEO_AMDGPU" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing AMDGPU (current)\n\n"
		if fetch --no-verify-peer ${REPO}config/20-amdgpu.conf ; then
			chmod 755 ./20-amdgpu.conf
			sysrc kld_list+="amdgpu"
			echo ""
		else
			printf "[ ${CR}FAIL${NC} ]  Could not download AMDGPU config file!\n"
			_n "The graphics driver may not work. Continue? [y/N] "
			if [ $? -q 0 ] ; then
				_abort
			fi
		fi

	elif [ "$INST_VIDEO_RADEON" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing RADEON (legacy)\n\n"
		if fetch --no-verify-peer ${REPO}config/20-radeon.conf ; then
			chmod 755 ./20-radeon.conf
			sysrc kld_list+="radeonkms"
			echo ""
		else
			printf "[ ${CR}FAIL${NC} ]  Could not download RADEON config file!\n"
			_n "The graphics driver may not work. Continue? [y/N] "
			if [ $? -q 0 ] ; then
				_abort
			fi
		fi
		
	elif [ "$INST_VIDEO_RADEONHD" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  RADEONHD driver is not supported\n"
		echo ""
		
	fi
	cd /tmp
}
i_amd

i_intel () {
	cd /etc/X11/xorg.conf.d/
	
	if [ "$INST_VIDEO_INTEL_CURRENT" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing INTEL graphics (current)\n\n"
		if fetch --no-verify-peer ${REPO}config/20-intelSB.conf ; then
			chmod 755 ./20-intelSB.conf
			sysrc kld_list+="i915kms"
			echo ""
		else
			printf "[ ${CR}FAIL${NC} ]  Could not download INTEL_SB config file!\n"
			_n "The graphics driver may not work. Continue? [y/N] "
			if [ $? -q 0 ] ; then
				_abort
			fi
		fi

	elif [ "$INST_VIDEO_INTEL_LEGACY" -eq 1 ] ; then
		printf "[ ${CG}NOTE${NC} ]  Installing INTEL (legacy)\n\n"
		if fetch --no-verify-peer ${REPO}config/20-intel.conf ; then
			chmod 755 ./20-intel.conf
			sysrc kld_list+="i915kms"
			echo ""
		else
			printf "[ ${CR}FAIL${NC} ]  Could not download INTEL config file!\n"
			_n "The graphics driver may not work. Continue? [y/N] "
			if [ $? -q 0 ] ; then
				_abort
			fi
		fi
	
	fi
	cd /tmp
}
i_intel

s_bootconf () {
	printf "[ ${CG}NOTE${NC} ]  Configuring boot/loader.conf\n\n"
	if grep -q coretemp_load /boot/loader.conf ; then
		sed -i ".bak" "s/coretemp_load.*/coretemp_load=\"YES\"/" /boot/loader.conf
	else
		echo "coretemp_load=\"YES\"" >> /boot/loader.conf
	fi
}
#s_bootconf #not sure why this is here

i_final () {
	clear
	printf "[ ${CG}NOTE${NC} ]  Time for a final update check!\n\n"
	pkg upgrade -y
	echo ""

	printf "[ ${CY}NOTE${NC} ]  Installation complete. Please restart your system!\n"
	printf "Either type ${CC}shutdown -r now${NC} to reboot now, or manually add\n"
	printf "other applications with ${CC}pkg install §name${NC} and reboot later.\n\n"
}
i_final

# EOF

# ------------------------------------ scratchpad - TODO

# testing on older AMD/nVidia graphics hardware
# testing on any Intel graphics hardware
