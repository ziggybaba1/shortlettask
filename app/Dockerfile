# Use the official PHP image as the base
FROM php:7.4-cli

# Copy the PHP source code to the container
COPY ./app/index.php /var/www/html/

# Set the working directory
WORKDIR /var/www/html

# Expose port 80 for the web server
EXPOSE 80

# Start PHP built-in server
CMD ["php", "-S", "0.0.0.0:80", "-t", "/var/www/html"]

