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

import QtQuick 2.2
import Ubuntu.Components 1.1
import Ubuntu.Components.Popups 1.0 as Popups
import Ubuntu.Contacts 0.1

import Ubuntu.AddressBook.Base 0.1
import Ubuntu.AddressBook.ContactView 0.1
import Ubuntu.AddressBook.ContactShare 0.1

ContactViewPage {
    id: root
    objectName: "contactViewPage"

    property string addPhoneToContact: ""

    head.actions: [
        Action {
            objectName: "share"
            text: i18n.tr("Share")
            iconName: "share"
            onTriggered: {
                pageStack.push(contactShareComponent, {contactModel: root.model, contacts: [root.contact]})
            }
        },
        Action {
            objectName: "edit"
            text: i18n.tr("Edit")
            iconName: "edit"
            onTriggered: {
                pageStack.push(Qt.resolvedUrl("ABContactEditorPage.qml"),
                               { model: root.model, contact: root.contact})
            }
        }
    ]

    onContactRemoved: pageStack.pop()

    extensions: ContactDetailSyncTargetView {
        contact: root.contact
        anchors {
            left: parent.left
            right: parent.right
        }
        height: implicitHeight
    }

    // This will load the contact information when the app was launched with
    // the URI: addressbook:///contact?id=<id>
    onContactFetched: {
        if (root.addPhoneToContact != "") {
            var detailSourceTemplate = "import QtContacts 5.0; PhoneNumber{ number: \"" + root.addPhoneToContact.trim() + "\" }"
            var newDetail = Qt.createQmlObject(detailSourceTemplate, contact)
            if (newDetail) {
                contact.addDetail(newDetail)
                pageStack.push(Qt.resolvedUrl("ABContactEditorPage.qml"),
                               { model: root.model,
                                 contact: contact,
                                 initialFocusSection: "phones",
                                 newDetails: [newDetail]})
                root.addPhoneToContact = ""
            }
        }
    }

    onActionTrigerred: Qt.openUrlExternally(("%1:///%2").arg(action).arg(detail.value(0)))

    Component {
        id: contactShareComponent
        ContactSharePage {}
    }
}