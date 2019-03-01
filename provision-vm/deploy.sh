#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)
# This is an optionianal file. Only used if you would like to perform the VM deployment through bash instead of through Azure CLI
# This script does not take into account the creation of the SP
# Using these commands:
# Login to the azure subscription using your credentials
# az login --username='<AzureUserName>' --password='<AzurePassword>'
# Create a service principal with the role owner in your subscription
# az ad sp create-for-rbac -n "DevOpsSP" --role owner
# Take note of the following: appId password tenant
# Create new resource group
# az group create --name='DevOpsVMRG' --location='<Location>'
# Run the deployment in that resource group using the values from the service principal created in step 2.
# az group deployment create --resource-group='DevOpsVMRG' --template-file ./azuredeploy.json --parameters spUserName=http://DevOpsSP spPassword='<password>' spTenant='<tenant>' spAppId='<appId>
# This is also outlined in the Readme.md

usage() { echo "Usage: deploy.sh -l <location> -n <number> -k <publickey>" 1>&2; exit 1; }

declare publickey=""
declare location=""
declare number=""

# Initialize parameters specified from command line
while getopts ":k:l:n:" arg; do
    case "${arg}" in
        k)
            publickey=${OPTARG}
        ;;
        l)
            location=${OPTARG}
        ;;
        n)
            number=${OPTARG}
        ;;
    esac
done
shift $((OPTIND-1))

if [[ -z "$publickey" ]]; then
    echo "Please specify a public key value"
    read publickey
fi

if [[ -z "$location" ]]; then
    echo "Enter a location"
    read location
    [[ "${location:?}" ]]
fi

randomChar() {
    s=abcdefghijklmnopqrstuvxwyz0123456789
    p=$(( $RANDOM % 36))
    echo -n ${s:$p:1}
}

randomNum() {
    echo -n $(( $RANDOM % 10 ))
}

if [[ -z "$number" ]]; then
    echo "Using a random proctor number since not specified."
    number="$(randomChar;randomChar;randomChar;randomNum;)"
fi

AdminUser="azureuser"
proctorDNSName="procohvm${number}"
resourceGroupName="ProctorVM${number}"

#Check for existing RG
if [ `az group exists -n $resourceGroupName -o tsv` == false ]; then
    echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
    set -e
    (
        set -x
        az group create --name $resourceGroupName --location $location
    )
else
    echo "Using existing resource group..."
fi

echo "Deploying Proctor Virtual Machine..."

az group deployment create \
    --name "${resourceGroupName}deployment" \
    --resource-group $resourceGroupName \
    --template-file azuredeploy.json \
    --parameters adminUsername=$AdminUser dnsNameForPublicIP=$proctorDNSName sshKeyData="$publickey"
