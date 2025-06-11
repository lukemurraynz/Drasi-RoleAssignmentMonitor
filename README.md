# drasi
Drasi playground

#Setup 
sudo az aks install-cli
az login
az aks get-credentials --resource-group aksdrasi-mvp-vscode --name drasiakstest
drasi version
drasi init --namespace drasi-system --version 0.3.2
kubectl get pods -n dapr-system

#Connect to Cluser

kubectl config use-context drasiakstest



az identity federated-credential create \
    --name drasi \
    --identity-name "drasiidentity" \
    --resource-group "aksdrasi-mvp-vscode" \
    --issuer "https://newzealandnorth.oic.prod-aks.azure.com/2463cfda-1c0b-43f5-b6e5-1c370752bb93/bc7c7b50-ff23-4ac8-a1a1-b13cfd0a3484/" \
    --subject system:serviceaccount:"drasi-system":"source.azure-role-eventhub-source" \
    --audience api://AzureADTokenExchange



## Reaction

az identity federated-credential create \
    --name drasistorage \
    --identity-name "drasiidentity" \
    --resource-group "aksdrasi-mvp-vscode" \
    --issuer "https://newzealandnorth.oic.prod-aks.azure.com/2463cfda-1c0b-43f5-b6e5-1c370752bb93/bc7c7b50-ff23-4ac8-a1a1-b13cfd0a3484/" \
    --subject system:serviceaccount:"drasi-system":"reaction.my-reaction" \
    --audience api://AzureADTokenExchange


    ## Docker Drasi

This section provides step-by-step instructions for setting up Drasi using Docker and managing your Drasi sources, queries, and reactions.

### 1. Initialize Drasi in Docker

```sh
# Initialize Drasi with Docker support
drasi init --docker
```

### 2. Apply Drasi Sources and Queries

```sh
# Apply your Event Hub source definition
drasi apply Sources/eventhubsource.yaml -f

# Apply your continuous query definition
drasi apply -f Queries/azure-role-change-vmadminlogin.yaml

# (Optional) Re-apply the Event Hub source if needed
drasi apply Reactions/azure-role-change-vmadminloginaction.yaml -f
```

### 3. List Drasi Resources

```sh
# List all registered continuous queries
drasi list query

# List all registered reactions
drasi list reaction

# List all registered sources
drasi list source
```

---

- Ensure your YAML files follow the latest Drasi templates and best practices.
- For more details, see the [Drasi documentation](https://drasi.io/) and [Drasi GitHub repositories](https://github.com/orgs/drasi-project/repositories).