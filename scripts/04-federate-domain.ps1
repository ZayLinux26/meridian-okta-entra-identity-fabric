<#
.SYNOPSIS
    Federates an Entra domain to Okta over SAML 2.0, using Okta's metadata.

.DESCRIPTION
    Modes:
      -Check     Pull Okta metadata, show domain auth type and blast radius (users on the domain). Changes nothing.
      -Federate  Create the internalDomainFederation object. One per domain: a second POST returns 400.
      -SetMfa    Set federatedIdpMfaBehavior on an existing federation (PATCH).
      -Show      Show the current federation config.

    Requires Hybrid Identity Administrator (activate in PIM first).
    Reading trust values from metadata avoids pasting a certificate into a shell.

.EXAMPLE
    ./04-federate-domain.ps1 -Check
    ./04-federate-domain.ps1 -Federate
    ./04-federate-domain.ps1 -SetMfa enforceMfaByFederatedIdp
#>
param(
    [switch]$Check,
    [switch]$Federate,
    [ValidateSet('acceptIfMfaDoneByFederatedIdp', 'enforceMfaByFederatedIdp', 'rejectMfaByFederatedIdp')]
    [string]$SetMfa,
    [switch]$Show,
    [string]$Domain      = 'mhp.isaiahherard.com',
    [string]$TenantId    = 'isaiahherard26gmail.onmicrosoft.com',
    [string]$MetadataUrl = 'https://trial-3542283.okta.com/app/exk18ufj4phzRZTcB698/sso/saml/metadata',
    [string]$SignOutUri  = 'https://trial-3542283.okta.com/login/signout'
)

Connect-MgGraph -TenantId $TenantId -Scopes 'Domain-InternalFederation.ReadWrite.All', 'Domain.Read.All', 'User.Read.All' -NoWelcome
$base = "https://graph.microsoft.com/v1.0/domains/$Domain/federationConfiguration"

if ($Check -or $Federate) {
    $md     = [xml](Invoke-WebRequest $MetadataUrl).Content
    $issuer = $md.EntityDescriptor.entityID
    $sso    = ($md.EntityDescriptor.IDPSSODescriptor.SingleSignOnService | Where-Object Binding -like '*HTTP-POST').Location
    $cert   = ($md.EntityDescriptor.IDPSSODescriptor.KeyDescriptor | Select-Object -First 1).KeyInfo.X509Data.X509Certificate -replace '\s', ''

    "Issuer:       $issuer"
    "SSO URL:      $sso"
    "Cert length:  $($cert.Length)"
    "Graph tenant: $((Get-MgContext).TenantId)"
    "Auth type:    $((Invoke-MgGraphRequest GET "https://graph.microsoft.com/v1.0/domains/$Domain").authenticationType)"
    $count = (Invoke-MgGraphRequest GET "https://graph.microsoft.com/v1.0/users?`$filter=endswith(userPrincipalName,'@$Domain')&`$count=true" -Headers @{ ConsistencyLevel = 'eventual' }).value.Count
    "Blast radius: $count user(s) on $Domain"
}

if ($Federate) {
    $body = @{
        '@odata.type'                         = '#microsoft.graph.internalDomainFederation'
        displayName                           = 'Okta - MHP (SAML)'
        issuerUri                             = $issuer
        passiveSignInUri                      = $sso
        signOutUri                            = $SignOutUri
        signingCertificate                    = $cert
        preferredAuthenticationProtocol       = 'saml'
        federatedIdpMfaBehavior               = 'enforceMfaByFederatedIdp'
        isSignedAuthenticationRequestRequired = $false
    } | ConvertTo-Json
    Invoke-MgGraphRequest POST $base -Body $body -ContentType 'application/json' | Out-Null
    "Federation created."
}

if ($SetMfa) {
    $cfg = (Invoke-MgGraphRequest GET $base).value[0]
    "BEFORE: $($cfg.federatedIdpMfaBehavior)"
    Invoke-MgGraphRequest PATCH "$base/$($cfg.id)" -Body @{
        '@odata.type'           = '#microsoft.graph.internalDomainFederation'
        federatedIdpMfaBehavior = $SetMfa
    }
    "AFTER:  $(((Invoke-MgGraphRequest GET $base).value[0]).federatedIdpMfaBehavior)"
}

if ($Show -or $Federate) {
    "Auth type: $((Invoke-MgGraphRequest GET "https://graph.microsoft.com/v1.0/domains/$Domain").authenticationType)"
    (Invoke-MgGraphRequest GET $base).value | ForEach-Object {
        [pscustomobject]@{
            Name     = $_.displayName
            Protocol = $_.preferredAuthenticationProtocol
            Issuer   = $_.issuerUri
            MFA      = $_.federatedIdpMfaBehavior
        }
    } | Format-List
}
