# Use PHP 8.1 with Apache
FROM php:8.1-apache

# Set environment variables
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
ENV COMPOSER_CACHE_DIR=/tmp/composer-cache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libzip-dev \
    zip \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Configure GD (used by DOMPDF, barcodes)
RUN docker-php-ext-configure gd \
    && docker-php-ext-install \
        gd \
        pdo_mysql \
        mbstring \
        bcmath \
        exif \
        pcntl \
        zip

# Install Composer (from official image)
COPY --from=composer:2.5 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer files and install dependencies
COPY composer.json composer.lock* ./

RUN mkdir -p /tmp/composer-cache && \
    composer install --no-dev --prefer-dist --no-interaction

# Copy the rest of the application
COPY . .

# Make sure .env exists (default if not overridden)
RUN cp .env.example .env || true

# Laravel setup: autoload, permissions, cache clearing
RUN composer dump-autoload --optimize && \
    php artisan config:clear && \
    php artisan cache:clear && \
    php artisan view:clear && \
    php artisan storage:link || true

# Set file permissions
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 775 storage bootstrap/cache

# Enable Apache modules
RUN a2enmod rewrite headers

# Set up Apache virtual host
RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        AllowOverride All\n\
        Require all granted\n\
        Options -Indexes\n\
        RewriteEngine On\n\
        RewriteCond %{REQUEST_FILENAME} !-d\n\
        RewriteCond %{REQUEST_FILENAME} !-f\n\
        RewriteRule ^(.*)$ index.php [QSA,L]\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# PHP production settings
RUN echo 'memory_limit = 512M\n\
upload_max_filesize = 100M\n\
post_max_size = 100M\n\
max_execution_time = 300\n\
log_errors = On\n\
error_log = /var/log/apache2/php_errors.log\n\
display_errors = Off' > /usr/local/etc/php/conf.d/laravel.ini

# Startup script to finalize Laravel config
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting Laravel..."\n\
if ! grep -q "APP_KEY=" .env || grep -q "APP_KEY=$" .env; then\n\
    php artisan key:generate --force --no-interaction\n\
fi\n\
php artisan config:clear || true\n\
php artisan cache:clear || true\n\
php artisan view:clear || true\n\
php artisan config:cache || true\n\
php artisan storage:link || true\n\
chmod -R 775 storage bootstrap/cache\n\
chown -R www-data:www-data storage bootstrap/cache\n\
apache2-foreground' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

CMD ["/usr/local/bin/docker-entrypoint.sh"]
