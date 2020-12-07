package main

//go:generate wire

import (
	"context"
	"fmt"
	"log"
	"os"

	"errors"
	"net/http"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

// Поскольку wire не поддерживает lifecycle (точнее, поддерживает только Cleanup-функции), а мы не хотим
// делать вызовы компонентов в нужном порядке руками, то придётся написать специальные врапперы для конструкторов,
// которые при этом будут при создании компонента начинать работу и возвращать cleanup-функцию для его остановки.
func NewDBConn(ctx context.Context, logger components.Logger) (*components.DBConn, func(), error) {
	conn := components.NewDBConn(logger)
	if err := conn.Connect(ctx); err != nil {
		return nil, nil, fmt.Errorf("can't connect to db: %w", err)
	}
	return conn, func() {
		if err := conn.Stop(context.Background()); err != nil {
			logger.Print("Error trying to stop dbconn", err)
		}
	}, nil
}

func NewHTTPServer(
	ctx context.Context,
	logger components.Logger,
	conn *components.DBConn,
	closer func(),
) (*components.HTTPServer, func()) {
	srv := components.NewHTTPServer(logger, conn)
	go func() {
		if err := srv.Serve(ctx); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Print("Error serving http: ", err)
		}
		closer()
	}()
	return srv, func() {
		if err := srv.Stop(context.Background()); err != nil {
			logger.Print("Error trying to stop http server", err)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Логгер в качестве исключения создадим заранее, потому что как правило что-то нужно писать в логи сразу, ещё до инициализации графа зависимостей.
	logger := log.New(os.Stderr, "", 0)
	logger.Print("Started")

	// Нужен способ остановить приложение по команде или в случае ошибки. Не хочется отменять "главный" кониекси, так
	// как он прекратит все Server'ы одновременно, что лишит смысла использование cleanup-функций. Поэтому мы будем
	// делать это на другом контексте.
	lifecycleCtx, cancelLifecycle := context.WithCancel(context.Background())
	defer cancelLifecycle()

	// Ничего не делаем с сервером, потому что вызываем Serve в конструкторах.
	_, cleanup, _ := initializeHTTPServer(ctx, logger, func() {
		cancelLifecycle()
	})
	defer cleanup()

	go func() {
		components.AwaitSignal(ctx) // ждём ошибки или сигнала
		cancelLifecycle()
	}()

	<-lifecycleCtx.Done()
	/*
		Output:
		---
		New DBConn
		Connecting DBConn
		Connected DBConn
		New HTTPServer
		Serving HTTPServer
		^CStop HTTPServer
		Stopped HTTPServer
		Stop DBConn
		Stopped DBConn
	*/
}
