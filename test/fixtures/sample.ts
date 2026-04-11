interface Greeter {
  greet(): string;
}

type ID = string | number;

enum Color {
  Red,
  Green,
  Blue,
}

class Person implements Greeter {
  greet() {
    return "hello";
  }

  walk() {
    return true;
  }
}

function createPerson(): Person {
  return new Person();
}

const helper = () => {
  return 42;
};
