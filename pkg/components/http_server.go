package components

import (
	"context"
	"fmt"
	"net/http"
)

type HTTPServer struct {
	httpSrv *http.Server
	conn    *DBConn
	logger  Logger
}

func NewHTTPServer(logger Logger, conn *DBConn) *HTTPServer {
	logger.Print("New HTTPServer")
	mux := http.NewServeMux()

	s := &HTTPServer{
		conn:   conn,
		logger: logger,
	}
	mux.HandleFunc("/get", func(writer http.ResponseWriter, _ *http.Request) {
		res, err := conn.Query("SELECT * FROM something")
		if err != nil {
			writer.WriteHeader(http.StatusInternalServerError)
			return
		}
		_, _ = writer.Write([]byte(res))
	})
	s.httpSrv = &http.Server{
		Addr:    ":3000",
		Handler: mux,
	}

	return s
}

func (s *HTTPServer) Serve(ctx context.Context) error {
	s.logger.Print("Serving HTTPServer")
	defer s.logger.Print("Finished serving HTTPServer")
	go func() { // вызываем остановку по отмене контекста, так как net/http не умеет работать с контекстами
		<-ctx.Done()
		_ = s.Stop(context.Background())
	}()
	if err := s.httpSrv.ListenAndServe(); err != nil {
		return fmt.Errorf("http listen: %w", err)
	}

	return nil
}

func (s *HTTPServer) Stop(ctx context.Context) error {
	s.logger.Print("Stop HTTPServer")
	defer s.logger.Print("Stopped HTTPServer")
	if err := s.httpSrv.Shutdown(ctx); err != nil {
		return fmt.Errorf("http shutdown: %w", err)
	}

	return nil
}
