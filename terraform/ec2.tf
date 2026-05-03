### Nodes
resource "aws_instance" "control_plane" {
  ami                = "${var.ami_id}"
  instance_type      = "${var.control_plane_type}"
  key_name           = "${var.key_name}"
  user_data          = templatefile("scripts/bootstrap.sh", {
    REGION           = var.region,
    VPC_ID           = var.vpc_id,
    CONTROL_PLANE    = "true",
    CP_SECRETS       = var.control_plane_secrets,
    KUBE_VERSION     = var.kube_version,
    CALICO_VERSION   = var.calico_version,
    POD_CIDR         = var.pod_cidr,
    BASE_PACKAGES    = join(" ", var.base_packages),
    KUBE_PACKAGES    = join(" ", var.kube_packages),
    NAMESPACE        = var.namespace,
    DEV_ROLE         = var.rw_role,
    SUPPORT_ROLE     = var.ro_role,
    GATEWAY          = tostring(var.deploy_istio),
    ISTIO_VERSION    = var.istio_version,
    TELEPORT         = tostring(var.deploy_teleport),
    TELEPORT_VERSION = var.teleport_version,
    LB_CONTROLLER    = tostring(var.deploy_lb_controller),
    ARGOCD           = tostring(var.deploy_argocd)
  })

  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.cluster_profile.name

  root_block_device {
    volume_size = var.control_plane_disk_size
    volume_type = var.control_plane_disk_type
  }

  tags = {
    Name = "${var.control_plane_name}"
  }

  depends_on = [
    aws_secretsmanager_secret.control_plane_secrets,
  ]

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}

resource "aws_instance" "worker" {
  ami                = "${var.ami_id}"
  instance_type      = "${var.worker_type}"
  key_name           = "${var.key_name}"
  count              = var.worker_count
  user_data          = templatefile("scripts/bootstrap.sh", {
    REGION           = var.region,
    VPC_ID           = var.vpc_id,
    CONTROL_PLANE    = "false",
    CP_SECRETS       = var.control_plane_secrets,
    KUBE_VERSION     = var.kube_version,
    CALICO_VERSION   = var.calico_version,
    POD_CIDR         = var.pod_cidr,
    BASE_PACKAGES    = join(" ", var.base_packages),
    KUBE_PACKAGES    = join(" ", var.kube_packages),
    NAMESPACE        = var.namespace,
    DEV_ROLE         = var.rw_role,
    SUPPORT_ROLE     = var.ro_role,
    GATEWAY          = tostring(var.deploy_istio),
    ISTIO_VERSION    = var.istio_version,
    TELEPORT         = tostring(var.deploy_teleport),
    TELEPORT_VERSION = var.teleport_version,
    LB_CONTROLLER    = tostring(var.deploy_lb_controller),
    ARGOCD           = tostring(var.deploy_argocd)
  })

  #associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.cluster_profile.name

  root_block_device {
    volume_size = var.worker_disk_size
    volume_type = var.worker_disk_type
  }

  tags = {
    Name = "${var.worker_name}-${format("%02d", count.index + 1)}"
  }

  depends_on = [
    aws_secretsmanager_secret.control_plane_secrets,
  ]
}

### Security Groups
resource "aws_security_group" "control_plane_sg" {
  name        = "${var.control_plane_name}-sg"
  vpc_id      = var.vpc_id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
