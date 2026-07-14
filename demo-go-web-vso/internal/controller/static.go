// Copyright IBM Corp. 2024, 2026

package controller

import (
	"github.com/benoitblais-hashicorp-demo/AWS-EKS-VSO/demo-go-web-vso/internal/tools"
	"github.com/gin-gonic/gin"
)

func GetStaticPage(c *gin.Context) {
	// The application consumes secrets transparently via standard environment variables.
	// It has no knowledge of Vault, Kubernetes Secrets, or VSO.
	firstMessage := tools.GetEnvVariable("FIRST_MESSAGE", "")
	centralImage := tools.GetEnvVariable("IMAGE_URL", "https://avatars.githubusercontent.com/u/320148?v=4")

	c.HTML(200, "static.html", gin.H{
		"Title":        tools.GetEnvVariable("TITLE", ""),
		"SubTitle":     tools.GetEnvVariable("SUB_TITLE", ""),
		"FirstMessage": firstMessage,
		"CentralImage": centralImage,
		"LearnMoreURL": tools.GetEnvVariable("LEARN_LINK", ""),
	})
}
