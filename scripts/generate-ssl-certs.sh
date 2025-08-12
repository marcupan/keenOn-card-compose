#!/bin/bash
# Script to generate self-signed SSL certificates for development

set -e

# Configuration
CERT_DIR="../nginx/ssl"
COUNTRY="US"
STATE="State"
LOCALITY="City"
ORGANIZATION="KeenOn Card Compose"
ORGANIZATIONAL_UNIT="Development"
COMMON_NAME="keenon-card-compose.example.com"
EMAIL="admin@example.com"
DAYS_VALID=365

# Create directory if it doesn't exist
mkdir -p $CERT_DIR

echo "Generating self-signed SSL certificates for development..."

# Generate private key
openssl genrsa -out $CERT_DIR/server.key 2048

# Generate CSR (Certificate Signing Request)
openssl req -new -key $CERT_DIR/server.key -out $CERT_DIR/server.csr -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

# Generate self-signed certificate
openssl x509 -req -days $DAYS_VALID -in $CERT_DIR/server.csr -signkey $CERT_DIR/server.key -out $CERT_DIR/server.crt

# Remove CSR as it's no longer needed
rm $CERT_DIR/server.csr

echo "SSL certificates generated successfully in $CERT_DIR"
echo "  - Private key: $CERT_DIR/server.key"
echo "  - Certificate: $CERT_DIR/server.crt"
echo ""
echo "Note: These are self-signed certificates for development only."
echo "For production, use certificates from a trusted Certificate Authority."
