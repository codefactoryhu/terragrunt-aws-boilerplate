# Boilerplate Templates for Terragrunt by Code Factory / Terragrunt sablonok a Code Factory-tól

- [English (ENG)](#english-eng)
- [Magyar (HUN)](#magyar-hun)

---
English (ENG)
## Terragrunt Templates from Code Factory

Overview
This repository contains pre-built AWS infrastructure templates built with Terragrunt.  
With these templates, you can generate consistent, well-structured IaC code for both multi-account and single-account setups. We use Boilerplate for this.

What is Boilerplate?
Boilerplate is a tool that creates files and directories from predefined templates.  
Instead of writing IaC code from scratch manually, you can generate a complete project structure with all the necessary files included using these templates.

> Gruntwork Boilerplate: https://github.com/gruntwork-io/boilerplate  

Options

This repository offers three configurations:
- single-account – For projects using a single AWS account.
- multi-account – For enterprise environments spanning multiple AWS accounts.
- stack – Creates a single, standalone Terragrunt stack file.

The repository is split into branches, with the main branch acting as a router: it uses the same boilerplate command as you will when starting the templating process. Based on your chosen option, it redirects you to the appropriate branch and template. During prompting, Boilerplate will guide you through creating your project.

Getting Started

1) Install Boilerplate  
Follow the official installation guide:  
> Install: https://github.com/gruntwork-io/boilerplate#install  

2) Generate Project  
You don’t need to clone this repository — Boilerplate downloads the templates directly from GitHub.  
Run the following command:

```bash
boilerplate --template-url "github.com/codefactoryhu/terragrunt-aws-boilerplate//terragrunt-boilerplate?ref=main" \
--output-folder ./new-boiler
```

Customize
After generation, review and edit the created files to fit your specific infrastructure needs.
Update variables, resource names, and configurations according to your environment.

---

Magyar (HUN)
## Terragrunt templatek a Code Factory-tól

Áttekintés
Ez a repository előre elkészített, Terragrunttal épített AWS infrastruktúra-templateket tartalmaz.  
A templatekkel generálhatsz egy konzisztens, jól strukturált IAC kódot multy-account és single-account felépítésre is. Ehhez a Boilerplatet használjuk.

Mi az a Boilerplate?
A Boilerplate egy eszköz, amely előre definiált templatekből létre fájlokat és könyvtárakat.  
Ahelyett, hogy az IAC kódot a nulláról, kézzel írnád meg, a a templatekkel teljes projektstruktúra generálható minden szükséges fájllal együtt.

> Gruntwork Boilerplate: https://github.com/gruntwork-io/boilerplate



Opciók:

A repository három konfigurációt kínál:
- single-account - Egyetlen AWS-fiókot használó projektekhez.
- multy-account - Több AWS-fiókot átfogó, enterprise környezetekhez.
- stack - Egyetlen, önálló Terragrunt stack filet hoz létre.

A repositoryt branchekre osztuttuk, a main branch routerként működik: ugyanazt a boilerplate parancshot használja mint te, amikor elkezded a templating folyamatot. A választott opció alapján továbbít a megfelelő branchre és template-re. A prompting során a boilerplate végigvezet majd a projekted elkészítésén.

Kezdő lépések

  1) Boilerplate telepítése
  Kövesd a hivatalos telepítési útmutatót:  
> Install: https://github.com/gruntwork-io/boilerplate#install  

  2) Projekt generálása
  Nem szükséges klónozni ezt a repositoryt — a Boilerplate közvetlenül a GitHubról tölti le a templateket:
  Futtasd az alábbi parancsot:

```bash
boilerplate --template-url "github.com/codefactoryhu/terragrunt-aws-boilerplate//terragrunt-boilerplate?ref=main" \
--output-folder ./new-boiler
```

  3) Testreszabás
  A generálás után nézd át és szerkeszd a létrehozott fájlokat, hogy illeszkedjenek a konkrét infrastruktúra-igényeidhez.
  Frissítsd a változókat, erőforrásneveket és a konfigurációkat a saját környezetednek megfelelően.