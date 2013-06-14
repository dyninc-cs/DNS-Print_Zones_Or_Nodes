#!/usr/bin/perl
#This script will print out either a list of all zones or a list of all nodes and optionally write them to a file

#The credentials are read out of a configuration file in the same directory named credentials.cfg in the format:

#[Dynect]
#user : user_name
#customer : customer_name
#password: password

#Usage: %perl pnz.pl [-z|-n] [options]

#Options:
#-h, --help            show this help message and exit
#-z, --zones           Output all zones
#-n, --nodes           Output all nodes
#-f FILE, --file=FILE  File to output list to

use warnings;
use strict;
use Data::Dumper;
use XML::Simple;
use Config::Simple;
use Getopt::Long qw(:config no_ignore_case);
use LWP::UserAgent;
use JSON;

#Get Options
my $opt_zone;
my $opt_node;
my $opt_help;
my $list;
my $opt_file="";

GetOptions(
	'help' => \$opt_help,
	'zones' => \$opt_zone,
	'nodes' => \$opt_node,
	'file=s' =>\$opt_file,
);

if ($opt_zone && $opt_node)
{
	print "Please enter -z or -n\n";
	exit 1;
}

#Printing help menu
if ($opt_help) {
	print "\tAPI integration requires paramaters stored in config.cfg\n\n";

	print "\tOptions:\n";
	print "\t\t-h, --help\t\t Show the help message and exit\n";
	print "\t\t-z, --zones\t\t Print the zones\n";
	print "\t\t-n, --nodes\t\t Print the nodes\n";
	print "\t\t-f, --file\t\t File to output\n\n";
	exit;
}

#Create config reader
my $cfg = new Config::Simple();

# read configuration file (can fail)
$cfg->read('config.cfg') or die $cfg->error();


#dump config variables into hash for later use
my %configopt = $cfg->vars();
my $apicn = $configopt{'cn'} or do {
	print "Customer Name required in config.cfg for API login\n";
	exit;
};

my $apiun = $configopt{'un'} or do {
	print "User Name required in config.cfg for API login\n";
	exit;
};

my $apipw = $configopt{'pw'} or do {
	print "User password required in config.cfg for API login\n";
	exit;
};

#API login
my $session_uri = 'https://api2.dynect.net/REST/Session';
my %api_param = ( 
	'customer_name' => $apicn,
	'user_name' => $apiun,
	'password' => $apipw,
);

#API Login
my $api_request = HTTP::Request->new('POST',$session_uri);
$api_request->header ( 'Content-Type' => 'application/json' );
$api_request->content( to_json( \%api_param ) );

my $api_lwp = LWP::UserAgent->new;
my $api_result = $api_lwp->request( $api_request );

my $api_decode = decode_json ( $api_result->content ) ;
my $api_key = $api_decode->{'data'}->{'token'};

#$api_decode = &api_request("https://api2.dynect.net/REST/Session/", 'POST', %api_param); 

#Zone delete
if($opt_zone)
{
	##Set param to empty
	%api_param = ();
	$session_uri = "https://api2.dynect.net/REST/Zone/";
	$api_decode = &api_request($session_uri, 'GET', %api_param); 
	$list .= "==============Zones==============\n";
	foreach my $zoneIn (@{$api_decode->{'data'}})
	{
		#Print each zone	
		$list .= "$zoneIn\n";
	}
	$list .= "=================================\n";
	#Print list of zones user
	print $list;
	#Write to file if opt_file is set
	&write_file( $opt_file, \$list) unless ($opt_file eq "");
}

#Node delete
if($opt_node)
{
	
	#Set param to empty
	%api_param = ();
	$session_uri = "https://api2.dynect.net/REST/Zone/";
	$api_decode = &api_request($session_uri, 'GET', %api_param); 
	$list = "==============Nodes==============\n";
	foreach my $zoneIn (@{$api_decode->{'data'}})
	{
		#Print each zone	
		
		$list .= "Zone: $zoneIn\n";
		#Getting the zone name out of the response.
		$zoneIn =~ /\/REST\/Zone\/(.*)$/;
		%api_param = ();
		$session_uri = "https://api2.dynect.net/REST/NodeList/$1";
		$api_decode = &api_request($session_uri, 'GET', %api_param); 

		#Print each node in zone
		$list .= "Nodes: \n";
		foreach my $nodeIn (@{$api_decode->{'data'}})
		{$list .= "\t$nodeIn\n";}
		$list .= "=================================\n";
	}
	#Print list of nodes to uesr.
	print $list;
	#Write to file if opt_file is set
	&write_file( $opt_file, \$list) unless ($opt_file eq "");
}


#api logout
%api_param = ();
$session_uri = 'https://api2.dynect.net/REST/Session';
&api_request($session_uri, 'DELETE', %api_param); 

sub write_file{
	my( $opt_file, $list_ref ) = @_ ;
	open( my $fh, ">$opt_file" ) || die "can't create $opt_file $!" ;
	print $fh $$list_ref ;
}

#Accepts Zone URI, Request Type, and Any Parameters
sub api_request{
	#Get in variables, send request, send parameters, get result, decode, display if error
	my ($zone_uri, $req_type, %api_param) = @_;
	$api_request = HTTP::Request->new($req_type, $zone_uri);
	$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $api_key );
	$api_request->content( to_json( \%api_param ) );
	$api_result = $api_lwp->request($api_request);
	$api_decode = decode_json( $api_result->content);
	$api_decode = &api_fail(\$api_key, $api_decode) unless ($api_decode->{'status'} eq 'success');
	return $api_decode;
}

#Expects 2 variable, first a reference to the API key and second a reference to the decoded JSON response
sub api_fail {
	my ($api_keyref, $api_jsonref) = @_;
	#set up variable that can be used in either logic branch
	my $api_request;
	my $api_result;
	my $api_decode;
	my $api_lwp = LWP::UserAgent->new;
	my $count = 0;
	#loop until the job id comes back as success or program dies
	while ( $api_jsonref->{'status'} ne 'success' ) {
		if ($api_jsonref->{'status'} ne 'incomplete') {
			foreach my $msgref ( @{$api_jsonref->{'msgs'}} ) {
				print "API Error:\n";
				print "\tInfo: $msgref->{'INFO'}\n" if $msgref->{'INFO'};
				print "\tLevel: $msgref->{'LVL'}\n" if $msgref->{'LVL'};
				print "\tError Code: $msgref->{'ERR_CD'}\n" if $msgref->{'ERR_CD'};
				print "\tSource: $msgref->{'SOURCE'}\n" if $msgref->{'SOURCE'};
			};
			#api logout or fail
			%api_param = ();
			my $zone_uri = "https://api2.dynect.net/REST/Session";
			my $api_decode = &api_request("$zone_uri", 'PUT', %api_param); 
			$api_decode = decode_json ( $api_result->content);
			exit;
		}
		else {
			sleep(5);
			my $job_uri = "https://api2.dynect.net/REST/Job/$api_jsonref->{'job_id'}/";
			$api_jsonref = &api_request("$job_uri", 'GET', %api_param); 
		}
	}
	$api_jsonref;
}
