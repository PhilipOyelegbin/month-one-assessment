output "outputs" {
  description = "RDS Endpoint"
  value       = <<EOF
  🚨 Deployment Output
  VPC ID: ${aws_vpc.vpc.id}
  Load Balancer DNS Name: ${aws_lb.app-lb.dns_name}
  Bastion public IP: ${aws_instance.bastion-server.public_ip}
  🎉 Infrastructure deployed successfully!
  EOF
}