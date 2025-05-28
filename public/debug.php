<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>Laravel Full Bootstrap Test</h1>";

try {
    // Autoload
    require_once __DIR__ . '/../vendor/autoload.php';
    echo "✅ Autoload successful<br>";
    
    // Bootstrap Laravel application
    $app = require_once __DIR__ . '/../bootstrap/app.php';
    echo "✅ App created<br>";
    
    // Create and boot the HTTP kernel
    $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
    echo "✅ HTTP Kernel created<br>";
    
    // Create a request
    $request = Illuminate\Http\Request::capture();
    echo "✅ Request captured<br>";
    
    // Boot the application properly
    $app->boot();
    echo "✅ Application booted<br>";
    
    // Now test configuration access
    echo "<h2>Configuration Test (After Boot):</h2>";
    echo "App Name: " . config('app.name') . "<br>";
    echo "App Environment: " . config('app.env') . "<br>";
    echo "App Debug: " . (config('app.debug') ? 'true' : 'false') . "<br>";
    echo "App Key Set: " . (config('app.key') ? 'Yes' : 'No') . "<br>";
    
    // Test basic Laravel functionality
    echo "<h2>Laravel Functions Test:</h2>";
    echo "App Environment: " . app()->environment() . "<br>";
    echo "Base Path: " . base_path() . "<br>";
    echo "Storage Path: " . storage_path() . "<br>";
    
    // Test route resolution
    echo "<h2>Route Test:</h2>";
    $router = app('router');
    echo "Router instance: " . (is_object($router) ? "✅ Created" : "❌ Failed") . "<br>";
    
    echo "<h1>✅ Laravel is working properly!</h1>";
    echo "<p><a href='/'>Try your main application now</a></p>";
    
} catch (Exception $e) {
    echo "<h1>❌ Laravel Bootstrap Failed</h1>";
    echo "Error: " . $e->getMessage() . "<br>";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "<br>";
    echo "<h3>Stack Trace:</h3>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
?>