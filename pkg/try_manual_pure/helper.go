package main

import (
	"context"
	"errors"
	"fmt"
)

func Serve(
	ctx context.Context,
	name string,
	errSet *ErrSet,
	server func(ctx context.Context) error,
) (context.Context, error) {
	select {
	case <-ctx.Done():
		return nil, ctx.Err() // для пропуска инициализации в случае, если где-то уже произошла ошибка
	default:
	}

	ctx, cancel := context.WithCancel(ctx)
	go func() {
		if err := server(context.Background()); err != nil {
			errSet.Add(fmt.Errorf("err serving %q: %w", name, err))
		} else {
			errSet.Add(fmt.Errorf("component %q stopped without an error", name))
		}
		cancel() // даже, если компонент завершил работу без ошибки, всё равно стоит прервать работу всего приложения
	}()

	return ctx, nil
}

func Shutdown(name string, errSet *ErrSet, shutdown func(ctx context.Context) error) {
	if err := shutdown(context.Background()); err != nil &&
		!errors.Is(err, context.Canceled) &&
		!errors.Is(err, context.DeadlineExceeded) {
		errSet.Add(fmt.Errorf("finished %q with error: %w", name, err))
	}
}
