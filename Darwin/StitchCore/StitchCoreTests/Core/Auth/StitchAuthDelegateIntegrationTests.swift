// swiftlint:disable nesting
// swiftlint:disable function_body_length
// swiftlint:disable force_try
// swiftlint:disable file_length
// swiftlint:disable type_body_length

import Foundation
import StitchCore
import StitchDarwinCoreTestUtils
import XCTest
import StitchCoreAdminClient

class StitchAuthDelegateIntTests: BaseStitchIntTestCocoaTouch {
    private var client: StitchAppClient!
    private var app: (AppResponse, Apps.App)!

    override func setUp() {
        super.setUp()
        do {
            self.app = try createApp()

            _ = try addProvider(toApp: app.1, withConfig: .anon())
            _ = try addProvider(toApp: app.1, withConfig: .userpass(
                emailConfirmationURL: "http://emailConfirmURL.com",
                resetPasswordURL: "http://resetPasswordURL.com",
                confirmEmailSubject: "email subject",
                resetPasswordSubject: "password subject"))

            self.client = try appClient(forApp: app.0)
        } catch let err {
            XCTFail(err.localizedDescription)
        }
    }

    func waitForDelegate(work: DispatchGroup) {
        guard work.wait(timeout: .now() + 20) == .success else {
            // note: this is a fatalError so that there is a stack trace when debugging
            fatalError("expected assertion not called")
        }
    }

    func testOnUserAddedDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var numCalls = 0

            func onUserAdded(auth: StitchAuth, addedUser: StitchUser) {
                XCTAssertNotNil(addedUser.id)
                numCalls += 1
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        // this should trigger the user being added
        del.work.enter()
        _ = try self.registerAndLoginWithUserPass(
            app: self.app.1, client: client, email: "test@10gen.com", pass: "hunter1"
        )
        waitForDelegate(work: del.work)

        // this should not trigger the user added event because the user already exists
        var exp = expectation(description: "should not trigger any event")
        client.auth.logout { _ in
            self.client.auth.login(withCredential: UserPasswordCredential(
                withUsername: "test@10gen.com", withPassword: "hunter1")) { _ in
                    exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10)

        // this should trigger another user added event
        del.work.enter()
        var anonUser1Id = ""
        client.auth.login(withCredential: AnonymousCredential()) { (result: StitchResult<StitchUser>) in
            switch result {
            case .success(let result):
                anonUser1Id = result.id
            case .failure(let error):
                XCTFail("unexpected error: \(error.description)")
            }
        }
        waitForDelegate(work: del.work)

        // logging out of the anon user and logging back in should trigger an added user event
        // because logging out of an anon user removes the user
        exp = expectation(description: "should logout anon user")
        client.auth.logoutUser(withId: anonUser1Id) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        del.work.enter()
        var anonUser2Id = ""
        client.auth.login(withCredential: AnonymousCredential()) { (result: StitchResult<StitchUser>) in
            switch result {
            case .success(let result):
                anonUser2Id = result.id
            case .failure(let error):
                XCTFail("unexpected error: \(error.description)")
            }
        }

        waitForDelegate(work: del.work)

        XCTAssertNotEqual(anonUser1Id, anonUser2Id)

        // assert that onUserAdded was only called three times
        XCTAssertEqual(del.numCalls, 3)
    }

    func testOnUserLoggedInDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var numCalls = 0

            func onUserLoggedIn(auth: StitchAuth, loggedInUser: StitchUser) {
                XCTAssertNotNil(loggedInUser.id)
                XCTAssertTrue(loggedInUser.isLoggedIn)
                numCalls += 1
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        // this should trigger the user being logged in
        del.work.enter()
        _ = try self.registerAndLoginWithUserPass(
            app: self.app.1, client: client, email: "test@10gen.com", pass: "hunter1"
        )
        waitForDelegate(work: del.work)

        // this should also trigger the user logging in
        var exp = expectation(description: "user should log out")
        client.auth.logout { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        del.work.enter()
        var emailPassUser: StitchUser?
        client.auth.login(withCredential: UserPasswordCredential(
            withUsername: "test@10gen.com",
            withPassword: "hunter1")) { (result: StitchResult<StitchUser>) in
                switch result {
                case .success(let result):
                    emailPassUser = result
                case .failure(let error):
                    XCTFail("unexpected error: \(error.description)")
                }
        }
        waitForDelegate(work: del.work)

        // this should trigger yet another user logged in event
        del.work.enter()
        var anonUser: StitchUser?
        client.auth.login(withCredential: AnonymousCredential()) { (result: StitchResult<StitchUser>) in
                switch result {
                case .success(let result):
                    anonUser = result
                case .failure(let error):
                    XCTFail("unexpected error: \(error.description)")
                }
        }
        waitForDelegate(work: del.work)

        // logging into the anonymous user again, even when not the active user,
        // should not trigger a login event, since under the hood it is simply
        // changing the active user and re-using the anonymous session.
        exp = expectation(description: "login with anonymous credential multiple times")
        client.auth.login(withCredential: AnonymousCredential()) { _ in
            _ = try! self.client.auth.switchToUser(withId: emailPassUser!.id)
            self.client.auth.login(withCredential: AnonymousCredential()) { _ in
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 10)

        XCTAssertEqual(client.auth.currentUser!.id, anonUser!.id)

        // assert that onUserLoggedIn was called only three times
        XCTAssertEqual(del.numCalls, 3)
    }

    func testOnUserLoggedOutDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var numCalls = 0

            func onUserLoggedOut(auth: StitchAuth, loggedOutUser: StitchUser) {
                XCTAssertNotNil(loggedOutUser.id)
                XCTAssertFalse(loggedOutUser.isLoggedIn)
                numCalls += 1
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        _ = try registerAndLoginWithUserPass(
            app: self.app.1, client: client, email: "test@10gen.com", pass: "hunter1"
        )

        // this should trigger the user logging out
        del.work.enter()
        client.auth.logout { _ in }
        waitForDelegate(work: del.work)

        var exp = expectation(description: "should log back in")
        var emailPassUser: StitchUser?
        client.auth.login(withCredential: UserPasswordCredential(
            withUsername: "test@10gen.com", withPassword: "hunter1"
        )) { result in
            switch result {
            case .success(let result):
                emailPassUser = result
            case .failure(let error):
                XCTFail("unexpected error: \(error.description)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)

        // logging a user out when they're not the active user should trigger a logout event
        del.work.enter()
        client.auth.login(withCredential: AnonymousCredential()) { _ in
            self.client.auth.logoutUser(withId: emailPassUser!.id, { _ in
            })
        }
        waitForDelegate(work: del.work)

        // logging out a user when they are already logged out should not trigger a logout event
        exp = expectation(description: "log out a logged out user")
        client.auth.logoutUser(withId: emailPassUser!.id, { _ in exp.fulfill() })
        wait(for: [exp], timeout: 10)

        // removing a user should trigger a logout they are already logged in
        del.work.enter()
        client.auth.removeUser { _ in }
        waitForDelegate(work: del.work)

        // removing a user who is already logged out should not trigger a logout
        exp = expectation(description: "remove a logged out user")
        client.auth.removeUser(withId: emailPassUser!.id, { _ in exp.fulfill() })
        wait(for: [exp], timeout: 10)

        // make sure there are no more users left after removing everyone
        XCTAssertEqual(client.auth.listUsers().count, 0)

        // assert that onUserLoggedOut was called only three times
        XCTAssertEqual(del.numCalls, 3)
    }

    func testOnActiveUserChangedDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var expectingCurrentUserToExist = false
            var expectingPreviousUserToExist = false
            var numCalls = 0

            func onActiveUserChanged(auth: StitchAuth,
                                     currentActiveUser: StitchUser?,
                                     previousActiveUser: StitchUser?) {
                XCTAssertEqual(currentActiveUser != nil, expectingCurrentUserToExist)
                XCTAssertEqual(previousActiveUser != nil, expectingPreviousUserToExist)
                numCalls += 1
                work.leave()
            }
        }

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        // this should trigger the event with a current user and no previous user
        del.expectingCurrentUserToExist = true
        del.expectingPreviousUserToExist = false
        del.work.enter()
        _ = try registerAndLoginWithUserPass(
            app: self.app.1, client: client, email: "test@10gen.com", pass: "hunter1"
        )
        waitForDelegate(work: del.work)

        // this should trigger the event with a previous user and no current user
        del.expectingCurrentUserToExist = false
        del.expectingPreviousUserToExist = true
        del.work.enter()
        client.auth.logout { _ in }
        waitForDelegate(work: del.work)

        // this should trigger the event with a current user and no previous user
        del.expectingCurrentUserToExist = true
        del.expectingPreviousUserToExist = false
        del.work.enter()
        var emailPassUser: StitchUser?
        client.auth.login(
        withCredential: UserPasswordCredential(withUsername: "test@10gen.com", withPassword: "hunter1")) { result in
            switch result {
            case .success(let result):
                emailPassUser = result
            case .failure(let error):
                XCTFail("unexpected error: \(error.description)")
            }
        }
        waitForDelegate(work: del.work)

        // logging in a user when there is an active user should trigger the event with both a current user and
        // no previous user
        del.expectingCurrentUserToExist = true
        del.expectingPreviousUserToExist = true
        del.work.enter()
        client.auth.login(withCredential: AnonymousCredential()) { _ in }
        waitForDelegate(work: del.work)

        // logging a user out when they're not the active user should not trigger an active user changed event
        var exp = expectation(description: "log out a non-active user")
        client.auth.logoutUser(withId: emailPassUser!.id) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        // logging out a user when they're already logged out should not trigger an active user changed event
        exp = expectation(description: "log out a logged out user")
        client.auth.logoutUser(withId: emailPassUser!.id) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        // removing a user should trigger the event with a previous user and
        // no current user if they are the active user
        del.expectingCurrentUserToExist = false
        del.expectingPreviousUserToExist = true
        del.work.enter()
        client.auth.removeUser { _ in }
        waitForDelegate(work: del.work)

        // removing a user who is already logged out should not trigger the event
        exp = expectation(description: "remove a logged out user")
        client.auth.removeUser(withId: emailPassUser!.id) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        // make sure there are no users left after removing everyone
        XCTAssertEqual(client.auth.listUsers().count, 0)

        // assert that the onActiveUserChanged event was called only five times
        XCTAssertEqual(del.numCalls, 5)
    }

    func testOnUserRemovedDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var numCalls = 0

            func onUserRemoved(auth: StitchAuth, removedUser: StitchUser) {
                XCTAssertNotNil(removedUser.id)
                XCTAssertFalse(removedUser.isLoggedIn)
                numCalls += 1
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        let emailPassUserId = try registerAndLoginWithUserPass(
            app: self.app.1, client: client, email: "test@10gen.com", pass: "hunter1"
        )

        // logging out an email/pass user should not trigger the remove event
        var exp = expectation(description: "log out an email/pass user")
        client.auth.logout { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        // removing a user when they're not the active user should trigger a remove event
        exp = expectation(description: "should log in as anon user")
        client.auth.login(withCredential: AnonymousCredential()) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 10)

        del.work.enter()
        client.auth.removeUser(withId: emailPassUserId) { _ in }
        waitForDelegate(work: del.work)

        // logging out an anonymous user should trigger a remove
        del.work.enter()
        client.auth.logout { _ in }
        waitForDelegate(work: del.work)

        // make sure there are no more users left after removing everyone
        XCTAssertEqual(client.auth.listUsers().count, 0)

        // log back in as the email/pass user, and assert that removing the active user triggers the remove event
        del.work.enter()
        client.auth.login(
            withCredential: UserPasswordCredential(withUsername: "test@10gen.com", withPassword: "hunter1")
        ) { _ in self.client.auth.removeUser(withId: emailPassUserId) { _ in } }
        waitForDelegate(work: del.work)

        // make sure there are no more users left after removing everyone
        XCTAssertEqual(client.auth.listUsers().count, 0)

        // assert that the onActiveUserChanged event was called only three times
        XCTAssertEqual(del.numCalls, 3)
    }

    func testOnUserLinkedDispatched() {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var numCalls = 0
            var expectedUserId: String!

            func onUserLinked(auth: StitchAuth, linkedUser: StitchUser) {
                XCTAssertEqual(linkedUser.id, expectedUserId)
                XCTAssertTrue(linkedUser.isLoggedIn)
                XCTAssertEqual(linkedUser.identities.count, 2)
                numCalls += 1
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        let userPassClient = client.auth.providerClient(fromFactory: userPasswordClientFactory)

        var exp = expectation(description: "should create an email identity to link to")
        userPassClient.register(withEmail: "test@10gen.com", withPassword: "hunter1") { _ in
            let conf = try! self.app.1.userRegistrations.sendConfirmation(toEmail: "test@10gen.com")
            userPassClient.confirmUser(withToken: conf.token, withTokenID: conf.tokenID) { _ in exp.fulfill() }
        }
        wait(for: [exp], timeout: 10)

        exp = expectation(description: "log in as an anon user")
        var anonUser: StitchUser!
        client.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success(let result):
                anonUser = result
            case .failure(let error):
                XCTFail("unexpected error: \(error.description)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10)

        del.expectedUserId = anonUser.id

        // linking to the user/password auth provider identity should trigger the link event
        del.work.enter()
        anonUser.link(
            withCredential: UserPasswordCredential(withUsername: "test@10gen.com", withPassword: "hunter1")
        ) { _ in }
        waitForDelegate(work: del.work)

        // assert that there is one user in the list, because the linking should not have created a new user
        XCTAssertEqual(client.auth.listUsers().count, 1)

        // assert that the onUserLinked event got called only once
        XCTAssertEqual(del.numCalls, 1)
    }

    func testOnDelegateRegisteredDispatched() {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var numCalls = 0

            func onDelegateRegistered(auth: StitchAuth) {
                XCTAssertFalse(auth.isLoggedIn)
                numCalls += 1
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        del.work.enter()
        client.auth.add(authDelegate: del)
        waitForDelegate(work: del.work)

        // assert the onDelegateRegistered event got called once
        XCTAssertEqual(del.numCalls, 1)
    }
}
