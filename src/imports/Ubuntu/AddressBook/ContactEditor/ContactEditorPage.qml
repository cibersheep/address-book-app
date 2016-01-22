/*
 * Copyright (C) 2012-2015 Canonical, Ltd.
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

import QtQuick 2.4
import QtContacts 5.0

import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3
import Ubuntu.Components.Popups 1.3
import Ubuntu.Contacts 0.1 as ContactsUI

import Ubuntu.AddressBook.Base 0.1

Page {
    id: contactEditor

    property QtObject contact: null
    property QtObject model: null
    property QtObject activeItem: null

    property string initialFocusSection: ""
    property var newDetails: []
    property list<QtObject> leadingActions
    property alias headerActions: trailingBar.actions

    readonly property bool isNewContact: contact && (contact.contactId === "qtcontacts:::")
    readonly property bool isContactValid: !avatarEditor.busy && (!nameEditor.isEmpty() || !phonesEditor.isEmpty())
    readonly property alias editorFlickable: scrollArea

    signal contactSaved(var contact);
    signal canceled()

    function cancel() {
        for (var i = 0; i < contactEditor.newDetails.length; ++i) {
            contactEditor.contact.removeDetail(contactEditor.newDetails[i])
        }
        contactEditor.newDetails = []

        for(var i = 0; i < contents.children.length; ++i) {
            var field = contents.children[i]
            if (field.cancel) {
                field.cancel()
            }
        }
        if (pageStack && pageStack.removePages) {
            pageStack.removePages(contactEditor)
        } else if (pageStack) {
            pageStack.pop()
        }
        contactEditor.canceled()
    }

    function save() {
        var changed = false
        for(var i = 0; i < contents.children.length; ++i) {
            var field = contents.children[i]
            if (field.save) {
                if (field.save()) {
                    changed = true
                }
            }
        }

        // new contact and there is only two details (name, avatar)
        // name and avatar, are not removable details, because of that the contact will have at least 2 details
        if (isNewContact &&
            (contact.contactDetails.length === 2)) {

            // if name is empty this means that the contact is empty
            var nameDetail = contact.detail(ContactDetail.Name)
            if (nameDetail &&
                (nameDetail.firstName && nameDetail.firstName != "") ||
                (nameDetail.lastName && nameDetail.lastName != "")) {
                // save contact
            } else {
                changed  = false
            }
        }

        if (changed) {
            // backend error will be handled by the root page (contact list)
            var newContact = (contact.model == null)
            contactEditor.model.saveContact(contact)
            if (newContact) {
                contactEditor.contactSaved(contact)
            }
        }
        if (pageStack.removePages) {
            pageStack.removePages(contactEditor)
        } else {
            pageStack.pop()
        }
    }

    function idleMakeMeVisible(item) {
        if (!enabled || !item) {
            return
        }

        activeItem = item
        timerMakemakeMeVisible.restart()
    }

    function makeMeVisible(item) {
        if (!item)
            return


        var position = item.mapToItem(editEditor, item.x, item.y);
        // check if the item is already visible
        var bottomY = scrollArea.contentY + scrollArea.height
        var itemBottom = position.y + (item.height * 3) // extra margin
        if (position.y >= scrollArea.contentY && itemBottom <= bottomY) {
            Qt.inputMethod.show()
            return;
        }

        // if it is not, try to scroll and make it visible
        var targetY = itemBottom - scrollArea.height
        if (targetY >= 0 && position.y) {
            scrollArea.contentY = targetY;
        } else if (position.y < scrollArea.contentY) {
            // if it is hidden at the top, also show it
            scrollArea.contentY = position.y;
        }

        scrollArea.returnToBounds()
        Qt.inputMethod.show()
    }

    function ready()
    {
        enabled = true
        switch (contactEditor.initialFocusSection)
        {
        case "phones":
            contactEditor.focusToLastPhoneField()
            break;
        case "name":
        default:
            nameEditor.fieldDelegates[0].forceActiveFocus()
            break;
        }
    }

    function focusToLastPhoneField()
    {
        var lastPhoneField = phonesEditor.detailDelegates[phonesEditor.detailDelegates.length - 2].item
        lastPhoneField.forceActiveFocus()
    }

    function focusToFirstEntry(field)
    {
        var itemToFocus = field
        if (field.repeater)
            itemToFocus = field.repeater.itemAt(0)

        if (itemToFocus) {
            root.idleMakeMeVisible(itemToFocus)
            itemToFocus.forceActiveFocus()
        }
    }

    Timer {
        id: timerMakemakeMeVisible

        interval: 100
        repeat: false
        running: false
        onTriggered: root.makeMeVisible(root.activeItem)
    }

    header: PageHeader {
        id: pageHeader

        title: isNewContact ? i18n.dtr("address-book-app", "New contact") : i18n.dtr("address-book-app", "Edit")
        trailingActionBar {
            id: trailingBar
        }
        leadingActionBar {
            id: leadingBar
            actions: contactEditor.leadingActions
        }
    }

    enabled: false
    flickable: null
    Timer {
        id: focusTimer

        interval: 1000
        running: false
        repeat: false
        onTriggered: contactEditor.ready()
    }

    Flickable {
        id: scrollArea
        objectName: "scrollArea"

        // this is necessary to avoid the page to appear bellow the header
        clip: true
        flickableDirection: Flickable.VerticalFlick
        anchors{
            left: parent.left
            top: parent.top
            topMargin: pageHeader.height
            right: parent.right
            bottom: keyboardRectangle.top
        }
        contentHeight: contents.height + units.gu(2)
        contentWidth: parent.width

        Column {
            id: contents

            anchors {
                top: parent.top
                topMargin: units.gu(2)
                left: parent.left
                right: parent.right
            }
            height: childrenRect.height

            Row {
                id: editEditor
                function save()
                {
                    var avatarSave = avatarEditor.save()
                    var nameSave = nameEditor.save();

                    return (nameSave || avatarSave);
                }

                function isEmpty()
                {
                    return (avatarEditor.isEmpty() && nameEditor.isEmpty())
                }

                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    right: parent.right
                }
                height: Math.max(avatarEditor.height, nameEditor.height) - units.gu(2)

                ContactDetailAvatarEditor {
                    id: avatarEditor

                    contact: contactEditor.contact
                    height: implicitHeight
                    width: implicitWidth
                    anchors.verticalCenter: editEditor.verticalCenter
                }

                ContactDetailNameEditor {
                    id: nameEditor

                    width: parent.width - avatarEditor.width
                    height: nameEditor.implicitHeight + units.gu(3)
                    contact: contactEditor.contact
                }
            }


            ContactDetailPhoneNumbersEditor {
                id: phonesEditor
                objectName: "phones"

                contact: contactEditor.contact
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: implicitHeight
                onNewFieldAdded: root.focusToFirstEntry(field)
            }

            ContactDetailEmailsEditor {
                id: emailsEditor
                objectName: "emails"

                contact: contactEditor.contact
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: implicitHeight
                onNewFieldAdded: root.focusToFirstEntry(field)
            }

            ContactDetailOnlineAccountsEditor {
                id: accountsEditor
                objectName: "ims"

                contact: contactEditor.contact
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: implicitHeight
                onNewFieldAdded: root.focusToFirstEntry(field)
            }

            ContactDetailAddressesEditor {
                id: addressesEditor
                objectName: "addresses"

                contact: contactEditor.contact
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: implicitHeight
                onNewFieldAdded: root.focusToFirstEntry(field)
            }

            ContactDetailOrganizationsEditor {
                id: organizationsEditor
                objectName: "professionalDetails"

                contact: contactEditor.contact
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: implicitHeight
                onNewFieldAdded: root.focusToFirstEntry(field)
            }

            ContactDetailSyncTargetEditor {
                id: syncTargetEditor

                active: contactEditor.active
                contact: contactEditor.contact
                anchors {
                    left: parent.left
                    right: parent.right
                }
                onChanged: {
                    if (contactEditor.enabled &&
                        !contactEditor.isNewContact &&
                        syncTargetEditor.contactIsReadOnly(contactEditor.contact)) {
                        PopupUtils.open(alertMessage)
                    }
                }
            }

            ThinDivider {}

            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: units.gu(2)
            }

            ComboButtonAddField {
                id: addNewFieldButton
                objectName: "addNewFieldButton"

                contact: contactEditor.contact
                text: i18n.dtr("address-book-app", "Add Field")
                anchors {
                    left: parent.left
                    right: parent.right
                    margins: units.gu(2)
                }
                height: implicitHeight
                activeFocusOnPress: false
                onHeightChanged: {
                    if (expanded && (height === expandedHeight) && !scrollArea.atYEnd) {
                        moveToBottom.start()
                    }
                }

                UbuntuNumberAnimation {
                    id: moveToBottom

                    target: scrollArea
                    property: "contentY"
                    to: scrollArea.contentHeight - scrollArea.height
                    onStopped: {
                        scrollArea.returnToBounds()
                        addNewFieldButton.forceActiveFocus()
                    }
                }

                onFieldSelected: {
                    if (qmlTypeName) {
                        var newDetail = Qt.createQmlObject("import QtContacts 5.0; " + qmlTypeName + "{}", contactEditor)
                        if (newDetail) {
                            var newDetailsCopy = contactEditor.newDetails
                            newDetailsCopy.push(newDetail)
                            contactEditor.newDetails = newDetailsCopy
                            contactEditor.contact.addDetail(newDetail)
                        }
                    }
                }
            }


            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: units.gu(2)
            }

            Button {
                id: deleteButton

                text: i18n.dtr("address-book-app", "Delete")
                visible: !contactEditor.isNewContact
                color: UbuntuColors.red
                anchors {
                    left: parent.left
                    right: parent.right
                    margins: units.gu(2)
                }
                action: Action {
                    enabled: contactEditor.active && deleteButton.visible
                    shortcut: "Ctrl+Delete"
                    onTriggered: {
                        var dialog = PopupUtils.open(removeContactDialog, null)
                        dialog.contacts = [contactEditor.contact]
                    }
                }
            }


            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: units.gu(2)
            }
        }
    }

    KeyboardRectangle {
        id: keyboardRectangle

        onHeightChanged: {
            if (addNewFieldButton.expanded) {
                scrollArea.contentY = scrollArea.contentHeight - scrollArea.height
                scrollArea.returnToBounds()
            } else if (activeItem) {
                idleMakeMeVisible(activeItem)
            }
        }
    }

    onActiveChanged: {
        if (!active) {
            return
        }

        if (contactEditor.initialFocusSection != "") {
            focusTimer.restart()
        } else {
            contactEditor.ready()
        }
    }

    Component {
        id: alertMessage

        Dialog {
            id: aletMessageDialog

            title: i18n.dtr("address-book-app", "Contact Editor")
            text: {
                if (ContactsUI.Contacts.updateIsRunning) {
                    return i18n.dtr("address-book-app",
                                    "Your <b>%1</b> contact sync account needs to be upgraded.\nWait until the upgrade is complete to edit contacts.")
                                    .arg(contactEditor.contact.syncTarget.syncTarget)
                }
                if (Qt.application.name === "AddressBookApp") {
                      i18n.dtr("address-book-app",
                               "Your <b>%1</b> contact sync account needs to be upgraded. Use the sync button to upgrade the Contacts app.\nOnly local contacts will be editable until upgrade is complete.")
                        .arg(contactEditor.contact.syncTarget.syncTarget)
                } else {
                      i18n.dtr("address-book-app",
                               "Your <b>%1</b> contact sync account needs to be upgraded by running Contacts app.\nOnly local contacts will be editable until upgrade is complete.")
                        .arg(contactEditor.contact.syncTarget.syncTarget);
                }
            }

            Button {
                text: i18n.dtr("address-book-app", "Close")
                onClicked: PopupUtils.close(aletMessageDialog)
            }

            Component.onCompleted: Qt.inputMethod.hide()
            Component.onDestruction: contactEditor.pageStack.removePages(contactEditor)
        }
    }

    Component {
        id: removeContactDialog

        RemoveContactsDialog {
            id: removeContactsDialogMessage

            property bool popPages: false

            onCanceled: {
                PopupUtils.close(removeContactsDialogMessage)
            }

            onAccepted: {
                popPages = true
                removeContacts(contactEditor.model)
                PopupUtils.close(removeContactsDialogMessage)
            }

            // hide virtual keyboard if necessary
            Component.onCompleted: {
                contactEditor.enabled = false
                Qt.inputMethod.hide()
            }

            // WORKAROUND: SDK element crash if pop the page where the dialog was created
            Component.onDestruction: {
                contactEditor.enabled = true
                if (popPages) {
                    if (contactEditor.pageStack.removePages) {
                        contactEditor.pageStack.removePages(contactEditor)
                    } else {
                        contactEditor.pageStack.pop() // editor page
                        contactEditor.pageStack.pop() // view page
                    }
                }
                if (contactEditor.pageStack.primaryPage)
                    contactEditor.pageStack.primaryPage.forceActiveFocus()
            }
        }
    }
}
