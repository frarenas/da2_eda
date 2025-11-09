# Terraform — citypass (infrastructure)

This folder contains Terraform configuration to provision the Citypass infrastructure (VPC, subnets, NAT, ECS, EFS, security groups, etc.).

Use this README to run Terraform locally and manage the infrastructure.

## Prerequisites

- macOS / Linux / Windows with a terminal
- Terraform installed (see https://developer.hashicorp.com/terraform/install)
- AWS CLI installed (see https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS credentials (see Configure AWS below)

## Configure AWS credentials

The easiest way is to use the AWS CLI `aws configure` command:

```bash
aws configure
```

This will create `~/.aws/credentials` and `~/.aws/config` for the `default` profile.

If you prefer to use a named profile, do:

```bash
aws configure --profile myprofile
export AWS_PROFILE=myprofile   # or set profile in provider block
```

Verify credentials:

```bash
aws sts get-caller-identity
```

If this returns an error, your credentials are invalid or expired. Refresh temporary credentials (set `AWS_SESSION_TOKEN`) or run `aws sso login --profile myprofile` if you use SSO.

## Terraform workflow (recommended)

Open a terminal and change to this folder:

```bash
cd terraform
```

1. Initialize the working directory and download providers:

```bash
terraform init
```

If you don't have a backend configured or want to skip backend initialization during local checks, you can run:

```bash
terraform init -backend=false
```

2. (Optional) Format and validate configuration locally:

```bash
terraform fmt
terraform validate
```

3. Create a plan file (safe preview):

```bash
terraform plan -out=ec2_plan.tfplan
```

4. Apply the plan (creates the resources):

```bash
terraform apply ec2_plan.tfplan
```

5. To destroy everything created by this configuration:

```bash
terraform destroy
```

Notes:
- `terraform plan` shows what will be created/changed. Use `-out` to save the plan and then `terraform apply` that exact plan for reproducible deployments.
- Do not commit AWS credentials or sensitive values to Git. Use variables, environment variables or a secrets manager.

## Provider profile in Terraform

If you created a non-default AWS profile, you can set the profile either using the `AWS_PROFILE` environment variable or in the Terraform provider block, e.g. in `main.tf`:

```hcl
provider "aws" {
  region  = var.aws_region
  profile = "myprofile"
}
```

## Security & best practices

- Do not commit `~/.aws/credentials` or any file containing secrets to the repository.
- Limit IAM privileges for the credentials used by Terraform to only what is necessary.
- Use remote backends (S3 + DynamoDB) for state locking if you run Terraform in teams.

## Troubleshooting

- Error `No valid credential sources found` — ensure environment variables or `~/.aws/credentials` exist and are correct.
- Error `InvalidClientTokenId` or `ExpiredToken` — refresh temporary credentials (`AWS_SESSION_TOKEN`) or re-run `aws sso login` / `aws configure`.
- If a provider error references an unsupported argument (for example `vpc = true` on `aws_eip`), update the Terraform code and run `terraform validate`.

If you want, I can add a short `.gitignore` suggestion or a CI example to run `terraform validate` and `fmt` on PRs.

---

README generated from `instructions.txt`.
