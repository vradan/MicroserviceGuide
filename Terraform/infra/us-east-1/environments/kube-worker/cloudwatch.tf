resource "aws_cloudwatch_metric_alarm" "memory-alarm" {
  alarm_name                = "LowMemAvailableAlarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "AvailableMemory"
  namespace                 = "Kubernetes"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "200"
  alarm_description         = "Alarm to monitor Memory Available"
  dimensions {
    Workers = "${aws_autoscaling_group.workers.name}"
  }
  alarm_actions     = ["${aws_autoscaling_policy.memory-policy.arn}"]
}

resource "aws_autoscaling_policy" "memory-policy" {
  name = "Policy to increment workers nodes"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.workers.name}"
}

resource "aws_cloudwatch_metric_alarm" "high-cpu-alarm" {
  alarm_name                = "LowCPUAlarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "70"
  alarm_description         = "Alarm to monitor CPU Utilization"
  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.workers.name}"
  }
  alarm_actions     = ["${aws_autoscaling_policy.high-cpu-policy.arn}"]
}

resource "aws_autoscaling_policy" "high-cpu-policy" {
  name = "Policy to increment workers nodes"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.workers.name}"
}
