#!/bin/bash
# Enable FOG Auto-Registration Settings
# This script configures FOG to minimize manual intervention during host registration

set -e

echo "============================================"
echo "FOG Auto-Registration Configuration"
echo "============================================"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# FOG configuration
FOG_SETTINGS_DB="fog"
MYSQL_USER="fogmaster"

# Get MySQL password from FOG config
if [ -f /var/www/html/fog/lib/fog/config.class.php ]; then
    MYSQL_PASS=$(grep "DATABASE_PASSWORD" /var/www/html/fog/lib/fog/config.class.php | cut -d"'" -f2)
else
    echo "FOG config not found at expected location"
    read -sp "Enter MySQL password for fogmaster: " MYSQL_PASS
    echo
fi

mysql_query() {
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" "$FOG_SETTINGS_DB" -N -e "$1"
}

mysql_update() {
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" "$FOG_SETTINGS_DB" -e "$1"
    echo "  -> OK"
}

echo "Configuring FOG settings..."
echo

# 1. Enable Quick Registration
echo "1. Enabling Quick Registration..."
mysql_update "UPDATE globalSettings SET settingValue='1' WHERE settingKey='FOG_QUICKREG_AUTOPOP';"

# 2. Set Quick Registration to auto-add to pending
echo "2. Setting Quick Reg to add to pending (for review)..."
mysql_update "UPDATE globalSettings SET settingValue='1' WHERE settingKey='FOG_QUICKREG_PENDING_MAC_FILTER';"

# 3. Enable registration with inventory
echo "3. Enabling full inventory collection during registration..."
mysql_update "UPDATE globalSettings SET settingValue='1' WHERE settingKey='FOG_REGISTRATION_ENABLED';"

# 4. Set default host naming to MAC address (can be renamed by auto-approve script)
echo "4. Setting default host naming scheme..."
mysql_update "UPDATE globalSettings SET settingValue='1' WHERE settingKey='FOG_QUICKREG_AUTOPOP';"

# 5. Check current pending host settings
echo
echo "Current pending hosts setting:"
PENDING_COUNT=$(mysql_query "SELECT COUNT(*) FROM hosts WHERE hostPending=1;")
echo "  Pending hosts: $PENDING_COUNT"

echo
echo "============================================"
echo "Installing auto-approve cron job..."
echo "============================================"
echo

# Copy PHP scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/var/www/html/fog/service"

echo "Copying auto-approve script..."
cp "$SCRIPT_DIR/auto-approve-hosts.php" "$TARGET_DIR/"
chown www-data:www-data "$TARGET_DIR/auto-approve-hosts.php"
chmod 640 "$TARGET_DIR/auto-approve-hosts.php"
echo "  -> Installed to $TARGET_DIR/auto-approve-hosts.php"

echo "Copying CSV import script..."
cp "$SCRIPT_DIR/csv-import-hosts.php" "$TARGET_DIR/"
chown www-data:www-data "$TARGET_DIR/csv-import-hosts.php"
chmod 640 "$TARGET_DIR/csv-import-hosts.php"
echo "  -> Installed to $TARGET_DIR/csv-import-hosts.php"

# Create log file
touch /var/log/fog-auto-approve.log
chown www-data:www-data /var/log/fog-auto-approve.log

# Setup cron job (runs every 5 minutes)
CRON_FILE="/etc/cron.d/fog-auto-approve"
echo "Setting up cron job..."

cat > "$CRON_FILE" << 'EOF'
# FOG Auto-Approve Pending Hosts
# Runs every 5 minutes to approve new pending hosts
# Edit /var/www/html/fog/service/auto-approve-hosts.php to configure

*/5 * * * * www-data /usr/bin/php /var/www/html/fog/service/auto-approve-hosts.php >> /var/log/fog-auto-approve.log 2>&1
EOF

chmod 644 "$CRON_FILE"
echo "  -> Created $CRON_FILE"

echo
echo "============================================"
echo "Configuration Complete!"
echo "============================================"
echo
echo "What's been set up:"
echo "  1. Quick Registration enabled"
echo "  2. Full inventory collection during registration"
echo "  3. Auto-approve script installed"
echo "  4. Cron job running every 5 minutes"
echo
echo "To customize auto-approve behavior, edit:"
echo "  $TARGET_DIR/auto-approve-hosts.php"
echo
echo "To import hosts from CSV:"
echo "  php $TARGET_DIR/csv-import-hosts.php /path/to/hosts.csv"
echo
echo "View auto-approve log:"
echo "  tail -f /var/log/fog-auto-approve.log"
echo
echo "To disable auto-approve cron:"
echo "  rm $CRON_FILE"
echo

