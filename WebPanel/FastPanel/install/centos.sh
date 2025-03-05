#!/bin/bash

export SYSTEMD_PAGER=''
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

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

    if [ -z ${MYSQL_VERSION} ]; then
        export MYSQL_VERSION='mariadb10.6'
    fi
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

function CheckPackageInstall {
    yum -q list installed |grep -cE "$1\..+\s"
    #yum -q list installed $1 >/dev/null 2>&1
    #echo $?
}

function CheckPreinstalledPackages {
    case `CheckPackageInstall fastpanel2` in
        0 )     Debug "Package 'fastpanel2' not installed."
                ;;
        1 )     Error "FASTPANEL package have already been installed on the server. Exiting.\n"
                ;;
    esac

    case `CheckPackageInstall bitrix-env` in
        0 )     Debug "Package 'bitrix-env' not installed."
                ;;
        1 )     Error "\nThe Control Panel can only be installed on a fresh OS installation.\nUnfortunately with the preinstalled bitrix-env installing is not possible."
                ;;
    esac

    # case `CheckPackageInstall openssh-server` in
    #     0 )     Error "${FAMILY} ${OS} without openssh-server doesn't supported.\nPlease install the 'openssh-server' package."
    #             ;;
    #     1 )     Debug "Package 'openssh-server' is installed."
    #             ;;
    # esac

    local PACKAGES="nginx httpd"
    for package in ${PACKAGES}; do
        case `CheckPackageInstall ${package}` in
            0 )     Debug "Package '${package}' not installed."
                    ;;
            * )     INSTALLED_SOFTWARE+=("${package}")
                    ;;
        esac
    done

    for package in mysql-server mariadb-server MariaDB-server percona-server-server mysql-community-server percona-server-server-5.6 percona-server-server-5.7; do
        case `CheckPackageInstall ${package}` in
            0 )     Debug "Package '${package}' not installed."
                    ;;
            * )     Error "\nThe Control Panel can only be installed on a fresh OS installation.\nUnfortunately with the preinstalled MySQL installing is not possible."
                    ;;
        esac
    done
}

function CheckServerConfiguration {
    if [ -f /usr/sbin/getenforce ] && [ `/usr/sbin/getenforce` = 'Enforcing' ]; then
        Error "Unfortunately FASTPANEL can't work with SELinux.\nPlease disable SELinux.\n"
    fi
    # export INSTALLED_SOFTWARE=''
    Message "Start pre-installation checks\n"
    Message "OS:\t" && Info "${PRETTY_NAME}\n\n"
    CheckPreinstalledPackages
    if [ "${#INSTALLED_SOFTWARE[@]}" != '0' ] && [ "${force}" != '1' ]; then
        local PACKAGES="${INSTALLED_SOFTWARE[@]}"
        Message "The following software have been found installed: ${PACKAGES}.\n"
        Warning "\nThe Control Panel can only be installed on a fresh OS installation.\nYou can use the -f flag to ignore the installed software.\n"
        exit 1
    fi
    PrepareInstallationPanel
}

function InstallationFailed {
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
    yum makecache || InstallationFailed
}

function InstallMySQLService {
    #UpdateSoftwareList
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
    esac || InstallationFailed
    installMySQL || InstallationFailed
    Success
}

function InstallPanelRepository {
    Debug "Configuring FASTPANEL repository.\n"
    wget https://repo.fastpanel.direct/RPM-GPG-KEY-fastpanel -O /etc/pki/rpm-gpg/RPM-GPG-KEY-fastpanel
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fastpanel
    echo -e "[fastpanel]\nname=FASTPANEL\nbaseurl=http://repo.fastpanel.direct/${FAMILY}/${OS}/x86_64/\nenabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fastpanel\n" > /etc/yum.repos.d/fastpanel.repo
    yum makecache
}

function PrepareInstallationPanel {
    #Message "Installing all the Programs Required for the Control Panel Installation Process.\n"
    #UpdateSoftwareList
    yum remove -y firewalld || InstallationFailed
    yum install --setopt=skip_missing_names_on_install=False -qq -y epel-release.noarch || InstallationFailed
    yum install --setopt=skip_missing_names_on_install=False -qq -y dialog pwgen || InstallationFailed
    #Success

    #Debug 'Reset iptables rules'
    #iptables -P INPUT ACCEPT || InstallationFailed
    #iptables -P FORWARD ACCEPT || InstallationFailed
    #iptables -P OUTPUT ACCEPT || InstallationFailed
    #iptables -F || InstallationFailed
    #iptables -X || InstallationFailed

    #Debug 'Reset ip6tables rules'
    #ip6tables -P INPUT ACCEPT || InstallationFailed
    #p6tables -P FORWARD ACCEPT || InstallationFailed
    #ip6tables -P OUTPUT ACCEPT || InstallationFailed
    #ip6tables -F || InstallationFailed
    #p6tables -X || InstallationFailed

    #mkdir -p /etc/iptables/
    #iptables-save > /etc/iptables/rules.v4
    #p6tables-save > /etc/iptables/rules.v6
}

function CheckVersionOS {
    source /etc/os-release

    case ${ID} in
        centos )    export FAMILY='centos'
                    case ${VERSION_ID} in
                        7 )         export OS='7'
                                    export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.4|mariadb10.5|mariadb10.6|mariadb10.11|mysql5.7|mysql8.0|percona8.0'
                                    ;;
                        * )         Error 'Unsupported OS version.'
                                    ;;
                    esac
                    ;;
        almalinux ) export FAMILY='almalinux'
                    case ${VERSION_ID} in
                        8.* )       export OS='8'
                                    export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.4|mariadb10.5|mariadb10.6|mariadb10.11|mysql8.0|percona8.0'
                                    ;;
                        * )         Error 'Unsupported OS version.'
                                    ;;
                    esac
                    ;;
        rocky )     export FAMILY='rocky'
                    case ${VERSION_ID} in
                        8.* )       export OS='8'
                                    export AVAILABLE_MYSQL_VERSIONS='default|mariadb10.4|mariadb10.5|mariadb10.6|mariadb10.11|mysql8.0|percona8.0'
                                    ;;
                        * )         Error 'Unsupported OS version.'
                                    ;;
                    esac
                    ;;
        * )         Error 'Unsupported OS version.'
                    ;;
    esac
}

function CheckArch {
    if [ `arch` = "x86_64" ]; then
        Debug "Architecture x86_64."
    else
        Debug "FASTPANEL supports only x86_64 Architecture."
        InstallationFailed
    fi
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
    # Closing file descriptor for debug log
    exec 3>&-
}

function InstallFastpanel {
    Message "Installing FASTPANEL package.\n"

    InstallPanelRepository

    yum install --setopt=skip_missing_names_on_install=False -y fastpanel2 || InstallationFailed
    Success
}

function FinishInstallation {
    PASSWORD=`generatePassword 16` || InstallationFailed
    /usr/local/fastpanel2/fastpanel chpasswd -u fastuser -p $PASSWORD >/dev/null 2>&1
    export IP=`ip -o -4 address show scope global | tr '/' ' ' | awk '$3~/^inet/ && $2~/^(eth|veth|venet|ens|eno)[0-9]+$|^enp[0-9]+s[0-9a-z]+$/ {print $4}'|head -1`
    echo ""
    Message "\nCongratulations! FASTPANEL has been successfully installed and available for you at https://$IP:8888/ .\n"
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
