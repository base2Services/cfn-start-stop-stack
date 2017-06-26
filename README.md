# cfn-library
Common Cloud Formation stacks functionality


## Stack traversal

Used to traverse through stack and all it's substacks

## Start-stop environment

For stop:

- Set all ASG's size to 0
- Stops RDS instances
- If RDS instance is Multi-AZ, it is converted to single-az prior it
  is being stopped


For start:

- Set all ASG's size to what was prior stop operation
- Starts ASG instances
- If ASG instance was Mutli-AZ, it is converted back to Multi-AZ
