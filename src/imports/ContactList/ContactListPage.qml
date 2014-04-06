/*
 * Copyright (C) 2012-2013 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import QtContacts 5.0

import Ubuntu.Components 0.1
import Ubuntu.Components.ListItems 0.1 as ListItem
import Ubuntu.Contacts 0.1 as ContactsUI
import Ubuntu.Components.Popups 0.1 as Popups

Page {
    id: mainPage
    objectName: "contactListPage"

    property bool pickMode: false
    property bool pickMultipleContacts: false
    property var onlineAccountsMessageDialog: null
    property QtObject contactIndex: null
    property var contactModel: contactList.listModel ? contactList.listModel : null

    function createEmptyContact(phoneNumber) {
        var details = [ {detail: "PhoneNumber", field: "number", value: phoneNumber},
                        {detail: "EmailAddress", field: "emailAddress", value: ""},
                        {detail: "OnlineAccount", field: "accountUri", value: ""},
                        {detail: "Address", field: "street", value: ""},
                        {detail: "Name", field: "firstName", value: "" }
                      ]

        var newContact =  Qt.createQmlObject("import QtContacts 5.0; Contact{ }", mainPage)
        var detailSourceTemplate = "import QtContacts 5.0; %1{ %2: \"%3\" }"
        for (var i=0; i < details.length; i++) {
            var detailMetaData = details[i]
            var newDetail = Qt.createQmlObject(detailSourceTemplate.arg(detailMetaData.detail)
                                            .arg(detailMetaData.field)
                                            .arg(detailMetaData.value), mainPage)
            newContact.addDetail(newDetail)
        }
        return newContact
    }

    title: i18n.tr("Contacts")

    Component {
        id: onlineAccountsDialog

        OnlineAccountsMessage {
            id: onlineAccountsMessage
            onCanceled: {
                mainPage.onlineAccountsMessageDialog = null
                PopupUtils.close(onlineAccountsMessage)
                application.unsetFirstRun()
            }
            onAccepted: {
                Qt.openUrlExternally("settings:///system/online-accounts")
                mainPage.onlineAccountsMessageDialog = null
                PopupUtils.close(onlineAccountsMessage)
                application.unsetFirstRun()
            }
        }
    }

    ContactsUI.ContactListView {
        id: contactList
        objectName: "contactListView"

        multiSelectionEnabled: true
        acceptAction.text: pickMode ? i18n.tr("Select") : i18n.tr("Delete")
        multipleSelection: !pickMode ||
                           ((contactContentHub && contactContentHub.multipleItems) || mainPage.pickMultipleContacts)
        anchors {
            // This extra margin is necessary because the toolbar area overlaps the last item in the view
            // in the selection mode we remove it to avoid visual problems due the selection bar appears
            // inside of the listview
            bottomMargin: contactList.isInSelectionMode ? 0 : units.gu(2)
            fill: parent
        }
        swipeToDelete: !pickMode

        onCountChanged: {
            if ((count > 0) && mainPage.onlineAccountsMessageVisible) {
                // Because of some contacts can take longer to arrive due the dbus delay,
                // we need to destroy the online account dialog if this happen
                PopupUtils.close(mainPage.onlineAccountsMessageDialog)
                application.unsetFirstRun()
            }
        }

        onContactClicked: {
            pageStack.push(Qt.resolvedUrl("../ContactView/ContactView.qml"),
                           {model: contactList.listModel,
                            contact: contact})
        }

        onSelectionDone: {
            if (pickMode) {
                var contacts = []
                for (var i=0; i < items.count; i++) {
                    contacts.push(items.get(i).model.contact)
                }
                exporter.contactModel = contactList.listModel
                exporter.contacts = contacts
                exporter.start()
            } else {
                var ids = []
                for (var i=0; i < items.count; i++) {
                    ids.push(items.get(i).model.contact.contactId)
                }
                contactList.listModel.removeContacts(ids)
            }
        }

        onSelectionCanceled: {
            if (pickMode) {
                if (contactContentHub) {
                    contactContentHub.cancelTransfer()
                }
                pageStack.pop()
                application.returnVcard("")
            }
        }

        onIsInSelectionModeChanged: {
            if (isInSelectionMode) {
                toolbar.opened = false
            }
        }

        onError: pageStack.contactModelError(error)
    }

    tools: ToolbarItems {
        id: toolbar

        locked: contactList.isInSelectionMode
        ToolbarButton {
            objectName: "Sync"
            action: Action {
                text: application.syncing ? i18n.tr("Syncing") : i18n.tr("Sync")
                iconName: "reload"
                enabled: !application.syncing
                onTriggered: application.startSync()
            }
        }
        ToolbarButton {
            action: Action {
                objectName: "selectButton"
                text: i18n.tr("Select")
                iconName: "select"
                onTriggered: contactList.startSelection()
            }
        }
        ToolbarButton {
            objectName: "Add"
            action: Action {
                text: i18n.tr("Add")
                iconName: "add"
                onTriggered: {
                    var newContact = mainPage.createEmptyContact("")
                    pageStack.push(Qt.resolvedUrl("../ContactEdit/ContactEditor.qml"),
                                   {model: contactList.listModel, contact: newContact})
                }
            }
        }
    }

    // WORKAROUND: Avoid the gap btw the header and the contact list when the list moves
    // see bug #1296764
    onActiveChanged: {
        contactList.returnToBounds()
    }

    Connections {
        target: pageStack
        onContactRequested: {
            pageStack.push(Qt.resolvedUrl("../ContactView/ContactView.qml"),
                           {model: contactList.listModel, contactId: contactId})
        }
        onCreateContactRequested: {
            var newContact = mainPage.createEmptyContact(phoneNumber)
            pageStack.push(Qt.resolvedUrl("../ContactEdit/ContactEditor.qml"),
                           {model: contactList.listModel, contact: newContact})
        }
        onEditContatRequested: {
            pageStack.push(Qt.resolvedUrl("../ContactEdit/ContactEditor.qml"),
                           {model: contactList.listModel, contactId: contactId, newPhoneNumber: phoneNumber })
        }
        onContactCreated: {
            mainPage.contactIndex = contact
        }
    }

    Connections {
        target: mainPage.contactModel
        onContactsChanged: {
            if (contactIndex) {
                contactList.positionViewAtContact(mainPage.contactIndex)
                mainPage.contactIndex = null
            }
        }
    }

    ContactExporter {
        id: exporter
        contactModel: contactList.listModel ? contactList.listModel : null
        outputFile: contactContentHub ? contactContentHub.createTemporaryFile() : "/tmp/vcard_address_book_app.vcf"
        onCompleted: {
            if (contactContentHub) {
                if (error == ContactModel.ExportNoError) {
                    contactContentHub.returnContacts(exporter.outputFile)
                } else {
                    contactContentHub.cancelTransfer()
                }
            }
            pageStack.pop()
            application.returnVcard(exporter.outputFile)
        }
    }


    Component.onCompleted: {
        if (pickMode) {
            contactList.startSelection()
        } else if ((contactList.count === 0) && application.firstRun) {
            mainPage.onlineAccountsMessageDialog = PopupUtils.open(onlineAccountsDialog, null)
        }

        if (TEST_DATA != "") {
            contactList.listModel.importContacts("file://" + TEST_DATA)
        }
    }
}
