package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"go.uber.org/fx"

	"errors"
	"net/http"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Логгер в качестве исключения создадим заранее, потому что как правило что-то нужно писать в логи сразу, ещё до
	// инициализации графа зависимостей.
	logger := log.New(os.Stderr, "", 0)
	logger.Print("Started")

	// На этот раз используем fx, здесь уже у нас появляется объект "приложения".
	app := fx.New(
		fx.Provide(func() components.Logger {
			return logger // Добавляем логгер как внешний компонент.
		}),
		fx.Provide(
			func(logger components.Logger, lc fx.Lifecycle) *components.DBConn { // можем получить ещё и lc - жизненный цикл.
				conn := components.NewDBConn(logger)
				// Можно навесить хуки.
				lc.Append(fx.Hook{
					OnStart: func(ctx context.Context) error {
						if err := conn.Connect(ctx); err != nil {
							return fmt.Errorf("can't connect to db: %w", err)
						}
						return nil
					},
					OnStop: func(ctx context.Context) error {
						return conn.Stop(ctx)
					},
				})
				return conn
			},
			func(logger components.Logger, dbConn *components.DBConn, lc fx.Lifecycle) *components.HTTPServer {
				s := components.NewHTTPServer(logger, dbConn)
				lc.Append(fx.Hook{
					OnStart: func(_ context.Context) error {
						go func() {
							defer cancel()
							// Ассинхронно запускаем сервер, т.к. Serve - блокирующая операция.
							if err := s.Serve(context.Background()); err != nil && !errors.Is(err, http.ErrServerClosed) {
								logger.Print("Error: ", err)
							}
						}()
						return nil
					},
					OnStop: func(ctx context.Context) error {
						return s.Stop(ctx)
					},
				})
				return s
			},
		),
		fx.Invoke(
			// Конструкторы - "ленивые", так что нужно будет вызвать корень графа зависимостей, чтобы прогрузилось всё необходимое.
			func(*components.HTTPServer) {
				go func() {
					components.AwaitSignal(ctx) // ожидаем сигнала, чтобы после этого завершить приложение.
					cancel()
				}()
			},
		),
		fx.NopLogger,
	)

	_ = app.Start(ctx)

	<-ctx.Done() // ожидаем завершения контекста в случае ошибки или получения сигнала

	_ = app.Stop(context.Background())
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
		Stopped HTTPServer
		Stop DBConn
		Stopped DBConn
	*/
}
