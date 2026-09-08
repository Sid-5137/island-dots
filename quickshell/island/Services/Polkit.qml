pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import QtQuick

// Authorization prompts.
//
// The agent only asks — polkitd still makes every decision and still
// runs the PAM stack. Nothing security-relevant is reimplemented here.
//
// Requests are queued by the agent, so a second prompt arrives on its
// own signal once the first is done.

Singleton {
    id: root

    property string entry: ""

    readonly property var flow: agent.flow
    readonly property bool active: flow !== null && !flow.isCompleted

    readonly property string message: flow ? flow.message : ""
    readonly property string prompt: flow ? flow.inputPrompt : "Password"
    readonly property string action: flow ? flow.actionId : ""
    readonly property string iconName: flow ? flow.iconName : ""

    readonly property string supplementary: flow ? flow.supplementaryMessage : ""
    readonly property bool supplementaryIsError: flow ? flow.supplementaryIsError : false
    readonly property bool failed: flow ? flow.failed : false
    readonly property bool needsResponse: flow ? flow.isResponseRequired : false
    readonly property bool responseVisible: flow ? flow.responseVisible : false

    function submit() {
        if (!flow || entry === "") return;
        flow.submit(entry);
        entry = "";
    }

    function cancel() {
        if (flow) flow.cancel();
        entry = "";
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.entry = "";
        }
    }

    IpcHandler {
        target: "polkit"
        function status(): string {
            return root.active ? "asking: " + root.message : "idle";
        }
    }
}
