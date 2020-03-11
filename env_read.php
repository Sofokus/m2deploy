<?php

if ($argc < 3)
    exit(1);

/** @var string $file */
$file = $argv[1];
/** @var string $path */
$path = $argv[2];
/** @var string $default */
$default = $argv[3] ?? '';

/** @var array $env */
$env = include $file;

foreach(explode('/', $path) as $child) {
    if (!isset($env[$child])) {
        echo $default;
        exit;
    }
    $env = $env[$child];
}

$result = (string)$env;
echo $result ?: $default;
