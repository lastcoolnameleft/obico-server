LOCATION=eastus

ACR_NAME=spaghettidetective
REGISTRY_SERVER=${ACR_NAME}.azurecr.io
REGISTRY_USERNAME=$(az acr credential show -n $ACR_NAME --query username -o tsv)
REGISTRY_PASSWORD=$(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)

RESOURCE_GROUP=spaghetti-detective
REDIS_NAME=spaghetti-detective
CONTAINERAPPS_ENVIRONMENT=managedEnvironment-spaghettidetect-bce1

ACA_MLAPI_NAME=mlapi
ACA_MLAPI_IMAGE=spaghettidetective.azurecr.io/obico-ml-api:4
ACA_TASKS_NAME=tasks
ACA_TASKS_IMAGE=spaghettidetective.azurecr.io/obico-server-tasks:4
ACA_WEB_NAME=web
ACA_WEB_IMAGE=spaghettidetective.azurecr.io/obico-server-web:4

# Create resource group
az group create -n $RG_NAME -l $LOCATION

# Redis
az redis create --location $LOCATION --name $REDIS_NAME -g $RESOURCE_GROUP \
        --sku Basic --vm-size c0
az redis show -n $REDIS_NAME -g $RESOURCE_GROUP
REDIS_HOSTNAME=$(az redis show -n $REDIS_NAME -g $RESOURCE_GROUP --query hostName -o tsv)
az redis list-keys -n $REDIS_NAME -g $RESOURCE_GROUP
REDIS_KEY=$(az redis list-keys -n $REDIS_NAME -g $RESOURCE_GROUP --query primaryKey -o tsv)
REDIS_URL="rediss://:${REDIS_KEY}@${REDIS_HOSTNAME}:6380?ssl_cert_reqs=none"

# ml_api
az containerapp create \
  --name $ACA_MLAPI_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $ACA_MLAPI_IMAGE \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --registry-server $REGISTRY_SERVER \
  --registry-username $REGISTRY_USERNAME \
  --registry-password $REGISTRY_PASSWORD \
  --target-port 3333 --ingress 'internal' \
  --cpu 1 --memory 2.0Gi \
  --min-replicas 1 \
  --env-vars DEBUG='True' \
             FLASK_APP="server.py" 
ACA_MLAPI_FQDN=$(az containerapp show --name $ACA_MLAPI_NAME --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)
echo $ACA_MLAPI_FQDN

# tasks
az containerapp create \
  --name $ACA_TASKS_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $ACA_TASKS_IMAGE \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --registry-server $REGISTRY_SERVER \
  --registry-username $REGISTRY_USERNAME \
  --registry-password $REGISTRY_PASSWORD \
  --cpu 0.5 --memory 1.0Gi \
  --min-replicas 1 \
  --env-vars DATABASE_URL='sqlite:////app/db.sqlite3' \
             REDIS_URL="redis://${ACA_REDIS_FQDN}:6379" \

# web
az containerapp create \
  --name $ACA_WEB_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $ACA_WEB_IMAGE \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --target-port 3334 \
  --ingress 'external' \
  --registry-server $REGISTRY_SERVER \
  --registry-username $REGISTRY_USERNAME \
  --registry-password $REGISTRY_PASSWORD \
  --cpu 0.5 --memory 1.0Gi \
  --min-replicas 1 \
  --env-vars DATABASE_URL='sqlite:////app/db.sqlite3' \
             REDIS_URL="${REDIS_URL}" \
             SITE_USES_HTTPS='True' \
             SITE_IS_PUBLIC='True' \
             INTERNAL_MEDIA_HOST="http://localhost:3334" \
             ML_API_HOST="http://${ACA_MLAPI_FQDN}:3333"

# UPDATE
az containerapp update \
  --name $ACA_TASKS_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $ACA_TASKS_IMAGE \
  --set-env-vars ML_API_HOST="http://${ACA_MLAPI_FQDN}:3333"

az containerapp update \
  --name $ACA_WEB_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $ACA_WEB_IMAGE \
  --set-env-vars REDIS_URL="${REDIS_URL}"

# Validate 
az containerapp replica list -g $RESOURCE_GROUP -n $ACA_REDIS_NAME
az containerapp replica list -g $RESOURCE_GROUP -n $ACA_MLAPI_NAME 
az containerapp revision list  -g $RESOURCE_GROUP -n $ACA_MLAPI_NAME -o table

# View Logs
az containerapp logs show --follow -g $RESOURCE_GROUP -n $ACA_WEB_NAME 
az containerapp logs show --follow -g $RESOURCE_GROUP -n $ACA_MLAPI_NAME 
az containerapp logs show --follow -g $RESOURCE_GROUP -n $ACA_TASKS_NAME 

# Cleanup
az containerapp delete -n $ACA_WEB_NAME -g $RESOURCE_GROUP
az containerapp delete -n $ACA_TASKS_NAME -g $RESOURCE_GROUP
az containerapp delete -n $ACA_MLAPI_NAME -g $RESOURCE_GROUP
