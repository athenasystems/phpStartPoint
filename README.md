# tl;dr version
Have Linux. In a terminal as root do ... 

`wget -N https://raw.githubusercontent.com/athenasystems/phpstartpoint/master/psp.sh && bash psp.sh`

It builds all the classes (in /lib)  
And makes all the web pages (in /www)

# phpStartPoint
phpStartPoint is a tool to help programmers start to develop PHP code for a database driven web application. The idea is that you build a database, and then you run this script which will produce PHP Class code, and php web pages that can be used to control the data in the database. What gets output is a starting point, and not all of the code will be useful or probably needed. 

The psp.sh script also optionally sets up Apache2, MySQL, and php5, and adds the neccesary software and configuration to get a working development set up on the developers machine, or a server. There is a sample database to serve as an example for the curious.

It aim is to take the work out of setting up a web app system on a LAMP server, and leave the developer with a starting point to code on from. It also aims to not tie the developers hands in any way, and encourages understanding the lowest level of code. Some frameworks promise to allow you to do code without knowing the code, which arguably disempowers new coders.

# Usage
To simply run phpStartPoint on your database run  
`perl ./phpStartPoint.pl`

To run phpStartPoint on your database and setup an Apache Virtual Host for the files created run  
`perl ./phpStartPoint.pl www`

To run phpStartPoint and setup an Apache Virtual Host for the files created, and import the example database run  
`perl ./phpStartPoint.pl example`


# Building Classes
This script will examine a MySQL database, and create object oriented PHP classes and PHP code for the web pages. It will create as many classes as there are tables, and create web pages to add a new item, update a row, or delete a row from the database.

# Binding Parameters to SQL statements
The script queries the MySQL database table e.g. 'select data_type from information_schema.columns', and determines the relevant data type, and creates a php function that will automatically work out the bind_params format to pass to the function. This means you get nice clean functions, and it simplifies the coding later on.

# It's Vanilla Flavoured
You get a blank slate. The web pages have a very basic Bootstrap CSS setup and almost no design whatsoever. This is deliberate in order that you can apply whatever styling you wish.

# PHP pages
The script creates a series of php pages intended to be the basis for a web site that controls the data in the MySQL database. For each table four pages are created:

	1. A page to list the entries in the table
	2. A page to add a row
	3. A page to edit an existing row
	4. A page to delete a row

# Redundent Classes and Pages
It is unlikely all the php code that is produced will be needed, but the idea is that it gives a developer a good starting point to start developing further.

# Just running the phpStartPoint script
You can just run the **phpStartPoint.pl** script in this package. You will need Perl, with the perl DBI, and Term::ReadKey modules i.e. perl-DBI perl-Term-ReadKey on debian based OS, or perl-DBI perl-TermReadKey on a RedHat based distro.
