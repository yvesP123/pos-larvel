FROM php:8.0-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libzip-dev \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_pgsql \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Set composer memory limit and disable platform requirements
ENV COMPOSER_MEMORY_LIMIT=-1
ENV COMPOSER_ALLOW_SUPERUSER=1

# Copy composer files first for better caching
COPY composer.json composer.lock* ./

# Clear composer cache and install dependencies with better error handling
RUN composer clear-cache && \
    composer install \
    --no-scripts \
    --no-autoloader \
    --no-dev \
    --prefer-dist \
    --ignore-platform-reqs \
    --optimize-autoloader \
    --no-interaction \
    --verbose || \
    (echo "First install failed, trying with updates..." && \
     composer update --no-scripts --no-dev --ignore-platform-reqs --no-interaction --verbose && \
     composer install --no-scripts --no-autoloader --no-dev --prefer-dist --ignore-platform-reqs --no-interaction)

# Copy application files
COPY . .

# Copy .env.example to .env if .env doesn't exist
RUN if [ ! -f .env ]; then cp .env.example .env; fi

# Complete composer installation with error handling
RUN composer dump-autoload --optimize --no-dev --no-interaction || \
    (composer dump-autoload --optimize --no-interaction)

# Create necessary directories
RUN mkdir -p storage/logs \
    && mkdir -p storage/framework/cache \
    && mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p bootstrap/cache

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 storage bootstrap/cache

# Generate application key
RUN php artisan key:generate --no-interaction

# Clear and cache configurations (with error handling)
RUN php artisan config:clear || true
RUN php artisan cache:clear || true
RUN php artisan view:clear || true
RUN php artisan route:clear || true

# Only cache in production
RUN php artisan config:cache || true

# Configure Apache
RUN a2enmod rewrite

# Create Apache configuration
RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/public\n\
    ServerName localhost\n\
    \n\
    <Directory /var/www/html/public>\n\
        Options -Indexes +FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
        \n\
        # Handle Laravel routing\n\
        RewriteEngine On\n\
        RewriteCond %{REQUEST_FILENAME} !-d\n\
        RewriteCond %{REQUEST_FILENAME} !-f\n\
        RewriteRule ^(.*)$ index.php [QSA,L]\n\
    </Directory>\n\
    \n\
    # Logging\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
    LogLevel warn\n\
    \n\
    # Security headers\n\
    Header always set X-Content-Type-Options nosniff\n\
    Header always set X-Frame-Options DENY\n\
    Header always set X-XSS-Protection "1; mode=block"\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# Enable headers module for security headers
RUN a2enmod headers

# PHP configuration for production
RUN echo 'log_errors = On\n\
error_log = /var/log/apache2/php_errors.log\n\
display_errors = Off\n\
display_startup_errors = Off\n\
expose_php = Off\n\
max_execution_time = 300\n\
memory_limit = 256M\n\
post_max_size = 32M\n\
upload_max_filesize = 32M\n\
max_file_uploads = 20' > /usr/local/etc/php/conf.d/laravel.ini

# Create startup script
COPY <<'EOF' /usr/local/bin/start.sh
#!/bin/bash
set -e

echo "🚀 Starting Laravel Application..."

# Check if APP_KEY is set
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "base64:" ]; then
    echo "⚠️  APP_KEY not set, generating..."
    php artisan key:generate --force --no-interaction
fi

# Wait for database if needed (optional)
if [ -n "$DB_HOST" ]; then
    echo "⏳ Checking database connection..."
    php -r "
        try {
            \$pdo = new PDO('mysql:host=$DB_HOST;port=${DB_PORT:-3306};dbname=$DB_DATABASE', '$DB_USERNAME', '$DB_PASSWORD');
            echo '✅ Database connection successful' . PHP_EOL;
        } catch (Exception \$e) {
            echo '⚠️  Database connection failed: ' . \$e->getMessage() . PHP_EOL;
            echo 'Continuing without database...' . PHP_EOL;
        }
    "
fi

# Run migrations if requested
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "🔄 Running database migrations..."
    php artisan migrate --force --no-interaction || echo "⚠️  Migrations failed, continuing..."
fi

# Clear caches in development
if [ "$APP_ENV" = "local" ] || [ "$APP_DEBUG" = "true" ]; then
    echo "🧹 Clearing caches for development..."
    php artisan config:clear || true
    php artisan route:clear || true
    php artisan view:clear || true
    php artisan cache:clear || true
else
    echo "🚀 Optimizing for production..."
    php artisan config:cache || true
    php artisan route:cache || true
    php artisan view:cache || true
fi

# Ensure proper permissions
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "✅ Laravel application ready!"
echo "📊 Environment: ${APP_ENV:-production}"
echo "🐛 Debug mode: ${APP_DEBUG:-false}"

# Start Apache
exec apache2-foreground
EOF

RUN chmod +x /usr/local/bin/start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["/usr/local/bin/start.sh"]