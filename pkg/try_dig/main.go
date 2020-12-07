package main

import (
	"log"
	"os"

	"go.uber.org/dig"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func main() {
	// Логгер в качестве исключения создадим заранее, потому что как правило что-то нужно писать в логи сразу, ещё до инициализации графа зависимостей.
	logger := log.New(os.Stderr, "", 0)
	logger.Print("Started")

	container := dig.New() // создаём контейнер
	// Регистрируем конструкторы.
	// Dig во время запуска программы будет использовать рефлексию, чтобы по сигнатуре каждой функции понять, что она создаёт и что для этого требует.
	_ = container.Provide(func() components.Logger {
		logger.Print("Provided logger")
		return logger // Прокинули уже созданный логгер.
	})
	_ = container.Provide(components.NewDBConn)
	_ = container.Provide(components.NewHTTPServer)

	_ = container.Invoke(func(_ *components.HTTPServer) {
		// Вызвали HTTPServer, как "корень" графа зависимостей, чтобы прогрузилось всё необходимое.
		logger.Print("Can work with HTTPServer")
		// Никаких средств для управления жизненным циклом нет, пришлось бы всё писать вручную.
	})
	/*
		Output:
		---
		Started
		Provided logger
		New DBConn
		New HTTPServer
		Can work with HTTPServer
	*/
}
