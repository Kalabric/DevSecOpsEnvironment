
# ********************************************************************
# * Script run by the Custom Script Extension on the provisioning VM *
# ********************************************************************
# Set Azure Credentials by reading the command line arguments

AZUREUSERNAME=$1
AZUREPASSWORD=$2
SUBID=$3
LOCATION=$4
DEVSECOPSENVNAME=$5
RECIPIENTEMAIL=$6
CHATCONNECTIONSTRING=$7
CHATMESSAGEQUEUE=$8
TENANTID=$9
APPID=${10}
#GITBRANCH=

echo "############### Adding package respositories ###############"
# Get the Microsoft signing key 
curl -L https://packages.microsoft.com/keys/microsoft.asc 2>&1 | sudo apt-key add -

# Get the Docker GPG key 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg 2>&1 | sudo apt-key add -
# sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893

# Azure-cli
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ xenial main"
# Dotnet SDK v2.1
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main"
# Add MSSQL source 
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/ubuntu/16.04/prod xenial main"
# Add Docker source
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable"

echo "############### Installing Helm v2.12.2 ###############"
sudo curl -s -O https://storage.googleapis.com/kubernetes-helm/helm-v2.12.2-linux-amd64.tar.gz
sudo tar -zxvf helm-v2.12.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

echo "############### Installing kubectl ###############"
curl -s -LO https://storage.googleapis.com/kubernetes-release/release/v1.11.7/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

echo "############### Installing Packages ###############" 

sudo DEBIAN_FRONTEND=noninteractive apt-get update 
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dotnet-sdk-2.2 jq git zip azure-cli=2.0.49-1~xenial
sudo DEBIAN_FRONTEND=noninteractive ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce

touch /home/azureuser/.bashrc
echo 'export PATH=$PATH:/opt/mssql-tools/bin' >> /home/azureuser/.bashrc

echo "############### Pulling DevSecOpsEnvironment-tools from Github ###############"
sudo git clone https://github.com/Kalabric/DevSecOpsEnvironment.git /home/azureuser/DevSecOpsEnvironment
sudo chown azureuser:azureuser -R //home/azureuser/MHDevSecOpsEnv/.

echo "############### Install kvstore ###############"
sudo install -b /home/azureuser/MHDevSecOpsEnv/provision-DevSecOpsEnvironment/kvstore.sh /usr/local/bin/kvstore
echo 'export KVSTORE_DIR=/home/azureuser/DevSecOpsEnvironment/kvstore' >> /home/azureuser/.bashrc

echo azure-cli hold | sudo dpkg --set-selections

#Add user to docker usergroup
sudo usermod -aG docker azureuser

#Holding walinuxagent before upgrade
sudo apt-mark hold walinuxagent
sudo apt-get upgrade -y

#Set environement variables
export PATH=$PATH:/opt/mssql-tools/bin
export KVSTORE_DIR=/home/azureuser/DevSecOpsEnvironment/kvstore

cd /home/azureuser/DevSecOpsEnvironment/provision

echo "############### Azure credentials ###############"
echo "UserName: $AZUREUSERNAME"
echo "Password: $AZUREPASSWORD"
echo "Subscription ID: $SUBID"
echo "Location: $LOCATION"
echo "DevOps EnvName: $DEVSECOPSENVNAME"
echo "Recipient email: $RECIPIENTEMAIL"
echo "ChatConnectionString= $CHATCONNECTIONSTRING"
echo "ChatConnectionQueue= $CHATMESSAGEQUEUE"
echo "Tenant is $TENANTID"
echo "AppId is $APPID"

# Running the provisioning of the DevOps environment

if [[ -z "$TENANTID" ]]; then
    az login --username=$AZUREUSERNAME --password=$AZUREPASSWORD
else
    az login --service-principal --username=$AZUREUSERNAME --password=$AZUREPASSWORD --tenant=$TENANTID
fi 


# Launching the DevOps provisioning in background
sudo PATH=$PATH:/opt/mssql-tools/bin KVSTORE_DIR=/home/azureuser/DevSecOpsEnvironment/kvstore nohup ./setup.sh -i $SUBID -l $LOCATION -n $DEVSECOPSENVNAME -u "$AZUREUSERNAME" -p "$AZUREPASSWORD" -r "$RECIPIENTEMAIL" -c "$CHATCONNECTIONSTRING" -q "$CHATMESSAGEQUEUE" -t "$TENANTID" -a "$APPID">teamdeploy.out &

echo "############### End of custom script ###############"
