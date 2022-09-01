package main

import "core:unicode/utf8"
import "core:fmt"

Pos :: struct {
    offset: int,
    line:   int,
    column: int,
}

Token :: struct {
    using pos: Pos,
    kind: Token_Kind,
    text: string,
}

Error :: enum {
    None,
    EOF,
    Illegal_Charater,
}

Token_Kind :: enum {
    Invalid,
    EOF,

    Identifier,

    Number,
    String,
    Boolean,
    List,

    Period,
    Colon,
    Comma,
    Semicolon,

    Open_Brace,
    Close_Brace,

    Open_Bracket,
    Close_Bracket,

    Open_Paren,
    Close_Paren,

    Let,
    Func,

    If,
    Else,
    While,
    Repeat,
    For,
    Match,

    Assign,

	Eq,
	NotEq,

    Lt,
	LtEq,
	Gt,
	GtEq,

    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Pow,

    Comment,
    Simple_Block,
}

token_string_table := [Token_Kind]string {
    .Invalid        = "Invalid",
    .EOF            =  "EOF",

    .Identifier     = "identifier",

    .Number         = "number",
    .String         = "string",
    .Boolean        = "boolean",
    .List           = "list",

    .Period         = "period",
    .Colon          = "colon",
    .Comma          = "comma",
    .Semicolon      = "semicolon",

    .Open_Brace     = "{",
    .Close_Brace    = "}",

    .Open_Bracket   = "[",
    .Close_Bracket  = "]",

    .Open_Paren     = "(",
    .Close_Paren    = ")",

    .Let            = "let",
    .Func           = "func",

    .If             = "if",
    .Else           = "else",
    .While          = "while",
    .Repeat         = "repeat",
    .For            = "for",
    .Match          = "match",

    .Assign         = "=",

	.Eq             = "==",
	.NotEq          = "!=",

    .Lt             = "<",
	.LtEq           = "<=",
	.Gt             = ">",
	.GtEq           = ">=",

    .Add            = "+",
    .Sub            = "-",
    .Mul            = "*",
    .Div            = "/",
    .Mod            = "%",
    .Pow            = "^",

    .Comment        = "comment",
    .Simple_Block   = "simple block",
}

simple_block_table := map[string]string {
    "eraseAll"  = "pen_clear",
    "stamp"     = "pen_stamp",
    "penDown"   = "pen_penDown",
    "penUp"     = "pen_penUp",
}

Tokenizer :: struct {
    using pos:          Pos,
    data:               string,
    cur_rune:           rune,
    cur_rune_width:     int,
    cur_line_offset:    int,
    insert_semicolon:   bool,
}


// Returns the string equivalent of the given token
token_string :: proc(token: Token) -> string {
    if token.kind == .Semicolon && token.text == "\n" {
        return "newline"
    } 
    return token_string_table[token.kind]
}

tokenizer_init :: proc(tokenizer: ^Tokenizer, data: string) {
    tokenizer^ = Tokenizer {
        pos  = {line = 1 },
        data = data,
    }

    next_rune(tokenizer)

    if tokenizer.cur_rune == utf8.RUNE_BOM {
        next_rune(tokenizer)
    }
}

next_rune :: proc(tokenizer: ^Tokenizer) -> rune #no_bounds_check {
    // If we're at the end of the string, set cur rune to EOF
    if tokenizer.offset >= len(tokenizer.data) {
        tokenizer.cur_rune = utf8.RUNE_EOF
    }
    else {
        tokenizer.offset += tokenizer.cur_rune_width
        tokenizer.cur_rune, tokenizer.cur_rune_width = utf8.decode_rune_in_string(tokenizer.data[tokenizer.offset:])
        tokenizer.pos.column = tokenizer.offset - tokenizer.cur_line_offset

        // If we're at the end of the string, set cur rune to EOF
        if tokenizer.offset >= len(tokenizer.data) {
            tokenizer.cur_rune = utf8.RUNE_EOF
        }
    }
    return tokenizer.cur_rune
}

skip_whitespace :: proc(tokenizer: ^Tokenizer, on_newline: bool) {
    loop: for tokenizer.offset < len(tokenizer.data) {
        switch tokenizer.cur_rune {
            case ' ', '\t', '\v', '\f', '\r':
                next_rune(tokenizer)
            
            case '\n':
                tokenizer.line += 1
                tokenizer.cur_line_offset = tokenizer.offset
                tokenizer.column = 1
                next_rune(tokenizer)
            
            case:
                switch tokenizer.cur_rune {
                    case 0x2028, 0x2029, 0xFEFF:
                        next_rune(tokenizer)
                        continue loop   
                }
                break loop
        }
    }
}

get_token :: proc(tokenizer: ^Tokenizer) -> (token: Token, error: Error) {

    skip_whitespace(tokenizer, tokenizer.insert_semicolon)
    token.pos = tokenizer.pos

    token.kind = .Invalid

    cur_rune := tokenizer.cur_rune
    
    next_rune(tokenizer)

    block: switch cur_rune {
        case utf8.RUNE_ERROR:
            error = .Illegal_Charater
        
        case utf8.RUNE_EOF, '\x00':
            token.kind = .EOF
            error = .EOF

        case '"':
            token.kind = .String
            token.offset += 1
            for tokenizer.offset < len(tokenizer.data) {
                if tokenizer.cur_rune == '"' {
                    break
                }
                next_rune(tokenizer)
            }
            next_rune(tokenizer)
            tokenizer.offset -= 1
        
        case 'A'..='Z', 'a'..='z', '_':
            token.kind = .Identifier

            for tokenizer.offset < len(tokenizer.data) {
                switch tokenizer.cur_rune {
                    case 'A'..='Z', 'a'..='z', '0'..='9', '_':
                        next_rune(tokenizer)
                        continue

                }
                break
            }
            
            switch str := string(tokenizer.data[token.offset:tokenizer.offset]); str {
                case "let":     token.kind = .Let
                case "func":    token.kind = .Func

                case "if":      token.kind = .If
                case "else":    token.kind = .Else
                case "while":   token.kind = .While
                case "repeat":  token.kind = .Repeat
                case "for":     token.kind = .For
                case "match":   token.kind = .Match

                case:
                    if str in simple_block_table {
                        token.kind = .Simple_Block
                    }
            }
        
        case '0'..='9':
            token.kind = .Number

            for tokenizer.offset < len(tokenizer.data) && '0' <= tokenizer.cur_rune && tokenizer.cur_rune <= '9' {
                next_rune(tokenizer)
            }
        
        case ':':
            token.kind = .Colon
        
        case '=':
            token.kind = .Assign

            if tokenizer.cur_rune == '=' {
                next_rune(tokenizer)
                token.kind = .Eq
            }
        
        case '+': token.kind = .Add
        case '-': token.kind = .Sub
        case '*': token.kind = .Mul
        case '%': token.kind = .Mod

        case '.': token.kind = .Period
        case ',': token.kind = .Comma
        case ';': token.kind = .Semicolon
        case '{': token.kind = .Open_Brace
        case '}': token.kind = .Close_Brace
        case '(': token.kind = .Open_Paren
        case ')': token.kind = .Close_Paren
        case '[': token.kind = .Open_Bracket
        case ']': token.kind = .Close_Bracket

        case '<':
            token.kind = .Lt
            if tokenizer.cur_rune == '=' {
                next_rune(tokenizer)
                token.kind = .LtEq
            }
        
        case '>':
            token.kind = .Gt
            if tokenizer.cur_rune == '=' {
                next_rune(tokenizer)
                token.kind = .GtEq
            }
        
        case '!':
            token.kind = .Invalid
            if tokenizer.cur_rune == '=' {
                next_rune(tokenizer)
                token.kind = .NotEq
            }
        
        case '/':
            token.kind = .Div
            
            if tokenizer.cur_rune == '/' {
                token.offset += 2
                token.kind = .Comment
                
                for {
                    next_rune(tokenizer)
                    if tokenizer.cur_rune == utf8.RUNE_EOF || tokenizer.cur_rune == '\n' {
                        break
                    }
                }
            }

        case:
            error = .Illegal_Charater
    }

    #partial switch token.kind {
        case .Invalid:
            // preserve insert_semicolon info
        
        case .EOF, .Semicolon:
            tokenizer.insert_semicolon = false
        
        case .Identifier, .Number, .Close_Brace, .Close_Paren, .Close_Bracket:
            tokenizer.insert_semicolon = true
            
        case:
            tokenizer.insert_semicolon = false
    }

    token.text = string(tokenizer.data[token.offset:tokenizer.offset])
    return
}
