# AWS Web Platform — Terraform

Terraform for a multi-AZ web platform on AWS, built from reusable modules with one thin
composition per environment.

## Current scope: network foundation

The `vpc` module provisions the network layer the rest of the platform builds on.

```mermaid
flowchart TB
    igw[Internet Gateway]

    subgraph vpc["VPC — 10.20.0.0/16"]
        subgraph az1["AZ a"]
            pub1["Public 10.20.0.0/24"]
            priv1["Private 10.20.10.0/24"]
        end
        subgraph az2["AZ b"]
            pub2["Public 10.20.1.0/24"]
            priv2["Private 10.20.11.0/24"]
        end
        nat["NAT Gateway (optional)"]
    end

    pub1 & pub2 --> igw
    priv1 & priv2 -.-> nat --> igw
```

- **Public and private subnets in each Availability Zone.** CIDRs are derived with `cidrsubnet()`, so adding a zone never renumbers existing subnets.
- **Subnets keyed by AZ name** (`for_each`, not `count`), so changing the zone count doesn't destroy and recreate unrelated subnets.
- **Locked-down default security group.** All rules are removed, so nothing can attach to it by accident.
- **Optional single NAT gateway** for private subnet egress. It's off by default in dev because it's billed hourly. Production would run one per AZ.
- **Validated inputs** (CIDR size, zone count) and consistent tagging through provider `default_tags`.

## Repository layout

```
.
├── environments/
│   └── dev/        # Composes modules for the dev environment
└── modules/
    └── vpc/        # VPC, subnets, internet gateway, NAT, routing
```

## Usage

Requires Terraform ≥ 1.10 and AWS credentials for the target account.

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Without the NAT gateway, every resource in this configuration is free.
