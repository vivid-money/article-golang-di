// +build wireinject

package main

import (
	"context"

	"github.com/google/wire"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func initializeHTTPServer(
	_ context.Context,
	_ components.Logger,
	closer func(), // функция, которая вызовет остановку всего приложения
) (
	res *components.HTTPServer,
	cleanup func(), // функция, которая остановит приложение
	err error,
) {
	wire.Build(
		NewDBConn,
		NewHTTPServer,
	)
	return &components.HTTPServer{}, nil, nil
}
