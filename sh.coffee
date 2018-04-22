fs = require 'fs'
parse = require 'bash-parser'


iter_ = ( c ) ->
    if 'type' not of c
        console.error 'No type of', c
        process.exit 1

    if c.type == 'LogicalExpression'
        iter_ c.left
        iter_ c.right
    else if c.type == 'Function'
        iter_ c.body
    else if c.type == 'For'
        for wl in c.wordlist
            iter_ wl
        iter_ c.do
    else if c.type == 'While'
        iter_ c.do
    else if c.type == 'Case'
        for case_item in c.cases
            if case_item.body
                iter_ case_item.body
    else if c.type == 'Command'
        if 'name' of c
            if c.name.text in ['su', 'sudo', 'xargs'] 
                # TODO
            else
                console.log c.name.text
        else
            for it in c.prefix
                iter_ it
    else if c.type == 'Word'
    else if c.type == 'ParameterExpansion'
    else if c.type == 'AssignmentWord'
        if 'expansion' of c
            for ex in c.expansion
                iter_ ex
    else if c.type == 'CommandExpansion'
        iter_ c.commandAST
    else if c.type in [ 'Script', 'CompoundList', 'Pipeline' ]
        iter c
    else
        console.log c.type

iter = ( ast ) ->
    if 'commands' of ast
        for c in ast.commands
            iter_ c
    else
        console.log 'iter?', ast

args = process.argv.slice(2)
if not args.length
    throw new Error("Shell scriptname arguments expected")

for f in args
    rfs = fs.readFileSync f
    try
        ast = parse String(rfs)
    catch e
        console.error 'In file', f, ':', e
    #console.log JSON.stringify ast
    iter ast
