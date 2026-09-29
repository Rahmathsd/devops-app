resource "aws_iam_role_policy" "ec2_secrets" {
  name = "devops-ec2-secrets"
  role = aws_iam_role.ec2_ecr.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = "arn:aws:secretsmanager:us-east-1:604275788475:secret:devops-app/db-password-*"
      }
    ]
  })
}