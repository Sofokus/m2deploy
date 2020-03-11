<?php

if ($argc < 3)
    exit(1);

/** @var string $old */
$old = $argv[1];
/** @var string $new */
$new = $argv[2];

/** @var array $oldConfig */
$oldConfig = include $old;
$oldModules = $oldConfig['modules'];

/** @var array $newConfig */
$newConfig = include $new;
$newModules = $newConfig['modules'];
if (empty($newModules))
    exit(1);

$removed = array_keys(array_diff_key($oldModules, $newModules));
echo implode(' ', $removed);
