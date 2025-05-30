#/bin/bash
# Passed validation in Cloud Shell on 10/29/2024
# Code blocks for ../container-instances/container-instances-nat-gateway-custom.sh
# <FullScript>
# Configure a NAT gateway for static IP address for outbound traffic from a container group
# set -e # exit if error
# Variable block
# <variable>
# Function to display usage
usage() {
    echo "Usage: $0 -resourcegroup <resourceGroup> -location <location>"
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -resourcegroup) resourceGroup="$2"; shift ;;
        -location) location="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Check if required arguments are provided
if [ -z "$resourceGroup" ] || [ -z "$location" ]; then
    usage
fi
# </variable>
# <creategroup>
# Check if resource group already exists
if az group show --name $resourceGroup &> /dev/null; then
    echo "Resource group $resourceGroup already exists."
else
    # Create resource group
    az group create --name $resourceGroup --location $location
fi
# </creategroup>
# <container>
az container create \
  --name appcontainer \
  --resource-group $resourceGroup \
  --image mcr.microsoft.com/azuredocs/aci-helloworld \
  --vnet aci-vnet \
  --vnet-address-prefix 10.0.0.0/16 \
  --subnet aci-subnet \
  --subnet-address-prefix 10.0.0.0/24
# </container>
# <publicip>
az network public-ip create \
  --name myPublicIP \
  --resource-group $resourceGroup \
  --sku standard \
  --zone 1 \
  --allocation static
# </publicip>
# <storeip>
ngPublicIp="$(az network public-ip show \
  --name myPublicIP \
  --resource-group $resourceGroup \
  --query ipAddress --output tsv)"
# </storeip>
# <natgateway>
az network nat gateway create \
  --resource-group $resourceGroup \
  --name myNATgateway \
  --public-ip-addresses myPublicIP \
  --idle-timeout 10
# </natgateway>
# <subnet>
az network vnet subnet update \
    --resource-group $resourceGroup  \
    --vnet-name aci-vnet \
    --name aci-subnet \
    --nat-gateway myNATgateway
# </subnet>
# <sidecar>
az container create \
  --resource-group $resourceGroup \
  --name testegress \
  --image mcr.microsoft.com/azuredocs/aci-helloworld \
  --command-line "curl -s http://checkip.dyndns.org" \
  --restart-policy OnFailure \
  --vnet aci-vnet \
  --subnet aci-subnet
# </sidecar>
# <viewlogs>
az container logs \
  --resource-group $resourceGroup \
  --name testegress
# </viewlogs>
# <echo>
echo $ngPublicIp
# </echo>
# </FullScript>

# echo "Deleting all resources"
# az group delete --name $resourceGroup -y
