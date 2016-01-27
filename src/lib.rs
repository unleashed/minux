#![feature(lang_items)]
#![no_std]

#[no_mangle]
pub extern fn rust_main() {}

// Rust requires these for panic!
#[lang = "eh_personality"]
extern fn eh_personality() {}

#[lang = "panic_fmt"]
extern fn panic_fmt() -> ! { loop {} }