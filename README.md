# telekemp

Testing k8s cluster w/ Teleport.

## Infrastucture

### Terraform

All resources are controlled via Terraform. State is stored in the `telekemp-terraform-state` S3 bucket.

> [!NOTE]
> Typically DNS would also be managed at this layer via Route 53, however this particular test environment is using DNS with another provider.

### Kubernetes

Kubernetes is bootstraped via Terraform using `user_data`; this includes basic cluster configuration. All associated scripts can be found [here](https://github.com/necrux/telekemp/tree/main/terraform/scripts).

> [!NOTE]
> Terraform is intended for cluster initialization only and any additional Kubernetes configuration should be moved outside of IaC. However many cluster initialization options have been exposed [here](https://github.com/necrux/telekemp/blob/main/terraform/variables.tf) for portability purposes. 

### Applications

## Roadmap

## Sources
