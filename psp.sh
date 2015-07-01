#!/bin/bash
# Prepares your system to run phpStartPoint
clear
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root if you want toinstall the "
	echo "required Perl Modules or set up the Apache Web Server"
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
		aptitude -y install php5 php5-mysqlnd apache2 apache2-mod_php5 perl-DBI perl-Term-ReadKey perl-DBD-mysql
		rcmysql start
		rcapache2 start
	fi				    
fi

if [[ $platform == 'debian' ]]; then
	echo $spacer
	echo "Install any missing LAMP software?"
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
		apt-get -y install apache2 php5 mysql-server php5-mysqlnd libapache2-mod-php5 libdbi-perl libterm-readkey-perl
	else
	echo "Ok ... skipping"
	fi
fi

if [[ $platform == 'redhat' ]]; then
	echo $spacer
	echo "Install any missing LAMP software? Y/n:"	
	read -s -n 1 ans
	if [ "$ans" = "" ]; then 
		ans=y
	fi 	
	if [ "$ans" = "y" ]; then 	
		if [ "$(id -u)" != "0" ]; then
		   echo "This script must be run as root" 1>&2
		   exit 1
		fi
		
		yum install httpd mariadb-server php php-mysqlnd perl-DBI perl-TermReadKey perl-DBD-mysql
		service httpd start
		systemctl start mariadb
		systemctl enable mariadb		
		chkconfig httpd on
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
