({
    checkPCMAllExists: function(component) {
        var action = component.get("c.checkPCMAllExists");
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.pcmAllExists", response.getReturnValue());
            } else {
                component.set("v.pcmAllExists", false);
            }
        });
        
        $A.enqueueAction(action);
    },
    
    getSnippetCount: function(component) {
        var action = component.get("c.getSnippetCount");
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.snippetCount", response.getReturnValue());
            } else {
                component.set("v.snippetCount", 0);
            }
        });
        
        $A.enqueueAction(action);
    },
    
    showToast: function(title, message, type) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "type": type,
            "mode": type === 'error' ? 'sticky' : 'dismissable'
        });
        toastEvent.fire();
    }
})
