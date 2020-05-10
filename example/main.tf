provider "aws" {
  region = var.region
}

### Grab the Region
data "aws_region" "current" {}

### CodePipeline Module
module "codepipeline" {
  source                  = "../"
  asg_groups              = [aws_autoscaling_group.asg.name]
  region                  = "us-east-1"
  repo_name               = "examplerepo"
  tag_name_for_codedeploy = "Example-App"
}


### Define the AMI to use (Aamzon Linux 2)
data "aws_ami" "autoscale_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*-x86_64-gp2"]
  }
}

### IAM Resources
data "aws_iam_policy_document" "ec2_instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_codedeploy_role" {
  name               = "ec2-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_role.json
}

data "template_file" "ec2_codedeploy_role_template" {
  template = file("${path.module}/policies/ec2_codedeploy.json")

  vars = {
    aws_kms_key     = module.codepipeline.kms_key_arn
    artifact_bucket = module.codepipeline.artifact_bucket_arn
  }
}

resource "aws_iam_role_policy" "ec2_codedeploy_policy_attach" {
  name   = "ec2-codedeploy-policy"
  role   = aws_iam_role.ec2_codedeploy_role.id
  policy = data.template_file.ec2_codedeploy_role_template.rendered
}

resource "aws_iam_instance_profile" "ec2_codedeploy_instance_profile" {
  name = "ec2-codedeploy-instance-profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}

### Create the AutoScaling Group
resource "aws_autoscaling_group" "asg" {
  name                 = var.asg_name
  vpc_zone_identifier  = var.private_subnets
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.launch_config.name
  target_group_arns    = [aws_alb_target_group.app.arn]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  lifecycle {
    ignore_changes = [
      desired_capacity
    ]
  }

  tags = [
    {
      key                 = "Name"
      value               = var.asg_name
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = var.environment
      propagate_at_launch = true
    }
  ]
}

### Launch Configuration
resource "aws_launch_configuration" "launch_config" {
  security_groups = [
    aws_security_group.instance_sg.id,
    aws_security_group.alb.id
  ]

  name_prefix                 = var.asg_name
  key_name                    = var.key_name
  image_id                    = data.aws_ami.autoscale_ami.id
  instance_type               = var.instance_type
  user_data                   = base64encode(file("${path.module}/bootstrap.sh"))
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.ec2_codedeploy_instance_profile.name

  lifecycle {
    create_before_destroy = true
  }
}

### Auto-Scaling Policy
### Policy - Scale Up
resource "aws_autoscaling_policy" "policy_up" {
  name                   = "autoscale_policy_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

### Alarm - Scale Up
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_up" {
  alarm_name          = "autoscale_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metrics monitors EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.policy_up.arn]
}

### Policy - Scale Down
resource "aws_autoscaling_policy" "policy_down" {
  name                   = "autoscale_policy_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

### Alarm - Scale Down
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_down" {
  alarm_name          = "autoscale_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metrics monitors EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.policy_down.arn]
}

### Security
### Application Load Balancer Security Group
### Modify this to allow ports for your application or to restrict access
resource "aws_security_group" "alb" {
  name        = "terraform-alb"
  description = "Controls Access to the ALB"
  vpc_id      = var.vpcid

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Security Group - EC2 Instance Access
resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = var.vpcid
  name        = "direct-ec2-instance-access"

  ingress {
    description = "Allow direct access from home"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.ec2_allow_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Restrict traffic to the Backend Servers, only allow it to come from the ALB
resource "aws_security_group" "backend" {
  name        = "terraform-backend"
  description = "Allow access from the ALB"
  vpc_id      = var.vpcid

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Application Load Balancer
resource "aws_alb" "main" {
  name            = "${var.alb_name}-ALB"
  subnets         = var.public_subnets
  security_groups = [aws_security_group.alb.id]
}

### Application Load Balancer Target Group
resource "aws_alb_target_group" "app" {
  name        = "${var.alb_name}-TG-80"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpcid
  target_type = "instance"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.alb_name}-TG-80"
  }
}

resource "aws_alb_listener" "app_front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}
