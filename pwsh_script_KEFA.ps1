Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
Import-Module -Name Az
Connect-AzAccount

# Check whether the signed in user is assigned the Owner or Administrator role.
Get-AzRoleAssignment | Select-Object RoleDefinitionName

# Check whether you are registered to be an Azure resource provider, and do so if you are not.
$registrationStates = Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization | Select-Object RegistrationState
if (-Not $registrationStates[0] -match 'Registered') { (Register-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization) }

# Overview of already existing resources.
Get-AzResourceGroup
Get-AzResource -ExpandProperties

$VPNClientAddressPool = "172.16.201.0/24"
$GWName = "myVNetGW"
$GWIPName = "myVNetGWpip"
$GWIPconfName = "gwipconf"

# Start by creating a new resource group.
New-AzResourceGroup -Name $RG -Location $Location

# Define subnet properties.
$fesub = New-AzVirtualNetworkSubnetConfig -Name "FrontEndSubnet" -AddressPrefix "10.1.0.0/24"
$gwsub = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix "10.1.255.0/27"

New-AzVirtualNetwork `
   -ResourceGroupName "myRG" `
   -Location "westeurope" `
   -Name "myVNet" `
   -AddressPrefix "10.1.0.0/16" `
   -Subnet $fesub, $gwsub `

# Define variables for subsequent use based on the 'myVNet' virtual network.
$vnet = Get-AzVirtualNetwork -Name 'myVNet' -ResourceGroupName 'myRG'
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet

# Get a dynamic public IP address for the virtual network gateway and set configurations for subsequent creation.
$pip = New-AzPublicIpAddress -Name 'myVNetGWpip' -ResourceGroupName 'myRG' -Location 'westeurope' -AllocationMethod Dynamic
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name "gwipconf" -Subnet $subnet -PublicIpAddress $pip

New-AzVirtualNetworkGateway -Name 'myVNetGW' -ResourceGroupName 'myRG' `
-Location 'westeurope' -IpConfigurations $ipconf -GatewayType Vpn `
-VpnType RouteBased -EnableBgp $false -GatewaySku VpnGw1 -VpnClientProtocol "IKEv2",'SSTP'






$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

$vmParams = @{
    ResourceGroupName = 'myRG-I9B42Z9NGD'
    Name = 'TestVM1'
    Location = 'eastus'
    ImageName = 'Win2016Datacenter'
    PublicIpAddressName = 'TestPublicIp'
    Credential = $cred
    OpenPorts = 3389
  }


# Set system-wide dark mode.
$registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty -Path $registryPath -Name AppsUseLightTheme -Value 0 -Type Dword -Force

$ie = New-Object -ComObject 'Edge.Application'

Install-Module Selenium -Scope CurrentUser
$Driver = Start-SeFirefox
Enter-SeUrl https://www.vbs.admin.ch -Driver $Driver