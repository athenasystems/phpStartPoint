#!/usr/bin/perl
use strict;
###########################################################
# Edit this section to reflect your MySQL database details
my $db     = '';
my $dbpw   = '';
my $dbuser = '';
my $dbhost = 'localhost';
my $domain = '';
###########################################################
use DBI;
use Term::ReadKey;

my $dir = $ENV{"HOME"};
if ( $dir eq '/root' ) { $dir = '/srv/www' }
my $user = ( defined( $ENV{"SUDO_USER"} ) ) ? $ENV{"SUDO_USER"} : $ENV{"USER"};
my $platform = &getPlatform();

system("clear");
my $spacer = '------------------------------------------------------------------------------';
print "$spacer\nRunning ... phpStartPoint\n$spacer";
my $runType = 'none';

while ( $runType !~ /(normal|www|example)/ ) {
	&getRunType();
}

&makeDirectory();

&doDatabase();

&outputCredFile();

my $doApace = '';
if ( ( $runType eq 'example' ) || ( $runType eq 'www' ) ) {
	&setupApache;
}

my $dbh = DBI->connect( "DBI:mysql:$db:$dbhost", $dbuser, $dbpw );

# Generic footer for the PHP pages
my $htmlFoot = '
<?php
include "' . $dir . '/tmpl/footer.php";
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

# Strings to use for concatenation in the Table and Column loops
my $allPHPClasses = '';
my $phpOutTxtFull = '';
my $htmlIndex     = '';
my $outFormatsTxt = '';
my $navHTML       = '';

print "\n$spacer\nRunning phpStartPoint on the $db database...\n";

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
$pageTitle = "' . $capTableName . ' Page";
include "' . $dir . '/tmpl/header.php"; 
 

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
$pageTitle = "' . $capTableName . ' Page";
include "' . $dir . '/tmpl/header.php";
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
$pageTitle = "' . $capTableName . ' Page";
include "' . $dir . '/tmpl/header.php";


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
$pageTitle = "' . $capTableName . ' Page";
include "' . $dir . '/tmpl/header.php";
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
	my $htmlH1  = '<h1>' . $capTableName . '</h1>';
	my $htmlAdd = '<div><a href="add.php">Add an Item to the ' . $capTableName . ' table</a></div><br>';

	print "creating web pages ";

	open( FH, ">$dir/www/$table/index.php" );
	print FH $htmlHead . $htmlH1 . $htmlAdd . $htmlListBody . $htmlFoot;
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

	my $classHeader = "
class $capTableName
{
";

	my $phpClass =
	    $classHeader
	  . $privateVariables
	  . $getsAndSets
	  . $getAllFunction
	  . $loadFunction
	  . $saveToDBFunction
	  . $insertToDBFunction
	  . $deleteFromDBFunction . '}';

	$allPHPClasses .=
	    $classHeader
	  . $privateVariables
	  . $getsAndSets
	  . $getAllFunction
	  . $loadFunction
	  . $saveToDBFunction
	  . $insertToDBFunction
	  . $deleteFromDBFunction . '}';

	print "& PHP $capTableName Class\n";
	open( FH, ">$dir/lib/$capTableName.php" );
	print FH '<?php' . "\n" . $bindValues . $phpClass . "
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

&makeNav($navHTML);

&makeTemplate();

$htmlIndex .= <<EOF;
<div style="margin:60px;">phpStartPoint gives developers a way to create a coding <br>
environment quickly to allow rapid development of solutions<br> 
blah blah blah ... <br><br><br>
tl:dr use it if helps :) </div>
EOF

print "Creating the Index web page in $dir/www/index.php\n";
open( FH, ">$dir/www/index.php" );
print FH '<?php 
$pageTitle = "Home Page";
include "../tmpl/header.php"; ?>' . $htmlIndex . '<?php include "../tmpl/footer.php";?>';
close(FH);

$sth->finish;

# Write out the DB Class file
&makeDBClass();

&doPermissions();

print "Credentials file is stored at $dir/etc/db.conf\n";
print "PHP Classes files are stored at $dir/lib\n";
print "Web pages are stored at $dir/www\n";
if ( ( $runType eq 'example' ) || ( $runType eq 'www' ) ) {
	print "The Apache web root is $dir/www\n";
	print "Go to http://$domain in a brower\n";
}

exit;

###############################################################################

sub getRunType() {
	print "
Type a number 1, 2 or 3   

1. To run phpStartPoint on your database  

2. To run phpStartPoint on your database and setup an Apache Virtual Host

3. To run phpStartPoint on the example database, setup an Apache Virtual Host

$spacer
";
	my $ans = <STDIN>;
	chomp $ans;

	if    ( $ans eq 1 ) { $runType = 'normal'; }
	elsif ( $ans eq 2 ) { $runType = 'www'; }
	elsif ( $ans eq 3 ) { $runType = 'example'; }
	else                { print "Not a valid answer\n\n"; }
	my $userLevel = $>;
	if ( ($userLevel) && ( $runType =~ /(example|www)/ ) ) {
		print "\nGotta be root to run that option!\n\nTry sudo ./phpStartPoint.pl\n\n";
		exit;
	}
}

sub outputCredFile {

	my $credConf = "db=$db\ndbpw=$dbpw\ndbuser=$dbuser\nhost=$dbhost";
	open( FH, ">$dir/etc/db.conf" );
	print FH $credConf;
	close(FH);

}

sub doDatabase {

	if ( $runType eq 'example' ) {
		$db     = 'phpstartpoint';
		$dbpw   = 'PHPSPPWD';
		$dbuser = 'athena';
		$dbhost = 'localhost';

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
	print "Default is $dir meaning the files will live in $dir/phpstartpoint\n($dir): ";
	ReadMode 1;
	my $userdir = <STDIN>;
	chomp $userdir;

	if ( ( !defined($userdir) ) || ( $userdir eq '' ) ) {
		$dir .= '/phpstartpoint';
	}
	else {
		$dir = $userdir . '/phpstartpoint';
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

sub makeNav() {

	my $nav = shift;

	$nav =~ s/ \| $//s;

	$navHTML = '
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
			<a class="navbar-brand" href="/">phpStartPoint</a>
		</div>
		<div id="navbar" class="navbar-collapse collapse">
			<ul class="nav navbar-nav">';
	$navHTML .= <<EOF;
$nav
</ul></div>
</div></nav>
EOF

	return $navHTML;

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
<title><?php echo $pageTitle; ?></title>
' . $bootstrap . '
</head><body>' . $navHTML;
	close(FH);

	open( FH, ">$dir/tmpl/footer.php" );
	print FH '</body></html>';
	close(FH);

}

sub doPermissions {

	system("chown -R $user:$user $dir");

	if ( $platform =~ /^(fedora|redhat|centos)$/ ) {
		my $parentDir = $dir;
		$parentDir =~ s/\/phpstartpoint//;
		print "Doing SE permissions on $parentDir\n";
		system("semanage fcontext -a -t httpd_sys_content_t \"$parentDir(/.*)?\" > /dev/null 2>&1");
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
	if ( $ans eq '' ) { $ans = 'dev.phpstartpoint.com'; }
	return $ans;
}

sub setupApache {

	#	my $apacheInstalled = `dpkg --get-selections | grep apache`;
	if ( ( -e "/etc/apache2" ) || ( -e "/etc/httpd" ) ) {

		if ( $runType =~ /(example|www)/ ) {
			$domain = 'dev.phpstartpoint.com';
		}
		if ( $domain eq '' ) { $domain = &getDomain(); }

		# Write out the Apache2 Conf file
		&makeApacheConf();
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

	print "Making the Apache Virtual Host conf file\n";

	if ( -e "/etc/apache2/sites-available" ) {
		open( FH, ">/etc/apache2/sites-available/$domain.conf" );
		print FH $apache2Conf;
		close(FH);
		print "Apache2 Conf file written to /etc/apache2/sites-available/$domain.conf\n";
		chdir('/etc/apache2/sites-available');
		system("a2ensite $domain.conf");
	}
	elsif ( -e "/etc/apache2/vhosts.d/" ) {
		open( FH, ">/etc/apache2/vhosts.d/$domain.conf" );
		print FH $apache2Conf;
		close(FH);
		print "Apache2 Conf file written to /etc/apache2/vhosts.d/$domain.conf\n";
	}
	elsif ( -e "/etc/httpd/conf.d/" ) {
		open( FH, ">/etc/httpd/conf.d/$domain.conf" );
		print FH $apache2Conf;
		close(FH);
		print "Apache2 Conf file written to /etc/httpd/conf.d/$domain.conf\n";
	}

	if ( $platform eq 'suse' ) {
		system("rcapache2 restart");
	}
	if ( $platform =~ /^(debian|ubuntu|mint)$/ ) {
		system("service apache2 restart");
	}
	if ( $platform =~ /^(fedora|redhat|centos)$/ ) {
		system("service httpd restart");
	}

	print "Adding '127.0.0.1  $domain' to the /etc/hosts file\n";

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
            $config = parse_ini_file('ATHENADIR/etc/db.conf');
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

	$dbclassFile =~ s/ATHENADIR/$dir/s;

	open( FH, ">$dir/lib/DB.php" );
	print FH $dbclassFile;
	close(FH);

}

sub makeDB() {
	my $sqlRootPwd = shift;

	my $sql = q|DROP DATABASE IF EXISTS phpstartpoint;
CREATE DATABASE phpstartpoint;
USE phpstartpoint;


DROP TABLE IF EXISTS `contacts`;
CREATE TABLE `contacts` (
  `contactsid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `fname` varchar(45) DEFAULT NULL,
  `sname` varchar(45) DEFAULT NULL,
  `role` varchar(128) DEFAULT NULL,
  `co_name` varchar(128) DEFAULT NULL,
  `customerid` int(10) unsigned DEFAULT NULL,
  `supplierid` int(10) unsigned DEFAULT NULL,
  `notes` text,
  `lastlogin` int(10) unsigned DEFAULT NULL,
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
  PRIMARY KEY (`contactsid`)
) ENGINE=InnoDB AUTO_INCREMENT=1198 DEFAULT CHARSET=latin1;
LOCK TABLES `contacts` WRITE;
INSERT INTO `contacts` VALUES (1102,'Terrence','Hlavka','','Galletta and Co.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435871835,'27 Clara Mount Road',NULL,NULL,'Queensbury','Bradford','England','BD5 DA69','+44 1305 164953','+44 1446 97656','+44 1591 136232','terrence.hlavka@gallettaandco.com','http://www.GallettaandCo.com','http://www.facebook.com/GallettaandCo.com','http://www.twitter.com/GallettaandCo.com','http://www.linkedin.com/GallettaandCo.com'),(1103,'Coy','Waggaman','','Albarran Studios',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436029093,'73 Ramsworth Close',NULL,NULL,'Annan','Dumfries and Galloway','Scotland','DG12 R863','+44 1144 109109','+44 1605 156718','+44 1032 164801','coy.waggaman@albarranstudios.com','http://www.AlbarranStudios.com','http://www.facebook.com/AlbarranStudios.com','http://www.twitter.com/AlbarranStudios.com','http://www.linkedin.com/AlbarranStudios.com'),(1104,'Rolf','Ballestas','','Goffney GmbH',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435875721,'93 Ronalds Way',NULL,NULL,'Albrighton','Shropshire','England','WV7 IK93','+44 1751 117866','+44 1794 98413','+44 971 118344','rolf.ballestas@goffneygmbh.com','http://www.GoffneyGmbH.com','http://www.facebook.com/GoffneyGmbH.com','http://www.twitter.com/GoffneyGmbH.com','http://www.linkedin.com/GoffneyGmbH.com'),(1105,'Armando','Brunkhorst','','Fair Pty. Ltd.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435563546,'5 Ilford Way',NULL,NULL,'Thame','Oxfordshire','England','OX9 KE4','+44 1618 113273','+44 1187 150350','+44 848 125832','armando.brunkhorst@fairptyltd.com','http://www.FairPtyLtd.com','http://www.facebook.com/FairPtyLtd.com','http://www.twitter.com/FairPtyLtd.com','http://www.linkedin.com/FairPtyLtd.com'),(1106,'Earnest','Balerio','','Lagonia Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435693616,'167 Melbourne Chase',NULL,NULL,'Macduff','Aberdeenshire','Scotland','AB44 0D35','+44 1292 149960','+44 1568 81736','+44 1358 107503','earnest.balerio@lagoniacoltd.com','http://www.LagoniaCoLtd.com','http://www.facebook.com/LagoniaCoLtd.com','http://www.twitter.com/LagoniaCoLtd.com','http://www.linkedin.com/LagoniaCoLtd.com'),(1107,'Alphonse','Sunderman','','Zilka Institute',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436040689,'168 Lee Dale Close',NULL,NULL,'Hackney','Greater London','England','E5 AC11','+44 1503 164803','+44 1622 140839','+44 1173 160201','alphonse.sunderman@zilkainstitute.com','http://www.ZilkaInstitute.com','http://www.facebook.com/ZilkaInstitute.com','http://www.twitter.com/ZilkaInstitute.com','http://www.linkedin.com/ZilkaInstitute.com'),(1108,'Elijah','Burrowes','','Agustine and Co.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435344456,'254 Gorse Hall Road',NULL,NULL,'Graig','Newport','Wales','NP10 JD37','+44 1415 106272','+44 1422 127422','+44 1591 178072','elijah.burrowes@agustineandco.com','http://www.AgustineandCo.com','http://www.facebook.com/AgustineandCo.com','http://www.twitter.com/AgustineandCo.com','http://www.linkedin.com/AgustineandCo.com'),(1109,'Tanner','Norstrom','','Jabbour and Co.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435789422,'176 Fairlie Close',NULL,NULL,'Shellingford','Oxfordshire','England','SN7 J666','+44 1252 164608','+44 1666 131135','+44 1125 107241','tanner.norstrom@jabbourandco.com','http://www.JabbourandCo.com','http://www.facebook.com/JabbourandCo.com','http://www.twitter.com/JabbourandCo.com','http://www.linkedin.com/JabbourandCo.com'),(1110,'Rickey','Marcell','','Mendivil Associates',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436070585,'208 Buckland Walk',NULL,NULL,'Muir Of Ord','Highland','Scotland','IV6 SD24','+44 997 125708','+44 1502 159457','+44 1141 178107','rickey.marcell@mendivilassociates.com','http://www.MendivilAssociates.com','http://www.facebook.com/MendivilAssociates.com','http://www.twitter.com/MendivilAssociates.com','http://www.linkedin.com/MendivilAssociates.com'),(1111,'Wilber','Faster','','Robello Company',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435340213,'110 Finney Well Close',NULL,NULL,'Taunton','Somerset','England','TA1 C851','+44 1527 150366','+44 894 176904','+44 1187 174169','wilber.faster@robellocompany.com','http://www.RobelloCompany.com','http://www.facebook.com/RobelloCompany.com','http://www.twitter.com/RobelloCompany.com','http://www.linkedin.com/RobelloCompany.com'),(1112,'Jerry','Isaack','','Mattison Inc.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435637725,'256 Etal Close',NULL,NULL,'Poplar','Greater London','England','E3 6V6','+44 1568 108305','+44 1204 123692','+44 865 149164','jerry.isaack@mattisoninc.com','http://www.MattisonInc.com','http://www.facebook.com/MattisonInc.com','http://www.twitter.com/MattisonInc.com','http://www.linkedin.com/MattisonInc.com'),(1113,'Dominique','Macomber','','Rushen Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436126742,'273 Petvin Close',NULL,NULL,'Matlock Bath','Derbyshire','England','DE4 XV27','+44 1419 118973','+44 947 133159','+44 1048 138899','dominique.macomber@rushencoltd.com','http://www.RushenCoLtd.com','http://www.facebook.com/RushenCoLtd.com','http://www.twitter.com/RushenCoLtd.com','http://www.linkedin.com/RushenCoLtd.com'),(1114,'Damien','Florin','','Biancuzzo Products',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435600486,'110 Back Hulton Lane West',NULL,NULL,'Thurrock','Thurrock','England','RM19 ZV66','+44 1263 121902','+44 1154 173714','+44 1523 84271','damien.florin@biancuzzoproducts.com','http://www.BiancuzzoProducts.com','http://www.facebook.com/BiancuzzoProducts.com','http://www.twitter.com/BiancuzzoProducts.com','http://www.linkedin.com/BiancuzzoProducts.com'),(1115,'Percy','Amacher','','Incarnato Products',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435607134,'30 Aylesford Street',NULL,NULL,'Argyll and Bute','Argyll and Bute','Scotland','PA70 _A38','+44 822 137861','+44 1541 111795','+44 1196 105422','percy.amacher@incarnatoproducts.com','http://www.IncarnatoProducts.com','http://www.facebook.com/IncarnatoProducts.com','http://www.twitter.com/IncarnatoProducts.com','http://www.linkedin.com/IncarnatoProducts.com'),(1116,'Derek','Petermann','','Musielak Automation',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436113732,'272 Garden Lodge Grove',NULL,NULL,'Knebworth','Hertfordshire','England','SG3 1T0','+44 1373 95926','+44 1552 164384','+44 1716 102717','derek.petermann@musielakautomation.com','http://www.MusielakAutomation.com','http://www.facebook.com/MusielakAutomation.com','http://www.twitter.com/MusielakAutomation.com','http://www.linkedin.com/MusielakAutomation.com'),(1117,'Dante','Giesel','','Pennycuff Studios',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435760220,'133 Grindon Lane',NULL,NULL,'Worcester','Worcester','England','WR3 3J78','+44 1266 173180','+44 1409 88665','+44 1216 147007','dante.giesel@pennycuffstudios.com','http://www.PennycuffStudios.com','http://www.facebook.com/PennycuffStudios.com','http://www.twitter.com/PennycuffStudios.com','http://www.linkedin.com/PennycuffStudios.com'),(1118,'Vern','Hanshaw','','Gouldman and Sons',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435533502,'94 Little Smith Street',NULL,NULL,'Uttoxeter','Staffordshire','England','ST14 WQ88','+44 1087 176463','+44 1723 94256','+44 1456 142506','vern.hanshaw@gouldmanandsons.com','http://www.GouldmanandSons.com','http://www.facebook.com/GouldmanandSons.com','http://www.twitter.com/GouldmanandSons.com','http://www.linkedin.com/GouldmanandSons.com'),(1119,'Barney','Cabrara','','Lao Pty. Ltd.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436296180,'33 Tatenhill Gardens',NULL,NULL,'Dolwyddelan','Conwy','Wales','LL25 2R88','+44 1115 127763','+44 802 164355','+44 1300 126470','barney.cabrara@laoptyltd.com','http://www.LaoPtyLtd.com','http://www.facebook.com/LaoPtyLtd.com','http://www.twitter.com/LaoPtyLtd.com','http://www.linkedin.com/LaoPtyLtd.com'),(1120,'Randal','Sjolund','','Radaker PLC',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435609782,'160 Cookham Wood Road',NULL,NULL,'Greenwich','Greater London','England','SE7 UF99','+44 1176 113462','+44 874 162701','+44 1339 91261','randal.sjolund@radakerplc.com','http://www.RadakerPLC.com','http://www.facebook.com/RadakerPLC.com','http://www.twitter.com/RadakerPLC.com','http://www.linkedin.com/RadakerPLC.com'),(1121,'Brett','Guiliani','','Puma Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435330678,'293 The Walmers',NULL,NULL,'Highland','Highland','Scotland','IV7 OO58','+44 1617 151560','+44 946 129496','+44 956 106940','brett.guiliani@pumacoltd.com','http://www.PumaCoLtd.com','http://www.facebook.com/PumaCoLtd.com','http://www.twitter.com/PumaCoLtd.com','http://www.linkedin.com/PumaCoLtd.com'),(1122,'Carlton','Dupouy','','Tomblinson Agency',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436037508,'183 Crownthorpe Road',NULL,NULL,'Leeds','Leeds','England','LS7 2_46','+44 1715 141703','+44 1312 126356','+44 806 153560','carlton.dupouy@tomblinsonagency.com','http://www.TomblinsonAgency.com','http://www.facebook.com/TomblinsonAgency.com','http://www.twitter.com/TomblinsonAgency.com','http://www.linkedin.com/TomblinsonAgency.com'),(1123,'Enoch','Catello','','Reppert Logistics',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435803323,'192 Butts Paddock',NULL,NULL,'Bygrave','Hertfordshire','England','SG7 MX74','+44 815 114846','+44 1352 173224','+44 1309 145377','enoch.catello@reppertlogistics.com','http://www.ReppertLogistics.com','http://www.facebook.com/ReppertLogistics.com','http://www.twitter.com/ReppertLogistics.com','http://www.linkedin.com/ReppertLogistics.com'),(1124,'Dick','Craton','','Ohrenich Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435804418,'119 Cadgwith Drive',NULL,NULL,'Crossapol','Argyll and Bute','Scotland','PA77 0T45','+44 1642 88489','+44 1169 120881','+44 1453 124063','dick.craton@ohrenichcorp.com','http://www.OhrenichCorp.com','http://www.facebook.com/OhrenichCorp.com','http://www.twitter.com/OhrenichCorp.com','http://www.linkedin.com/OhrenichCorp.com'),(1125,'Wallace','Bushweller','','Jaskolka and Co.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436013486,'289 Dalton Lane',NULL,NULL,'West Farleigh','Kent','England','ME18 3_87','+44 917 100824','+44 837 143634','+44 1254 171910','wallace.bushweller@jaskolkaandco.com','http://www.JaskolkaandCo.com','http://www.facebook.com/JaskolkaandCo.com','http://www.twitter.com/JaskolkaandCo.com','http://www.linkedin.com/JaskolkaandCo.com'),(1126,'Gavin','Skibski','','Busbey Company',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436017788,'233 Back Parnaby Terrace',NULL,NULL,'Frome','Somerset','England','BA11 XI67','+44 1341 159445','+44 1120 101798','+44 1706 89907','gavin.skibski@busbeycompany.com','http://www.BusbeyCompany.com','http://www.facebook.com/BusbeyCompany.com','http://www.twitter.com/BusbeyCompany.com','http://www.linkedin.com/BusbeyCompany.com'),(1127,'Jasper','Ximines','','Nitcher Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436208898,'35 Yarmouth Way',NULL,NULL,'Birmingham','Birmingham','England','B28 M169','+44 1660 85399','+44 1106 110128','+44 1576 162416','jasper.ximines@nitcherenterprise.com','http://www.NitcherEnterprise.com','http://www.facebook.com/NitcherEnterprise.com','http://www.twitter.com/NitcherEnterprise.com','http://www.linkedin.com/NitcherEnterprise.com'),(1128,'Elden','Mattison','','Sibble PLC',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435997497,'8 Glenbow Road',NULL,NULL,'Kingston Upon Thames','Greater London','England','KT6 VS99','+44 1695 121487','+44 1003 165569','+44 1780 162255','elden.mattison@sibbleplc.com','http://www.SibblePLC.com','http://www.facebook.com/SibblePLC.com','http://www.twitter.com/SibblePLC.com','http://www.linkedin.com/SibblePLC.com'),(1129,'Barton','Sarnosky','','Migliaccio Products',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435815662,'223 Clay Hill Road',NULL,NULL,'Stainton','Middlesbrough','England','TS8 JV70','+44 807 147664','+44 1507 94942','+44 1472 168955','barton.sarnosky@migliaccioproducts.com','http://www.MigliaccioProducts.com','http://www.facebook.com/MigliaccioProducts.com','http://www.twitter.com/MigliaccioProducts.com','http://www.linkedin.com/MigliaccioProducts.com'),(1130,'Jeffrey','Macbeth','','Kremer Foundry',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436278433,'149 Acresbush Close',NULL,NULL,'Hounslow','Greater London','England','TW4 LI52','+44 1042 170877','+44 1440 171680','+44 1644 124405','jeffrey.macbeth@kremerfoundry.com','http://www.KremerFoundry.com','http://www.facebook.com/KremerFoundry.com','http://www.twitter.com/KremerFoundry.com','http://www.linkedin.com/KremerFoundry.com'),(1131,'Enoch','Eddlemon','','Bonhomme Products',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435789215,'100 Claudius Close',NULL,NULL,'Bournemouth','Bournemouth','England','BH7 OX99','+44 952 177122','+44 1443 156056','+44 1307 177266','enoch.eddlemon@bonhommeproducts.com','http://www.BonhommeProducts.com','http://www.facebook.com/BonhommeProducts.com','http://www.twitter.com/BonhommeProducts.com','http://www.linkedin.com/BonhommeProducts.com'),(1132,'Rolf','Heilbrun','','Joo Agency',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436142654,'175 Old Tenby Road',NULL,NULL,'Fort William','Highland','Scotland','PH33 IY80','+44 1724 146655','+44 1014 80737','+44 1265 153334','rolf.heilbrun@jooagency.com','http://www.JooAgency.com','http://www.facebook.com/JooAgency.com','http://www.twitter.com/JooAgency.com','http://www.linkedin.com/JooAgency.com'),(1133,'Granville','Modglin','','Seldon Institute',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436067211,'114 Street Lane',NULL,NULL,'Kirkcudbright','Dumfries and Galloway','Scotland','DG6 HZ52','+44 1633 141467','+44 1582 132207','+44 939 159835','granville.modglin@seldoninstitute.com','http://www.SeldonInstitute.com','http://www.facebook.com/SeldonInstitute.com','http://www.twitter.com/SeldonInstitute.com','http://www.linkedin.com/SeldonInstitute.com'),(1134,'Morgan','Lippi','','Ramrirez Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436248475,'162 Usk Street',NULL,NULL,'Lancaster','Lancashire','England','LA3 6K99','+44 997 140534','+44 1585 80602','+44 1410 174267','morgan.lippi@ramrirezcoltd.com','http://www.RamrirezCoLtd.com','http://www.facebook.com/RamrirezCoLtd.com','http://www.twitter.com/RamrirezCoLtd.com','http://www.linkedin.com/RamrirezCoLtd.com'),(1135,'Brenton','Gara','','Altman Company',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435302164,'176 Steelmans Road',NULL,NULL,'Richmond','Greater London','England','SW14 IT2','+44 1161 147099','+44 1197 178683','+44 967 116493','brenton.gara@altmancompany.com','http://www.AltmanCompany.com','http://www.facebook.com/AltmanCompany.com','http://www.twitter.com/AltmanCompany.com','http://www.linkedin.com/AltmanCompany.com'),(1136,'Fidelia','Faraco','','Radaker Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435365321,'166 Hardwicke Road',NULL,NULL,'Birmingham','Birmingham','England','B2 Q191','+44 1554 150700','+44 1540 109348','+44 1048 81205','fidelia.faraco@radakercorp.com','http://www.RadakerCorp.com','http://www.facebook.com/RadakerCorp.com','http://www.twitter.com/RadakerCorp.com','http://www.linkedin.com/RadakerCorp.com'),(1137,'Mazie','Maury','','Lao PLC',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436260274,'76 Raneley Grove',NULL,NULL,'Sunderland','Sunderland','England','SR6 CQ54','+44 1236 138273','+44 850 99061','+44 1273 132343','mazie.maury@laoplc.com','http://www.LaoPLC.com','http://www.facebook.com/LaoPLC.com','http://www.twitter.com/LaoPLC.com','http://www.linkedin.com/LaoPLC.com'),(1138,'Crysta','Ell','','Marzella Foundry',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435350279,'26 Little Casterton Road',NULL,NULL,'Barkby','Leicestershire','England','LE7 ZV65','+44 1079 175520','+44 1047 87381','+44 875 123654','crysta.ell@marzellafoundry.com','http://www.MarzellaFoundry.com','http://www.facebook.com/MarzellaFoundry.com','http://www.twitter.com/MarzellaFoundry.com','http://www.linkedin.com/MarzellaFoundry.com'),(1139,'Katheleen','Dechick','','Croan Studios',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435931823,'196 Bowbridge Court',NULL,NULL,'Bolton','Bolton','England','BL7 GP39','+44 866 131306','+44 1637 164114','+44 891 177961','katheleen.dechick@croanstudios.com','http://www.CroanStudios.com','http://www.facebook.com/CroanStudios.com','http://www.twitter.com/CroanStudios.com','http://www.linkedin.com/CroanStudios.com'),(1140,'Cecile','Mclaughlan','','Leclaire Inc.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435735020,'79 Anstee Road',NULL,NULL,'Erpingham','Norfolk','England','NR11 VE59','+44 1282 107253','+44 1449 155662','+44 1454 173047','cecile.mclaughlan@leclaireinc.com','http://www.LeclaireInc.com','http://www.facebook.com/LeclaireInc.com','http://www.twitter.com/LeclaireInc.com','http://www.linkedin.com/LeclaireInc.com'),(1141,'Christy','Saephan','','Nott Automation',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435517322,'41 Links Parade',NULL,NULL,'Birmingham','Birmingham','England','B25 _M99','+44 876 174784','+44 950 95964','+44 838 147557','christy.saephan@nottautomation.com','http://www.NottAutomation.com','http://www.facebook.com/NottAutomation.com','http://www.twitter.com/NottAutomation.com','http://www.linkedin.com/NottAutomation.com'),(1142,'Sydney','Heidtman','','Kirckof Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436184074,'161 Felipe Road',NULL,NULL,'Burnhope','County Durham','England','DH8 OK6','+44 1355 159601','+44 910 154754','+44 1011 150133','sydney.heidtman@kirckofenterprise.com','http://www.KirckofEnterprise.com','http://www.facebook.com/KirckofEnterprise.com','http://www.twitter.com/KirckofEnterprise.com','http://www.linkedin.com/KirckofEnterprise.com'),(1143,'Earline','Luongo','','Coroniti Pty. Ltd.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435392870,'220 Smarts Way',NULL,NULL,'Romford','Greater London','England','RM12 HW71','+44 995 112740','+44 1368 110382','+44 1527 120419','earline.luongo@coronitiptyltd.com','http://www.CoronitiPtyLtd.com','http://www.facebook.com/CoronitiPtyLtd.com','http://www.twitter.com/CoronitiPtyLtd.com','http://www.linkedin.com/CoronitiPtyLtd.com'),(1144,'Carmel','Hellams','','Schulman Pty. Ltd.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436048637,'42 Lovel Close',NULL,NULL,'Syleham','Suffolk','England','IP21 G873','+44 1175 90332','+44 1298 98057','+44 1428 150531','carmel.hellams@schulmanptyltd.com','http://www.SchulmanPtyLtd.com','http://www.facebook.com/SchulmanPtyLtd.com','http://www.twitter.com/SchulmanPtyLtd.com','http://www.linkedin.com/SchulmanPtyLtd.com'),(1145,'Elanor','Delco','','Vankammen Associates',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435866253,'247 Baldwins Close',NULL,NULL,'Belfast','Belfast','Northern Ireland','BT4 CS97','+44 1614 161240','+44 1620 93703','+44 843 82150','elanor.delco@vankammenassociates.com','http://www.VankammenAssociates.com','http://www.facebook.com/VankammenAssociates.com','http://www.twitter.com/VankammenAssociates.com','http://www.linkedin.com/VankammenAssociates.com'),(1146,'Rubi','Syck','','Schmidt Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436035863,'69 Minneymoor Hill',NULL,NULL,'Darfield','Barnsley','England','S73 LL51','+44 948 122069','+44 837 144863','+44 914 116567','rubi.syck@schmidtcoltd.com','http://www.SchmidtCoLtd.com','http://www.facebook.com/SchmidtCoLtd.com','http://www.twitter.com/SchmidtCoLtd.com','http://www.linkedin.com/SchmidtCoLtd.com'),(1147,'Chantay','Coolbeth','','Backenstose Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435452907,'21 Downsview Avenue',NULL,NULL,'Cotgrave','Nottinghamshire','England','NG12 S485','+44 1130 161400','+44 1684 108291','+44 1449 124913','chantay.coolbeth@backenstosecorp.com','http://www.BackenstoseCorp.com','http://www.facebook.com/BackenstoseCorp.com','http://www.twitter.com/BackenstoseCorp.com','http://www.linkedin.com/BackenstoseCorp.com'),(1148,'Cassi','Vonderheide','','Curiel Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436183887,'95 Gilbertstone Avenue',NULL,NULL,'Leiston','Suffolk','England','IP16 SE10','+44 957 168872','+44 1464 131696','+44 892 177287','cassi.vonderheide@curielcoltd.com','http://www.CurielCoLtd.com','http://www.facebook.com/CurielCoLtd.com','http://www.twitter.com/CurielCoLtd.com','http://www.linkedin.com/CurielCoLtd.com'),(1149,'Rosalind','Katsaounis','','Valera Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436094578,'114 Emerson Court',NULL,NULL,'Bath','Bath and North East Somerset','England','BA2 D085','+44 1106 175931','+44 820 179346','+44 1697 116250','rosalind.katsaounis@valeraenterprise.com','http://www.ValeraEnterprise.com','http://www.facebook.com/ValeraEnterprise.com','http://www.twitter.com/ValeraEnterprise.com','http://www.linkedin.com/ValeraEnterprise.com'),(1150,'Lina','Hudspeth','','Neider Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435703281,'222 Cadgwith Drive',NULL,NULL,'Withernsea','East Riding of Yorkshire','England','HU19 CE22','+44 1782 150112','+44 1175 177894','+44 1187 129030','lina.hudspeth@neiderenterprise.com','http://www.NeiderEnterprise.com','http://www.facebook.com/NeiderEnterprise.com','http://www.twitter.com/NeiderEnterprise.com','http://www.linkedin.com/NeiderEnterprise.com'),(1151,'Katheleen','Batley','','Karstens Agency',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435919317,'52 West Front Road',NULL,NULL,'Glasgow','Glasgow City','Scotland','G2 SI35','+44 929 155138','+44 826 123755','+44 1273 177569','katheleen.batley@karstensagency.com','http://www.KarstensAgency.com','http://www.facebook.com/KarstensAgency.com','http://www.twitter.com/KarstensAgency.com','http://www.linkedin.com/KarstensAgency.com'),(1152,'Leesa','Karim','','Mccalanahan Products',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435358588,'256 Wales Farm Road',NULL,NULL,'Aberdeen','Aberdeen City','Scotland','AB12 O864','+44 1151 117509','+44 956 141982','+44 1311 162696','leesa.karim@mccalanahanproducts.com','http://www.MccalanahanProducts.com','http://www.facebook.com/MccalanahanProducts.com','http://www.twitter.com/MccalanahanProducts.com','http://www.linkedin.com/MccalanahanProducts.com'),(1153,'Skye','Galleta','','Spinner Corporation',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436034997,'30 Marcourt Road',NULL,NULL,'Salford','Salford','England','M6 NZ19','+44 1089 141089','+44 999 150372','+44 1645 178524','skye.galleta@spinnercorporation.com','http://www.SpinnerCorporation.com','http://www.facebook.com/SpinnerCorporation.com','http://www.twitter.com/SpinnerCorporation.com','http://www.linkedin.com/SpinnerCorporation.com'),(1154,'Kyle','Bercier','','Violette Logistics',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435864205,'268 Coppull Moor Lane',NULL,NULL,'Weymouth','Dorset','England','DT4 SI88','+44 1509 83863','+44 1623 176577','+44 1156 82717','kyle.bercier@violettelogistics.com','http://www.VioletteLogistics.com','http://www.facebook.com/VioletteLogistics.com','http://www.twitter.com/VioletteLogistics.com','http://www.linkedin.com/VioletteLogistics.com'),(1155,'Harriet','Isaack','','Borre Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436081004,'29 Ormskirk Avenue',NULL,NULL,'Gravesend','Kent','England','DA12 W688','+44 1678 118429','+44 1404 169326','+44 1151 148317','harriet.isaack@borrecorp.com','http://www.BorreCorp.com','http://www.facebook.com/BorreCorp.com','http://www.twitter.com/BorreCorp.com','http://www.linkedin.com/BorreCorp.com'),(1156,'Gwenn','Lemmer','','Laschinger Company',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436087618,'234 Bents Green Road',NULL,NULL,'Elmstead','Essex','England','CO7 YO51','+44 811 157406','+44 992 155818','+44 1423 174168','gwenn.lemmer@laschingercompany.com','http://www.LaschingerCompany.com','http://www.facebook.com/LaschingerCompany.com','http://www.twitter.com/LaschingerCompany.com','http://www.linkedin.com/LaschingerCompany.com'),(1157,'Xiao','Gosso','','Litzinger Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436097995,'125 Rochdale Court',NULL,NULL,'Norton','Sheffield','England','S1 LW46','+44 1554 177098','+44 1578 101203','+44 938 156080','xiao.gosso@litzingerenterprise.com','http://www.LitzingerEnterprise.com','http://www.facebook.com/LitzingerEnterprise.com','http://www.twitter.com/LitzingerEnterprise.com','http://www.linkedin.com/LitzingerEnterprise.com'),(1158,'France','Schimming','','Wujcik Studios',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436196701,'81 Lasgarn Lane',NULL,NULL,'Wick','Worcestershire','England','WR10 4S82','+44 920 110337','+44 955 81655','+44 1769 178052','france.schimming@wujcikstudios.com','http://www.WujcikStudios.com','http://www.facebook.com/WujcikStudios.com','http://www.twitter.com/WujcikStudios.com','http://www.linkedin.com/WujcikStudios.com'),(1159,'Janie','Dangerfield','','Junod Inc.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435802688,'118 Abinger Grove',NULL,NULL,'Hertford','Hertford','England','SG14 VR19','+44 1170 129187','+44 1386 158530','+44 873 90607','janie.dangerfield@junodinc.com','http://www.JunodInc.com','http://www.facebook.com/JunodInc.com','http://www.twitter.com/JunodInc.com','http://www.linkedin.com/JunodInc.com'),(1160,'Leisha','Belnas','','Castaldi Foundry',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435768457,'204 Alfriston Park',NULL,NULL,'Argyll and Bute','Argyll and Bute','Scotland','PA33 EP4','+44 1352 129985','+44 1555 97072','+44 1156 164961','leisha.belnas@castaldifoundry.com','http://www.CastaldiFoundry.com','http://www.facebook.com/CastaldiFoundry.com','http://www.twitter.com/CastaldiFoundry.com','http://www.linkedin.com/CastaldiFoundry.com'),(1161,'Elsie','Avril','','Hauschild Automation',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435470513,'89 Church Farm Crescent',NULL,NULL,'Wickham and Dunston','Gateshead','England','NE11 HK62','+44 1311 179097','+44 821 154001','+44 1592 150042','elsie.avril@hauschildautomation.com','http://www.HauschildAutomation.com','http://www.facebook.com/HauschildAutomation.com','http://www.twitter.com/HauschildAutomation.com','http://www.linkedin.com/HauschildAutomation.com'),(1162,'Ronni','Desharnais','','Singson Company',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435378921,'1 Leek Lane',NULL,NULL,'Liverpool','Liverpool','England','L11 GB57','+44 1286 177252','+44 889 174488','+44 1790 146039','ronni.desharnais@singsoncompany.com','http://www.SingsonCompany.com','http://www.facebook.com/SingsonCompany.com','http://www.twitter.com/SingsonCompany.com','http://www.linkedin.com/SingsonCompany.com'),(1163,'Madalene','Damm','','Nacol Foundry',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435783161,'128 Bells Chase',NULL,NULL,'Redcar','Redcar and Cleveland','England','TS10 D522','+44 946 89960','+44 1686 80054','+44 1767 156412','madalene.damm@nacolfoundry.com','http://www.NacolFoundry.com','http://www.facebook.com/NacolFoundry.com','http://www.twitter.com/NacolFoundry.com','http://www.linkedin.com/NacolFoundry.com'),(1164,'Perla','Stepps','','Radich Associates',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435697887,'127 Oulton Road',NULL,NULL,'Bingley','Bradford','England','BD16 E727','+44 999 109840','+44 1776 155742','+44 1452 85436','perla.stepps@radichassociates.com','http://www.RadichAssociates.com','http://www.facebook.com/RadichAssociates.com','http://www.twitter.com/RadichAssociates.com','http://www.linkedin.com/RadichAssociates.com'),(1165,'Leanora','Poser','','Finlay and Sons',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435509468,'258 Scholars Acre',NULL,NULL,'Bury','Bury','England','BL8 686','+44 1547 104933','+44 1704 128631','+44 1781 133804','leanora.poser@finlayandsons.com','http://www.FinlayandSons.com','http://www.facebook.com/FinlayandSons.com','http://www.twitter.com/FinlayandSons.com','http://www.linkedin.com/FinlayandSons.com'),(1166,'Lieselotte','Golphin','','Clendaniel GmbH',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436058323,'36 Dimlington Bungalows',NULL,NULL,'The Scottish Borders','The Scottish Borders','Scotland','TD14 5C56','+44 938 163312','+44 989 138221','+44 1233 159968','lieselotte.golphin@clendanielgmbh.com','http://www.ClendanielGmbH.com','http://www.facebook.com/ClendanielGmbH.com','http://www.twitter.com/ClendanielGmbH.com','http://www.linkedin.com/ClendanielGmbH.com'),(1167,'Kimberley','Nabb','','Tacker and Sons',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436236127,'133 Dancing Close',NULL,NULL,'Leeds','Leeds','England','LS11 XN85','+44 1758 157761','+44 918 97808','+44 1087 97719','kimberley.nabb@tackerandsons.com','http://www.TackerandSons.com','http://www.facebook.com/TackerandSons.com','http://www.twitter.com/TackerandSons.com','http://www.linkedin.com/TackerandSons.com'),(1168,'Joetta','Spikes','','Krzynowek Inc.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435773349,'87 Beck Place',NULL,NULL,'Aberdovey','Gwynedd','Wales','LL35 5A89','+44 1208 149051','+44 890 164125','+44 1297 144511','joetta.spikes@krzynowekinc.com','http://www.KrzynowekInc.com','http://www.facebook.com/KrzynowekInc.com','http://www.twitter.com/KrzynowekInc.com','http://www.linkedin.com/KrzynowekInc.com'),(1169,'Jenell','Micheals','','Pete Company',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436200464,'22 Heathness Road',NULL,NULL,'Warfield','Bracknell Forest','England','RG42 OG56','+44 1757 156448','+44 883 176083','+44 1347 83241','jenell.micheals@petecompany.com','http://www.PeteCompany.com','http://www.facebook.com/PeteCompany.com','http://www.twitter.com/PeteCompany.com','http://www.linkedin.com/PeteCompany.com'),(1170,'Donita','Kalafatis','','Salquero PLC',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435657359,'153 Beza Road',NULL,NULL,'Exmouth','Devon','England','EX8 PL54','+44 1163 177328','+44 1524 172989','+44 944 165804','donita.kalafatis@salqueroplc.com','http://www.SalqueroPLC.com','http://www.facebook.com/SalqueroPLC.com','http://www.twitter.com/SalqueroPLC.com','http://www.linkedin.com/SalqueroPLC.com'),(1171,'Alessandra','Decelles','','Houde Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435994598,'270 Ridgway Close',NULL,NULL,'Northampton','Northamptonshire','England','NN2 QW6','+44 1658 90072','+44 1021 173145','+44 1237 119220','alessandra.decelles@houdecorp.com','http://www.HoudeCorp.com','http://www.facebook.com/HoudeCorp.com','http://www.twitter.com/HoudeCorp.com','http://www.linkedin.com/HoudeCorp.com'),(1172,'Stevie','Hartwigsen','','Rorie Corporation',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435556259,'125 Deeside Close',NULL,NULL,'Gresford','Wrexham','Wales','LL12 FJ58','+44 1619 170630','+44 1433 106274','+44 1021 171156','stevie.hartwigsen@roriecorporation.com','http://www.RorieCorporation.com','http://www.facebook.com/RorieCorporation.com','http://www.twitter.com/RorieCorporation.com','http://www.linkedin.com/RorieCorporation.com'),(1173,'Lemuel','Ficken','','Rynearson Inc.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435460439,'26 Coed Cae Road',NULL,NULL,'Burnhope','County Durham','England','DH8 EB51','+44 1707 135570','+44 1348 87242','+44 1455 162783','lemuel.ficken@rynearsoninc.com','http://www.RynearsonInc.com','http://www.facebook.com/RynearsonInc.com','http://www.twitter.com/RynearsonInc.com','http://www.linkedin.com/RynearsonInc.com'),(1174,'Kip','Nimon','','Bonfield Inc.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435675947,'197 Green Pastures Road',NULL,NULL,'Bournemouth','Bournemouth','England','BH10 LC84','+44 1645 175593','+44 1332 112257','+44 1355 148605','kip.nimon@bonfieldinc.com','http://www.BonfieldInc.com','http://www.facebook.com/BonfieldInc.com','http://www.twitter.com/BonfieldInc.com','http://www.linkedin.com/BonfieldInc.com'),(1175,'Ellis','Aravjo','','Gaus Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435323038,'256 Hegarty Court',NULL,NULL,'Keynsham','Bath and North East Somerset','England','BS31 MZ23','+44 1441 127352','+44 1717 145737','+44 800 111594','ellis.aravjo@gausenterprise.com','http://www.GausEnterprise.com','http://www.facebook.com/GausEnterprise.com','http://www.twitter.com/GausEnterprise.com','http://www.linkedin.com/GausEnterprise.com'),(1176,'Ferdinand','Trippensee','','Poeppel Associates',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435461586,'206 Helens Mead Road',NULL,NULL,'Dursley','Gloucestershire','England','GL11 XK65','+44 1441 165169','+44 1363 94404','+44 890 178399','ferdinand.trippensee@poeppelassociates.com','http://www.PoeppelAssociates.com','http://www.facebook.com/PoeppelAssociates.com','http://www.twitter.com/PoeppelAssociates.com','http://www.linkedin.com/PoeppelAssociates.com'),(1177,'Morris','Krause','','Schuring Institute',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436232604,'217 Boulmer Close',NULL,NULL,'West Lothian','West Lothian','Scotland','EH47 FZ64','+44 1705 153805','+44 1672 151396','+44 826 91976','morris.krause@schuringinstitute.com','http://www.SchuringInstitute.com','http://www.facebook.com/SchuringInstitute.com','http://www.twitter.com/SchuringInstitute.com','http://www.linkedin.com/SchuringInstitute.com'),(1178,'Buck','Tetro','','Modglin Agency',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435329591,'62 Edzell Park',NULL,NULL,'Esher','Surrey','England','KT10 IQ75','+44 955 122818','+44 1532 164221','+44 1725 81311','buck.tetro@modglinagency.com','http://www.ModglinAgency.com','http://www.facebook.com/ModglinAgency.com','http://www.twitter.com/ModglinAgency.com','http://www.linkedin.com/ModglinAgency.com'),(1179,'Evan','Mattice','','Figliola Industries',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435825968,'89 William Ash Close',NULL,NULL,'Snainton','North Yorkshire','England','YO22 UC76','+44 1361 174066','+44 1239 86192','+44 1454 155132','evan.mattice@figliolaindustries.com','http://www.FigliolaIndustries.com','http://www.facebook.com/FigliolaIndustries.com','http://www.twitter.com/FigliolaIndustries.com','http://www.linkedin.com/FigliolaIndustries.com'),(1180,'Wilburn','Cooler','','Guichard Pty. Ltd.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435325685,'195 Shawlea Avenue',NULL,NULL,'Lymm','Warrington','England','WA13 CC89','+44 1619 102138','+44 1587 154192','+44 1545 103682','wilburn.cooler@guichardptyltd.com','http://www.GuichardPtyLtd.com','http://www.facebook.com/GuichardPtyLtd.com','http://www.twitter.com/GuichardPtyLtd.com','http://www.linkedin.com/GuichardPtyLtd.com'),(1181,'Reginald','Ranjel','','Bockman Institute',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435556461,'73 Wexford Way',NULL,NULL,'Edinburgh','City of Edinburgh','Scotland','EH17 0L55','+44 1509 117321','+44 1798 163601','+44 972 90920','reginald.ranjel@bockmaninstitute.com','http://www.BockmanInstitute.com','http://www.facebook.com/BockmanInstitute.com','http://www.twitter.com/BockmanInstitute.com','http://www.linkedin.com/BockmanInstitute.com'),(1182,'Stefan','Daulton','','Doornbos Institute',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436218021,'259 Nyewood Lane',NULL,NULL,'Rushden','Northamptonshire','England','NN10 XE40','+44 1209 115888','+44 1554 86153','+44 1558 115866','stefan.daulton@doornbosinstitute.com','http://www.DoornbosInstitute.com','http://www.facebook.com/DoornbosInstitute.com','http://www.twitter.com/DoornbosInstitute.com','http://www.linkedin.com/DoornbosInstitute.com'),(1183,'Desmond','Stahly','','Hooper Agency',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435532084,'47 Sandhill Fold',NULL,NULL,'Standon','Hertfordshire','England','SG11 1W65','+44 903 110511','+44 1122 115647','+44 1683 159713','desmond.stahly@hooperagency.com','http://www.HooperAgency.com','http://www.facebook.com/HooperAgency.com','http://www.twitter.com/HooperAgency.com','http://www.linkedin.com/HooperAgency.com'),(1184,'Bryant','Schickel','','Paul Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436026673,'89 Drax Avenue',NULL,NULL,'Torquay','Torbay','England','TQ4 1G46','+44 1664 119999','+44 1511 123460','+44 1615 127988','bryant.schickel@paulltd.com','http://www.PaulLtd.com','http://www.facebook.com/PaulLtd.com','http://www.twitter.com/PaulLtd.com','http://www.linkedin.com/PaulLtd.com'),(1185,'Terence','Badie','','Sluyter Associates',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435758150,'209 Little Smith Street',NULL,NULL,'Braunton','Devon','England','EX33 L89','+44 1535 131686','+44 1030 149454','+44 1751 124177','terence.badie@sluyterassociates.com','http://www.SluyterAssociates.com','http://www.facebook.com/SluyterAssociates.com','http://www.twitter.com/SluyterAssociates.com','http://www.linkedin.com/SluyterAssociates.com'),(1186,'Hosea','Cozzy','','Jubilee Industries',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436216504,'270 Looe Street',NULL,NULL,'Sancreed','Cornwall','England','TR19 C_24','+44 1175 107293','+44 1561 141502','+44 1269 167258','hosea.cozzy@jubileeindustries.com','http://www.JubileeIndustries.com','http://www.facebook.com/JubileeIndustries.com','http://www.twitter.com/JubileeIndustries.com','http://www.linkedin.com/JubileeIndustries.com'),(1187,'Hans','Brau','','Karen GmbH',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435508221,'88 Bardsey Place',NULL,NULL,'Montgomery','Powys','Wales','SY15 OC81','+44 1249 111636','+44 1698 152387','+44 928 139452','hans.brau@karengmbh.com','http://www.KarenGmbH.com','http://www.facebook.com/KarenGmbH.com','http://www.twitter.com/KarenGmbH.com','http://www.linkedin.com/KarenGmbH.com'),(1188,'Jamison','Hamalak','','Zambotti Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436269892,'260 Macdonnell Gardens',NULL,NULL,'Montacute','Somerset','England','TA15 Y033','+44 1239 170842','+44 1179 90248','+44 1472 114391','jamison.hamalak@zambotticorp.com','http://www.ZambottiCorp.com','http://www.facebook.com/ZambottiCorp.com','http://www.twitter.com/ZambottiCorp.com','http://www.linkedin.com/ZambottiCorp.com'),(1189,'Josef','Centeno','','Eve and Co.',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435869185,'183 Nyewood Lane',NULL,NULL,'Hounslow','Greater London','England','TW3 E252','+44 1322 109977','+44 1083 92767','+44 1001 178779','josef.centeno@eveandco.com','http://www.EveandCo.com','http://www.facebook.com/EveandCo.com','http://www.twitter.com/EveandCo.com','http://www.linkedin.com/EveandCo.com'),(1190,'Nelson','Philippi','','Schroeppel Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435306349,'263 Cogdean Walk',NULL,NULL,'Llanwenog','Ceredigion','Wales','SA40 KI90','+44 1013 123815','+44 1202 154329','+44 875 177483','nelson.philippi@schroeppelcoltd.com','http://www.SchroeppelCoLtd.com','http://www.facebook.com/SchroeppelCoLtd.com','http://www.twitter.com/SchroeppelCoLtd.com','http://www.linkedin.com/SchroeppelCoLtd.com'),(1191,'Erwin','Terrones','','Montello Corporation',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436201054,'172 Beech Hollows',NULL,NULL,'Reading','Reading','England','RG2 3M2','+44 1634 131842','+44 891 102878','+44 967 94505','erwin.terrones@montellocorporation.com','http://www.MontelloCorporation.com','http://www.facebook.com/MontelloCorporation.com','http://www.twitter.com/MontelloCorporation.com','http://www.linkedin.com/MontelloCorporation.com'),(1192,'Steve','Kulik','','Hazlip Agency',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435482872,'258 Ridge Side',NULL,NULL,'Calne','Wiltshire','England','SN11 PJ87','+44 1555 142860','+44 1373 158121','+44 804 145970','steve.kulik@hazlipagency.com','http://www.HazlipAgency.com','http://www.facebook.com/HazlipAgency.com','http://www.twitter.com/HazlipAgency.com','http://www.linkedin.com/HazlipAgency.com'),(1193,'Dusty','Luria','','Soose Co. Ltd',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435976811,'165 Garraway Place',NULL,NULL,'Dumbarton','West Dunbartonshire','Scotland','G82 LF32','+44 1333 97843','+44 904 164329','+44 984 128111','dusty.luria@soosecoltd.com','http://www.SooseCoLtd.com','http://www.facebook.com/SooseCoLtd.com','http://www.twitter.com/SooseCoLtd.com','http://www.linkedin.com/SooseCoLtd.com'),(1194,'Carey','Hepworth','','Jarzynka Corp',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436170069,'278 Colt House Close',NULL,NULL,'Paddington','Greater London','England','W1H UC43','+44 968 169565','+44 1673 167451','+44 1378 99042','carey.hepworth@jarzynkacorp.com','http://www.JarzynkaCorp.com','http://www.facebook.com/JarzynkaCorp.com','http://www.twitter.com/JarzynkaCorp.com','http://www.linkedin.com/JarzynkaCorp.com'),(1195,'Anton','Tyre','','Stolarski and Sons',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435834062,'169 West Holmes Gardens',NULL,NULL,'Birkenhead','Wirral','England','CH41 FC35','+44 1519 147222','+44 1202 132115','+44 988 144325','anton.tyre@stolarskiandsons.com','http://www.StolarskiandSons.com','http://www.facebook.com/StolarskiandSons.com','http://www.twitter.com/StolarskiandSons.com','http://www.linkedin.com/StolarskiandSons.com'),(1196,'Lloyd','Wishart','','Wojtas Enterprise',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1435414691,'258 Monet Crescent',NULL,NULL,'Crayford','Greater London','England','DA7 3W97','+44 1755 84426','+44 1070 111671','+44 1319 139109','lloyd.wishart@wojtasenterprise.com','http://www.WojtasEnterprise.com','http://www.facebook.com/WojtasEnterprise.com','http://www.twitter.com/WojtasEnterprise.com','http://www.linkedin.com/WojtasEnterprise.com'),(1197,'Carlos','Yavorsky','','Letters Industries',0,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1436177772,'199 The Bakers',NULL,NULL,'Bryncrug','Gwynedd','Wales','LL36 WT12','+44 1265 179245','+44 1041 176688','+44 1454 137515','carlos.yavorsky@lettersindustries.com','http://www.LettersIndustries.com','http://www.facebook.com/LettersIndustries.com','http://www.twitter.com/LettersIndustries.com','http://www.linkedin.com/LettersIndustries.com');
UNLOCK TABLES;
DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer` (
  `customerid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `co_name` varchar(128) NOT NULL,
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
  PRIMARY KEY (`customerid`)
) ENGINE=InnoDB AUTO_INCREMENT=132 DEFAULT CHARSET=latin1;
LOCK TABLES `customer` WRITE;
INSERT INTO `customer` VALUES (116,'Gundert Logistics','95 Patio Close',NULL,NULL,'Eltham','Greater London','England','SE28 Q761','+44 1410 133510','+44 1322 129283','+44 927 83370','info@GundertLogisticscom','http://www.GundertLogisticscom','http://www.facebook.com/GundertLogisticscom','http://www.twitter.com/GundertLogisticscom','http://www.linkedin.com/GundertLogisticscom'),(117,'Canalez GmbH','124 Wragg Castle Lane',NULL,NULL,'Milngavie','East Dunbartonshire','Scotland','G61 JN13','+44 1633 124630','+44 1711 167882','+44 1572 160911','info@CanalezGmbHcom','http://www.CanalezGmbHcom','http://www.facebook.com/CanalezGmbHcom','http://www.twitter.com/CanalezGmbHcom','http://www.linkedin.com/CanalezGmbHcom'),(118,'Eley Products','296 Colt House Close',NULL,NULL,'Cottingham','East Riding of Yorkshire','England','HU17 7K67','+44 1174 124720','+44 1039 167348','+44 896 170312','info@EleyProductscom','http://www.EleyProductscom','http://www.facebook.com/EleyProductscom','http://www.twitter.com/EleyProductscom','http://www.linkedin.com/EleyProductscom'),(119,'Polee Enterprise','20 West Holmes Gardens',NULL,NULL,'Briston','Norfolk','England','NR24 Z335','+44 1569 119981','+44 1798 147039','+44 1744 144041','info@PoleeEnterprisecom','http://www.PoleeEnterprisecom','http://www.facebook.com/PoleeEnterprisecom','http://www.twitter.com/PoleeEnterprisecom','http://www.linkedin.com/PoleeEnterprisecom'),(120,'Eschberger Enterprise','241 Ivy Graham Close',NULL,NULL,'Rotherham','Rotherham','England','S61 V83','+44 892 177243','+44 1520 151317','+44 1237 90785','info@EschbergerEnterprisecom','http://www.EschbergerEnterprisecom','http://www.facebook.com/EschbergerEnterprisecom','http://www.twitter.com/EschbergerEnterprisecom','http://www.linkedin.com/EschbergerEnterprisecom'),(121,'Rosseau Company','195 Wyming Brook Drive',NULL,NULL,'Ipswich','Suffolk','England','IP1 AR39','+44 843 174382','+44 1222 147070','+44 967 151388','info@RosseauCompanycom','http://www.RosseauCompanycom','http://www.facebook.com/RosseauCompanycom','http://www.twitter.com/RosseauCompanycom','http://www.linkedin.com/RosseauCompanycom'),(122,'Hasselvander Automation','191 Prince Edward Avenue',NULL,NULL,'Lewes','East Sussex','England','BN7 ZU84','+44 1704 111466','+44 963 130446','+44 996 88850','info@HasselvanderAutomationcom','http://www.HasselvanderAutomationcom','http://www.facebook.com/HasselvanderAutomationcom','http://www.twitter.com/HasselvanderAutomationcom','http://www.linkedin.com/HasselvanderAutomationcom'),(123,'Spikes Automation','31 Durweston Close',NULL,NULL,'Graig','Newport','Wales','NP10 9797','+44 1416 158594','+44 1383 144576','+44 1469 128196','info@SpikesAutomationcom','http://www.SpikesAutomationcom','http://www.facebook.com/SpikesAutomationcom','http://www.twitter.com/SpikesAutomationcom','http://www.linkedin.com/SpikesAutomationcom'),(124,'Glascott Industries','172 Tideswell Green',NULL,NULL,'Rustington','West Sussex','England','BN16 EM79','+44 1169 156875','+44 937 116576','+44 1389 118287','info@GlascottIndustriescom','http://www.GlascottIndustriescom','http://www.facebook.com/GlascottIndustriescom','http://www.twitter.com/GlascottIndustriescom','http://www.linkedin.com/GlascottIndustriescom'),(125,'Iwashita Industries','213 Standedge Foot Road',NULL,NULL,'Perth and Kinross','Perth and Kinross','Scotland','PH1 1L11','+44 1387 168039','+44 1543 104617','+44 1773 115351','info@IwashitaIndustriescom','http://www.IwashitaIndustriescom','http://www.facebook.com/IwashitaIndustriescom','http://www.twitter.com/IwashitaIndustriescom','http://www.linkedin.com/IwashitaIndustriescom'),(126,'Laidler Corp','35 Rose Acre Lane',NULL,NULL,'Withernsea','East Riding of Yorkshire','England','HU19 C142','+44 1232 131110','+44 1229 100352','+44 1704 152701','info@LaidlerCorpcom','http://www.LaidlerCorpcom','http://www.facebook.com/LaidlerCorpcom','http://www.twitter.com/LaidlerCorpcom','http://www.linkedin.com/LaidlerCorpcom'),(127,'Tschache Industries','150 Abbey Rooms Lane',NULL,NULL,'Camden Town','Greater London','England','NW6 SC40','+44 1771 100989','+44 1733 168506','+44 1166 111918','info@TschacheIndustriescom','http://www.TschacheIndustriescom','http://www.facebook.com/TschacheIndustriescom','http://www.twitter.com/TschacheIndustriescom','http://www.linkedin.com/TschacheIndustriescom'),(128,'Vonderheide Enterprise','52 Briton Square',NULL,NULL,'Canterbury','Kent','England','CT6 MT30','+44 1697 118707','+44 1306 143957','+44 963 94192','info@VonderheideEnterprisecom','http://www.VonderheideEnterprisecom','http://www.facebook.com/VonderheideEnterprisecom','http://www.twitter.com/VonderheideEnterprisecom','http://www.linkedin.com/VonderheideEnterprisecom'),(129,'Prakash Enterprise','228 Tramway Road',NULL,NULL,'Worplesdon','Surrey','England','GU3 IF86','+44 1665 115066','+44 1027 147607','+44 1480 151649','info@PrakashEnterprisecom','http://www.PrakashEnterprisecom','http://www.facebook.com/PrakashEnterprisecom','http://www.twitter.com/PrakashEnterprisecom','http://www.linkedin.com/PrakashEnterprisecom'),(130,'Pagliari PLC','112 Greenwood Quadrant',NULL,NULL,'Barking','Greater London','England','RM8 BV17','+44 1781 129347','+44 1246 111618','+44 1678 158508','info@PagliariPLCcom','http://www.PagliariPLCcom','http://www.facebook.com/PagliariPLCcom','http://www.twitter.com/PagliariPLCcom','http://www.linkedin.com/PagliariPLCcom'),(131,'Rotunda and Co.','36 Carlton Park Avenue',NULL,NULL,'Peasmarsh','East Sussex','England','TN31 X686','+44 1790 149451','+44 1381 146067','+44 1335 152757','info@RotundaandCocom','http://www.RotundaandCocom','http://www.facebook.com/RotundaandCocom','http://www.twitter.com/RotundaandCocom','http://www.linkedin.com/RotundaandCocom');
UNLOCK TABLES;
DROP TABLE IF EXISTS `invoices`;
CREATE TABLE `invoices` (
  `invoicesid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `customerid` int(10) unsigned NOT NULL,
  `contactsid` int(10) unsigned DEFAULT NULL,
  `incept` int(10) unsigned NOT NULL,
  `paid` int(10) unsigned DEFAULT '0',
  `content` text,
  `notes` text,
  `price` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`invoicesid`)
) ENGINE=InnoDB AUTO_INCREMENT=280 DEFAULT CHARSET=latin1;
LOCK TABLES `invoices` WRITE;
INSERT INTO `invoices` VALUES (160,127,1149,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',43.43),(161,118,1185,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',20.22),(162,124,1122,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',63.62),(163,127,1176,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',72.77),(164,121,1103,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',40.31),(165,130,1191,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',89.38),(166,120,1179,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',6.02),(167,127,1150,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',70.88),(168,121,1115,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',74.10),(169,119,1141,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',54.58),(170,127,1149,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',38.99),(171,128,1155,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',58.96),(172,129,1169,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',7.97),(173,122,1111,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',35.09),(174,123,1193,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',90.08),(175,116,1183,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',62.28),(176,118,1115,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',86.89),(177,120,1149,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',52.24),(178,116,1173,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',88.92),(179,122,1140,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',75.83),(180,120,1110,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',44.84),(181,125,1117,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',79.32),(182,116,1196,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',50.36),(183,120,1173,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',36.72),(184,124,1104,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',66.25),(185,128,1108,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',39.42),(186,130,1116,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',98.57),(187,124,1124,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',19.56),(188,129,1141,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',24.75),(189,123,1190,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',37.34),(190,118,1197,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',87.92),(191,125,1180,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',58.43),(192,127,1136,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',46.47),(193,131,1125,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',82.90),(194,129,1129,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',69.22),(195,129,1108,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',22.62),(196,124,1116,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',44.08),(197,128,1148,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',48.72),(198,116,1181,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',38.54),(199,125,1109,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',91.21),(200,122,1158,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',7.71),(201,125,1111,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',62.31),(202,121,1167,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',82.37),(203,127,1169,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',49.90),(204,122,1179,1436301059,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',19.12),(205,127,1173,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',92.79),(206,121,1194,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',34.94),(207,123,1185,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',78.29),(208,124,1147,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',31.91),(209,127,1134,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',91.29),(210,120,1165,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.73),(211,120,1163,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',75.75),(212,117,1177,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',73.66),(213,119,1110,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',42.29),(214,128,1191,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',41.60),(215,121,1188,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',49.36),(216,116,1191,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',22.65),(217,118,1196,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',93.10),(218,124,1120,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',40.50),(219,116,1138,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',29.25),(220,120,1192,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',71.87),(221,127,1118,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',39.92),(222,127,1175,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',41.42),(223,122,1123,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.84),(224,127,1176,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',55.54),(225,116,1128,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',51.64),(226,120,1110,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.54),(227,130,1195,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',95.64),(228,128,1106,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.84),(229,121,1171,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',24.82),(230,130,1190,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',12.59),(231,124,1125,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',62.23),(232,117,1138,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',79.84),(233,118,1102,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',52.93),(234,129,1138,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',21.09),(235,116,1113,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',65.96),(236,130,1104,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',68.93),(237,124,1188,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',6.46),(238,123,1126,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',58.99),(239,129,1173,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',87.60),(240,127,1113,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',35.76),(241,127,1176,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',4.02),(242,122,1173,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',33.86),(243,129,1137,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',34.14),(244,122,1173,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.79),(245,121,1116,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',81.90),(246,129,1142,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',47.15),(247,129,1119,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',40.21),(248,123,1124,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',87.20),(249,126,1109,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',66.31),(250,118,1178,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',40.08),(251,124,1192,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',50.93),(252,117,1148,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',84.96),(253,130,1151,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',19.00),(254,128,1160,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',59.64),(255,126,1157,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.03),(256,131,1154,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',94.86),(257,131,1185,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',68.52),(258,124,1169,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',73.05),(259,116,1148,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',57.38),(260,128,1138,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',32.92),(261,118,1113,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',83.06),(262,121,1133,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',95.42),(263,127,1190,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',34.63),(264,118,1135,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',70.84),(265,124,1133,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',71.04),(266,129,1135,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',51.93),(267,120,1109,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',37.42),(268,116,1102,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',20.62),(269,122,1158,1436301060,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',67.25),(270,120,1153,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',35.68),(271,120,1111,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.48),(272,117,1194,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',62.76),(273,129,1141,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',37.60),(274,129,1197,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',77.95),(275,123,1133,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',48.19),(276,116,1156,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',67.92),(277,123,1106,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',98.08),(278,120,1151,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',45.90),(279,127,1163,1436301061,0,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',34.24);
UNLOCK TABLES;
DROP TABLE IF EXISTS `quotes`;
CREATE TABLE `quotes` (
  `quotesid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `staffid` int(10) unsigned DEFAULT '1',
  `customerid` int(10) unsigned NOT NULL,
  `contactsid` int(10) unsigned DEFAULT NULL,
  `incept` int(10) unsigned NOT NULL,
  `content` text NOT NULL,
  `notes` text,
  `price` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`quotesid`)
) ENGINE=InnoDB AUTO_INCREMENT=200 DEFAULT CHARSET=latin1;
LOCK TABLES `quotes` WRITE;
INSERT INTO `quotes` VALUES (120,136,121,1124,1436301057,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',54.45),(121,140,128,1172,1436301057,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',55.47),(122,139,124,1177,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',53.30),(123,143,130,1152,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',69.16),(124,142,127,1150,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',42.31),(125,133,127,1164,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',0.44),(126,133,121,1104,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',59.11),(127,134,130,1149,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',46.97),(128,131,125,1139,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',72.99),(129,135,128,1134,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',73.51),(130,144,124,1147,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',56.91),(131,126,127,1174,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',74.99),(132,130,128,1170,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',78.45),(133,148,130,1181,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',12.45),(134,128,131,1132,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',45.45),(135,145,117,1166,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',90.34),(136,141,125,1184,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',37.21),(137,138,131,1111,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',72.82),(138,135,123,1126,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',39.27),(139,138,128,1181,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',65.05),(140,135,124,1176,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',69.04),(141,131,117,1104,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',26.82),(142,143,123,1145,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',65.33),(143,129,130,1138,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',70.39),(144,126,129,1177,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',45.18),(145,134,116,1123,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',74.53),(146,144,118,1158,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',37.38),(147,135,121,1148,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',41.35),(148,143,130,1191,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',32.42),(149,145,127,1151,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',71.47),(150,146,127,1192,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',12.28),(151,143,117,1197,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',13.73),(152,136,130,1140,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',42.25),(153,138,129,1156,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',58.50),(154,138,130,1196,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',95.10),(155,139,121,1117,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',32.39),(156,140,121,1152,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',52.53),(157,129,123,1115,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',27.28),(158,128,131,1167,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',96.53),(159,128,128,1153,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',22.88),(160,135,126,1159,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',68.46),(161,132,125,1148,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',43.35),(162,134,126,1111,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',91.93),(163,143,121,1195,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',14.24),(164,129,130,1121,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',85.01),(165,134,123,1113,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',29.47),(166,143,126,1168,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',67.70),(167,147,123,1165,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',73.78),(168,138,126,1160,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',54.20),(169,136,120,1153,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',38.57),(170,136,119,1134,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',19.03),(171,140,120,1178,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',1.81),(172,145,131,1152,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',82.22),(173,133,131,1177,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',97.81),(174,125,129,1190,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',28.85),(175,130,127,1122,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',64.95),(176,139,117,1148,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',22.61),(177,140,116,1140,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',13.98),(178,126,118,1180,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',79.86),(179,131,119,1162,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',60.63),(180,135,116,1188,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',69.08),(181,141,117,1187,1436301058,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',4.53),(182,129,124,1115,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',39.96),(183,145,122,1152,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',84.28),(184,130,128,1103,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',13.71),(185,125,128,1116,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',65.94),(186,138,122,1155,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',0.25),(187,146,126,1102,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',58.96),(188,135,122,1157,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',40.70),(189,127,119,1182,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',49.77),(190,148,116,1195,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',11.35),(191,138,130,1137,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',17.99),(192,143,131,1193,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',92.80),(193,136,124,1109,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',72.49),(194,141,120,1194,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',55.82),(195,139,125,1192,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',52.87),(196,128,127,1128,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',33.27),(197,137,116,1191,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',3.35),(198,129,116,1180,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',56.30),(199,125,125,1189,1436301059,'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat',38.26);
UNLOCK TABLES;
DROP TABLE IF EXISTS `staff`;
CREATE TABLE `staff` (
  `staffid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `fname` varchar(45) NOT NULL,
  `sname` varchar(45) DEFAULT NULL,
  `notes` text,
  `jobtitle` varchar(128) DEFAULT NULL,
  `content` text,
  `status` enum('active','retired','left','temp') NOT NULL,
  `level` smallint(5) unsigned NOT NULL DEFAULT '10',
  `lastlogin` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`staffid`)
) ENGINE=InnoDB AUTO_INCREMENT=149 DEFAULT CHARSET=latin1;
LOCK TABLES `staff` WRITE;
INSERT INTO `staff` VALUES (125,'Fatima','Maggiore','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435777054),(126,'Leann','Shapiro','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435554688),(127,'Ethelyn','Hardter','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435855877),(128,'Verdie','Goucher','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435344599),(129,'Diamond','Koenigsfeld','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1436032240),(130,'Kandace','Moorefield','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435694129),(131,'Delores','Maner','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435864096),(132,'Lucretia','Francher','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435639693),(133,'Nohemi','Tordsen','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435538297),(134,'Suzanna','Wahlberg','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1436037534),(135,'Candy','Chaple','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435494627),(136,'Gay','Amolsch','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435896256),(137,'Synthia','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435374626),(138,'Johnetta','Loudermilk','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435477610),(139,'Ruthann','Troe','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435908974),(140,'Sindy','Marcia','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435723304),(141,'Bebe','Juncaj','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1436011205),(142,'Suzanne','Abuaita','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435667378),(143,'Liliana','Parmeter','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1436167997),(144,'Lakenya','Sorotzkin','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435715225),(145,'Elina','Picasso','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435343812),(146,'Jazmin','Sabat','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1436019460),(147,'Larry','Tahir','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435717686),(148,'Shalonda','Costeira','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','','Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat','active',10,1435376697);
UNLOCK TABLES;
DROP TABLE IF EXISTS `supplier`;
CREATE TABLE `supplier` (
  `supplierid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `co_name` varchar(128) NOT NULL,
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
  PRIMARY KEY (`supplierid`)
) ENGINE=InnoDB AUTO_INCREMENT=109 DEFAULT CHARSET=latin1;
LOCK TABLES `supplier` WRITE;
INSERT INTO `supplier` VALUES (103,'Koepnick Industries','242 Gaydon Lane',NULL,NULL,'Haslemere','Surrey','England','GU27 HV4','+44 875 126294','+44 1621 97303','+44 1229 103437','info@KoepnickIndustriescom','www.KoepnickIndustriescom','http://www.facebook.com/KoepnickIndustriescom','http://www.twitter.com/KoepnickIndustriescom','http://www.linkedin.com/KoepnickIndustriescom'),(104,'Battisto GmbH','70 Reynold Drive',NULL,NULL,'Caerphilly','Caerphilly','Wales','CF83 UA85','+44 1589 88632','+44 1786 96408','+44 1096 105063','info@BattistoGmbHcom','www.BattistoGmbHcom','http://www.facebook.com/BattistoGmbHcom','http://www.twitter.com/BattistoGmbHcom','http://www.linkedin.com/BattistoGmbHcom'),(105,'Hansis Company','237 Wilson Fold',NULL,NULL,'Borehamwood','Hertfordshire','England','WD6 EB49','+44 1433 161620','+44 1306 93679','+44 953 99355','info@HansisCompanycom','www.HansisCompanycom','http://www.facebook.com/HansisCompanycom','http://www.twitter.com/HansisCompanycom','http://www.linkedin.com/HansisCompanycom'),(106,'Brickel Company','21 Kilton Hill',NULL,NULL,'Sandridge','Hertfordshire','England','AL4 6F25','+44 1375 124144','+44 1452 95902','+44 959 143518','info@BrickelCompanycom','www.BrickelCompanycom','http://www.facebook.com/BrickelCompanycom','http://www.twitter.com/BrickelCompanycom','http://www.linkedin.com/BrickelCompanycom'),(107,'Eon Products','176 Mermaid Street',NULL,NULL,'The Scottish Borders','The Scottish Borders','Scotland','EH44 US35','+44 1554 140450','+44 1758 135111','+44 1708 147247','info@EonProductscom','www.EonProductscom','http://www.facebook.com/EonProductscom','http://www.twitter.com/EonProductscom','http://www.linkedin.com/EonProductscom'),(108,'Menon Foundry','278 Sneyd Hall Close',NULL,NULL,'Gravesend','Kent','England','DA12 S289','+44 1114 117390','+44 1682 147646','+44 1175 163408','info@MenonFoundrycom','www.MenonFoundrycom','http://www.facebook.com/MenonFoundrycom','http://www.twitter.com/MenonFoundrycom','http://www.linkedin.com/MenonFoundrycom');
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
	if ( $q =~ /centos/s ) {
		return 'centos';
	}
	return 'unknown';
}
