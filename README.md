# PHP API on GKE with Terraform and GitHub Actions

This project deploys a simple PHP API that returns the current time to Google Kubernetes Engine (GKE) using Terraform and GitHub Actions.

## Prerequisites

- Google Cloud Platform account
- GitHub account
- Docker Hub account
- Terraform installed locally
- Google Cloud SDK installed locally

## Local Setup

1. Clone this repository:
   ```
   git clone https://github.com/your-username/your-repo-name.git
   cd your-repo-name
   ```

2. Set up your GCP credentials:
   ```
   gcloud auth application-default login
   ```

3. Create a `terraform.tfvars` file with your GCP project ID and Docker Hub username:
   ```
   project_id = "your-gcp-project-id"
   docker_hub_username = "your-docker-hub-username"
   ```

4. Initialize Terraform:
   ```
   terraform init
   ```

5. Plan and apply the Terraform configuration:
   ```
   terraform plan
   terraform apply
   ```

6. After the infrastructure is created, you can get the API endpoint:
   ```
   kubectl get service api-service -n api-namespace
   ```

   Use the EXTERNAL-IP to access your API.

## GitHub Actions Setup

1. In your GitHub repository, go to Settings > Secrets and add the following secrets:
   - GCP_PROJECT_ID: Your Google Cloud Project ID
   - GCP_SA_KEY: The JSON key of a service account with necessary permissions
   - DOCKER_HUB_USERNAME: Your Docker Hub username

2. Push your code to the main branch to trigger the GitHub Actions workflow.

## Testing

Once deployed, you can test the API by sending a GET request to the EXTERNAL-IP of the api-service:

```
curl http://EXTERNAL-IP
```

You should receive a JSON response with the current time.

## Cleaning Up

To avoid incurring charges, remember to destroy the resources when you're done:

```
terraform destroy
```

## Security Notes

- The NAT gateway is set up to manage outbound traffic from the GKE cluster.
- Firewall rules are implemented to restrict inbound traffic to port 80 only.
- IAM roles are managed through the GKE service account.
- Always follow the principle of least privilege when setting up service accounts and IAM roles.