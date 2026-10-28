<#
.SYNOPSIS
    Lists every Entra user on the federated domain with their ImmutableID.

.DESCRIPTION
    Compare the ImmutableID column with the output of 01-compute-immutableid.ps1.
    Every value must match AD exactly, and adopted users (Elena) must keep their
    original object ID. A duplicate object for the same person means Okta created
    instead of linked.

    Expected for the pilot:
      esokolova  eO6NYRFWXES3DfsrawT5BA==  (object ID caf23ae2-...)
      dreyes     OKguRL3xe0iCuJNL3NX3TA==
      kwalsh     Ghk/WtmeOki9TvEm1wEXig==
#>
param(
    [string]$Domain   = 'mhp.isaiahherard.com',
    [string]$TenantId = 'isaiahherard26gmail.onmicrosoft.com'
)

Connect-MgGraph -TenantId $TenantId -Scopes 'User.Read.All' -NoWelcome

Get-MgUser -Filter "endswith(userPrincipalName,'@$Domain')" -ConsistencyLevel eventual -CountVariable c `
    -Property Id, DisplayName, UserPrincipalName, OnPremisesImmutableId, AccountEnabled, Department |
    Select-Object DisplayName, UserPrincipalName, OnPremisesImmutableId, AccountEnabled, Department, Id |
    Format-Table -AutoSize

"Users on @$($Domain): $c"
