#!/bin/bash

# SSL Certificate Renewal Script for app.contentgenerator.me
# This script renews the Let's Encrypt certificate and updates the project files

# Renew the certificate
/usr/bin/certbot renew --quiet

# Copy renewed certificates to project directory
if [ -f "/etc/letsencrypt/live/app.contentgenerator.me/fullchain.pem" ]; then
    cp /etc/letsencrypt/live/app.contentgenerator.me/fullchain.pem /root/ai_content_studio/AI_Content_Studio/ssl/app.contentgenerator.me.crt
    cp /etc/letsencrypt/live/app.contentgenerator.me/privkey.pem /root/ai_content_studio/AI_Content_Studio/ssl/app.contentgenerator.me.key
    
    # Reload nginx if running
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    fi
    
    echo "$(date): SSL certificates updated successfully"
else
    echo "$(date): SSL certificate files not found"
fi