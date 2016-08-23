<#
.SYNOPSIS
Accesses the NSXREST API

.DESCRIPTION
See:
TODO
 
#>

[string]$nsxAPIuri = $null
[string]$nsxbase64Auth = $null
[bool]$nsxConnected = $false

# fixes SSL trust issues uncomment if you do not have signed certs
#
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
# end SSL trust fix


<#
.SYNOPSIS
Disconnects from NSX Rest services, supplied by the NSX module

.DESCRIPTION
Disconnects from NSX Rest services and blanks all connection variables

.EXAMPLE
Disconnect-NSXREST

.LINK
https://united.earth/nsxrest/Disconnect-NSXREST

#>
function Disconnect-NSXREST {
	if ($script:nsxConnected)
	{
		$script:nsxbase64Auth = $null
		$script:nsxAPIuri = $null
		$script:nsxConnected = $false
		return $true
	}
	return $false
}
<#
.SYNOPSIS
Get's the state of the current NSX Rest connection, supplied by the NSX module

.DESCRIPTION
Get's the state of the current NSX Rest connection

.EXAMPLE
Get-NSXREST

.LINK
https://united.earth/nsxrest/Get-NSXREST

#>
function Get-NSXREST {
	if ($script:nsxConnected)
	{
		"Connected to $($script:nsxAPIuri)"
	} else
	{
		"Not connected"
	}
}
<#
.SYNOPSIS
Connects you to the NSX REST API, supplied by the NSX module

.DESCRIPTION
Connects you to the NSX REST API, supply Uri, Username, Password

.EXAMPLE
Connect-NSXREST https://nsxmanager admin default
Connect-NSXREST -uri https://nsxmanager -Username admin -Password default


.LINK
https://united.earth/nsxrest/Connect-NSXREST

#>
Function Connect-NSXREST {
	param(
	       [Parameter(Mandatory=$true)][string] $uri,
	       [Parameter(Mandatory=$true)][string] $Username,
	       [Parameter(Mandatory=$true)][string] $Password
	     )

	$con = $null

	if ($script:nsxConnected) 
	{
		"Already connected to $($script:nsxAPIuri)"
		return $false
	}



	$script:nsxbase64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
	$script:nsxAPIuri = $uri

	$apipath = "/api/versions"
	
	$fullpath = "$($script:nsxAPIuri)$($apipath)"

	try {
 		$result = Invoke-RestMethod -Uri $fullpath -ContentType "application/xml"  -Method GET -Headers  @{Authorization=("Basic {0}" -f $script:nsxbase64Auth)}
	} catch {
		$result = $_.Exception.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($result)
   		$responseBody = $reader.ReadToEnd();
	}
	if (!$result.versions) 
	{
		$script:nsxConnected=$false
		return $false
	}

	if ($con -eq $false) 
	{
		return $false
	} else 
	{
		$script:nsxConnected=$true
	}
	return $script:nsxConnected
}
<#
.SYNOPSIS
Internal Invoke-NSXRestMethod, supplied by the NSX module

.DESCRIPTION
Connects you to the NSX REST API, supply Uri, internally used by the module
Returns raw XML variables

.EXAMPLE
Invoke-NSXRESTMethod -uri https://nsxmanager 

.LINK
https://united.earth/nsxrest/Invoke-NSXRestMethod

#>
function Invoke-NSXRestMethod()
{
	param([Parameter(Mandatory=$true)][string]$uri,$method="GET",$body=$null)

	if ($script:nsxConnected -eq $false -Or $bypass) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}


	try {
		if ($body -eq $null)
		{
 			$result = Invoke-RestMethod -Uri $uri -ContentType "application/xml"  -Method $method -Headers  @{Authorization=("Basic {0}" -f $script:nsxbase64Auth)}
	       	}else{
			$result = Invoke-RestMethod -Uri $uri -ContentType "application/xml" -Body $body -Method $method -Headers  @{Authorization=("Basic {0}" -f $script:nsxbase64Auth)}
		}
			
	} catch {
		$result = $_.Exception.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($result)
   		$responseBody = $reader.ReadToEnd();
	}
	return $result
}

function New-NSXLDRInterface()
{
	param([Parameter(Mandatory=$true)][string]$edgeid,[Parameter(Mandatory=$true)][string]$iname,[Parameter(Mandatory=$true)][string]$ip,[Parameter(Mandatory=$true)][string]$dvpg,$subnet="255.255.255.0",$itype="internal",$mtu="1500",$isConnected="true")

	
#attach edge
$xml="<interfaces>
   <interface>
      <name>$($iname)</name>
      <addressGroups>
         <addressGroup>
            <primaryAddress>$($ip)</primaryAddress>
            <subnetMask>$($subnet)</subnetMask>
         </addressGroup>
      </addressGroups>
      <mtu>$($mtu)</mtu>
      <type>$($itype)</type>
      <isConnected>$($isConnected)</isConnected>
      <connectedToId>$($dvpg)</connectedToId>
   </interface>
</interfaces>"

	$apipath = "/api/4.0/edges/$($edgeid)/interfaces/?action=patch"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod $fullpath "POST" $xml

}

function New-NSXLogicalSwitch()
{
	param([Parameter(Mandatory=$true)][string]$lsname,[Parameter(Mandatory=$true)][string]$vdnscopeid,$tenantid="default")

	Get-NSXVDNScopes | Where {$_.objectid -like $vdnscopeid} | %{ $cpMode = $_.controlPlaneMode }

	$body = "<virtualWireCreateSpec><name>"
	$body += $lsname
	$body += "</name><description>"
	$body += $lsname
	$body += "</description>"
	$body += "<tenantId>"
	$body += $tenantid
	$body += "</tenantId>"
	$body +="<controlPlaneMode>"
	$body += $cpMode
	$body +="</controlPlaneMode><guestVlanAllowed>false</guestVlanAllowed></virtualWireCreateSpec>"

	$apipath = "/api/2.0/vdn/scopes/$($vdnscopeid)/virtualwires"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"

#$body
#	$fullpath
	$result = Invoke-NSXRestMethod $fullpath "POST" $body
	
#<virtualWireCreateSpec> 
#<name>
#LS_vlan_tagging
#</name> 
#<description>
#For guest VLAN tagging
#</description> 
#<tenantId>
#virtual wire tenant
#</tenantId> 
#<controlPlaneMode>UNICAST_MODE</controlPlaneMode>   <!-- Optional. Default is the 
#value specified for the transport zone. -->
#<guestVlanAllowed>true</guestVlanAllowed>
#</virtualWireCreateSpec>
	$pgInfo=Get-NSXLogicalSwitches $vdnscopeid 100 0 $true
	if ($pgInfo.totalCount -gt 100) 
	{
		$vwire=$null;
		$pages = [math]::ceiling( $pgInfo.totalCount / 100 )

		for($i=0;$i -lt $pages; $i+=1)
		{
			Get-NSXLogicalSwitches $vdnscopeid 100 $i | Where {$_.name -eq $lsname} | % { $vwire = $_.objectId }
		if ($vwire -ne $null) {break}
		}

	}else{
		Get-NSXLogicalSwitches $vdnscopeid | Where {$_.name -eq $lsname} | % { $vwire = $_.objectId } 
	}
	return $vwire
}

function Get-NSXLogicalSwitches()
{
	param([Parameter(Mandatory=$true)][string]$vdnscopeid,$pageSize=100,$startIndex=0,$pageInfo=$false)

	$apipath = "/api/2.0/vdn/scopes/$($vdnscopeid)/virtualwires?pagesize=$($pageSize)&startIndex=$($startIndex)"
	$fullpath = "$($script:nsxAPIuri)$($apipath)"

	$result = Invoke-NSXRestMethod($fullpath)

##$result

	if ($pageInfo -eq $true)
	{
		return $result.virtualWires.dataPage.pagingInfo
	}

	return $result.virtualWires.dataPage.virtualWire
}

<#
.SYNOPSIS
Get-NSXEdgeListView returns a list of Edge and LDR services, supplied by the NSX module

.DESCRIPTION
Get-NSXEdgeListView returns a list of Edge and LDR services and edge page information

.EXAMPLE
Get-NSXEdgeListView 30 0 $true
Get-NSXEdgeListView -pageSize 10 -startIndex 20
Get-NSXEdgeListView -pageInfo $true


.LINK
https://united.earth/nsxrest/Get-NSXEdgeListView

#>
function Get-NSXEdgeListView()
{
	param($pageSize=30,$startIndex=0,$pageInfo=$false,$datacenter=$null,$tenantId=$null,$pg=$null)
	

	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/4.0/edges?pageSize=$($pageSize)&startIndex=$($startIndex)"

	if ($datacenter -ne $null) 
	{
		$apipath="$($apipath)&datacenter=$($datacenter)"
	}
	if ($tenantId -ne $null) 
	{
		$apipath="$($apipath)&tenantId=$($tenantId)"
	}
	if ($pg -ne $null) 
	{
		$apipath="$($apipath)&pg=$($pg)"
	}


	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	

	$result = Invoke-NSXRestMethod($fullpath)

	if ($pageInfo)
	{
		$result.pagedEdgeList.edgePage.pagingInfo | FT -AutoSize
	}	

	$result.pagedEdgeList.edgePage.edgeSummary | Select-Object  objectId,name,edgeType,@{N="size";E={@($_.appliancesSummary.applianceSize)}},state,edgeStatus,@{N="activeVM";E={@($_.appliancesSummary.vmNameOfActiveVse)}},@{N="activeHost";E={@($_.appliancesSummary.hostNameOfActiveVse)}},@{N="activeDS";E={@($_.appliancesSummary.dataStoreNameOfActiveVse)}} | FT -AutoSize

}
<#
.SYNOPSIS
Get-NSXEdges returns all edge Objects, supplied by the NSX module

.DESCRIPTION
Get-NSXEdges returns all edge Objects or edge page information

.EXAMPLE
Get-NSXEdges 30 0 
Get-NSXEdges -pageSize 10 -startIndex 20
Get-NSXEdges -pageInfo $true


.LINK
https://united.earth/nsxrest/Get-NSXEdges

#>
function Get-NSXEdges()
{
	param($pageSize=30,$startIndex=0,$pageInfo=$false,$datacenter=$null,$tenantId=$null,$pg=$null)
	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}
	$apipath = "/api/4.0/edges?pageSize=$($pageSize)&startIndex=$($startIndex)"
	if ($datacenter -ne $null) 
	{
		$apipath="$($apipath)&datacenter=$($datacenter)"
	}
	if ($tenantId -ne $null) 
	{
		$apipath="$($apipath)&tenantId=$($tenantId)"
	}
	if ($pg -ne $null) 
	{
		$apipath="$($apipath)&pg=$($pg)"
	}
	$fullpath = "$($script:nsxAPIuri)$($apipath)"


	$result = Invoke-NSXRestMethod($fullpath)


	if ($pageInfo)
	{	
		return $result.pagedEdgeList.edgePage.pagingInfo 
	}

	return $result.pagedEdgeList.edgePage.edgeSummary 
}

<#
.SYNOPSIS
Get-NSXEdge returns an edge Object, supplied by the NSX module

.DESCRIPTION
Get-NSXEdge returns an edge Object

.EXAMPLE
Get-NSXEdges edge-1

.LINK
https://united.earth/nsxrest/Get-NSXEdge

#>
function Get-NSXEdge()
{
	param(
		[Parameter(Mandatory=$true)][string] $edgeId
	     )

	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/4.0/edges/$($edgeId)"
	
	$fullpath = "$($script:nsxAPIuri)$($apipath)"


	$result = Invoke-NSXRestMethod($fullpath)


if (!$result.edge)
{
 	return $false
}

	if ($result.edge.id -ne $edgeId) 
{
	return $false
}

	return $result.edge
}
<#
.SYNOPSIS
Get-NSXControllers returns controller objects, supplied by the NSX module

.DESCRIPTION
Get-NSXControllers returns all controllers as objects in an array

.EXAMPLE
Get-NSXControllers 

.LINK
https://united.earth/nsxrest/Get-NSXControllers

#>
function Get-NSXControllers()
{
	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/2.0/vdn/controller"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod($fullpath)

	if (!$result.controllers)
	{
		return $false
	}

	return $result.controllers.controller

}
<#
.SYNOPSIS
Get-NSXVDNScopes returns vdn scopes, supplied by the NSX module

.DESCRIPTION
Get-NSXVDNScopes returns vdn scopes as an array

.EXAMPLE
Get-NSXVDNScopes

.LINK
https://united.earth/nsxrest/Get-NSXVDNScopes

#>
function Get-NSXVDNScopes()
{
	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/2.0/vdn/scopes"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod($fullpath)

	if (!$result.vdnScopes)
	{
		return $false
	}

	return $result.vdnScopes.vdnScope

}

<#
.SYNOPSIS
Get-NSXVDNScope returns vdn scopes, supplied by the NSX module

.DESCRIPTION
Get-NSXVDNScope returns vdn scopes as an array

.EXAMPLE
Get-NSXVDNScope vdnscope-1

.LINK
https://united.earth/nsxrest/Get-NSXVDNScope

#>
function Get-NSXVDNScope()
{

	param(		[Parameter(Mandatory=$true)][string] $scopeId )

	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/2.0/vdn/scopes/$($scopeId)"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod($fullpath)

	if (!$result.vdnScope)
	{
		return $false
	}

	return $result.vdnScope

}

<#
.SYNOPSIS
Get-NSXFabricFeatures returns network fabric features, supplied by the NSX module

.DESCRIPTION
Get-NSXFabricFeatures returns network fabric features as an array

.EXAMPLE
Get-NSXFabricFeatures

.LINK
https://united.earth/nsxrest/Get-NSXFabricFeatures

#>
function Get-NSXFabricFeatures()
{
	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/2.0/nwfabric/features"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod($fullpath)

	if (!$result.featureInfos)
	{
		return $false
	}

	return $result.featureInfos.featureInfo
}
<#
.SYNOPSIS
Get-NSXResFeatures returns resource features, supplied by the NSX module

.DESCRIPTION
Get-NSXResFeatures returns resource features as an array

.EXAMPLE
Get-NSXResFeatures resource-id

.LINK
https://united.earth/nsxrest/Get-NSXResFeatures

#>
function Get-NSXResFeatures()
{
	param ([Parameter(Mandatory=$true)][string] $resourceId)

	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/2.0/nwfabric/status?resource=$($resourceId)"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod($fullpath)

	if (!$result.resourceStatuses)
	{
		return $false
	}

	return $result.resourceStatuses.resourceStatus
}

<#
.SYNOPSIS
Get-NSXVCConfig returns vcenter configuratio, supplied by the NSX module

.DESCRIPTION
Get-NSXVCConfig returns  vcenter configuratio

.EXAMPLE
Get-NSXVCConfig

.LINK
https://united.earth/nsxrest/Get-NSXVCConfig

#>
function Get-NSXVCConfig()
{
	
	if (!$script:nsxConnected) 
	{
		"You are not connected, please run Connect-NSXREST"
		return $false
	}

	$apipath = "/api/2.0/services/vcconfig"

	$fullpath = "$($script:nsxAPIuri)$($apipath)"
	
	$result = Invoke-NSXRestMethod($fullpath)

	if (!$result.vcInfo)
	{
		return $false
	}

	return $result.vcInfo
}
