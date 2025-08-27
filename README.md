## Boilerplate Templates for Terragrunt by Code Factory

This repository contains ready-to-use AWS infrastructure templates built with Terragrunt. These templates help you quickly set up consistent, well-structured infrastructure across different environments and account configurations.

### What is Boilerplate?

Boilerplate is a powerful templating tool that generates files and directories from predefined templates. Instead of manually creating infrastructure code from scratch, you can use these templates to generate a complete project structure with all the necessary files.

[Learn more about Boilerplate](https://github.com/gruntwork-io/boilerplate)

### Template Options

This repository offers three different template configurations:

- single-account:  Perfect for projects that deploy infrastructure within a single AWS account.
- multy-account:  Designed for enterprise-grade setups that require infrastructure spanning multiple AWS accounts.
- stack:  Creates a single, self-contained Terragrunt stack deployment. It's lightweight and focused on single-purpose deployments.

The main branch automatically guides you through selecting the most appropriate template for your specific use case.

#### Getting Started
- Install Boilerplate: Follow the installation instructions from the [official Boilerplate repository](https://github.com/gruntwork-io/boilerplate#install)

- Generate your project: Run the following command to create a new project structure. You don't need to clone this repository - Boilerplate will fetch the templates directly from GitHub:


```bash
boilerplate --template-url "github.com/codefactoryhu/terragrunt-aws-boilerplate//terragrunt-boilerplate?ref=main" \
--output-folder ./new-boiler
```

This command will guide you through the templating process.

Customize for your project: After generation, review and edit the generated files to match your specific infrastructure requirements. Update variables, resource names, and configurations as needed for your environment.
