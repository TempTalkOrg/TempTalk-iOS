import Foundation

extension OWSContactsManager {

    /// 根据 recipientId 从服务端获取联系人信息并更新本地数据库
    @objc
    public func fetchAndUpdateContactInfo(forRecipientId recipientId: String) {
        guard !recipientId.isEmpty else { return }

        TSAccountManager.sharedInstance().getContactMessageV1(byPhoneNumber: [recipientId]) { [weak self] contacts in
            guard let self = self, let newContact = contacts.first as? Contact else { return }

            self.databaseStorage.asyncWrite { transaction in
                let account = self.signalAccount(forRecipientId: recipientId, transaction: transaction)

                if let account = account, let contact = account.contact, !contact.isEqual(newContact) {
                    account.contact = newContact
                    self.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: account, with: transaction)
                } else if account == nil {
                    let newAccount = SignalAccount(recipientId: recipientId)
                    newAccount.contact = newContact
                    self.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: newAccount, with: transaction)
                }
            }
        } failure: { error in
            OWSLogger.error("fetchAndUpdateContactInfo fail for \(recipientId): \(error)")
        }
    }
}
