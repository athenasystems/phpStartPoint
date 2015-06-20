# phpStartPoint
phpStartPoint is a perl script that creates php classes code from a MySQL database, designed for a Linux system, but could easily be modified for Windows. The idea is that when starting a project you can start by building the database, and then next run this script which will produce PHP Classes and php web pages that can be used to control the data in the database.

# TL;DR verison

wget -N http://athenace.co.uk/psp.sh && bash psp.sh


# Building Classes
This script will examine a MySQL database, and create object oriented php classes and php code for the web pages. It will create as many classes as there are tables, and provide an interface to load data into the object from the DB, update a DB record, insert a record into the DB, a delete a row from the DB.

# To set up a development environment

Run this command in a terminal :-

**wget -N http://athenace.co.uk/psp.sh && bash psp.sh**

The script will check your OS and environment for required software. If you want to run the pages in a browser you will need a LAMP server, e.g. Linux, Apache, MySQL and PHP and a few extra programs (php5-mysql apache2-mod_php5 perl-DBD-mysql). The script will make attempts to install and setup a development enviroment for you.

The script will create a folders 'etc', 'inc', 'lib' and 'www'.

In 'lib' it will write seperate class files for each table, as well as DB.php which is the interface to the DB. It will also create a file Classes.php which will contain all the classes in one file.  
In 'www' it will write the php pages intended as a starting point for your development.  
In 'etc' it will create a config file with your databases name, user and pass for the DB Class to use. This way it keeps it out of your code. If you chown yourusername:www-data and chmod 660, it will protect it from being read by normal users, but still be accesible by you and the Apache2 user.  
In 'inc' it will write the header and footer for the php pages.  


# Just running the phpStartPoint script

You can just run the **phpStartPoint.pl** script in this package. You will need Perl, with the perl DBI, and Term::ReadKey modules i.e. perl-DBI perl-Term-ReadKey on debian based OS, or perl-DBI perl-TermReadKey on a RedHat based distro.


# Bind parameters
The script queries the MySQL database table e.g. 'select data_type from information_schema.columns', and determines the relevant data type, and the script creates a php function that will automatically work out the bind_params format to pass to the function.

# PHP pages
The script creates a series of php pages intended to be the basis for a web site that controls the data in the MySQL database. For each table four pages are created:

	1. A page to list the entries in the table
	2. A page to add a row
	3. A page to edit an existing row
	4. A page to delete a row

# Redundent Classes and Pages
It is unlikely all the php code that is produced will be needed, but the idea is that it gives a developer a good starting point to start developing further.

# The DB.php Class
I totally stole this from John Morris at http://www.johnmorrisonline.com/simple-php-class-prepared-statements-mysqli. All credit to John for this. I have made a few alterations. Check out John's great tutorials for further details.

The format variable has been converted into a string rather than an array  
The delete function is now passed 3 parameters to allow for index columns not named 'ID'  
The '%' was taken off the format strings  
The connection to the DB is now done in the __construct, as suggested by John, and it uses an external file to read in credentials  


