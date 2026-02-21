({
    doInit: function(component, event, helper) {
        helper.checkPCMAllExists(component);
        helper.getSnippetCount(component);
    },
    
    handleGenerateCML: function(component, event, helper) {
        if (!component.get("v.pcmAllExists")) {
            helper.showToast('Error', 'PCM_All ExpressionSet not found', 'error');
            return;
        }
        
        component.set("v.isGenerating", true);
        
        var action = component.get("c.generateCML");
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            component.set("v.isGenerating", false);
            
            if (state === "SUCCESS") {
                var result = response.getReturnValue();
                helper.showToast('Success', result, 'success');
                console.log('CML Generation Result:', result);
            } else if (state === "ERROR") {
                var errors = response.getError();
                var message = 'Unknown error';
                if (errors && errors[0] && errors[0].message) {
                    message = errors[0].message;
                }
                helper.showToast('Error', message, 'error');
                console.error('CML Generation Error:', errors);
            }
        });
        
        $A.enqueueAction(action);
    }
})
