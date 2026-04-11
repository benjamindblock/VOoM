package main

import "fmt"

type Animal struct {
	Name string
}

func (a *Animal) Speak() string {
	return a.Name
}

type Mover interface {
	Move()
}

func NewAnimal(name string) *Animal {
	return &Animal{Name: name}
}

func main() {
	a := NewAnimal("Dog")
	fmt.Println(a.Speak())
}
