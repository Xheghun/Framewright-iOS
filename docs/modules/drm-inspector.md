# FairPlay diagnostic hooks

Create a `FramewrightDRMInspector` for the active diagnostic session. In the host's own FairPlay
delegate or license client, call `beginAttempt` before a request and `finishAttempt` after its outcome.
Supply the retry number from the host. Report lifecycle transitions explicitly with
`recordSessionEvent`. Call `detach` on session replacement; late or repeated tokens are ignored.

Only typed outcomes and diagnostic identifiers are accepted. Keep the actual license URL, SPC,
CKC, key material, native session identifiers and raw errors inside the host integration.
The inspector never performs the license request or changes key/session ownership. Observe the
returned pipeline result if diagnostics acceptance matters to the host.

The hooks have deterministic tests. Authorized FairPlay media and hardware are still required to
verify native callbacks, provisioning equivalence, key validity, expiration, security, and HDCP.
