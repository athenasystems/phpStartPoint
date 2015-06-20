# To set up a development environment

Run this command in a terminal :-

wget -N http://athenace.co.uk/psp.sh && sudo bash psp.sh

The Bash script will check your OS and environment for required software. If you want to run the pages in a browser you will need a LAMP server, e.g. Linux, Apache, MySQL and PHP and a few extra programs (php5-mysql apache2-mod_php5 perl-DBD-mysql). 

The script will make attempts to install and setup a development enviroment for you.

The psp.sh script will then download the phpStartPoint perl script (from http://athenace.co.uk/phpStartPoint). It sets permissions (chmod 755), and runs it (perl ./phpStartPoint).

# Example Database
I have included a very simple example database if you want to see the script before you try it on your own Database. When the script runs it will ask you if you want to try it.

If you are running the script to analyse your own database, you will be asked for the details of your database, user pass etc.

# Apache2 Virtual Host
You will be asked if you want to set up the web server on your development computer, and if so, it will create a .conf file and add it to the sites on your web server. It will also add entries in your /etc/hosts file to point (via 127.0.0.1) to the development version domain, as specified at Install.

# Output Files
The script will create folders 'etc', 'inc', 'lib' and 'www' in the location you chose at install.

In 'lib' it will write seperate class files for each table, as well as DB.php which is the interface to the DB. It will also create a file Classes.php which will contain all the classes in one file.  
In 'www' it will write the php pages intended as a starting point for your development.  
In 'etc' it will create a config file with your databases name, user and pass for the DB Class to use. This way it keeps it out of your code. If you chown yourusername:www-data and chmod 660, it will protect it from being read by normal users, but still be accesible by you and the Apache2 user.  
In 'inc' it will write the header and footer for the php pages.  

# The DB.php Class
I totally stole this from John Morris at http://www.johnmorrisonline.com/simple-php-class-prepared-statements-mysqli. All credit to John for this. I have made a few alterations. Check out John's great tutorials for further details.
I have changed ...  
The format variable has been converted into a string rather than an array  
The delete function is now passed 3 parameters to allow for index columns not named 'ID'  
The '%' was taken off the format strings  
The connection to the DB is now done in the __construct, as suggested somewhere by John Morris, and it uses an external file to read in credentials  


