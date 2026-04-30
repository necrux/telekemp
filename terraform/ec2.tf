### Nodes
resource "aws_instance" "control_plane" {
  ami              = "${var.ami_id}"
  instance_type    = "${var.control_plane_type}"
  key_name         = "${var.key_name}"
  user_data        = templatefile("scripts/bootstrap.sh", {
    CONTROL_PLANE  = "true",
    KUBE_VERSION   = var.kube_version,
    CALICO_VERSION = var.calico_version,
    POD_CIDR       = var.pod_cidr,
    BASE_PACKAGES  = join(" ", var.base_packages),
    KUBE_PACKAGES  = join(" ", var.kube_packages),
    NAMESPACE      = var.namespace,
    DEV_ROLE       = var.dev_team,
    SUPPORT_ROLE   = var.support_team
  })

  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.telekemp_instance_profile.name

  tags = {
    Name = "${var.control_plane_name}"
  }
}

resource "aws_instance" "worker" {
  ami              = "${var.ami_id}"
  instance_type    = "${var.worker_type}"
  key_name         = "${var.key_name}"
  count            = var.worker_count
  user_data        = templatefile("scripts/bootstrap.sh", {
    CONTROL_PLANE  = "false",
    KUBE_VERSION   = var.kube_version,
    CALICO_VERSION = var.calico_version,
    POD_CIDR       = var.pod_cidr,
    BASE_PACKAGES  = join(" ", var.base_packages),
    KUBE_PACKAGES  = join(" ", var.kube_packages),
    NAMESPACE      = var.namespace,
    DEV_ROLE       = var.dev_team,
    SUPPORT_ROLE   = var.support_team
  })

  #associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.telekemp_instance_profile.name

  tags = {
    Name = "${var.worker_name}-${format("%02d", count.index + 1)}"
  }
}

### Security Groups
resource "aws_security_group" "control_plane_sg" {
  name        = "${var.control_plane_name}-sg"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.lockdown ? ["136.50.255.66/32"] : ["0.0.0.0/0"]
  }

  # API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.lockdown ? ["136.50.255.66/32"] : ["0.0.0.0/0"]
  }

  # Kubelet API & Internal Components
  ingress {
    from_port = 10250
    to_port   = 10259
    protocol  = "tcp"
    self      = true # Allows master-to-master communication
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "worker_sg" {
  name        = "${var.worker_name}-sg"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.lockdown ? ["136.50.255.66/32"] : ["0.0.0.0/0"]
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Individual SG Rules (avoids cyclic dependency)
# Allow all traffic from Worker Security Group
resource "aws_security_group_rule" "from_worker" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = aws_security_group.worker_sg.id

  security_group_id = aws_security_group.control_plane_sg.id
}

# Kubelet API
resource "aws_security_group_rule" "from_control_plane" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "-1"
  source_security_group_id = aws_security_group.control_plane_sg.id

  security_group_id = aws_security_group.worker_sg.id
}

### IAM
resource "aws_iam_role" "secrets_role" {
  name = "${var.control_plane_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "secrets_rw_policy" {
  name        = "${var.control_plane_name}-rw-policy"
  description = "Allow read/write access to Secrets Manager."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secrets_policy" {
  role       = aws_iam_role.secrets_role.name
  policy_arn = aws_iam_policy.secrets_rw_policy.arn
}

resource "aws_iam_instance_profile" "telekemp_instance_profile" {
  name = "${var.control_plane_name}-profile"
  role = aws_iam_role.secrets_role.name
}
