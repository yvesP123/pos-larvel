<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>Laravel Debug Information</h1>";
echo "PHP Version: " . phpversion() . "<br>";
echo "Current Directory: " . __DIR__ . "<br>";
echo "Document Root: " . ($_SERVER['DOCUMENT_ROOT'] ?? 'Not set') . "<br>";

// Check critical Laravel files
$files = [
    '../.env' => '.env file',
    '../bootstrap/app.php' => 'Bootstrap file',
    '../vendor/autoload.php' => 'Composer autoload',
    '../config/app.php' => 'App config',
    '../storage' => 'Storage directory',
    '../bootstrap/cache' => 'Bootstrap cache'
];

echo "<h2>File System Check:</h2>";
foreach ($files as $file => $desc) {
    $path = __DIR__ . '/' . $file;
    $exists = file_exists($path);
    echo "$desc: ";
    if ($exists) {
        echo "✅ EXISTS";
        if (is_dir($path)) {
            echo " (writable: " . (is_writable($path) ? "✅ YES" : "❌ NO") . ")";
        }
    } else {
        echo "❌ MISSING";
    }
    echo "<br>";
}

// Check environment variables
echo "<h2>Environment Check:</h2>";
$envFile = __DIR__ . '/../.env';
if (file_exists($envFile)) {
    echo "✅ .env file exists<br>";
    $envContent = file_get_contents($envFile);
    echo "APP_KEY present: " . (strpos($envContent, 'APP_KEY=') !== false ? "✅ YES" : "❌ NO") . "<br>";
    echo "APP_DEBUG value: " . (strpos($envContent, 'APP_DEBUG=true') !== false ? "TRUE" : "FALSE") . "<br>";
} else {
    echo "❌ .env file missing<br>";
}

// Test Laravel Bootstrap
echo "<h2>Laravel Bootstrap Test:</h2>";
try {
    // Test autoload
    if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
        require_once __DIR__ . '/../vendor/autoload.php';
        echo "✅ Autoload successful<br>";
    } else {
        throw new Exception("Autoload file missing");
    }
    
    // Test Laravel bootstrap
    if (file_exists(__DIR__ . '/../bootstrap/app.php')) {
        $app = require_once __DIR__ . '/../bootstrap/app.php';
        echo "✅ Laravel bootstrap successful<br>";
        
        // Test kernel creation
        $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
        echo "✅ HTTP Kernel created<br>";
        
        // Test basic request
        $request = Illuminate\Http\Request::capture();
        echo "✅ Request captured<br>";
        
    } else {
        throw new Exception("Bootstrap file missing");
    }
    
} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "<br>";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "<br>";
    echo "<h3>Stack Trace:</h3>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}

// Test Laravel config loading
echo "<h2>Configuration Test:</h2>";
try {
    if (isset($app)) {
        $config = $app->make('config');
        echo "App Name: " . $config->get('app.name', 'Not found') . "<br>";
        echo "App Environment: " . $config->get('app.env', 'Not found') . "<br>";
        echo "App Debug: " . ($config->get('app.debug') ? 'true' : 'false') . "<br>";
        echo "App Key Set: " . ($config->get('app.key') ? 'Yes' : 'No') . "<br>";
    }
} catch (Exception $e) {
    echo "❌ Config Error: " . $e->getMessage() . "<br>";
}

echo "<h2>PHP Extensions:</h2>";
$required = ['mbstring', 'pdo', 'pdo_mysql', 'openssl', 'tokenizer', 'xml', 'ctype', 'json', 'bcmath'];
foreach ($required as $ext) {
    echo "$ext: " . (extension_loaded($ext) ? "✅ Loaded" : "❌ Missing") . "<br>";
}

echo "<h2>Memory & Limits:</h2>";
echo "Memory Limit: " . ini_get('memory_limit') . "<br>";
echo "Max Execution Time: " . ini_get('max_execution_time') . "<br>";
echo "Current Memory Usage: " . round(memory_get_usage(true) / 1024 / 1024, 2) . " MB<br>";
?>