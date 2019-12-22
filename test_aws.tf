provider "aws" {
  profile = "default"
  region  = "us-east-1"
  access_key = ***
  secret_key = ***
  
}

resource "aws_vpc" "new_test" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
 
 tags = {
   Name = "new_test"
}
}


resource "aws_subnet" "public" {
  vpc_id = aws_vpc.new_test.id
  cidr_block = "10.0.0.0/24"
  
  tags = {
     Name = "Mt_test_public_subnet"
     }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.new_test.id
}


resource "aws_route_table" "new_test-public" {
    vpc_id = aws_vpc.new_test.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Public_Subnet_route"
    }
}

resource "aws_route_table_association" "public_associations" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.new_test-public.id
}


resource "aws_security_group" "allow_jenkins_ssh" {
  name        = "allow_jenkins_ssh"
  description = "Allow http/ssh inbound traffic"
  vpc_id      = aws_vpc.new_test.id

  ingress {
   
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"    
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"    
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_for jenkins"
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
 }
  
}


resource "aws_security_group" "allow_nginx_ssh" {
  name        = "allow_nginx_ssh"
  description = "Allow http/ssh inbound traffic"
  vpc_id      = aws_vpc.new_test.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { 
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_for_nginx"
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
 }
  
}




resource "aws_key_pair" "terraform-demo" {
  key_name   = "terraform-demo"
  public_key = file("terraform-demo.pub")
}


resource "aws_instance" "jenkins" {
   ami    = "ami-00eb20669e0990cb4"
   instance_type = "t2.micro"
   key_name = aws_key_pair.terraform-demo.key_name
   security_groups = [aws_security_group.allow_jenkins_ssh.id]
   subnet_id=aws_subnet.public.id
   associate_public_ip_address = true
   private_ip = "10.0.0.101"
      
   user_data = <<-EOT
            #!/bin/bash
            sudo yum update -y
            sudo yum remove java -y
            sudo yum install java-1.8.0-openjdk -y
            sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo   
            sudo rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
            sudo yum install jenkins -y
            sudo service jenkins start
            EOT
   tags = {
     Name = "Jenkins"
     }
     
}



resource "aws_instance" "docker" {
   ami    = "ami-00eb20669e0990cb4"
   instance_type = "t2.micro"
   key_name = aws_key_pair.terraform-demo.key_name
   security_groups = [aws_security_group.allow_nginx_ssh.id]
   subnet_id=aws_subnet.public.id
   associate_public_ip_address = true
   private_ip = "10.0.0.102"
      
   user_data = <<-EOT
            #!/bin/bash
            sudo yum update -y
            sudo yum remove java -y
            sudo yum install java-1.8.0-openjdk -y
            
            sudo yum install docker -y
            sudo useradd -m  -d /var/lib/jenkins jenkins
            sudo usermod -aG docker jenkins
            sudo service docker start
            sudo chown root:docker /var/run/docker.sock
            sudo mkdir /var/lib/jenkins/.ssh
            sudo sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0gteqOGRqYLXgACtDyYPEDQYpQOanUAUR5UD+JhilD69PbK8aun4wWRTnuAGEQn/24rP2L9pNkfMd2J+s1DPRDeGs510cl3Xc3XScOzNd0KJ16QXKFTVVcmZl0ZWI9z2iw7iFlbZthGHWbiXDcgD0BDfUqck9pUTKTmQ/HTWmbJveNQDskDo+BOBiGwrWgZQhtlBQnj/ryKWCagkE3TQVp77jMsVgjNrBho6giEMUgOzuesUmKZVN4lBu37RlpOUmKYuquuVY1L7N6QMjMG93TaarHPcO0NFrtXKhrhEZxQq7vmwjRUPFloFFa1AYDTEjm9fqxIcrx3b/fvUdj0eb jenkins' > /var/lib/jenkins/.ssh/authorized_keys"
            sudo chown -R jenkins.jenkins /var/lib/jenkins/.ssh
            sudo chmod 700 /var/lib/jenkins/.ssh
            sudo chmod 600 /var/lib/jenkins/.ssh/authorized_keys
            EOT
            
   tags = {
     Name = "Docker"
     }
     
}


