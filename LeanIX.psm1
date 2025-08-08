function Connect-LeanIX {
    <#
        .SYNOPSIS
        This will Connect to LeanIX.

        .EXAMPLE
        Connect-LeanIX -URL "https://tenant.leanix.net" -apiToken "LXT_XXXXXXXXXXXXXXXXXXXXXXX" -WorkspaceID "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$URL,
        [Parameter(Mandatory=$true)]
		[string]$apiToken,
        [Parameter(Mandatory=$true)]
		[string]$WorkspaceID,
        [switch]$Force
    )

	# this is stupid
	if ($global:LeanIXConnection -and !$force) {
		Write-Verbose "Connect-LeanIX: Using cached server information for tenant $($global:LeanIXConnection:tenantName)"
		return
	}

    Write-Verbose "Connecting to LeanIX..."    
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("apitoken:$($LXapiToken)"))

    $Headers = @{
        Authorization = "Basic $encodedCreds"
    }

    $result = Invoke-WebRequest -Uri "$URL/services/mtm/v1/oauth2/token" -Headers $Headers -body "grant_type=client_credentials" -method POST
    $LXtoken = ($result.content | convertfrom-json).access_token

    $AuthHeaders = @{
        Accept = "application/json"
        Authorization = "Bearer $LXtoken"
    }

    $global:LeanIXConnection = @{
        LXToken = $LXToken
        LXURL = $URL
        LXHeaders = $AuthHeaders
        LXWorkspaceID = $WorkspaceID
        LXTokenExpiry = (Get-Date).AddSeconds(($result.content | convertfrom-json).expires_in)
    }
}

function Disconnect-LeanIX {
    <#
        .SYNOPSIS
        This will remove the LeanIX authentication mechanism.
    
    #>
    [CmdletBinding()]
    param()
    $null = Remove-Variable -Name LeanIXConnection -Scope global -Force -Confirm:$false -ErrorAction SilentlyContinue
    if($LeanIXConnection -or $global:LeanIXConnection) {
        Write-Error "There was an error clearing connection information.`n$($Error[0])"
    } else {
        Write-Verbose 'Disconnect-LeanIX $LeanIXConnection, variable removed.'
    }
}

function Invoke-LeanIXGraphQL {
    <#
        .SYNOPSIS
        This will invoke a GraphQL query against LeanIX.
    
        .EXAMPLE
        Invoke-LeanIXGraphQL -Query "query { allProjects { edges { node { id name } } } }"
    
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,
        [string]$Variables
    )

    if (-not $global:LeanIXConnection) {
        Write-Error "You must connect to LeanIX first using Connect-LeanIX."
        return
    }

    if ( $Global:LeanIXConnection.LXTokenExpiry -lt (Get-Date) ) {
        Write-Error "LeanIX connection has expired. You must connect again via Connect-LeanIX"
        return
    }

    $url = "$($global:LeanIXConnection.LXURL)services/pathfinder/v1/graphql"

    if ($Variables) {

        $body = @{
            "query" = $query
            "variables" = $variables
        } | ConvertTo-Json

    } else {

        $body = @{
            "query" = $query
        } | ConvertTo-Json

    }

    $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $global:LeanIXConnection.LXHeaders -ContentType "application/json"
    return $response.data
}

Function Get-LXInitiatives {
    <#
        .SYNOPSIS
        Gets the initiatives in LeanIX
    #>
    [CmdletBinding()]
    param(
        [switch]$summary=$false
    )
    Write-Verbose "Retrieving initiatives"
    if ($summary) {
$query = @"
query retrieveFactSheetsByType(`$filter: FilterInput!) {
  allFactSheets(filter: `$filter) {
    totalCount
    edges {
      node {
        id
        displayName
        type
        ... on Initiative {
          externalId {
            externalId
          }
        }
            subscriptions {
      edges {
        node {
          id
          user {
            id
            email
          }
          type
          roles {
            id
            name
            comment
          }
        }
      }
    }
      }
    }
  }
}
"@

$variables = @"
{
  "filter": {
    "facetFilters": [
      {
        "facetKey": "FactSheetTypes",
        "operator": "OR",
        "keys": [
          "Initiative"
        ]
      }
    ]
  }
}
"@
    } else {
        
$query = @"
query retrieveFactSheetsByType(`$filter: FilterInput!) {
  allFactSheets(filter: `$filter) {
    totalCount
    edges {
      node {
        id
        displayName
        type
        ... on Initiative {
          fullName
          name
          ariBenefitsAnticipated
          ariInitiativeDescription
          ariName
          ariObjective
          ariPriority
          ariProblemStatement
          ariScheduledFinish
          ariScheduledStart
          ariStage
          ariStatus
          ariStrategyBusiness
          ariStrategyFinancial
          ariTotalCost
          ariTotalCostCAPEX
          ariTotalCostOPEX
          ariWorkParent
          lifecycle {
            phases {
              milestoneId
            }
          }
          tags {
            tagGroup {
              id
              name
            }
            description
            name
          }
        }
        subscriptions {
          edges {
            node {
              id
              user {
                id
                email
              }
              type
              roles {
                id
                name
                comment
              }
            }
          }
        }
      }
    }
  }
}
"@

$variables = @"
{
  "filter": {
    "facetFilters": [
      {
        "facetKey": "FactSheetTypes",
        "operator": "OR",
        "keys": [
          "Initiative"
        ]
      }
    ]
  }
}
"@

    }

    $response = Invoke-LeanIXGraphQL -Query $query -Variables $variables
    return $response.allfactsheets.edges.node

}


Function Get-LXTags {
    <#
        .SYNOPSIS
        Gets all tags in LeanIX
    #>
$query = @"
query GetTags {
  allTagGroups {
    edges {
      node {
        name
        id
        tags {
          edges {
            node {
              id
              name
            }
          }
        }
      }
    }
  }
}
"@
    $response = Invoke-LeanIXGraphQL -Query $query
    return $response.allTagGroups.edges.node
}

Function Add-LXTag {
    <#
        .SYNOPSIS
        Add Tag to LX FactSheet

        .EXAMPLE
        Add-LXTag -factSheetID XXXXX -tagId XXXXX
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$factSheetId,
        [Parameter(Mandatory=$true)]
        [string]$tagId
    )
$query = @"
mutation (`$patches: [Patch]!) {
  updateFactSheet(id: "$($factsheetid)", patches: `$patches) {
    factSheet {
      id
      name
      tags {
        id
        name
      }
    }
  }
}
"@


$variables = @"
{
  "patches": [
    {
      "op": "add",
      "path": "/tags",
      "value": "[{\"tagId\":\"$($tagid)\"}]"
    }
  ]
}
"@

    $response = Invoke-LeanIXGraphQL -Query $query -Variables $variables
    return $response.allTagGroups.edges.node
}

Function Get-LXSubscriptionRoles {
    <#
        .SYNOPSIS
        Gets the subscription roles in LeanIX
    #>
$query = @"
{
  allSubscriptionRoles {
    edges {
      node {
        id
        name
      }
    }
  }
}
"@
    $response = Invoke-LeanIXGraphQL -Query $query
    return $response.allsubscriptionRoles.edges.node
}


Function Remove-LXSubscription {
    <#
        .SYNOPSIS
        Removes a subscription in LeanIX
    #>
    [CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true)]
	[String]$subscriptionId
	)
$query = @"
mutation {
  deleteSubscription(id: "$($subscriptionId)") {
    id
    name
  }
}
"@
    $response = Invoke-LeanIXGraphQL -Query $query
    return $response.allsubscriptionRoles.edges.node

    if ($response.deletesubscription.id) {
        Write-Verbose "`tSuccessfully removed subscription"
    } else {
        Write-Error "`tFailed to remove subscription with ID $subscriptionId"
    }
}

function New-LXSubscription {
    <#
        .SYNOPSIS
        Creates a subscription in LeanIX
    #>
    [CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true)]
	[String]$factSheetId,
	[Parameter(Mandatory=$true)]
	[String]$userId,
	[Parameter(Mandatory=$true)]
	[String]$subtype,
    [Parameter(Mandatory=$true)]
	[String[]]$roles
	)
    if ("OBSERVER","RESPONSIBLE" -notcontains $subtype) {
        write-error "Type must be one of OBSERVER, RESPONSIBLE"
        return
    }

    $subroles = ($roles | % { "`"$($_)`""}) -join ","

$query = @"
mutation {
  createSubscription(factSheetId: "$($factSheetId)", 
  user: {id: "$($userId)"}, 
  type: $($subtype), 
  roleIds: [$subroles]) {
    id
    user {
      id
      email
    }
    type
    roles {
      id
      name
    }
  }
}
"@
    $response = Invoke-LeanIXGraphQL -Query $Query

    if ($response.createsubscription.user.id -eq $userid) {
        Write-Verbose "`tSuccessfully created subscription"
    } else {
        Write-Error "`tFailed to create subscription for userid $($userid) on factsheet $($factsheetId) with roles $($subroles)"
    }
}


function Update-LXSubscription {
    <#
        .SYNOPSIS
        Updates a subscription in LeanIX
    #>
    [CmdletBinding()]
	Param(
	[Parameter(Mandatory=$true)]
	[String]$subscriptionId,
	[Parameter(Mandatory=$true)]
	[String]$userId,
	[Parameter(Mandatory=$true)]
	[String]$subtype,
    [Parameter(Mandatory=$true)]
	[String[]]$roles
	)
    if ("OBSERVER","RESPONSIBLE" -notcontains $subtype) {
        write-error "Type must be one of OBSERVER, RESPONSIBLE"
        return
    }

    $subroles = ($roles | % { "`"$($_)`""}) -join ","

$query = @"
mutation {
  updateSubscription(
    id: "$($subscriptionId)"
    user: {id: "$($userId)"}
    type: $($subtype)
    roleIds: [$($subroles)]) {
    id
    user {
      id
      email
    }
    type
    roles {
      id
      name
      comment
    }
  }
}
"@
    $response = Invoke-LeanIXGraphQL -Query $Query

    if ($response.UpdateSubscription.Id -eq $subscriptionId) {
        Write-Verbose "`tSuccessfully updated subscription"
    } else {
        Write-Error "`tFailed to update subscription $($subscriptionId) for userid $($userid) with roles $($subroles)"
    }
}

function Get-LXUsers {
    <#
        .SYNOPSIS
        Retrieves all users from LeanIX
    #>

    if (-not $global:LeanIXConnection) {
        Write-Error "You must connect to LeanIX first using Connect-LeanIX."
        return
    }

    if ( $Global:LeanIXConnection.LXTokenExpiry -lt (Get-Date) ) {
        Write-Error "LeanIX connection has expired. You must connect again via Connect-LeanIX"
        return
    }

    
    $page = 1
    $url = "$($global:LeanIXConnection.LXURL)/services/mtm/v1/workspaces/$($global:LeanIXConnection.LXWorkspaceID)/users?page=$($page)&size=100"
    $lxUsers = @()

    do {

        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $global:LeanIXConnection.LXHeaders -ContentType "application/json"
        $lxUsers += $response.data
    
        if ($response.data) {
            $page++
            $url = "$($global:LeanIXConnection.LXURL)/services/mtm/v1/workspaces/$($global:LeanIXConnection.LXWorkspaceID)/users?page=$($page)&size=100"
        } else {
            $url = $null
        }
    } while ($url)

    return $lxUsers

}
