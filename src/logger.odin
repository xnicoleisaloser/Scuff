package main

import "core:strings"
import "core:fmt"
import "core:os"

// https://github.com/alexeyraspopov/picocolors/blob/main/picocolors.js
Fmt_Option :: struct {
    open: string,
    close: string,
}

Fmt_Options_Enum :: enum {
    bold,
    dim,
    italic,
    underline,
    inverse,
    hidden,
    strikethrough,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    gray,
    bg_black,
    bg_red,
    bg_green,
    bg_yellow,
    bg_blue,
    bg_magenta,
    bg_cyan,
    bg_white,
}

FMT_OPTIONS: map[Fmt_Options_Enum]Fmt_Option = {
    .bold          = {"\x1b[1m",  "\x1b[22m"},
    .dim           = {"\x1b[2m",  "\x1b[22m"},
    .italic        = {"\x1b[3m",  "\x1b[23m"},
    .underline     = {"\x1b[4m",  "\x1b[24m"},
    .inverse       = {"\x1b[7m",  "\x1b[27m"},
    .hidden        = {"\x1b[8m",  "\x1b[28m"},
    .strikethrough = {"\x1b[9m",  "\x1b[29m"},
    .black         = {"\x1b[30m", "\x1b[39m"},
    .red           = {"\x1b[31m", "\x1b[39m"},
    .green         = {"\x1b[32m", "\x1b[39m"},
    .yellow        = {"\x1b[33m", "\x1b[39m"},
    .blue          = {"\x1b[34m", "\x1b[39m"},
    .magenta       = {"\x1b[35m", "\x1b[39m"},
    .cyan          = {"\x1b[36m", "\x1b[39m"},
    .white         = {"\x1b[37m", "\x1b[39m"},
    .gray          = {"\x1b[90m", "\x1b[39m"},
    .bg_black      = {"\x1b[40m", "\x1b[49m"},
    .bg_red        = {"\x1b[41m", "\x1b[49m"},
    .bg_green      = {"\x1b[42m", "\x1b[49m"},
    .bg_yellow     = {"\x1b[43m", "\x1b[49m"},
    .bg_blue       = {"\x1b[44m", "\x1b[49m"},
    .bg_magenta    = {"\x1b[45m", "\x1b[49m"},
    .bg_cyan       = {"\x1b[46m", "\x1b[49m"},
    .bg_white      = {"\x1b[47m", "\x1b[49m"},
}

chalk :: proc(text: string,  options: ..Fmt_Options_Enum) -> string {
    if text == "" { return text }
    
    formatted_string := text
    
    for option in options {
        assert(option in FMT_OPTIONS, "Unknown option")
        formatted_string = strings.concatenate({FMT_OPTIONS[option].open, formatted_string, FMT_OPTIONS[option].close})
    }

    return formatted_string
}

log_error :: proc(error: string, argument: string = "") {
    fmt.println(chalk("[Error]", .red, .bold), chalk(error, .red), chalk(argument, .underline))
    os.exit(1)
}

log_warn :: proc(warning: string, argument: string = "") {
    fmt.println(chalk("[Warning]", .yellow, .bold), chalk(warning, .yellow), chalk(argument, .underline))
}

log_info :: proc(info: string, argument: string = "") {
    fmt.println(chalk("[Info]", .green, .bold), chalk(info, .green), chalk(argument, .underline))
}

log_debug :: proc(debug: string, argument: string = "") {
    fmt.println(chalk("[Debug]", .cyan, .bold), chalk(debug, .cyan), chalk(argument, .underline))
}