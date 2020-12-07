package main

import (
	"context"
	"errors"
	"sync"

	"go.uber.org/multierr"
)

type ErrSet struct {
	mtx sync.Mutex
	err error
}

func (s *ErrSet) Add(err error) {
	if err == nil {
		return
	}
	s.mtx.Lock()
	defer s.mtx.Unlock()
	if s.err != nil && (errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded)) {
		// Second context.Cancel should be ignored to avoid duplicate errors.
		return
	}

	s.err = multierr.Append(s.err, err)
}

func (s *ErrSet) Error() error {
	return s.err
}
