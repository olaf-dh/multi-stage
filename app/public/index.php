<?php

use App\Kernel;

require_once dirname(__DIR__) . '/vendor/autoload_runtime.php';

return function (array $context): Kernel {
    $env = isset($context['APP_ENV']) && is_string($context['APP_ENV'])
        ? $context['APP_ENV']
        : 'dev';

    $debugVal = $context['APP_DEBUG'] ?? false;
    if (is_bool($debugVal)) {
        $debug = $debugVal;
    } elseif (is_string($debugVal)) {
        $debug = filter_var($debugVal, FILTER_VALIDATE_BOOL);
    } elseif (is_int($debugVal)) {
        $debug = $debugVal !== 0;
    } else {
        $debug = false;
    }

    return new Kernel($env, $debug);
};
