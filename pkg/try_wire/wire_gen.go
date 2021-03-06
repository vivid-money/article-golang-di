// Code generated by Wire. DO NOT EDIT.

//go:generate wire
//+build !wireinject

package main

import (
	"context"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

// Injectors from wireinject.go:

func initializeHTTPServer(contextContext context.Context, logger components.Logger, closer func()) (*components.HTTPServer, func(), error) {
	dbConn, cleanup, err := NewDBConn(contextContext, logger)
	if err != nil {
		return nil, nil, err
	}
	httpServer, cleanup2 := NewHTTPServer(contextContext, logger, dbConn, closer)
	return httpServer, func() {
		cleanup2()
		cleanup()
	}, nil
}
