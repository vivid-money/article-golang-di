package components

import (
	"context"
	"os"
	"os/signal"
	"syscall"
)

// Простенький хелпер, чтобы не писать один и тот же код несколько раз.
func AwaitSignal(ctx context.Context) {
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-ctx.Done():
	case <-sig:
	}
}
