---
name: hashicorp-terraform-provider-development-skills-new-terraform-provider
description: Use this when scaffolding a new Terraform provider.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

To scaffold a new Terraform provider with Plugin Framework:

1. If I am already in a Terraform provider workspace, then confirm that I want
   to create a new workspace. If I do not want to create a new workspace, then
   skip all remaining steps.
1. Create a new workspace root directory. The root directory name should be
   prefixed with "terraform-provider-". Perform all subsequent steps in this
   new workspace.
1. Initialize a new Go module..
1. Run `go get -u github.com/hashicorp/terraform-plugin-framework@latest`.
1. Write a `main.go` file that follows this example:
   ```go
   package main

   import (
   	"context"
   	"flag"
   	"log"

   	"github.com/hashicorp/terraform-plugin-framework/providerserver"
   	// "github.com/example/terraform-provider-example/internal/provider"
   )

   func main() {
   	var debug bool
   	flag.BoolVar(&debug, "debug", false, "set to true to run the provider with support for debuggers like delve")
   	flag.Parse()

   	opts := providerserver.ServeOpts{
   		// TODO: Update this string with the published name of your provider.
   		Address: "registry.terraform.io/example/example",
   		Debug:   debug,
   	}

   	// err := providerserver.Serve(context.Background(), provider.New("version"), opts)
   	// if err != nil {
   	// 	log.Fatal(err.Error())
   	// }
   }
   ```
1. Remove TODO comments from `main.go`
1. Run `go mod tidy`
1. Run `go build -o /dev/null`
1. Run `go test ./...`
