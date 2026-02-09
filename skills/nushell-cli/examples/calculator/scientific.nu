# Scientific operations

# Scientific operations - namespace stub
export def "main sci" [] {
  help main sci
}

# Calculate square root
export def "main sci sqrt" [
  x: float # Number to find square root of
] {
  if $x < 0 {
    error make {msg: "Cannot calculate square root of negative number"}
  }
  $x ** 0.5
}

# Raise base to power
export def "main sci pow" [
  base: float # Base number
  exp: float # Exponent
] {
  $base ** $exp
}

# Calculate factorial
export def "main sci factorial" [
  n: int # Number to calculate factorial of
] {
  if $n < 0 {
    error make {msg: "Factorial not defined for negative numbers"}
  }

  if $n == 0 or $n == 1 {
    1
  } else {
    2..$n | reduce {|it acc| $acc * $it }
  }
}

# Calculate logarithm (base 10)
export def "main sci log" [
  x: float # Number to calculate log of
] {
  if $x <= 0 {
    error make {msg: "Logarithm not defined for non-positive numbers"}
  }
  $x | math log 10
}
