BUILD_VER=4

az acr login -n spaghettidetective

docker build web -f web/Dockerfile.web -t spaghettidetective.azurecr.io/obico-server-web:${BUILD_VER}
docker build web -f web/Dockerfile.tasks -t spaghettidetective.azurecr.io/obico-server-tasks:${BUILD_VER}
docker build ml_api -f ml_api/Dockerfile -t spaghettidetective.azurecr.io/obico-ml-api:${BUILD_VER}

docker push spaghettidetective.azurecr.io/obico-server-web:${BUILD_VER}
docker push spaghettidetective.azurecr.io/obico-server-tasks:${BUILD_VER}
docker push spaghettidetective.azurecr.io/obico-ml-api:${BUILD_VER}
