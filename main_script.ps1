# Install the Az module if you haven't already and connect to your Azure account.
# Install-Module -Name Az
Connect-AzAccount

# Check whether the signed in user is assigned the Owner or Administrator role.
Get-AzRoleAssignment | Select-Object RoleDefinitionName

# Check whether you are registered to be an Azure resource provider, and do so if you are not.
$registrationStates = Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization | Select-Object RegistrationState
if (-Not $registrationStates[0] -match 'Registered') { (Register-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization) }

# Overview of already existing resource groups and resources.
Get-AzResourceGroup
Get-AzResource -ExpandProperties

# Start by creating a new resource group.
New-AzResourceGroup -Name $RG -Location $Location

# Define subnet properties and deploy the virtual network.
$fesub = New-AzVirtualNetworkSubnetConfig -Name "FrontEndSubnet" -AddressPrefix "10.1.0.0/24"
$gwsub = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix "10.1.255.0/27"
New-AzVirtualNetwork `
   -ResourceGroupName "myRG" `
   -Location "westeurope" `
   -Name "myVNet" `
   -AddressPrefix "10.1.0.0/16" `
   -Subnet $fesub, $gwsub `

# Get a dynamic public IP address for the virtual network gateway and set configurations for subsequent creation.
$vnet = Get-AzVirtualNetwork -Name 'myVNet' -ResourceGroupName 'myRG'
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
$pip = New-AzPublicIpAddress -Name 'myVNetGWpip' -ResourceGroupName 'myRG' -Location 'westeurope' -AllocationMethod Dynamic
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name "gwipconf" -Subnet $subnet -PublicIpAddress $pip

# Create the virtual network gateway. This will take approximately 45 minutes.
New-AzVirtualNetworkGateway -Name 'myVNetGW' -ResourceGroupName 'myRG' `
-Location 'westeurope' -IpConfigurations $ipconf -GatewayType Vpn `
-VpnType RouteBased -EnableBgp $false -GatewaySku VpnGw1 -VpnClientProtocol "IKEv2",'SSTP'

# Set the VPN Client Address pool for the virtual network gateway. 
# Note that this only works with PowerShell 7.2 or earlier versions of PowerShell 7.
# As of November 16th 2022 there have still been issues with PowerShell 7.3.
$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName myRG -Name myVNetGW
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway -VpnClientAddressPool "172.16.201.0/24"

# Generate a root certificate. This can only be done by an admin in a PowerShell session.
# The session should stay active for the next part, where the client certificate is generated.
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

# Generate a client certificate.
New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" `
-Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# After generating both certificates, it is necessary to export the public key of the root certificates 
# to later upload it to Azure. Follow the instructions here: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#cer
# Upload the root certificate's public key to Azure.
$P2SRootCertName = "P2SRootCert1.cer"
$filePathForCert = "C:\Users\IWA-JUN-11\Documents\pwsh_project\P2SRootCert1.cer"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($filePathForCert)
$CertBase64 = [system.convert]::ToBase64String($cert.RawData)
Add-AzVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName -VirtualNetworkGatewayname "myVNetGW" -ResourceGroupName "myRG" -PublicCertData $CertBase64

# Finally, create a client configuration package, follow the link in $profile.VPNProfileSASUrl to download the ZIP file,
# and configure your VPN client by opening the file that matches your operating system.
$profile = New-AzVpnClientConfiguration -ResourceGroupName 'myRG' -Name 'myVNetGW' -AuthenticationMethod "EapTls"
$profile.VPNProfileSASUrl

# Create a VM.
Get-AzureRmMarketplaceTerms -Publisher ntegralinc1586961136942 -Product ntg_ubuntu_22_04_daas -Name ntg_ubuntu_22_04_daas `
 | Set-AzureRmMarketplaceTerms -Accept
(Get-AzSshKey -ResourceGroupName myRG -Name myVM_key).PublicKey
New-AzResourceGroupDeployment -ResourceGroupName myRG -TemplateFile .\main.bicep

(Get-AzNetworkInterface).IpConfigurations | Select-Object -ExpandProperty PrivateIpAddress

Invoke-AzVMRunCommand -ResourceGroupName 'myRG' -Name 'myVM' -CommandId 'RunShellScript' -ScriptPath '.\ref_script.ps1'














# Create new VM in the 'myRG' resource group.
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
Get-Module Selenium
$Driver = Start-SeFirefox
Enter-SeUrl https://www.vbs.admin.ch -Driver $Driver