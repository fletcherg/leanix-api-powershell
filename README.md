# leanix-api-powershell

Very rough and basic Powershell to interact with LeanIX API 🙈

# Getting Started

Need to create a LX token, via LeanIX admin portal.

```

$LXbaseURL = "https://tenant.leanix.net"
$LXapiToken = "LXT_XXXXXXXXXXXXXXXXXXXXXXX
$LXworkspaceID = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

Connect-LeanIX -URL $LXbaseURL -apiToken $LXapiToken -WorkspaceID $LXworkspaceID -Force

# Retrieve initiatives fact sheets
Get-LXInitiatives

```

# Updates

PRs welcome 😊🙏😍
