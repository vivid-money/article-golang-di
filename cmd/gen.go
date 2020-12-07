// Generates a README.md from the README.tpl and provides some template helpers.
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"strings"
	"text/template"
	"unicode"
	"unicode/utf8"
)

func main() {
	if err := run(); err != nil {
		println(err.Error())
		os.Exit(1)
	}
}

func run() error {
	const tplName = "README.tpl"
	tplVal, err := ioutil.ReadFile(tplName)
	if err != nil {
		return fmt.Errorf("can't read a file %q: %w", tplName, err)
	}

	tpl := template.New("readme").Funcs(template.FuncMap{
		"quote_go_func": func(fileName, funcName string) (string, error) {
			fileVal, err := ioutil.ReadFile(fileName)
			if err != nil {
				return "", fmt.Errorf("can't read a file %q: %w", fileName, err)
			}

			fileValS := string(fileVal)
			f, err := parser.ParseFile(token.NewFileSet(), fileName, fileValS, 0)
			if err != nil {
				return "", fmt.Errorf("can't parse a file %q: %w", fileName, err)
			}
			found := false
			var functionBody string
			ast.Inspect(f, func(node ast.Node) bool {
				if found {
					return false
				}
				fDecl, ok := node.(*ast.FuncDecl)
				if ok && fDecl.Name.Name == funcName && fDecl.Body != nil {
					found = true
					functionBody = fileValS[fDecl.Pos()-1 : fDecl.End()]
					return false
				}

				return true
			})

			if !found {
				return "", fmt.Errorf("can't read a file %q: %w", fileName, err)
			}

			return resetIndents(functionBody), nil
		},
		"quote_go_func_body": func(fileName, funcName string) (string, error) {
			fileVal, err := ioutil.ReadFile(fileName)
			if err != nil {
				return "", fmt.Errorf("can't read a file %q: %w", fileName, err)
			}

			fileValS := string(fileVal)
			f, err := parser.ParseFile(token.NewFileSet(), fileName, fileValS, 0)
			if err != nil {
				return "", fmt.Errorf("can't parse a file %q: %w", fileName, err)
			}
			found := false
			var functionBody string
			ast.Inspect(f, func(node ast.Node) bool {
				if found {
					return false
				}
				fDecl, ok := node.(*ast.FuncDecl)
				if ok && fDecl.Name.Name == funcName && fDecl.Body != nil {
					found = true
					functionBody = fileValS[fDecl.Body.Pos() : fDecl.Body.End()-2]
					return false
				}

				return true
			})

			if !found {
				return "", fmt.Errorf("can't read a file %q: %w", fileName, err)
			}
			return resetIndents(functionBody), nil
		},
		"quote_file": func(fileName string) (string, error) {
			fileVal, err := ioutil.ReadFile(fileName)
			if err != nil {
				return "", fmt.Errorf("can't read a file %q: %w", fileName, err)
			}

			return strings.TrimRight(string(fileVal), "\n"), nil
		},
		"indent": indent,
	})

	if tpl, err = tpl.Parse(string(tplVal)); err != nil {
		return fmt.Errorf("can't parse a template: %w", err)
	}

	const resFileName = "README.md"
	resFile, err := os.Create(resFileName)
	if err != nil {
		return fmt.Errorf("can't create a result file %q: %w", resFileName, err)
	}

	if err = tpl.Execute(resFile, nil); err != nil {
		return fmt.Errorf("can't execute template: %w", err)
	}

	return nil
}

func resetIndents(s string) string {
	minCountOfLeadingSpaces := -1
	lines := strings.Split(strings.Trim(s, "\n"), "\n")
	for _, line := range lines {
		trimmed := strings.TrimLeftFunc(line, unicode.IsSpace)
		if utf8.RuneCountInString(trimmed) == 0 {
			continue
		}
		countOfLeadingSpaces := utf8.RuneCountInString(line) - utf8.RuneCountInString(trimmed)
		if countOfLeadingSpaces < minCountOfLeadingSpaces || minCountOfLeadingSpaces == -1 {
			minCountOfLeadingSpaces = countOfLeadingSpaces
		}
	}
	if minCountOfLeadingSpaces == 0 {
		return s
	}
	res := ""
	for i, line := range lines {
		if i != 0 {
			res += "\n"
		}
		if utf8.RuneCountInString(line) == 0 {
			continue
		}
		res += string([]rune(line)[minCountOfLeadingSpaces:])
	}
	return res
}

func indent(spaces int, v string) string {
	pad := strings.Repeat(" ", spaces)
	return pad + strings.Replace(v, "\n", "\n"+pad, -1)
}
