var ob = ob || {};

ob.setupEditor = function() {
    ob.editor = CodeMirror(document.querySelector("#editor"), {
        lineNumbers: true,
        tabSize: 2,
        indentUnit: 2,
        mode: "application/json",
        theme: "ayu-dark",
        matchBrackets: true,
        autoCloseBrackets: true
    });
}

ob.getBackgroundColor = function(mode) {
    if (mode == "dark") {
        return "black";
    }
    return "white";
}

ob.getEditorTheme = function(mode) {
    if (mode == "dark") {
        return "ayu-dark";
    }
    return "mdn-like";
}

/// Updates the editor and webview theme based on the given display mode.
/// @param {string} mode: Takes "dark" or "light".
ob.updateTheme = function(args) {
    var mode = args["mode"] || "dark";
    document.body.style.backgroundColor = ob.getBackgroundColor(mode);
    ob.editor.setOption("theme", ob.getEditorTheme(mode));
}

ob.test = function() {
    console.log("hello test");
    ob.msg.postMessage({"fn": "test", "ret": "hello test"});
    return "hello test";
}

window.onload = function() {
    ob.setupEditor();
    ob.greet();
}

