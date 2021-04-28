# Drupal on Azure AKS

This sample provides guidance and code to run a containerized Drupal image on [Azure AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/). This solution leverages [Bitnami's Docker images for Drupal with NGINX](https://github.com/bitnami/bitnami-docker-drupal-nginx) as a foundation and then adds additional configuration to do the following:

- Externalize the Drupal database to [Azure Database for MariaDB](https://docs.microsoft.com/en-us/azure/mariadb/),
- Mount a Persistent Volume Claim using Azure File Share, so that Drupal's file system can be mounted by multiple Drupal pods

This guidance was tested and verified on the following platforms:
- Ubuntu 18.04 LTS

## Pre-Requisites

The following software needs to be installed on your local computer before you start.

- Azure Subscription (commercial) 
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli), v2.18 (or newer)
- [Helm](https://helm.sh/docs/intro/install/), v3.5.1 (or newer)

## Get Started

To get started, you need to perform the following tasks in order:
- Configure your environment
- Deploy the solution to Azure
- Verify your deployment

### Configure your environment
Set and save the environment variables listed below to a `.env` file to personalize your deployment.

```bash
# Azure resoure group settings
RG_NAME=                  # Resource group name, ie: 'drupal-rg'
LOCATION=eastus           # az account list-locations --query '[].name'

# AKS settings
AKS_NAME=                 # AKS Cluster Name, ie: 'drupal-aks'
AKS_NODE_COUNT=2

# Drupal DB settings
DB_SERVER_NAME=           # Must be globally unique, ie: 'drupal-db-$RANDOM'
DB_SERVER_SKU=GP_Gen5_2   # Azure Database SKU
DB_ADMIN_NAME=            # Cannot be 'admin'.
DB_ADMIN_PASSWORD=        # Must include uppercase, lowercase, and numeric
DB_NAME=bitnami_drupal    # Drupal DB name
```

### Deploy the solution to Azure

After you have updated and saved your changes to the `.env` file, open a terminal window and execute the following commands to load your environment.

```bash
# Login to your Azure Subscription
az login

# Source and export the environment variables
cd ./drupal-on-aks
set -a  
source .env    # Assumes your .env is at ./drupal-on-aks/.env
set +a

# Deploy the solution
./deploy.sh
```

> NOTE: This step will take about 5 minutes to complete.

After the deployment is complete, it will take Drupal another ~3 mins to initialize.  The initialization process will initialize the Maria DB and the file share (Azure FileShare) where configuration and static data is persisted.

Execute the following command to watch the Drupal pod.  When it reaches a _Running_ status, you can continue to the next section.

```bash
kubectl get pods -w    # Press Ctrl-C to stop watching
```

### Verify your deployment
Run the following commands to get the URL for your site:

```bash
# Get the public IP of the load balancer.  
export SERVICE_IP=$(kubectl get svc --namespace default drupal-release \
    --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  
# Get the URL to access Drupal
  echo "Drupal URL: http://$SERVICE_IP/"
```

Next, open a browser and navivate to the Drupal URL.  In the Drupal site, you will need to login to be able to create content.  The Drupal image creates a default user for you that you can use to login with.  Run the following commands to get your _user_ credentials:

```bash
echo Username: user
echo Password: $(kubectl get secret --namespace default drupal-release -o jsonpath="{.data.drupal-password}" | base64 --decode)
```

Click the *Log in* link in the upper right corner of the screen to log in with these credentials.

#### Create some content

After you are logged into Drupal, you should see an _Add content_ link.  Use this link to create a new page of content.

#### Verify data in the Azure FileShare

To verify your file share is where Drupal is persisting data, use Storage Explorer or the Azure Portal to explore the contents of the file share.

## FAQ

### Why does the HTML not render correctly when accessing the site using HTTP (not HTTPS)?

If you find that the CSS files are not rendering the site correctly when accessing the site using HTTP, this is a known issue.  See the bug reported [here](https://github.com/bitnami/charts/issues/5450).

### How can I run a load test against the Drupal site?
Azure Container Instances are a great option for this.  The command below will create an Azure Container Instance and use _apache benchmark (ab)_ to execute 500 requests across 10 concurrent I/O threads.

```bash
# Create a container instance and run the load test.
az container create -resource-group $RG_NAME -n loadtest --cpu 4 --image httpd \
    --restart-policy Never --command-line "ab -n 500 -c 10 https://$SERVICE_IP/"

# Retrieve the load test logs
az container logs --name loadtest --resource-group $RG_NAME

# Run the load test again.
az container start --name loadtest --resource-group $RG_NAME
```

### How do I uninstall the Drupal release running on my cluster?

Run the following command to remove the helm release.

```bash
helm delete drupal-release
```

The command above only removes the helm release.  If you want to remove the Drupal database from your Azure Database instance, you will have to do that separately.

### How do I remove the Drupal database from my Azure Database for MariaDB instance?

Run the following command to remove the Drupal Database.

```bash
az mariadb db delete --name $DB_NAME --server-name $DB_SERVER_NAME --resource-group $RG_NAME
```

## References

The resources below provide additional details that influenced this reference architecture.
- [Deploying Drupal in K8S](https://github.com/geerlingguy/kubernetes-101/tree/master/episode-04)
- [Scaling Drupal in K8S](https://github.com/geerlingguy/kubernetes-101/tree/master/episode-05)
- [Dynammically create and Azure persistent volume backed by Azure Files](https://docs.microsoft.com/en-us/azure/aks/azure-files-dynamic-pv)