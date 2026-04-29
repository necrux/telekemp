# telekemp
Testing k8s cluster w/ Teleport.

## Infrastucture

### Kubernetes

Kubernetes is bootstrap by Terraform via `user_data`.

### Applications

### Terraform

All other resources are controlled via Terraform. State is stored in the `telekemp-terraform-state` S3 bucket.

> [!NOTE]
> Typically DNS would also be managed at this layer via Route 53, however this particular test environment is using DNS with another provider.
