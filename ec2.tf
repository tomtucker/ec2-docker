# Configure AWS provider using named profile from local AWS CLI configuration.
provider "aws" {
  region  = "us-east-2"
  profile = "default"
}

# Default VPC if one does not exist
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}

# Array of all avalablility zones in region.
data "aws_availability_zones" "available_zones" {}

# Default subnet in the VPC if one does not exist
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}

# Security group for the EC2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "docker host sg"
  description = "Allow inbound access on ports 80 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description = "Allow TCP/80 (HTTP) inbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow TCP/22 (SSH) inbound"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker host sg"
  }
}


# Get array of registered, Amazon Linux 2, AMIs.
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# Launch the EC2 instance using a pre-created EC2 Key Pair
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "ttucker-ec2key" 

  tags = {
    Name = "docker host"
  }
}

# Empty resource block used to connect to the EC2 instance via SSH
resource "null_resource" "name" {

  # ssh into the ec2 instance 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/ttucker-ec2key.pem")
    host        = aws_instance.ec2_instance.public_ip
  }

  # copy the password file for your docker hub account
  # from your computer to the ec2 instance 
  provisioner "file" {
    source      = "~/.docker/docker_passwd.txt"
    destination = "/home/ec2-user/docker_passwd.txt"
  }

  # copy the dockerfile from your computer to the ec2 instance 
  provisioner "file" {
    source      = "Dockerfile"
    destination = "/home/ec2-user/Dockerfile"
  }

  # Copy shell script to EC2 that will:
  #   Install and start Docker
  #   Build the Docker image inside the EC2 instance
  #   Tag and push the image to Docker Hub
  #   Run the container using the image from Docker Hub
  #   and the build_docker_image.sh from your computer to the ec2 instance 
  provisioner "file" {
    source      = "build_docker_image.sh"
    destination = "/home/ec2-user/build_docker_image.sh"
  }

  # set permissions and run the build_docker_image.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/build_docker_image.sh",
      "sh /home/ec2-user/build_docker_image.sh",
    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_instance.ec2_instance]

}


# print the url of the container
output "container_url" {
  value = join("", ["http://", aws_instance.ec2_instance.public_dns])
}