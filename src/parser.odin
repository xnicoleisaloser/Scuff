package main

import "core:fmt"
import "core:os"
import "core:bytes"
import "core:strconv"
import "core:path/filepath"
import "core:encoding/json"
import "core:strings"

Expression :: struct {
    left:     Operand,
    right:    Operand,
    operator: Operator,
}   

Associativity :: enum {
    Left,
    Right,
}

Operator :: struct {
    associativity:  Associativity,
    precidence:     int,
    symbol:         enum {Add, Sub, Mul, Div, Mod, Pow},
}

Operand :: struct {
    value: union {i64, string, [dynamic]i64},
    type:  enum {Number, String, Variable},
}

operators_table := map[Token_Kind]Operator {
    .Add = {.Left,  0, .Add},
    .Sub = {.Left,  0, .Sub},
    .Mul = {.Left,  1, .Mul},
    .Div = {.Left,  1, .Div},
    .Mod = {.Left,  1, .Mod},
    .Pow = {.Right, 2, .Pow},
}

Entity :: struct {
    kind:       Token_Kind,
    name:       string,
    value:      i32,
    addr:       u32,
    is_global:  bool,    
	function:  ^Function,
}

Entity_Table :: distinct map[string]Entity

Argument :: struct {
    name:       string,
    id:         string,
    block_id:   string,
}

Function :: struct {
    name: string,
    definition_id: string,
    prototype_id: string,
    arguments: [dynamic]Argument,
    is_global: bool,
    refresh_screen: bool,
    entities: Entity_Table,
}

Checker :: struct {
    variables:          [dynamic]string,
	functions:          map[string]^Function,
    // block id is used for generating unique id for each block
    block_num:          i32,
	curr_function:      ^Function,
	tokenizer:          Tokenizer,
	prev_token:         Token,
	curr_token:         Token,
    blocks:             map[string]json.Object,
    block_id_array:     [dynamic]string,
	filename: string,
	fatalf:   proc(c: ^Checker, pos: Pos, format: string, args: ..any) -> !,
}

default_fatalf :: proc(c: ^Checker, pos: Pos, format: string, args: ..any) -> ! {
	fmt.eprintf("%s(%d:%d) ", c.filename, pos.line, pos.column)
	fmt.eprintf(format, ..args)
	fmt.eprintln()
	os.exit(1)
}

compile_target :: proc(target: Makefile_Target) -> json.Object {
    // read file
    data, ok := os.read_entire_file(target.file_path)

    // ensure file was read
    assert(ok, fmt.aprintf("could not read file: \"%s\"", target.file_path))

    // debug print file contents
    fmt.println("------------------------")
    fmt.println(string(data))
    fmt.println("------------------------")

    // initialize checker
    checker := &Checker{}
    checker.filename, _ = filepath.abs(target.file_path)
    
    // generate blocks
    tokenizer_init(&checker.tokenizer, string(data))
    next(checker)
    parse_program(checker)

    // generate costumes
    costumes: json.Array
    for costume in target.costumes {
        append(&costumes, gen_costume(costume))
    }

    gen_runtime(checker)
    return gen_target(target.kind, target.name, costumes, checker.variables, checker.blocks)
}

get_last_block_id :: proc(checker: ^Checker) -> string {
    return checker.block_id_array[len(checker.block_id_array) - 1]
}

get_last_block :: proc(checker: ^Checker) -> ^json.Object {
    return &checker.blocks[get_last_block_id(checker)]
}

parse_program :: proc(checker: ^Checker) {
    if checker.fatalf == nil {
        checker.fatalf = default_fatalf
    }

    declarations: for {
        #partial switch peek(checker).kind {
            case .Func:
                function(checker)

            case .EOF:
                break declarations

            case:
                statement(checker)
            }   

    }
}

function :: proc(checker: ^Checker) {
    expect(checker, .Func)
    name := expect(checker, .Identifier)
    
    if name.text in checker.functions {
        checker->fatalf(name.pos, "%s redeclared", name.text)
    }

    push_function(checker, name.text)
    function_body(checker)
    pop_function(checker)
}

push_function :: proc(checker: ^Checker, name: string) -> ^Function {
    // TODO: actually implement proper global support
    func := new_clone(Function{
        name            = name,
        definition_id   = strings.concatenate({"def_", name}),
        prototype_id    = strings.concatenate({"prot_", name}),
        entities        = make(Entity_Table),
        is_global       = true,
        refresh_screen  = false,
    })

    checker.functions[name] = func
    checker.curr_function = func
    return func
}

// procedure_body = "{" value_decls statement_list "}";
function_body :: proc(checker: ^Checker) {
    expect(checker, .Open_Paren)
    
    arguments := [dynamic]Token{}

    if peek(checker).kind == .Identifier {
        for {
            identifier := expect(checker, .Identifier)

            argument: Argument = {
                name     = identifier.text,
                id       = strings.concatenate({"arg_", identifier.text}),
                block_id = strings.concatenate({"block_", identifier.text}),
            }

            append(&checker.curr_function.arguments, argument)

            if peek(checker).kind != .Comma {
                break
            }

            expect(checker, .Comma)
        }
    }

    expect(checker, .Close_Paren)


    gen_function(checker, .Prototype)
    gen_function(checker, .Arguments)
    gen_function(checker, .Declaration)

    expect(checker, .Open_Brace)

    for peek(checker).kind != .Close_Brace {
        statement(checker)
    }

    expect(checker, .Close_Brace)
}

pop_function :: proc(checker: ^Checker) {
    checker.curr_function = nil
}

statement :: proc(checker: ^Checker) {
    token := next(checker)
     
    #partial switch token.kind {
        case .Identifier:
            if peek(checker).kind == .Assign {
                append(&checker.variables, token.text)
                // entity := check_identifier(checker, token, true)
                expect(checker, .Assign)
                expression(checker)
            } else {
                // call(checker, token)
            }
            
        case .If:
            expect(checker, .Open_Paren)
            // condition(checker)
            expect(checker, .Close_Paren)
            expect(checker, .Open_Brace)
            statement(checker)
    

        case .Simple_Block:
            expect(checker, .Open_Paren)
            expect(checker, .Close_Paren)  
            gen_simple_block(checker, simple_block_table[token.text])
            
        // case .Set_Pen_Color:        gen_set_pen_color(checker)
        // case .Set_Pen_Saturation:   gen_set_pen_saturation(checker)
        // case .Set_Pen_Brightness:   gen_set_pen_brightness(checker)
        // case .Set_Pen_Size:         gen_set_pen_size(checker)
    }

}

// TODO: implement function calls in expressions
// TODO: implement parenthesis in expressions
// (shunting yard algorithm)
expression :: proc(checker: ^Checker) {
    operators  := [dynamic]Operator{}
    operands   := [dynamic]Operand{}

    stack := [dynamic]Token{}
    queue := [dynamic]Token{}

    for {
        token := next(checker)

        #partial switch token.kind{
            case .Identifier: {
                append(&queue, token)
            }

            case .Number: {
                append(&queue, token)
            }

            case .Open_Paren: {
                append(&stack, token)
            }

            case .Close_Paren: {
                for {
                    operator := pop(&stack)

                    if operator.kind != .Open_Paren {
                        append(&queue, operator)
                    } else {
                        break
                    }
                }
            }

            case .Add, .Sub, .Div, .Mul: {
                if len(stack) > 0 {
                    curr_operator := operators_table[token.kind] 
                    last_operator := operators_table[stack[len(stack) - 1].kind]

                    if last_operator.precidence > curr_operator.precidence {
                        append(&queue, pop(&stack))
                    }
                }

                append(&stack, token)
            }

            case: {
                for len(stack) > 0 {
                    append(&queue, pop(&stack))
                }
                
                eval_stack := [dynamic]Token{}

                for len(queue) > 0 {
                    value := pop_front(&queue)

                    #partial switch value.kind {
                        case .Number: {
                            append(&eval_stack, value)
                        }

                        case .Identifier: {
                            append(&eval_stack, value)
                        }

                        case .Add, .Sub, .Div, .Mul: {
                            left  := pop(&eval_stack)
                            right := pop(&eval_stack)

                            left_operand:  Operand = { value = left.text }
                            right_operand: Operand = { value = right.text }

                            expression: Expression = {
                                operator = operators_table[value.kind],
                                left     = left_operand,
                                right    = right_operand,
                            }

                        }
                    } 
                }

                for item in queue {
                    fmt.print(item.text, " ")
                }


                return
            }
        }
    }
}


// factor = ident | number | "(" expression ")";
factor :: proc(checker: ^Checker) {
    token := next(checker) 
    

    #partial switch token.kind {
        case .Identifier:
            if peek(checker).kind == .Open_Paren || peek(checker).kind == .Open_Bracket {
                checker->fatalf(token.pos, "invalid factor, got %s", token_string(token))
            }


        
        case .Number:
            value, ok := strconv.parse_i64(token.text)
            assert(ok, "cannot parse number")


        case .Open_Paren:
            // NOT IMPLEMENTED
            // expression(checker)
            expect(checker, .Close_Paren)
        
        case:
            checker->fatalf(token.pos, "invalid factor, got %s", token_string(token))

    }
}

check_call :: proc(checker: ^Checker, token: Token) -> ^Function {
    func, ok := checker.functions[token.text]

    if !ok {
        checker->fatalf(token.pos, "undeclared function: %s", token.text)
    }

    return func
}

// TODO: this function is really broken
check_identifier :: proc(checker: ^Checker, token: Token, is_assignment: bool) -> Entity {
    name := token.text
    entity, ok := checker.curr_function.entities[name]

    if ok {
        if is_assignment && entity.kind != .Let {
			checker->fatalf(token.pos, "expected a variable, got '%s'", name)
        }
        return entity
    }

    // entity, ok = checker.functions[""].entities[name]

    if ok {
        if is_assignment && entity.kind != .Let {
            checker->fatalf(token.pos, "expected a variable, got '%s'", name)
        }
        return entity
    }
    // checker->fatalf(token.pos, "undeclared name: %s", name)

    return entity
}



// Grammar related procedures

next :: proc(checker: ^Checker) -> Token {
    token, error := get_token(&checker.tokenizer)

    if error != nil && token.kind != .EOF {
        checker->fatalf(token.pos, "invalid token: %v", error)
    }
    checker.prev_token = checker.curr_token
    checker.curr_token = token

    return checker.prev_token
}

expect :: proc(checker: ^Checker, kind: Token_Kind) -> Token {
    token := next(checker)

    if token.kind != kind {
        checker->fatalf(token.pos, "expected %q, got %s", token_string_table[kind], token_string(token))
    }

    return token
}

allow :: proc(checker: ^Checker, kind: Token_Kind) -> bool {
    if checker.curr_token.kind == kind {
        next(checker)
        return true
    }
    return false
}

peek :: proc(checker: ^Checker) -> Token {
    return checker.curr_token
}




// Parser :: struct {
//     position: int,
//     tokens: [dynamic]Token,
// }


// peek :: proc(parser: ^Parser) -> Token {
//     return parser.tokens[parser.position]
// }

// previous :: proc(parser: ^Parser) -> Token {
//     return parser.tokens[parser.position - 1]
// }

// peek_next :: proc(parser: ^Parser) -> Token {
//     return parser.tokens[parser.position + 1]
// }

// advance :: proc(parser: ^Parser) -> Token {
//     if !is_at_end(parser) {
//         parser.position += 1
//     }
//     return previous(parser)
// }

// // checks that the next token is of the given type and then advances to the next token
// // if check fails, we fail with given message
// consume :: proc(parser: ^Parser, token_kind: Token_Kind, message: string) -> Token {
//     if check(parser, token_kind) {
//         return advance(parser)
//     } 
//     fmt.println("ERROR:", message)
    
//     // !FIXME: hack fix this later 
//     return advance(parser)
// }

// check :: proc(parser: ^Parser, token_kind: Token_Kind) -> bool {
//     if is_at_end(parser) {
//         return false
//     }
    
//     return peek(parser).kind == token_kind
// }

// match :: proc(parser: ^Parser, wanted_token_kinds: ..Token_Kind) -> bool {
//     for token_kind in wanted_token_kinds {
//         if check(parser, token_kind) {
//             advance(parser)
//             return true
//         }
//     }

//     return false
// }

// is_at_end :: proc(parser: ^Parser) -> bool {
//     return peek(parser).kind == .EOF
// }

// parse :: proc(parser: ^Parser) {
//     for !is_at_end(parser) {
//         #partial switch consume(parser).kind {
//             case .Let:
//                 fmt.println(var_declaration(parser))
//                 return
//         }
//     }
// }

// var_declaration :: proc(parser: ^Parser) -> ^Parsed_Var_Declaration {
//     result := new(Parsed_Var_Declaration)
//     name := consume(parser, .Identifier, "Expect variable name.")
//     return result
// }