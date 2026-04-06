# Endpoint Topology: 1,000-User Global MDM Rollout

## 1. Device Enrollment

### macOS — Apple Business Manager (ABM) + MDM
**Enrolment type: Pre-provisioned.**
Devices purchased through an ABM-linked reseller are automatically registered to the MDM (e.g. Jamf). On first boot, the device enrolls via Automated Device Enrolment (ADE) with zero IT touch — no user action required. Supervised mode is enabled for full management. Users are assigned via directory sync (Okta / Entra ID).

### Windows — Intune + Autopilot
**Enrolment type: Pre-provisioned (IT-shipped) or user-driven (BYOD).**
Hardware hashes registered at procurement. For IT-shipped machines, white-glove pre-provisioning allows IT to fully configure the device before it reaches the user. For BYOD, the user signs in with Entra ID credentials on first boot and Autopilot delivers config, apps, and policy silently.

### ChromeOS — Google Admin Console + Zero-Touch
**Enrolment type: Pre-provisioned.**
Serials registered in Google Admin at procurement. On first sign-in with a Google Workspace account, policies and apps are applied automatically. Enrolment lock prevents unenrolment without admin approval. No IT hands-on time required.

### Identity Assumptions
- Single IdP (Okta) — SSO via SAML 2.0 / OIDC, MFA enforced for all users
- Device identity tied to the enrolled user account at MDM level

---

## 2. Security Baseline — Day-One Controls

**Disk encryption**
> macOS — FileVault enforced via MDM
> Windows — BitLocker via Intune
> ChromeOS — built-in, mandatory by default

**Firewall**
> macOS — application firewall enabled
> Windows — Windows Firewall on across all profiles
> ChromeOS — sandboxed OS model, not applicable

**Screen lock**
> all platforms — idle lock at 5 min or less, enforced via MDM/GPO/Admin Console

**Admin rights**
> standard user on all platforms — no local admin for end users

**EDR**
> macOS / Windows — CrowdStrike or SentinelOne
> ChromeOS — not applicable (read-only sandboxed OS)

**Remote wipe**
> macOS — MDM wipe + Activation Lock bypass
> Windows — Intune selective or full wipe
> ChromeOS — Google Admin remote wipe

**Certificates**
> macOS — MDM-deployed device cert
> Windows — SCEP/PKCS via Intune
> ChromeOS — auto-managed device cert

---

## 3. Application Management

**Deployment**
> macOS — VPP licences pushed silently via Jamf
> Windows — Intune Win32 packages or Microsoft Store
> ChromeOS — Managed Google Play with force-install

**Core apps** (browser, comms, EDR, VPN) deploy silently on enrolment day one.
Non-core apps are available via self-service — Jamf Self Service / Company Portal / Chrome Web Store.

**Updates** — MDM enforces minimum versions. Updates go to a pilot group first before broad rollout.

**Removal** — on offboarding MDM revokes the licence and removes the app on next check-in. Licence returns to the pool for reassignment.

---

## 4. Update & Compliance Strategy

**Rollout rings**
> Pilot (5%) — IT team + volunteers — no deferral, gets updates immediately
> Early adopters (20%) — tech-comfortable users — 7 day deferral
> General (75%) — everyone else — 14 day deferral

Two weeks soak time between rings before promoting to the next group.

**Compliance reporting**
MDM dashboards give real-time view of OS version, encryption status, and last check-in per device. Non-compliant devices get flagged in daily reports and blocked from resources via conditional access at the IdP. Compliance events forwarded to SIEM for audit trails.

**Exceptions** — deferrals beyond the policy window need formal approval, max 30 days.
