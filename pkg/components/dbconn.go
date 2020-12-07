package components

import (
	"context"
	"sync"
)

// Fake db connection.
type DBConn struct {
	logger Logger
	once   sync.Once
}

func NewDBConn(logger Logger) *DBConn {
	logger.Print("New DBConn")
	return &DBConn{
		logger: logger,
	}
}

func (h *DBConn) Connect(ctx context.Context) error {
	h.logger.Print("Connecting DBConn")
	defer h.logger.Print("Connected DBConn")
	go func() { // эмулируем остановку соединения по отмене контекста
		<-ctx.Done()
		_ = h.Stop(context.Background())
	}()
	return nil
}

func (h *DBConn) Stop(_ context.Context) error {
	h.once.Do(func() {
		h.logger.Print("Stop DBConn")
		defer h.logger.Print("Stopped DBConn")
	})
	return nil
}

func (h *DBConn) Query(_ string) (string, error) {
	return "Fake result", nil
}
