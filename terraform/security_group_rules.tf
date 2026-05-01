### Control Plane Rules
# Control Plane - SSH
resource "aws_vpc_security_group_ingress_rule" "control_plane_ssh" {
  security_group_id = aws_security_group.control_plane_sg.id
  cidr_ipv4         = var.lockdown ? "136.50.255.66/32" : "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Control Plane - Kube API
resource "aws_vpc_security_group_ingress_rule" "control_plane_kube" {
  security_group_id = aws_security_group.control_plane_sg.id
  cidr_ipv4         = var.lockdown ? "136.50.255.66/32" : "0.0.0.0/0"
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

# Control Plane - Kubelet API & Internal Components
resource "aws_vpc_security_group_ingress_rule" "control_plane_kubelet" {
  security_group_id = aws_security_group.control_plane_sg.id
  from_port         = 10250
  to_port           = 10259
  ip_protocol       = "tcp"

  referenced_security_group_id = aws_security_group.control_plane_sg.id
}

# Control Plane - Allow all traffic from Worker Security Group
resource "aws_vpc_security_group_ingress_rule" "from_worker" {
  security_group_id = aws_security_group.control_plane_sg.id
  ip_protocol       = "-1"

  referenced_security_group_id = aws_security_group.worker_sg.id

  depends_on = [
    aws_security_group.control_plane_sg,
    aws_security_group.worker_sg
  ]
}

### Worker Rules
# Worker - SSH
resource "aws_vpc_security_group_ingress_rule" "worker_ssh" {
  security_group_id = aws_security_group.worker_sg.id
  cidr_ipv4         = var.lockdown ? "136.50.255.66/32" : "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Worker - NodePort Services
resource "aws_vpc_security_group_ingress_rule" "worker_node_port" {
  security_group_id = aws_security_group.worker_sg.id
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# Worker - Allow all traffic from Control Plane Security Group
resource "aws_vpc_security_group_ingress_rule" "from_control_plane" {
  security_group_id = aws_security_group.worker_sg.id
  ip_protocol       = "-1"

  referenced_security_group_id = aws_security_group.control_plane_sg.id

  depends_on = [
    aws_security_group.control_plane_sg,
    aws_security_group.worker_sg
  ]
}