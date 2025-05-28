#!/usr/bin/env bash
# Build script for Render

# Install PHP dependencies
composer install --optimize-autoloader --no-dev

# Clear and cache config
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Run database migrations
php artisan migrate --force