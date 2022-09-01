package main

import "core:encoding/json"
import "core:/c/libc"
import "core:path/filepath"
import "core:/os"
import "core:fmt"
import "core:strings"
import "core:crypto/md5"

// todo: add pack configs
// todo: holy shit, this is a mess
// todo: please fix
pack :: proc(project: json.Object, output_path: string, costumes: [dynamic]Target_Costume) {
    // get temp project dir
    dir                 := filepath.dir(output_path)
    project_dir_path    := filepath.join({dir, "project"})

    // delete the temp project dir
    rm_command          := strings.concatenate({"rm -rf", " ", project_dir_path})
    rm_command_cstring  := strings.clone_to_cstring(rm_command)
    libc.system(rm_command_cstring)

    // create project dir
    os.make_directory(project_dir_path)

    // write project.json to folder
    json_string, _ := json.marshal(project)
    os.write_entire_file(filepath.join({project_dir_path, "project_temp.json"}), json_string)

    // TODO: replace with native odin code
    // pretty print the json file
    project_temp_path               := filepath.join({project_dir_path, "project_temp.json"})
    pretty_print_command            := strings.concatenate({"cat", " ", project_temp_path, " ", "| jq >>", " ", filepath.join({project_dir_path, "project.json"}), " ", "&& rm", " ", project_temp_path, " ", ">> /dev/null"})
    pretty_print_command_cstring    := strings.clone_to_cstring(pretty_print_command)
    libc.system(pretty_print_command_cstring)

    // loop through costumes and write them to the project dir
    for costume in costumes {
        file_path       := filepath.join({project_dir_path, strings.concatenate({costume.hash, ".", costume.ext})})
        os.write_entire_file(file_path, costume.data)
    }


    zip_command         := strings.concatenate({"rm ../project.sb3 && zip", " ", output_path, " ", project_dir_path, "/* ", ">> /dev/null"})
    zip_command_cstring := strings.clone_to_cstring(zip_command)
    libc.system(zip_command_cstring)
}