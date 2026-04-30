# telekemp

Testing k8s cluster w/ Teleport.

## Infrastucture

### Terraform

All other resources are controlled via Terraform. State is stored in the `telekemp-terraform-state` S3 bucket.

> [!NOTE]
> Typically DNS would also be managed at this layer via Route 53, however this particular test environment is using DNS with another provider.

### Kubernetes

Kubernetes is bootstraped by Terraform via `user_data`. All associated scripts can be found [here](https://github.com/necrux/telekemp/tree/main/terraform/scripts).

### Applications

## Roadmap

## Sources
