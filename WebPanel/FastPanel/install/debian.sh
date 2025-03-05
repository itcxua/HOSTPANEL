#!/bin/bash

export SYSTEMD_PAGER=''
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

function SetLogFile {
    export LOG_FILE="/tmp/install_fastpanel.debug"

    if [ -f "$LOG_FILE" ]; then
        rm "$LOG_FILE"
    fi
    
    exec 3>&1
    exec &> $LOG_FILE
}

function ParseParameters {
    CheckArch    
    CheckVersionOS
    while [ "$1" != "" ]; do
        case $1 in
            -m | --mysql )          shift
                                    ChooseMySQLVersion $1
                                    ;;
            -f | --force )          export force=1
                                    ;;
            -o | --only-panel )     export minimal=1
                                    ;;
            -h | --help )           Usage
                                    exit
                                    ;;
            * )                     Usage
                                    Error "Unknown option: \"$1\"."
        esac
        shift
    done
}

function ChooseMySQLVersion {
    shopt -s extglob
    local versions="@(${AVAILABLE_MYSQL_VERSIONS})"
    case "$1" in
        $versions )              export MYSQL_VERSION=$1
                                ;;
        * )                     Usage
                                Error "Unknown MySQL version: \"$1\"."
                                ;;
    esac
}

function Usage {
    cat << EOU >&3

Usage:  $0 [-h|--help]
        $0 [-f|--force] [-m|--mysql <mysql_version>]

Options:
    -h, --help             Print this help
    -f, --force            Skip check installed software (nginx, MySQL, apache2)
    -m, --mysql            Set MySQL version on fork for installation
            Available versions: ${AVAILABLE_MYSQL_VERSIONS}
EOU
}

function Greeting {
    ShowLogo
    Message "Greetings user!\n\nNow I will install the best control panel for you!\n\n"
}

function CheckPreinstalledPackages {
    case `dpkg --get-selections |grep -E "fastpanel2\s+install" -c` in
        0 )     Debug "Package 'fastpanel2' not installed."
                ;;
        1 )     Error "FASTPANEL package have already been installed on the server. Exiting.\n"
                ;;
    esac

    local PACKAGES="nginx apache2 "
    for package in ${PACKAGES}; do
        case `dpkg --get-selections |grep -E "${package}\s+install" -c` in
            0 )     Debug "Package '${package}' not installed."
                    ;;
            * )     INSTALLED_SOFTWARE+=("${package}")
                    ;;
        esac
    done
    
    for package in mysql-server mariadb-server percona-server-server percona-server-server-5.6 percona-server-server-5.7; do
        case `dpkg --get-selections |grep -E "${package}\s+install" -c` in
            0 )     Debug "Package '${package}' not installed."
                    ;;
            * )     Error "\nThe Control Panel can only be installed on a fresh OS installation.\nUnfortunately with the preinstalled MySQL installing is not possible."
                    ;;
        esac
    done
}


function InstallationFailed {
    if [ ! -z "$1" ]; then
        Debug "$1"
    fi
    printf "\033[1;31m[Failed]\033[0m\n" >&3
    printf "\033[1;31m\nOops! I've failed to install control panel... Please look for the reason in \"${LOG_FILE}\" log file.'\nFeel free to send the log to my creators via ticket at https://cp.fastpanel.direct/ and they will do their best to help you!\033[0m\n" >&3
    exit 1
}

function Error {
    printf "\033[1;31m$@\033[0m\n" >&3
    exit 1
}

function Message {
    printf "\033[1;36m$@\033[0m" >&3
    Debug "$@\n"
}

function Warning {
    printf "\033[1;35m$@\033[0m" >&3
    Debug "$@\n"
}

function Info {
    printf "\033[00;32m$@\033[0m" >&3
    Debug "$@\n"
}

function Debug {
    printf "$@\n"
}

function Success {
    printf "\033[00;32m[Success]\n\033[0m" >&3
}

function generatePassword {
    LENGHT="16"
    if [ ! -z "$1" ]; then
        LENGHT="$1"
    fi
    openssl rand -base64 64 | tr -dc a-zA-Z0-9=+ | fold -w ${LENGHT} |head -1
}

function UpdateSoftwareList {
    apt-get update -qq || InstallationFailed "Please check apt"
}

function InstallMySQLService {
    UpdateSoftwareList
    case ${MYSQL_VERSION} in
        mysql5.7 )              source /usr/share/fastpanel2/bin/mysql/install-mysql5.7.sh
                                ;;
        mysql8.0 )              source /usr/share/fastpanel2/bin/mysql/install-mysql8.0.sh
                                ;;
        mariadb10.4 )           source /usr/share/fastpanel2/bin/mysql/install-mariadb10.4.sh
                                ;;
        mariadb10.5 )           source /usr/share/fastpanel2/bin/mysql/install-mariadb10.5.sh
                                ;;
        mariadb10.6 )           source /usr/share/fastpanel2/bin/mysql/install-mariadb10.6.sh
                                ;;
        mariadb10.11 )          source /usr/share/fastpanel2/bin/mysql/install-mariadb10.11.sh
                                ;;
        percona5.7 )            source /usr/share/fastpanel2/bin/mysql/install-percona5.7.sh
                                ;;
        percona8.0 )            source /usr/share/fastpanel2/bin/mysql/install-percona8.0.sh
                                ;;
        default )               source /usr/share/fastpanel2/bin/mysql/install-default.sh
                                ;;
        * )                     Debug "MySQL functuion import failed" && InstallationFailed
                                ;;
    esac
    installMySQL || InstallationFailed
    Success
}

function InstallPanelRepository {
    Debug "Configuring FASTPANEL repository.\n"

    Debug "Adding repository key from https://repo.fastpanel.direct/."
    wget -q https://repo.fastpanel.direct/RPM-GPG-KEY-fastpanel -O /etc/apt/trusted.gpg.d/RPM-GPG-KEY-fastpanel.asc  || InstallationFailed

    Debug "Adding repository file /etc/apt/sources.list.d/fastpanel2.list"
    echo "deb [arch=${ARCH}] http://repo.fastpanel.direct ${OS} main" > /etc/apt/sources.list.d/fastpanel2.list
}

function CheckVersionOS {
    source /etc/os-release
    case ${ID} in
        debian )    export FAMILY='debian'
                    case ${VERSION_ID} in
                        9 )             export OS='stretch'
                                        export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.4|mariadb10.5|percona5.7|percona8.0'
                                        export MYSQL_VERSION='percona5.7'
                                        ;;
                        10 )            export OS='buster'
                                        export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.4|mariadb10.5|mariadb10.6|mariadb10.11|mysql5.7|mysql8.0|percona5.7|percona8.0'
                                        export MYSQL_VERSION='mysql5.7'
                                        ;;
                        11 )            export OS='bullseye'
                                        export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.5|mariadb10.6|mariadb10.11|mysql8.0|percona8.0'
                                        export MYSQL_VERSION='mysql8.0'
                                        ;;
                        12 )            export OS='bookworm'
                                        export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.11|mysql8.0'
                                        export MYSQL_VERSION='mysql8.0'
                                        ;;
                        * )             Error 'Unsupported Debian version.'
                                        ;;
                    esac
                    ;;
        ubuntu )    export FAMILY='ubuntu'
                    case ${VERSION_ID} in
                        24.04 )         export OS='noble'
                                        case ${ARCH} in
                                            amd64 )
                                                export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.11|mysql8.0|percona8.0'
                                                ;;
                                            arm64 )
                                                export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.11|percona8.0'
                                                ;;
                                        esac
                                        export MYSQL_VERSION='default'
                                        # fix for the old Ubuntu images
                                        echo 'libssl1.1 libraries/restart-without-asking boolean true' |  debconf-set-selections
                                        ;;
                        22.04 )         export OS='jammy'
                                        case ${ARCH} in
                                            amd64 )
                                                export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.6|mariadb10.11|mysql8.0|percona8.0'
                                                ;;
                                            arm64 )
                                                export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.6|mariadb10.11|percona8.0'
                                                ;;
                                        esac
                                        export MYSQL_VERSION='default'
                                        # fix for the old Ubuntu images
                                        echo 'libssl1.1 libraries/restart-without-asking boolean true' |  debconf-set-selections
                                        ;;
                        20.04 )         export OS='focal'
                                        case ${ARCH} in
                                            amd64 )
                                                export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.5|mariadb10.6|mariadb10.11|mysql8.0|percona8.0'
                                                ;;
                                            arm64 )
                                                export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.5|mariadb10.6|mariadb10.11|percona8.0'
                                                ;;
                                        esac
                                        export MYSQL_VERSION='default'
                                        # fix for the old Ubuntu images
                                        echo 'libssl1.1 libraries/restart-without-asking boolean true' |  debconf-set-selections
                                        ;;
                        18.04 )         export OS='bionic'
                                        export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.5|mariadb10.6|mariadb10.11|mysql5.7|mysql8.0|percona5.7|percona8.0'
                                        export MYSQL_VERSION='mysql5.7'
                                        # fix for the old Ubuntu images
                                        echo 'libssl1.1 libraries/restart-without-asking boolean true' |  debconf-set-selections
                                        ;;
                        * )             Error 'Unsupported Ubuntu version.'
                                        ;;
                    esac
                    ;;
        * )         Error 'Unsupported OS version.'
                    ;;
    esac
}

function CheckSystemd {
    Debug "Checking init daemon.\n"
    case `dpkg --get-selections |grep -E "systemd-sysv\s+install" -c` in
        0 )     Error "OS ${OS} without systemd doesn't supported.\nPlease install the 'systemd-sysv' package."
                ;;
        1 )     Debug "Package 'systemd-sysv' is installed."
                ;;
    esac
}

function CheckOpensshServer {
    Debug "Checking that the sshd is installed.\n"
    case `dpkg --get-selections |grep -E "openssh-server\s+install" -c` in
        0 )     Error "OS ${OS} without openssh-server doesn't supported.\nPlease install the 'openssh-server' package."
                ;;
        1 )     Debug "Package 'openssh-server' is installed."
                ;;
    esac
}

function CheckArch {
    system_arch=$(uname -m)
    case ${system_arch} in
        x86_64)
            export SYS_ARCH='x86_64'
            export ARCH='amd64'
            ;;
        aarch64)
            export SYS_ARCH='aarch64'
            export ARCH='arm64'
            ;;
        *)
            Debug "Unknown architecture: ${system_arch}"
            InstallationFailed
            ;;
    esac
}

function CheckGnupgPackage {
    case `dpkg --get-selections |grep -E "gnupg2?\s+install" -c` in
        0 )     Debug "Package 'gnupg' not installed."
                UpdateSoftwareList
                apt-get install -y gnupg
                ;;
        * )     Debug "The package 'gnupg' is installed"
                ;;
    esac
}

function CheckServerConfiguration {
    export INSTALLED_SOFTWARE=''
    Message "Start pre-installation checks\n"
    Message "OS:\t" && Info "${PRETTY_NAME}\n\n"
    CheckSystemd
    # CheckOpensshServer
    CheckPreinstalledPackages
    if [ "${INSTALLED_SOFTWARE[@]}" != '' ] && [ "${force}" != '1' ]; then
        Message "The following software have been found installed: ${INSTALLED_SOFTWARE}.\n"
        Warning "\nThe Control Panel can only be installed on a fresh OS installation.\nYou can use the -f flag to ignore the installed software.\n"
        exit 1
    fi
    CheckGnupgPackage
}

function ShowLogo {
cat << "EOF" >&3
        _________   _______________  ___    _   __________ 
       / ____/   | / ___/_  __/ __ \/   |  / | / / ____/ / 
      / /_  / /| | \__ \ / / / /_/ / /| | /  |/ / __/ / /  
     / __/ / ___ |___/ // / / ____/ ___ |/ /|  / /___/ /___
    /_/   /_/  |_/____//_/ /_/   /_/  |_/_/ |_/_____/_____/

EOF
}

function Clean {
    apt-get clean
    # Closing file descriptor for debug log
    exec 3>&-
}

function InstallFastpanel {
    Message "Installing FASTPANEL package.\n"

    InstallPanelRepository
    UpdateSoftwareList

    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

    apt-get install -qq -y fastpanel2 || InstallationFailed
    Success
}

function FinishInstallation {
    PASSWORD=`generatePassword 16` || InstallationFailed
    mogwai chpasswd -u fastuser -p $PASSWORD >/dev/null 2>&1
    export IP=`ip -o -4 address show scope global | tr '/' ' ' | awk '$3~/^inet/ && $2~/^(eth|veth|venet|ens|eno|enp)[0-9]+$|^enp[0-9]+s[0-9a-z]+$/ {print $4}'|head -1`
    echo ""
    Message "\nCongratulations! FASTPANEL successfully installed and available now for you at https://$IP:8888/ .\n"
    Message "Login: fastuser\n"
    Message "Password: $PASSWORD\n"
}

function InstallServices {
    if [ -z ${minimal} ]; then
        InstallMySQLService
        source /usr/share/fastpanel2/bin/install-web.sh
        InstallWebService
        source /usr/share/fastpanel2/bin/install-ftp.sh
        InstallFtpService
        source /usr/share/fastpanel2/bin/install-mail.sh
        InstallMailService
        source /usr/share/fastpanel2/bin/install-recommended.sh
        InstallRecommended
    else
        Debug "Choosen minimal installation."
    fi
}

function Run {
    SetLogFile
    ParseParameters $@
    Greeting
    CheckServerConfiguration
    InstallFastpanel
    InstallServices
    FinishInstallation
    Clean
}


Run $@
