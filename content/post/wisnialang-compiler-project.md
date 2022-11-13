---
title: "WisniaLang: Compiler Project"
date: 2022-10-17T20:55:19-05:00
publishdate: 2022-10-17
lastmod: 2022-11-13
draft: false
tags: ["c++", "elf", "compiler", "llvm", "rust"]
---

![dragon-book](/post-images/dragon-maid-compiler-book.jpg)

## Introduction

For the past 3 years, I have been working on a [compiler](https://github.com/belijzajac/WisniaLang) for an experimental programming language that compiles to native machine code. It focuses on delivering small Linux binaries (ELF x86_64) with no LLVM dependency. As a result, what it actually competes with is the LLVM toolchain, on which a large number of other programming languages rely extensively.

## Architecture

![architecture](/post-images/wisnialang-architecture.png)

### Programming languages that depend on LLVM

Before going further, let me get straight to the point:

1. Writing compilers is easy
2. Optimizing the machine code is hard
3. Supporting arbitrary architectures / operating systems is hard

![llvm-approach](/post-images/llvm-approach.png)

This is where LLVM comes in handy. LLVM uses an intermediate representation language, which is kind of similar to assembly, but with a few higher level constructs. LLVM is good at optimizing this IR language, as well as compiling into different architecture / binary formats. So as a language author using LLVM, I'm really writing a transpiler from my language -> LLVM IR, and letting the LLVM compiler do the hard work.

<center><img src="/post-images/wisnialang-approach.png"></center>
<br>

Even though it is an amateurish project, [WisniaLang](https://github.com/belijzajac/WisniaLang) takes a more traditional approach to compiler design. It goes through all of the same front-end procedures as other LLVM-based programming languages, but it handles register allocation, machine code generation, and ELF binary format construction on its own.

## Example programs

Let's take a look at simple programs and see how a handwritten compiler compares to Rust, an LLVM-based programming language. Both compilers generate the identical number sequence, `3000 2997 ... 6 3 1`, for both programs.

<table>
<tr><th>WisniaLang</th><th>Rust</th></tr>
<tr><td>

```rust
fn foo(base: int, number: int) -> void {          
  if (number) {
    print(base * number, " ");
    foo(base, number - 1);
  }
}

fn main() -> void {
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

</td></tr> </table>

## A dive deeper

Let us now compare the final size of the produced binary files and the time it took to assemble them. **TLDR**: If you wish to skip the lenghty blabberings and view the results as a graphic representation, scroll to the bottom of the page.

### WisniaLang

```bash
┌─[tautvydas][kagamin][~/tests]
└─▪ time ./wisnia test.wsn
real    0m0.005s
user    0m0.003s
sys     0m0.002s

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh a.out 
-rwxrwxrwx 1 tautvydas tautvydas 549 Nov 13 15:25 a.out

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./a.out
3000 2997 2994 2991 (omitted by the author)

real    0m0.007s
user    0m0.000s
sys     0m0.007s
```

The example program was compiled into a `549`-byte binary file in just `5` milliseconds by our compiler, which took `7` milliseconds to run.

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
-rwxr-xr-x 1 tautvydas tautvydas 3.9M Nov 13 15:26 test

┌─[tautvydas][kagamin][~/tests]
└─▪ strip test

┌─[tautvydas][kagamin][~/tests]
└─▪ ls -lh test
-rwxr-xr-x 1 tautvydas tautvydas 319K Nov 13 15:26 test

┌─[tautvydas][kagamin][~/tests]
└─▪ time ./test 
3000 2997 2994 2991 (omitted by the author)

real    0m0.003s
user    0m0.000s
sys     0m0.003s
```

Rust, on the other hand, took `167` milliseconds to compile the program, which weighted `3.9` megabytes. After removing the symbols from the binary file, the program now weighs `319` kilobytes, putting it considerably behind WisniaLang. The compiled program took `3` milliseconds to run.

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
    unsafe { libc::printf("%u \0".as_ptr() as *const libc::c_char, (base * number) as c_uint); }
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

Let's see how well it performs now, excluding the compilation of `libc`.

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
-rwxr-xr-x 2 tautvydas tautvydas 14K Nov 13 15:27 target/release/optimized-size

┌─[tautvydas][kagamin][~/tests/rust-optim-size]
└─▪ time ./target/release/optimized-size 
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.000s
sys     0m0.002s
```

Rust took `222` milliseconds to assemble a binary file weighing `14` kilobytes, which took `2` milliseconds to run. 

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
-rwxr-xr-x 2 tautvydas tautvydas 14K Nov 13 15:28 target/release/optimized-speed

┌─[tautvydas][kagamin][~/tests/rust-optim-speed]
└─▪ time ./target/release/optimized-speed
3000 2997 2994 2991 (omitted by the author)

real    0m0.002s
user    0m0.000s
sys     0m0.002s
```

This time, Rust took `226` milliseconds to assemble a binary file weighing `14` kilobytes, which took `2` milliseconds to run. 

## Results

![wisnialang-vs-rust](/post-images/wisnialang-vs-rust.png)

## Summary

* If compilation speed and binary file size are important, dropping the LLVM toolchain can have a positive impact
* However, doing so means missing out on LLVM optimizations as well as support for arbitrary OSes and architectures
