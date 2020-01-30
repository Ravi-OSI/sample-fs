variable region {
}
variable ami {
}
variable instance_type {
}
variable db_instance_type {
}
variable db_instance_name {
}
variable db_user_name {
}
variable db_password {
}

provider "aws" {
  region     = var.region
}

resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "private_key" {
  content  = "${tls_private_key.test_key.private_key_pem}"
  filename = "${path.module}/keys/id_rsa"
}

resource "local_file" "public_key" {
  content  = "${tls_private_key.clusterkey.public_key_openssh}"
  filename = "${path.module}/keys/id_rsa.pub"
}

resource "aws_key_pair" "test_key" {
  key_name   = "test_key"
  public_key = "${file("${path.module}/keys/id_rsa")}"
}

resource "aws_security_group" "testSG_for_pretia" {
  name        = "testSG_for_pretia"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

}

resource "aws_elb" "testELB_for_pretia" {
  name = "testELB_for_pretia"
  security_groups = [
    "${aws_security_group.testSG_for_pretia.id}"
  ]
  cross_zone_load_balancing   = true
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

resource "aws_launch_configuration" "testLC_for_pretia" {
  name   = "testLC_for_pretia"
  image_id      = var.ami
  instance_type = var.instance_type
  key_name      = "${aws_key_pair.test_key.key_name}"
  associate_public_ip_address = true
  user_data = <<USER_DATA
    #!/bin/bash
    sudo yum update
    sudo tee /etc/yum.repos.d/docker.repo <<-'EOF'
       [dockerrepo]
       name=Docker Repository
       baseurl=https://yum.dockerproject.org/repo/main/centos/7/
       enabled=1
       gpgcheck=1
       gpgkey=https://yum.dockerproject.org/gpg
       EOF
    sudo yum install docker-engine -y
    sudo service docker start
    USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "testASG_for_pretia" {
  depends_on = [ aws_elb.testELB_for_pretia,
               ]
  name                 = "testASG_for_pretia"
  launch_configuration = "${aws_launch_configuration.testLC_for_pretia.name}"
  min_size             = 2
  max_size             = 4
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "testRDS_for_pretia" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = var.db_instance_type
  name                 = var.db_instance_name
  username             = var.db_user_name
  password             = var.db_password
}

resource "null_resource" "test_dockerfile_for_pretia" {
  depends_on = [
                 aws_launch_configuration.testLC_for_pretia,
               ]
  connection {
    host = module.ocp.AnsibleHostIp
    type = "ssh"
    user = "ec2-user"
    private_key = "${file("~/.ssh/id_rsa")}"
    agent   = false
    timeout = "5m"
  }

  triggers = {
        launchConfigurationName = "${aws_launch_configuration.testLC_for_pretia.name}"
        docker_file = "${sha1(file("${path.module}/docker/Dockerfile"))}"
    }

  provisioner "local-exec" {
    inline = [ "echo DB_user=${var.DB_user} > ${path.module}/docker/secret.txt", "echo DB_password=${var.DB_password} >> ${path.module}/docker/secret.txt", "echo DB_endpoint=${aws_db_instance.testRDS_for_pretia.endpoint} >> ${path.module}/docker/secret.txt"]
 }
  provisioner "file" {
    source      = "${path.module}/docker"
    destination = "/tmp/"
  }
  provisioner "remote-exec" {
    inline = [ "cd /tmp/docker && docker-compose up -d",]
}
