#!/bin/bash

# Installs phpStartPoint
clear

platform='unknown'

if [ -f /etc/redhat-release ]; then
platform='redhat'
fi

if [ -f /etc/debian_version ]; then
platform='debian'
fi


unamestr=`uname`
regex='BSD'
if [[ "$unamestr" =~ 'FreeBSD' ]]; then
   platform='freebsd'
fi

if [[ $platform == 'freebsd' ]]; then
  echo "Platform is: freebsd"  
fi


spacer="---------------------------------------------------------------"
echo $spacer
echo "Setting up phpStartPoint to create PHP classes and web interfaces ... "
echo $spacer

if [[ $platform == 'debian' ]]; then

	if perl -e 'use DBI;' < /dev/null > /dev/null 2>&1  ; then
		echo Yes we have perl DBI module
	else
		req1 = n	 
	fi
	
	if perl -e 'use Term::ReadKey;' < /dev/null > /dev/null 2>&1  ; then
		echo Yes we have perl Term::ReadKey module
	else
		req2 = n
	fi
	
	if [[ $req1 == 'n' ]] || [[ $req2 == 'n'  ]]
		echo Dang! ... need some perl modules installed
		echo Shall I install them now? Y/n
		read -n 1 ans
		if [ "$ans" = "y" ]; then 
			apt-get -y install libterm-readkey-perl libdbi-perl
		fi 
	fi
	
	
	

	if [ -f /usr/sbin/apache2 ]
	then echo "Apache2 is installed"
	else
		echo "Apache2 does not appear to be installed. Would you like to install it now? y/n:"	
		read -n 1 ans
	
	    if [ "$ans" = "y" ]; then 
				    
			if [ "$(id -u)" != "0" ]; then
			   echo "This script must be run as root" 1>&2
			   exit 1
			fi
			apt-get -y install libterm-readkey-perl libdbi-perl apache2 mysql-server php5 libapache2-mod-php5  libapache2-mod-auth-mysql expect libcrypt-ssleay-perl libexpect-perl php5-mysqlnd
		else
		echo "Ok ... skipping"
		fi
	fi
fi

if [[ $platform == 'redhat' ]]; then

	if [ "$(id -u)" != "0" ]; then
	   echo "This script must be run as root" 1>&2
	   exit 1
	fi
	
	yum install httpd
	service httpd start
	yum install mysql mysql-server
	service mysqld start
	yum install php php-mysql
	chkconfig httpd on
	chkconfig mysqld on
	service httpd restart
fi


echo $spacer
echo -n "OK, going to grab the setup script from the web"
echo " and continue the installation... "
echo "That cool? y/n:"
echo $spacer

read -n 1 resp

if [ "$resp" = "y" ]; then
	wget http://sc21.co/phpStartPoint
	chmod 755 phpStartPoint
	perl ./phpStartPoint
else
	echo "Quiting"
fi

exit 1
