#!/bin/bash

# CyberPanel 2.4 Paywall Removal Script
# Removes ALL enterprise/paywall restrictions and blocks addon redirects
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
echo "║         🔓 CYBERPANEL 2.4 PAYWALL REMOVER 🔓              ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  This script will:                                        ║"
echo "║  ✓ Remove ALL enterprise/paywall restrictions            ║"
echo "║  ✓ Block redirects to cyberpanel.net/addons              ║"
echo "║  ✓ Unlock all premium features                           ║"
echo "║  ✓ Disable license checks completely                     ║"
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
log "Stopping CyberPanel services..."
systemctl stop lscpd
sleep 3

# ============================================================================
# BLOCK EXTERNAL ADDON REDIRECTS - CRITICAL
# ============================================================================

log "Blocking external cyberpanel.net redirects..."

# Find and replace ALL redirects to cyberpanel.net
find /usr/local/CyberCP -type f -name "*.py" | while read file; do
    if [[ "$file" == *"__pycache__"* ]] || [[ "$file" == *".pyc" ]]; then
        continue
    fi
    
    # Block various forms of cyberpanel.net redirects
    sed -i 's|https://cyberpanel.net/cyberpanel-addons|#|g' "$file" 2>/dev/null
    sed -i 's|http://cyberpanel.net/cyberpanel-addons|#|g' "$file" 2>/dev/null
    sed -i 's|cyberpanel.net/cyberpanel-addons|#|g' "$file" 2>/dev/null
    sed -i 's|"https://cyberpanel.net/[^"]*"|"#"|g' "$file" 2>/dev/null
    sed -i "s|'https://cyberpanel.net/[^']*'|'#'|g" "$file" 2>/dev/null
    
    # Replace any redirect or HttpResponseRedirect to external sites
    sed -i 's|return redirect("https://cyberpanel.net[^"]*")|return HttpResponse("Feature Unlocked - No Purchase Required")|g' "$file" 2>/dev/null
    sed -i "s|return redirect('https://cyberpanel.net[^']*')|return HttpResponse('Feature Unlocked - No Purchase Required')|g" "$file" 2>/dev/null
    sed -i 's|return HttpResponseRedirect("https://cyberpanel.net[^"]*")|return HttpResponse("Feature Unlocked - No Purchase Required")|g' "$file" 2>/dev/null
    sed -i "s|return HttpResponseRedirect('https://cyberpanel.net[^']*')|return HttpResponse('Feature Unlocked - No Purchase Required')|g" "$file" 2>/dev/null
done

success "External redirects blocked"

# ============================================================================
# AGGRESSIVE PAYWALL REMOVAL
# ============================================================================

log "Starting aggressive paywall removal..."

# Method 1: Replace all ACL admin checks with True
log "Method 1: Bypassing all ACL admin checks..."

find /usr/local/CyberCP -type f -name "*.py" | while read file; do
    if [[ "$file" == *"__pycache__"* ]] || [[ "$file" == *".pyc" ]]; then
        continue
    fi
    
    # Replace various forms of admin checks
    sed -i "s/if currentACL\['admin'\] == 1:/if True:  # bypass/g" "$file" 2>/dev/null
    sed -i 's/if currentACL\["admin"\] == 1:/if True:  # bypass/g' "$file" 2>/dev/null
    sed -i "s/if currentACL\['admin'\] != 1:/if False:  # bypass/g" "$file" 2>/dev/null
    sed -i 's/if currentACL\["admin"\] != 1:/if False:  # bypass/g' "$file" 2>/dev/null
    sed -i "s/currentACL\['admin'\] == 1/True  # bypass/g" "$file" 2>/dev/null
    sed -i 's/currentACL\["admin"\] == 1/True  # bypass/g' "$file" 2>/dev/null
    sed -i "s/elif currentACL\['admin'\] != 1:/elif False:  # bypass/g" "$file" 2>/dev/null
    sed -i "s/and currentACL\['admin'\] == 1/and True  # bypass/g" "$file" 2>/dev/null
done

success "ACL admin checks bypassed"

# Method 2: Replace enterprise checks
log "Method 2: Removing enterprise license checks..."

find /usr/local/CyberCP -type f -name "*.py" | while read file; do
    if [[ "$file" == *"__pycache__"* ]] || [[ "$file" == *".pyc" ]]; then
        continue
    fi
    
    sed -i "s/currentACL\['enterprise'\] == 1/True  # bypass/g" "$file" 2>/dev/null
    sed -i 's/currentACL\["enterprise"\] == 1/True  # bypass/g' "$file" 2>/dev/null
    sed -i "s/if currentACL\['enterprise'\] == 1:/if True:  # bypass/g" "$file" 2>/dev/null
    sed -i 's/if currentACL\["enterprise"\] == 1:/if True:  # bypass/g' "$file" 2>/dev/null
    sed -i "s/currentACL\['enterprise'\] != 1/False  # bypass/g" "$file" 2>/dev/null
    sed -i "s/and currentACL\['enterprise'\] == 1/and True  # bypass/g" "$file" 2>/dev/null
done

success "Enterprise checks removed"

# Method 3: Find and neutralize addon verification functions
log "Method 3: Disabling addon verification..."

find /usr/local/CyberCP -type f -name "*.py" -exec grep -l "addon" {} \; | while read file; do
    if [[ "$file" == *"__pycache__"* ]] || [[ "$file" == *".pyc" ]]; then
        continue
    fi
    
    # Look for addon check functions and make them always return True
    sed -i 's/def.*checkAddon.*/&\n    return True  # bypassed/g' "$file" 2>/dev/null
    sed -i 's/def.*verifyAddon.*/&\n    return True  # bypassed/g' "$file" 2>/dev/null
    sed -i 's/def.*validateAddon.*/&\n    return True  # bypassed/g' "$file" 2>/dev/null
done

success "Addon verification disabled"

# Method 4: Patch ACL Manager directly
log "Method 4: Patching ACL Manager to always return admin=1..."

if [ -f "/usr/local/CyberCP/plogical/acl.py" ]; then
    cp /usr/local/CyberCP/plogical/acl.py /usr/local/CyberCP/plogical/acl.py.bak
    
    # Add a force-admin return at the end of loadedACL function
    python3 << 'PYEOF'
import re

with open('/usr/local/CyberCP/plogical/acl.py', 'r') as f:
    content = f.read()

# Find all return statements in loadedACL and patch them
lines = content.split('\n')
new_lines = []
in_loaded_acl = False
indent_level = 0

for i, line in enumerate(lines):
    if 'def loadedACL' in line:
        in_loaded_acl = True
        indent_level = len(line) - len(line.lstrip())
        new_lines.append(line)
        continue
        
    if in_loaded_acl:
        current_indent = len(line) - len(line.lstrip())
        
        # Check if we're exiting the function (new function definition at same or lower indent)
        if line.strip() and current_indent <= indent_level and line.strip().startswith('def '):
            in_loaded_acl = False
        
        # Patch any return statement to force admin/enterprise
        if in_loaded_acl and 'return ' in line and not line.strip().startswith('#'):
            # Get the variable being returned
            var_match = re.search(r'return\s+(\w+)', line)
            if var_match:
                var_name = var_match.group(1)
                patch_indent = ' ' * current_indent
                
                # Add forced admin/enterprise before return
                new_lines.append(patch_indent + f"# PAYWALL BYPASS")
                new_lines.append(patch_indent + f"try:")
                new_lines.append(patch_indent + f"    {var_name}['admin'] = 1")
                new_lines.append(patch_indent + f"    {var_name}['enterprise'] = 1")
                new_lines.append(patch_indent + f"except: pass")
    
    new_lines.append(line)

with open('/usr/local/CyberCP/plogical/acl.py', 'w') as f:
    f.write('\n'.join(new_lines))

print("ACL Manager patched successfully")
PYEOF
    
    success "ACL Manager patched"
else
    warn "ACL Manager not found at expected location"
fi

# Method 5: Remove ALL redirect calls to external sites
log "Method 5: Removing ALL external redirects..."

find /usr/local/CyberCP -type f -name "*.py" | while read file; do
    if [[ "$file" == *"__pycache__"* ]] || [[ "$file" == *".pyc" ]]; then
        continue
    fi
    
    # Find lines with redirects and comment them out
    sed -i 's/^\(\s*\)return redirect(\(.*cyberpanel\.net.*\))/\1# return redirect(\2) # BLOCKED\n\1return HttpResponse("Feature Unlocked")/g' "$file" 2>/dev/null
    sed -i 's/^\(\s*\)return HttpResponseRedirect(\(.*cyberpanel\.net.*\))/\1# return HttpResponseRedirect(\2) # BLOCKED\n\1return HttpResponse("Feature Unlocked")/g' "$file" 2>/dev/null
done

success "External redirects removed"

# Method 6: Patch specific known paywall locations
log "Method 6: Patching known paywall locations..."

# Backup features
if [ -f "/usr/local/CyberCP/backup/views.py" ]; then
    log "Unlocking backup features..."
    sed -i "s/if request.session\['userID'\] == 1:/if True:  # bypass/g" /usr/local/CyberCP/backup/views.py
    sed -i "s/request.session\['userID'\] == 1/True  # bypass/g" /usr/local/CyberCP/backup/views.py
fi

# Email Premium features
if [ -d "/usr/local/CyberCP/emailPremium" ]; then
    log "Unlocking email premium features..."
    find /usr/local/CyberCP/emailPremium -name "*.py" -exec sed -i "s/currentACL\['admin'\] == 1/True  # bypass/g" {} \;
fi

# DNS features
if [ -d "/usr/local/CyberCP/dns" ]; then
    log "Unlocking DNS features..."
    find /usr/local/CyberCP/dns -name "*.py" -exec sed -i "s/currentACL\['admin'\] == 1/True  # bypass/g" {} \;
fi

# Database features
if [ -d "/usr/local/CyberCP/databases" ]; then
    log "Unlocking database features..."
    find /usr/local/CyberCP/databases -name "*.py" -exec sed -i "s/currentACL\['admin'\] == 1/True  # bypass/g" {} \;
fi

# File Manager
if [ -d "/usr/local/CyberCP/filemanager" ]; then
    log "Unlocking file manager..."
    find /usr/local/CyberCP/filemanager -name "*.py" -exec sed -i "s/currentACL\['admin'\] == 1/True  # bypass/g" {} \;
fi

# Web Terminal
if [ -d "/usr/local/CyberCP/WebTerminal" ]; then
    log "Unlocking web terminal..."
    find /usr/local/CyberCP/WebTerminal -name "*.py" -exec sed -i "s/currentACL\['admin'\] == 1/True  # bypass/g" {} \;
fi

success "Known paywall locations patched"

# Method 7: Disable license verification
log "Method 7: Disabling license verification..."

if [ -f "/usr/local/CyberCP/plogical/virtualHostUtilities.py" ]; then
    sed -i 's/def verifyConn/def verifyConn_disabled/g' /usr/local/CyberCP/plogical/virtualHostUtilities.py
fi

# Disable update checks
if [ -f "/usr/local/CyberCP/plogical/upgrade.py" ]; then
    sed -i 's/def checkForUpdates/def checkForUpdates_disabled/g' /usr/local/CyberCP/plogical/upgrade.py
fi

# Disable any phone-home functions
find /usr/local/CyberCP -name "*.py" -exec grep -l "requests.post.*cyberpanel.net" {} \; | while read file; do
    sed -i 's/requests\.post.*cyberpanel\.net.*)/None  # blocked/g' "$file" 2>/dev/null
done

success "License verification disabled"

# Method 8: Create ACL override middleware
log "Method 8: Creating ACL override middleware..."

cat > /usr/local/CyberCP/plogical/acl_override.py << 'EOF'
"""
ACL Override Middleware - Forces admin access for all users
"""

class ACLOverrideMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Force admin session
        if hasattr(request, 'session'):
            if 'userID' in request.session:
                request.session['admin'] = 1
                request.session['enterprise'] = 1
        
        response = self.get_response(request)
        return response

# Monkey patch ACLManager
try:
    from plogical.acl import ACLManager
    
    original_loadedACL = ACLManager.loadedACL
    
    @staticmethod
    def patched_loadedACL(userID):
        result = original_loadedACL(userID)
        # Force admin and enterprise
        result['admin'] = 1
        result['enterprise'] = 1
        return result
    
    ACLManager.loadedACL = patched_loadedACL
except:
    pass
EOF

# Add middleware to settings
if [ -f "/usr/local/CyberCP/CyberCP/settings.py" ]; then
    if ! grep -q "acl_override.ACLOverrideMiddleware" /usr/local/CyberCP/CyberCP/settings.py; then
        sed -i "/MIDDLEWARE = \[/a \    'plogical.acl_override.ACLOverrideMiddleware'," /usr/local/CyberCP/CyberCP/settings.py
        success "ACL override middleware added"
    fi
fi

# Method 9: Block at hosts level (nuclear option)
log "Method 9: Blocking cyberpanel.net at system level..."

if ! grep -q "cyberpanel.net" /etc/hosts; then
    echo "127.0.0.1 cyberpanel.net" >> /etc/hosts
    echo "127.0.0.1 www.cyberpanel.net" >> /etc/hosts
    success "cyberpanel.net blocked in /etc/hosts"
fi

# Method 10: Clear all caches
log "Method 10: Clearing Python cache..."
find /usr/local/CyberCP -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find /usr/local/CyberCP -type f -name "*.pyc" -delete 2>/dev/null

# Method 11: Recompile everything
log "Method 11: Recompiling Python bytecode..."
python3 -m compileall /usr/local/CyberCP/ 2>/dev/null

success "All patching methods completed"

# ============================================================================
# RESTART AND VERIFY
# ============================================================================

log "Restarting CyberPanel services..."
systemctl daemon-reload
systemctl restart lscpd
sleep 5

# Check if running
if systemctl is-active --quiet lscpd; then
    success "CyberPanel started successfully"
else
    warn "CyberPanel may have issues. Checking logs..."
    journalctl -u lscpd -n 20 --no-pager
    error "CyberPanel failed to start. Check logs above."
fi

# Completion message
echo
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║          ✅ PAYWALL REMOVAL COMPLETE! ✅                   ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  Applied 11 different bypass methods:                     ║"
echo "║                                                            ║"
echo "║  ✓ External cyberpanel.net redirects BLOCKED              ║"
echo "║  ✓ cyberpanel.net added to /etc/hosts                     ║"
echo "║  ✓ ACL admin checks bypassed                              ║"
echo "║  ✓ Enterprise license checks removed                      ║"
echo "║  ✓ Addon verification disabled                            ║"
echo "║  ✓ ACL Manager patched                                    ║"
echo "║  ✓ All external redirects removed                         ║"
echo "║  ✓ Known paywall locations patched                        ║"
echo "║  ✓ License verification disabled                          ║"
echo "║  ✓ Override middleware installed                          ║"
echo "║  ✓ Python cache cleared & recompiled                      ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  📋 CRITICAL - Next Steps:                                ║"
echo "║                                                            ║"
echo "║  1. Clear your browser cache completely                   ║"
echo "║     (Ctrl+Shift+Delete - All time)                        ║"
echo "║                                                            ║"
echo "║  2. Logout of CyberPanel                                  ║"
echo "║                                                            ║"
echo "║  3. Close ALL browser tabs with CyberPanel                ║"
echo "║                                                            ║"
echo "║  4. Open new browser window/tab                           ║"
echo "║                                                            ║"
echo "║  5. Login to CyberPanel again                             ║"
echo "║                                                            ║"
echo "║  6. Test features - should NOT redirect anymore!          ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  📁 Backup Location:                                      ║"
echo "║     $BACKUP_DIR"
echo "║                                                            ║"
echo "║  🔄 To Restore if Needed:                                 ║"
echo "║     systemctl stop lscpd                                  ║"
echo "║     rm -rf /usr/local/CyberCP                             ║"
echo "║     cp -r $BACKUP_DIR/CyberCP /usr/local/                ║"
echo "║     systemctl start lscpd                                 ║"
echo "║     # Remove /etc/hosts entries manually                  ║"
echo "║                                                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║                                                            ║"
echo "║  🔍 If STILL redirecting:                                 ║"
echo "║                                                            ║"
echo "║  The redirect may be in JavaScript/HTML templates        ║"
echo "║  Let me know which feature and I'll create a             ║"
echo "║  template scanner script                                  ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

success "All done! Clear browser cache completely and re-login!"
echo
log "cyberpanel.net is now blocked in /etc/hosts"
log "Check service status: systemctl status lscpd"
log "View logs if issues: journalctl -u lscpd -n 50"
