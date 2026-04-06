#!/usr/bin/env bash
# macOS FileVault compliance check test for wave home assignment
# by Alan Cowes
# v1.0 - 6/4/2026 

# stop immediately if any command fails — no silent errors in production
set -euo pipefail

# --- config: secrets injected via MDM, never hardcoded , ex. $4 & $5 in jamf ---
ASSETS_CSV="./assets.csv"
LOG="/var/log/filevault_check.log"
EMAIL_URL="https://api.sendgrid.com/v3/mail/send"
TICKET_URL="https://wave.service-now.com/api/now/table/incident"
EMAIL_KEY="${1:-REPLACE_ME}"
TICKET_KEY="${2:-REPLACE_ME}"
IT_EMAIL="it-support@wave.com"

# timestamp every line → written to stdout and log file for SIEM ingestion (elastic, splunk etc)
log() { echo "[$(date '+%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG"; }

# delete temp file on exit, even if the script crashes
TMP=""; trap '[[ -n "$TMP" ]] && rm -f "$TMP"' EXIT

#  device id ---
# system_profiler = native macOS hardware ifno command
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial Number/ { print $NF }')
HOST=$(hostname -s)
NOW=$(date '+%Y-%m-%dT%H:%M:%SZ')
# match serial against CSV to find the assigned user (col 3)
USER_EMAIL=$(awk -F',' -v s="$SERIAL" '$1==s { print $3 }' "$ASSETS_CSV")
USER_EMAIL="${USER_EMAIL:-unknown@wave.com}"   # fallback if device not in CSV yet

# check ift he serial exists, otherwise fail with exit 1
[[ -z "$SERIAL" ]] && { log "ERROR: no serial number"; exit 1; }
log "Device: $HOST ($SERIAL)"

# compliance check ---
# fdesetup, returns "FileVault is On." or "FileVault is Off."
FV=$(fdesetup status 2>&1) || { log "ERROR: fdesetup failed"; exit 1; }
if echo "$FV" | grep -q "FileVault is On"; then STATUS="enabled"; else STATUS="disabled"; fi
log "FileVault: $STATUS"

#  update CSV: write to temp file first, then atomic move to avoid corrupt writes ---
if grep -q "^${SERIAL}," "$ASSETS_CSV"; then
    TMP=$(mktemp)
    # col 5 = filevault_status, col 8 = last_checked
    awk -F',' -v OFS=',' -v s="$SERIAL" -v st="$STATUS" -v ts="$NOW" \
        '$1==s { $5=st; $8=ts } 1' "$ASSETS_CSV" > "$TMP"
    mv "$TMP" "$ASSETS_CSV"; TMP=""
    log "CSV updated: filevault_status=$STATUS"
else
    log "WARN: serial $SERIAL not in CSV"
fi

# --- alert: if disabled, email user and open IT ticket ---
# API failures log a warning but never crash — CSV result is already saved
if [[ "$STATUS" == "disabled" ]]; then
    curl -sf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $EMAIL_KEY" \
        -d "{\"personalizations\":[{\"to\":[{\"email\":\"$USER_EMAIL\"}]}],\"from\":{\"email\":\"$IT_EMAIL\"},\"subject\":\"Action required: FileVault not enabled\",\"content\":[{\"type\":\"text/plain\",\"value\":\"FileVault is disabled on $HOST. IT will be in contact to remediate.\"}]}" \
        "$EMAIL_URL" && log "Email sent" || log "WARN: email failed"

    curl -sf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TICKET_KEY" \
        -d "{\"short_description\":\"FileVault disabled on $HOST\",\"description\":\"Serial: $SERIAL | User: $USER_EMAIL | Checked: $NOW\",\"category\":\"endpoint_compliance\",\"urgency\":\"2\"}" \
        "$TICKET_URL" && log "Ticket created" || log "WARN: ticket failed"
fi

log "Done"
