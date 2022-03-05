#!/bin/bash
#
# This script looks at the operating system, architecture, bit type, etc., to determine
# whether or not the system is supported by Mewdeko. Once the system is deemed as
# supported, the master installer will be downloaded and executed.
#
# Comment key:
#   A.1. - Grouping One
#   A.2. - Grouping Two
#
########################################################################################
#### [ Exported and/or Globally Used Variables ]


# Revision number of 'linuxAIO.sh'.
# Refer to the 'README' note at the beginning of 'linuxAIO.sh' for more information.
current_linuxAIO_revision="1"
# Name of the master installer script.
main_installer="mewdeko_main_installer.sh"

## Modify output text color.
export _YELLOW=$'\033[1;33m'
export _GREEN=$'\033[0;32m'
export _CYAN=$'\033[0;36m'
export _RED=$'\033[1;31m'
export _NC=$'\033[0m'
export _GREY=$'\033[0;90m'
export _CLRLN=$'\r\033[K'

## PURPOSE: The '--no-hostname' flag for 'journalctl' only works with systemd 230 and
##          later. So if systemd is older than 230, $_NO_HOSTNAME will not be created.
{
    journalctl_version=$(journalctl --version)
    journalctl_version=${journalctl_version:1:1}

    if ((journalctl_version >= 230)); then export _NO_HOSTNAME="--no-hostname"
    fi
} 2>/dev/null


#### End of [ Exported and/or Globally Used Variables ]
########################################################################################
#### [ Functions ]


detect_sys_info() {
    ####
    # Function Info: Identify the operating system, version number, architecture, bit
    #                type (32 or 64), etc.
    ####

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        _DISTRO="$ID"
        _VER="$VERSION_ID"  # Version: x.x.x...
        _SVER=${_VER//.*/}  # Version: x
        pname="$PRETTY_NAME"
    else
        _DISTRO=$(uname -s)
        _VER=$(uname -r)
    fi

    ## Identify bit and architecture type.
    case $(uname -m) in
        x86_64) bits="64"; _ARCH="x64" ;;
        i*86)   bits="32"; _ARCH="x86" ;;
        armv*)  bits="32"; _ARCH="?" ;;
        *)      bits="?";  _ARCH="?" ;;
    esac
}

# TODO: Add error checking to sed...
linuxAIO_update() {
    ####
    # Function Info: Download the latest version of 'linuxAIO.sh' if $_LINUXAIO_REVISION
    #                and $current_linuxAIO_revision aren't of equal value.
    ####

    echo "${_YELLOW}You are using an older version of 'linuxAIO.sh'$_NC"
    echo "Downloading latest 'linuxAIO.sh'..."

    ## Save the values of the current Configuration Variables specified in
    ## 'linuxAIO.sh', to be set in the new 'linuxAIO.sh'.
    ## NOTE: Declaration and instantiation is separated at the recommendation by
    ##       shellcheck.
    local installer_branch                                       # A.1.
    local installer_branch_found                                 # A.1.
    installer_branch=$(grep '^installer_branch=.*' linuxAIO.sh)  # A.1.
    installer_branch_found="$?"	                                 # A.1.
    local mewdko_install_version                                                      # A.2.
    local mewdko_install_version_found                                                # A.2.
    mewdko_install_version=$(grep '^export _MEWDEKO_INSTALL_VERSION=.*' linuxAIO.sh)  # A.2.
    mewdko_install_version_found="$?"                                                 # A.2.

    curl -O "$_RAW_URL"/linuxAIO.sh \
        && sudo chmod +x linuxAIO.sh

    echo "Applying existing configurations to the new 'linuxAIO.sh'..."

    ## Set $installer_branch inside of the new 'linuxAIO.sh'.
    if [[ $installer_branch_found = 0 ]]; then
        sed -i "s/^installer_branch=.*/$installer_branch/" linuxAIO.sh
    fi

    ## Set $mewdko_install_version inside of the new 'linuxAIO.sh'.
    if [[ $mewdko_install_version_found = 0 ]]; then
        sed -i "s/^export _MEWDEKO_INSTALL_VERSION=.*/$mewdko_install_version/" linuxAIO.sh
    fi

    echo "${_GREEN}Successfully downloaded the newest version of 'linuxAIO.sh'" \
        "and applied changes to the newest version of 'linuxAIO.sh'$_NC"

    clean_up "0" "Exiting" "true"
}

unsupported() {
    ####
    # Function Info: Provide the end-user with the option to continue, even if their
    #                system isn't officially supported.
    ####

    echo "${_RED}Your operating system/Linux Distribution is not OFFICIALLY supported" \
        "for the installation, setup, and/or use of Mewdeko" >&2
    echo "${_YELLOW}WARNING: By continuing, you accept that unexpected behaviors" \
        "may occur. If you run into any errors or problems with the installation and" \
        "use of the Mewdeko, you are on your own.$_NC"
    read -rp "Would you like to continue anyways? [y/N] " choice

    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    case "$choice" in
        y|yes) clear -x; execute_main_installer ;;
        *)     clean_up "0" "Exiting" ;;
    esac
}

clean_up() {
    ####
    # Function Info: Cleanly exit the installer by removing files that aren't required
    #                unless the installer is currently running.
    #
    # Parameters:
    #   $1 - Exit status code.
    #   $2 - Output text.
    #   $3 - Determines if 'Cleaning up...' needs to be printed with a new-line symbol.
    ####

    # Files to be removed.
    local installer_files=("installer_prep.sh" "prereqs_installer.sh"
        "nadeko_latest_installer.sh" "nadeko_runner.sh" "mewdeko_main_installer.sh"
        "file_backup.sh")

    if [[ $3 = true ]]; then echo "Cleaning up..."
    else                     echo -e "\nCleaning up..."
    fi

    cd "$_WORKING_DIR" || {
        echo "${_RED}Failed to move to project root directory$_NC" >&2
        exit 1
    }

    ## Remove 'mewdeko_tmp' if it exists.
    ## EXPLANATION: 'mewdeko_tmp' contains a newly downloaded version of Mewdeko. If
    ##              the installer is stopped while downloading Mewdeko, this directory
    ##              will remain on the system, if this if statement doesn't exist.
    if [[ -d mewdeko_tmp ]]; then rm -rf mewdeko_tmp
    fi

    ## Remove any and all files specified in $installer_files.
    for file in "${installer_files[@]}"; do
        if [[ -f $file ]]; then rm "$file"
        fi
    done

    echo "$2..."
    exit "$1"
}

execute_main_installer() {
    ####
    # Function Info: Download and execute $main_installer.
    ####

    _DOWNLOAD_SCRIPT "$main_installer" "true"
    ./mewdeko_main_installer.sh
    clean_up "$?" "Exiting"
}

########################################################################################
#### [[ Functions To Be Exported ]]


# TODO: Add explanation to $2...
_DOWNLOAD_SCRIPT() {
    ####
    # Function Info: Download the specified script and modify it's execution
    #                permissions.
    #
    # Parameters:
    #   $1 - Name of script to download.
    #   $2 - ...
    ####

    if [[ ! $2 ]]; then echo "Downloading '$1'..."
    fi
    curl -O -s "$_RAW_URL"/"$1"
    sudo chmod +x "$1"
}


#### End of [[ Functions To Be Exported ]]
########################################################################################

#### End of [ Functions ]
########################################################################################
#### [ Error Traps ]


# Execute when the user uses 'Ctrl + Z', 'Ctrl + C', or otherwise forcefully exits the
# installer.
trap 'echo -e "\n\nScript forcefully stopped"
    clean_up "2" "Exiting" "true"' \
    SIGINT SIGTSTP SIGTERM


#### End of [ Error Traps ]
########################################################################################
#### [ Prepping ]


# If the current 'linuxAIO.sh' revision number is not of equil value of the expected
# revision number.
if [[ $_LINUXAIO_REVISION && $_LINUXAIO_REVISION != "$current_linuxAIO_revision" ]]; then
    linuxAIO_update
    clean_up "0" "Exiting" "true"
fi

# Change the working directory to the location of the executed scrpt.
cd "$(dirname "$0")" || {
    echo "${_RED}Failed to change working directory" >&2
    echo "${_CYAN}Change your working directory to that of the executed script$_NC"
    clean_up "1" "Exiting" "true"
}

export _WORKING_DIR="$PWD"
export _INSTALLER_PREP="$_WORKING_DIR/installer_prep.sh"


#### End of [ Prepping ]
########################################################################################
#### [ Main ]


clear -x  # Clear the screen of any text.

detect_sys_info
export _DISTRO _SVER _VER _ARCH
export -f _DOWNLOAD_SCRIPT

# Use $_DISTRO if $pname is unset or null...
echo "SYSTEM INFO
Bit Type: $bits
Architecture: $_ARCH
Distro: ${pname:=$_DISTRO}
Distro Version: $_VER
"

### Check if the operating system is supported by Mewdeko and installer.
if [[ $bits = 64 ]]; then
    # Ubuntu:
    #   16.04
    #   18.04
    #   20.04
    if [[ $_DISTRO = "ubuntu" ]]; then
        case "$_VER" in
            16.04|18.04|20.04) execute_main_installer ;;
            *)                 unsupported ;;
        esac
    # Debian:
    #   9
    #   10
    elif [[ $_DISTRO = "debian" ]]; then
        case "$_SVER" in
            9|10) execute_main_installer ;;
            *)    unsupported ;;
        esac
    # Linux Mint:
    #   18
    #   19
    #   20
    elif [[ $_DISTRO = "linuxmint" ]]; then
        case "$_SVER" in
            18|19|20) execute_main_installer ;;
            *)        unsupported ;;
        esac
    else
        unsupported
    fi
else
    unsupported
fi


#### End of [ Main ]
########################################################################################