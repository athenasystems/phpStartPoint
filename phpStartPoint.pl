#!/usr/bin/perl
use strict;
###########################################################
# Edit this section to reflect your MySQL database details
my $db     = '';
my $dbpw   = '';
my $dbuser = '';
my $domain = '';
my $host   = 'localhost';
###########################################################
use DBI;
use Term::ReadKey;
my $dir      = '/srv';
my $user     = ( defined( $ENV{"SUDO_USER"} ) ) ? $ENV{"SUDO_USER"} : $ENV{"USER"};
my $platform = &getPlatform();

system("clear");
my $spacer = '------------------------------------------------------------------------------';
print "$spacer\n\nRunning ... phpStartPoint\n\n$spacer\n\n";
my $ans = '';

# Get folder
print "Where shall I put the 'phpstartpoint' folder for the php files?\n";
print "Default is /srv meaning the files will live in /srv/phpstartpoint\n($dir): ";
ReadMode 1;
$dir = <STDIN>;
chomp $dir;

if ( ( !defined($dir) ) || ( $dir eq '' ) ) {
	$dir = '/srv/phpstartpoint';
}
else {
	$dir .= '/phpstartpoint';
}
print "Installing to ... $dir\n";
if ( -e $dir ) {
	print "Warning: Everything in the existing $dir folder will be toast OK?\n(Y/n): ";
	ReadMode 4;
	my $confirm = '';
	while ( not defined( $confirm = ReadKey(-1) ) ) { }
	chomp $confirm;
	ReadMode 1;
	print "\n";
	if ( $confirm eq '' ) { $confirm = 'y'; }

	if ( $confirm eq 'n' ) {
		print "OK quitting ...\n";
		exit;
	}

}

if ( -e "$dir" ) {

	# Clearing any previously made scripts
	system("rm -rf $dir");
}

mkdir($dir);
mkdir( $dir . '/etc' );
mkdir( $dir . '/inc' );
mkdir( $dir . '/lib' );
mkdir( $dir . '/www' );
mkdir( $dir . '/www/css' );
system("chown -R $user:$user $dir");

# Import Example DB
print "Would you like to install the example database and run the script?\nY/n: ";
ReadMode 4;
while ( not defined( $ans = ReadKey(-1) ) ) { }
ReadMode 1;
chomp $ans;
if ( $ans eq '' ) { $ans = 'y'; }
print "\n\n";

if ( $ans eq 'y' ) {
	$db     = 'phpstartpoint';
	$dbpw   = 'PHPSPPWD';
	$dbuser = 'athena';
	$host   = 'localhost';

	# Get MySQL Root password
	print "Type in the MySQL Root Password: ";
	ReadMode 4;
	my $mysqlRootDbPwd = <STDIN>;
	ReadMode 1;
	chomp $mysqlRootDbPwd;
	print "\n";
	&makeDB($mysqlRootDbPwd);
}
else {
	if ( $db     eq '' ) { $db     = &getDBName(); }
	if ( $dbuser eq '' ) { $dbuser = &getDBUser(); }
	if ( $dbpw   eq '' ) { $dbpw   = &getDBPwd(); }
}

print "$spacer\n\n";

my $doApace = '';
&setupApache;

## SQL query to get Table names from DB
my $query   = "show tables";
my $dbh     = DBI->connect( "DBI:mysql:$db:$host", $dbuser, $dbpw );
my $sqltext = "show tables";
my $sth     = $dbh->prepare($sqltext);
$sth->execute();

# Generic footer for the PHP pages
my $htmlFoot = '
<?php
include "' . $dir . '/inc/footer.php";
?>
';

# Form HTML tag for the add, edit and delete pages
my $formTagStart = '<form role="form" action="<?php echo $_SERVER[\'PHP_SELF\']?>?go=y"
	enctype="multipart/form-data" method="post">';
my $formTagEnd = '<input type=submit value="Save Changes" class="btn btn-default btn-success">
</form>';
my $formEditTagStart = '<form role="form" action="<?php echo $_SERVER[\'PHP_SELF\']?>?go=y&amp;id=<?php echo $_GET[\'id\']; ?>"
	enctype="multipart/form-data" method="post">';

# PHP line to check for data to be processed on the add, edit and delete pages
my $goFuncStart = 'if ((isset($_GET[\'go\'])) && ($_GET[\'go\'] == "y")) {';
my $goFuncEnd   = '}';

my $credConf = "db=$db\ndbpw=$dbpw\ndbuser=$dbuser\nhost=$host";
open( FH, ">$dir/etc/db.conf" );
print FH $credConf;
close(FH);

# Strings to use for concatenation in the Table and Column loops
my $allPHPClasses = '';
my $phpOutTxtFull = '';
my $htmlIndex     = '';
my $outFormatsTxt = '';
my $navHTML       = '
<nav class="navbar navbar-inverse navbar-fixed-top">
	<div class="container-fluid">
		<div class="navbar-header">
			<button type="button" class="navbar-toggle collapsed"
				data-toggle="collapse" data-target="#navbar" aria-expanded="false"
				aria-controls="navbar">
				<span class="sr-only">Toggle navigation</span> <span
					class="icon-bar"></span> <span class="icon-bar"></span> <span
					class="icon-bar"></span>
			</button>
			<a class="navbar-brand" href="#">phpStartPoint</a>
		</div>
		<div id="navbar" class="navbar-collapse collapse">
			<ul class="nav navbar-nav">';

print "\n$spacer\nRunning phpStartPoint on the $db database...\n$spacer\n";

# Loop the Tables
while ( my @row_array = $sth->fetchrow_array ) {

	my $privateVariables = '';
	my $getsAndSets      = '';
	my $phpOutTxt        = '';
	my $phpEditOutTxt    = '';
	my $phpDeleteOutTxt  = '<h2>Please confirm you wish to delete this item</h2>';
	my $table            = $row_array[0];
	my $bindValues       = "\n\ \$" . $table . "Formats= array(\n";
	my $capTableName     = ucfirst($table);
	$navHTML .= <<EOF;
<li><a href="/$table">$capTableName</a></li> 
EOF

	my $classHeader = "
	
class $capTableName
{
";

	print "Processing the $table table ... ";

	# Make the folder for the PHP pages for this Table
	mkdir( $dir . '/www/' . $table );

	my $sqltext = "SELECT * FROM $table WHERE 1=0";
	my $sth     = $dbh->prepare($sqltext);
	$sth->execute();

	my @cols = @{ $sth->{NAME_lc} };

	my $indexCol    = $cols[0];
	my $capindexCol = ucfirst($indexCol);

	my $loadFromDB       = "";
	my $indexFeild       = '';
	my $indexCount       = 1;
	my $indexFeildType   = '';
	my $getAllTxt        = '';
	my $getAllFunction   = '';
	my $outAddFieldsTxt  = '';
	my $outEditFieldsTxt = '';

	foreach (@cols) {
		my $field    = $_;
		my $capField = ucfirst($field);
		if ($indexCount) {
			$indexFeild = $field;
			my $fType    = $field . 'Format';
			my $fTypeRef = \$fType;
			$indexFeildType = $$fTypeRef;

			$phpOutTxt       .= &mkHidden($field);
			$phpDeleteOutTxt .= &mkHidden($field);
			$phpEditOutTxt   .= &mkHidden($field);
			$indexCount = 0;
		}
		else {
			my $pt = &getPHPType( $table, $field );

			if ( $pt =~ /^(i|d|s|t)/ ) {
				$phpOutTxt     .= &mkTxt( $field, $field, '<?php echo $_POST[' . $field . '];?>' );
				$phpEditOutTxt .= &mkTxt( $field, $field, '<?php echo $' . $table . '->get' . $capField . '();?>' );
			}
			elsif ( $pt eq 'e' ) {
				$phpOutTxt     .= &mkSelectFromEnum( $db, $table, $field, $field, $field );
				$phpEditOutTxt .= &mkSelectFromEnum( $db, $table, $field, $field, $field );
			}
			$getAllTxt .= "		'$field'=>\$this->get$capField(),\n";

			$outAddFieldsTxt .= "\t" . '$' . $table . 'New->set' . $capField . '($_POST[\'' . $field . '\']);' . "\n";

		}

		$privateVariables .= 'private $' . $field . ";\n";

		my $t = &getType( $table, $field );

		#private static
		$bindValues .= "\"$field\" => \"$t\"," . "\n";

		$loadFromDB .= "\t\t" . '$this->set' . $capField . '($r->' . $field . ')' . ";\n";

		$getsAndSets .= '		
	public function set' . $capField . '($' . $field . ')
	{
		$this->' . $field . ' = $' . $field . ';
	}

	public function get' . $capField . '()
	{
		return $this->' . $field . ';
	}
';
		$outEditFieldsTxt .= "\t" . '$' . $table . 'Update->set' . $capField . '($_POST[\'' . $field . '\']);' . "\n";
	}

	my $htmlHead = '<?php	
include "' . $dir . '/lib/DB.php";
$db = new DB();
include "' . $dir . '/lib/' . $capTableName . '.php";
include "' . $dir . '/inc/header.php"; 
 

?>
';
	my $htmlAddHead = '<?php	
include "' . $dir . '/lib/DB.php";
$db = new DB();
include "' . $dir . '/lib/' . $capTableName . '.php"; 
 

' . $goFuncStart . '

	# Insert into DB
	$' . $table . 'New = new ' . $capTableName . '();
' . $outAddFieldsTxt . '
	$' . $table . 'New->insertIntoDB();
		
	header("Location: /' . $table . '/?ItemAdded=y");

}
include "' . $dir . '/inc/header.php";
?>
';
	my $htmlEditHead = '<?php	
include "' . $dir . '/lib/DB.php";
$db = new DB();
include "' . $dir . '/lib/' . $capTableName . '.php";
' . $goFuncStart . '

	# Update DB
	$' . $table . 'Update = new ' . $capTableName . '();

' . $outEditFieldsTxt . '
	$' . $table . 'Update->updateDB();
}
include "' . $dir . '/inc/header.php";


$' . $table . ' = new ' . $capTableName . '();
// Load DB data into object
$' . $table . '->set' . $capindexCol . '($_GET[\'id\']);
$' . $table . '->load' . $capTableName . '();
$all = $' . $table . '->getAll();


?>
';
	my $htmlDeleteHead = '<?php	
include "' . $dir . '/lib/DB.php";
$db = new DB();
include "' . $dir . '/lib/' . $capTableName . '.php";
' . $goFuncStart . '

	$' . $table . 'Delete = new ' . $capTableName . '();
	$' . $table . 'Delete->set' . $capindexCol . '($_GET[\'id\']);
	$' . $table . 'Delete->deleteFromDB();
	
	header("Location: /' . $table . '/?ItemDeleted=y");
    
    exit();
}
include "' . $dir . '/inc/header.php";
?>
';

	my $htmlViewBody = '<?php
$' . $table . ' = new ' . $capTableName . '();
// Load DB data into object
$' . $table . '->set' . $capindexCol . '($_GET[\'id\']);
$' . $table . '->load' . $capTableName . '();
$all = $' . $table . '->getAll();

if (isset($all)) {
		   ?>
		   
<div class="panel panel-info">
	<div class="panel-heading">
		<strong>Viewing <?php echo $' . $table . '->get' . $capindexCol . '();?></strong>
	</div>
	<div class="panel-body">
		<?php
    
    foreach ($all as $key => $value) {
        if (isset($value) && ($value != \'\')) {
            ?>
		    <dl class="dl-horizontal">
			<dt><?php echo $key;?></dt>
			<dd><?php echo $value;?></dd>
		</dl>
		    <?php
        }
    }
    
    ?>
	</div>
</div>
<?php
}else{
	?>
	<h2>No results found</h2>
	<?php
}
?>';

	my $htmlListBody = '
<?php
$res = $db->query("SELECT SQL_CALC_FOUND_ROWS DISTINCT * FROM ' . $table . ' ORDER BY ' . $indexFeild . ' DESC");
if (! empty($res)) {
	foreach($res as $r) {
		   ?>
<div class="panel panel-info">
	<div class="panel-heading">
		<strong><?php echo $r->' . $indexFeild . ';?></strong>
	</div>
	<div class="panel-body">
		<a href="view.php?id=<?php echo $r->' . $indexFeild . ';?>">View</a> |
		<a href="edit.php?id=<?php echo $r->' . $indexFeild . ';?>">Edit</a>|
		<a href="delete.php?id=<?php echo $r->' . $indexFeild . ';?>">Delete</a>
	</div>
</div>
<?php
	}
}else{
	?>
	<h2>No results found</h2>
	<?php
}
?>
';
	$getAllTxt =~ s/,\n$//;
	$getAllFunction .= '
	public function getAll()
	{
		$ret = array(' . "\n" . $getAllTxt . ');
		return $ret;
	}
';

	my $htmlAdd = '<div><a href="add.php">Add an Item</a></div><br>';

	print "creating web pages ";

	open( FH, ">$dir/www/$table/index.php" );
	print FH $htmlHead . $htmlAdd . $htmlListBody . $htmlFoot;
	close(FH);

	open( FH, ">$dir/www/$table/view.php" );
	print FH $htmlHead . $htmlViewBody . $htmlFoot;
	close(FH);

	open( FH, ">$dir/www/$table/add.php" );
	print FH $htmlAddHead . $formTagStart . $phpOutTxt . $formTagEnd . $htmlFoot;
	close(FH);

	open( FH, ">$dir/www/$table/edit.php" );
	print FH $htmlEditHead . $formEditTagStart . $phpEditOutTxt . $formTagEnd . $htmlFoot;
	close(FH);

	open( FH, ">$dir/www/$table/delete.php" );
	print FH $htmlDeleteHead . $htmlViewBody . $formEditTagStart . $phpDeleteOutTxt . $formTagEnd . $htmlFoot;
	close(FH);

	my $colList = join( ',', @cols );

	my $loadFunction = '
	public function load' . $capTableName . '() {
		global $db;
		if(!isset($this->' . $indexFeild . ')){
			return "No ' . $capTableName . ' ID";
		}		
    	$res = $db->select(\'SELECT ' 
	  . $colList 
	  . ' FROM ' 
	  . $table
	  . ' WHERE '
	  . $indexFeild
	  . '=?\', array($this->'
	  . $indexFeild
	  . '), \'d\');		
		$r=$res[0];    
' . $loadFromDB . '
	}
';

	my $saveToDBFunction = '

	public function updateDB() {
		global $db;
		global $' . $table . 'Formats;
		
	    $format = \'\';
	    foreach($this as $key => $value) {
	    	if($key == \'' . $indexFeild . '\'){continue;}
	        if (isset($this->$key)) {
	            $data[$key] = $value;
	            $format .= $' . $table . 'Formats[$key];
	        }
	    }
	     
	    $res = $db->update(\'' . $table . '\', $data, $format, array(\'' . $indexFeild . '\'=>$this->' . $indexFeild . '), \'i\');
	    
	    return $res;
	}

';

	my $insertToDBFunction = '

	public function insertIntoDB() {
		global $db;
		global $' . $table . 'Formats;
	    $format = \'\';
		foreach($this as $key => $value) {	    	
	        if (isset($this->$key)) {
	            $data[$key] = $value;
	            $format .= $' . $table . 'Formats[$key];
	        }
	    }
		 $res = $db->insert(\'' . $table . '\', $data, $format);
	    
	    return $res;
		
	}
';

	my $deleteFromDBFunction = '

	 public function deleteFromDB() {

        global $db;
        
        if(!isset($this->' . $indexFeild . ')){
			return "No ' . $capTableName . ' ID";
		}
        $res = $db->delete(\'' . $table . '\', $this->' . $indexFeild . ', \'' . $indexFeild . '\');
         
        return $res;
        
    }

';

	$bindValues =~ s/,\n$//s;
	$bindValues .= ');' . "\n\n";

	my $phpClass =
	    $classHeader
	  . $privateVariables
	  . $getsAndSets
	  . $getAllFunction
	  . $loadFunction
	  . $saveToDBFunction
	  . $insertToDBFunction
	  . $deleteFromDBFunction . '}'
	  . $bindValues;

	$allPHPClasses .=
	    $classHeader
	  . $privateVariables
	  . $getsAndSets
	  . $loadFunction
	  . $saveToDBFunction
	  . $insertToDBFunction
	  . $deleteFromDBFunction . '}';

	print "& PHP Class\n";
	open( FH, ">$dir/lib/$capTableName.php" );
	print FH '<?php' . $phpClass . "

?>";
	close(FH);

	$outFormatsTxt .= $bindValues;
}
open( FH, ">$dir/lib/Classes.php" );
print FH '<?php' . $allPHPClasses . "

$outFormatsTxt

?>";
close(FH);

open( FH, ">$dir/www/css/sitestyle.css" );
print FH '@CHARSET "UTF-8";

body {
	padding-top: 70px;
	padding-bottom: 30px;
	padding-left: 10px;
	padding-right: 10px;
}

.theme-dropdown .dropdown-menu {
	position: static;
	display: block;
	margin-bottom: 20px;
}

.theme-showcase>p>.btn {
	margin: 5px 0;
}

.theme-showcase .navbar .container {
	width: auto;
}

ul, ol {
	list-style-type: none;
};
';

close(FH);

$navHTML =~ s/ \| $//s;

$navHTML = <<EOF;
$navHTML
</ul></div>
</div></nav>
EOF

my $bootstrap = '<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css">
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
<link href="/css/sitestyle.css" rel="stylesheet"> 
';

print "$spacer\nCreating headers and footers for the web pages $dir/inc\n";
open( FH, ">$dir/inc/header.php" );
print FH '<!DOCTYPE html><html><head><meta charset="UTF-8">
<title></title>
' . $bootstrap . '
</head><body>' . $navHTML;
close(FH);

open( FH, ">$dir/inc/footer.php" );
print FH '</body></html>';
close(FH);

$htmlIndex .= <<EOF;
<div style="margin:60px;">phpStartPoint gives developers a way to create a coding <br>
environment quickly to allow rapid development of solutions<br> 
blah blah blah ... <br><br><br>
tl:dr use it if helps :) </div>
EOF

print "$spacer\nCreating the Index web page in $dir/www/index.php\n";
open( FH, ">$dir/www/index.php" );
print FH '<?php include "' . $dir . '/inc/header.php"; ?>' . $htmlIndex . '<?php include "' . $dir . '/inc/footer.php";?>';
close(FH);

$sth->finish;

# Write out the DB Class file
&makeDBClass();

system("chown -R $user:$user $dir");

if ( $platform =~ /^(fedora|redhat)$/ ) {
	my $parentDir = $dir;
	$parentDir =~ s/\/phpstartpoint//;
	print "Doing SE permissions on $parentDir\n";
	system("semanage fcontext -a -t public_content_rw_t \"$parentDir(/.*)?\" > /dev/null 2>&1");
	system("restorecon -R -v $parentDir/ > /dev/null 2>&1");
}

print "Credentials file is stored at $dir/etc/db.conf\n\n";
print "PHP Classes files are stored at $dir/lib\n\n";
print "Web pages are stored at $dir/www\n\n";
if ( $doApace eq 'y' ) {
	print "The Apache web root is $dir/www\n\n";
	print "Go to http://$domain in a brower\n\n";
}

exit;

sub getDBName {
	print "Enter the name of the database you would like to analyse (phpstartpoint): ";
	my $ans = <STDIN>;
	chomp $ans;
	if ( $ans eq '' ) { $ans = 'phpstartpoint' }
	return $ans;
}

sub getDBUser {
	print "Enter the username to connect to the database (athena): ";
	my $ans = <STDIN>;
	chomp $ans;
	if ( $ans eq '' ) { $ans = 'athena' }
	return $ans;
}

sub getDBPwd {
	print "Enter the password to connect to the database (PHPSPPWD): ";
	ReadMode 2;
	my $ans = <STDIN>;
	ReadMode 1;
	chomp $ans;
	if ( $ans eq '' ) { $ans = 'PHPSPPWD' }
	print "\n";
	return $ans;
}

sub getDomain {
	print "Enter the domain you would like to use for the development site (dev.phpstartpoint.com): ";
	my $ans = <STDIN>;
	chomp $ans;
	if ( $ans eq '' ) { $ans = 'dev.phpstartpoint.com' }
	return $ans;
}

sub setupApache {

	#	my $apacheInstalled = `dpkg --get-selections | grep apache`;
	if ( ( -e "/etc/apache2" ) || ( -e "/etc/httpd" ) ) {

		print "Would you like to add a dummy domain to the Apache Web Server\n";
		print "on this computer for you to view the php pages?\nY/n: ";
		ReadMode 4;
		while ( not defined( $doApace = ReadKey(-1) ) ) { }
		ReadMode 1;
		chomp $doApace;
		print "\n";
		if ( $doApace eq '' ) { $doApace = 'y'; }

		if ( $doApace eq 'y' ) {
			my $user = $>;
			if ($user) {
				print "\nGotta be root!\n\nTry sudo ./phpStartPoint.pl\n\n";
				exit;
			}
			if ( $domain eq '' ) { $domain = &getDomain(); }

			# Write out the Apache2 Conf file
			&makeApacheConf();

		}
	}
}

sub getType() {
	my $table = shift;
	my $col   = shift;
	my $sql =
"select data_type from information_schema.columns where table_schema = '$db' and table_name = '$table' AND column_name = '$col'";
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my @row_array = $sth->fetchrow_array;
	my $data_type = $row_array[0];

	if ( $data_type =~ /int$/ ) {
		return 'i';
	}

	if ( $data_type eq 'decimal' ) {
		return 'd';
	}

	if ( ( $data_type eq 'varchar' ) || ( $data_type eq 'text' ) || ( $data_type eq 'enum' ) ) {
		return 's';
	}
}

sub getPHPType() {
	my $table = shift;
	my $col   = shift;
	my $sql =
"select data_type from information_schema.columns where table_schema = '$db' and table_name = '$table' AND column_name = '$col'";
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my @row_array = $sth->fetchrow_array;
	my $data_type = $row_array[0];

	if ( $data_type =~ /int$/ ) {
		return 'i';
	}

	if ( $data_type eq 'decimal' ) {
		return 'd';
	}

	if ( $data_type eq 'varchar' ) {
		return 's';
	}
	if ( $data_type eq 'enum' ) {

		return 'e';
	}

	if ( $data_type eq 'text' ) {
		return 't';
	}
}

sub mkSelectFromEnum() {

	my $db    = shift;
	my $table = shift;
	my $col   = shift;
	my $title = shift;
	my $name  = shift;

	my $sql = "SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
    WHERE  table_schema = '$db' AND TABLE_NAME = '$table' AND COLUMN_NAME = '$col'";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @row_array = $sth->fetchrow_array;
	my $enum      = $row_array[0];
	$enum =~ s/enum\((.*)\)/$1/;
	$enum =~ s/'//g;

	my @enums = split( /,/, $enum );
	my $ret = <<EOF;
	
	<div class="form-group">
	<label for="$name">$title</label>
	<select name="$name" id="$name" class="form-control">
	
EOF

	foreach (@enums) {
		$ret .= "<option value=\"$_\">$_</option>\n";
	}

	$ret .= '</select></div>
';

	return $ret;
}

sub mkTxt() {
	my $title = shift;
	my $name  = shift;
	my $value = shift;

	my $ret = <<EOF;
	
	<div class="form-group">
	<label for="$name">$title</label>
	<input type="text" name="$name" id="$name" value="$value" class="form-control">
	</div>
	
EOF

	return $ret;
}

sub mkTxtBox() {
	my $title = shift;
	my $name  = shift;
	my $value = shift;

	my $ret = <<EOF;
	
	    <div class="form-group"><label for="$name">$title</label>
   <textarea name="$name" rows="4" cols="30" id="$name" class="form-control">$value
   </textarea></div>
   
EOF

	return $ret;
}

sub mkHidden() {

	my $name = shift;

	my $ret = <<EOF;
	
	    <div class="form-group"><input type="hidden" name="$name" id="$name" value="<?php echo \$_GET['id'];?>"></div>
	    
EOF

	return $ret;
}

sub makeApacheConf() {
	my $apache2Conf = "<VirtualHost *:80>
	ServerName phpstartpoint.com
	ServerAlias $domain
	DocumentRoot $dir/www
	
	 <Directory $dir/www/>
                AllowOverride None
                Options +Multiviews
                MultiviewsMatch Any
                Require all granted
    </Directory>
	
	
	php_admin_value open_basedir /tmp:$dir


	#ErrorLog \${APACHE_LOG_DIR}/error.log
	#CustomLog \${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
";


	print "\n\nMaking the Apache Virtual Host conf file\n\n";

	if ( -e "/etc/apache2/sites-available" ) {
		open( FH, ">/etc/apache2/sites-available/phpstartpoint.conf" );
		print FH $apache2Conf;
		close(FH);
		print "\n\nApache2 Conf file written to /etc/apache2/sites-available/phpstartpoint.conf\n\n";
		chdir('/etc/apache2/sites-available');
		system("a2ensite phpstartpoint.conf");
	}elsif ( -e "/etc/apache2/vhosts.d/" ) {
		open( FH, ">/etc/apache2/vhosts.d/phpstartpoint.conf" );
		print FH $apache2Conf;
		close(FH);
		print "\n\nApache2 Conf file written to /etc/apache2/vhosts.d/phpstartpoint.conf\n\n";
	}elsif ( -e "/etc/httpd/conf.d/" ) {
		open( FH, ">/etc/httpd/conf.d/phpstartpoint.conf" );
		print FH $apache2Conf;
		close(FH);
		print "\n\nApache2 Conf file written to /etc/httpd/conf.d/phpstartpoint.conf\n\n";
	}

	if ( $platform eq 'suse' ) {
		system("rcapache2 restart");
	}
	if ( $platform =~ /^(debain|ubuntu|mint)$/ ) {
		system("service apache2 restart");
	}
	if ( $platform =~ /^(fedora|redhat)$/ ) {
		system("service httpd restart");
	}

	print "\n\nAdding '127.0.0.1  $domain' to the /etc/hosts file\n\n";

	my $hosttext = '';
	open( FHH, "</etc/hosts" );
	while (<FHH>) {
		if ( !/$domain/ ) {
			$hosttext .= $_;
		}
	}
	close(FHH);

	$hosttext .= "
127.0.0.1       $domain
127.0.0.1       www.$domain";

	open( FHOUT, ">/etc/hosts" );
	print FHOUT $hosttext;
	close(FHOUT);

	chdir($dir);

}

sub makeDBClass() {

	my $dbclassFile = q^<?php
if (! class_exists('DB')) {

    class DB
    {

        public function __construct()
        {
            /*
             * The file db.conf should look similar to:-
             *
				db=yourdbname
				dbpw=yourdbpassword
				dbuser=adbusername
				host=localhost
             */
            $config = parse_ini_file('THISDIR/etc/db.conf');
            $this->user = $config['dbuser'];
            $this->password = $config['dbpw'];
            $this->database = $config['db'];
            $this->host = $config['host'];
            // Connect to the database
            $this->db = $this->connect();
        }

        protected function connect()
        {
            return new mysqli($this->host, $this->user, $this->password, $this->database);
        }

        public function query($query)
        {
            $result = $this->db->query($query);
            
            while ($row = $result->fetch_object()) {
                $results[] = $row;
            }
            
            return $results;
        }

        public function insert($table, $data, $format)
        {
            // Check for $table or $data not set
            if (empty($table) || empty($data)) {
                return false;
            }
            
            // Cast $data to array
            $data = (array) $data;
            
            list ($fields, $placeholders, $values) = $this->prep_query($data);
            
            // Prepend $format onto $values
            array_unshift($values, $format);
            
            // Prepary our query for binding
            $stmt = $this->db->prepare("INSERT INTO {$table} ({$fields}) VALUES ({$placeholders})");
            
            // Dynamically bind values
            call_user_func_array(array(
                $stmt,
                'bind_param'
            ), $this->ref_values($values));
            
            // Execute the query
            $stmt->execute();
            
            // Check for successful insertion
            if ($stmt->affected_rows) {
                return true;
            }
            
            return false;
        }

        public function update($table, $data, $format, $where, $where_format)
        {
            // Check for $table or $data not set
            if (empty($table) || empty($data)) {
                return false;
            }
            
            // Cast $data to array
            $data = (array) $data;
            
            // Build format string
            $format .= $where_format;
            
            list ($fields, $placeholders, $values) = $this->prep_query($data, 'update');
            
            // Format where clause
            $where_clause = '';
            $where_values = '';
            $count = 0;
            
            foreach ($where as $field => $value) {
                if ($count > 0) {
                    $where_clause .= ' AND ';
                }
                
                $where_clause .= $field . '=?';
                $where_values[] = $value;
                
                $count ++;
            }
            
            // Prepend $format onto $values
            array_unshift($values, $format);
            $values = array_merge($values, $where_values);
            
            // Prepary our query for binding
            $stmt = $this->db->prepare("UPDATE {$table} SET {$placeholders} WHERE {$where_clause}");
            // echo "UPDATE {$table} SET {$placeholders} WHERE {$where_clause}";
            // Dynamically bind values
            call_user_func_array(array(
                $stmt,
                'bind_param'
            ), $this->ref_values($values));
            
            // Execute the query
            $stmt->execute();
            
            // Check for successful insertion
            if ($stmt->affected_rows) {
                return true;
            }
            
            return false;
        }

        public function select($query, $data, $format)
        {
            
            // Prepare our query for binding
            $stmt = $this->db->prepare($query);
            
            // Prepend $format onto $values
            array_unshift($data, $format);
            
            // Dynamically bind values
            call_user_func_array(array(
                $stmt,
                'bind_param'
            ), $this->ref_values($data));
            echo $this->db->error;
            // Execute the query
            $stmt->execute();
            
            // Fetch results
            $result = $stmt->get_result();
            
            // Create results object
            while ($row = $result->fetch_object()) {
                $results[] = $row;
            }
            
            return $results;
        }

        public function delete($table, $id, $idField)
        {
            
            // Prepary our query for binding
            $stmt = $this->db->prepare("DELETE FROM {$table} WHERE {$idField} = ?");
            
            // Dynamically bind values
            $stmt->bind_param('d', $id);
            
            // Execute the query
            $stmt->execute();
            
            // Check for successful insertion
            if ($stmt->affected_rows) {
                return true;
            }
        }

        private function prep_query($data, $type = 'insert')
        {
            // Instantiate $fields and $placeholders for looping
            $fields = '';
            $placeholders = '';
            $values = array();
            
            // Loop through $data and build $fields, $placeholders, and $values
            foreach ($data as $field => $value) {
                $fields .= "{$field},";
                $values[] = $value;
                
                if ($type == 'update') {
                    $placeholders .= $field . '=?,';
                } else {
                    $placeholders .= '?,';
                }
            }
            
            // Normalize $fields and $placeholders for inserting
            $fields = substr($fields, 0, - 1);
            $placeholders = substr($placeholders, 0, - 1);
            
            return array(
                $fields,
                $placeholders,
                $values
            );
        }

        private function ref_values($array)
        {
            $refs = array();
            
            foreach ($array as $key => $value) {
                $refs[$key] = &$array[$key];
            }
            
            return $refs;
        }
    }
}
?>
^;

	$dbclassFile =~ s/THISDIR/$dir/s;

	open( FH, ">$dir/lib/DB.php" );
	print FH $dbclassFile;
	close(FH);

}

sub makeDB() {
	my $sqlRootPwd = shift;

	my $sql = q|

DROP DATABASE IF EXISTS phpstartpoint;
CREATE DATABASE phpstartpoint;

USE phpstartpoint;

DROP TABLE IF EXISTS `address`;
CREATE TABLE `address` (
  `addsid` int(10) unsigned NOT NULL,
  `add1` varchar(128) DEFAULT NULL,
  `add2` varchar(128) DEFAULT NULL,
  `add3` varchar(128) DEFAULT NULL,
  `city` varchar(128) DEFAULT NULL,
  `county` varchar(128) DEFAULT NULL,
  `country` varchar(128) DEFAULT NULL,
  `postcode` varchar(128) DEFAULT NULL,
  `tel` varchar(45) DEFAULT NULL,
  `mob` varchar(56) DEFAULT NULL,
  `fax` varchar(45) DEFAULT NULL,
  `email` varchar(128) DEFAULT NULL,
  `web` varchar(128) DEFAULT NULL,
  `facebook` varchar(256) DEFAULT NULL,
  `twitter` varchar(256) DEFAULT NULL,
  `linkedin` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`addsid`)
);

LOCK TABLES `address` WRITE;
INSERT INTO `address` VALUES (100,'201 Old Bracknell Close','','','Hatfield','Doncaster','England','DN7 EG70','+44 1125 116144','+44 968 155088','+44 1212 159964','test@athena.systems','','','',''),(1000,'203 Fothergill Way','','','Dumfries and Galloway','Dumfries and Galloway','Scotland','DG10 HC92','+44 969 89582','+44 925 90539','+44 1246 86673','Dorthea.Commiskey@athena.systems','',NULL,NULL,NULL),(1001,'9 Pencombe Mews','','','Llanfihangel-Ar-Arth','Carmarthenshire','Wales','SA39 RY83','+44 1031 144946','+44 1719 141709','+44 1540 171429','Sharice.Buress@athena.systems','',NULL,NULL,NULL),(1002,'215 Hayfield Mews','','','Bangor','North Down','Northern Ireland','BT20 U957','+44 1220 94424','+44 1338 101286','+44 1021 170900','Dortha.Dobias@athena.systems','',NULL,NULL,NULL),(1003,'153 Milizac Close','','','Lymm','Warrington','England','WA13 VN23','+44 1178 113584','+44 1322 142815','+44 1409 118201','Julie.Canterberry@athena.systems','',NULL,NULL,NULL),(1004,'39 Easterfield Drive','','','Capel','Surrey','England','RH5 DQ97','+44 1027 120500','+44 1650 169868','+44 1225 150437','Lamar.Bunck@athena.systems','',NULL,NULL,NULL),(1005,'236 Ashgrove Lane','','','Crosby','Liverpool','England','L23 OV67','+44 1723 138936','+44 1001 106299','+44 948 114364','Doyle.Mccole@athena.systems','',NULL,NULL,NULL),(1006,'198 Nimrod Way','','','Stainton','Middlesbrough','England','TS8 S790','+44 1640 146666','+44 950 150971','+44 1485 176113','Jay.Jubilee@athena.systems','',NULL,NULL,NULL),(1007,'296 Neath Gardens','','','Dalton-le-Dale','County Durham','England','SR7 Z158','+44 1643 94826','+44 1509 164814','+44 1007 120126','Lynwood.Foulger@athena.systems','',NULL,NULL,NULL),(1008,'65 Kentmere Approach','','','Birmingham','Birmingham','England','B73 7C28','+44 1080 84663','+44 927 157757','+44 1250 123765','Howard.Schmandt@athena.systems','',NULL,NULL,NULL),(1009,'15 Gauldry Terrace','','','Westbury','Wiltshire','England','BA13 JV2','+44 1023 160427','+44 919 139669','+44 1767 142189','Everette.Ximines@athena.systems','',NULL,NULL,NULL),(1010,'269 Cookham Wood Road','','','Watford','Hertfordshire','England','WD17 NQ94','+44 1462 121376','+44 1673 92893','+44 1323 133093','Carlton.Miskin@athena.systems','',NULL,NULL,NULL),(1011,'211 Branksome Court','','','Wolverhampton','Wolverhampton','England','WV4 SN41','+44 1238 171985','+44 923 114308','+44 1690 92838','Ok.Ridgle@athena.systems','',NULL,NULL,NULL),(1012,'197 Bure Homage Gardens','','','Faversham','Kent','England','ME13 BI14','+44 1060 117434','+44 1261 162028','+44 1515 164225','Luann.Karakas@athena.systems','',NULL,NULL,NULL),(1013,'173 Beeston Court','','','Crowborough','East Sussex','England','TN6 7V23','+44 1219 171315','+44 1487 125973','+44 1670 111850','Tijuana.Traicoff@athena.systems','',NULL,NULL,NULL),(1014,'149 Chequers Close','','','Sutton','Greater London','England','KT4 TC13','+44 1365 174242','+44 1334 122457','+44 1612 143468','Giovanna.Stutesman@athena.systems','',NULL,NULL,NULL),(1015,'282 Boulmer Close','','','Saddleworth','Oldham','England','OL3 VZ51','+44 1163 125650','+44 1263 90808','+44 1683 85210','Cassondra.Lehenbauer@athena.systems','',NULL,NULL,NULL),(1016,'61 Dunsterville Road','','','Ashendon','Buckinghamshire','England','HP18 RR24','+44 1597 106563','+44 1233 144716','+44 1107 94740','Paulina.Toles@athena.systems','',NULL,NULL,NULL),(1017,'241 Dercongal Road','','','Hurst Green','Dudley','England','B62 N551','+44 1292 118482','+44 1374 102614','+44 1525 119624','Caryn.Urbanik@athena.systems','',NULL,NULL,NULL),(1018,'8 Roslin Close','','','Dover','Kent','England','CT16 OR37','+44 1419 82760','+44 1425 89817','+44 1403 178153','Don.Aills@athena.systems','',NULL,NULL,NULL),(1019,'94 Links Parade','','','Camberwell','Greater London','England','SE17 XI70','+44 1504 135981','+44 1481 170513','+44 1463 156803','Kim.Jaskolka@athena.systems','',NULL,NULL,NULL),(1020,'259 Smalewell Close','','','Holsworthy Hamlets','Devon','England','EX22 X572','+44 819 119799','+44 1234 129885','+44 1424 82249','Tobias.Furubotten@athena.systems','',NULL,NULL,NULL),(1021,'205 Doric Avenue','','','Tadmarton','Oxfordshire','England','OX15 C292','+44 1047 98613','+44 1248 85733','+44 865 136514','Ramon.Emerton@athena.systems','',NULL,NULL,NULL),(1022,'237 Raneley Grove','','','Islington','Greater London','England','EC1V HX30','+44 1395 145134','+44 1143 164915','+44 846 141356','Vern.Beiley@athena.systems','',NULL,NULL,NULL),(1023,'33 The Childers','','','Barnet','Greater London','England','NW7 BC52','+44 1544 112567','+44 1610 132771','+44 1135 142369','Jamal.Fishburne@athena.systems','',NULL,NULL,NULL),(1024,'298 Bryneinon Road','','','Stroud','Hampshire','England','GU32 ZX25','+44 1004 83809','+44 1707 94153','+44 1421 94440','Lopus.Pty..Ltd.@athena.systems','',NULL,NULL,NULL),(1025,'224 Baberton Mains Crescent','','','Madeley','Telford and Wrekin','England','TF7 LY4','+44 853 167796','+44 1687 150994','+44 1520 179478','Overly.Ltd@athena.systems','',NULL,NULL,NULL),(1026,'146 Cogdean Walk','','','Corbridge','Northumberland','England','NE45 AP97','+44 1137 176088','+44 949 135376','+44 1589 103083','Buden.and.Co.@athena.systems','',NULL,NULL,NULL),(1027,'110 Trellech Court','','','Lewisham','Greater London','England','SE26 JB40','+44 1706 124575','+44 1269 139114','+44 1438 162161','Likio.and.Sons@athena.systems','',NULL,NULL,NULL),(1028,'218 Rattle Road','','','Carlton in Lindrick','Nottinghamshire','England','S81 Y517','+44 1714 81785','+44 1269 115775','+44 989 115961','Houseal.Foundry@athena.systems','',NULL,NULL,NULL),(1029,'229 Shalloch Park','','','Lymm','Warrington','England','WA13 XD62','+44 1594 129864','+44 806 170643','+44 1244 175823','Tyre.Logistics@athena.systems','',NULL,NULL,NULL),(1030,'111 Kellock Drive','','','Rame','Cornwall','England','PL10 FM57','+44 1489 155468','+44 959 104745','+44 981 137594','Hodges.Co..Ltd@athena.systems','',NULL,NULL,NULL),(1031,'122 Wavertree Green','','','Ellerker','East Riding of Yorkshire','England','HU15 AS80','+44 946 139576','+44 812 161565','+44 1190 88897','Tahir.Studios@athena.systems','',NULL,NULL,NULL),(1032,'217 Beadon Lane','','','Potters Bar','Hertfordshire','England','WD23 Q_23','+44 1467 141314','+44 978 166462','+44 1280 98025','Barragan.Associates@athena.systems','',NULL,NULL,NULL),(1033,'218 Franchise Street','','','Hackney','Greater London','England','E5 TK99','+44 1620 96587','+44 817 162969','+44 852 171765','Tieman.Foundry@athena.systems','',NULL,NULL,NULL),(1034,'216 Carlibar Gardens','','','Wednesfield','Wolverhampton','England','WV11 CF9','+44 845 121536','+44 1683 179934','+44 1374 160366','Escobar.Inc.@athena.systems','',NULL,NULL,NULL),(1035,'236 Southway Lane','','','Rawtenstall','Lancashire','England','OL13 RH4','+44 1687 116670','+44 1254 97863','+44 1743 103578','Isaacks.Pty..Ltd.@athena.systems','',NULL,NULL,NULL),(1036,'228 Honeysuckle Rise','','','Bury','Bury','England','M45 8N59','+44 1039 98747','+44 885 136891','+44 1365 118048','Goldfischer.Agency@athena.systems','',NULL,NULL,NULL),(1037,'163 Keer Bank','','','Blofield','Norfolk','England','NR13 XZ24','+44 1720 95845','+44 1625 153332','+44 1310 167528','Lenci.Products@athena.systems','',NULL,NULL,NULL),(1038,'216 Clopton Park','','','Milford Haven','Pembrokeshire','Wales','SA73 VF62','+44 1535 159840','+44 1060 104630','+44 1450 124414','Kivisto.Associates@athena.systems','',NULL,NULL,NULL),(1039,'261 Wanny Road','','','Nailsea','North Somerset','England','BS48 XP44','+44 1106 115962','+44 884 125406','+44 1622 130216','Vandenberghe.Ltd@athena.systems','',NULL,NULL,NULL),(1040,'152 Pheasantford Green','','','Solihull','Solihull','England','B90 M813','+44 833 162966','+44 1430 134148','+44 859 154369','Lilliam.Roberge@athena.systems','',NULL,NULL,NULL),(1041,'43 Hill Grove Crescent','','','Argyll and Bute','Argyll and Bute','Scotland','PA73 XT49','+44 1025 112675','+44 1720 175673','+44 1048 118859','Manuela.Zerko@athena.systems','',NULL,NULL,NULL),(1042,'141 Shimsey Close','','','Leeds','Leeds','England','LS9 PY49','+44 832 122873','+44 1117 174663','+44 1634 130596','Ashely.Moncada@athena.systems','',NULL,NULL,NULL),(1043,'76 Lady Well Lane','','','Bury','Bury','England','M25 WY27','+44 1593 89815','+44 1147 163595','+44 1134 145587','Alleen.Picasso@athena.systems','',NULL,NULL,NULL),(1044,'130 Iveagh Crescent','','','Norton','Sheffield','England','S12 C526','+44 986 84404','+44 1118 133046','+44 864 132609','Kip.Dopp@athena.systems','',NULL,NULL,NULL),(1045,'7 Colne Park Road','','','Bournemouth','Bournemouth','England','BH9 F027','+44 802 101171','+44 1683 107759','+44 1260 101406','Chase.Bossardet@athena.systems','',NULL,NULL,NULL),(1046,'120 Landsholme Court','','','Broad Clyst','Devon','England','EX5 PK38','+44 1185 136927','+44 1416 99432','+44 977 164882','Elijah.Gullion@athena.systems','',NULL,NULL,NULL),(1047,'176 Holdaway Close','','','Westminster','London','England','WC2 OU42','+44 1389 140232','+44 1339 87494','+44 1323 107641','Jarrett.Behanan@athena.systems','',NULL,NULL,NULL),(1048,'51 Wern Bank','','','Marazion','Cornwall','England','TR17 CG90','+44 1082 90899','+44 1763 151544','+44 890 81056','Lynwood.Cashon@athena.systems','',NULL,NULL,NULL),(1049,'170 Warmingham Road','','','Martock','Somerset','England','TA12 M445','+44 939 144186','+44 948 109451','+44 1422 154817','Ali.Abajian@athena.systems','',NULL,NULL,NULL),(1050,'87 Elmhurst Close','','','Reigate and Banstead','Surrey','England','SM7 6W68','+44 1500 129320','+44 826 117882','+44 1096 121464','Gregoria.Mcken@athena.systems','',NULL,NULL,NULL),(1051,'96 Lower Broad Path','','','Dungannon','Dungannon','Northern Ireland','BT71 CC63','+44 1629 81061','+44 1014 94082','+44 978 123353','Janay.Hilger@athena.systems','',NULL,NULL,NULL),(1052,'162 Hoathly Mews','','','Stawell','Somerset','England','TA7 JA41','+44 1215 145041','+44 1184 150910','+44 1096 94027','Stephanie.Craton@athena.systems','',NULL,NULL,NULL),(1053,'218 Mull Close','','','Heywood','Rochdale','England','OL10 V_3','+44 1159 90118','+44 1221 110412','+44 809 172709','Natividad.Mcbrayer@athena.systems','',NULL,NULL,NULL),(1054,'261 Applehaigh Grove','','','Royal Tunbridge Wells','Kent','England','TN3 5X71','+44 1109 128283','+44 1438 148669','+44 1627 168231','Wanetta.Kingsberry@athena.systems','',NULL,NULL,NULL),(1055,'195 Heol Buckley','','','Edinburgh','City of Edinburgh','Scotland','EH1 SN91','+44 1498 97634','+44 1372 177949','+44 1721 178509','Sharell.Prez@athena.systems','',NULL,NULL,NULL),(1056,'87 Portman Road','','','Royal Tunbridge Wells','Kent','England','TN3 BN21','+44 1151 105541','+44 1791 162012','+44 1287 156450','Doyle.Hollinger@athena.systems','',NULL,NULL,NULL),(1057,'173 Henry De Grey Close','','','Ormskirk','Lancashire','England','WN8 C867','+44 1105 91745','+44 1728 174122','+44 1013 137825','Caleb.Jumonville@athena.systems','',NULL,NULL,NULL),(1058,'132 Fourth Street','','','Accrington','Lancashire','England','BB5 ZS65','+44 1505 99224','+44 1366 176956','+44 1797 151705','Dorsey.Mcphetridge@athena.systems','',NULL,NULL,NULL),(1059,'9 Detmore Close','','','Bracknell','Bracknell Forest','England','RG12 RQ76','+44 1119 101311','+44 1172 109083','+44 1795 101630','Claude.Yip@athena.systems','',NULL,NULL,NULL),(1060,'175 Fornham Street','','','Lyndhurst','Hampshire','England','SO43 SZ11','+44 1014 130537','+44 1571 153875','+44 1158 155492','Cristobal.Knoth@athena.systems','',NULL,NULL,NULL),(1061,'89 Crawford Court','','','Thurso','Highland','Scotland','KW14 UX18','+44 1564 175146','+44 931 167826','+44 1392 165211','Kyung.Pfost@athena.systems','',NULL,NULL,NULL),(1062,'142 Ocean Street','','','Surrey','Surrey','England','TW19 OJ30','+44 1734 134553','+44 800 153611','+44 964 85126','Kena.Laplant@athena.systems','',NULL,NULL,NULL),(1063,'129 Nutfields Grove','','','Ffestiniog','Gwynedd','Wales','LL41 DA3','+44 858 156996','+44 1725 125109','+44 1346 141826','Gregoria.Helmes@athena.systems','',NULL,NULL,NULL),(1064,'154 Scandinavian Way','','','Clint','North Yorkshire','England','HG3 PU78','+44 1520 84123','+44 1049 155752','+44 1476 85918','Lavonia.Plumb@athena.systems','',NULL,NULL,NULL),(1065,'113 Larkrise Close','','','Guildford','Surrey','England','GU4 QD0','+44 1690 147990','+44 1216 131701','+44 1395 131018','Alexa.Smull@athena.systems','',NULL,NULL,NULL),(1066,'1 Caldbeck Drive','','','Swindon','Swindon','England','SN1 LJ8','+44 1296 120928','+44 1371 126890','+44 1303 170356','Vi.Dreiling@athena.systems','',NULL,NULL,NULL),(1067,'74 Arundel Road','','','Ross-on-Wye','County of Herefordshire','England','HR9 5U70','+44 952 108883','+44 1612 163140','+44 1772 145056','Lenny.Zaidi@athena.systems','',NULL,NULL,NULL),(1068,'295 Joseph Locke Way','','','Sandford','Devon','England','EX17 A666','+44 1031 89932','+44 885 81788','+44 1511 162497','Geraldo.Hammitt@athena.systems','',NULL,NULL,NULL),(1069,'2 Sullington Close','','','Torbay','Torbay','England','TQ5 RB38','+44 955 88291','+44 1597 143980','+44 1486 178229','Tuan.Brunn@athena.systems','',NULL,NULL,NULL),(1070,'263 Lornton Walk','','','Coleford','Gloucestershire','England','GL16 FK63','+44 938 144802','+44 855 82856','+44 1249 81250','Herb.Quirino@athena.systems','',NULL,NULL,NULL),(1071,'231 Mill Green Garth','','','Great Wyrley','Staffordshire','England','WS6 _S37','+44 1139 146591','+44 1505 82913','+44 1715 152740','Nestor.Worsell@athena.systems','',NULL,NULL,NULL),(1072,'225 Barbara Square','','','Wakefield','Wakefield','England','WF8 IF45','+44 1307 93290','+44 809 82803','+44 1746 158762','Bradley.Moler@athena.systems','',NULL,NULL,NULL),(1073,'70 Geddes Hill','','','Dudley','Dudley','England','DY3 JI90','+44 1116 146672','+44 1781 115969','+44 1038 89526','Emely.Lowney@athena.systems','',NULL,NULL,NULL),(1074,'297 Vincents Road','','','Perranarworthal','Cornwall','England','TR3 8I88','+44 1280 144497','+44 963 150974','+44 1443 159284','Jeannie.Kawczynski@athena.systems','',NULL,NULL,NULL),(1075,'204 Bethune Close','','','Bridgemere','Cheshire East','England','CW3 ZD30','+44 1074 87906','+44 1166 87270','+44 931 175316','Albertina.Faires@athena.systems','',NULL,NULL,NULL),(1076,'103 Rockland Lane','','','Beaumaris','Isle of Anglesey','Wales','LL58 AM70','+44 1665 95490','+44 1241 159617','+44 1697 156750','Angelica.Towle@athena.systems','',NULL,NULL,NULL),(1077,'276 Wagon Lane','','','Enfield','Greater London','England','EN2 OB63','+44 1528 96400','+44 1247 147487','+44 1459 100815','Myrtle.Rocquemore@athena.systems','',NULL,NULL,NULL),(1078,'229 East Brougham Street','','','Sandhurst','Bracknell Forest','England','GU47 _337','+44 1528 98798','+44 926 95847','+44 1517 104751','Carolyn.Buntyn@athena.systems','',NULL,NULL,NULL),(1079,'183 Waun Ganol','','','Farnham','Surrey','England','GU10 _C89','+44 1502 147831','+44 857 109817','+44 1640 156284','Ahmed.Brousard@athena.systems','',NULL,NULL,NULL),(1080,'73 Hornyold Road','','','Llangoedmor','Ceredigion','Wales','SA43 _Y39','+44 1281 110177','+44 1448 116550','+44 1309 117060','Irving.Taintor@athena.systems','',NULL,NULL,NULL),(1081,'246 Gallowhill Road','','','Morpeth','Northumberland','England','NE61 _N11','+44 1628 176142','+44 1261 129219','+44 922 96611','Benton.Borton@athena.systems','',NULL,NULL,NULL),(1082,'140 Pitskelly Road','','','Banbridge','Banbridge','Northern Ireland','BT25 2H57','+44 1570 158132','+44 1729 165020','+44 1125 88726','Vicente.Mose@athena.systems','',NULL,NULL,NULL),(1083,'294 Wilman Road','','','Four Throws','Kent','England','TN18 DZ63','+44 1242 116450','+44 994 112743','+44 1039 139670','Douglas.Therriault@athena.systems','',NULL,NULL,NULL),(1084,'249 Mount Pleasant Grove','','','Dingley','Northamptonshire','England','LE16 7S38','+44 1643 162624','+44 1185 112377','+44 1120 162635','Lucien.Delosier@athena.systems','',NULL,NULL,NULL),(1085,'18 Backmoor Road','','','Uttoxeter','Staffordshire','England','ST14 F741','+44 1383 90384','+44 971 93794','+44 1381 80525','Nancie.Magarelli@athena.systems','',NULL,NULL,NULL),(1086,'71 Chapmans Passage','','','Highland','Highland','Scotland','PH23 TQ6','+44 1463 174929','+44 1242 96036','+44 1147 162282','Nohemi.Deiters@athena.systems','',NULL,NULL,NULL),(1087,'208 Bissoe Road','','','Wolverhampton','Wolverhampton','England','WV3 1B98','+44 1138 80335','+44 1016 120293','+44 1463 85568','Kandis.Raponi@athena.systems','',NULL,NULL,NULL),(1088,'128 Knowlton Road','','','Pentyrch','Cardiff','Wales','CF15 KD72','+44 1631 107871','+44 1655 178965','+44 1006 113164','Robin.Fair@athena.systems','',NULL,NULL,NULL),(1089,'158 Lansdown Place West','','','Norton Sub Hamdon','Somerset','England','TA14 MV6','+44 935 161858','+44 963 92101','+44 1099 150518','Jami.Korb@athena.systems','',NULL,NULL,NULL),(1090,'67 Marlcliff Grove','','','Stevenage','Hertfordshire','England','SG1 O660','+44 809 174588','+44 1107 103647','+44 1005 100063','Nicole.Haegele@athena.systems','',NULL,NULL,NULL),(1091,'5 Tod Holes Lane','','','Greenwich','Greater London','England','SE3 5W38','+44 1145 93817','+44 969 105286','+44 1230 144545','Carmen.Colli@athena.systems','',NULL,NULL,NULL),(1092,'33 Nene Grove','','','Aberdeen','Aberdeen City','Scotland','AB15 KL74','+44 1389 83221','+44 1211 125215','+44 915 109784','Robbie.Kivisto@athena.systems','',NULL,NULL,NULL),(1093,'63 Astrey Close','','','Somerton','Somerset','England','TA11 KJ74','+44 1592 169091','+44 1779 105467','+44 1678 129420','Arthur.Stmichel@athena.systems','',NULL,NULL,NULL),(1094,'211 Sandra Road','','','Halifax','Calderdale','England','HX5 JT19','+44 1689 127745','+44 1037 170104','+44 1504 85363','Dino.Dockal@athena.systems','',NULL,NULL,NULL),(1095,'25 Hatston Park','','','Camden Town','Greater London','England','NW5 MR11','+44 1794 137361','+44 1341 147346','+44 1407 102165','Johnathon.Leetch@athena.systems','',NULL,NULL,NULL),(1096,'287 Hillcroft Close','','','Ormiston','East Lothian','Scotland','EH35 5D0','+44 1101 134556','+44 1529 125660','+44 1607 132019','Noah.Marandi@athena.systems','',NULL,NULL,NULL),(1097,'99 Farthing Gale Mews','','','Attleborough','Norfolk','England','NR17 KK48','+44 1670 150342','+44 1095 97746','+44 1551 106328','Alyce.Mccunn@athena.systems','',NULL,NULL,NULL),(1098,'222 Lower Broad Path','','','Juniper Green','City of Edinburgh','Scotland','EH13 FB78','+44 1714 138114','+44 1254 147892','+44 1516 123240','Donnetta.Turnpaugh@athena.systems','',NULL,NULL,NULL),(1099,'272 Crocker Lane','','','Hutton','North Somerset','England','BS24 UN67','+44 1189 90670','+44 1210 92141','+44 1732 139754','Allen.Lewczyk@athena.systems','',NULL,NULL,NULL),(1100,'266 Horsegate Bank','','','North Ferriby','East Riding of Yorkshire','England','HU14 E759','+44 873 164181','+44 997 109179','+44 957 130437','Natisha.Hendron@athena.systems','',NULL,NULL,NULL),(1101,'180 Livesay Road','','','Ayr','South Ayrshire','Scotland','KA7 RH1','+44 1557 112698','+44 1332 164208','+44 1096 134109','Jeanett.Bostwick@athena.systems','',NULL,NULL,NULL),(1102,'195 Withers Street','','','Haverhill','Suffolk','England','CB9 D_60','+44 1380 148196','+44 1023 155055','+44 1290 156967','Reita.Paisley@athena.systems','',NULL,NULL,NULL),(1103,'172 Furzehatt Avenue','','','Oulton Broad','Suffolk','England','NR32 PQ88','+44 1717 97795','+44 1704 160970','+44 1592 126787','Tyron.Bigusiak@athena.systems','',NULL,NULL,NULL),(1104,'164 Mill Quadrant','','','Trimdon','County Durham','England','TS29 CA49','+44 1308 140641','+44 821 113774','+44 861 179482','Wade.Voit@athena.systems','',NULL,NULL,NULL),(1105,'46 Arden Close','','','Bristol','City of Bristol','England','BS4 AF72','+44 1670 152005','+44 1559 146348','+44 942 102128','Domingo.Sagel@athena.systems','',NULL,NULL,NULL),(1106,'112 Hollymead Lane','','','Brent','Greater London','England','HA0 KG66','+44 1260 87492','+44 1739 98474','+44 993 161261','Bobbie.Nagelkirk@athena.systems','',NULL,NULL,NULL),(1107,'121 William Petty Way','','','Trimdon','County Durham','England','TS29 PS53','+44 1519 110661','+44 1237 89400','+44 1353 163865','Basil.Finlay@athena.systems','',NULL,NULL,NULL),(1108,'75 Chainhill Road','','','Argyll and Bute','Argyll and Bute','Scotland','PA49 WV20','+44 924 87953','+44 1793 158238','+44 1332 95265','Oren.Hayward@athena.systems','',NULL,NULL,NULL),(1109,'6 Enyeat Road','','','Enfield','Greater London','England','N21 GH77','+44 1767 165574','+44 1605 153280','+44 1687 161613','Fernande.Pegues@athena.systems','',NULL,NULL,NULL),(1110,'237 Burrows Close Lane','','','Bromley','Greater London','England','BR7 4P57','+44 1594 144601','+44 1705 99957','+44 1454 93272','Thresa.Pacini@athena.systems','',NULL,NULL,NULL),(1111,'109 Crabtree Place','','','Cornhill-on-Tweed','Northumberland','Scotland','TD12 2A37','+44 1698 165840','+44 867 112463','+44 1471 133251','Salena.Wibeto@athena.systems','',NULL,NULL,NULL),(1112,'150 Loder Place','','','Norwich','Norfolk','England','NR1 QK31','+44 1347 133159','+44 870 100751','+44 1762 162808','Nita.Laroche@athena.systems','',NULL,NULL,NULL),(1113,'281 Trefoil Court','','','Meopham Station','Kent','England','DA13 8X76','+44 1313 125259','+44 1299 161360','+44 1078 123783','Margart.Birrueta@athena.systems','',NULL,NULL,NULL),(1114,'286 Moray Street','','','Chesterton','Oxfordshire','England','OX25 V951','+44 1641 135701','+44 1659 123977','+44 907 99172','Rhonda.Lemmer@athena.systems','',NULL,NULL,NULL),(1115,'231 Ronalds Way','','','Liverpool','Liverpool','England','L13 Q382','+44 1075 177239','+44 1526 162032','+44 1630 86294','Ervin.Kershner@athena.systems','',NULL,NULL,NULL),(1116,'127 Hawnby Grove','','','Comrie','Perth and Kinross','Scotland','PH6 GV63','+44 1220 136877','+44 1591 108082','+44 805 176313','Garland.Coffey@athena.systems','',NULL,NULL,NULL),(1117,'50 Harding Shute','','','Martley','Worcestershire','England','WR6 MZ13','+44 1344 173500','+44 1767 154023','+44 1785 177866','Eduardo.Hartley@athena.systems','',NULL,NULL,NULL),(1118,'140 Gelligaer Gardens','','','East Lothian','East Lothian','Scotland','EH36 XD2','+44 1638 167395','+44 1251 114151','+44 1792 100490','Andrea.Sheskey@athena.systems','',NULL,NULL,NULL),(1119,'187 Trewarren Road','','','Nottingham','Nottingham','England','NG8 R233','+44 1154 114608','+44 1696 99531','+44 1727 103817','Darwin.Zotos@athena.systems','',NULL,NULL,NULL),(1120,'20 Silverlea Drive','','','Mosstodloch','Moray','Scotland','IV32 7D64','+44 1025 161740','+44 991 147053','+44 1687 114482','Hoyt.Vieths@athena.systems','',NULL,NULL,NULL),(1121,'232 Thanet Terrace','','','Glantwymyn','Powys','Wales','SY20 RC85','+44 1422 109345','+44 1623 113487','+44 1202 87609','Aletha.Curvin@athena.systems','',NULL,NULL,NULL),(1122,'76 Hayward Way','','','Corby','Northamptonshire','England','NN17 M933','+44 1416 151763','+44 1003 138271','+44 1430 119964','Jerilyn.Miserendino@athena.systems','',NULL,NULL,NULL),(1123,'69 The Stakes','','','Southminster','Essex','England','CM0 S448','+44 1742 84305','+44 1426 174036','+44 1789 106644','Odessa.Sanjose@athena.systems','',NULL,NULL,NULL),(1124,'174 Morry Lane','','','Dumfries and Galloway','Dumfries and Galloway','Scotland','DG10 3M57','+44 1404 148115','+44 996 132265','+44 1121 150757','Alex.Curtice@athena.systems','',NULL,NULL,NULL),(1125,'72 Henke Court','','','Holton','Oxfordshire','England','OX33 GM37','+44 986 145207','+44 872 85118','+44 1187 120637','Shameka.Atherton@athena.systems','',NULL,NULL,NULL),(1126,'118 Prestwold Avenue','','','Syleham','Suffolk','England','IP21 DA62','+44 1667 125709','+44 880 118705','+44 1614 151695','Nathalie.Shahin@athena.systems','',NULL,NULL,NULL),(1127,'231 Glynde Close','','','Cockenzie and Port Seton','East Lothian','Scotland','EH32 AN50','+44 1433 134763','+44 1361 172082','+44 899 168930','Zack.Faulkingham@athena.systems','',NULL,NULL,NULL),(1128,'5 Lerwick Close','','','Eastbourne','East Sussex','England','BN21 ON71','+44 1301 165464','+44 1357 120867','+44 1361 135554','Marcelino.Laferty@athena.systems','',NULL,NULL,NULL),(1129,'243 Drury Park','','','Potters Bar','Hertfordshire','England','EN6 NF29','+44 1466 138293','+44 1193 103644','+44 1427 145242','Tobias.Mcaveney@athena.systems','',NULL,NULL,NULL),(1130,'18 New Inns Lane','','','Exeter','Devon','England','EX2 H196','+44 1499 155308','+44 1368 86454','+44 845 134812','Johnson.Delle@athena.systems','',NULL,NULL,NULL),(1131,'176 Fourth Street','','','Bishops Waltham','Hampshire','England','SO32 5E20','+44 916 174393','+44 1718 111126','+44 925 96854','Warner.Buley@athena.systems','',NULL,NULL,NULL),(1132,'250 Godson Road','','','Thornton-le-Clay','North Yorkshire','England','YO60 K594','+44 1061 90987','+44 932 136221','+44 1171 84123','Elvis.Daoust@athena.systems','',NULL,NULL,NULL),(1133,'38 Craythorne Close','','','Worcester','Worcester','England','WR2 G_73','+44 1181 133117','+44 1135 98286','+44 999 93675','Tama.Kasuboski@athena.systems','',NULL,NULL,NULL),(1134,'0 Aberdour Place','','','Princes Risborough','Buckinghamshire','England','HP27 ZJ81','+44 1281 168818','+44 987 142919','+44 1085 153578','Mikaela.Tricarico@athena.systems','',NULL,NULL,NULL),(1135,'166 Sir Alexander Close','','','Highland','Highland','Scotland','IV55 HO5','+44 1764 114399','+44 860 123666','+44 1275 179406','Annice.Thach@athena.systems','',NULL,NULL,NULL),(1136,'21 Flagg Wood Avenue','','','Darwen','Blackburn with Darwen','England','BB2 YT41','+44 1783 134865','','+44 816 159672','Lochotzki.Corporation@athena.systems','',NULL,NULL,NULL),(1137,'217 Summerfield Hall Lane','','','Longbridge Deverill','Wiltshire','England','BA12 0A66','+44 1014 171736','','+44 1064 93441','Bretos.Pty..Ltd.@athena.systems','',NULL,NULL,NULL),(1138,'3 Llandudno Road','','','Reigate and Banstead','Surrey','England','SM7 NZ71','+44 1171 105459','','+44 1042 101974','Baynes.Foundry@athena.systems','',NULL,NULL,NULL),(1139,'138 Tynron Grove','','','The Scottish Borders','The Scottish Borders','Scotland','EH44 EU21','+44 1071 141241','+44 1163 125792','+44 1568 93598','Christopher.Maret@athena.systems','',NULL,NULL,NULL),(1140,'242 Godson Road','','','Ipswich','Suffolk','England','IP1 9T66','+44 1794 172685','+44 980 140353','+44 1232 98532','Tyrone.Philippi@athena.systems','',NULL,NULL,NULL),(1141,'252 Little Casterton Road','','','Highland','Highland','Scotland','IV42 2T92','+44 1535 150002','+44 1586 179789','+44 1515 109904','Mervin.Boesen@athena.systems','',NULL,NULL,NULL),(1142,'147 Salwick Road','','','Strachur','Argyll and Bute','Scotland','PA27 MX25','+44 1095 93280','+44 1212 132462','+44 1117 91369','Bradley.Gillerist@athena.systems','',NULL,NULL,NULL),(1143,'192 Coalfield Way','','','Heswall','Wirral','England','CH61 7G42','+44 932 153750','+44 1536 174702','+44 968 147141','Gladys.Fuger@athena.systems','',NULL,NULL,NULL),(1144,'55 Joannies Watch','','','St Cuthbert Out','Somerset','England','BA5 OC56','+44 1652 88503','+44 1410 123166','+44 899 113821','Erica.Yavorsky@athena.systems','',NULL,NULL,NULL);
UNLOCK TABLES;
DROP TABLE IF EXISTS `contacts`;
CREATE TABLE `contacts` (
  `contactsid` int(10) unsigned NOT NULL,
  `title` enum('Mr','Ms','Mrs','Dr','Sir') DEFAULT NULL,
  `fname` varchar(45) DEFAULT NULL,
  `sname` varchar(45) DEFAULT NULL,
  `co_name` varchar(128) DEFAULT NULL,
  `role` varchar(128) DEFAULT NULL,
  `custid` int(10) unsigned DEFAULT NULL,
  `suppid` int(10) unsigned DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT '100',
  `logon` varchar(45) DEFAULT NULL,
  `init_pw` varchar(48) NOT NULL,
  `notes` text,
  `lastlogin` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`contactsid`)
);

LOCK TABLES `contacts` WRITE;
INSERT INTO `contacts` VALUES (1000,NULL,'Lilliam','Roberge','','',112,0,1040,'lilliamr','RVD4tCKv','',NULL),(1001,NULL,'Manuela','Zerko','','',109,0,1041,'manuelaz','BX9Hr4Gk','',NULL),(1002,NULL,'Ashely','Moncada','','',102,0,1042,'ashelym','GjpQXzyN','',NULL),(1003,NULL,'Alleen','Picasso','','',115,0,1043,'alleenp','h4rM32C6','',NULL),(1004,NULL,'Kip','Dopp','','',115,0,1044,'kipd','NT9cfRLW','',NULL),(1005,NULL,'Chase','Bossardet','','',105,0,1045,'chaseb','LTMNZHbx','',NULL),(1006,NULL,'Elijah','Gullion','','',115,0,1046,'elijahg','CMNtXfBv','',NULL),(1007,NULL,'Jarrett','Behanan','','',115,0,1047,'jarrettb','nLtJRByq','',NULL),(1008,NULL,'Lynwood','Cashon','','',109,0,1048,'lynwoodc','fdpxKB7y','',NULL),(1009,NULL,'Ali','Abajian','','',115,0,1049,'alia','mdbKJRhw','',NULL),(1010,NULL,'Gregoria','Mcken','','',106,0,1050,'gregoriam','pQGxvfD9','',NULL),(1011,NULL,'Janay','Hilger','','',108,0,1051,'janayh','pFbzfqgL','',NULL),(1012,NULL,'Stephanie','Craton','','',110,0,1052,'stephaniec','xVNyJDfw','',NULL),(1013,NULL,'Natividad','Mcbrayer','','',111,0,1053,'natividadm','DkWFVrq2','',NULL),(1014,NULL,'Wanetta','Kingsberry','','',101,0,1054,'wanettak','gp3ZTq8w','',NULL),(1015,NULL,'Sharell','Prez','','',114,0,1055,'sharellp','VRTbPzn6','',NULL),(1016,NULL,'Doyle','Hollinger','','',111,0,1056,'doyleh','MJF8vfdb','',NULL),(1017,NULL,'Caleb','Jumonville','','',102,0,1057,'calebj','DZpXfhjV','',NULL),(1018,NULL,'Dorsey','Mcphetridge','','',105,0,1058,'dorseym','Nm2pTrnh','',NULL),(1019,NULL,'Claude','Yip','','',103,0,1059,'claudey','Kx8vT4Cd','',NULL),(1020,NULL,'Cristobal','Knoth','','',101,0,1060,'cristobalk','kBLD3mpf','',NULL),(1021,NULL,'Kyung','Pfost','','',115,0,1061,'kyungp','WjRtYq3C','',NULL),(1022,NULL,'Kena','Laplant','','',112,0,1062,'kenal','zfGXVqDk','',NULL),(1023,NULL,'Gregoria','Helmes','','',110,0,1063,'gregoriah','QfYqB6NV','',NULL),(1024,NULL,'Lavonia','Plumb','','',111,0,1064,'lavoniap','wWxzmnXL','',NULL),(1025,NULL,'Alexa','Smull','','',102,0,1065,'alexas','nhRPJxwv','',NULL),(1026,NULL,'Vi','Dreiling','','',112,0,1066,'vid','tnm49NkG','',NULL),(1027,NULL,'Lenny','Zaidi','','',109,0,1067,'lennyz','zJxbQYdM','',NULL),(1028,NULL,'Geraldo','Hammitt','','',112,0,1068,'geraldoh','Pjq8WycG','',NULL),(1029,NULL,'Tuan','Brunn','','',100,0,1069,'tuanb','rNPZTHx8','',NULL),(1030,NULL,'Herb','Quirino','','',111,0,1070,'herbq','wWXt26GY','',NULL),(1031,NULL,'Nestor','Worsell','','',102,0,1071,'nestorw','MHCGNp8m','',NULL),(1032,NULL,'Bradley','Moler','','',110,0,1072,'bradleym','Kr3C8qFV','',NULL),(1033,NULL,'Emely','Lowney','','',102,0,1073,'emelyl','ygxXwpc8','',NULL),(1034,NULL,'Jeannie','Kawczynski','','',106,0,1074,'jeanniek','qTcYxfP3','',NULL),(1035,NULL,'Albertina','Faires','','',114,0,1075,'albertinaf','f3hdy7H6','',NULL),(1036,NULL,'Angelica','Towle','','',102,0,1076,'angelicat','8GzmRpdB','',NULL),(1037,NULL,'Myrtle','Rocquemore','','',108,0,1077,'myrtler','Yv3PLQ4T','',NULL),(1038,NULL,'Carolyn','Buntyn','','',102,0,1078,'carolynb','32NzfGM6','',NULL),(1039,NULL,'Ahmed','Brousard','','',101,0,1079,'ahmedb','qmHgFWhx','',NULL),(1040,NULL,'Irving','Taintor','','',115,0,1080,'irvingt','Xny3wtgJ','',NULL),(1041,NULL,'Benton','Borton','','',101,0,1081,'bentonb','qWFdnRK3','',NULL),(1042,NULL,'Vicente','Mose','','',110,0,1082,'vicentem','mYyChjPn','',NULL),(1043,NULL,'Douglas','Therriault','','',111,0,1083,'douglast','cg7CxNJG','',NULL),(1044,NULL,'Lucien','Delosier','','',110,0,1084,'luciend','pdTN29Ry','',NULL),(1045,NULL,'Nancie','Magarelli','','',114,0,1085,'nanciem','NrdtvxK2','',NULL),(1046,NULL,'Nohemi','Deiters','','',105,0,1086,'nohemid','BnVqXGRh','',NULL),(1047,NULL,'Kandis','Raponi','','',107,0,1087,'kandisr','TWq7M6HQ','',NULL),(1048,NULL,'Robin','Fair','','',113,0,1088,'robinf','x6ZbrYhv','',NULL),(1049,NULL,'Jami','Korb','','',103,0,1089,'jamik','RjdVHB6z','',NULL),(1050,NULL,'Nicole','Haegele','','',115,0,1090,'nicoleh','4fbKkHRX','',NULL),(1051,NULL,'Carmen','Colli','','',102,0,1091,'carmenc','PwYnqLW2','',NULL),(1052,NULL,'Robbie','Kivisto','','',115,0,1092,'robbiek','HfZnDt2b','',NULL),(1053,NULL,'Arthur','Stmichel','','',106,0,1093,'arthurs','rwkbYjLX','',NULL),(1054,NULL,'Dino','Dockal','','',115,0,1094,'dinod','NHC6tMLk','',NULL),(1055,NULL,'Johnathon','Leetch','','',100,0,1095,'johnathonl','d6R3V8Tp','',NULL),(1056,NULL,'Noah','Marandi','','',110,0,1096,'noahm','HDM7vzRK','',NULL),(1057,NULL,'Alyce','Mccunn','','',109,0,1097,'alycem','qwXm92rK','',NULL),(1058,NULL,'Donnetta','Turnpaugh','','',109,0,1098,'donnettat','n3RLd2F8','',NULL),(1059,NULL,'Allen','Lewczyk','','',111,0,1099,'allenl','7FrQPyfq','',NULL),(1060,NULL,'Natisha','Hendron','','',111,0,1100,'natishah','KfPybCXt','',NULL),(1061,NULL,'Jeanett','Bostwick','','',100,0,1101,'jeanettb','gFcQrwTv','',NULL),(1062,NULL,'Reita','Paisley','','',101,0,1102,'reitap','wQcGFxh8','',NULL),(1063,NULL,'Tyron','Bigusiak','','',103,0,1103,'tyronb','6nHZ4KCj','',NULL),(1064,NULL,'Wade','Voit','','',101,0,1104,'wadev','NgMmDtBh','',NULL),(1065,NULL,'Domingo','Sagel','','',107,0,1105,'domingos','yT98RtkY','',NULL),(1066,NULL,'Bobbie','Nagelkirk','','',104,0,1106,'bobbien','vb6jctGh','',NULL),(1067,NULL,'Basil','Finlay','','',102,0,1107,'basilf','8RfJ2F93','',NULL),(1068,NULL,'Oren','Hayward','','',100,0,1108,'orenh','bQVx2kvc','',NULL),(1069,NULL,'Fernande','Pegues','','',109,0,1109,'fernandep','t9MJYdR8','',NULL),(1070,NULL,'Thresa','Pacini','','',107,0,1110,'thresap','4W2bhmG6','',NULL),(1071,NULL,'Salena','Wibeto','','',110,0,1111,'salenaw','JM38zVFW','',NULL),(1072,NULL,'Nita','Laroche','','',110,0,1112,'nital','VnRgF8kZ','',NULL),(1073,NULL,'Margart','Birrueta','','',101,0,1113,'margartb','bRdryfgM','',NULL),(1074,NULL,'Rhonda','Lemmer','','',104,0,1114,'rhondal','VTrdGBqF','',NULL),(1075,NULL,'Ervin','Kershner','','',104,0,1115,'ervink','Z9bcHvXF','',NULL),(1076,NULL,'Garland','Coffey','','',107,0,1116,'garlandc','QdWcVN4G','',NULL),(1077,NULL,'Eduardo','Hartley','','',110,0,1117,'eduardoh','qCHDrnVM','',NULL),(1078,NULL,'Andrea','Sheskey','','',108,0,1118,'andreas','QtwjkCTV','',NULL),(1079,NULL,'Darwin','Zotos','','',101,0,1119,'darwinz','p4WdqKvy','',NULL),(1080,NULL,'Hoyt','Vieths','','',104,0,1120,'hoytv','6gWdbjxM','',NULL),(1081,NULL,'Aletha','Curvin','','',109,0,1121,'alethac','KHvcWJC4','',NULL),(1082,NULL,'Jerilyn','Miserendino','','',110,0,1122,'jerilynm','vQ7gXMpL','',NULL),(1083,NULL,'Odessa','Sanjose','','',110,0,1123,'odessas','LCfkhbVN','',NULL),(1084,NULL,'Alex','Curtice','','',106,0,1124,'alexc','DQNrFKYZ','',NULL),(1085,NULL,'Shameka','Atherton','','',105,0,1125,'shamekaa','bhP9qyHd','',NULL),(1086,NULL,'Nathalie','Shahin','','',106,0,1126,'nathalies','JHY2BKg9','',NULL),(1087,NULL,'Zack','Faulkingham','','',111,0,1127,'zackf','thPC9bKZ','',NULL),(1088,NULL,'Marcelino','Laferty','','',111,0,1128,'marcelinol','zPtXkp9r','',NULL),(1089,NULL,'Tobias','Mcaveney','','',109,0,1129,'tobiasm','mKfDrYMq','',NULL),(1090,NULL,'Johnson','Delle','','',109,0,1130,'johnsond','m7H4dCMD','',NULL),(1091,NULL,'Warner','Buley','','',106,0,1131,'warnerb','xPcfbrXq','',NULL),(1092,NULL,'Elvis','Daoust','','',109,0,1132,'elvisd','WcMyPQv7','',NULL),(1093,NULL,'Tama','Kasuboski','','',103,0,1133,'tamak','h9gVNwfq','',NULL),(1094,NULL,'Mikaela','Tricarico','','',105,0,1134,'mikaelat','8yrB9LDj','',NULL),(1095,NULL,'Annice','Thach','','',114,0,1135,'annicet','4PQr8cwF','',NULL),(1096,NULL,'Christopher','Maret','','',0,100,1139,'christopherm','QpgJNnMP','',NULL),(1097,NULL,'Tyrone','Philippi','','',0,100,1140,'tyronep','j3YTgrGP','',NULL),(1098,NULL,'Mervin','Boesen','','',0,100,1141,'mervinb','6HQ34gCb','',NULL),(1099,NULL,'Bradley','Gillerist','','',0,101,1142,'bradleyg','8PDbvnmF','',NULL),(1100,NULL,'Gladys','Fuger','','',0,101,1143,'gladysf','BDnby6c3','',NULL),(1101,NULL,'Erica','Yavorsky','','',0,102,1144,'ericay','XzykhRfr','',NULL);
UNLOCK TABLES;
DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer` (
  `custid` int(10) unsigned NOT NULL,
  `co_name` varchar(128) NOT NULL,
  `contact` varchar(128) DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT NULL,
  `inv_email` varchar(255) DEFAULT NULL,
  `colour` varchar(7) DEFAULT '#2c0673',
  `init_pw` varchar(48) NOT NULL,
  PRIMARY KEY (`custid`)
);

LOCK TABLES `customer` WRITE;
INSERT INTO `customer` VALUES (100,'Lopus Pty. Ltd.',NULL,1024,'','#c2d99f',''),(101,'Overly Ltd',NULL,1025,'','#2c0673',''),(102,'Buden and Co.',NULL,1026,'','#2c0673',''),(103,'Likio and Sons',NULL,1027,'','#2c0673',''),(104,'Houseal Foundry',NULL,1028,'','#d5e1ad',''),(105,'Tyre Logistics',NULL,1029,'','#b39788',''),(106,'Hodges Co. Ltd',NULL,1030,'','#af8071',''),(107,'Tahir Studios',NULL,1031,'','#e00cd6',''),(108,'Barragan Associates',NULL,1032,'','#f6078b',''),(109,'Tieman Foundry',NULL,1033,'','#b7dad6',''),(110,'Escobar Inc.',NULL,1034,'','#2c0673',''),(111,'Isaacks Pty. Ltd.',NULL,1035,'','#2c0673',''),(112,'Goldfischer Agency',NULL,1036,'','#794a54',''),(113,'Lenci Products',NULL,1037,'','#2c0673',''),(114,'Kivisto Associates',NULL,1038,'','#55b915',''),(115,'Vandenberghe Ltd',NULL,1039,'','#1f143c','');
UNLOCK TABLES;
DROP TABLE IF EXISTS `invoices`;
CREATE TABLE `invoices` (
  `invoicesid` int(10) unsigned NOT NULL,
  `custid` int(10) unsigned NOT NULL,
  `contactsid` int(10) unsigned DEFAULT NULL,
  `incept` int(10) unsigned NOT NULL,
  `paid` int(10) unsigned DEFAULT '0',
  `content` text,
  `price` decimal(10,2) DEFAULT NULL,
  `notes` text,
  PRIMARY KEY (`invoicesid`),
  KEY `FK_invoices_1` (`custid`),
  CONSTRAINT `FK_invoices_1` FOREIGN KEY (`custid`) REFERENCES `customer` (`custid`) ON DELETE NO ACTION ON UPDATE NO ACTION
);

LOCK TABLES `invoices` WRITE;
INSERT INTO `invoices` VALUES (100,109,1008,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',618.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(101,108,1011,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',556.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(102,110,1083,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',894.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(103,101,1079,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1147.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(104,110,1023,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',212.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(105,111,1043,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',477.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(106,112,1026,1434639747,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',410.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(107,101,1073,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',143.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(108,105,1018,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',884.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(109,111,1060,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',981.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(110,108,1011,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',756.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(111,106,1053,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1001.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(112,106,1034,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',203.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(113,111,1030,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',774.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(114,102,1033,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1017.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(115,115,1050,1434639748,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1109.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(116,110,1042,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',9.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(117,112,1022,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',988.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(118,111,1059,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1062.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(119,105,1085,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1019.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(120,100,1068,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',786.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(121,106,1084,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',885.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(122,103,1093,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',285.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(123,110,1032,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1122.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(124,105,1018,1434639749,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',502.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(125,107,1076,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',834.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(126,114,1095,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',976.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(127,105,1094,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',413.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(128,110,1042,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',177.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(129,109,1058,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1023.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(130,113,1048,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',788.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(131,104,1080,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',281.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(132,105,1018,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',327.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(133,100,1029,1434639750,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',439.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(134,110,1023,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',545.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(135,109,1001,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',728.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(136,105,1094,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',911.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(137,114,1035,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',560.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(138,115,1050,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',563.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(139,106,1084,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',944.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(140,112,1022,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',259.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(141,106,1053,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',304.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(142,115,1050,1434639751,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',396.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(143,112,1026,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1001.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(144,105,1018,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',143.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(145,101,1062,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',857.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(146,113,1048,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',384.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(147,100,1055,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',62.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(148,102,1051,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',201.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(149,114,1035,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',599.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(150,115,1004,1434639752,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1011.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(151,101,1020,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',938.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(152,112,1028,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',946.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(153,102,1033,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',320.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(154,104,1075,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1157.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(155,102,1036,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',484.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(156,106,1084,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',390.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(157,109,1092,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',811.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(158,107,1070,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',149.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat'),(159,113,1048,1434639753,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',810.00,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat');
UNLOCK TABLES;
DROP TABLE IF EXISTS `quotes`;
CREATE TABLE `quotes` (
  `quotesid` int(10) unsigned NOT NULL,
  `staffid` int(10) unsigned DEFAULT '1',
  `custid` int(10) unsigned NOT NULL,
  `contactsid` int(10) unsigned DEFAULT NULL,
  `incept` int(10) unsigned NOT NULL,
  `agree` int(10) unsigned NOT NULL,
  `live` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `content` text NOT NULL,
  `notes` text,
  `origin` varchar(10) DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`quotesid`),
  KEY `FK_quotes_1` (`custid`),
  KEY `FK_quotes_2` (`staffid`),
  KEY `FK_quotes_3` (`contactsid`),
  CONSTRAINT `FK_quotes_1` FOREIGN KEY (`custid`) REFERENCES `customer` (`custid`) ON DELETE NO ACTION ON UPDATE NO ACTION
);

LOCK TABLES `quotes` WRITE;
INSERT INTO `quotes` VALUES (100,118,103,1093,1434639742,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,465.00),(101,107,100,1061,1434639742,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,460.00),(102,110,103,1049,1434639742,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,329.00),(103,110,105,1094,1434639743,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,589.00),(104,108,113,1048,1434639743,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,818.00),(105,116,105,1094,1434639743,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,14.00),(106,119,103,1063,1434639743,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,608.00),(107,113,100,1061,1434639744,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,1068.00),(108,115,107,1065,1434639744,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,467.00),(109,117,102,1036,1434639744,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,632.00),(110,118,106,1091,1434639744,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,612.00),(111,108,113,1048,1434639745,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,285.00),(112,120,108,1078,1434639745,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,939.00),(113,111,100,1029,1434639745,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,744.00),(114,121,111,1013,1434639745,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,870.00),(115,114,114,1045,1434639746,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,322.00),(116,111,115,1004,1434639746,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,271.00),(117,122,105,1005,1434639746,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,231.00),(118,113,100,1061,1434639746,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,501.00),(119,119,105,1094,1434639746,0,1,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',NULL,697.00);
UNLOCK TABLES;
DROP TABLE IF EXISTS `staff`;
CREATE TABLE `staff` (
  `staffid` int(10) unsigned NOT NULL,
  `fname` varchar(45) NOT NULL,
  `sname` varchar(45) DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT NULL,
  `logon` varchar(45) DEFAULT NULL,
  `init_pw` varchar(48) NOT NULL,
  `notes` text,
  `jobtitle` varchar(128) DEFAULT NULL,
  `content` text,
  `status` enum('active','retired','left','temp') NOT NULL,
  `level` smallint(5) unsigned NOT NULL DEFAULT '10',
  `teamsid` int(10) unsigned NOT NULL,
  `timesheet` tinyint(3) unsigned DEFAULT '1',
  `holiday` smallint(6) DEFAULT '34',
  `lastlogin` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`staffid`)
);

LOCK TABLES `staff` WRITE;
INSERT INTO `staff` VALUES (100,'System','Administrator',100,'root','zNE9ax5g10mwzrMxh',NULL,'',NULL,'active',1,0,1,1,1434639710),(101,'Dorthea','Commiskey',1000,'dc','ZmvpwLdW',NULL,'',NULL,'active',10,0,1,34,NULL),(102,'Sharice','Buress',1001,'sb','4rmdTVKn',NULL,'',NULL,'active',10,0,1,34,NULL),(103,'Dortha','Dobias',1002,'dd','pg6KQTGv',NULL,'',NULL,'active',10,0,1,34,NULL),(104,'Julie','Canterberry',1003,'jc','2dj8RT9z',NULL,'',NULL,'active',10,0,1,34,NULL),(105,'Lamar','Bunck',1004,'lb','cpZ4Xzgq',NULL,'',NULL,'active',10,0,1,34,NULL),(106,'Doyle','Mccole',1005,'dm','pzywBDgL',NULL,'',NULL,'active',10,0,1,34,NULL),(107,'Jay','Jubilee',1006,'jj','Z9Yg7pcy',NULL,'',NULL,'active',10,0,1,34,NULL),(108,'Lynwood','Foulger',1007,'lf','x64pLWyj',NULL,'',NULL,'active',10,0,1,34,NULL),(109,'Howard','Schmandt',1008,'hs','HQF3khqd',NULL,'',NULL,'active',10,0,1,34,NULL),(110,'Everette','Ximines',1009,'ex','wByCnYmP',NULL,'',NULL,'active',10,0,1,34,NULL),(111,'Carlton','Miskin',1010,'cm','cRMjCqhH',NULL,'',NULL,'active',10,0,1,34,NULL),(112,'Ok','Ridgle',1011,'or','hK4QWCrd',NULL,'',NULL,'active',10,0,1,34,NULL),(113,'Luann','Karakas',1012,'lk','cFJ9PVbr',NULL,'',NULL,'active',10,0,1,34,NULL),(114,'Tijuana','Traicoff',1013,'tt','jbY27vPg',NULL,'',NULL,'active',10,0,1,34,NULL),(115,'Giovanna','Stutesman',1014,'gs','bXL8TfPr',NULL,'',NULL,'active',10,0,1,34,NULL),(116,'Cassondra','Lehenbauer',1015,'cl','dZyn63G2',NULL,'',NULL,'active',10,0,1,34,NULL),(117,'Paulina','Toles',1016,'pt','YmcyqdQj',NULL,'',NULL,'active',10,0,1,34,NULL),(118,'Caryn','Urbanik',1017,'cu','dBT3ZQqG',NULL,'',NULL,'active',10,0,1,34,NULL),(119,'Don','Aills',1018,'da','GR4HxPF9',NULL,'',NULL,'active',10,0,1,34,NULL),(120,'Kim','Jaskolka',1019,'kj','tfDjNZ7C',NULL,'',NULL,'active',10,0,1,34,NULL),(121,'Tobias','Furubotten',1020,'tf','LJDWqGFy',NULL,'',NULL,'active',10,0,1,34,NULL),(122,'Ramon','Emerton',1021,'re','zB4qYDZJ',NULL,'',NULL,'active',10,0,1,34,NULL),(123,'Vern','Beiley',1022,'vb','9mHn8fL3',NULL,'',NULL,'active',10,0,1,34,NULL),(124,'Jamal','Fishburne',1023,'jf','p4Xf3RGw',NULL,'',NULL,'active',10,0,1,34,NULL);
UNLOCK TABLES;
DROP TABLE IF EXISTS `supplier`;
CREATE TABLE `supplier` (
  `suppid` int(10) unsigned NOT NULL,
  `co_name` varchar(128) NOT NULL,
  `contact` varchar(128) DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT NULL,
  `inv_email` varchar(255) DEFAULT NULL,
  `colour` varchar(7) DEFAULT '#2c0673',
  `init_pw` varchar(48) NOT NULL,
  PRIMARY KEY (`suppid`)
);

LOCK TABLES `supplier` WRITE;
INSERT INTO `supplier` VALUES (100,'Lochotzki Corporation',NULL,1136,'','#3e514b',''),(101,'Bretos Pty. Ltd.',NULL,1137,'','#2706da',''),(102,'Baynes Foundry',NULL,1138,'','#2c0673','');
UNLOCK TABLES;




GRANT ALL ON phpstartpoint.* TO athena@'localhost' IDENTIFIED BY 'PHPSPPWD';
FLUSH PRIVILEGES;

|;

	my $sqlFile = '/tmp/phpstartpoint.sql';

	open( FH, ">$sqlFile" );
	print FH $sql;
	close(FH);

	print "Importing the example database into MySQL\n";

	my $tmpFile = '/tmp/Athena.MyAcc' . time();
	open( FHOUT, ">$tmpFile" );
	print FHOUT "[mysql]\nuser=root\npassword=$sqlRootPwd";
	close(FHOUT);

	# Import DB into MySQL server
	my $cmd = "mysql --defaults-extra-file=$tmpFile < $sqlFile";
	system($cmd);

	unlink($sqlFile);
	unlink($tmpFile);

	print "Added example database\n";

	return 1;

}

sub getPlatform() {
	my $q = `cat /etc/*-release`;
	if ( $q =~ /SUSE/s ) {
		return 'suse';
	}
	if ( $q =~ /Ubuntu/s ) {
		return 'ubuntu';
	}
	if ( $q =~ /LinuxMint/s ) {
		return 'mint';
	}
	if ( $q =~ /Debian/s ) {
		return 'debian';
	}
	if ( $q =~ /Fedora/s ) {
		return 'fedora';
	}
	if ( $q =~ /Red Hat/s ) {
		return 'redhat';
	}
	return 'unknown';
}
