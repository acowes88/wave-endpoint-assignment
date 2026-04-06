# Part 3 — Reflection

## Trade-offs due to time constraints
- Mock API endpoints — real SendGrid/ServiceNow schemas, just swap credentials
- CSV instead of a real CMDB — keeps it self-contained
- No retry logic on API calls
- No unit tests

## How would you productionise at scale?
- Replace CSV with Jamf Pro API / Google Admin SDK
- Deploy via MDM on a schedule — no manual SSH
- Centralise logs to SIEM (Elastic/Splunk)
- Secrets via MDM-managed keychain, never in the script

## What would you improve with more time?
- Bash stub tests — mock fdesetup/lsblk, assert on log output
- Full semantic version comparison for ChromeOS (major.minor.patch)
- Event-driven triggers on MDM enrolment instead of polling

---
*AI tooling used for scaffolding the API calls and loops. Design decisions and explanations are my own.*
