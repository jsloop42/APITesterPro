var ob = ob || {};
ob.messageHandlerName = "ob";
ob.msg = webkit.messageHandlers[ob.messageHandlerName];

ob.log = {
    info: function(msg) {
        webkit.messageHandlers.ob.postMessage(msg);
    }
}

ob.greet = function() {
    ob.msg.postMessage({"fn": "greet", "ret": "hello world"});
}
