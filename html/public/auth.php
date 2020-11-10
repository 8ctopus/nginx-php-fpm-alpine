<?php

$user = $_SERVER['PHP_AUTH_USER'] ?? null;
$pass = $_SERVER['PHP_AUTH_PW'] ?? null;

if (!isset($user) && !isset($pass)) {
    //return response('Unauthorized', 401, ['WWW-Authenticate' => 'Basic']);
    header('WWW-Authenticate: Basic');
}
else
if ($user == '1' and $pass == '1') {
    echo('you\'re authorized');
}
else {
    echo('you\'re NOT authorized');
}