package main

import (
	"log"
	"os"

	"github.com/vivid-money/article-golang-di/pkg/components"
)

func doSomething(_ interface{}) {}

func simpleExampleA() {
	logger := log.New(os.Stderr, "", 0)
	dbConn := components.NewDBConn(logger)
	httpServer := components.NewHTTPServer(logger, dbConn)
	doSomething(httpServer)
}

type FakeComponent struct{}

func NewA() (FakeComponent, error) {
	return FakeComponent{}, nil
}

func NewB(_ FakeComponent) (FakeComponent, error) {
	return FakeComponent{}, nil
}

func (FakeComponent) Serve() {}

func (FakeComponent) Stop() {}

func simpleExampleB() {
	a, err := NewA()
	if err != nil {
		panic("cant create a: " + err.Error())
	}
	go a.Serve()
	defer a.Stop()

	b, err := NewB(a)
	if err != nil {
		panic("cant create b: " + err.Error())
	}
	go b.Serve()
	defer b.Stop()
	/*
		Порядок старта: A, B
		Порядок остановки: B, A
	*/
}
