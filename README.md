# drasi
Drasi playground

sudo az aks install-cli
az login
az aks get-credentials --resource-group drasiaks --name drasiaks1
kubectl config use-context drasiaks1
drasi init --namespace drasi-system --version latest
