# Setting your provider
terraform {
  required_version = "1.13.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.17.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#============================================ Network Resources ============================================#
# Get current IP for SSH access
data "http" "my_ip" {
  url = "http://ipv4.icanhazip.com"
}

# Fetch available availability zones for your region
data "aws_availability_zones" "available" {
  state = "available"
}

# creating a vpc
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Creating public subnet
resource "aws_subnet" "public-subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet_cidr[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier = "public"
  }

  depends_on = [aws_vpc.vpc]
}

# Creating private subnet
resource "aws_subnet" "private-subnet" {
  count             = 2
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet_cidr[count.index + 2]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Tier = "private"
  }

  depends_on = [aws_vpc.vpc]
}

# Creating an internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-ig"
  }

  depends_on = [aws_vpc.vpc]
}

# Creating an elastic IP for NAT Gateway
resource "aws_eip" "nat-eip" {
  count  = length(aws_subnet.public-subnet)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

# Creating a NAT gateway in the first PUBLIC subnet
resource "aws_nat_gateway" "nat" {
  count         = length(aws_subnet.public-subnet)
  subnet_id     = aws_subnet.public-subnet[count.index].id
  allocation_id = aws_eip.nat-eip[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.ig]
}

# Creating a public route table
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }

  depends_on = [aws_vpc.vpc]
}

# Associating public subnets with the public route table
resource "aws_route_table_association" "public-subnet-assoc" {
  count          = 2
  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.public-rt.id
}

# Creating a private route table
resource "aws_route_table" "private-rt" {
  count  = length(aws_subnet.private-subnet)
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

# Associating private subnets with the private route table
resource "aws_route_table_association" "private-subnet-assoc" {
  count          = length(aws_subnet.private-subnet)
  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.private-rt[count.index].id
}

#============================================ Security Groups ============================================#
resource "aws_security_group" "bastion-sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
    Tier = "bastion"
  }
}

resource "aws_security_group" "web-sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
    Tier = "web"
  }
}

resource "aws_security_group" "database-sg" {
  name        = "${var.project_name}-database-sg"
  description = "Allow custom inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "MySQL access"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
  }

  ingress {
    description     = "SSH access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-database-sg"
    Tier = "database"
  }
}

#============================================ Server Instance ============================================#
# Define the AMI data source to fetch the latest Ubuntu AMI
data "aws_ami" "amazon" {
  most_recent = true

  filter {
    name   = "name"
    values = var.ami_details.values
  }

  owners = var.ami_details.owners
}

# Define SSH keypair
resource "aws_key_pair" "deployer-key" {
  key_name   = "${var.project_name}-${var.keypair_name}"
  public_key = file("${path.module}/id_rsa.pub")
}

# Creating an EC2 instance as a bastion host
resource "aws_instance" "bastion-server" {
  ami                         = data.aws_ami.amazon.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public-subnet[0].id
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  key_name                    = aws_key_pair.deployer-key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-bastion-server"
    Tier = "bastion"
  }
}

# Creating two EC2 instance as a web host
resource "aws_instance" "web-servers" {
  count                       = 2
  ami                         = data.aws_ami.amazon.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private-subnet[count.index].id
  vpc_security_group_ids      = [aws_security_group.web-sg.id]
  key_name                    = aws_key_pair.deployer-key.key_name
  associate_public_ip_address = false

  user_data = file("${path.module}/user_data/web_server_setup.sh")

  tags = {
    Name = "${var.project_name}-web-server-${count.index + 1}"
    Tier = "web"
  }
}

# Creating an EC2 instance as a database host
resource "aws_instance" "database-server" {
  ami                    = data.aws_ami.amazon.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private-subnet[0].id
  vpc_security_group_ids = [aws_security_group.database-sg.id]
  key_name               = aws_key_pair.deployer-key.key_name

  user_data = file("${path.module}/user_data/db_server_setup.sh")

  tags = {
    Name = "${var.project_name}-database-server"
    Tier = "database"
  }
}

#============================================ Load Balancer ============================================#
# Creating a target group for the web servers
resource "aws_lb_target_group" "web-tg" {
  name     = "${var.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}

# Attaching web servers to the target group
resource "aws_lb_target_group_attachment" "web-tg-at" {
  count            = 2
  target_group_arn = aws_lb_target_group.web-tg.arn
  target_id        = aws_instance.web-servers[count.index].id
  port             = 80
}

# Creating an application load balancer
resource "aws_lb" "app-lb" {
  name                       = "${var.project_name}app-lb"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = [aws_subnet.public-subnet[0].id, aws_subnet.public-subnet[1].id]
  security_groups            = [aws_security_group.web-sg.id]
  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-app-lb"
  }
}

# Creating a listener for the load balancer
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-tg.arn
  }
}
