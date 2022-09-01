package main

import "core:fmt"
import "core:os"
import "core:encoding/json"
import "core:path/filepath"

// todo for tomorrow
// refactor lexer to use peek() and advance()
// https://github.com/nico-bb/lily/blob/main/lib/lexer.odin
// implement strings
// begin codegen

main :: proc() {
    makefile := load_makefile("../examples/project/makefile.json")
    log_info("Makefile Loaded:", "../examples/project/makefile.json")

    // TODO: add support for sounds in addition to costumes
    compiled_targets:   json.Array
    files:              [dynamic]string
    costumes:           [dynamic]Target_Costume

    // Compile all targets
    for target in makefile.targets {
        log_info("Compiling Target:", target.file_path)
        
        target_json := compile_target(target)
        append(&compiled_targets, target_json)

        for costume in target.costumes {
            append(&costumes, costume)
        }

    }

    log_info("Packing Project:", "project.sb3")
    project_json := gen_project(compiled_targets, makefile.extensions)
    pack(project_json, "../project.sb3", costumes)
}