# drasi
Drasi playground

#Setup 
sudo az aks install-cli
az login
az aks get-credentials --resource-group drasiaks --name drasiaks1
drasi version
drasi init --namespace drasi-system --version 0.2.1
kubectl get pods -n dapr-system

#Connect to Cluser

kubectl config use-context drasiaks1

#Event Hub source
drasi apply -f eventhubsource.yaml

az identity federated-credential create \
    --name drasi \
    --identity-name "drasiuim" \
    --resource-group "drasiaks" \
    --issuer "https://australiaeast.oic.prod-aks.azure.com/2463cfda-1c0b-43f5-b6e5-1c370752bb93/34045efe-e88e-4ecc-9437-2728a8076135/" \
    --subject system:serviceaccount:"drasi-system":"source.my-source" \
    --audience api://AzureADTokenExchange

    drasi describe source my-source -n drasi-system 

    # Continous Query

    MATCH (n:eventhub1) RETURN n LIMIT 10
