# One private application target and one Entra private network connector in a
# single availability zone. The connector reaches Microsoft outbound through an
# internet gateway; the target sits in a subnet with no route off the VPC.
# See ADR-019.

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "connector_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

locals {
  availability_zone = data.aws_availability_zones.available.names[0]

  # Amazon-provided Windows activation and time endpoints. Link-local, so they
  # need no route table entry, but the security group still has to allow them.
  windows_activation_hosts = ["169.254.169.250/32", "169.254.169.251/32"]
}

## Network

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-private-access" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "connector" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.connector_subnet_cidr
  availability_zone = local.availability_zone

  tags = merge(var.tags, { Name = "${var.name_prefix}-connector" })
}

resource "aws_subnet" "target" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.target_subnet_cidr
  availability_zone = local.availability_zone

  tags = merge(var.tags, { Name = "${var.name_prefix}-target" })
}

resource "aws_route_table" "connector" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-connector" })
}

# Declared with no routes beyond the VPC-local one so the absence of an egress
# path is a property of the route table, not just of a missing public address.
resource "aws_route_table" "target" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-target" })
}

resource "aws_route_table_association" "connector" {
  subnet_id      = aws_subnet.connector.id
  route_table_id = aws_route_table.connector.id
}

resource "aws_route_table_association" "target" {
  subnet_id      = aws_subnet.target.id
  route_table_id = aws_route_table.target.id
}

## Security groups

resource "aws_security_group" "connector" {
  name        = "${var.name_prefix}-connector"
  description = "Entra private network connector. Outbound only."
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-connector" })
}

# No ingress rules. The connector opens outbound tunnels to Microsoft and is
# administered through SSM Fleet Manager, so nothing reaches it inbound.

resource "aws_vpc_security_group_egress_rule" "connector_https" {
  security_group_id = aws_security_group.connector.id
  description       = "Global Secure Access, registration, SSM, and certificate services"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "connector_http" {
  security_group_id = aws_security_group.connector.id
  description       = "Certificate revocation lists"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "connector_ntp" {
  security_group_id = aws_security_group.connector.id
  description       = "Time synchronisation"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "udp"
  from_port         = 123
  to_port           = 123
}

resource "aws_vpc_security_group_egress_rule" "connector_dns" {
  for_each = toset(["tcp", "udp"])

  security_group_id = aws_security_group.connector.id
  description       = "VPC resolver (${each.key})"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = each.key
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "connector_activation" {
  for_each = toset(local.windows_activation_hosts)

  security_group_id = aws_security_group.connector.id
  description       = "Windows activation"
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 1688
  to_port           = 1688
}

resource "aws_vpc_security_group_egress_rule" "connector_to_target" {
  security_group_id            = aws_security_group.connector.id
  description                  = "Private application target"
  referenced_security_group_id = aws_security_group.target.id
  ip_protocol                  = "tcp"
  from_port                    = var.target_port
  to_port                      = var.target_port
}

resource "aws_security_group" "target" {
  name        = "${var.name_prefix}-target"
  description = "Private application target. Reachable only from the connector."
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-target" })
}

resource "aws_vpc_security_group_ingress_rule" "target_from_connector" {
  security_group_id            = aws_security_group.target.id
  description                  = "Application port from the connector only"
  referenced_security_group_id = aws_security_group.connector.id
  ip_protocol                  = "tcp"
  from_port                    = var.target_port
  to_port                      = var.target_port
}

# The target has no egress rules. Security groups are stateful, so it still
# answers the connector, and it originates nothing.

## Connector management access

resource "aws_iam_role" "connector" {
  name        = "${var.name_prefix}-connector"
  description = "Allows SSM Fleet Manager administration of the connector host."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "connector_ssm" {
  role       = aws_iam_role.connector.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "connector" {
  name = "${var.name_prefix}-connector"
  role = aws_iam_role.connector.name

  tags = var.tags
}

## Instances

resource "aws_instance" "connector" {
  ami                         = nonsensitive(data.aws_ssm_parameter.connector_ami.value)
  instance_type               = var.connector_instance_type
  subnet_id                   = aws_subnet.connector.id
  vpc_security_group_ids      = [aws_security_group.connector.id]
  iam_instance_profile        = aws_iam_instance_profile.connector.name
  key_name                    = var.connector_key_name
  associate_public_ip_address = true

  # Prepares the host to Microsoft's documented prerequisites. Connector
  # registration is interactive and is not scripted here: it needs an
  # administrator sign-in, and those credentials must not reach user data.
  user_data = <<-EOT
    <powershell>
    $protocols = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
    foreach ($role in @('Client', 'Server')) {
      $key = Join-Path $protocols $role
      if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
      New-ItemProperty -Path $key -Name 'Enabled' -Value 1 -PropertyType DWord -Force | Out-Null
      New-ItemProperty -Path $key -Name 'DisabledByDefault' -Value 0 -PropertyType DWord -Force | Out-Null
    }
    $netfx = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
    if (-not (Test-Path $netfx)) { New-Item $netfx -Force | Out-Null }
    New-ItemProperty -Path $netfx -Name 'SystemDefaultTlsVersions' -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $netfx -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force | Out-Null
    </powershell>
  EOT

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-connector" })
}

## Private target: one ARM Fargate task

# The target subnet has no route off the VPC, so the task pulls its image and
# ships its logs through endpoints rather than an internet path. The S3 gateway
# endpoint carries the image layers and is free; the three interface endpoints
# are the only recurring cost this choice adds. See ADR-019.

resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-endpoints"
  description = "Interface endpoints serving the private target."
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-endpoints" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_target" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the private target"
  referenced_security_group_id = aws_security_group.target.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ecr.api", "ecr.dkr", "logs"])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.target.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.target.id]

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3" })
}

resource "aws_vpc_security_group_egress_rule" "target_to_endpoints" {
  security_group_id            = aws_security_group.target.id
  description                  = "Image pull and log delivery through interface endpoints"
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "target_to_s3" {
  security_group_id = aws_security_group.target.id
  description       = "Image layers through the S3 gateway endpoint"
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "target_dns" {
  for_each = toset(["tcp", "udp"])

  security_group_id = aws_security_group.target.id
  description       = "VPC resolver (${each.key})"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = each.key
  from_port         = 53
  to_port           = 53
}

resource "aws_ecr_repository" "target" {
  name                 = "${var.name_prefix}-private-target"
  image_tag_mutability = "MUTABLE"

  # The repository is recreated with the test footprint, so a lingering image
  # must not block destroy.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-private-target" })
}

resource "aws_cloudwatch_log_group" "target" {
  name              = "/${var.name_prefix}/private-target"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_iam_role" "task_execution" {
  name        = "${var.name_prefix}-target-execution"
  description = "Lets ECS pull the private target image and write its logs."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-private-access"

  tags = var.tags
}

resource "aws_ecs_task_definition" "target" {
  family                   = "${var.name_prefix}-private-target"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.target_task_cpu
  memory                   = var.target_task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  # The workstation is ARM64, so the image builds natively and the task is
  # cheaper than its x86 equivalent.
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = "private-target"
    image     = "${aws_ecr_repository.target.repository_url}:${var.target_image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.target_port
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.target.name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "private-target"
      }
    }
  }])

  tags = var.tags
}

resource "aws_ecs_service" "target" {
  name            = "${var.name_prefix}-private-target"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.target.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.target.id]
    security_groups  = [aws_security_group.target.id]
    assign_public_ip = false
  }

  # Tasks cannot start until the pull path exists.
  depends_on = [
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
    aws_iam_role_policy_attachment.task_execution,
  ]

  tags = var.tags
}
