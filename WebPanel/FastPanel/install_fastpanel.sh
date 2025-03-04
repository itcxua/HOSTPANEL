#!/bin/bash

if [ -f /etc/os-release ]; then
    source /etc/os-release
else
    echo "Please check that the file /etc/os-release is exists."
    exit 1
fi

if [ `uname -m` = "aarch64" ]; then
    case ${ID} in
        ubuntu )    case ${VERSION_ID} in
                        20.04|22.04|24.04) ;;

                        *)                  echo "The ARM architecture is supported only for Ubuntu 20.04 and later versions"
                                            exit 1
                                            ;;
                    esac
                    ;;
        * )         echo "The ARM architecture is supported only for Ubuntu 20.04 and later versions"
                    exit 1
                    ;;
    esac
fi

case ${ID} in
    debian|ubuntu )     wget --quiet https://repo.fastpanel.direct/install/debian.sh -O /tmp/$$_install_fastpanel.sh
                        ;;
    centos|almalinux|rocky )            wget --quiet https://repo.fastpanel.direct/install/centos.sh -O /tmp/$$_install_fastpanel.sh 
                        ;;
    * )                 echo "Can\'t detect OS. Please check the /etc/os-release file.'"
                        exit 1
esac

bash /tmp/$$_install_fastpanel.sh $@
rm /tmp/$$_install_fastpanel.sh
