#!/usr/bin/env bash
# ChromeOS compliance check — encryption + minimum OS version.
# Updates asset CSV, alerts user + IT if either check fails.
# Run as root via Google Admin Console scripts.

# stop immediately if any command fails — no silent errors in production
set -euo pipefail

# --- config: secrets injected via mdm , jamf - $4 and $5
ASSETS_CSV="./assets.csv"
LOG="/var/log/chromeos_compliance.log"
MIN_VERSION="114"   # minimum accepted ChromeOS major version
EMAIL_URL="https://api.sendgrid.com/v3/mail/send"
TICKET_URL="https://wave.service-now.com/api/now/table/incident"
EMAIL_KEY="${1:FAKEKEy1234}"
TICKET_KEY="${2:FAKEKey1234}"
IT_EMAIL="it-support@wave.com"

# timestamp every line → stdout and log file for SIEM ingestion
log() { echo "[$(date '+%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG"; }

# delete temp file on exit, even if the script crashes - avoid corrupted data
TMP=""; trap '[[ -n "$TMP" ]] && rm -f "$TMP"' EXIT

# --- device id ---
SERIAL=$(cat /sys/class/dmi/id/product_serial 2>/dev/null || echo "")
HOST=$(hostname -s)
NOW=$(date '+%Y-%m-%dT%H:%M:%SZ')
# match serial against CSV to find the assigned user (col 3)
USER_EMAIL=$(awk -F',' -v s="$SERIAL" '$1==s { print $3 }' "$ASSETS_CSV")
USER_EMAIL="${USER_EMAIL:-unknown@company.com}"   # fallback if device not in CSV yet

## safety check if serial is not found, exit
[[ -z "$SERIAL" ]] && { log "ERROR: no serial number"; exit 1; }
log "Device: $HOST ($SERIAL)"

# encryption extra check (by default in chromeOS)
# check if lsblk lists device shows dm-crypt = encrypted 
if lsblk -o NAME,TYPE | grep -q "crypt"; then ENC="encrypted"; else ENC="not_encrypted"; fi
log "Encryption: $ENC"

# os version check
# get major versions only from chromeOS 
OS_VER=$(grep "^CHROMEOS_RELEASE_VERSION=" /etc/lsb-release | cut -d= -f2 | cut -d. -f1)
OS_VER="${OS_VER:-0}"
# check integer comparison against minimum
if (( OS_VER >= MIN_VERSION )); then VER_OK=true; else VER_OK=false; fi
log "Version: $OS_VER (min $MIN_VERSION) — $( $VER_OK && echo PASS || echo FAIL )"


# update CSV: temp file first, then atomic move to avoid corrupt writes ---
if grep -q "^${SERIAL}," "$ASSETS_CSV"; then
    TMP=$(mktemp)
    # col 6 = encryption, col 7 = version, col 8 = last_checked
    awk -F',' -v OFS=',' -v s="$SERIAL" -v enc="$ENC" -v ver="$OS_VER" -v ts="$NOW" \
        '$1==s { $6=enc; $7=ver; $8=ts } 1' "$ASSETS_CSV" > "$TMP"
    mv "$TMP" "$ASSETS_CSV"; TMP=""
    log "CSV updated"
else
    log "WARN: serial $SERIAL not in CSV"
fi

# --- alert: OR condition — either failure triggers email + ticket ---
# API failures log a warning but never crash — CSV result is already saved
if [[ "$ENC" == "not_encrypted" || "$VER_OK" == false ]]; then
    ISSUE="Encryption: $ENC | Version: $OS_VER (min $MIN_VERSION)"

    curl -sf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $EMAIL_KEY" \
        -d "{\"personalizations\":[{\"to\":[{\"email\":\"$USER_EMAIL\"}]}],\"from\":{\"email\":\"$IT_EMAIL\"},\"subject\":\"Action required: ChromeOS compliance issue\",\"content\":[{\"type\":\"text/plain\",\"value\":\"Issue on $HOST: $ISSUE. IT will be in contact.\"}]}" \
        "$EMAIL_URL" && log "Email sent" || log "WARN: email failed"

    curl -sf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TICKET_KEY" \
        -d "{\"short_description\":\"ChromeOS compliance failure on $HOST\",\"description\":\"Serial: $SERIAL | User: $USER_EMAIL | $ISSUE | $NOW\",\"urgency\":\"2\"}" \
        "$TICKET_URL" && log "Ticket created" || log "WARN: ticket failed"
fi

log "Done"
