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

ob.getBackgroundColor = function(theme) {
    if (theme == "dark") {
        return "black";
    }
    return "white";
}

ob.getEditorTheme = function(theme) {
    if (theme == "dark") {
        return "ayu-dark";
    }
    return "mdn-like";
}

/// Updates the editor and webview theme.
/// @param {string} theme: Takes the "dark" or "light".
ob.updateTheme = function(theme) {
    document.body.style.backgroundColor = ob.getBackgroundColor(theme);
    editor.setOption("theme", ob.getEditorTheme(theme));
}

ob.test = function() {
    console.log("hello test");
    ob.msg.postMessage({"fn": "test", "ret": "hello test"});
    return "hello test";
}

window.onload = function() {
    console.log("editor loaded");
    ob.setupEditor();
    ob.greet();
}

