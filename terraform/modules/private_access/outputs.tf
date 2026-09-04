output "target_repository_url" {
  description = "ECR repository the private target image is pushed to."
  value       = aws_ecr_repository.target.repository_url
}

output "target_port" {
  description = "Port to publish in the Private Access application segment."
  value       = var.target_port
}

# The task's address is assigned at run time, so the application segment is
# read from the running task rather than from Terraform state.
output "application_segment_lookup" {
  description = "Command returning the private IP to publish as the application segment."
  value       = "aws ecs list-tasks --cluster ${aws_ecs_cluster.this.name} --query 'taskArns[0]' --output text | xargs -I{} aws ecs describe-tasks --cluster ${aws_ecs_cluster.this.name} --tasks {} --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' --output text"
}

output "connector_instance_id" {
  description = "Instance ID of the connector host, for SSM Fleet Manager."
  value       = aws_instance.connector.id
}

output "availability_zone" {
  description = "Single availability zone holding the test footprint."
  value       = local.availability_zone
}
