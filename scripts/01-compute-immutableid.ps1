<#
.SYNOPSIS
    Shows the Entra ImmutableID (base64 objectGUID) for each pilot user in AD.

.DESCRIPTION
    Okta sends this value as the SAML NameID and writes it to Entra as
    onPremisesImmutableId. Run this on a domain-joined machine with the
    ActiveDirectory module, then compare the output to Entra
    (05-verify-pilot-anchors.ps1). A mismatch of one character breaks sign-in.

.EXAMPLE
    ./01-compute-immutableid.ps1 -SamAccountNames esokolova,dreyes,kwalsh
#>
param(
    [string[]]$SamAccountNames = @('esokolova', 'dreyes', 'kwalsh')
)

$SamAccountNames | ForEach-Object {
    $u = Get-ADUser $_ -Properties ObjectGUID, 'mS-DS-ConsistencyGuid', UserPrincipalName
    [pscustomobject]@{
        User               = $_
        UPN                = $u.UserPrincipalName
        ObjectGUID         = $u.ObjectGUID
        ImmutableID        = [Convert]::ToBase64String($u.ObjectGUID.ToByteArray())
        HasConsistencyGuid = [bool]$u.'mS-DS-ConsistencyGuid'
    }
} | Format-Table -AutoSize
