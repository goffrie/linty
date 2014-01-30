require! {
    analyze: '..'
    assert
}

_it = it

check = !(js, opts, warnings) ->
    if !warnings?
        warnings = opts
        opts = {}
    analyze {
        filename: ''
        js
        msg: ({ filename, line, col, comment, details }) !->
            assert warnings.length > 0, 'more warnings generated than expected'
            w = warnings.shift!
            assert comment.indexOf(w) != -1, "expected #{w}, but got #{comment}"
    } <<< opts

<- describe 'analyzer'

_it 'should accept good code', ->
    check """
        module.exports = function(a) {
            var b = a * a;
            return b;
        };
    """, []

_it 'should reject unused variables', ->
    check """
        module.exports = function(a) {
            var b = a * a;
            return a;
        };
    """, [
        'unused variable: b'
    ]

_it 'should reject undeclared variables', ->
    check """
        module.exports = function(a) {
            var b = a * a;
            return c;
        };
    """, [
        'unused variable: b'
        'undeclared variable: c'
    ]

_it 'should respect ignore-names', ->
    check """
        module.exports = function(__1, __2, p3) {
            var c = __1;
            var _d = "hello";
            return 0;
        };
    """, {
        ignore-names: /^_/
    }, [
        'unused function argument: p3'
        'unused variable: c'
    ]

_it 'should respect known-globals', ->
    check """
        module.exports = function() {
            window.alert("I exist");
            wat.alert("I don't");
        };
    """, {
        known-globals: [ 'window' ]
    }, [
        'undeclared variable: wat'
    ]

