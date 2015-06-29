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

&makeDirectory();

&doDatabase();

print "$spacer\n\n";

my $doApace = '';
&setupApache;

my $dbh = DBI->connect( "DBI:mysql:$db:$host", $dbuser, $dbpw );

# Generic footer for the PHP pages
my $htmlFoot = '
<?php
include "../tmpl/footer.php";
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

&outputCredFile();

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

## SQL query to get Table names from DB
my $sqltext = "show tables";
my $sth     = $dbh->prepare($sqltext);
$sth->execute();

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
include "../tmpl/header.php"; 
 

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
include "../tmpl/header.php";
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
include "../tmpl/header.php";


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
include "../tmpl/header.php";
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
	  . $getAllFunction
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
&makeStyleSheet();

$navHTML =~ s/ \| $//s;

$navHTML = <<EOF;
$navHTML
</ul></div>
</div></nav>
EOF

&makeTemplate();

$htmlIndex .= <<EOF;
<div style="margin:60px;">phpStartPoint gives developers a way to create a coding <br>
environment quickly to allow rapid development of solutions<br> 
blah blah blah ... <br><br><br>
tl:dr use it if helps :) </div>
EOF

print "$spacer\nCreating the Index web page in $dir/www/index.php\n";
open( FH, ">$dir/www/index.php" );
print FH '<?php include "../tmpl/header.php"; ?>' . $htmlIndex . '<?php include "../tmpl/footer.php";?>';
close(FH);

$sth->finish;

# Write out the DB Class file
&makeDBClass();

&doPermissions();

print "Credentials file is stored at $dir/etc/db.conf\n\n";
print "PHP Classes files are stored at $dir/lib\n\n";
print "Web pages are stored at $dir/www\n\n";
if ( $doApace eq 'y' ) {
	print "The Apache web root is $dir/www\n\n";
	print "Go to http://$domain in a brower\n\n";
}

exit;

sub outputCredFile {

	my $credConf = "db=$db\ndbpw=$dbpw\ndbuser=$dbuser\nhost=$host";
	open( FH, ">$dir/etc/db.conf" );
	print FH $credConf;
	close(FH);

}

sub doDatabase {

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

}

sub makeDirectory {

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

	system("mkdir -p $dir");
	mkdir( $dir . '/etc' );
	mkdir( $dir . '/tmpl' );
	mkdir( $dir . '/lib' );
	mkdir( $dir . '/www' );
	mkdir( $dir . '/www/css' );
	system("chown -R $user:$user $dir");

}

sub makeStyleSheet {

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

}

sub makeTemplate {

	my $bootstrap = '<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css">
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
<link href="/css/sitestyle.css" rel="stylesheet"> 
';

	print "$spacer\nCreating headers and footers for the web pages $dir/inc\n";
	open( FH, ">$dir/tmpl/header.php" );
	print FH '<!DOCTYPE html><html><head><meta charset="UTF-8">
<title></title>
' . $bootstrap . '
</head><body>' . $navHTML;
	close(FH);

	open( FH, ">$dir/tmpl/footer.php" );
	print FH '</body></html>';
	close(FH);

}

sub doPermissions {

	system("chown -R $user:$user $dir");

	if ( $platform =~ /^(fedora|redhat)$/ ) {
		my $parentDir = $dir;
		$parentDir =~ s/\/phpstartpoint//;
		print "Doing SE permissions on $parentDir\n";
		system("semanage fcontext -a -t public_content_rw_t \"$parentDir(/.*)?\" > /dev/null 2>&1");
		system("restorecon -R -v $parentDir/ > /dev/null 2>&1");
	}

}

sub getDBName {
	print "Enter the name of the database you would like to analyse: ";
	my $ans = <STDIN>;
	chomp $ans;
	if ( $ans eq '' ) { $ans = '' }
	return $ans;
}

sub getDBUser {
	print "Enter the username to connect to the database: ";
	my $ans = <STDIN>;
	chomp $ans;
	if ( $ans eq '' ) { $ans = '' }
	return $ans;
}

sub getDBPwd {
	print "Enter the password to connect to the database: ";
	ReadMode 2;
	my $ans = <STDIN>;
	ReadMode 1;
	chomp $ans;
	if ( $ans eq '' ) { $ans = '' }
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
	ServerName $domain
	ServerAlias dev.$domain
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
		open( FH, ">/etc/apache2/sites-available/$domain.conf" );
		print FH $apache2Conf;
		close(FH);
		print "\n\nApache2 Conf file written to /etc/apache2/sites-available/$domain.conf\n\n";
		chdir('/etc/apache2/sites-available');
		system("a2ensite $domain.conf");
	}
	elsif ( -e "/etc/apache2/vhosts.d/" ) {
		open( FH, ">/etc/apache2/vhosts.d/$domain.conf" );
		print FH $apache2Conf;
		close(FH);
		print "\n\nApache2 Conf file written to /etc/apache2/vhosts.d/$domain.conf\n\n";
	}
	elsif ( -e "/etc/httpd/conf.d/" ) {
		open( FH, ">/etc/httpd/conf.d/$domain.conf" );
		print FH $apache2Conf;
		close(FH);
		print "\n\nApache2 Conf file written to /etc/httpd/conf.d/$domain.conf\n\n";
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
            $config = parse_ini_file('/etc/athenace/athena.conf');
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
            //echo $query ."\n";
            #$results[] = array();
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
                return $this->db->insert_id;
            }
            
            return false;
        }

        public function update($table, $data, $format, $where, $where_format, $limit=1)
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
            $stmt = $this->db->prepare("UPDATE {$table} SET {$placeholders} WHERE {$where_clause} LIMIT {$limit}");
            // echo "UPDATE {$table} SET {$placeholders} WHERE {$where_clause}";exit;
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
            
            if(!isset($results)){
            	return false;
            }
            
            return $results;
        }

        public function delete($table, $id, $idField, $limit=1)
        {
            
            // Prepary our query for binding
            $stmt = $this->db->prepare("DELETE FROM {$table} WHERE {$idField} = ? LIMIT {$limit}");
            
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
  `notes` text,
  `lastlogin` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`contactsid`)
);

DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer` (
  `custid` int(10) unsigned NOT NULL,
  `co_name` varchar(128) NOT NULL,
  `contact` varchar(128) DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT NULL,
  `inv_email` varchar(255) DEFAULT NULL,
  `colour` varchar(7) DEFAULT '#2c0673',
  PRIMARY KEY (`custid`)
);

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

DROP TABLE IF EXISTS `staff`;
CREATE TABLE `staff` (
  `staffid` int(10) unsigned NOT NULL,
  `fname` varchar(45) NOT NULL,
  `sname` varchar(45) DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT NULL,
  `notes` text,
  `jobtitle` varchar(128) DEFAULT NULL,
  `content` text,
  `status` enum('active','retired','left','temp') NOT NULL,
  `lastlogin` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`staffid`)
);

DROP TABLE IF EXISTS `supplier`;
CREATE TABLE `supplier` (
  `suppid` int(10) unsigned NOT NULL,
  `co_name` varchar(128) NOT NULL,
  `contact` varchar(128) DEFAULT NULL,
  `addsid` int(10) unsigned DEFAULT NULL,
  `inv_email` varchar(255) DEFAULT NULL,
  `colour` varchar(7) DEFAULT '#2c0673',
  PRIMARY KEY (`suppid`)
);

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
