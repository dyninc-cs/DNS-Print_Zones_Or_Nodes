#!/usr/bin/php
<?php
#This script will print out either a list of all zones or a list of all nodes and optionally write them to a file

#The credentials are read out of a configuration file in the same directory named conifg.ini in the format:

#Usage: %php pnz.php [-z|-n] [options]

#Options:
#-h, --help		Show this help message and exit
#-z, --zones		Output all zones
#-n, --nodes		Output all nodes
#-f, --file		File to output list to

#Get options from command line
$shortopts .= "f:"; 
$shortopts .= "z"; 
$shortopts .= "n";  
$shortopts .= "h"; 
$longopts  = array(
			"file::",	
			"zones",
			"nodes",   
			"help",);	
$options = getopt($shortopts, $longopts);

#Set file to -f
$opt_file .= $options["f"]; 

#Print help menu
if (is_bool($options["h"])) {
        print "\tAPI integration requires paramaters stored in config.cfg\n\n";
        print "\tOptions:\n";
        print "\t\t-h, --help\t\t Show the help message and exit\n";
        print "\t\t-z, --zones\t\t Print the zones\n";
        print "\t\t-n, --nodes\t\t Print the nodes\n";
        print "\t\t-f, --file\t\t File to output\n\n";
        exit;
}
// Parse ini file (can fail)
$ini_array = parse_ini_file("config.ini") or die;

#Set the values from file to variables or die
$api_cn = $ini_array['cn'] or die("Customer Name required in config.ini for API login\n");
$api_un = $ini_array['un'] or die("User Name required in config.ini for API login\n");
$api_pw = $ini_array['pw'] or die("Password required in config.ini for API login\n");	

# Set opt_node to true if user enters -n or -nodes
if (is_bool($options["n"]) || is_bool($options["nodes"])) {$opt_node = true;}

# Set opt_zone to true if user enters -z or -zones
if (is_bool($options["z"]) || is_bool($options["zones"])) {$opt_zone = true;}

# Prevent the user from proceeding if they have not entered -n or -z
if(!$opt_zone == true && !$opt_node == true)
{
	print "You must enter either \"-z\" or \"-n\"\n";
	exit;
}

#If the file is to be written to file, start ob
if(is_string($options["f"])){ob_start();}

# Log into DYNECT
# Create an associative array with the required arguments
$api_params = array(
			'customer_name' => $api_cn,
			'user_name' => $api_un,
			'password' => $api_pw);
$session_uri = 'https://api2.dynect.net/REST/Session/'; 
$decoded_result = api_request($session_uri, 'POST', $api_params,  $token);	

#Set the token
if($decoded_result->status == 'success'){
	$token = $decoded_result->data->token;
}
else{
	#Print the result if it's an error
	foreach($decoded_result->msgs as $message){
		print $message->LVL.": ".($message->ERR_CD != '' ? '('.$message->ERR_CD.') ' : '').$message->SOURCE." - ".$message->INFO."\n\n";
	}
	exit;
}


# Zone URI & Empty Params	
$session_uri = 'https://api2.dynect.net/REST/Zone/'; 
$api_params = array (''=>'');
$decoded_result = api_request($session_uri, 'GET', $api_params,  $token);	

# For each zone print the zone name & nodes if requested
foreach($decoded_result->data as $zonein){

	# Getting ZoneName out of result
	preg_match("/\/REST\/Zone\/(.*)\/$/", $zonein, $matches);
	$zoneName = $matches[1];
	
	# Print out each zone
	print "ZONE: ".$zoneName . "\n";

	# If the user want to see the nodes
	if($opt_node == true)
	{
		# Zone URI & Empty Params	
		$session_uri = 'https://api2.dynect.net/REST/NodeList/'. $zoneName . '/'; 
		$api_params = array (''=>'');
		$decoded_result = api_request($session_uri, 'GET', $api_params,  $token);	
		#Print Nodes
		foreach($decoded_result->data as $nodein){
			print "\tNODE: " . $nodein. "\n";
		}
	}
}

#If -f is set, send the output to the file
if(is_string($options['f']))
{
	$output = ob_get_contents();
	ob_end_flush();
	$fp = fopen($opt_file,"w");
	fwrite($fp,$output);
	fclose($fp);
}

# Logging Out
$session_uri = 'https://api2.dynect.net/REST/Session/'; 
$api_params = array (''=>'');
$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	

#Print result if error occurs
if(!$decoded_result->status == 'success'){
	foreach($decoded_result->msgs as $message){
        	print $message->LVL.": ".($message->ERR_CD != '' ? '('.$message->ERR_CD.') ' : '').$message->SOURCE." - ".$message->INFO."\n";
	}
}

# Function that takes zone uri, request type, parameters, and token.
# Returns the decoded result
function api_request($zone_uri, $req_type, $api_params, $token)
{
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);  # TRUE to return the transfer as a string of the return value of curl_exec() instead of outputting it out directly.
	curl_setopt($ch, CURLOPT_FAILONERROR, false); # Do not fail silently. We want a response regardless
	curl_setopt($ch, CURLOPT_HEADER, false); # disables the response header and only returns the response body
	curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json','Auth-Token: '.$token)); # Set the token and the content type so we know the response format
	curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $req_type);
	curl_setopt($ch, CURLOPT_URL, $zone_uri); # Where this action is going,
	curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($api_params));
	
	$http_result = curl_exec($ch);
	
	$decoded_result = json_decode($http_result); # Decode from JSON as our results are in the same format as our request
	
	return $decoded_result;
}

?>

