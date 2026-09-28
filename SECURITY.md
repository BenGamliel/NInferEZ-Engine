# Security policy

## Reporting a vulnerability

Please report suspected security vulnerabilities through GitHub's private vulnerability reporting
for this repository when it is available. If private reporting is unavailable, open an issue that
contains no exploit details or secrets and ask the maintainers for a private contact channel.

Do not include model data, prompts, API keys, access tokens, personal information or unredacted log
archives in a public report.

## Supported releases

Only the newest published NInferEZ Engine release is eligible for security fixes. Preview builds are
unsigned and build-verified; verify the release archive against its published SHA-256 before use.

NInferEZ Engine exposes a local HTTP service. Bind it to a trusted interface, configure an API key
when other users or processes can reach the port, and do not expose it directly to the public
Internet without an authenticated reverse proxy and appropriate network controls.
