<?php

// Handle challenge URL requests immediately.
if (0 === strpos($_SERVER['REQUEST_URI'], '/challenge')) {
    chdir(__DIR__.'/web/challenge');

    require 'index.php';

    exit;
}

require __DIR__.'/lib/challenge/filter.php';

require_once dirname(__FILE__).'/config/ProjectConfiguration.class.php';

$configuration = ProjectConfiguration::getApplicationConfiguration('qubit', 'prod', false);
sfContext::createInstance($configuration)->dispatch();
