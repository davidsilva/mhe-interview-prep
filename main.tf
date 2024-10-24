provider "aws" {
  region = var.region
  profile = "aws-cli-user"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "interview-prep-vpc"
  }
}

# Create subnets. subnet_a and subnet_b are public subnets, db_subnet_a and db_subnet_b are private subnets
resource "aws_subnet" "subnet_a" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.subnet_a_cidr
  availability_zone = var.availability_zone_a
  tags = {
    Name = "interview-prep-subnet-a"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.subnet_b_cidr
  availability_zone = var.availability_zone_b
  tags = {
    Name = "interview-prep-subnet-b"
  }
}

resource "aws_subnet" "db_subnet_a" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.db_subnet_a_cidr
  availability_zone = var.availability_zone_a
  tags = {
    Name = "interview-prep-db-subnet-a"
  }
}

resource "aws_subnet" "db_subnet_b" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.db_subnet_b_cidr
  availability_zone = var.availability_zone_b
  tags = {
    Name = "interview-prep-db-subnet-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "interview-prep-igw"
  }
}

# Create a Route Table for general-purpose subnets
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "interview-prep-route-table"
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "assoc_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "assoc_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.route_table.id
}

# Associate Route Table with DB Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "interview-prep-private-route-table"
  }
}

resource "aws_route_table_association" "db_assoc_a" {
  subnet_id      = aws_subnet.db_subnet_a.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "db_assoc_b" {
  subnet_id      = aws_subnet.db_subnet_b.id
  route_table_id = aws_route_table.private_route_table.id
}

# Route for private subnets to use NAT Gateway
resource "aws_route" "private_route" {
  route_table_id = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gw.id
}

# Security Group for EC2. Frontend security group.
resource "aws_security_group" "frontend_sg" {
  name = "interview-prep-frontend-sg"
  description = "Managed by Terraform"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow all HTTP traffic
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow all HTTPS traffic
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Allow bastion host to ssh in
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "interview-prep-frontend-sg"
  }
}

# Backend security group
# ssh in from bastion, allow traffic from frontend
resource "aws_security_group" "backend_sg" {
  name = "interview-prep-backend-sg"
  description = "Managed by Terraform"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    security_groups = [aws_security_group.frontend_sg.id] # Allow traffic from frontend
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Allow bastion host to ssh in
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "interview-prep-backend-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "db_sg" {
  name = "interview-prep-db-sg"
  description = "Managed by Terraform"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.backend_sg.id, aws_security_group.bastion_sg.id] # Allow traffic from backend and bastion
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "interview-prep-db-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "interview-prep-db-subnet-group"
  description = "Managed by Terraform"
  subnet_ids = [aws_subnet.db_subnet_a.id, aws_subnet.db_subnet_b.id]

  tags = {
    Name = "interview-prep-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "interviewprepdbinstance"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "16.4"
  username                = var.db_username
  password                = var.db_password
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot     = true
  apply_immediately       = false
  publicly_accessible = false
  tags                    = {}
}

# EC2 Instance
resource "aws_instance" "app_instance" {
  ami = "ami-0fff1b9a61dec8a5f"
  instance_type = "t2.micro"
  key_name = "OnyxKeyPair"
  network_interface {
    network_interface_id = aws_network_interface.app_network_interface.id
    device_index = 0
  }
  tags = {
    Name = "interview-prep-app-instance"
  }
}

resource "aws_network_interface" "app_network_interface" {
  subnet_id = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.frontend_sg.id]
  tags = {
    Name = "interview-prep-app-network-interface"
  }
}

# Elastic IP
resource "aws_eip" "app_eip" {
  associate_with_private_ip = aws_instance.app_instance.private_ip
}

resource "aws_eip_association" "app_eip_assoc" {
  allocation_id = aws_eip.app_eip.id
  instance_id = aws_instance.app_instance.id
}

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "interview-prep-nat-eip"
  }
}

# NAT Gateway for Outbound Internet Access from private subnets
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.subnet_a.id # Public subnet
  tags = {
    Name = "interview-prep-nat-gw"
  }
}

resource "aws_ecr_repository" "frontend" {
  name = "interview-prep-frontend"
}

resource "aws_ecr_repository" "backend" {
  name = "interview-prep-backend"
}

resource "aws_ecs_cluster" "main" {
  name = "interview-prep-cluster"
}

resource "aws_ecs_task_definition" "frontend" {
  family = "interview-prep-frontend"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name = "frontend"
      image = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort = 80
          protocol = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family = "interview-prep-backend"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name = "backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort = 3000
        }
      ]
      environment = [
        {
          name = "DATABASE_URL"
          value = "postgres://$${DB_USERNAME}:$${DB_PASSWORD}@interviewprepdbinstance:5432/interviewprepdb"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "frontend" {
  name            = "interview-prep-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.subnet_a.id, aws_subnet.db_subnet_b.id]
    security_groups = [aws_security_group.frontend_sg.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "backend" {
  name            = "interview-prep-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    security_groups = [aws_security_group.backend_sg.id]
    assign_public_ip = false
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "interview-prep-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# Security Group for EC2
# This actually isn't used but I'm having trouble deleting it because of dependencies
resource "aws_security_group" "ec2_sg" {
  name = "interview-prep-ec2-sg"
  description = "Managed by Terraform"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["45.147.172.140/32"]  # Allow VPN
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "interview-prep-ec2-sg"
  }
}

resource "aws_security_group" "bastion_sg" {
  name = "interview-prep-bastion-sg"
  description = "Managed by Terraform"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["45.147.172.140/32"]  # Allow VPN
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "interview-prep-bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami = "ami-0fff1b9a61dec8a5f"
  instance_type = "t2.micro"
  key_name = "OnyxKeyPair"
  network_interface {
    network_interface_id = aws_network_interface.bastion_eni.id
    device_index = 0
  }

  tags = {
    Name = "interview-prep-bastion"
  }
}

resource "aws_eip" "bastion_eip" {
  tags = {
    Name = "interview-prep-bastion-eip"
  }
}

resource "aws_network_interface" "bastion_eni" {
  subnet_id = aws_subnet.subnet_a.id
  security_groups = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "interview-prep-bastion-eni"
  }
}

resource "aws_eip_association" "bastion_eip_assoc" {
  allocation_id = aws_eip.bastion_eip.id
  network_interface_id = aws_network_interface.bastion_eni.id
}
