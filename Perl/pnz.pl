#!/usr/bin/perl
#This script will print out the zones or nodes in JSON format.
#It defaults to standard output to be used for piping. 
#You can use the -f flag to specify a file to write to.

#The credentials are read out of a configuration file in the same directory named config.cfg:

#Options:
#-h, --help		Show the help message and exit
#-z, --zones		Prints out the URI's of all the zones
#-n, --nodes		Prints out the nodes on the account
#-f, --file		Filename to send output to

#Usage: This will print out the nodes to standard output.
#perl pnz.pl -n
#Usage: This will print out the zone URI's to example.txt
#perl pnz.pl -z -f example.txt

use warnings;
use strict;
use Data::Dumper;
use XML::Simple;
use Config::Simple;
use Getopt::Long;
use LWP::UserAgent;
use JSON;
use IO::Handle;

#Import DynECT handler
use FindBin;
use lib "$FindBin::Bin/DynECT";  # use the parent directory
require DynECT::DNS_REST;

#Get Options
my $opt_zone;
my $opt_node;
my $opt_help;
my $opt_file="";

GetOptions(
	'help' => \$opt_help,
	'zones' => \$opt_zone,
	'nodes' => \$opt_node,
	'file=s' =>\$opt_file,
);


#Printing help menu
if ($opt_help) {
	print "\tOptions:\n";
	print "\t\t-h, --help\t\t Show this help message and exit\n";
	print "\t\t-z, --zones\t\t Prints out the URI's of all the zones\n";
	print "\t\t-n, --nodes\t\t Prints out the nodes no the account\n";
	print "\t\t-f, --file\t\t Filename to send JSON output to\n\n";
	exit;
}

# Dont let the program run unless -z or -n are set
if (($opt_zone && $opt_node) || (!$opt_zone && !$opt_node))
{
	print "Please enter \"-z\" or \"-n\"\n";
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

#API login & zone request
my $dynect = DynECT::DNS_REST->new;
$dynect->login( $apicn, $apiun, $apipw) or die $dynect->message;
$dynect->request( '/REST/Zone/', 'GET') or die $dynect->message;

#Open file for output
open my $fh, ">", $opt_file unless ($opt_file eq "");

#If -z is set, print out the information
if($opt_zone)
{
	#Print out information to either user or file
	print $fh encode_json($dynect->result->{'data'}) unless ($opt_file eq "");
	print encode_json($dynect->result->{'data'}) unless ($opt_file ne "");

}
#Go through the zones and print the nodes if -n is set
else
{
	foreach my $zoneIn (@{$dynect->result->{'data'}})
	{
		#Getting the zone name out of the response.
		$zoneIn =~ /\/REST\/Zone\/(.*)\/$/;
		#If -n is set, print the nodes
		$dynect->request( "/REST/NodeList/$1", "GET" ) or die $dynect->message;
		#Print each node in zone
		print $fh encode_json($dynect->result->{'data'}) unless ($opt_file eq "");
		print encode_json($dynect->result->{'data'}) unless ($opt_file ne "");
	}
}

close $fh unless ($opt_file eq "");

#api logout
$dynect->logout;

