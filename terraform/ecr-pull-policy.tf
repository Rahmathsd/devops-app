resource "aws_iam_role_policy" "ec2_ecr_pull" {
  name = "devops-ec2-ecr-pull"
  role = aws_iam_role.ec2_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]

        Resource = "arn:aws:ecr:us-east-1:604275788475:repository/devops-app"
      }
    ]
  })
}