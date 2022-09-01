package main

import "core:fmt"
import "core:strings"
import "core:encoding/json"
import "core:path/filepath"
import "core:os"
import "core:crypto/md5"

Gen :: struct {

}

json_test :: proc() {
    project: json.Object
    target: json.Object
    // target = gen_target(true, "Stage", )
    // project = gen_project(cast(json.Array){target})

    event := gen_event("event_whenflagclicked")

    json_marshal, _ := json.marshal(event)
    // json.parse_object("{\"a\":1,\"b\":2}")
    // fmt.println(cast(string)json_marshal)
    // fmt.println(gen_blank_svg())
}

// FIXME: please this is such an atrocious hack
hash_to_str :: proc(bytes: [16]u8) -> string {
    str: string

    x := 0
    y := 100

    for byte in bytes {
        str = fmt.aprintf("%v%x", str, byte)
    
        if x == 3 {
            str = fmt.aprintf("%v%v", str, "0")
            y = 0
        }

        if y == 6 {
            str = fmt.aprintf("%v%v", str, "0")
        }

        x += 1
        y += 1
    }

    return str
}

hash :: proc(str: string) -> string {
    return hash_to_str(md5.hash_string(str))
}

hash_file :: proc(path: string) -> string {
    handle, _   := os.open(path)
    hash, _     := md5.hash_file(handle)
    hash_str    := hash_to_str(hash)
    os.close(handle)
    return hash_str
}

// this could be a constant,
// but it's cleaner to have it as a function
gen_blank_svg :: proc() -> string {
    return`<svg version="1.1" width="2" height="2" viewBox="-1 -1 2 2" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <!-- Exported by Scratch - http://scratch.mit.edu/ -->
</svg>`
}

gen_event :: proc(event_name: string, inputs: json.Object = {}, fields: json.Object = {}) -> json.Object {
    return {
        "opcode"    = event_name,
        "next"      = nil,
        "parent"    = nil,
        "inputs"    = cast(json.Object)inputs,    
        "fields"    = cast(json.Object)fields,    
        "shadow"    = false,
        "topLevel"  = true,
        "x"         = 0,
        "y"         = 0,
    }
}

gen_block_id :: proc(checker: ^Checker) -> string {
    block_num := fmt.aprintf("%v", checker.block_num)
    block_id := strings.concatenate({"block_", block_num})
    checker.block_num += 1
    return block_id
}


gen_simple_block :: proc(checker: ^Checker, opcode: string) {
    last_block := get_last_block(checker)
    block_id := gen_block_id(checker)

    if last_block["next"] == nil {
        last_block["next"] = block_id
    }
    
    block: json.Object = {
        "opcode"    = opcode,
        "next"      = nil,
        "parent"    = get_last_block_id(checker),
        "inputs"    = json.Object{},
        "fields"    = json.Object{},
        "shadow"    = false,
        "topLevel"  = false,
        "x"         = 0,
        "y"         = 0,
    }

    emit_block(checker, block, block_id)
}

// Most of these are constants, 
// agent is just the browser agent of the user
gen_meta :: proc() -> json.Object {
    return {
        "semver"    = "3.0.0",
        "vm"        = "0.2.0",
        "agent"     = "scuff",  
    }
}

gen_costume :: proc(costume: Target_Costume) -> json.Object {
    ext, _ := strings.replace(filepath.ext(costume.path), ".", "", 1)

    return {
        "name"              = costume.name,
        "bitmapResolution"  = 1,
        "dataFormat"        = costume.ext,
        "assetId"           = costume.hash,
        "md5ext"            = strings.concatenate({costume.hash, ".", costume.ext}),
        "rotationCenterX"   = costume.rotation_center_x,
        "rotationCenterY"   = costume.rotation_center_y,
    }
}

// FIXME:
// these functions are nearly identical, fix pls
array_from_objects :: proc(objects: [dynamic]json.Object) -> json.Array {
    array: json.Array

    for object in objects {
        append(&array, object)
    }

    return array
}

gen_extensions :: proc(extensions: [dynamic]string) -> json.Array {
    // FIXME: this is O(n)
    extensions_json: json.Array

    for extension in extensions {
        append(&extensions_json, extension)
    }

    return extensions_json
}

gen_variables :: proc(variables: [dynamic]string) -> json.Object { 
    json_variables: json.Object
    
    for variable in variables {
        json_variables[variable] = json.Array{
            variable,
            0,
        }
    }

    return json_variables
}

emit_block :: proc(checker: ^Checker, block: json.Object, block_id: string) {
    checker.blocks[block_id] = block
    append(&checker.block_id_array, block_id)
}

gen_function :: proc(checker: ^Checker, part: enum{Declaration, Prototype, Arguments}) {
    function := checker.curr_function
    if part == .Declaration {
        block: json.Object = {
            "opcode"    = "procedures_definition",
            "next"      = nil,
            "parent"    = nil,
            "inputs"    = cast(json.Object){"custom_block" = cast(json.Array){1, function.prototype_id}},
            "fields"    = cast(json.Object){},
            "shadow"    = false,
            "topLevel"  = true,
            "x"         = 0,
            "y"         = 0,
        }

        block_id := function.definition_id
        emit_block(checker, block, block_id)
    }

    if part == .Prototype {
        inputs:            json.Object
        proc_code       := function.name
        argument_ids:      [dynamic]string
        argument_names:    [dynamic]string
        argument_defaults: [dynamic]string

        for argument in function.arguments {
            inputs[argument.id] = json.Array{1, argument.block_id}
        
            proc_code = strings.concatenate({proc_code, " %s"})
            argument_id := strings.concatenate({"\"", argument.id, "\""})
            argument_name := strings.concatenate({"\"", argument.name, "\""})
            argument_default := strings.concatenate({"\"", "", "\""})
            
            append(&argument_ids, argument_id)
            append(&argument_names, argument_name)
            append(&argument_defaults, argument_default)
        }

        block: json.Object = {
            "opcode"    = "procedures_prototype",
            "next"      = nil,
            "parent"    = function.definition_id,
            "inputs"    = inputs,
            "fields"    = json.Object{},
            "shadow"    = true,
            "topLevel"  = false,
            "mutation"  = json.Object{
                "tagName"          = "mutation",
                "children"          = json.Array{},
                "proccode"          = proc_code,
                "argumentids"       = fmt.aprintf("%s", argument_ids),
                "argumentnames"     = fmt.aprintf("%s", argument_names),
                "argumentdefaults"  = fmt.aprintf("%s", argument_defaults),
                "warp"              = fmt.aprintf("%v", !function.refresh_screen),
            },
        }

        emit_block(checker, block, function.prototype_id)
    }


    if part == .Arguments {
        for argument in function.arguments {
            block: json.Object = {
                "opcode"    = "argument_reporter_string_number",
                "next"      = nil,
                "parent"    = function.prototype_id,
                "inputs"    = json.Object{},
                "fields"    = json.Object{
                    "VALUE" = json.Array{argument.name, nil},
                },
                "shadow"    = true,
                "topLevel"  = false,
            }
            
            emit_block(checker, block, argument.block_id)
        }
    }
}

gen_variable_id :: proc(variable: string) -> string {
    return strings.concatenate({"var_", variable})
}

// this might be redundant
gen_blocks :: proc(blocks: map[string]json.Object) -> json.Object {
    json_blocks: json.Object
    
    for block in blocks {
        json_blocks[block] = blocks[block]
    }

    return json_blocks
}

// FIXME: this is so incredibly bad
gen_runtime :: proc(checker: ^Checker) {
    handle, _    := os.open("runtime")
    file_info, _ := os.read_dir(handle, 100)

    for file in file_info {
        data, _ := os.read_entire_file_from_filename(file.fullpath)
        json_data, _ := json.parse_string(cast(string)data)


        for block_name, block_data in json_data.(json.Object) {
            data := block_data.(json.Object)
            block: json.Object

            for entry, entry_data in data {
                if fmt.aprint(entry_data) == "0x0" {
                    block[entry] = nil
                }
                else {
                    block[entry] = entry_data
                }
            }

            emit_block(checker, block, block_name)
        }
    }
    os.close(handle)
}


gen_target :: proc(kind: string, name: string, costumes: json.Array, variables: [dynamic]string, blocks: map[string]json.Object) -> json.Object {
    layer_order: i64

    if kind == "stage" {
        layer_order = 0
    }
    else {
        layer_order = 1
    }
    
    return {
        "isStage"               = kind == "stage",
        "name"                  = name,
        "variables"             = gen_variables(variables),
        "lists"                 = cast(json.Object){},
        "broadcasts"            = cast(json.Object){},
        "blocks"                = gen_blocks(blocks),
        "comments"              = cast(json.Object){},
        "currentCostume"        = 0,
        "costumes"              = costumes,
        "sounds"                = cast(json.Array){},
        "volume"                = 100,
        "layerOrder"            = layer_order,
        "visible"               = true,
        "x"                     = 0,
        "y"                     = 0,
        "size"                  = 100,
        "direction"             = 90,
        "draggable"             = false,
        "rotationStyle"         = "all around",
        "tempo"                 = 60,
        "videoTransparency"     = 50,
        "videoState"            = "on",
        "textToSpeechLanguage"  = nil,
    }
}

gen_project :: proc(compiled_targets: json.Array, extensions: [dynamic]string) -> json.Object {
    project: json.Object
    project["targets"]      = compiled_targets
    project["monitors"]     = cast(json.Array){}
    project["extensions"]   = gen_extensions(extensions)
    project["meta"]         = gen_meta()
    return project
}
