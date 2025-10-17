#!/bin/bash

# CyberPanel NAS Backup Script - Interactive Setup
# Backs up websites, databases, and CyberPanel config to NAS
# Version 1.0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Must run as root. Use: sudo bash $0"
fi

# Welcome screen
clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     💾 CYBERPANEL NAS BACKUP - INTERACTIVE SETUP 💾       ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  This will create an automated backup system that sends   ║"
echo "║  your CyberPanel data to your NAS daily at 3 AM           ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# Collect NAS information
log "Let's configure your NAS backup settings..."
echo

echo -e "${YELLOW}📡 NAS Server IP or Hostname:${NC}"
read -p "Example: 192.168.1.100 or nas.local: " NAS_SERVER
if [ -z "$NAS_SERVER" ]; then
    error "NAS server is required"
fi

echo
echo -e "${YELLOW}👤 NAS Username:${NC}"
read -p "The SSH/rsync username on your NAS: " NAS_USER
if [ -z "$NAS_USER" ]; then
    error "NAS username is required"
fi

echo
echo -e "${YELLOW}📁 NAS Backup Path:${NC}"
read -p "Full path on NAS (e.g., /volume1/backups/server): " NAS_PATH
if [ -z "$NAS_PATH" ]; then
    error "NAS path is required"
fi

echo
echo -e "${YELLOW}🔐 SSH Port (default 22):${NC}"
read -p "NAS SSH port [22]: " NAS_PORT
NAS_PORT=${NAS_PORT:-22}

echo
echo -e "${YELLOW}🗂️  Local backup staging directory:${NC}"
read -p "Where to stage backups locally [/root/backups]: " LOCAL_BACKUP_DIR
LOCAL_BACKUP_DIR=${LOCAL_BACKUP_DIR:-/root/backups}

echo
echo -e "${YELLOW}🗓️  Retention period (days):${NC}"
read -p "Keep backups for how many days [30]: " RETENTION_DAYS
RETENTION_DAYS=${RETENTION_DAYS:-30}

echo
echo -e "${YELLOW}⏰ Backup schedule:${NC}"
echo "1) Daily at 3:00 AM (recommended)"
echo "2) Daily at 2:00 AM"
echo "3) Daily at 4:00 AM"
echo "4) Custom time"
read -p "Choose [1-4]: " SCHEDULE_CHOICE

case $SCHEDULE_CHOICE in
    1) CRON_TIME="0 3 * * *" ;;
    2) CRON_TIME="0 2 * * *" ;;
    3) CRON_TIME="0 4 * * *" ;;
    4)
        echo -e "${YELLOW}Enter cron time (e.g., '0 3 * * *' for 3 AM daily):${NC}"
        read CRON_TIME
        ;;
    *) CRON_TIME="0 3 * * *" ;;
esac

# Summary
echo
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║               📋 CONFIGURATION SUMMARY                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${GREEN}NAS Server:${NC}        $NAS_SERVER"
echo -e "${GREEN}NAS User:${NC}          $NAS_USER"
echo -e "${GREEN}NAS Path:${NC}          $NAS_PATH"
echo -e "${GREEN}NAS SSH Port:${NC}      $NAS_PORT"
echo -e "${GREEN}Local Staging:${NC}     $LOCAL_BACKUP_DIR"
echo -e "${GREEN}Retention:${NC}         $RETENTION_DAYS days"
echo -e "${GREEN}Schedule:${NC}          $CRON_TIME"
echo
read -p "Is this correct? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    error "Setup cancelled. Run the script again to reconfigure."
fi

# Install dependencies
log "Installing required packages..."
apt-get update -qq
apt-get install -y -qq rsync openssh-client >/dev/null 2>&1
success "Dependencies installed"

# Create local backup directory
log "Creating local backup directory..."
mkdir -p "$LOCAL_BACKUP_DIR"
chmod 700 "$LOCAL_BACKUP_DIR"
success "Backup directory created: $LOCAL_BACKUP_DIR"

# Setup SSH key for passwordless authentication
log "Setting up SSH key for passwordless backup..."
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -q
    success "SSH key generated"
else
    info "SSH key already exists"
fi

echo
echo -e "${YELLOW}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║            🔑 SSH KEY SETUP REQUIRED                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${CYAN}Copy the following public key to your NAS:${NC}"
echo
cat /root/.ssh/id_rsa.pub
echo
echo -e "${YELLOW}On your NAS, add this key to:${NC}"
echo "  ~/.ssh/authorized_keys (for user: $NAS_USER)"
echo
echo -e "${YELLOW}Or use this command on your NAS:${NC}"
echo "  mkdir -p ~/.ssh && echo \"$(cat /root/.ssh/id_rsa.pub)\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
echo
read -p "Press Enter once you've added the key to your NAS..."

# Test connection
log "Testing NAS connection..."
if ssh -p "$NAS_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$NAS_USER@$NAS_SERVER" "echo 'Connection successful'" >/dev/null 2>&1; then
    success "NAS connection successful!"
else
    warn "Could not connect to NAS. The backup script will still be created."
    warn "Make sure to add the SSH key and test the connection manually."
fi

# Create the backup script
log "Creating backup script..."

cat > /usr/local/bin/cyberpanel-nas-backup.sh << EOFSCRIPT
#!/bin/bash

# CyberPanel NAS Backup Script
# Auto-generated on $(date)

# Configuration
NAS_SERVER="$NAS_SERVER"
NAS_USER="$NAS_USER"
NAS_PATH="$NAS_PATH"
NAS_PORT="$NAS_PORT"
LOCAL_BACKUP_DIR="$LOCAL_BACKUP_DIR"
RETENTION_DAYS="$RETENTION_DAYS"
LOG_FILE="/var/log/cyberpanel-nas-backup.log"

# Colors for logging
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

# Logging function
log() {
    echo -e "\${GREEN}[\$(date '+%Y-%m-%d %H:%M:%S')] [INFO]\${NC} \$1" | tee -a "\$LOG_FILE"
}

error() {
    echo -e "\${RED}[\$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]\${NC} \$1" | tee -a "\$LOG_FILE"
    exit 1
}

success() {
    echo -e "\${GREEN}[\$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]\${NC} \$1" | tee -a "\$LOG_FILE"
}

# Start backup
log "═══════════════════════════════════════════════════════════"
log "Starting CyberPanel NAS Backup"
log "═══════════════════════════════════════════════════════════"

# Create timestamp
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="cyberpanel_\$DATE"
STAGING_DIR="\$LOCAL_BACKUP_DIR/\$BACKUP_NAME"

# Create staging directory
log "Creating staging directory: \$STAGING_DIR"
mkdir -p "\$STAGING_DIR"

# Backup websites
log "Backing up websites from /home..."
if [ -d /home ]; then
    tar -czf "\$STAGING_DIR/websites.tar.gz" /home/*/public_html /home/*/logs 2>/dev/null || log "Some website files skipped"
    success "Websites backed up"
else
    log "No /home directory found, skipping websites"
fi

# Backup databases
log "Backing up MySQL/MariaDB databases..."
MYSQL_USER="root"
MYSQL_PASS=\$(grep -oP 'password\\s*=\\s*\\K[^\\s]+' /root/.my.cnf 2>/dev/null || echo "")

if [ -n "\$MYSQL_PASS" ]; then
    for db in \$(mysql -u root -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | grep -v information_schema | grep -v performance_schema | grep -v mysql | grep -v sys); do
        log "Backing up database: \$db"
        mysqldump -u root "\$db" > "\$STAGING_DIR/\${db}.sql" 2>/dev/null
        gzip "\$STAGING_DIR/\${db}.sql"
    done
    success "Databases backed up"
else
    log "Could not find MySQL password, trying without password..."
    for db in \$(mysql -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | grep -v information_schema | grep -v performance_schema | grep -v mysql | grep -v sys); do
        log "Backing up database: \$db"
        mysqldump "\$db" > "\$STAGING_DIR/\${db}.sql" 2>/dev/null
        gzip "\$STAGING_DIR/\${db}.sql"
    done
fi

# Backup CyberPanel configuration
log "Backing up CyberPanel configuration..."
if [ -d /usr/local/CyberCP ]; then
    tar -czf "\$STAGING_DIR/cyberpanel_config.tar.gz" /usr/local/CyberCP 2>/dev/null || log "Some config files skipped"
    success "CyberPanel config backed up"
fi

# Backup SSL certificates
log "Backing up SSL certificates..."
if [ -d /etc/letsencrypt ]; then
    tar -czf "\$STAGING_DIR/ssl_certificates.tar.gz" /etc/letsencrypt 2>/dev/null
    success "SSL certificates backed up"
fi

# Calculate backup size
BACKUP_SIZE=\$(du -sh "\$STAGING_DIR" | awk '{print \$1}')
log "Total backup size: \$BACKUP_SIZE"

# Transfer to NAS
log "Transferring backup to NAS: \$NAS_SERVER"
log "Destination: \$NAS_PATH/"

rsync -avz --progress -e "ssh -p \$NAS_PORT -o StrictHostKeyChecking=no" \\
    "\$STAGING_DIR/" \\
    "\$NAS_USER@\$NAS_SERVER:\$NAS_PATH/\$BACKUP_NAME/" >> "\$LOG_FILE" 2>&1

if [ \$? -eq 0 ]; then
    success "Backup transferred to NAS successfully"
    
    # Remove local staging
    log "Cleaning up local staging directory..."
    rm -rf "\$STAGING_DIR"
    success "Local staging cleaned"
else
    error "Failed to transfer backup to NAS! Check log: \$LOG_FILE"
fi

# Cleanup old backups on NAS
log "Cleaning up old backups on NAS (keeping last \$RETENTION_DAYS days)..."
ssh -p "\$NAS_PORT" -o StrictHostKeyChecking=no "\$NAS_USER@\$NAS_SERVER" \\
    "find \$NAS_PATH -maxdepth 1 -type d -name 'cyberpanel_*' -mtime +\$RETENTION_DAYS -exec rm -rf {} \\;" 2>/dev/null

success "Old backups cleaned (kept last \$RETENTION_DAYS days)"

# Cleanup old local backups
log "Cleaning up old local backups..."
find "\$LOCAL_BACKUP_DIR" -maxdepth 1 -type d -name "cyberpanel_*" -mtime +7 -exec rm -rf {} \\;

log "═══════════════════════════════════════════════════════════"
success "Backup completed successfully!"
log "Backup location: \$NAS_SERVER:\$NAS_PATH/\$BACKUP_NAME"
log "═══════════════════════════════════════════════════════════"
EOFSCRIPT

chmod +x /usr/local/bin/cyberpanel-nas-backup.sh
success "Backup script created: /usr/local/bin/cyberpanel-nas-backup.sh"

# Create log file
touch /var/log/cyberpanel-nas-backup.log
chmod 644 /var/log/cyberpanel-nas-backup.log

# Setup cron job
log "Setting up automated backup schedule..."
(crontab -l 2>/dev/null | grep -v cyberpanel-nas-backup; echo "$CRON_TIME /usr/local/bin/cyberpanel-nas-backup.sh") | crontab -
success "Backup scheduled: $CRON_TIME"

# Test backup (optional)
echo
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✅ SETUP COMPLETE!                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo
echo -e "${GREEN}Backup script installed successfully!${NC}"
echo
echo -e "${YELLOW}📋 Summary:${NC}"
echo "  Script location:  /usr/local/bin/cyberpanel-nas-backup.sh"
echo "  Log file:         /var/log/cyberpanel-nas-backup.log"
echo "  Schedule:         $CRON_TIME"
echo "  NAS destination:  $NAS_USER@$NAS_SERVER:$NAS_PATH"
echo
echo -e "${YELLOW}🧪 Test your backup:${NC}"
echo "  sudo /usr/local/bin/cyberpanel-nas-backup.sh"
echo
echo -e "${YELLOW}📊 View backup log:${NC}"
echo "  tail -f /var/log/cyberpanel-nas-backup.log"
echo
echo -e "${YELLOW}✏️  Edit backup settings:${NC}"
echo "  sudo nano /usr/local/bin/cyberpanel-nas-backup.sh"
echo
read -p "Would you like to run a test backup now? (yes/no): " RUN_TEST

if [ "$RUN_TEST" = "yes" ]; then
    echo
    log "Running test backup..."
    /usr/local/bin/cyberpanel-nas-backup.sh
fi

echo
success "All done! Your backups will run automatically at the scheduled time."
echo
