#!/bin/bash

# Installs phpStartPoint
clear
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root if you want to"
	echo "install Perl Modules or set up the Apache Web Server"
	echo "OK to continue Y/n"
	read -s -n 1 ans
	if [ "$ans" = "" ]; then 
		ans=y
	fi 
	if [ "$ans" != "y" ]; then 		
		echo "Quitting"
		exit 1
	fi 
fi
			
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


spacer="---------------------------------------------------------------\n"
echo $spacer
echo "Setting up phpStartPoint to create PHP classes and web interfaces ... "
echo $spacer
echo "Checking your OS and environment"
echo OS is $platform

if [[ $platform == 'debian' ]]; then

	if which php < /dev/null > /dev/null 2>&1  ; then
		echo "PHP is installed"
	else
		echo $spacer
		echo "PHP does not appear to be installed. Would you like to install it now? y/n:"	
		read -s -n 1 ans
		if [ "$ans" = "" ]; then 
			ans=y
		fi 	
	    if [ "$ans" = "y" ]; then 
				    
			if [ "$(id -u)" != "0" ]; then
			   echo "This script must be run as root" 1>&2
			   exit 1
			fi
			apt-get -y install php5
		else
		echo "Ok ... skipping"
		fi
	fi
	
	
	if which mysqld < /dev/null > /dev/null 2>&1  ; then
		echo "MySQL server is installed"
	else
		echo $spacer
		echo "MySQL server does not appear to be installed. Would you like to install it now? Y/n:"	
		read -s -n 1 ans
		if [ "$ans" = "" ]; then 
			ans=y
		fi 	
	
	    if [ "$ans" = "y" ]; then 
				    
			if [ "$(id -u)" != "0" ]; then
			   echo "This script must be run as root" 1>&2
			   exit 1
			fi
			apt-get -y install mysql-server php5-mysqlnd
		else
		echo "Ok ... skipping"
		fi
	fi
	
	

	if [ -f /usr/sbin/apache2 ]
	then echo "Apache2 is installed"
	else
		echo $spacer
		echo "Apache2 does not appear to be installed. Would you like to install it now? Y/n:"	
		read -s -n 1 ans
		if [ "$ans" = "" ]; then 
			ans=y
		fi 	
	
	    if [ "$ans" = "y" ]; then 
				    
			if [ "$(id -u)" != "0" ]; then
			   echo "This script must be run as root" 1>&2
			   exit 1
			fi
			apt-get -y install apache2 libapache2-mod-php5  libapache2-mod-auth-mysql
		else
		echo "Ok ... skipping"
		fi
	fi

	req1=''
	req2=''

	if perl -e 'use DBI;' < /dev/null > /dev/null 2>&1  ; then
		echo Perl DBI module installed
	else
		req1=libdbi-perl	 
	fi
	
	if perl -e 'use Term::ReadKey;' < /dev/null > /dev/null 2>&1  ; then
		echo Perl Term::ReadKey module installed
	else
		req2=libterm-readkey-perl
	fi
	
	if [[ $req1 != '' ]] || [[ $req2 != ''  ]] ; then
		echo $spacer
		echo Dang! ... need some perl modules installed i.e. $req1 $req2
		echo Shall I install them now? Y/n
		read -s -n 1 ans
		if [ "$ans" = "" ]; then 
			ans=y
		fi 
		if [ "$ans" = "y" ]; then
		    
			if [ "$(id -u)" != "0" ]; then
			   echo "This script must be run as root" 1>&2
			   exit 1
			fi
			apt-get -y install $req1 $req2
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
echo "OK, going to grab the phpStartPoint script"
echo "from the web and then run it ... That cool? Y/n: "
echo $spacer

read -s -n 1 resp
if [ "$resp" = "" ]; then
	resp=y
fi
if [ "$resp" = "y" ]; then
	wget -N http://sc21.co/phpStartPoint
	chmod 755 phpStartPoint
	perl ./phpStartPoint
else
	echo "Quiting"
fi

exit 1
