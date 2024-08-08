# LeafLink Take Home

Install dependencies with `poetry install`

Run the application with `poetry run python3 weather_app/app.py`

# Project structure
``` 
.
└── .github/
    └── workflows/
        ├── ci.yml
└── bin/
├── Dockerfile
├── compose.yaml
├── pyproject.toml
├── README.md
└── charts/
     └── weather-chart
         └── templates/
         │   └── tests/
         │   ├── _helpers.tpl
         │   ├── deployment.yaml
         │   ├── hpa.yaml
         │   ├── ingress.yaml
         │   ├── pdb.yaml
         │   ├── secret.yaml
         │   ├── service.yaml
         │   └── serviceaccount.yaml
         │
         ├── .helmignore
         ├── Chart.yaml
         └── values.yaml
└── weather_app
    ├── app.py
└── kubernetes-manifests /
   ├── weather-deployment.yaml
   ├── weather-service.yaml 
   ├── weather-pod-disruption-budget.yaml
   ├── weather-scaling.yaml
```

# Assumptions
1. **Development Environment**: Unix-like environment (Linux/MacOS) with bash as the shell. Commands may need modification for Windows.
2. **Docker Container Registry**: Docker Hub as Container Registry. You can use other Container Registries like: ECR, ACR, GAR etc.
3. **Internet Access**: The environment where the Docker image is built has access to the internet for downloading dependencies and packages.
4. **Kubernetes Cluster**: A running Kubernetes cluster is needed. You can use Minikube for local development or create a cluster 
 with appropriate permissions on cloud providers such as GKE, EKS, or AKS. 
5. **Docker and Kubernetes Installation**: Docker, Docker Compose, Kubernetes, and kubectl are installed and properly configured on your local machine.
6. **Poetry**: Poetry is used for Python dependency management and should be installed and configured correctly on your machine.
7. **Networking**: The host machine's firewall and network settings allow communication on the ports specified for Docker and Kubernetes.
8. **User Permissions**: Necessary permissions to execute Docker and Kubernetes commands on your local machine and Kubernetes cluster.



# Docker setup
### Build docker image
```commandline
docker build . -t weather_api
```

### Run Docker container
Add SECURE_WEATHER_API_KEY in .env file
```commandline
docker run -p 5001:5000 --env-file <path to .env file> weather_api:latest
```
OR
```commandline
docker compose up
```
The application should be accessible directly via at `localhost:5001` as we did port-forwarding

### Access the Container's shell
For debugging
```commandline
docker exec -it <container name> bash
```
#### Troubleshooting from inside the container
1. Execute the following command to verify if Environment variable is set:
    ```commandline
    echo $SECURE_WEATHER_API_KEY
    ```
2. Ping the API from Inside the Container:
    ```commandline
    curl -H "X-API-KEY: <API_KEY>" https://api.weather.gov/stations/KNYC/observations/latest
    ```

# Kubernetes setup
## Create Kubernetes Secrets
1. To store API_KEY value create secret:
    ```commandline
    kubectl create secret generic api-secret --from-literal=api-key=<API_KEY>
    ```
2. To store credentials of Container Registry:
    ```commandline
    kubectl create secret docker-registry regcred \
     --docker-server=https://index.docker.io/v1/ \
     --docker-username=<DOCKER_HUB_USERNAME> \
     --docker-password=<DOCKER_HUB_PASSWORD> \
     --docker-email=<DOCKER_HUB_EMAIL>
    ```
   
## Create Kubernetes Deployment
Replace the `DOCKER_HUB_USERNAME` in the image field with actual value in [kubernetes-manifests/weather-deployment.yaml](kubernetes-manifests/weather-deployment.yaml).
``` 
image: <DOCKER_HUB_USERNAME>/weather-app:latest
```
Create Deployment using below command:
```commandline
kubectl apply -f kubernetes-manifests/weather-deployment.yaml
```

## Create Kubernetes Service
```commandline
kubectl apply -f kubernetes-manifests/weather-service.yaml
```

## Create Kubernetes HorizontalPodAutoscaler
```commandline
kubectl apply -f kubernetes-manifests/weather-scaling.yaml
```

## Create Kubernetes PodDisruptionBudget
```commandline
kubectl apply -f kubernetes-manifests/weather-pod-disruption-budget.yaml
```

## Port-Forwarding
If you want to access the application running on Kubernetes without setting up a LoadBalancer or Ingress, you can use port 
forwarding:
```commandline
kubectl port-forward service/weather-api-service 5001:5001
```

## Logs in Kubernetes
To check logs in Kubernetes:
```commandline
kubectl logs -l app=weather-api
```

# Helm Chart

## Prerequisites

**Helm Package Manager:** Helm needs to be installed for managing Kubernetes applications.


## Installing Helm Chart
Create **DOCKER_SECRET_STRING** secret using this command and place it inside [charts/weather-chart/templates/secret.yaml](charts/weather-chart/templates/secret.yaml)
``` bash
#DOCKER_SECRET_STRING
echo -n '{"auths":{"https://index.docker.io/v1/":{"username":"rajeevranjan31","password":"","email":"rajeevferryranjan@gmail.com","auth":""}}}' | base64
```
```yaml
#secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: weather-docker-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <DOCKER_SECRET_STRING>
```
Both of these methods ensure that secrets are not compromised, even when pushing the values.yaml file to version control systems.
### Option 1
```yaml
#deployment.yaml
env:
- name: SECURE_WEATHER_API_KEY
  valueFrom:
    secretKeyRef:
      name: api-secret
      key: api-key
```

**Prior to installing chart, run this command to securely create a secret which can be accessed by helm chart you're creating**

```bash
kubectl create secret generic api-secret --from-literal=api-key=<API_KEY>
```

```bash
helm install weather charts/weather-chart 
```

### Option 2
```yaml
#values.yaml
apiSecret:
  apiKey: ""
```

```yaml
#deployment.yaml
env:
    - name: API_KEY
      value: {{ .Values.apiSecret.apiKey | quote }}
```

```bash
helm install weather charts/weather-chart  --set apiSecret.apiKey="<API_KEY>"
```

### Accessing the service
To get the IP address and Port on which service is running
```bash
export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services weather-weather-chart)
export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
echo http://$NODE_IP:$NODE_PORT/weather
```

An example would be this url from where you can access the app.
```
http://192.168.105.5:31531/weather
```


_By implementing the deployment process in GitHub Actions,
you can leverage GitHub Secrets to securely store sensitive 
information, such as API keys. This approach enables you to 
automate the entire cloud deployment pipeline, including creating 
the cluster, installing necessary dependencies, and deploying Helm 
charts. With this setup, all cloud-related processes are seamlessly 
integrated into a single automated workflow._


# CI workflow through Github Actions

 - `.github/workflows/ci.yml` contains CI workflow.

 - It consists of commands to perform Linting and Building the Docker   Image every time when `the code is pushed to the GitHub repository`.

 - Create two secret variables for storing `DOCKER_USERNAME` and `DOCKER_PASSWORD` in `GitHub secrets` for logging into Docker Hub.

 - It logs in the Docker Hub with the credentials fetched from the secrets and pushes the Docker Image to the Docker Hub on every push to the main branch.


### Workflow consists of following jobs:
 - lint: performs linting of the code files:
    - It sets up environment for python.
    - Installs poetry package manager.
    - installs black and flake8 through poetry.
    - runs the bash file containing commands for linting in bin/lint file.

 - build: builds the Docker Image and pushes it to the Docker Hub:
    - builds the Docker Image.
    - logs in to the Docker Hub by using credentials from the github secrets.
    - pushes the Docker Image to the Docker Hub.


# Conclusion
1. For High Availability, I have used PodDisruptionBudget 
2. For High Scalability, I have used HorizontalPodAutoscaling
3. For Security, I have used environment variables, GitHub secrets and kubernetes secrets 