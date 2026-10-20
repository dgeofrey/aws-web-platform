locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  cidr_block         = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.common_tags
}

module "web" {
  source = "../../modules/web"

  name               = local.name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_type    = var.instance_type
  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  app_source_dir = "${path.module}/../../app"

  tags = local.common_tags
}
