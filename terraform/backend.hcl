# Nome legado do backend; a migração do state fica fora desta remoção.
bucket         = "pomi-exchange-terraform-state"
key            = "production/terraform.tfstate"
region         = "sa-east-1"
encrypt        = true
dynamodb_table = "pomi-exchange-terraform-locks"
of these warnings, use the -compact-warnings option.
╵
╷
│ Warning: Value for undeclared variable
│
│ The root module does not declare a variable named "frontend_root_directory" but a value was found in file "terraform.tfvars". If you meant to use this value, add a "variable" block to the configuration.
│
│ To silence these warnings, use TF_VAR_... environment variables to provide certain "global" settings to all configurations in your organization. To reduce the verbosity of these warnings, use the -compact-warnings option.
╵
