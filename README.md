# drasi
Drasi playground

sudo az aks install-cli
az login
az aks get-credentials --resource-group drasiaks --name drasiaks1
kubectl config use-context drasiaks1
drasi version
drasi init --namespace drasi-system --version 0.2.1
