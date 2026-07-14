// Copyright IBM Corp. 2024, 2026

package app

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Message struct {
	Message string `json:"message"`
}

func StartUp() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(gin.LoggerWithConfig(gin.LoggerConfig{
		SkipPaths: []string{"/health"},
	}))

	router.LoadHTMLGlob("/app/templates/*")
	router.Static("/resources", "/app/resources")
	router.GET("/health", func(ctx *gin.Context) {
		ctx.Writer.Header().Set("Content-Type", "application/json")
		ctx.JSON(http.StatusOK, Message{
			Message: "I'm alive!",
		})
	})
	router.NoRoute(func(ctx *gin.Context) {
		ctx.Writer.Header().Set("Content-Type", "application/json")
		ctx.JSON(http.StatusOK, Message{
			Message: "Sorry, the path you requested is not available.",
		})
	})

	return router
}
