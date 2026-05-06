output "control_plane_public_ip" {
  description = "Public IP addresses for the control-plane instance"
  value       = aws_instance.control_plane.public_ip
}

output "worker_private_ips" {
  description = "Private IP addresses for worker instances"
  value       = aws_instance.worker[*].private_ip
}
