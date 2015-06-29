#!/bin/bash

# Prepares your system to run phpStartPoint
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
elif [ -f /etc/debian_version ]; then
platform='debian'
elif [ -f /etc/SUSE-brand ]; then
platform='suse'
fi

spacer="---------------------------------------------------------------"
installPromt="Would you like me to install it now? Y/n:"
echo $spacer
echo "Setting up phpStartPoint to create PHP classes and web interfaces ... "
echo $spacer
echo "Checking your OS and environment"
echo OS is $platform based

if [[ $platform == 'suse' ]]; then

	echo $spacer
	echo "Install any missing stuff? Y/n:"	
	read -s -n 1 ans
	if [ "$ans" = "" ]; then 
		ans=y
	fi 	
	if [ "$ans" = "y" ]; then 
				
		zypper install mariadb
		systemctl start mariadb
		systemctl enable mariadb
		aptitude -y install php5 php5-mysql apache2 apache2-mod_php5 perl-DBI perl-Term-ReadKey perl-DBD-mysql
		rcmysql start
		rcapache2 start
	fi				    
fi


if [[ $platform == 'debian' ]]; then

	if which php < /dev/null > /dev/null 2>&1  ; then
		echo "PHP is installed"
	else
		echo $spacer
		echo "PHP does not appear to be installed"	
		echo $installPromt	
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
		echo "MySQL server does not appear to be installed"
		echo $installPromt
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
		echo "Apache2 does not appear to be installed"
		echo $installPromt
		read -s -n 1 ans
		if [ "$ans" = "" ]; then 
			ans=y
		fi 	
	
	    if [ "$ans" = "y" ]; then 
				    
			if [ "$(id -u)" != "0" ]; then
			   echo "This script must be run as root" 1>&2
			   exit 1
			fi
			apt-get -y install apache2 libapache2-mod-php5
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


	echo $spacer
	echo "Install any missing stuff? Y/n:"	
	read -s -n 1 ans
	if [ "$ans" = "" ]; then 
		ans=y
	fi 	
	if [ "$ans" = "y" ]; then 	
		if [ "$(id -u)" != "0" ]; then
		   echo "This script must be run as root" 1>&2
		   exit 1
		fi
		
		yum install httpd perl-DBI perl-TermReadKey perl-DBD-mysql mariadb-server php php-mysql
		service httpd start
		systemctl start mariadb
		systemctl enable mariadb
		
		chkconfig httpd on
		chkconfig mysqld on
		service httpd restart
	fi
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
	wget -N https://raw.githubusercontent.com/athenasystems/phpstartpoint/master/phpStartPoint.pl
	chmod 755 phpStartPoint.pl
	perl ./phpStartPoint.pl
else
	echo "Quiting"
fi

exit 1
