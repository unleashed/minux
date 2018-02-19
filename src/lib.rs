#![feature(lang_items)]
#![no_std]

extern crate rlibc;

#[no_mangle]
pub extern fn rust_main() {
    let x = ["Hello", " ", "World", "!"];
    let test = (0..3).flat_map(|x| 0..x).zip(0..);
}

// Rust requires these for panic!
#[lang = "eh_personality"]
#[no_mangle]
pub extern fn eh_personality() {}

#[lang = "panic_fmt"]
#[no_mangle]
pub extern fn panic_fmt() -> ! {
    let buffer_ptr = (0xb8000) as *mut _;
    let red = 0x4f;
    unsafe {
        *buffer_ptr = [b'P', red, b'a', red, b'n', red,
                       b'i', red, b'c', red, b'!', red];
    };
    loop {}
}
