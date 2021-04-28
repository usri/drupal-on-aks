# Create a resource group for the Drupal workload
echo "Creating resource group '$RG_NAME' in region '$LOCATION'."
az group create --name $RG_NAME --location $LOCATION --output none

# Create an AKS cluster 
echo "Creating AKS cluster '$AKS_NAME' in resource group '$RG_NAME'."
az aks create --name $AKS_NAME --resource-group $RG_NAME \
    --node-count $AKS_NODE_COUNT --enable-addons monitoring \
    --generate-ssh-keys --output none

# Retrieve kubectl credentials from the cluster
az aks get-credentials --name $AKS_NAME --resource-group $RG_NAME \
    --overwrite-existing

echo "Creating custom K8S StorageClass to support volume mount from Drupal pods."
kubectl apply -f drupal-sc.yaml

# Create a MariaDB Server
echo "Creating MariaDB server '$DB_SERVER_NAME' in resource group '$RG_NAME'."
az mariadb server create --name $DB_SERVER_NAME \
    --location $LOCATION --resource-group $RG_NAME \
    --sku-name $DB_SERVER_SKU -u $DB_ADMIN_NAME -p $DB_ADMIN_PASSWORD \
    --ssl-enforcement Disabled --version 10.3 --output none

# Enable Azure services (ie: AKS) to connect to the server.
echo "Configuring firewall for MariaDB server '$DB_SERVER_NAME'."
az mariadb server firewall-rule create --resource-group $RG_NAME \
    --server-name $DB_SERVER_NAME --name AllowAllWindowsAzureIps \
    --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --output none

## Create a blank DB for Drupal - the initialization process expects it to already exist.
echo "Creating Drupal database '$DB_NAME' in server '$DB_SERVER_NAME'."
az mariadb db create --resource-group $RG_NAME \
    --server-name $DB_SERVER_NAME --name $DB_NAME --output none

# Install charts
echo "Installing Drupal helm chart."
helm install drupal-release \
    --set mariadb.enabled=false \
    --set externalDatabase.host="${DB_SERVER_NAME}.mariadb.database.azure.com" \
    --set externalDatabase.user="${DB_ADMIN_NAME}@${DB_SERVER_NAME}" \
    --set externalDatabase.password="${DB_ADMIN_PASSWORD}" \
    --set externalDatabase.database="${DB_NAME}" \
    --set persistence.accessMode=ReadWriteMany \
    --set persistence.size=100Gi \
    --set persistence.storageClass=drupal-sc \
    bitnami/drupal
