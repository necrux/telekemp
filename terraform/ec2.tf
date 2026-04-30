### Nodes

resource "aws_instance" "control_plane" {
  ami             = "${var.ami_id}"
  instance_type   = "${var.control_plane_type}"
  key_name        = "${var.key_name}"
  user_data       = templatefile("scripts/bootstrap.sh", {
    CONTROL_PLANE = "true",
    KUBE_VERSION  = var.kube_version,
    BASE_PACKAGES = join(" ", var.base_packages),
    KUBE_PACKAGES = join(" ", var.kube_packages)
  })

  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]

  tags = {
    Name = "${var.control_plane_name}"
  }
}

resource "aws_instance" "worker" {
  ami             = "${var.ami_id}"
  instance_type   = "${var.worker_type}"
  key_name        = "${var.key_name}"
  count           = var.worker_count
  user_data       = templatefile("scripts/bootstrap.sh", {
    CONTROL_PLANE = "false",
    KUBE_VERSION  = var.kube_version,
    BASE_PACKAGES = join(" ", var.base_packages),
    KUBE_PACKAGES = join(" ", var.kube_packages)
  })

  #associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]

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
