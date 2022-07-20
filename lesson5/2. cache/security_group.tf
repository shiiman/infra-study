resource "aws_security_group" "sg_cache" {
  name   = "${var.user_name}-cache-sg"
  vpc_id = module.before.vpc_id

  tags = {
    Name = "${var.user_name}-cache-sg"
  }
}

# webインスタンスからcacheへのredis
resource "aws_security_group_rule" "security_group_rule_web_instance_to_cache_redis" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.before.sg_web_instance_id
  source_security_group_id = resource.aws_security_group.sg_cache.id
}

# webインスタンスからcacheへのredis
resource "aws_security_group_rule" "security_group_rule_cache_from_web_instance_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_cache.id
  source_security_group_id = module.before.sg_web_instance_id
}
