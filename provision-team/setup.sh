#!/bin/bash

# set -euo pipefail
IFS=$'\n\t'

usage() { echo "Usage: setup.sh -i <subscriptionId> -l <resourceGroupLocation> -n <envName> -r <recipientEmail> -c <chatConnectionString> -q <chatMessageQueue> -u <azureUserName> -p <azurePassword> -j <bingAPIkey> -t <tenantId> -d <dbName>" 1>&2; exit 1; }
echo "$@"

declare subscriptionId=""
declare resourceGroupLocation=""
declare envName=""
declare azcliVerifiedVersion="2.0.43"
declare azureUserName=""
declare azurePassword=""
declare recipientEmail=""
declare chatConnectionString=""
declare chatMessageQueue=""
declare provisioningVMIpaddress=""
declare bingAPIkey=""
declare tenantId=""
declare appId=""
declare dbName=""

# Initialize parameters specified from command line
while getopts ":a:c:i:l:n:e:q:r:t:u:p:j:d:" arg; do
    case "${arg}" in
        a)
            appId=${OPTARG}
        ;;
        c)
            chatConnectionString=${OPTARG}
        ;;
        i)
            subscriptionId=${OPTARG}
        ;;
        l)
            resourceGroupLocation=${OPTARG}
        ;;
        n)
            envName=${OPTARG}
        ;;
        q)
            chatMessageQueue=${OPTARG}
        ;;
        r)
            recipientEmail=${OPTARG}
        ;;
        t)
            tenantId=${OPTARG}
        ;;
        u)
            azureUserName=${OPTARG}
        ;;
        p)
            azurePassword=${OPTARG}
        ;;
        j)
            bingAPIkey=${OPTARG}
        ;;
        d)
            dbName=${OPTARG}
        ;;
    esac
done
shift $((OPTIND-1))

# Check if kubectl is installed or that we can install it
type -p kubectl
if [ ! $? == 0 ]; then
    if [[ ! $EUID == 0 ]]; then
        echo "kubectl not found, install and re-run setup."
        exit 1
    fi
fi

type -p sqlcmd
if [ ! $? == 0 ]; then
    echo "sqlcmd not found, install and re-run setup."
    exit 1
fi

# Check if az is installed and that we can install it
#type -p az
#if [[ ! $? == 0 ]]; then
#    # is az is not present we need to install it
#    echo "The script need the az command line to be installed\n"
#    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest"
#    exit 1
#else
#    currentCliVersion=$(echo "$(az --version)" | sed -ne 's/azure-cli (\(.*\))/\1/p' )
#    if [ $currentCliVersion != $azcliVersion ]; then
#       echo "Error current az cli version $currentCliVersion does not match expected version $azcliVerifiedVersion"
#       exit 1
#    fi
#fi
#
##Prompt for parameters is some required parameters are missing
#if [[ -z "$subscriptionId" ]]; then
#    echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
#    echo "Enter your subscription ID:"
#    read subscriptionId
#    [[ "${subscriptionId:?}" ]]
#fi
#
#if [[ -z "$resourceGroupLocation" ]]; then
#    echo "If creating a *new* resource group, you need to set a location "
#    echo "You can lookup locations with the CLI using: az account list-locations "
#
#    echo "Enter resource group location:"
#    read resourceGroupLocation
#fi
#
#if [[ -z "$envName" ]]; then
#    echo "Enter a team name to be used in app provisioning:"
#    read envName
#fi
#
#if [ -z "$subscriptionId" ] || [ -z "$resourceGroupLocation" ] || [ -z "$envName" ] ; then
#    echo "Parameter missing..."
#    usage
#fi
#
randomChar() {
    s=abcdefghijklmnopqrstuvxwyz0123456789
    p=$(( $RANDOM % 36))
    echo -n ${s:$p:1}
}

randomNum() {
    echo -n $(( $RANDOM % 10 ))
}

randomCharUpper() {
    s=ABCDEFGHIJKLMNOPQRSTUVWXYZ
    p=$(( $RANDOM % 26))
    echo -n ${s:$p:1}
}

declare resourceGroupName="${envName}rg";
declare registryName="${envName}acr"
declare clusterName="${envName}aks"
declare keyVaultName="${envName}kv"
declare sqlServerName="${envName}sql"
declare sqlServerUsername="${envName}sa"
declare sqlServerPassword="$(randomChar;randomCharUpper;randomNum;randomChar;randomChar;randomNum;randomCharUpper;randomChar;randomNum)pwd"
#SQLDBName will need to reflect the necessary DB name for the MH Application
declare sqlDBName="${dbName}"
declare zipPassword=$(< /dev/urandom tr -dc '!@#$%_A-Z-a-z-0-9' | head -c${1:-32};echo;)

echo "=========================================="
echo " VARIABLES"
echo "=========================================="
echo "subscriptionId            = "${subscriptionId}
echo "resourceGroupLocation     = "${resourceGroupLocation}
echo "envName                   = "${envName}
echo "teamNumber                = "${teamNumber}
echo "keyVaultName              = "${keyVaultName}
echo "resourceGroupName         = "${resourceGroupName}
echo "registryName              = "${registryName}
echo "clusterName               = "${clusterName}
echo "sqlServerName             = "${sqlServerName}
echo "sqlServerUsername         = "${sqlServerUsername}
echo "sqlServerPassword         = "${sqlServerPassword}
echo "sqlDBName                 = "${sqlDBName}
echo "recipientEmail            = "${recipientEmail}
echo "chatConnectionString      = "${chatConnectionString}
echo "chatMessageQueue          = "${chatMessageQueue}
echo "zipPassword"              = "${zipPassword}"
echo "bingAPIkey"               = "${bingAPIkey}"
echo "tenantId"                 = "${tenantId}"
echo "AppId"                    = "${appId}"
echo "=========================================="

#login to azure using your credentials
echo "Username: $azureUserName"
echo "Password: $azurePassword"

if [[ -z "$tenantId" ]]; then
    echo "Command will be az login --username=$azureUserName --password=$azurePassword"
    az login --username=$azureUserName --password=$azurePassword
else
        echo "Command will be az login --username=$azureUserName --password=$azurePassword --tenant=$tenantId"
    az login  --service-principal --username=$azureUserName --password=$azurePassword --tenant=$tenantId
fi

#set the default subscription id
echo "Setting subscription to $subscriptionId..."

az account set --subscription $subscriptionId

declare tenantId=$(az account show -s ${subscriptionId} --query tenantId -o tsv)

#TODO need to check if provider is registered and if so don't run this command.  Also probably need to sleep a few minutes for this to finish.
echo "Registering ContainerServiceProvider..."
az provider register -n Microsoft.ContainerService

set +e

#Check for existing RG
if [ `az group exists -n $resourceGroupName -o tsv` == false ]; then
    echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
    set -e
    (
        set -x
        az group create --name $resourceGroupName --location $resourceGroupLocation
    )
else
    echo "Using existing resource group..."
fi

# Verify that the devopsConfig dir exist
if [ ! -d "/home/azureuser/devops_env" ]; then
   mkdir /home/azureuser/devops_env
fi

# Verify that kvstore dir exist
if [ ! -d "/home/azureuser/devops_env/kvstore" ]; then
   mkdir /home/azureuser/devops_env/kvstore
fi

# Verify that the devops dir exist
if [ ! -d "/home/azureuser/devops_env/${envName}${teamNumber}" ]; then
   mkdir /home/azureuser/devops_env/${envName}${teamNumber}
fi

kvstore set ${envName}${teamNumber} subscriptionId ${subscriptionId}
kvstore set ${envName}${teamNumber} tenantId ${tenantId}
kvstore set ${envName}${teamNumber} resourceGroupLocation ${resourceGroupLocation}
kvstore set ${envName}${teamNumber} teamNumber ${teamNumber}
kvstore set ${envName}${teamNumber} keyVaultName ${keyVaultName}
kvstore set ${envName}${teamNumber} resourceGroup ${resourceGroupName}
kvstore set ${envName}${teamNumber} ACR ${registryName}
kvstore set ${envName}${teamNumber} AKS ${clusterName}
kvstore set ${envName}${teamNumber} sqlServerName ${sqlServerName}
kvstore set ${envName}${teamNumber} sqlServerUserName ${sqlServerUsername}
kvstore set ${envName}${teamNumber} sqlServerPassword ${sqlServerPassword}
kvstore set ${envName}${teamNumber} sqlDbName ${sqlDBName}
kvstore set ${envName}${teamNumber} teamFiles /home/azureuser/team_env/${envName}${teamNumber}


az configure --defaults 'output=json'
#Done
echo "0-Provision KeyVault  (bash ./provision_kv.sh -i $subscriptionId -g $resourceGroupName -k $keyVaultName -l $resourceGroupLocation)"
bash ./provision_kv.sh -i $subscriptionId -g $resourceGroupName -k $keyVaultName -l $resourceGroupLocation
#Done
echo "1-Provision ACR  (bash ./provision_acr.sh -i $subscriptionId -g $resourceGroupName -r $registryName -l $resourceGroupLocation)"
bash ./provision_acr.sh -i $subscriptionId -g $resourceGroupName -r $registryName -l $resourceGroupLocation
#Done
echo "2-Provision AKS  (bash ./provision_aks.sh -i $subscriptionId -g $resourceGroupName -c $clusterName -l $resourceGroupLocation)"
bash ./provision_aks.sh -i $subscriptionId -g $resourceGroupName -c $clusterName -l $resourceGroupLocation -a $appId -n $azureUserName -p $azurePassword

echo "5-Clone repo"
bash ./git_fetch.sh -u https://github.com/Kalabric/DevSecOpsEnvironment -s ./test_fetch_build

echo "6-Deploy ingress  (bash ./deploy_ingress_dns.sh -s ./test_fetch_build -l $resourceGroupLocation -n ${envName}${teamNumber})"
bash ./deploy_ingress_dns.sh -s ./test_fetch_build -l $resourceGroupLocation -n ${envName}${teamNumber}

echo "7-Provision SQL (bash ./provision_sql.sh -s ./test_fetch_build -g $resourceGroupName -l $resourceGroupLocation -q $sqlServerName -k $keyVaultName -u $sqlServerUsername -p $sqlServerPassword -d $sqlDBName)"
bash ./provision_sql.sh -g $resourceGroupName -l $resourceGroupLocation -q $sqlServerName -k $keyVaultName -u $sqlServerUsername -p $sqlServerPassword -d $sqlDBName

echo "8-Configure SQL  (bash ./configure_sql.sh -s ./test_fetch_build -g $resourceGroupName -u $sqlServerUsername -n ${envName}${teamNumber} -k $keyVaultName -d $sqlDBName)"
bash ./configure_sql.sh -s ./test_fetch_build -g $resourceGroupName -u $sqlServerUsername -n ${envName}${teamNumber} -k $keyVaultName -d $sqlDBName

# Save the public DNS address to be provisioned in the helm charts for each service
dnsURL='akstraefik'${envName}${teamNumber}'.'$resourceGroupLocation'.cloudapp.azure.com'
echo -e "DNS URL for "${envName}" is:\n"$dnsURL

kvstore set ${envName}${teamNumber} endpoint ${dnsURL}

echo "9-Build and deploy POI API to AKS  (bash ./build_deploy_poi.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-poi' -d $dnsURL -n ${envName}${teamNumber} -g $registryName)"
bash ./build_deploy_poi.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-poi' -d $dnsURL -n ${envName}${teamNumber} -g $registryName

echo "10-Build and deploy User API to AKS  (bash ./build_deploy_user.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-user' -d $dnsURL -n ${envName}${teamNumber} -g $registryName)"
bash ./build_deploy_user.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-user' -d $dnsURL -n ${envName}${teamNumber} -g $registryName

echo "11-Build and deploy Trip API to AKS  (# bash ./build_deploy_trip.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-trip' -d $dnsURL -n ${envName}${teamNumber} -g $registryName)"
bash ./build_deploy_trip.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-trip' -d $dnsURL -n ${envName}${teamNumber} -g $registryName

echo "12-Build and deploy User-Profile API to AKS  (# bash ./build_deploy_user-profile.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-userprofile' -d $dnsURL -n ${envName}${teamNumber} -g $registryName)"
bash ./build_deploy_user-java.sh -s ./test_fetch_build -b Release -r $resourceGroupName -t 'api-user-java' -d $dnsURL -n ${envName}${teamNumber} -g $registryName

echo "16-Check services (# bash ./service_check.sh -d ${dnsURL} -n ${envName}${teamNumber})"
bash ./service_check.sh -d ${dnsURL} -n ${envName}${teamNumber}

echo "17-Clean the working environment"
bash ./cleanup_environment.sh -t ${envName}${teamNumber} -p $zipPassword

echo "18-Expose the team settings on a website"
bash ./run_nginx.sh

#This line is not valid when using a self-provisioning.
if [ "${chatConnectionString}" == "null" ] && [ "${chatMessageQueue}" == "null" ]; then
    echo "OpenHack credentials are here: http://$provisioningVMIpaddress:2018/teamfiles.zip with zip password $zipPassword"
else
    echo "19-Send Message home"
    provisioningVMIpaddress=$(az vm list-ip-addresses --resource-group=ProctorVMRG --name=proctorVM --query "[].virtualMachine.network.publicIpAddresses[].ipAddress" -otsv)
    echo -e "IP Address of the provisioning VM is $provisioningVMIpaddress"
    bash ./send_msg.sh -n  -e $recipientEmail -c $chatConnectionString -q $chatMessageQueue -m "OpenHack credentials are here: http://$provisioningVMIpaddress:2018/teamfiles.zip with zip password $zipPassword"
fi

echo "############ END OF TEAM PROVISION ############"
