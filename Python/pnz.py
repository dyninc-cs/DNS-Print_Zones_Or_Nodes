#! /usr/bin/env python

''' 
	This script will print out either a list of all zones or a list of all nodes and optionally write them to a file

	The credentials are read out of a configuration file in the same directory named credentials.cfg in the format:

	[Dynect]
	user : user_name
	customer : customer_name
	password: password

	Usage: %python pnz.py [-z|-n] [options]

	Options:
		  -h, --help            show this help message and exit
		  -z, --zones           Output all zones
		  -n, --nodes           Output all nodes
		  -f FILE, --file=FILE  File to output list to

	The library is available at: https://github.com/dyninc/Dynect-API-Python-Library
'''

import sys
import ConfigParser
from optparse import OptionParser
from DynectDNS import DynectRest

# create an instance of the api reference library to use
dynect = DynectRest()

def login(cust, user, pwd):
	'''	
	This method will do a dynect login

	@param cust: customer name
	@type cust: C{str}
	
	@param user: user name
	@type user: C{str}
	
	@param pwd: password
	@type pwd: C{str}

	@return: Th function will exit the script on failure to login
	@rtype: None
	
	'''
        arguments = {
		'customer_name':  cust,
		'user_name':  user,  
		'password':  pwd,
	}
	response = dynect.execute('/Session/', 'POST', arguments)

	if response['status'] != 'success':
		sys.exit("Incorrect credentials")


def parseZoneURI(zone_uri):
	'''	
	Return back just the zone name from a zone uri
	
	@param zone_uri:  zone uri string
	@type zone_uri: C{str}

	@return: Just the name of the zone
	@rtype: C{str}
	
	'''
	zone_uri = zone_uri.strip('/')
	parts = zone_uri.split('/')
	return parts[len(parts) - 1]

def parseNodeURI(node_uri):
	'''	
	Return back just the fqdn name from an fqdn uri
	
	@param node_uri:  node uri string
	@type node_uri: C{str}

	@return: Just the name of the fqdn
	@rtype: C{str}
	
	'''
	node_uri = node_uri.strip('/')
	parts = node_uri.split('/')
	return parts[len(parts) - 1]

def getNodeList(zone, fqdn=None):
	'''	
	This method will return all the nodes for a zone or fqdn

	@param zone: zone name
	@type zone: C{str}

	@param fqdn: fqdn
	@type fqdn: C{str}
	
	@return: list of all nodes in a zone
	@rtype: C{list}
	
	'''
	ending = '/' + zone + '/'
	if fqdn != None:
		ending = ending + fqdn + '/'
	else:
		ending = ending + zone + '/'
		
	response = dynect.execute('/REST/NodeList' + ending, 'GET')
	if response['status'] != 'success':
		print 'Failed to get nodelist!'
		print response
		return None
	nodes = response['data']
	return nodes

def getZoneFromNode(fqdn):
	'''	
	This method will return all the nodes for a zone for the fqdn

	@param fqdn: fqdn 
	@type fqdn: C{str}
	
	@return: zone name
	@rtype: C{str}
	
	'''
	expanded = fqdn.split('.')
	return expanded[len(expanded) - 2] + '.' + expanded[len(expanded) -1]
	
def getZones():
	'''
	This method will return all the top level zones in the system
	
	@return: zone uri's for all top level zones
	@rtype: list
	'''
	response = dynect.execute('/REST/Zone/', 'GET')
	
	if response['status'] != 'success':
		print "Failed to retrieve zone list"
		print response
		return None
	return response['data']
	
def printZones(file=None):
	'''
	This method will print the top level zones in the system
	
	@param file: optional file to write list to 
	@type file: C{str}
	
	@return: None
	@rtype: 
	'''
	# open the file for writing if it is specified
	f = None
	if file != None:
		try:
			f = open(file, 'w')
		except:
			f = None
			print "Unable to open file for writing"
			
	zones = getZones()
	for zone_uri in zones:
		zone = parseZoneURI(zone_uri)
		if f != None:
			f.write(zone + "\n")
		print zone
		
def printFqdns(file=None):
	'''
	This method will print the fqdns in the system
	
	@param file: optional file to write list to 
	@type file: C{str}
	
	@return: None
	@rtype: 
	'''	
	# open the file for writing if it is specified
	f = None
	if file != None:
		try:
			f = open(file, 'w')
		except:
			f = None
			print "Unable to open file for writing"
			
	zones = getZones()
	for zone_uri in zones:
		zone = parseZoneURI(zone_uri)
		
		nodes = getNodeList(zone)
		for node in nodes:
			n =  parseNodeURI(node)
			if f != None:
				f.write(n + "\n")
			print n
			
usage = "usage: %python pnz.py [-z|-n] [options]"
parser = OptionParser(usage=usage)
parser.add_option("-z", "--zones", action="store_true", dest="zones", default=False, help="Output all zones")
parser.add_option("-n", "--nodes", action="store_true", dest="nodes", default=False, help="Output all nodes")
parser.add_option("-f", "--file", dest="file", help="File to output list to")

(options, args) = parser.parse_args()

# start by validating that the options passed in make sense
val = int(options.zones) + int(options.nodes)
if val != 1:
	parser.error("You must specify exactly one of -n|-z")

# now read in the DynECT user credentials
config = ConfigParser.ConfigParser()
try:
	config.read('credentials.cfg')
except:
	sys.exit("Error Reading Config file")


login(config.get('Dynect', 'customer', 'none'), config.get('Dynect', 'user', 'none'), config.get('Dynect', 'password', 'none'))

if options.zones:
	printZones(options.file)
else:
	printFqdns(options.file)
	
		
# Log out, to be polite
dynect.execute('/Session/', 'DELETE')
