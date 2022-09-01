// www.openbookproject.net/books/pythonds/Trees/NodesandReferences.html
package main

import "core:fmt"

Tree :: struct {
    value:          any,
    left_child:     ^Tree,
    right_child:    ^Tree,
    insert_left:    proc(tree: ^Tree, value: any),
    insert_right:   proc(tree: ^Tree, value: any),
    get_left:       proc(tree: ^Tree) -> ^Tree,
    get_right:      proc(tree: ^Tree) -> ^Tree,
}

new_node :: proc(value: any) -> ^Tree {
    tree := new(Tree)

    tree^.value         = value    
    tree^.left_child    = nil
    tree^.right_child   = nil
    tree^.insert_left   = insert_left
    tree^.insert_right  = insert_right
    tree^.get_left      = get_left
    tree^.get_right     = get_right

    return tree
}

insert_left :: proc(tree: ^Tree, value: any) {
    if tree.left_child == nil {
        new_tree := new_node(value)
        tree^.left_child = new_tree
    }
    else {
        new_tree := new_node(value)
        new_tree.left_child = tree.left_child
        tree.left_child = new_tree
    }
}

insert_right :: proc(tree: ^Tree, value: any) {
    if tree.right_child == nil {
        new_tree := new_node(value)
        tree^.right_child = new_tree
    }
    else {
        new_tree := new_node(value)
        new_tree.right_child = tree.right_child
        tree.right_child = new_tree
    }
}

get_left :: proc(tree: ^Tree) -> ^Tree {
    return tree^.left_child
}

get_right :: proc(tree: ^Tree) -> ^Tree {
    return tree^.right_child
}

pretty_print_tree :: proc(tree: ^Tree) {
    if tree.left_child == nil {
        fmt.println("ERROR: left child is nil")
    }

    if tree.right_child == nil {
        fmt.println("ERROR: right child is nil")
    }

    fmt.printf("      %s\n", tree.value)
    fmt.printf("   %s   %s\n", tree.left_child.value, tree.right_child.value)
}