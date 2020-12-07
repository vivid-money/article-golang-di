package main

import (
	"context"
	"log"
	"os"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	logger := log.New(os.Stderr, "", 0)
	logger.Print("Started")

	lc := lifecycle.NewLifecycle()

	dbConn := components.NewDBConn(logger)
	lc.AddServer(func(ctx context.Context) error { // просто регистриуем в правильном порядке серверы и шатдаунеры
		return dbConn.Connect(ctx)
	}).AddShutdowner(func(ctx context.Context) error {
		return dbConn.Stop(ctx)
	})

	httpSrv := components.NewHTTPServer(logger, dbConn)
	lc.Add(httpSrv) // потому что httpSrv реализует интерфейсы Server и Shutdowner

	go func() {
		components.AwaitSignal(ctx)
		lc.Stop(context.Background())
	}()

	_ = lc.Serve(ctx)
}
