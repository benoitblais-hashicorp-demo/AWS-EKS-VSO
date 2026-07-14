// Copyright IBM Corp. 2024, 2026

package tools

import "os"

func GetEnvVariable(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
