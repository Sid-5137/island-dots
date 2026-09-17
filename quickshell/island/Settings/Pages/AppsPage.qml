import QtQuick
import "root:/Services"
import "root:/Widgets"

// Which application opens which kind of thing.
//
// The rows are dropdowns of what is actually installed and claims the
// type, not a text field to type a command into: a command that does
// not exist is a setting that fails at the moment you try to use it,
// hours after you set it, with nothing on screen to say why.
//
// Everything here except the terminal is written to mimeapps.list,
// which is the desktop's own file — so a choice made here is the same
// choice every other application reads. See Services/DefaultApps.qml.

Column {
    id: page
    spacing: 4

    // Scanning every .desktop file on the machine is not work to do at
    // startup for a page most sessions never open, so it happens here.
    // Re-read on each open rather than cached, because something else
    // may have claimed a type in between — a browser's "make me the
    // default" button, most often.
    Component.onCompleted: DefaultApps.refresh()

    // Two apps can carry the same Name — "Files", "Image Viewer", a
    // Flatpak beside its distribution package. A dropdown with two
    // identical rows is a choice you cannot make, so the ones that
    // collide get their entry id and the rest stay clean.
    function labelsFor(apps) {
        const count = {};
        for (const app of apps)
            count[app.name] = (count[app.name] || 0) + 1;

        return apps.map(app => count[app.name] > 1
            ? app.name + " (" + app.id.replace(/\.desktop$/, "") + ")"
            : app.name);
    }

    Component {
        id: appRow

        SelectRow {
            required property var modelData

            readonly property var apps: DefaultApps.optionsFor(modelData)
            readonly property var labels: page.labelsFor(apps)

            readonly property int index:
                apps.findIndex(app => app.id === DefaultApps.currentFor(modelData))

            label: modelData.label
            description: modelData.description || ""

            options: labels

            // Blank when nothing installed claims the type, and blank
            // when the default is an application that has since been
            // removed — which is a true answer in both cases, and the
            // second one is how a dropdown earns its keep: the row
            // that opens nothing is visibly the row that opens
            // nothing.
            current: index >= 0 ? labels[index] : ""

            onSelected: function(chosen) {
                const at = labels.indexOf(chosen);
                if (at >= 0) DefaultApps.choose(modelData.key, apps[at].id);
            }
        }
    }

    SectionHeader { text: "Programs" }

    Repeater {
        model: DefaultApps.categories.filter(cat => cat.group === "Programs")
        delegate: appRow
    }

    SectionHeader { text: "File types" }

    Repeater {
        model: DefaultApps.categories.filter(cat => cat.group === "File types")
        delegate: appRow
    }

    SectionHeader { text: "Where these go" }

    Item {
        width: parent.width
        height: note.implicitHeight + 16

        Text {
            id: note
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: DefaultApps.problem !== "" ? DefaultApps.problem
                : DefaultApps.loading ? "Reading the association database…"
                : "Everything but the terminal goes in "
                  + "~/.config/mimeapps.list, the file the whole desktop "
                  + "reads — so these are the machine's settings rather "
                  + "than island's, and changing one here changes it "
                  + "everywhere. The terminal is the exception because it "
                  + "handles no file type, so it has no entry there.\n\n"
                  + "The first, third and fourth rows are also what "
                  + "Super+B, Super+E and Super+X spawn."

            color: DefaultApps.problem !== "" ? Theme.error : Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }
}
