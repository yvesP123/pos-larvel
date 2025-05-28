FROM php:8.1-apache

# Set environment variables for Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_MEMORY_LIMIT=-1
ENV COMPOSER_CACHE_DIR=/tmp/composer-cache

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
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd
    && docker-php-ext-install \
    pdo_pgsql \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip

# Install Composer
COPY --from=composer:2.5 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy only composer files first
COPY composer.json ./
COPY composer.lock* ./

# Install PHP dependencies with fallback strategy
RUN mkdir -p /tmp/composer-cache \
    && composer clear-cache \
    && (composer install \
        --no-scripts \
        --no-autoloader \
        --no-dev \
        --prefer-dist \
        --ignore-platform-reqs \
        --no-interaction \
        --verbose \
        || composer install \
            --no-scripts \
            --no-autoloader \
            --ignore-platform-reqs \
            --no-interaction \
            --verbose)

# Copy application code
COPY . .

# Make sure .env exists
RUN cp .env.example .env 2>/dev/null || echo "APP_NAME=Laravel" > .env

# Finalize composer setup
RUN composer dump-autoload --optimize --no-dev --no-interaction 2>/dev/null || \
    composer dump-autoload --optimize --no-interaction

# Create required directories
RUN mkdir -p storage/{app,framework,logs} \
    && mkdir -p storage/framework/{cache,sessions,views} \
    && mkdir -p bootstrap/cache \
    && mkdir -p public/storage

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && chmod -R 775 storage bootstrap/cache

# Configure Apache
RUN a2enmod rewrite headers

# Simple Apache configuration
RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/public\n\
    \n\
    <Directory /var/www/html/public>\n\
        AllowOverride All\n\
        Require all granted\n\
        Options -Indexes\n\
        \n\
        RewriteEngine On\n\
        RewriteCond %{REQUEST_FILENAME} !-d\n\
        RewriteCond %{REQUEST_FILENAME} !-f\n\
        RewriteRule ^(.*)$ index.php [QSA,L]\n\
    </Directory>\n\
    \n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# Optimize PHP for production
RUN echo 'memory_limit = 512M\n\
max_execution_time = 300\n\
post_max_size = 100M\n\
upload_max_filesize = 100M\n\
log_errors = On\n\
error_log = /var/log/apache2/php_errors.log\n\
display_errors = Off' > /usr/local/etc/php/conf.d/laravel.ini

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting Laravel application..."\n\
\n\
# Generate app key if not set\n\
if grep -q "APP_KEY=$" .env || ! grep -q "APP_KEY=" .env; then\n\
    echo "Generating APP_KEY..."\n\
    php artisan key:generate --force --no-interaction\n\
fi\n\
\n\
# Clear any problematic cache files\n\
rm -f bootstrap/cache/*.php\n\
\n\
# Set up Laravel\n\
php artisan config:clear 2>/dev/null || true\n\
php artisan cache:clear 2>/dev/null || true\n\
php artisan view:clear 2>/dev/null || true\n\
\n\
# Create storage link if it doesn'\''t exist\n\
php artisan storage:link 2>/dev/null || true\n\
\n\
# Cache config for production\n\
if [ "$APP_ENV" != "local" ]; then\n\
    php artisan config:cache 2>/dev/null || true\n\
fi\n\
\n\
# Ensure permissions\n\
chown -R www-data:www-data storage bootstrap/cache\n\
chmod -R 775 storage bootstrap/cache\n\
\n\
echo "Laravel ready!"\n\
\n\
# Start Apache\n\
apache2-foreground' > /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

CMD ["/usr/local/bin/docker-entrypoint.sh"]