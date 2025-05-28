<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>Laravel Deployment Debug</h1>";

// Check if .env file exists
echo "<h2>Environment File Check:</h2>";
$env_files = ['.env', '.env.example'];
foreach ($env_files as $file) {
    $path = __DIR__ . "/../$file";
    if (file_exists($path)) {
        echo "✅ $file exists<br>";
        $content = file_get_contents($path);
        if (strpos($content, 'APP_KEY=') !== false) {
            $app_key_line = '';
            foreach (explode("\n", $content) as $line) {
                if (strpos($line, 'APP_KEY=') === 0) {
                    $app_key_line = $line;
                    break;
                }
            }
            if (strlen(trim(str_replace('APP_KEY=', '', $app_key_line))) > 10) {
                echo "  ✅ APP_KEY is set<br>";
            } else {
                echo "  ❌ APP_KEY is empty or too short<br>";
            }
        } else {
            echo "  ❌ APP_KEY not found in $file<br>";
        }
    } else {
        echo "❌ $file missing<br>";
    }
}

// Check vendor directory and autoloader
echo "<h2>Composer Dependencies Check:</h2>";
$vendor_path = __DIR__ . '/../vendor';
if (is_dir($vendor_path)) {
    echo "✅ vendor directory exists<br>";
    
    $autoload_path = $vendor_path . '/autoload.php';
    if (file_exists($autoload_path)) {
        echo "✅ autoload.php exists<br>";
        
        try {
            require_once $autoload_path;
            echo "✅ Autoloader loaded successfully<br>";
        } catch (Exception $e) {
            echo "❌ Autoloader failed: " . $e->getMessage() . "<br>";
        }
    } else {
        echo "❌ autoload.php missing<br>";
    }
} else {
    echo "❌ vendor directory missing - Run 'composer install'<br>";
}

// Check Laravel classes
echo "<h2>Laravel Framework Check:</h2>";
$classes_to_check = [
    'Illuminate\Foundation\Application',
    'Illuminate\Config\Repository',
    'Dotenv\Dotenv'
];

foreach ($classes_to_check as $class) {
    if (class_exists($class)) {
        echo "✅ $class available<br>";
    } else {
        echo "❌ $class not found<br>";
    }
}

// Check file permissions
echo "<h2>File Permissions Check:</h2>";
$paths_to_check = [
    'storage',
    'bootstrap/cache',
    'storage/logs',
    'storage/framework/cache',
    'storage/framework/sessions',
    'storage/framework/views'
];

foreach ($paths_to_check as $path) {
    $full_path = __DIR__ . "/../$path";
    if (is_dir($full_path)) {
        $perms = fileperms($full_path);
        $perms_octal = substr(sprintf('%o', $perms), -4);
        echo "✅ $path exists (permissions: $perms_octal)<br>";
        
        if (is_writable($full_path)) {
            echo "  ✅ Writable<br>";
        } else {
            echo "  ❌ Not writable<br>";
        }
    } else {
        echo "❌ $path missing<br>";
    }
}

// Try proper Laravel bootstrap
echo "<h2>Laravel Bootstrap Test:</h2>";
try {
    // Check if we have all required components
    if (!file_exists(__DIR__ . '/../vendor/autoload.php')) {
        throw new Exception("Composer autoloader not found");
    }
    
    if (!file_exists(__DIR__ . '/../.env')) {
        throw new Exception(".env file not found");
    }
    
    // Load the autoloader
    require_once __DIR__ . '/../vendor/autoload.php';
    
    // Create Laravel application instance
    $app = new Illuminate\Foundation\Application(
        $_ENV['APP_BASE_PATH'] ?? dirname(__DIR__)
    );
    
    echo "✅ Application instance created<br>";
    
    // Load environment variables first
    if (class_exists('Dotenv\Dotenv')) {
        $dotenv = Dotenv\Dotenv::createImmutable(dirname(__DIR__));
        $dotenv->load();
        echo "✅ Environment variables loaded<br>";
    }
    
    // Register the config service provider
    $app->singleton('config', function() {
        return new Illuminate\Config\Repository();
    });
    
    // Load config files with proper error handling
    $config_files = ['app', 'database', 'cache', 'session'];
    foreach ($config_files as $config_name) {
        $config_path = __DIR__ . "/../config/$config_name.php";
        if (file_exists($config_path)) {
            try {
                $config_data = require $config_path;
                $app['config'][$config_name] = $config_data;
                echo "✅ $config_name.php loaded<br>";
            } catch (Exception $e) {
                echo "❌ Error loading $config_name.php: " . $e->getMessage() . "<br>";
            }
        }
    }
    
    // Test config access
    if ($app['config']->has('app.name')) {
        echo "✅ Config accessible - App Name: " . $app['config']->get('app.name') . "<br>";
    }
    
    echo "<h1>✅ Laravel bootstrap successful!</h1>";
    
} catch (Exception $e) {
    echo "❌ Laravel bootstrap failed: " . $e->getMessage() . "<br>";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "<br>";
    
    // More specific error diagnosis
    if (strpos($e->getMessage(), 'env()') !== false) {
        echo "<h3>🔍 env() Function Issue Detected:</h3>";
        echo "The env() function is not available. This usually means:<br>";
        echo "1. Laravel helpers are not loaded<br>";
        echo "2. Environment variables are not loaded<br>";
        echo "3. The application is not properly bootstrapped<br>";
    }
}

// Check cache files (these can cause issues)
echo "<h2>Cache Files Check:</h2>";
$cache_files = [
    'bootstrap/cache/config.php',
    'bootstrap/cache/routes.php',
    'bootstrap/cache/services.php'
];

$cache_issues = false;
foreach ($cache_files as $file) {
    $path = __DIR__ . "/../$file";
    if (file_exists($path)) {
        echo "⚠️  $file exists (may cause issues)<br>";
        $cache_issues = true;
    } else {
        echo "✅ $file not cached<br>";
    }
}

if ($cache_issues) {
    echo "<h3>🔧 Recommendation: Clear cached files</h3>";
    echo "Run these commands:<br>";
    echo "- php artisan config:clear<br>";
    echo "- php artisan route:clear<br>";
    echo "- php artisan cache:clear<br>";
    echo "Or manually delete the files above.<br>";
}

// Environment-specific checks
echo "<h2>Environment-Specific Checks:</h2>";
echo "PHP Version: " . PHP_VERSION . "<br>";
echo "Server Software: " . ($_SERVER['SERVER_SOFTWARE'] ?? 'Unknown') . "<br>";
echo "Document Root: " . ($_SERVER['DOCUMENT_ROOT'] ?? 'Unknown') . "<br>";
echo "Current Working Directory: " . getcwd() . "<br>";

?>