# Basic arithmetic operations

# Basic operations - namespace stub
export def "main basic" [] {
  help main basic
}

# Add two numbers
export def "main basic add" [
  a: int # First number
  b: int # Second number
] {
  $a + $b
}

# Subtract second number from first
export def "main basic subtract" [
  a: int # First number
  b: int # Second number
] {
  $a - $b
}

# Multiply two numbers
export def "main basic multiply" [
  a: int # First number
  b: int # Second number
] {
  $a * $b
}

# Divide first number by second
export def "main basic divide" [
  a: float # Numerator
  b: float # Denominator
] {
  if $b == 0 {
    error make {msg: "Division by zero"}
  }
  $a / $b
}
