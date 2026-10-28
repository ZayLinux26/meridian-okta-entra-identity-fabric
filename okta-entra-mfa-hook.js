// Okta SAML assertion inline hook for the Microsoft Entra ID (MHP) custom SAML app.
//
// Why this exists: for SAML 2.0 federation, Entra ID only accepts an inbound MFA signal
// in <AuthnStatement><AuthnContext><AuthnContextClassRef>. Okta's custom SAML app UI
// only offers standard context classes (PasswordProtectedTransport, X.509, etc.), so
// this hook replaces the context class with Microsoft's multipleauthn value.
//
// Trust note: the value is static. It is truthful only because the app's Okta
// authentication policy always requires a phishing-resistant factor, with a
// catch-all Deny rule. Relaxing that policy would make this claim false.

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Okta SAML inline hook endpoint", { status: 200 });
    }

    // Okta sends the shared secret configured on the inline hook in this header.
    if (request.headers.get("Authorization") !== env.HOOK_SECRET) {
      return new Response("Unauthorized", { status: 401 });
    }

    const patch = {
      commands: [
        {
          type: "com.okta.assertion.patch",
          value: [
            {
              op: "replace",
              path: "/authentication/authnContext",
              value: {
                authnContextClassRef: "http://schemas.microsoft.com/claims/multipleauthn",
              },
            },
          ],
        },
      ],
    };

    return new Response(JSON.stringify(patch), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  },
};
