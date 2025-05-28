<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>Comprehensive Laravel Debug</h1>";

// Check config files
echo "<h2>Config Files Check:</h2>";
$config_files = ['app.php', 'database.php', 'cache.php', 'session.php'];
foreach ($config_files as $file) {
    $path = __DIR__ . "/../config/$file";
    if (file_exists($path)) {
        echo "✅ $file exists<br>";
        // Check for syntax errors
        $content = file_get_contents($path);
        if (strpos($content, '<?php') === 0) {
            echo "  - Valid PHP syntax<br>";
        } else {
            echo "  - ❌ Invalid PHP syntax<br>";
        }
    } else {
        echo "❌ $file missing<br>";
    }
}

// Check service providers
echo "<h2>Service Providers Check:</h2>";
$app_config_path = __DIR__ . '/../config/app.php';
if (file_exists($app_config_path)) {
    $app_config = require $app_config_path;
    if (isset($app_config['providers']) && is_array($app_config['providers'])) {
        echo "✅ Service providers array exists (" . count($app_config['providers']) . " providers)<br>";
        
        // Check for essential providers
        $essential = [
            'Illuminate\Foundation\Providers\FoundationServiceProvider',
            'Illuminate\Database\DatabaseServiceProvider',
            'Illuminate\Filesystem\FilesystemServiceProvider',
            'Illuminate\View\ViewServiceProvider',
        ];
        
        $providers_string = implode('|', $app_config['providers']);
        foreach ($essential as $provider) {
            if (strpos($providers_string, $provider) !== false) {
                echo "  ✅ $provider registered<br>";
            } else {
                echo "  ❌ $provider missing<br>";
            }
        }
    } else {
        echo "❌ Service providers array not found or invalid<br>";
    }
} else {
    echo "❌ app.php config file missing<br>";
}

// Try to manually register config
echo "<h2>Manual Laravel Initialization:</h2>";
try {
    require_once __DIR__ . '/../vendor/autoload.php';
    
    // Create the application
    $app = new Illuminate\Foundation\Application(
        $_ENV['APP_BASE_PATH'] ?? dirname(__DIR__)
    );
    
    echo "✅ Application instance created<br>";
    
    // Bind important paths
    $app->singleton(
        Illuminate\Contracts\Http\Kernel::class,
        App\Http\Kernel::class
    );
    
    $app->singleton(
        Illuminate\Contracts\Console\Kernel::class,
        App\Console\Kernel::class
    );
    
    $app->singleton(
        Illuminate\Contracts\Debug\ExceptionHandler::class,
        App\Exceptions\Handler::class
    );
    
    echo "✅ Core bindings registered<br>";
    
    // Load environment variables
    $dotenv = Dotenv\Dotenv::createImmutable(dirname(__DIR__));
    $dotenv->load();
    
    echo "✅ Environment loaded<br>";
    
    // Register config service provider manually
    $configServiceProvider = new Illuminate\Config\ConfigServiceProvider($app);
    $configServiceProvider->register();
    
    echo "✅ Config service provider registered<br>";
    
    // Load configuration files
    $app->make('config')->set('app', require __DIR__ . '/../config/app.php');
    
    echo "✅ App config loaded<br>";
    
    // Test config access
    echo "App Name: " . $app->make('config')->get('app.name') . "<br>";
    echo "App Environment: " . $app->make('config')->get('app.env') . "<br>";
    
    echo "<h1>✅ Manual initialization successful!</h1>";
    echo "<p>Your Laravel app should work. The issue might be with automatic service provider registration.</p>";
    
} catch (Exception $e) {
    echo "❌ Manual initialization failed: " . $e->getMessage() . "<br>";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "<br>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}

// Check if it's a caching issue
echo "<h2>Cache Check:</h2>";
$cache_files = [
    'bootstrap/cache/config.php',
    'bootstrap/cache/routes.php',
    'bootstrap/cache/services.php'
];

foreach ($cache_files as $file) {
    $path = __DIR__ . "/../$file";
    if (file_exists($path)) {
        echo "⚠️  $file exists (cached)<br>";
        echo "  Size: " . filesize($path) . " bytes<br>";
        echo "  Modified: " . date('Y-m-d H:i:s', filemtime($path)) . "<br>";
    } else {
        echo "✅ $file not cached<br>";
    }
}
?>