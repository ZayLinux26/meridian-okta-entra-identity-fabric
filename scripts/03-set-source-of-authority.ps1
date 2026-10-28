<#
.SYNOPSIS
    Reads or sets a user's source of authority (isCloudManaged) in Entra.

.DESCRIPTION
    isCloudManaged = $true   Entra blocks writes from the directory sync channel.
    isCloudManaged = $false  The sync channel can write to the object.

    Okta's Office 365 connector (User Sync) writes through the sync channel, so
    Okta-managed users must be $false. Setting $true on one of them causes:
    "Unable to update an object that has another Source of Authority."

    Requires Hybrid Identity Administrator (activate in PIM first).
    Use the object ID, not the UPN. The beta endpoint returned 404 for UPNs.

.EXAMPLE
    ./03-set-source-of-authority.ps1 -UserId caf23ae2-faff-4c85-9d25-c3ddde42fe0d
    ./03-set-source-of-authority.ps1 -UserId caf23ae2-faff-4c85-9d25-c3ddde42fe0d -CloudManaged $false
#>
param(
    [Parameter(Mandatory)][string]$UserId,
    [Nullable[bool]]$CloudManaged,
    [string]$TenantId = 'isaiahherard26gmail.onmicrosoft.com'
)

Connect-MgGraph -TenantId $TenantId -Scopes 'User-OnPremisesSyncBehavior.ReadWrite.All', 'User.Read.All' -NoWelcome

$uri = "https://graph.microsoft.com/beta/users/$UserId/onPremisesSyncBehavior"
$sel = "https://graph.microsoft.com/beta/users/$UserId`?`$select=displayName,userPrincipalName,onPremisesSyncEnabled,onPremisesImmutableId"

"BEFORE:"
Invoke-MgGraphRequest GET $sel
(Invoke-MgGraphRequest GET $uri).isCloudManaged

if ($null -ne $CloudManaged) {
    Invoke-MgGraphRequest PATCH $uri -Body @{ isCloudManaged = [bool]$CloudManaged }
    "AFTER:"
    (Invoke-MgGraphRequest GET $uri).isCloudManaged
    "Anchor (should be unchanged):"
    (Invoke-MgGraphRequest GET $sel).onPremisesImmutableId
}
