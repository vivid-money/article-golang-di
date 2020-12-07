package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"errors"
	"net/http"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	logger := log.New(os.Stderr, "", 0)
	logger.Print("Started")

	go func() {
		components.AwaitSignal(ctx)
		cancel()
	}()

	errset := &ErrSet{}

	errset.Add(runApp(ctx, logger, errset))

	_ = errset.Error() // можно обработать ошибку
	/*
		Output:
		---
		Started
		New DBConn
		Connecting DBConn
		Connected DBConn
		New HTTPServer
		Serving HTTPServer
		^CStop HTTPServer
		Stop DBConn
		Stopped DBConn
		Stopped HTTPServer
		Finished serving HTTPServer
	*/
}

func runApp(ctx context.Context, logger components.Logger, errSet *ErrSet) error {
	var err error

	dbConn := components.NewDBConn(logger)
	if err := dbConn.Connect(ctx); err != nil {
		return fmt.Errorf("cant connect dbConn: %w", err)
	}
	defer Shutdown("dbConn", errSet, dbConn.Stop)

	httpServer := components.NewHTTPServer(logger, dbConn)
	if ctx, err = Serve(ctx, "httpServer", errSet, httpServer.Serve); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("cant serve httpServer: %w", err)
	}
	defer Shutdown("httpServer", errSet, httpServer.Stop)

	components.AwaitSignal(ctx)
	return ctx.Err()
}
