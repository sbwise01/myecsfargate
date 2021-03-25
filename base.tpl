[
  {
    "image": "amazon/aws-for-fluent-bit:latest",
    "name": "log_router_sumo",
    "cpu": 100,
    "memory": 100,
    "environment": [],
    "essential": true,
    "mountPoints": [],
    "portMappings": [],
    "user": "0",
    "volumesFrom": [],
    "firelensConfiguration": {
      "type": "fluentbit",
      "options": {
        "enable-ecs-log-metadata": "true"
      }
    },
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${loggroup}",
        "awslogs-region": "${region}",
        "awslogs-stream-prefix": "${loggroup}"
      }
    }
  },
  {
    "name": "${name}",
    "image": "${image}",
    "cpu": 412,
    "environment": [],
    "essential": true,
    "mountPoints": [],
    "portMappings": [
      {
        "containerPort": 5000,
        "hostPort": 5000,
        "protocol": "tcp"
      }
    ],
    "volumesFrom": [],
    "logConfiguration": {
      "logDriver": "awsfirelens",
      "options": {
        "Name": "http",
        "Host": "endpoint6.collection.us2.sumologic.com",
        "URI": "/receiver/v1/http/ZaVnC4dhaV3aaXosCZU6Xvo5bN3wk1kiCnYRLWQ6gjueT6cfKonzOlHb5FSruHCG2gFUSiicCa4N7HOJ01K5GfvTdUfhUlOfBZ78R9qM5Q7Y6RWHA3kwpg==",
        "Port": "443",
        "tls": "on",
        "tls.verify": "off",
        "Format": "json_lines"
      }
    }
  }
]