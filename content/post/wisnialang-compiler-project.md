---
title: "WisniaLang: Compiler Project"
description: "Can we produce small and fast binaries at the same time?"
date: 2022-10-17
tags: ["c++", "elf", "compiler", "llvm", "rust"]
---

![dragon-book](/post-images/dragon-maid-compiler-book.jpg)

## Introduction

For the past 3 years, I have been working on the <highlight>[WisniaLang](https://github.com/belijzajac/WisniaLang)</highlight> compiler for my own programming language that compiles to native machine code and packs it into an executable by itself. Unlike many others, I rolled out my own compiler backend from scratch that does fast but naive code generation. While it's admittedly a more old-fashioned approach to compiler engineering, it's the path I chose to take when developing my compiler.

## Architecture

![architecture](/post-images/wisnialang-architecture.png)

My compiler's architecture is divided into several main phases that work together to complete this translation. These phases include lexical analysis, which breaks the source code down into smaller pieces called tokens; syntactic analysis, which builds a representation of the structure of the source code called an abstract syntax tree (AST); semantic analysis, which checks the AST for semantic errors while traversing the tree; intermediate representation (IR), which represents the code in a lower-level form close to the target architecture; code generation, which allocates registers and generates machine code from the said IRs; and, lastly, packing the resulting machine code into an executable program in ELF format.

## Programming languages and LLVM

Before going further, let me get straight to the point:

1. Writing compilers is easy
2. Optimizing the machine code is hard
3. Supporting arbitrary architectures / operating systems is hard

![llvm-approach](/post-images/llvm-approach.png)

This is where LLVM comes in handy. LLVM uses an intermediate representation language, which is kind of similar to assembly, but with a few higher level constructs. LLVM is good at optimizing this IR language, as well as compiling into different architecture and binary formats. So as a language author using LLVM, I'm really writing a transpiler from my language to LLVM IR, and letting the LLVM compiler do the hard work.

---

You talk about LLVM so much, why's that? Let me begin with this illustration:

![llvm-family](/post-images/llvm-family.png)

I'm not sure if it's a positive thing, but the LLVM project has achieved such widespread adoption that it's almost reached a monopoly status, much like the Chromium project, for instance. Apart from Google Chrome, numerous other browsers are built upon the Chromium codebase. From Electron web apps to Arc, Microsoft Edge, Opera, Vivaldi, Brave, and beyond, the list just goes on. Firefox and Safari are perhaps the only web browsers that stand out from this copy-paste crowd.

I just wanted to point out that while 99.9% of compiler developers opt for LLVM, the remaining few explore alternative compiler backends like <highlight>[QBE](https://c9x.me/compile/)</highlight>, develop interpreters (like Python), or create virtual machines (such as the JVM for Java and Kotlin). Some even write transpilers that convert high-level languages into something low-level like C, which is then compiled with gcc. If you recall the dragon compiler book appearing at the top of this page, these and similar compiler books are gradually losing relevance because they don't teach how to use LLVM, the industry's compiler standard.

## Benchmark No. 1: Fibonacci sequence

To benchmark different compilers, I chose the Fibonacci sequence without recursion problem and computed the 46th Fibonacci number with each compiler under test. This number was chosen because it conveniently fits within 32 bits. Compile-time and runtime benchmarks were performed using the <highlight>[hyperfine](https://github.com/sharkdp/hyperfine)</highlight> command-line benchmarking tool, which closely resembles Rust's <highlight>[Criterion](https://github.com/bheisler/criterion.rs)</highlight> benchmarking library. Binary size benchmarks were carried out using standard Linux tools like `strip` to remove debug symbols from binaries and `wc` to display byte counts for each binary file.

### WisniaLang benchmark

```rust
fn fibonacci(n: int) -> int {
  if (n <= 1) {
    return n;
  }
  int prev = 0;
  int current = 1;
  for (int i = 2; i <= n; i = i + 1) {
    int next = prev + current;
    prev = current;
    current = next;
  }
  return current;
}

fn main() {
  print(fibonacci(46));
}
```

<h4>Compile time</h4>

```bash
hyperfine --runs 1000 --warmup 10 --shell=none './wisnia fibonacci.wsn'
Benchmark 1: ./wisnia fibonacci.wsn
  Time (mean ± σ):       1.6 ms ±   0.3 ms    [User: 0.8 ms, System: 0.5 ms]
  Range (min … max):     1.3 ms …   8.7 ms    1000 runs
```

<h4>Runtime</h4>

```bash
hyperfine --runs 1000 --warmup 10 --shell=none './a.out'
Benchmark 1: ./a.out
  Time (mean ± σ):     109.6 µs ±  36.8 µs    [User: 58.2 µs, System: 4.7 µs]
  Range (min … max):    84.0 µs … 736.3 µs    1000 runs

```

<h4>Binary size</h4>

```bash
wc -c a.out
421 a.out

```

### C++ (gcc) benchmark

```cpp
#include <iostream>

constexpr auto fibonacci(u_int32_t n) {
  if (n <= 1) {
    return n;
  }
  u_int32_t prev = 0, current = 1;
  for (size_t i = 2; i <= n; i++) {
    u_int32_t next = prev + current;
    prev = current;
    current = next;
  }
  return current;
}

int main() {
  std::printf("%d", fibonacci(46));
}
```

<h4>Compile time</h4>

```bash
hyperfine --runs 100 --warmup 10 --shell=none 'g++ -std=c++23 -O3 fibonacci.cpp'
Benchmark 1: g++ -std=c++23 -O3 fibonacci.cpp
  Time (mean ± σ):     456.4 ms ±   4.5 ms    [User: 415.8 ms, System: 35.2 ms]
  Range (min … max):   448.9 ms … 472.1 ms    100 runs
```

<h4>Runtime</h4>

```bash
hyperfine --runs 1000 --warmup 10 --shell=none './a.out'
Benchmark 1: ./a.out
  Time (mean ± σ):     347.1 µs ±  62.8 µs    [User: 206.4 µs, System: 67.2 µs]
  Range (min … max):   271.9 µs … 926.4 µs    1000 runs
```

<h4>Binary size</h4>

```bash
strip a.out
wc -c a.out
14472 a.out
```

### C++ (clang) benchmark

Same program as before, just different compiler.

<h4>Compile time</h4>

```bash
hyperfine --runs 100 --warmup 10 --shell=none 'clang++ -std=c++2b -O3 fibonacci.cpp'
Benchmark 1: clang++ -std=c++2b -O3 fibonacci.cpp
  Time (mean ± σ):     538.2 ms ±  16.9 ms    [User: 481.7 ms, System: 45.7 ms]
  Range (min … max):   524.3 ms … 657.9 ms    100 runs
```

<h4>Runtime</h4>

```bash
hyperfine --runs 1000 --warmup 10 --shell=none './a.out'
Benchmark 1: ./a.out
  Time (mean ± σ):     351.4 µs ±  67.7 µs    [User: 203.2 µs, System: 72.2 µs]
  Range (min … max):   267.1 µs … 984.8 µs    1000 runs
```

<h4>Binary size</h4>

```bash
strip a.out
wc -c a.out
14504 a.out
```

### Rust benchmark

```rust
fn fibonacci(n: u32) -> u32 {
  if n <= 1 {
    return n;
  }
  let (mut prev, mut current) = (0, 1);
  for _ in 2..=n {
    let next = prev + current;
    prev = current;
    current = next;
  }
  current
}

fn main() {
  println!("{}", fibonacci(46));
}
```

<h4>Compile time</h4>

```bash
hyperfine --runs 100 --warmup 10 --shell=none 'rustc -C opt-level=3 fibonacci.rs'
Benchmark 1: rustc -C opt-level=3 fibonacci.rs
  Time (mean ± σ):     173.4 ms ±   3.0 ms    [User: 130.5 ms, System: 51.2 ms]
  Range (min … max):   168.6 ms … 183.8 ms    100 runs
```

<h4>Runtime</h4>

```bash
hyperfine --runs 1000 --warmup 10 --shell=none './fibonacci'
Benchmark 1: ./fibonacci
  Time (mean ± σ):     490.4 µs ±  82.8 µs    [User: 264.9 µs, System: 129.3 µs]
  Range (min … max):   375.1 µs … 1092.6 µs    1000 runs
```

<h4>Binary size</h4>

```bash
strip fibonacci
wc -c fibonacci
321920 fibonacci
```

## Benchmark No. 2: 29'988 lines of code

I wrote a <highlight>[Python script](/post-data/main.py)</highlight> that generates program code for WisniaLang, C++, and Rust. It generates similar calls to a function named `calculate_1997`, such as `calculate_1`, `calculate_2`, and `calculate_1999`, for over 2000 times:

```cpp
...
void calculate_1997() {
  int i = 0;
  int a = 0;
  int b = 0;
  while (b < 1997) {
    a = a + b + i;
    b = a - b - i;
    int c = a + b;
    int d = a + b + c;
    int e = a + b + c + d;
    int f = a + b + c + d + e;
    i = f - e - d - c + 1;
  }
}
...
int main() {
  ...
  calculate_1997();
  ...
}
```

You can run this script with `python main.py --wisnia --cpp --rust 2000`.

### WisniaLang benchmark

The program can be found at <highlight>[post-data/calculate.wsn](/post-data/calculate.wsn)</highlight>.

<h4>Compile time</h4>

```bash
hyperfine --runs 20 --warmup 1 --shell=none './wisnia calculate.wsn'
Benchmark 1: ./wisnia calculate.wsn
  Time (mean ± σ):      2.367 s ±  0.054 s    [User: 2.328 s, System: 0.036 s]
  Range (min … max):    2.282 s …  2.466 s    20 runs
```

<h4>Binary size</h4>

```bash
wc -c a.out
336025 a.out
```

### C++ (gcc) benchmark

The program can be found at <highlight>[post-data/calculate.cpp](/post-data/calculate.cpp)</highlight>.

<h4>Compile time</h4>

```bash
hyperfine --runs 20 --warmup 1 --shell=none 'g++ -std=c++23 -O3 calculate.cpp'
Benchmark 1: g++ -std=c++23 -O3 calculate.cpp
  Time (mean ± σ):      2.177 s ±  0.009 s    [User: 2.110 s, System: 0.064 s]
  Range (min … max):    2.156 s …  2.193 s    20 runs
```

<h4>Binary size</h4>

```bash
strip a.out
wc -c a.out
96304 a.out
```

### C++ (clang) benchmark

Same program as before, just different compiler.

<h4>Compile time</h4>

```bash
hyperfine --runs 20 --warmup 1 --shell=none 'clang++ -std=c++2b -O3 calculate.cpp'
Benchmark 1: clang++ -std=c++2b -O3 calculate.cpp
  Time (mean ± σ):      2.179 s ±  0.025 s    [User: 2.125 s, System: 0.048 s]
  Range (min … max):    2.156 s …  2.252 s    20 runs
```

<h4>Binary size</h4>

```bash
strip a.out
wc -c a.out
96336 a.out
```

### Rust benchmark

The program can be found at <highlight>[post-data/calculate.rs](/post-data/calculate.rs)</highlight>.

<h4>Compile time</h4>

```bash
hyperfine --runs 20 --warmup 1 --shell=none 'rustc -C opt-level=3 calculate.rs'
Benchmark 1: rustc -C opt-level=3 calculate.rs
  Time (mean ± σ):      2.353 s ±  0.027 s    [User: 2.268 s, System: 0.095 s]
  Range (min … max):    2.324 s …  2.436 s    20 runs
```

<h4>Binary size</h4>

```bash
strip calculate
wc -c calculate
317824 calculate
```

## Results

Combining mean compile time, runtime, and binary sizes from benchmark results, we obtain the following graphs.

![benchmark-results-1](/post-images/benchmark-1.png)

The runtime range for WisniaLang was from `84.0 µs` to `736.3 µs` over 1000 program runs, indicating ambiguous results due to benchmarking a 17-line program that executes 3 lines of code 45 times. However, this does demonstrate the speed at which we can compile small programs. In the future, I plan to report on the recursive Fibonacci sequence.

![benchmark-results-1](/post-images/benchmark-2.png)

WisniaLang generates code as fast as established compilers, but this may be because it doesn't perform many static code analysis or optimization steps. This has resulted in my binary being quite large. In contrast, C++ optimizes out redundant code, simplifying the while loop to use at most three variables. This is the while loop in question:

```cpp
while (b < 1997) {
  a = a + b + i;
  b = a - b - i;
  int c = a + b;
  int d = a + b + c;
  int e = a + b + c + d;
  int f = a + b + c + d + e;
  i = f - e - d - c + 1;
}
```

What I mean is that C++ likely optimized the code to use only three variables -- `a`, `b`, and `i` -- by substituting the values of `c`, `d`, `e`, and `f` directly, thereby reducing redundancy. This is something I'll fix in the future releases of WisniaLang.

## Summary

* If compilation speed and binary size are important, dropping the LLVM toolchain can have a positive impact
* However, doing so means missing out on LLVM optimizations as well as support for arbitrary OSes and architectures
