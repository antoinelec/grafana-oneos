#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Output file names
KEY_FILE="grafana/server.key"
CRT_FILE="grafana/server.crt"
DAYS_VALID=365

echo "Generating dummy SSL certificate and key..."

# Generate a 2048-bit RSA private key and self-signed X.509 certificate in one command
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CRT_FILE" \
  -days "$DAYS_VALID" \
  -subj "/C=US/ST=State/L=City/O=Development/OU=IT/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# Set secure permissions (read/write for owner only)
chmod 640 "$KEY_FILE"
chmod 644 "$CRT_FILE"

echo "----------------------------------------------------"
echo "Successfully generated dummy certificates:"
echo "  - Private Key : $KEY_FILE"
echo "  - Certificate : $CRT_FILE"
echo "  - Valid for   : $DAYS_VALID days"
echo "  - SANs        : localhost, 127.0.0.1"
echo "----------------------------------------------------"

ENV_FILE=".env"

# Helper function to generate a secure random hex token
generate_token() {
    # Generates a 32-character random string using openssl (or fallbacks)
    if command -v openssl &>/dev/null; then
        openssl rand -hex 16
    else
        head -c 16 /dev/urandom | xxd -p
    fi
}

# Check if the file already exists and prompt the user
if [ -f "$ENV_FILE" ]; then
    read -p "The file '$ENV_FILE' already exists. Do you want to overwrite and regenerate it? (y/N): " choice
    case "$choice" in
        [yY][eE][sS]|[yY])
            echo "Regenerating $ENV_FILE..."
            ;;
        *)
            echo "Operation cancelled. Existing $ENV_FILE was kept."
            exit 0
            ;;
    esac
fi

# Automatically generate the token
INFLUXDB_TOKEN=$(generate_token)

# Prompt for non-secret/customizable values with sensible defaults
echo ""
echo "--- Environment Configuration Setup ---"
INFLUXDB_ORG="MyOrg"

INFLUXDB_BUCKET="oneos_snmp"

read -p "Enter InfluxDB Admin Username [default: admin]: " INFLUXDB_USER
INFLUXDB_USER=${INFLUXDB_USER:-admin}

read -s -p "Enter InfluxDB Admin Password [default: Admin123456!]: " INFLUXDB_PASSWORD
echo ""
INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD:-Admin123456!}

read -p "Enter InfluxDB Admin Username [default: admin]: " GRAFANA_ADMIN_USER
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}

read -s -p "Enter InfluxDB Admin Password [default: Admin123456!]: " GRAFANA_ADMIN_PASSWORD
echo ""
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-Admin123456!}


# Write out the target configuration file
cat <<EOF > "$ENV_FILE"
# Generated on $(date)
INFLUXDB_USERNAME=${INFLUXDB_USER}
INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD}
INFLUXDB_URL=http://influxdb:8086
INFLUXDB_ORG=${INFLUXDB_ORG}
INFLUXDB_BUCKET=${INFLUXDB_BUCKET}
INFLUXDB_TOKEN=${INFLUXDB_TOKEN}
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
EOF

TELEGRAF_CONF="telegraf/telegraf.conf"
echo "Patching $TELEGRAF_CONF with sed..."
    
sed -i '/\[\[outputs\.influxdb_v2\]\]/,/^$/ {
        s|urls = .*|urls = [ "http://influxdb:8086" ]|
        s|token = .*|token = "'"${INFLUXDB_TOKEN}"'"|
        s|organization = .*|organization = "'"${INFLUXDB_ORG}"'"|
        s|bucket = .*|bucket = "'"${INFLUXDB_BUCKET}"'"|
    }' "$TELEGRAF_CONF"

# Restrict permissions on secret configuration file
chmod 600 "$ENV_FILE"

GRAFANA_DATASOURCE="grafana/provisioning/datasources/influxdb.yml"
echo "Patching $GRAFANA_DATASOURCE with sed..."

# Update organization, defaultBucket, and token in Grafana provisioning file
sed -i \
  -e 's|organization: .*|organization: '"${INFLUXDB_ORG}"'|' \
  -e 's|defaultBucket: .*|defaultBucket: '"${INFLUXDB_BUCKET}"'|' \
  -e 's|token: .*|token: '"${INFLUXDB_TOKEN}"'|' \
  "$GRAFANA_DATASOURCE"

echo ""
echo "----------------------------------------------------"
echo "Successfully generated $ENV_FILE"
echo "  - Generated Token : ${INFLUXDB_TOKEN}"
echo "----------------------------------------------------"
echo ""
echo "Now, you need to copy OneOS MIBs into telegraf/mibs/."
echo "Finally, edit telegraf/telegraf.conf for SNMP settings"

