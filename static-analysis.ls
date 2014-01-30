require! [
    \uglify-js
    fs
    path
    \source-map
]

add-comment = (ctx, node, comment, details) !->
    source = ctx.filename
    if node?.start?
        line = node.start.line
        column = node.start.col
        pos = ctx.map?.originalPositionFor {
            line
            column
        }
        if !pos?.line && node.thedef?.references?.length
            # No mapping exists for this variable.
            # But CoffeeScript & co. insert automatic `var` statements for variables.
            # Maybe we can find a source line for the first _reference_ to this variable?
            n = node.thedef.references.0
            line = n.start.line
            column = n.start.col
            pos = ctx.map?.originalPositionFor {
                line
                column
            }
        if pos?.source
            { line, column, source } = pos
            # Clean up the source name for readability.
            source = path.relative process.cwd(), path.resolve path.dirname(ctx.map-file), source
    ctx.msg {
        filename: source
        line
        col: column + 1
        comment
        details
    }

check-unused = (ctx, ast) !->
    process-var = (def, name) !->
        if name.match(ctx.ignore-names) || def.orig[0] instanceof uglify-js.AST_SymbolLambda
            return
        type = if def.orig[0] instanceof uglify-js.AST_SymbolFunarg then "function argument" else "variable"
        if def.references.every((ref) -> ref.lvalue)
            add-comment ctx, def.orig.0, "unused #type: #name"

    # mark lvalues
    ast.walk new uglify-js.TreeWalker (node) !->
        if node instanceof uglify-js.AST_Assign
            node.left.lvalue = true

    # check for unused variables
    ast.walk new uglify-js.TreeWalker (scope) !->
        if scope instanceof uglify-js.AST_Scope
            if scope.uses_eval
                add-comment ctx, scope, "this scope uses eval; analysis may be inaccurate"
            if scope.uses_eval
                add-comment ctx, scope, "this scope uses with; analysis will be inaccurate"
            scope.variables.each process-var

check-undeclared = (ctx, ast) !->
    ast.walk new uglify-js.TreeWalker (node) !->
        return unless node instanceof uglify-js.AST_Symbol
        def = node.definition!
        if def && !def.name.match(ctx.ignore-names) && !def.visited && def.undeclared && def.name not in known-globals
            ref = def.references[0] # should not be undefined...
            add-comment ctx, ref, "undeclared variable: #{def.name}"
            def.visited = true

analyze = (ctx) !->
    ast = uglify-js.parse ctx.js
    ast.figure_out_scope!
    check-unused ctx, ast
    check-undeclared ctx, ast

print-message = ({ filename, line, col, comment, details }) !->
    prefix = "#filename "
    if line? and col?
        prefix += "#line:#col"
    prefix += ": "
    console.log "#prefix#comment"
    if details?
        console.log "#{Array(prefix.length + 1).join ' '}#details"

ignore-names = /(^_.)|(^data$)/
known-globals = <[
    arguments
    __filename
    __dirname
    exports
    module
    require
    rootRequire
]>.concat Object.get-own-property-names(global)

for filename in process.argv.slice 2
    js = fs.read-file-sync filename, encoding: 'utf-8'
    if m = js.match /\/\/[@#].*sourceMappingURL\s*=\s*(.*)\s*$/
        map-file = m[1]
        map =
            if fs.exists-sync p = path.join(path.dirname(filename), map-file)
                map-file = p
                fs.read-file-sync map-file, encoding: 'utf-8'
            else if fs.exists-sync map-file
                fs.read-file-sync map-file, encoding: 'utf-8'
        if map
            map = new source-map.SourceMapConsumer map
    analyze {
        filename
        js
        map
        map-file
        ignore-names
        msg: print-message
    }
