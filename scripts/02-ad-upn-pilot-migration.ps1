<#
.SYNOPSIS
    Adds the federated UPN suffix to the AD forest and moves a pilot ring onto it.

.DESCRIPTION
    1. Adds the routable suffix to the forest (needs Enterprise Admin).
    2. Lists every user still on the old suffix (the migration manifest).
    3. Moves only the named pilot users. Runs with -WhatIf unless -Apply is set.

    After this, run an incremental import in Okta so usernames update there.

.EXAMPLE
    ./02-ad-upn-pilot-migration.ps1                 # dry run
    ./02-ad-upn-pilot-migration.ps1 -Apply          # make the change
#>
param(
    [string]$Forest     = 'meridianfg.internal',
    [string]$NewSuffix  = 'mhp.isaiahherard.com',
    [string]$OldSuffix  = 'isaiahherard26gmail.onmicrosoft.com',
    [string[]]$Pilot    = @('esokolova', 'dreyes', 'kwalsh'),
    [switch]$Apply
)

"UPN suffixes BEFORE:"; (Get-ADForest $Forest).UPNSuffixes
if ((Get-ADForest $Forest).UPNSuffixes -notcontains $NewSuffix) {
    if ($Apply) { Set-ADForest -Identity $Forest -UPNSuffixes @{ Add = $NewSuffix } }
    else { "Would add suffix $NewSuffix" }
}
"UPN suffixes AFTER:"; (Get-ADForest $Forest).UPNSuffixes

"`nMigration manifest (users on @$OldSuffix):"
Get-ADUser -Filter "UserPrincipalName -like '*@$OldSuffix'" -Properties Enabled, Department |
    Select-Object Name, SamAccountName, UserPrincipalName, Enabled, Department,
        @{ n = 'OU'; e = { ($_.DistinguishedName -split ',', 2)[1] } } |
    Sort-Object OU, Name | Format-Table -AutoSize

foreach ($s in $Pilot) {
    if ($Apply) { Set-ADUser $s -UserPrincipalName "$s@$NewSuffix" }
    else        { Set-ADUser $s -UserPrincipalName "$s@$NewSuffix" -WhatIf }
}

"`nUsers now on @$($NewSuffix):"
Get-ADUser -Filter "UserPrincipalName -like '*@$NewSuffix'" |
    Select-Object Name, SamAccountName, UserPrincipalName | Format-Table -AutoSize
