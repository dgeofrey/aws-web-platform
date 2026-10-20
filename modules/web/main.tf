locals {
  https_enabled  = var.certificate_arn != null
  listener_ports = local.https_enabled ? [80, 443] : [80]
  app_port       = 80

  # One ingress rule per (CIDR, listener port) pair
  alb_ingress = {
    for pair in setproduct(var.allowed_ingress_cidrs, local.listener_ports) :
    "${pair[0]}-${pair[1]}" => { cidr = pair[0], port = pair[1] }
  }

  # Application artifact
  app_enabled = var.app_source_dir != null
  app_files   = local.app_enabled ? sort(tolist(fileset(var.app_source_dir, "**"))) : []

  # Content hash of every app file. It's rendered into user data, so any change to the
  # app produces a new launch template version, which triggers a rolling instance refresh.
  app_version = local.app_enabled ? substr(sha1(join("", [
    for f in local.app_files : "${f}:${filemd5("${var.app_source_dir}/${f}")}"
  ])), 0, 12) : "placeholder"

  mime_types = {
    html = "text/html; charset=utf-8"
    css  = "text/css; charset=utf-8"
    js   = "application/javascript; charset=utf-8"
    json = "application/json"
    svg  = "image/svg+xml"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    gif  = "image/gif"
    ico  = "image/x-icon"
    webp = "image/webp"
    txt  = "text/plain; charset=utf-8"
  }
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter
}

# ---------------------------------------------------------------------------
# Application artifact: a private S3 bucket the instances sync from at boot
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "app" {
  count = local.app_enabled ? 1 : 0

  bucket_prefix = "${var.name}-app-"

  # Holds build artifacts only, which are always reproducible from the repo
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "app" {
  count = local.app_enabled ? 1 : 0

  bucket = aws_s3_bucket.app[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  count = local.app_enabled ? 1 : 0

  bucket                  = aws_s3_bucket.app[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  count = local.app_enabled ? 1 : 0

  bucket = aws_s3_bucket.app[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "app" {
  for_each = toset(local.app_files)

  bucket       = aws_s3_bucket.app[0].id
  key          = each.value
  source       = "${var.app_source_dir}/${each.value}"
  source_hash  = filemd5("${var.app_source_dir}/${each.value}")
  content_type = lookup(local.mime_types, lower(reverse(split(".", each.value))[0]), "application/octet-stream")

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Security groups: internet -> ALB -> app. Instances accept traffic from the
# ALB only and have no inbound SSH; shell access is through SSM Session Manager.
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Load balancer: public HTTP/HTTPS in, app port out to instances"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name_prefix = "${var.name}-app-"
  description = "App instances: traffic from the ALB only, HTTPS out for updates and SSM"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-app-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  for_each = local.alb_ingress

  security_group_id = aws_security_group.alb.id
  description       = "Port ${each.value.port} from ${each.value.cidr}"
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To app instances"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = local.app_port
  to_port                      = local.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "From the load balancer only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = local.app_port
  to_port                      = local.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out for package repositories and SSM"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# ---------------------------------------------------------------------------
# IAM: instance role limited to SSM Session Manager
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name_prefix        = "${var.name}-app-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read-only access to the application artifact bucket, and nothing else in S3
data "aws_iam_policy_document" "app_artifact_read" {
  count = local.app_enabled ? 1 : 0

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.app[0].arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "app_artifact_read" {
  count = local.app_enabled ? 1 : 0

  name   = "app-artifact-read"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_artifact_read[0].json
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = "${var.name}-app-"
  role        = aws_iam_role.app.name

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.alb_deletion_protection

  tags = var.tags
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.name}-app"
  port                 = local.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  # Forward when there's no certificate; otherwise redirect everything to HTTPS
  default_action {
    type             = local.https_enabled ? "redirect" : "forward"
    target_group_arn = local.https_enabled ? null : aws_lb_target_group.app.arn

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Compute: launch template + Auto Scaling group in private subnets
# ---------------------------------------------------------------------------

resource "aws_launch_template" "app" {
  name_prefix            = "${var.name}-app-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app.id]
  update_default_version = true

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_name    = var.name
    app_bucket  = local.app_enabled ? aws_s3_bucket.app[0].id : ""
    app_version = local.app_version
    region      = data.aws_region.current.region
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  # IMDSv2 only, and a hop limit of 1 so containers can't reach instance credentials
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  tags = var.tags
}

resource "aws_autoscaling_group" "app" {
  name_prefix               = "${var.name}-app-"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.app.arn]
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # A new launch template version rolls out gradually without dropping capacity
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }

  # Instances sync the app at boot, so the artifact and read permission must exist first
  depends_on = [
    aws_s3_object.app,
    aws_iam_role_policy.app_artifact_read,
  ]
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.cpu_target_value

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
