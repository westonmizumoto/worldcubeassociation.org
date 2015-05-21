<?php
// THIS FILE CAME FROM webroot/results/includes/_config.php.template
// data here is loaded into configuration class.  Should be accessed by via configuration object (global $config in _framework file).

$config['database']['host'] = 'localhost';
$config['database']['user'] = 'root';
$config['database']['pass'] = '<%= @secrets['mysql_password'] %>';
$config['database']['name'] = 'cubing_results';

// Currently used on /results/media_insertion.php
$config['recaptcha']['publickey'] = '<%= @secrets['RECAPTCHA_PUBLIC_KEY'] %>';
$config['recaptcha']['privatekey'] = '<%= @secrets['RECAPTCHA_PRIVATE_KEY'] %>';

$config['maps']['api_key'] = '<%= @secrets['GOOGLE_MAPS_API_KEY'] %>';

// check for PEAR mail (to send auth email)
if(class_exists('Mail')) {
  $config['mail']['pear'] = true;
} else {
  $config['mail']['pear'] = false;
}

if($config['mail']['pear']) {
  $config['mail']['from'] = 'no-reply@worldcubeassociation.org';
  $config['mail']['host'] = 'ssl://smtp.mandrillapp.com';
  $config['mail']['port'] = '587';
  $config['mail']['user'] = '<%= @secrets['MANDRILL_USERNAME'] %>';
  $config['mail']['pass'] = '<%= @secrets['MANDRILL_PASSWORD'] %>';
} else {
  $config['mail']['from'] = 'no-reply@worldcubeassociation.org';
}


// pathToRoot and filesPath are determined by config class - just a placeholder here.  You can enter an explicit value if desired.  Include trailing slash.
// pathToRoot is for web urls, etc.  May be different than filesystem paths.  Eg, "/results/".
$config['pathToRoot'] = "/results/";
// filesPath is absolute path for system files.  May be different than web urls.  Eg, "/var/www/results/".
$config['filesPath'] = realpath(dirname(__FILE__) . "../");