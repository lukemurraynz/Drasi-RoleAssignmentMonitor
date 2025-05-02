# drasi
Drasi playground

#Setup 
sudo az aks install-cli
az login
az aks get-credentials --resource-group aksdrasi-mvp-vscode --name drasiaksmvp
drasi version
drasi init --namespace drasi-system --version 0.2.1
kubectl get pods -n dapr-system

#Connect to Cluser

kubectl config use-context drasiaksmvp



az identity federated-credential create \
    --name drasi \
    --identity-name "drasiidentity" \
    --resource-group "aksdrasi-mvp-vscode" \
    --issuer "https://australiaeast.oic.prod-aks.azure.com/2463cfda-1c0b-43f5-b6e5-1c370752bb93/2dbd79b2-4e33-43d0-bf98-3f117015a45d/" \
    --subject system:serviceaccount:"drasi-system":"source.my-source" \
    --audience api://AzureADTokenExchange

# Add Azure Event Hubs Data Receiver 

#Event Hub source
drasi apply -f eventhubsource.yaml

    drasi describe source my-source -n drasi-system 

    # Continous Query

    MATCH (n:eventhub1) RETURN n LIMIT 10


## Reaction

az identity federated-credential create \
    --name drasistorage \
    --identity-name "drasiidentity" \
    --resource-group "aksdrasi-mvp-vscode" \
    --issuer "https://australiaeast.oic.prod-aks.azure.com/2463cfda-1c0b-43f5-b6e5-1c370752bb93/2dbd79b2-4e33-43d0-bf98-3f117015a45d/" \
    --subject system:serviceaccount:"drasi-system":"reaction.my-reaction" \
    --audience api://AzureADTokenExchange