# Terraform Docker Container in AWS EC2

This project uses Terraform to:

1. Create EC2 Instance
    1. Allow HTTP & SSH access
    2. Configure EC2 with existing Key Pair
2. Connect to the EC2 instance using SSH
    1. Install and enable Docker in EC2
    2. Build image
    3. Push image to pre-existing Docker Hub repository
    4. Run Docker container using this image

The pattern for this project (Docker Container in EC2 built from image in Docker Hub) is a bit dated. It is likely more prevalent to use AWS ECR and ECS or EKS.

resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}


# print the url of the container
  value = join("", ["http://", aws_instance.ec2_instance.public_dns])
output "container_url" {
}

The last output from the `terraform apply` is a URL for the container:

>container_url = "http://<EC2-INSTANCE-PUBLIC-IPV4-DNS>"

Use this to browse to the website installed or connect via `ssh` with:

```bash
ssh -i ~/.ssh/my-ec2-key-pair.pem ec2-user@<EC2-INSTANCE-PUBLIC-IPV4-DNS>
```
