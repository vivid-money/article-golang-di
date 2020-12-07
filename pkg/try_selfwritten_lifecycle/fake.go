package main

import "context"

var lifecycle *Lifecycle // to emulate a "Lifecycle" package

type Lifecycle struct{}

func (l *Lifecycle) NewLifecycle() *Lifecycle {
	return &Lifecycle{}
}

func (l *Lifecycle) AddServer(_ func(_ context.Context) error) *Lifecycle {
	return &Lifecycle{}
}

func (l *Lifecycle) Add(_ interface{}) *Lifecycle {
	return &Lifecycle{}
}

func (l *Lifecycle) AddShutdowner(_ func(_ context.Context) error) *Lifecycle {
	return &Lifecycle{}
}

func (l *Lifecycle) Stop(_ context.Context) {
}

func (l *Lifecycle) Serve(_ context.Context) error {
	return nil
}
