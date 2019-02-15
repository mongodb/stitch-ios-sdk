import Foundation
import StitchCore
import StitchDarwinCoreTestUtils
import XCTest
import StitchCoreAdminClient

// swiftlint:disable nesting
class StitchAuthListenerIntTests: BaseStitchIntTestCocoaTouch, StitchAuthDelegate {
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

    func testOnUserLoggedInDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            func onUserLoggedIn(auth: StitchAuth, loggedInUser: StitchUser) {
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        del.work.enter()
        client.auth.login(withCredential: AnonymousCredential()) { _ in
        }

        guard del.work.wait(timeout: .now() + 10) == .success else {
            XCTFail("onUserLoggedIn not called")
            return
        }
    }

    func testOnAddUserDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            func onUserAdded(auth: StitchAuth, addedUser: StitchUser) {
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        del.work.enter()
        client.auth.login(withCredential: AnonymousCredential()) { _ in
        }

        guard del.work.wait(timeout: .now() + 10) == .success else {
            XCTFail("onUserAdded not called")
            return
        }
    }

    func testOnActiveUserChangedDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()
            var initialChange: Bool = true

            func onActiveUserChanged(auth: StitchAuth,
                                     currentActiveUser: StitchUser?,
                                     previousActiveUser: StitchUser?) {
                if initialChange {
                    XCTAssertNotNil(currentActiveUser)
                    XCTAssertNil(previousActiveUser)
                    initialChange = false
                    work.leave()
                } else {
                    XCTAssertNotNil(currentActiveUser)
                    XCTAssertNotNil(previousActiveUser)
                    work.leave()
                }
            }
        }

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)
        del.work.enter()
        client.auth.login(withCredential: AnonymousCredential()) { _ in
        }

        guard del.work.wait(timeout: .now() + 10) == .success else {
            XCTFail("onActiveUserChanged not called")
            return
        }
        del.work.enter()
        _ = try registerAndLoginWithUserPass(app: app.1,
                                             client: client,
                                             email: "email@10gen.com",
                                             pass: "tester10")

        guard del.work.wait(timeout: .now() + 10) == .success else {
            XCTFail("onActiveUserChanged not called")
            return
        }
    }
//
//    @Test
//    fun testOnUserLoggedOutDispatched() {
//        val app = createApp()
//
//        addProvider(app.second, ProviderConfigs.Anon)
//        addProvider(app.second, config = ProviderConfigs.Userpass(
//            emailConfirmationUrl = "http://emailConfirmURL.com",
//            resetPasswordUrl = "http://resetPasswordURL.com",
//            confirmEmailSubject = "email subject",
//            resetPasswordSubject = "password subject")
//        )
//
//        val client = getAppClient(app.first)
//
//        val countDownLatch = CountDownLatch(1)
//
//        client.auth.addAuthListener(object : StitchAuthListener {
//            override fun onAuthEvent(auth: StitchAuth?) {
//            }
//
//            override fun onUserLoggedOut(
//                auth: StitchAuth?,
//                loggedOutUser: StitchUser?
//            ) {
//                assertNotNull(auth)
//                assertNotNull(loggedOutUser)
//                countDownLatch.countDown()
//            }
//        })
//
//        assertFalse(client.auth.isLoggedIn)
//        assertNull(client.auth.user)
//
//        Tasks.await(client.auth.loginWithCredential(AnonymousCredential()))
//        registerAndLoginWithUserPass(app.second, client, "email@10gen.com", "tester10")
//        Tasks.await(client.auth.logout())
//        assert(countDownLatch.await(10, TimeUnit.SECONDS))
//    }

    func testOnUserRemovedDispatched() throws {
        class TestAuthDelegate: StitchAuthDelegate {
            let work = DispatchGroup()

            func onUserRemoved(auth: StitchAuth, removedUser: StitchUser) {
                work.leave()
            }
        }

        let del = TestAuthDelegate()
        client.auth.add(authDelegate: del)

        XCTAssertFalse(client.auth.isLoggedIn)
        XCTAssertNil(client.auth.currentUser)

        del.work.enter()
        client.auth.login(withCredential: AnonymousCredential()) { _ in
        }
        client.auth.removeUser { _ in
        }
        guard del.work.wait(timeout: .now() + 10) == .success else {
            XCTFail("onUserLoggedIn not called")
            return
        }
    }
//
//    @Test
//    fun testOnUserLinkedDispatched() {
//        val app = createApp()
//
//        addProvider(app.second, ProviderConfigs.Anon)
//        addProvider(app.second, config = ProviderConfigs.Userpass(
//            emailConfirmationUrl = "http://emailConfirmURL.com",
//            resetPasswordUrl = "http://resetPasswordURL.com",
//            confirmEmailSubject = "email subject",
//            resetPasswordSubject = "password subject")
//        )
//
//        val client = getAppClient(app.first)
//
//        val countDownLatch = CountDownLatch(1)
//
//        client.auth.addAuthListener(object : StitchAuthListener {
//            override fun onAuthEvent(auth: StitchAuth?) {
//            }
//
//            override fun onUserLinked(auth: StitchAuth?, linkedUser: StitchUser?) {
//                assertNotNull(auth)
//                assertNotNull(linkedUser)
//                countDownLatch.countDown()
//            }
//        })
//
//        assertFalse(client.auth.isLoggedIn)
//        assertNull(client.auth.user)
//
//        val userPassClient = client.auth.getProviderClient(UserPasswordAuthProviderClient.factory)
//
//        val email = "user@10gen.com"
//        val password = "password"
//        Tasks.await(userPassClient.registerWithEmail(email, password))
//
//        val conf = app.second.userRegistrations.sendConfirmation(email)
//        Tasks.await(userPassClient.confirmUser(conf.token, conf.tokenId))
//
//        val anonUser = Tasks.await(client.auth.loginWithCredential(AnonymousCredential()))
//
//        Tasks.await(anonUser.linkWithCredential(
//            UserPasswordCredential(email, password)))
//
//        assert(countDownLatch.await(10, TimeUnit.SECONDS))
//    }
//
//    @Test
//    fun testOnListenerRegisteredDispatched() {
//        val app = createApp()
//
//        addProvider(app.second, ProviderConfigs.Anon)
//        addProvider(app.second, config = ProviderConfigs.Userpass(
//            emailConfirmationUrl = "http://emailConfirmURL.com",
//            resetPasswordUrl = "http://resetPasswordURL.com",
//            confirmEmailSubject = "email subject",
//            resetPasswordSubject = "password subject")
//        )
//
//        val client = getAppClient(app.first)
//
//        val countDownLatch = CountDownLatch(1)
//
//        client.auth.addAuthListener(object : StitchAuthListener {
//            override fun onAuthEvent(auth: StitchAuth?) {
//            }
//
//            override fun onListenerRegistered(auth: StitchAuth?) {
//                assertNotNull(auth)
//                countDownLatch.countDown()
//            }
//        })
//
//        assert(countDownLatch.await(10, TimeUnit.SECONDS))
//    }
}
