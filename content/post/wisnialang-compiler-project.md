---
title: "WisniaLang: Compiler Project"
description: "Can we produce small and fast binaries at the same time?"
date: 2022-10-17
tags: ["c++", "elf", "compiler", "llvm", "rust"]
---

![dragon-book](/post-images/dragon-maid-compiler-book.jpg)

## Introduction

For the past 3 years, I have been working on the <mark>[WisniaLang](https://github.com/belijzajac/WisniaLang)</mark> compiler for an experimental programming language that compiles to native machine code. It focuses on delivering tiny Linux binaries (`ELF` `x86_64`) with no LLVM dependency. As a result, what it actually competes with is the LLVM toolchain, on which a large number of other programming languages rely extensively.

The reason for focusing on the delivery of small binaries with no LLVM dependency is to offer an alternative to the LLVM toolchain. While LLVM is a powerful and widely-used toolchain, it can be quite resource-intensive and may not be suitable for all scenarios. By offering a compiler that can produce efficient machine code without the need for LLVM, my aim is to provide a more lightweight and flexible solution for those who need it.

## Architecture

![architecture](/post-images/wisnialang-architecture.png)

The architecture of the compiler consists of several main phases, which work together to perform this translation. These phases include lexical analysis, which breaks the source code down into smaller units called tokens; syntactic analysis, which builds a representation of the structure of the source code called an abstract syntax tree (AST); semantic analysis, which checks the AST for semantic errors and performs type checking; intermediate representation (IR), which represents the code in a lower-level form that is easier for the compiler to work with; code generation, which generates machine code from the IR; optimization, which improves the performance of the machine code; and linking, which combines the machine code to create a complete executable program in ELF (Executable and Linking Format) format.

## Programming languages and LLVM

Before going further, let me get straight to the point:

1. Writing compilers is easy
2. Optimizing the machine code is hard
3. Supporting arbitrary architectures / operating systems is hard

![llvm-approach](/post-images/llvm-approach.png)

This is where LLVM comes in handy. LLVM uses an intermediate representation language, which is kind of similar to assembly, but with a few higher level constructs. LLVM is good at optimizing this IR language, as well as compiling into different architecture / binary formats. So as a language author using LLVM, I'm really writing a transpiler from my language -> LLVM IR, and letting the LLVM compiler do the hard work.

<center><img src="/post-images/wisnialang-approach.png"></center>
<br>

WisniaLang is an amateurish project that takes a more traditional approach to compiler design compared to other LLVM-based programming languages. Despite its amateur status, WisniaLang still follows the same front-end procedures as other programming languages in the LLVM family. However, it differs in the way it handles certain tasks, such as register allocation, machine code generation, and ELF binary format construction. Instead of relying on LLVM or other external tools for these tasks, WisniaLang handles them on its own. This approach allows WisniaLang to have more control over the compilation process, but it also requires more work and expertise on the part of its developers.

## Example programs

Let's take a look at simple programs and see how a handwritten compiler compares to Rust, an LLVM-based programming language. Both compilers generate the identical number sequence, `3000 2997 ... 6 3 1`, for both programs.

<table>
<tr><th>WisniaLang</th><th>Rust</th></tr>
<tr><td>

```rust
fn foo(base: int, number: int) {                    
  if (number) {
    print(base * number, " ");
    foo(base, number - 1);
  }
}

fn main() {
  foo(3, 1000);
  print("1\n");
}
```

</td><td>

```rust
fn foo(base: u16, number: u16) {                    
  if number > 0 {
    print!("{} ", base * number);
    foo(base, number - 1);
  }
}

fn main() {
  foo(3, 1000);
  print!("1\n");
}
```

</td></tr></table>

Since I was asked to include C in the benchmark, as it has been a standard for performance for almost half a century and it is something that every benchmark of a language attempting to surpass it should include, here is an example program in C:

```c
#include <stdint.h>
#include <stdio.h>

void foo(uint16_t base, uint16_t number) {
  if (number) {
    printf("%u ", base * number);
    foo(base, number - 1);
  }
}

int main() {
  foo(3, 1000);
  printf("1\n");
}
```

## A dive deeper

Let us now compare the final size of the produced binaries, as well as the time it took to assemble and run them.  <mark>TLDR: If you wish to skip the lenghty blabberings and view the results as a graphic representation, scroll to the bottom of the page.</mark>

### WisniaLang

```bash
┌─[tautvydas][kagamin][~/tests]
└─▪ time ./wisnia test.wsn
real    0m0.004s
user    0m0.002s
sys     0m0.001s

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh a.out
-rwxrwxrwx 1 tautvydas tautvydas 528 Dec 27 17:20 a.out

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./a.out
3000 2997 2994 2991 (omitted by the author)

real    0m0.004s
user    0m0.000s
sys     0m0.004s
```

Running 20 times, the results averaged out to:

* Compilation time: `3.3 ms`
* Size of the binary: `0.515 KiB`
* Runtime speed: `4.25 ms`

### C

```bash
┌─[tautvydas][kagamin][~/tests]
└─▪ time gcc test.c
real    0m0.040s
user    0m0.025s
sys     0m0.015s

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh a.out
-rwxr-xr-x 1 tautvydas tautvydas 16K Dec 27 12:39 a.out

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./a.out
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.001s
sys     0m0.001s
```

Running 20 times, the results averaged out to:

* Compilation time: `38.05 ms`
* Size of the binary: `16 KiB`
* Runtime speed: `1.6 ms`

### C (optimized for size)

```bash
┌─[tautvydas][kagamin][~/tests]
└─▪ time gcc -Os -s test.c
real    0m0.045s
user    0m0.028s
sys     0m0.017s

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh a.out
-rwxr-xr-x 1 tautvydas tautvydas 15K Dec 27 12:41 a.out

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./a.out
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.002s
sys     0m0.000s
```

Running 20 times, the results averaged out to:

* Compilation time: `42.15 ms`
* Size of the binary: `15 KiB`
* Runtime speed: `1.7 ms`

### C (optimized for speed)

```bash
┌─[tautvydas][kagamin][~/tests]
└─▪ time gcc -O3 -s test.c
real    0m0.046s
user    0m0.033s
sys     0m0.012s

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh a.out
-rwxr-xr-x 1 tautvydas tautvydas 15K Dec 27 12:42 a.out

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./a.out
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.000s
sys     0m0.002s
```

Running 20 times, the results averaged out to:

* Compilation time: `47.75 ms`
* Size of the binary: `15 KiB`
* Runtime speed: `1.6 ms`

### Rust

```bash
┌─[tautvydas][kagamin][~/tests]
└─▪ rustc --version
rustc 1.65.0 (897e37553 2022-11-02)

┌─[tautvydas][kagamin][~/tests]
└─▪ time rustc test.rs 
real    0m0.167s
user    0m0.131s
sys     0m0.042s

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh test
-rwxr-xr-x 1 tautvydas tautvydas 3.9M Dec 27 15:26 test

┌─[tautvydas][kagamin][~/tests]
└─▪ strip test

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh test
-rwxr-xr-x 1 tautvydas tautvydas 319K Dec 27 15:26 test

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./test 
3000 2997 2994 2991 (omitted by the author)

real    0m0.003s
user    0m0.000s
sys     0m0.003s
```

At first, Rust took `167 ms` to compile the program, which weighted `3.9 MiB`. After removing debug symbols from the binary, the binary now weighs `319 KiB`, putting it considerably behind WisniaLang.

Running 20 times, the results averaged out to:

* Compilation time: `156.2 ms`
* Size of the binary: `319 KiB`
* Runtime speed: `2.15 ms`

### Rust (optimized for size + libc)

This would necessitate a revision of the previously mentioned sample program to utilize `libc` rather than the standard library (`std::*`). The `Cargo.toml` file is provided below, along with a revised example program.

```text
[package]
name = "optimized-size"
version = "0.1.0"

[profile.release]
panic = "abort"
lto = true
strip = true
codegen-units = 1
incremental = false
opt-level = "z"

[dependencies]
libc = { version = "0.2", default-features = false }
```

```rust
#![no_std]
#![no_main]

extern crate libc;
use libc::c_uint;

fn foo(base: u16, number: u16) {
  if number > 0 {
    unsafe {
      libc::printf("%u \0".as_ptr() as *const libc::c_char, (base * number) as c_uint);
    }
    foo(base, number - 1);
  }
}

#[no_mangle]
pub extern "C" fn main() {
  unsafe {
    foo(3, 1000);
    libc::printf("1\n".as_ptr() as *const libc::c_char);
    libc::exit(0)
  }
}

#[panic_handler]
fn my_panic(_info: &core::panic::PanicInfo) -> ! {
  loop {}
}
```

Let's see how well it performs now, excluding the time it took to compile `libc`.

```bash
┌─[tautvydas][kagamin][~/tests/rust-optim-size]
└─▪ time cargo build --release
   Compiling optimized-size v0.1.0 (~/tests/rust-optim-size)
    Finished release [optimized] target(s) in 0.17s

real    0m0.222s
user    0m0.188s
sys     0m0.034s

┌─[tautvydas][kagamin][~/tests/rust-optim-size]
└─▪ ls -lh target/release/optimized-size
-rwxr-xr-x 2 tautvydas tautvydas 14K Dec 27 15:27 target/release/optimized-size

┌─[tautvydas][kagamin][~/tests/rust-optim-size]
└─▪ time ./target/release/optimized-size 
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.000s
sys     0m0.002s
```

Running 20 times, the results averaged out to:

* Compilation time: `225.6 ms`
* Size of the binary: `14 KiB`
* Runtime speed: `1.75 ms`

### Rust (optimized for speed + libc)

Same `Cargo.toml` file as before, but with `opt-level` set to `3`.

```bash
┌─[tautvydas][kagamin][~/tests/rust-optim-speed]
└─▪ time cargo build --release
   Compiling optimized-speed v0.1.0 (~/tests/rust-optim-speed)
    Finished release [optimized] target(s) in 0.17s

real    0m0.226s
user    0m0.187s
sys     0m0.039

┌─[tautvydas][kagamin][~/tests/rust-optim-speed]
└─▪ ls -lh target/release/optimized-speed
-rwxr-xr-x 2 tautvydas tautvydas 14K Dec 27 15:28 target/release/optimized-speed

┌─[tautvydas][kagamin][~/tests/rust-optim-speed]
└─▪ time ./target/release/optimized-speed
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.000s
sys     0m0.002s
```

Running 20 times, the results averaged out to:

* Compilation time: `235.5 ms`
* Size of the binary: `14 KiB`
* Runtime speed: `1.55 ms`

## Results

![wisnialang-vs-rust](/post-images/benchmark-results.png)

WisniaLang excels in the first two benchmark categories (compilation time and produced binary size), but falls short in the third category (speed of the binary), which remains an area for improvement.

## Summary

* If compilation speed and binary size are important, dropping the LLVM toolchain can have a positive impact
* However, doing so means missing out on LLVM optimizations as well as support for arbitrary OSes and architectures
