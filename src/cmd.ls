require! {
    path
    fs
    analyze: './analyze'
    \source-map
}

print-message = ({ filename, line, col, comment, details }) !->
    filename = path.relative process.cwd(), filename
    prefix = "#filename "
    if line? and col?
        prefix += "#line:#col"
    prefix += ": "
    console.log "#prefix#comment"
    if details?
        console.log "#{Array(prefix.length + 1).join ' '}#details"

ignore-names = /(^_.)|(^data$)/
known-globals = [ 'rootRequire' ]

for let filename in process.argv.slice 2
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
        known-globals
        msg: print-message
    }
