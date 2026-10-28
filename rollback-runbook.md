# Runbook: Okta Outage Response and Federation Rollback

**Scope:** `mhp.isaiahherard.com`, federated to Okta over SAML 2.0
**Status:** Section A was tested in the Phase 7 drill. Section B is documented and has not been executed.

---

## Before anything: who can still get in

| Account | Domain | Depends on Okta? | Use |
|---|---|---|---|
| `adm-zay@isaiahherard26gmail.onmicrosoft.com` | onmicrosoft.com | No | Tier 0 admin. Activate Global Admin through PIM (needs approval). |
| `meridian-admin@isaiahherard26gmail.onmicrosoft.com` | onmicrosoft.com | No | Break-glass. Permanent Global Admin. Only if PIM or approval is unavailable. |
| Federated users | mhp.isaiahherard.com | Yes | Locked out while Okta is down |

Credentials for both admin accounts are in Bitwarden, `Meridian-PAM-Vault`. Any break-glass sign-in gets a ticket and a review afterward.

---

## Section A: Okta outage (temporary, wait it out)

Use this when Okta or the Okta SAML app is unavailable and you expect it back.

1. **Confirm the scope.** Try a federated sign-in at `https://myapps.microsoft.com`. An Okta error page means the outage is on the IdP side. Check Okta's status page.
2. **Confirm admin access.** Sign in as `adm-zay`. It doesn't touch Okta. Activate Global Admin only if you need to make a change.
3. **Tell users.** Federated Microsoft sign-ins are down. Existing Microsoft sessions keep working until they expire.
4. **Don't roll back for a short outage.** Rolling back (Section B) changes how every user on the domain signs in and takes real work to reverse.
5. **When Okta reactivates, wait before announcing recovery.** In the drill, sign-ins failed with `Unable to find target app instance` for about 10 minutes after the app was reactivated. Test a real federated sign-in before telling users service is back.

**Drill result (Oct 27, 2026):** outage 10:11 PM, app reactivated 10:21 PM, first successful federated sign-in 10:31 PM.

---

## Section B: Roll back federation (return the domain to managed)

Use this only for a long Okta outage, a broken federation trust you can't fix, or a decision to leave Okta.

### B1. Pre-checks

- [ ] Change ticket opened and approved
- [ ] Signed in as `adm-zay` with Global Admin activated (or Hybrid Identity Administrator plus User Administrator)
- [ ] List every user on the domain. They will need a way to sign in after rollback:

```powershell
Connect-MgGraph -TenantId "isaiahherard26gmail.onmicrosoft.com" -Scopes "Domain-InternalFederation.ReadWrite.All","Domain.ReadWrite.All","User.ReadWrite.All"
Get-MgUser -Filter "endswith(userPrincipalName,'@mhp.isaiahherard.com')" -ConsistencyLevel eventual -CountVariable c `
    -Property DisplayName,UserPrincipalName,OnPremisesImmutableId | Format-Table
```

### B2. Give users a credential Entra can check

Federated users have **no password in Entra**. Okta's password sync is off by design. After rollback, Entra checks the sign-in itself, so each user needs a password or another method first.

> **Untested risk:** these users are sync-managed in Entra (written by Okta's connector). Entra may block a cloud password reset on sync-managed objects. Test this on one pilot user in a maintenance window before relying on it in an incident. If it's blocked, set `isCloudManaged = true` on the user first (this stops Okta's writes to that user, so disable Okta provisioning for them too).

### B3. Remove the federation

```powershell
$domain = 'mhp.isaiahherard.com'
$base   = "https://graph.microsoft.com/v1.0/domains/$domain/federationConfiguration"
$cfg    = (Invoke-MgGraphRequest GET $base).value[0]

# Save the current config to the ticket before deleting it
$cfg | ConvertTo-Json -Depth 5 | Out-File "./federation-config-backup-$(Get-Date -Format yyyyMMdd-HHmm).json"

Invoke-MgGraphRequest DELETE "$base/$($cfg.id)"
(Invoke-MgGraphRequest GET "https://graph.microsoft.com/v1.0/domains/$domain").authenticationType
```

Expect `Managed`. If it still says `Federated`, run:

```powershell
Update-MgDomain -DomainId $domain -AuthenticationType Managed
```

### B4. Verify

- [ ] A pilot user signs in at `https://myapps.microsoft.com` with no Okta redirect
- [ ] The pilot user completes Microsoft MFA registration (the registration campaign exclusion no longer makes sense for these users; review it)
- [ ] PIM activation still works for eligible users

### B5. Afterward

- Okta provisioning still writes to these users unless you stop it. Decide whether Okta keeps managing them.
- Leave the Okta SAML app deactivated, not deleted, so the trust can be rebuilt.
- Re-federating uses the saved config from B3 and the same Graph call as Phase 2 of the build.

---

## Rules that apply in every incident

- Disable, don't delete. Deactivated Okta apps keep their config, certificates, assignments, and inline hook.
- Break-glass is for when PIM or approval is unavailable, not for convenience.
- Write down the times. They become the measured recovery time for the next review.
