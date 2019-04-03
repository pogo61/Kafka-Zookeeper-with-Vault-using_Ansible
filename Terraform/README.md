# tp-aws-terraform
Infrastructure for transaction processing on AWS

## Getting started

Create a ~/credentials.tfvars file with the following key-values:
```
account_key=aws-account-key
secret_key=aws-secret-key
```

Then:
```
terraform init -backend-config=~/credentials.tfvars
terraform apply -var-file=~/credentials.tfvars
```
