resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "github-actions-ssm"
  role = "GitHubActionsECRRole"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ssm:SendCommand"
        ]

        Resource = [
          "arn:aws:ssm:us-east-1::document/AWS-RunShellScript",
          "arn:aws:ec2:us-east-1:604275788475:instance/i-0ded0f957ec08989b"
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "ssm:GetCommandInvocation"
        ]

        Resource = "*"
      }
    ]
  })
}