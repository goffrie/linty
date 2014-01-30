require! [
    \uglify-js
    path
]

add-comment = (ctx, node, comment, details) !->
    source = ctx.filename
    if node?.start?
        line = node.start.line
        column = node.start.col
        if ctx.map?
            pos = ctx.map.originalPositionFor {
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
                pos = ctx.map.originalPositionFor {
                    line
                    column
                }
            if pos?.source
                { line, column, source } = pos
                # Clean up the source name.
                source = path.resolve path.dirname(ctx.map-file), source
    ctx.msg {
        filename: source
        line
        col: column + 1
        comment
        details
    }

check-unused = (ctx, ast) !->
    process-var = (def, name) !->
        if ctx.ignore-names?.test(name) || def.orig[0] instanceof uglify-js.AST_SymbolLambda
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

known-globals = <[
    arguments
    __filename
    __dirname
    exports
    module
    require
]>.concat Object.get-own-property-names(global)

check-undeclared = (ctx, ast) !->
    ast.walk new uglify-js.TreeWalker (node) !->
        return unless node instanceof uglify-js.AST_Symbol
        def = node.definition!
        if (def && !ctx.ignore-names?.test(def.name) &&
                !def.visited && def.undeclared &&
                def.name not in known-globals &&
                def.name not in (ctx.known-globals ? []))
            ref = def.references[0] # should not be undefined...
            add-comment ctx, ref, "undeclared variable: #{def.name}"
            def.visited = true

analyze = (ctx) !->
    ast = uglify-js.parse ctx.js
    ast.figure_out_scope!
    check-unused ctx, ast
    check-undeclared ctx, ast

module.exports = analyze
