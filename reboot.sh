#!/bin/bash
# Reboot Checker
#
# About: Information gathering script to document certain pieces of information about a server
# and to see if it is safe for rebooting.
#
# Authors: Sean B, Steve R, and some yet to be identified person who wrote a similar script for rs-automations whom I borrowed pieces from.
# Usage: bash <(curl -sS https://raw.githubusercontent.com/Tesin/Reboot-Checker/master/reboot.sh)


# Declare color codes for use
red='\033[0;31m'
blue='\033[0;34m'
green='\033[0;32m'
nc='\033[0m'

printf "${blue}"
printf "\n\n========================================\n"
printf "=    ${nc}EVT - RHEL Upgrade Pre-Flight${blue}     =\n"
printf "========================================\n\n\n"

printf "Please make sure to check the known-limitations of Leapp Upgrade Tool:${nc}\n"
printf "${green}"
printf 'https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/upgrading_from_rhel_7_to_rhel_8/planning-an-upgrade_upgrading-from-rhel-7-to-rhel-8'
printf "${nc}"
printf "\n\n\n"


# Check to see if this is being run as root
printf "${blue}Check to see if running as root...${nc}\n"
if [ ! "$(whoami | grep "^root$")" ] ; then
  printf "${red}[ERROR]!... You must run this script as root!\n\n${nc}"
  exit
else
  printf ${green}"\u2714${nc}\n" # Green check mark
  printf "\n\n"
fi


# General Info
printf "${blue}Contents of /etc/redhat-release :${nc} \n"
printf "${green}"
cat /etc/redhat-release
printf "\n\n"
printf "${nc}"

printf "${blue}UNAME Info:\n${nc}"
printf "${green}"
uname -a
printf "\n\n"
printf "${nc}"

printf "${blue}Verify upgrade path...${nc}\n"
printf "${green}"
printf "<<PLACEHOLDER>>\n"
printf "\n\n"
printf "${nc}"
# Ensure source OS is 7.9 or 7.6 depending on ARCH

printf "${blue}Is RHEL running in FIPS mode?${nc}\n"
printf "${green}"
printf "<<PLACEHOLDER>>\n"
printf "\n\n"
printf "${nc}"
# Check if FIPS. Apparently this is a hard-stop and Red Hat recommends a new FIPS install versus in-place upgrade.

# Check for services that are running but not chkconfig'd on. This section checks the exit code from the service command where chkconfig reports runlevel 3 as off.
# An exit code of 0 means that it is running.
# If more services need to be added to servicefilter, bring it up please.
printf "${blue}The following services are running but not configured to start on boot:${nc}\n"

servicefilter='ipmi|rhnsd|anacron|rdisc|cpuspeed|dsm_om_connsv'

for service in $(chkconfig --list | grep 3:off | awk '{print $1}' | egrep -vi $servicefilter); do
  service $service status > /dev/null
  exitcode=$?

  if [ $exitcode -eq 0 ] ; then
    printf "$service\n"
  fi
done
printf "\n\n"


# Check for services that are chkconfig'd on but not running. This section checks the exit code from the service command where chkconfig reports runlevel 3 as on.
# The meaning and output as a result of non-zero status codes are dictated by the service's init script and is not standardized. Thus, for any non-zero status code,
# the exact output from the service command is passed through to stdout.
printf "${blue}The following services are set to start on boot but not currently running:${nc}\n"

for service in $(chkconfig --list | grep 3:on | awk '{print $1}' | egrep -vi $servicefilter); do
  service $service status > /dev/null
  exitcode=$?

  if [ $exitcode -ne 0 ] ; then
    printf "$service -- "
    service $service status
    echo
  fi
done
printf "\n\n"


# Check filesystems for possibility of fsck. As of right now this only checks for xfs and nvm strings in mount output.
printf "${blue}Check filesystems for possibility of fsck\n${nc}"
for filesystem in $(mount | egrep -i 'xfs|nvm' | awk '{print $1}'); do
  printf "${blue}$filesystem\n${nc}"
  tune2fs -l $filesystem | egrep -i 'mount count|maximum mount count|last checked|check interval'
  printf "\n\n"
done


# Check for any NFS exports
printf "${blue}Check for NFS exports\n${nc}"
nfsexports=$(showmount -e 2>/dev/null | egrep -vi 'Export list')
if [ "$nfsexports" ] ; then
  echo $nfsexports
else
  printf "${green}None found${nc}\n"
fi
printf "\n\n"


# Check for NFS mounts
printf "${blue}Check for NFS mounts${nc}\n"
fsfilter='sunrpc|nfsd|usbfs|/proc|sysfs|/dev/pts|tmpfs'
nfslist=$(mount | egrep -vi $fsfilter | egrep -i nfs)
if [ "$nfslist" ] ; then
  echo $nfslist
else
printf "${green}None found${nc}\n"
fi
printf "\n\n"


# Check for services listening on a specific IP
ipfilter='127.0.0.1|0.0.0.0'
printf "${blue}The following services are listening on specific IP's\n${nc}"
netstat -plnt | awk --re-interval '$4 ~ /[0-9]{1,3}(\.[0-9]{1,3}){2}\:.*/ {print $4,$7}' | egrep -vi $ipfilter
printf "\n\n"


# Check for RHCS cluster
printf "${blue}Check for RHCS clustering${nc}\n"
if [ -f /etc/cluster/cluster.conf ] ; then
  printf "${red}The file /etc/cluster/cluster.conf exists. This may be a node in an RHCS cluster.${nc}"
else
  printf "${green}The file /etc/cluster/cluster.conf not found.${nc}\n"
fi

clustat > /dev/null 2>&1
clusexit=$?
if [ $clusexit -eq 0 ] ; then
  clustat
else
  printf "${green}Clustat command not found${nc}.\n"
fi
printf "\n\n"


# Check for Managed Storage
# Our maintenance playbooks rely on: multipath -ll; powermt display; df -h; fdisk -cul;
printf "${blue}Check for Managed Storage${nc}\n"
if [ "$(ls /dev/emc* 2>/dev/null)" ] ; then
  printf "This server appears to have SAN attached.\n"
  ll /dev/emc* 2>/dev/null
else
  printf "${green}SAN not found${nc}\n"
fi

if [ "$(grep mpp /proc/modules)" ] && [ ! "$(ls /dev/cme* 2>/dev/null)" ] ; then
  printf "${red}This server appears to have DAS attached.${nc}\n"
else
  printf "${green}DAS not found${nc}\n"
fi
