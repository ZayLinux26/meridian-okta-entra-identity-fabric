<#
.SYNOPSIS
    Leaver step 1: disable a user in AD, in place, and record the time.

.DESCRIPTION
    Disables the account without moving it. Moving a leaver out of Okta's import
    scope first hides the change from incremental imports. Move the account to a
    Disabled Users OU only after Okta shows it as Deactivated.

    After running:
      1. Okta: run an incremental import (or wait for the schedule). Status should be Deactivated.
      2. Entra: accountEnabled should go to false about 10 seconds after Okta deactivates.
      3. PIM: check for eligible role assignments left behind and remove them.

.EXAMPLE
    ./06-leaver-disable.ps1 -SamAccountName dreyes
#>
param(
    [Parameter(Mandatory)][string]$SamAccountName
)

$t0 = Get-Date
"Termination started: $t0"

Disable-ADAccount -Identity $SamAccountName

Get-ADUser $SamAccountName -Properties Enabled, UserPrincipalName |
    Select-Object Name, UserPrincipalName, Enabled, DistinguishedName | Format-List
