package main

import "core:os"
import "core:path/filepath"
import "core:encoding/json"
import "core:fmt"
import "core:strings"

Target_Costume :: struct {
    name:               string,
    path:               string,
    hash:               string,
    ext:                string,
    data:               []byte,
    rotation_center_x:  i64,
    rotation_center_y:  i64,
}

Makefile_Target :: struct {
    kind:       string, // "stage" or "sprite"
    file_path:  string,
    name:       string,
    costumes:   [dynamic]Target_Costume,
}

Makefile :: struct {
    targets:    [dynamic]Makefile_Target,
    extensions: [dynamic]string,
}

// TODO: use a schema?
load_makefile :: proc(path_to_makefile: string) -> Makefile {
    abs_path_to_makefile, _ := filepath.abs(path_to_makefile)
    
    // Read makefile into string
    makefile_text, could_read_file := os.read_entire_file_from_filename(abs_path_to_makefile)
    
    // Get project folder
    project_folder := filepath.dir(abs_path_to_makefile)

    if !could_read_file {
        log_error("Could not read makefile from:", path_to_makefile)
    }

    // Parse makefile into JSON object
    makefile_json, json_error := json.parse(makefile_text)

    if json_error != .None {
        log_error("Could not parse JSON")
    }

    // Parse JSON object into Makefile struct
    makefile := Makefile{}

    stage_count := 0

    // Iterate through targets and append them to our makefile
    for json_target in makefile_json.(json.Object)["targets"].(json.Array) {
        target := Makefile_Target{}
        target.kind         = json_target.(json.Object)["kind"].(json.String)
        target.file_path    = filepath.join({filepath.dir(path_to_makefile), json_target.(json.Object)["filePath"].(json.String)})
        target.name         = json_target.(json.Object)["name"].(json.String)
        
        if target.kind == "stage" {
            if target.name != "Stage" {
                log_error("Stage name must be named:", "'Stage'")
            }

            if stage_count == 1 {
                log_error("Only one stage is allowed")
            }

            stage_count += 1
        }

        for json_costume in json_target.(json.Object)["costumes"].(json.Array) {
            path            := json_costume.(json.Object)["path"].(json.String)
            costume_path    := filepath.join({project_folder, path})
            ext, _          := strings.replace(filepath.ext(path), ".", "", 1)
            data, _         := os.read_entire_file_from_filename(costume_path)

            costume: Target_Costume = {
                name                = json_costume.(json.Object)["name"].(json.String),
                path                = path,
                hash                = hash_file(costume_path)[0:32],
                ext                 = ext,
                data                = data,
                rotation_center_x   = cast(i64)json_costume.(json.Object)["rotationCenterX"].(json.Float),
                rotation_center_y   = cast(i64)json_costume.(json.Object)["rotationCenterY"].(json.Float),
            }

            append(&target.costumes, costume)
        }
        append(&makefile.targets, target)
    }

    // FIXME: this is a hack
    for extension in makefile_json.(json.Object)["extensions"].(json.Array) {
        append(&makefile.extensions, extension.(json.String))
    }

    return makefile
}

