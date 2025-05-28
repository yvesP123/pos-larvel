FROM php:8.0-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_pgsql pdo_mysql mbstring exif pcntl bcmath gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer files first for better caching
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Copy application files
COPY . .

# Complete composer installation
RUN composer install --optimize-autoloader --no-dev

# Create necessary directories and set permissions
RUN mkdir -p /var/www/html/storage/logs \
    && mkdir -p /var/www/html/storage/framework/{cache,sessions,views} \
    && mkdir -p /var/www/html/bootstrap/cache

# Set permissions before running artisan commands
RUN chown -R www-data:www-data /var/www/html
RUN chmod -R 755 /var/www/html
RUN chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Generate application key (only if not set)
RUN php artisan key:generate --force

# Clear any cached config that might cause issues
RUN php artisan config:clear || true
RUN php artisan cache:clear || true

# Configure Apache
RUN a2enmod rewrite

# Apache configuration
COPY <<EOF /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    DocumentRoot /var/www/html/public
    
    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
        Options -Indexes
    </Directory>
    
    # Enable error logging
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    LogLevel warn
</VirtualHost>
EOF

# PHP configuration for better error reporting
RUN echo "log_errors = On" >> /usr/local/etc/php/conf.d/docker-php-logging.ini
RUN echo "error_log = /var/log/apache2/php_errors.log" >> /usr/local/etc/php/conf.d/docker-php-logging.ini

EXPOSE 80

# Improved start script
COPY <<EOF /usr/local/bin/start.sh
#!/bin/bash
set -e

echo "Starting Laravel application..."

# Skip database operations for now
# echo "Checking database connection..."
# php artisan tinker --execute="DB::connection()->getPdo();"

# echo "Running migrations..."
# php artisan migrate --force

# Clear any problematic cache
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true
php artisan cache:clear || true

# Only cache if not in debug mode
if [ "\$APP_DEBUG" != "true" ]; then
    echo "Optimizing application..."
    php artisan config:cache || true
    php artisan route:cache || true
    php artisan view:cache || true
fi

echo "Starting Apache..."
apache2-foreground
EOF

RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]