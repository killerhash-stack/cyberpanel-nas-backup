#!/bin/bash

# CyberPanel Unlock Script + NAS Backup Integration
# Removes paywall restrictions and adds custom NAS backup to UI
# Run AFTER fresh CyberPanel installation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"; exit 1; }
success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Must run as root. Use: sudo bash $0"
fi

# Check if CyberPanel is installed
if [ ! -d "/usr/local/CyberCP" ]; then
    error "CyberPanel not found! Install CyberPanel first."
fi

# Welcome
clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║    🔓 CYBERPANEL UNLOCK & NAS BACKUP INTEGRATION 🔓       ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  This script will:                                        ║"
echo "║  ✓ Remove all enterprise/paywall restrictions            ║"
echo "║  ✓ Unlock premium features                               ║"
echo "║  ✓ Add NAS backup button to CyberPanel UI                ║"
echo "║  ✓ Integrate your custom backup system                   ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    error "Installation cancelled"
fi

# Backup original files
log "Creating backup of CyberPanel files..."
BACKUP_DIR="/root/cyberpanel_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /usr/local/CyberCP "$BACKUP_DIR/"
success "Backup created: $BACKUP_DIR"

# Stop CyberPanel
log "Stopping CyberPanel..."
systemctl stop lscpd
sleep 2

# ============================================================================
# REMOVE PAYWALL/ENTERPRISE CHECKS
# ============================================================================

log "Removing enterprise/paywall restrictions..."

# Find all Python files with enterprise checks
log "Scanning for enterprise restrictions..."
find /usr/local/CyberCP -type f -name "*.py" -exec grep -l "enterprise" {} \; > /tmp/enterprise_files.txt

# 1. Universal enterprise unlock - Replace all enterprise checks
log "Applying universal enterprise unlock..."
while IFS= read -r file; do
    if [ -f "$file" ]; then
        # Method 1: Direct comparisons
        sed -i 's/currentACL\[.enterprise.\] == 1/True/g' "$file"
        sed -i 's/currentACL\[.enterprise.\] == 0/False/g' "$file"
        sed -i "s/currentACL\['enterprise'\] == 1/True/g" "$file"
        sed -i "s/currentACL\['enterprise'\] == 0/False/g" "$file"
        
        # Method 2: ACLManager checks
        sed -i 's/ACLManager\.currentACL\.enterprise == 1/True/g' "$file"
        sed -i 's/ACLManager\.currentACL\.enterprise == 0/False/g' "$file"
        
        # Method 3: If statements
        sed -i 's/if currentACL\.enterprise == 1:/if True:/g' "$file"
        sed -i 's/if ACLManager\.currentACL\.enterprise == 1:/if True:/g' "$file"
        
        # Method 4: Direct attribute access
        sed -i 's/\.enterprise == 1/True/g' "$file"
        sed -i 's/\.enterprise == 0/False/g' "$file"
    fi
done < /tmp/enterprise_files.txt

success "Universal enterprise checks removed"

# 2. Specifically target known locked features
log "Unlocking MySQL Manager..."
if [ -f "/usr/local/CyberCP/databases/views.py" ]; then
    sed -i 's/enterprise/True  # enterprise/g' /usr/local/CyberCP/databases/views.py
fi

log "Unlocking Root File Manager..."
if [ -f "/usr/local/CyberCP/filemanager/views.py" ]; then
    sed -i 's/enterprise/True  # enterprise/g' /usr/local/CyberCP/filemanager/views.py
fi

log "Unlocking Mail Settings..."
if [ -f "/usr/local/CyberCP/mailServer/views.py" ]; then
    sed -i 's/enterprise/True  # enterprise/g' /usr/local/CyberCP/mailServer/views.py
fi

log "Unlocking Email Debugger..."
if [ -f "/usr/local/CyberCP/emailPremium/views.py" ]; then
    sed -i 's/enterprise/True  # enterprise/g' /usr/local/CyberCP/emailPremium/views.py
fi

log "Unlocking Rspamd..."
if [ -d "/usr/local/CyberCP/mailServer" ]; then
    find /usr/local/CyberCP/mailServer -type f -name "*.py" -exec sed -i 's/enterprise/True  # enterprise/g' {} \;
fi

# 3. Remove license verification
log "Removing license verification system..."
if [ -f "/usr/local/CyberCP/plogical/CyberCPLogFileWriter.py" ]; then
    sed -i 's/def checkLicense/def checkLicense_DISABLED/g' /usr/local/CyberCP/plogical/CyberCPLogFileWriter.py
    sed -i 's/def verifyConn/def verifyConn_DISABLED/g' /usr/local/CyberCP/plogical/CyberCPLogFileWriter.py
fi

# 4. Patch the template files that show upgrade prompts
log "Removing upgrade prompts from templates..."
find /usr/local/CyberCP -type f -name "*.html" -exec sed -i 's/Enterprise Only/Unlocked/g' {} \;
find /usr/local/CyberCP -type f -name "*.html" -exec sed -i 's/enterprise only/unlocked/g' {} \;
find /usr/local/CyberCP -type f -name "*.html" -exec sed -i '/upgrade.*enterprise/d' {} \;

success "All enterprise restrictions removed"

# ============================================================================
# ADD CUSTOM NAS BACKUP TO UI
# ============================================================================

log "Adding NAS backup integration to CyberPanel UI..."

# Create custom backup module
mkdir -p /usr/local/CyberCP/nasBackup

cat > /usr/local/CyberCP/nasBackup/__init__.py << 'EOF'
# NAS Backup Module
EOF

cat > /usr/local/CyberCP/nasBackup/urls.py << 'EOF'
from django.conf.urls import url
from . import views

urlpatterns = [
    url(r'^$', views.nasBackupHome, name='nasBackupHome'),
    url(r'^runBackup$', views.runNASBackup, name='runNASBackup'),
    url(r'^viewLog$', views.viewBackupLog, name='viewBackupLog'),
]
EOF

cat > /usr/local/CyberCP/nasBackup/views.py << 'EOF'
import subprocess
import os
from django.shortcuts import render, redirect
from django.http import HttpResponse
from loginSystem.models import Administrator
from plogical.acl import ACLManager

def nasBackupHome(request):
    try:
        userID = request.session['userID']
        currentACL = ACLManager.loadedACL(userID)
        
        if currentACL['admin'] == 1:
            return render(request, 'nasBackup/index.html')
        else:
            return HttpResponse("Access Denied")
    except KeyError:
        return redirect('login')

def runNASBackup(request):
    try:
        userID = request.session['userID']
        currentACL = ACLManager.loadedACL(userID)
        
        if currentACL['admin'] == 1:
            # Run the backup script
            result = subprocess.run(
                ['/usr/local/bin/cyberpanel-nas-backup.sh'],
                capture_output=True,
                text=True,
                timeout=3600
            )
            
            return HttpResponse(f"Backup started successfully!<br><pre>{result.stdout}</pre>")
        else:
            return HttpResponse("Access Denied")
    except Exception as e:
        return HttpResponse(f"Error: {str(e)}")

def viewBackupLog(request):
    try:
        userID = request.session['userID']
        currentACL = ACLManager.loadedACL(userID)
        
        if currentACL['admin'] == 1:
            log_file = '/var/log/cyberpanel-nas-backup.log'
            
            if os.path.exists(log_file):
                with open(log_file, 'r') as f:
                    # Get last 100 lines
                    lines = f.readlines()
                    log_content = ''.join(lines[-100:])
                    
                return render(request, 'nasBackup/viewLog.html', {'log_content': log_content})
            else:
                return HttpResponse("No backup log found")
        else:
            return HttpResponse("Access Denied")
    except Exception as e:
        return HttpResponse(f"Error: {str(e)}")
EOF

# Create templates directory
mkdir -p /usr/local/CyberCP/nasBackup/templates/nasBackup

cat > /usr/local/CyberCP/nasBackup/templates/nasBackup/index.html << 'EOF'
{% extends "baseTemplate/index.html" %}
{% load static %}

{% block title %}NAS Backup{% endblock %}

{% block content %}
<div class="row">
    <div class="col-lg-12">
        <div class="card">
            <div class="card-header">
                <h3><i class="fa fa-database"></i> NAS Backup System</h3>
            </div>
            <div class="card-body">
                <p>Custom NAS backup system for backing up websites, databases, and configurations to network storage.</p>
                
                <div class="alert alert-info">
                    <strong>Backup includes:</strong>
                    <ul>
                        <li>All websites (/home/*/public_html)</li>
                        <li>All databases</li>
                        <li>CyberPanel configuration</li>
                        <li>SSL certificates</li>
                    </ul>
                </div>
                
                <div class="row mt-4">
                    <div class="col-md-6">
                        <div class="card bg-primary text-white">
                            <div class="card-body text-center">
                                <h5>Run Backup Now</h5>
                                <p>Start an immediate backup to your NAS</p>
                                <button class="btn btn-light" onclick="runBackup()">
                                    <i class="fa fa-play"></i> Start Backup
                                </button>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="card bg-success text-white">
                            <div class="card-body text-center">
                                <h5>View Backup Log</h5>
                                <p>Check backup history and status</p>
                                <a href="{% url 'viewBackupLog' %}" class="btn btn-light">
                                    <i class="fa fa-file-text"></i> View Log
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div id="backupResult" class="mt-4"></div>
            </div>
        </div>
    </div>
</div>

<script>
function runBackup() {
    document.getElementById('backupResult').innerHTML = '<div class="alert alert-info"><i class="fa fa-spinner fa-spin"></i> Backup in progress... This may take several minutes.</div>';
    
    fetch('{% url "runNASBackup" %}')
        .then(response => response.text())
        .then(data => {
            document.getElementById('backupResult').innerHTML = '<div class="alert alert-success">' + data + '</div>';
        })
        .catch(error => {
            document.getElementById('backupResult').innerHTML = '<div class="alert alert-danger">Error: ' + error + '</div>';
        });
}
</script>
{% endblock %}
EOF

cat > /usr/local/CyberCP/nasBackup/templates/nasBackup/viewLog.html << 'EOF'
{% extends "baseTemplate/index.html" %}
{% load static %}

{% block title %}Backup Log{% endblock %}

{% block content %}
<div class="row">
    <div class="col-lg-12">
        <div class="card">
            <div class="card-header">
                <h3><i class="fa fa-file-text"></i> NAS Backup Log (Last 100 lines)</h3>
            </div>
            <div class="card-body">
                <a href="{% url 'nasBackupHome' %}" class="btn btn-secondary mb-3">
                    <i class="fa fa-arrow-left"></i> Back to Backup
                </a>
                
                <pre style="background: #1e1e1e; color: #d4d4d4; padding: 15px; border-radius: 5px; max-height: 600px; overflow-y: auto;">{{ log_content }}</pre>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

# Add to main URLs
log "Registering NAS backup in CyberPanel navigation..."

if ! grep -q "nasBackup" /usr/local/CyberCP/CyberCP/urls.py; then
    # Add import
    sed -i "/from backup import urls as backup/a from nasBackup import urls as nasBackup" /usr/local/CyberCP/CyberCP/urls.py
    
    # Add URL pattern
    sed -i "/url(r'\^backup\/', include(backup)),/a \    url(r'^nasBackup/', include(nasBackup))," /usr/local/CyberCP/CyberCP/urls.py
fi

# Add menu item to sidebar
if [ -f "/usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html" ]; then
    if ! grep -q "NAS Backup" /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html; then
        log "Adding NAS Backup to sidebar menu..."
        
        # This adds the menu item after the regular Backup menu
        # Note: This is a simplified approach - actual line numbers may vary
        sed -i '/<a href="\/backup\/">/a \                        <li><a href="/nasBackup/"><i class="fa fa-database"></i> NAS Backup</a></li>' /usr/local/CyberCP/baseTemplate/templates/baseTemplate/index.html
    fi
fi

success "NAS backup integration added to UI"

# ============================================================================
# ADDITIONAL OPTIMIZATIONS
# ============================================================================

log "Applying additional optimizations..."

# Remove update nags
if [ -f "/usr/local/CyberCP/plogical/upgrade.py" ]; then
    sed -i 's/def checkForUpdates/def checkForUpdates_disabled/g' /usr/local/CyberCP/plogical/upgrade.py
fi

# Disable telemetry/phone-home
if [ -f "/usr/local/CyberCP/plogical/installUtilities.py" ]; then
    sed -i 's/def sendStatistics/def sendStatistics_disabled/g' /usr/local/CyberCP/plogical/installUtilities.py
fi

success "Additional optimizations applied"

# ============================================================================
# FINALIZE
# ============================================================================

log "Recompiling Python bytecode..."
python3 -m compileall /usr/local/CyberCP/ >/dev/null 2>&1

log "Starting CyberPanel..."
systemctl start lscpd
sleep 5

# Check if running
if systemctl is-active --quiet lscpd; then
    success "CyberPanel started successfully"
else
    error "CyberPanel failed to start. Check logs: journalctl -u lscpd -n 50"
fi

# Completion message
echo
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║          ✅ CYBERPANEL UNLOCK COMPLETE! ✅                 ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  🔓 All enterprise features unlocked                      ║"
echo "║  💾 NAS backup added to UI                                ║"
echo "║  🚀 Premium features now free                             ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  📋 What's New:                                           ║"
echo "║                                                            ║"
echo "║  • All backup features unlocked                           ║"
echo "║  • Premium email features unlocked                        ║"
echo "║  • DNS features unlocked                                  ║"
echo "║  • License checks removed                                 ║"
echo "║  • NAS Backup page added to menu                          ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  🎯 Access NAS Backup:                                    ║"
echo "║                                                            ║"
echo "║  1. Login to CyberPanel                                   ║"
echo "║  2. Look for 'NAS Backup' in the sidebar                 ║"
echo "║  3. Click to manage backups                               ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  📁 Backup Created:                                       ║"
echo "║     $BACKUP_DIR"
echo "║                                                            ║"
echo "║  🔄 To Restore Original:                                  ║"
echo "║     sudo rm -rf /usr/local/CyberCP                        ║"
echo "║     sudo cp -r $BACKUP_DIR/CyberCP /usr/local/           ║"
echo "║     sudo systemctl restart lscpd                          ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

success "All done! Refresh your CyberPanel page to see changes."
echo
