package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"golang.org/x/sync/errgroup"

	"errors"
	"net/http"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	logger := log.New(os.Stderr, "", 0)
	logger.Print("Started")

	g, gCtx := errgroup.WithContext(ctx)

	dbConn := components.NewDBConn(logger)
	g.Go(func() error {
		// dbConn умеет останавливаться по отмене контекста.
		if err := dbConn.Connect(gCtx); err != nil {
			return fmt.Errorf("can't connect to db: %w", err)
		}
		return nil
	})
	httpServer := components.NewHTTPServer(logger, dbConn)
	g.Go(func() error {
		go func() {
			// предположим, что httpServer (как и http.ListenAndServe, кстати) не умеет останавливаться по отмене
			// контекста, тогда придётся добавить обработку отмены вручную.
			<-gCtx.Done()
			if err := httpServer.Stop(context.Background()); err != nil {
				logger.Print("Stopped http server with error:", err)
			}
		}()
		if err := httpServer.Serve(gCtx); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("can't serve http: %w", err)
		}
		return nil
	})

	go func() {
		components.AwaitSignal(gCtx)
		cancel()
	}()

	_ = g.Wait()

	/*
		Output:
		---
		Started
		New DBConn
		New HTTPServer
		Connecting DBConn
		Connected DBConn
		Serving HTTPServer
		^CStop HTTPServer
		Stop DBConn
		Stopped DBConn
		Stopped HTTPServer
		Finished serving HTTPServer
	*/
}
