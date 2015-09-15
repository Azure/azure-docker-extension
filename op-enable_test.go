package main

import (
	"testing"
)

func Test_composeYaml(t *testing.T) {
	var m = map[string]interface{}{
		"db": map[string]interface{}{
			"image": "postgres"},
		"web": map[string]interface{}{
			"image": "myweb",
			"links": []interface{}{"db"},
			"ports": []interface{}{"8000:8000"}}}

	expected := `db:
  image: postgres
web:
  image: myweb
  links:
  - db
  ports:
  - 8000:8000
`

	yaml, err := composeYaml(m)
	if err != nil {
		t.Fatal(err)
	}
	if yaml != expected {
		t.Fatalf("got wrong yaml: '%s'\nexpected: '%s'", yaml, expected)
	}
}
