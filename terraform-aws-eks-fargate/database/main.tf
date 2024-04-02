resource "aws_db_subnet_group" "Groups" {
  name       = "db-groups"
  subnet_ids = var.private_subnets

  tags = {
    Name = "DB Subnet Group"
  }
}

resource "aws_security_group" "data" {
  name        = "data-sg"
  description = "Allow MySQL inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL Traffic"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Data Server SG"
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "database"
  description = "Database credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "dbuser"
    password = "dbpassword"
  })
}


data "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.credentials.secret_string)
}

resource "aws_db_instance" "db" {
  identifier             = "${lower(var.identifier)}-${lower(var.environment)}"
  allocated_storage      = var.allocated_storage
  storage_type           = var.storage_type
  iops                   = 1000  # 추가된 IOPS 설정
  engine                 = var.engine
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  db_name                = var.database_name
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.Groups.name
  vpc_security_group_ids = [aws_security_group.data.id]
  username               = local.db_credentials.username
  password               = local.db_credentials.password

  depends_on = [
    aws_db_subnet_group.Groups,
    aws_security_group.data,
    aws_secretsmanager_secret_version.db_credentials
  ]
}

