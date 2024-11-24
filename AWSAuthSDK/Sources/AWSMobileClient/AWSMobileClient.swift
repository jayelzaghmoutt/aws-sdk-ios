//
// Copyright 2017-2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/apache2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

import Foundation

public struct HarriSession: Codable {
    
    var idToken = HarriCognitoIdentityUserSessionToken()
    var accessToken = HarriCognitoIdentityUserSessionToken()
    var refreshToken = HarriCognitoIdentityUserSessionToken()
    var expiryTime: Date?
    var username: String?
    var SSO: Bool = false
    
    var signInInfo: [String: String] = [:]
    
    init(authSession: AWSCognitoAuthUserSession, username: String?, signInInfo: [String: String]) {
        
        if let awsIdToken = authSession.idToken, let awsAccessToken = authSession.accessToken, let awsrefreshToken = authSession.refreshToken {
         
            self.idToken = HarriCognitoIdentityUserSessionToken(tokenString: awsIdToken.tokenString, tokenClaims: [:])
            self.accessToken = HarriCognitoIdentityUserSessionToken(tokenString: awsAccessToken.tokenString, tokenClaims: [:])
            self.refreshToken = HarriCognitoIdentityUserSessionToken(tokenString: awsrefreshToken.tokenString, tokenClaims: [:])

            self.expiryTime = authSession.expirationTime
            
            self.username = username
            
            self.signInInfo = signInInfo
            self.SSO = true
        }
    }
    
    init(session: AWSCognitoIdentityUserSession, username: String?) {
        
        if let awsIdToken = session.idToken, let awsAccessToken = session.accessToken, let awsrefreshToken = session.refreshToken {
            
            self.idToken = HarriCognitoIdentityUserSessionToken(tokenString: awsIdToken.tokenString, tokenClaims: awsIdToken.tokenClaims)
            self.accessToken = HarriCognitoIdentityUserSessionToken(tokenString: awsAccessToken.tokenString, tokenClaims: awsAccessToken.tokenClaims)
            self.refreshToken = HarriCognitoIdentityUserSessionToken(tokenString: awsrefreshToken.tokenString,tokenClaims: awsrefreshToken.tokenClaims)

            self.expiryTime = session.expirationTime
            
            self.username = username
        }
    }
    
    public var getUserName: String? {
        get {
            self.username
        }
    }
    
    public var getIdToken: String {
        get {
            self.idToken.tokenString
        }
    }
    
    public var getAccessToken: String {
        get {
            self.accessToken.tokenString
        }
    }
    
    public var getRefreshToken: String {
        get {
            self.refreshToken.tokenString
        }
    }
    
    public var getExpiryDate: Date? {
        get {
            self.expiryTime
        }
    }
    
    func getAWSCognitoIdentityUserSession() -> AWSCognitoIdentityUserSession {
        
        let idToken = AWSCognitoIdentityUserSessionToken()
        idToken.updateWithtokenString(self.idToken.tokenString, tokenClaims: self.idToken.tokenClaims)
        
        let accessToken = AWSCognitoIdentityUserSessionToken()
        accessToken.updateWithtokenString(self.accessToken.tokenString, tokenClaims: self.accessToken.tokenClaims)
        
        let refreshToken = AWSCognitoIdentityUserSessionToken()
        refreshToken.updateWithtokenString(self.refreshToken.tokenString, tokenClaims: self.refreshToken.tokenClaims)
        
        
        let userSession = AWSCognitoIdentityUserSession()
        userSession.update(withIdToken: idToken, accessToken: accessToken, refreshToken: refreshToken, expirationTime: self.expiryTime)
        
        return userSession
    }
    
    func getAWSCognitoAuthUserSession() -> AWSCognitoAuthUserSession {
     
        let idToken = AWSCognitoAuthUserSessionToken()
        idToken.updateWithtokenString(self.idToken.tokenString, tokenClaims: self.idToken.tokenClaims)
        
        let accessToken = AWSCognitoAuthUserSessionToken()
        accessToken.updateWithtokenString(self.accessToken.tokenString, tokenClaims: self.accessToken.tokenClaims)
        
        let refreshToken = AWSCognitoAuthUserSessionToken()
        refreshToken.updateWithtokenString(self.refreshToken.tokenString, tokenClaims: self.refreshToken.tokenClaims)
        
        
        let authSession = AWSCognitoAuthUserSession()
        authSession.update(withIdToken: idToken, accessToken: accessToken, refreshToken: refreshToken, expirationTime: self.expiryTime)
        
        return authSession
    }
}

struct HarriCognitoIdentityUserSessionToken: Codable {
    var tokenString = ""
    var tokenClaims: [String: Any] = [:]
    
    init() {
        tokenString = ""
        tokenClaims = [:]
    }
    
    init(tokenString: String, tokenClaims: [String: Any]) {
        
        self.tokenString = tokenString
        self.tokenClaims = tokenClaims
    }
    
    init(from decoder: Decoder) throws {
        self.init()
        
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        if let value = try? values.decodeIfPresent(String.self, forKey: CodingKeys.tokenString){
            self.tokenString = value
        }
        
        // to get the claims and token claims
        
        
    }
    
    /**
     Encoder
     */
    func encode(to encoder: Encoder) throws  {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.tokenString, forKey: .tokenString)
    }
    
    enum CodingKeys: CodingKey {
        case tokenString
        case claims
        case tokenClaims
    }
}

/// `AWSMobileClient` is used for all auth related operations when your app is accessing AWS backend.
final public class AWSMobileClient: _AWSMobileClient {
    
    static var _sharedInstance: AWSMobileClient = AWSMobileClient(setDelegate: true)

    static var serviceConfiguration: CognitoServiceConfiguration? = nil
    
    // MARK: State handler variables
    
    var federationProvider: FederationProvider = .none
    var cachedLoginsMap: [String: String] = [:]
    /// Internal variable used to make sure AWSMobileClient is initialized only once.
    internal var isInitialized: Bool = false

    internal var federationDisabled: Bool = false
    internal var customRoleArnInternal: String? = nil
    
    internal var signInURIQueryParameters: [String: String]? = nil
    internal var tokenURIQueryParameters: [String: String]? = nil
    internal var signOutURIQueryParameters: [String: String]? = nil
    internal var scopes: [String]? = nil

    // UserPoolOperationHandler should be initialized after AWSMobileClient init and AWSInfo init is
    // completed, because it require the AWSInfo to be in a valid state to initialize. To achieve this
    // currently userpoolOpsHelper is initialized inside `_internalInitialize`.
    internal var userpoolOpsHelper: UserPoolOperationsHandler?

    internal static func missingUserpoolOpsHelperError() -> AWSMobileClientError {
        return AWSMobileClientError.invalidConfiguration(message: "Missing CognitoUserPool helper.")
    }

    internal static func missingCurrentActiveUser() -> AWSMobileClientError {
        return AWSMobileClientError.notSignedIn(message: AWSMobileClientConstants.notSignedInMessage)
    }
    
    
    public var previousSession: HarriSession?
    public var currentSession: HarriSession?
    
    public func updateCachedData(name: String?, idToken: String, refreshToken: String, accessToken: String, expiryDate: Date?) {
        
        self.userpoolOpsHelper?.currentActiveUser?.setName(name)
        
        if let name {
            // set current user in the key chain
            self.userpoolOpsHelper?.userpoolClient?.setCurrentUser(name)
            
        }
        
        self.userpoolOpsHelper?.currentActiveUser?.updateInKeyChanin(withIdToken: idToken, accessToken: accessToken, refreshToken: refreshToken, expirationTime: expiryDate)
    }
    
    public func swapSessions() {
        
        self.clearCurrentCredintials()
        
        if let previousSession {
            
            if previousSession.SSO {
                
                self.swapToAuthSession()
            } else {
                self.swapToUserSession()
            }
        }
    }
    
    
    private func swapToUserSession() {
        
        if let previousSession {
            self.internalCredentialsProvider?.clearCredentials()
            self.federationProvider = .userPools
            self.performUserPoolSuccessfulSignInTasks(session: previousSession.getAWSCognitoIdentityUserSession())
            let tokenString = currentSession!.getAWSCognitoIdentityUserSession().idToken!.tokenString
            self.mobileClientStatusChanged(
                userState: .signedIn,
                additionalInfo: [
                    AWSMobileClientConstants.ProviderKey:self.userPoolClient!.identityProviderName,
                    AWSMobileClientConstants.TokenKey:tokenString])
            self.invokeSignInCallback(signResult: SignInResult(signInState: .signedIn), error: nil)
        }
    }
    
    private func swapToAuthSession() {
        
        if let previousSession {
            var signInInfo = previousSession.signInInfo
            
            let hostedUIOptions = HostedUIOptions(disableFederation: false, scopes: ["profile","openid", "email"], identityProvider: signInInfo["identityProvider"], idpIdentifier: nil, federationProviderName: nil, signInURIQueryParameters: nil, tokenURIQueryParameters: nil, signOutURIQueryParameters: nil, signInPrivateSession: true)
            
            
            self.scopes = hostedUIOptions.scopes
            
            self.saveHostedUIOptionsScopesInKeychain()
            
            let session = previousSession.getAWSCognitoAuthUserSession()
            
            var federationToken: String = ""
            if let idToken = session.idToken?.tokenString {
                federationToken = idToken
            } else if let accessToken = session.accessToken?.tokenString {
                federationToken = accessToken
            }
            
            self.performHostedUISuccessfulSignInTasks(disableFederation: hostedUIOptions.disableFederation, session: session, federationToken: federationToken, federationProviderIdentifier: hostedUIOptions.federationProviderName, signInInfo: &signInInfo)
            self.mobileClientStatusChanged(userState: .signedIn, additionalInfo: signInInfo)
            
            configureAndRegisterCognitoAuth(hostedUIOptions: hostedUIOptions, {_,_ in })
        }
    }
    
    public func clearCurrentCredintials() {
        self.internalCredentialsProvider?.clearCredentials()
        self.cachedLoginsMap = [:]
        self.saveLoginsMapInKeychain()
        self.internalCredentialsProvider?.clearKeychain()
        self.currentUserState = .signedOut
    }

    // MARK: Execution Helpers (DispatchQueue, OperationQueue, DispatchGroup)
    
    // Internal DispatchQueue which will be used synchronously to initialize the AWSMobileClient.
    internal let initializationQueue = DispatchQueue(label: "awsmobileclient.credentials.fetch")
    
    /// Operation Queue to make sure there is only 1 active API call which is fetching/ waiting for UserPools token.
    internal let tokenFetchOperationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "AWSMobileClient.tokenFetchOperationQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /// Operation Queue to make sure there is only 1 active API call which is fetching/ waiting for AWS Credentials.
    internal let credentialsFetchOperationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "AWSMobileClient.credentialsFetchOperationQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    /// This token is invoked when the developer explicitly calls the signOut from
    /// AWSMobileClient, thus invalidating all credentials calls.
    var credentialsFetchCancellationSource: AWSCancellationTokenSource = AWSCancellationTokenSource()
    
    /// The internal Cognito Credentials Provider
    var internalCredentialsProvider: AWSCognitoCredentialsProvider?
    
    // Used as lock when AWSCredentials are requested
    internal var pendingAWSCredentialsCompletion: ((AWSCredentials?, Error?) -> Void)? = nil
    
    internal weak var developerNavigationController: UINavigationController? = nil
    
    var keychain: AWSUICKeyChainStore = AWSUICKeyChainStore.init(
        service: "\(String(describing: Bundle.main.bundleIdentifier)).AWSMobileClient")
    
    internal var isCognitoAuthRegistered = false
    
    /// The registered listeners who want to observe change in `UserState`.
    var listeners: [(AnyObject, UserStateChangeCallback)] = []

    /// Holds a reference to the AWSInfo configuration object
    internal lazy var awsInfo: AWSInfo = {
        return AWSInfo.default()
    }()
    
    /// Hold on to user password for custom auth. Password verification can
    /// come as the second step in custom auth.
    var userPassword: String? = nil

    var tokenOperations: WeakHashTable<FetchUserPoolTokensOperation> = WeakHashTable()

    // MARK: Public API variables
    
    /// Returns the current state of user. If MobileClient is not initialized, it will return `unknown`
    public var currentUserState: UserState = .unknown
    
    public var deviceOperations: DeviceOperations = DeviceOperations.sharedInstance


    /// The singleton instance of `AWSMobileClient`.
    ///
    /// **Deprecation note:** use `AWSMobileClient.default()` since it communicates better the API intent.
    ///
    /// - Returns: The singleton `AWSMobileClient` instance.
    @available(*, deprecated, renamed: "default")
    @objc override public class func sharedInstance() -> AWSMobileClient {
        return self.default()
    }

    /// The default instance of `AWSMobileClient`. The configuration is loaded from the `awsconfiguration.json` file.
    ///
    /// You can manage your own instance of `AWSMobileClient` by constructing it with `AWSMobileClient(configuration)`,
    /// however please note that multiple instances of AWSMobileClient is not supported.
    ///
    /// **Implementation Notes:**
    ///
    /// The `AWSMobileClient` relies on `AWSInfo` for configuration and once that class is initialized, the configuration
    /// cannot be reset and/or re-initialized. Therefore, even though you can instantiate `AWSMobileClient` multiple times,
    /// all instances will have the same configuration reference.
    ///
    /// - Returns: The default `AWSMobileClient` instance
    @objc public class func `default`() -> AWSMobileClient {
        return _sharedInstance
    }
    
    /// Check if there was a previous configuration with different values for user pool and identity pool. If we find that there is a previous configuration
    /// and the configuration are different from the present, clear all keychain values. Exception is the case where the previous configuration was only
    /// identity pool and developer decide to add user pool configuration with the same identitypool, in this case we do not clear keychain.
    ///
    func cleanupPreviousInstall() {
        let userpoolInfo = self.awsInfo.rootInfoDictionary["CognitoUserPool"] as? [String: [String: Any]]
        let userpoolDefault: [String: Any]? = userpoolInfo?["Default"]
        let userPoolClientId = userpoolDefault?["AppClientId"] ?? ""
        let userPooldId = userpoolDefault?["PoolId"] ?? ""
        
        let identityPoolInfo = self.awsInfo.rootInfoDictionary["CredentialsProvider"] as? [String: [String: Any]]
        let identityPoolDefault: [String: Any]? = identityPoolInfo?["CognitoIdentity"]?["Default"] as? [String: Any]
        let identityPoolId: String = identityPoolDefault?["PoolId"] as? String ?? ""
        
        let configValue = "\(userPooldId)#\(userPoolClientId)#\(identityPoolId)"
        if let existingConfigValue = self.keychain.string(forKey: AWSMobileClientConstants.ConfigurationKey),
           !existingConfigValue.isEmpty,
           !previousWasSameIdentityPool(previousConfig: existingConfigValue, currentIdentityPool: identityPoolId),
           configValue != existingConfigValue {
            
            let infoObject = AWSInfo.default().defaultServiceInfo("IdentityManager")
            if let credentialsProvider = infoObject?.cognitoCredentialsProvider {
                credentialsProvider.clearKeychain()
            }
            self.keychain.removeAllItems()
            self.clearKeychain()
            self.signOut()
        }
        self.keychain.setString(configValue, forKey: AWSMobileClientConstants.ConfigurationKey)
    }
    
    func previousWasSameIdentityPool(previousConfig: String, currentIdentityPool: String) -> Bool {
        
        let parts = previousConfig.split(separator: "#", omittingEmptySubsequences: false)
        if (parts[0].isEmpty && parts[1].isEmpty &&
            parts[2] == currentIdentityPool) {
            return true
        }
        return false
    }
    
    func saveConfig(userPoolID: String = "",
                    appClientID: String = "",
                    identityPoolID: String = "") {
        let configValue = "\(userPoolID)#\(appClientID)#\(identityPoolID)"
        self.keychain.setString(configValue, forKey: "configurationKey")
    }
    
    /// Initializes `AWSMobileClient` and determines the `UserState` for current user using cache.
    ///
    /// - Parameter completionHandler: Callback which describes current user's state.
    public func initialize(_ completionHandler: @escaping (UserState?, Error?) -> Void) {
        // Read awsconfiguration.json and set the credentials provider here
        initializationQueue.sync {
            if (isInitialized) {
                completionHandler(self.currentUserState, nil)
                return
            }
            _internalInitialize(completionHandler)
            isInitialized = true
        }
    }

    // Internal initialize method, pass userpoolHandler for testing purposes only.
    internal func _internalInitialize(
        userPoolHandler: UserPoolOperationsHandler = .sharedInstance,
        _ completionHandler: @escaping (UserState?, Error?) -> Void) {
        do {
            keychain.migrateToCurrentAccessibility()
            userpoolOpsHelper = userPoolHandler
            cleanupPreviousInstall()
            initializeKeychainItems()
            fallbackLegacyFederationProvider()

            DeviceOperations.sharedInstance.mobileClient = self

            try registerIfPresentHostedUI()

            setIfPresentCustomAuth()
            setIfPresentCredentialsProvider()

            currentUserState = determineInitialUserState()
            completionHandler(currentUserState, nil)
        } catch {
            completionHandler(nil, error)
        }
    }

    /// Using the cached keychain items determine the user state.
    private func determineInitialUserState() -> UserState {
        var userState: UserState = .signedOut
        if (self.cachedLoginsMap.count > 0) {
            userState = .signedIn

        } else if let credentialProvider = self.internalCredentialsProvider,
                  credentialProvider.identityId != nil {
            userState = (federationProvider == .none) ? .guest : .signedIn
        }

        // SignOut if we get an invalid signedIn state
        if userState == .signedIn
            && !isValidSignedInState (
                userState: userState,
                federationProvider: federationProvider
            ) {
            AWSMobileClientLogging.verbose("Invalid signedIn state found, signing out")
            signOut()
            userState = .signedOut
        }
        return userState
    }

    private func isValidSignedInState(
        userState: UserState,
        federationProvider: FederationProvider) -> Bool {
            if federationProvider == .userPools || federationProvider == .hostedUI {
                return self.username != nil
            }
            return federationProvider == .oidcFederation &&
            self.internalCredentialsProvider?.identityId != nil
        }
    
    /// Adds a listener who receives notifications on user state change.
    ///
    /// - Parameters:
    ///   - object: The object who intends to receive notification. A strong reference is held to the object and the developer is
    ///   required to call `removeUserStateListener` to stop getting notifications and release the object.
    ///   - callback: Callback describing the new user state.
    public func addUserStateListener(_ object: AnyObject, _ callback: @escaping UserStateChangeCallback)  {
        listeners.append((object, callback))
    }
    
    /// Removes a registered listener. If no listener exists, call is ignored.
    ///
    /// - Parameter object: The object to be de-registered from receiving notifications.
    public func removeUserStateListener(_ object: AnyObject) {
        listeners = listeners.filter { return !($0.0 === object)}
    }
    
    internal func mobileClientStatusChanged(userState: UserState, additionalInfo: [String: String]) {
        self.currentUserState = userState
        for operation in tokenOperations.allObjects {
            operation.authStateChanged(currentUserState)
        }
        for listener in listeners {
            listener.1(userState, additionalInfo)
        }
    }

    private func initializeKeychainItems() {
        loadLoginsMapFromKeychain()
        loadFederationProviderMetadataFromKeychain()
    }

    private func fallbackLegacyFederationProvider() {
        // legacy fallback logic to determine federation provider for AWSMobileClient
        if self.federationProvider == .none && self.cachedLoginsMap.count > 0 {
            if self.userPoolClient?.currentUser()?.isSignedIn == true {
                self.federationProvider = .userPools
            } else {
                self.federationProvider = .oidcFederation
            }
        }
    }

    private func setIfPresentCustomAuth() {
        let infoDict = self.awsInfo.rootInfoDictionary["Auth"] as? [String: [String: Any]]
        if let authFlowType = infoDict?["Default"]?["authenticationFlowType"] as? String,
           authFlowType == "CUSTOM_AUTH" {
            self.userPoolClient?.isCustomAuth = true
        }
    }

    private func setIfPresentCredentialsProvider() {
        let infoObject = AWSInfo.default().defaultServiceInfo("IdentityManager")
        if let credentialsProvider = infoObject?.cognitoCredentialsProvider {

            self.internalCredentialsProvider = credentialsProvider
            self.update(self)
            self.internalCredentialsProvider?.setIdentityProviderManagerOnce(self)
            self.registerConfigSignInProviders()
        }
    }

    private func registerIfPresentHostedUI() throws {
        guard self.federationProvider == .hostedUI else { return }

        loadHostedUIScopesFromKeychain()
        loadOAuthURIQueryParametersFromKeychain()

        let infoDictionaryMobileClient = self.awsInfo.rootInfoDictionary["Auth"] as? [String: [String: Any]]
        let infoDictionary: [String: Any]? = infoDictionaryMobileClient?["Default"]?["OAuth"] as? [String: Any]

        let clientId = infoDictionary?["AppClientId"] as? String
        let secret = infoDictionary?["AppClientSecret"] as? String
        guard let webDomain = infoDictionary?["WebDomain"] as? String else {
            throw AWSMobileClientError.invalidConfiguration(
                message: "WebDomain is missing in the configuration for hosted UI")
        }
        let hostURL = "https://\(webDomain)"
        if self.scopes == nil {
            self.scopes = infoDictionary?["Scopes"] as? [String]
        }

        let signInRedirectURI = infoDictionary?["SignInRedirectURI"] as? String
        let signInURI = infoDictionary?["SignInURI"] as? String
        if self.signInURIQueryParameters == nil {
            self.signInURIQueryParameters = infoDictionary?["SignInURIQueryParameters"] as? [String: String]
        }

        let signOutRedirectURI = infoDictionary?["SignOutRedirectURI"] as? String
        let signOutURI = infoDictionary?["SignOutURI"] as? String
        if self.signOutURIQueryParameters == nil {
            self.signOutURIQueryParameters = infoDictionary?["SignOutURIQueryParameters"] as? [String: String]
        }

        let tokensURI = infoDictionary?["TokenURI"] as? String
        if self.tokenURIQueryParameters == nil {
            self.tokenURIQueryParameters = infoDictionary?["TokenURIQueryParameters"] as? [String: String]
        }

        guard
            let clientId = clientId,
            let scopes = scopes,
            let signInRedirectURI = signInRedirectURI,
            let signOutRedirectURI = signOutRedirectURI
        else {
            throw AWSMobileClientError.invalidConfiguration(
                message: "Please provide all configuration parameters to use the hosted UI feature.")
        }

        let cognitoAuthConfig = AWSCognitoAuthConfiguration(
            appClientId: clientId,
            appClientSecret: secret,
            scopes: Set<String>(scopes.map { $0 }),
            signInRedirectUri: signInRedirectURI,
            signOutRedirectUri: signOutRedirectURI,
            webDomain: hostURL,
            identityProvider: nil,
            idpIdentifier: nil,
            signInUri: signInURI,
            signOutUri: signOutURI,
            tokensUri: tokensURI,
            signInUriQueryParameters: self.signInURIQueryParameters,
            signOutUriQueryParameters: self.signOutURIQueryParameters,
            tokenUriQueryParameters: self.tokenURIQueryParameters,
            userPoolServiceConfiguration: AWSMobileClient.serviceConfiguration?.userPoolServiceConfiguration,
            signInPrivateSession: false)

        if (isCognitoAuthRegistered) {
            AWSCognitoAuth.remove(forKey: AWSMobileClientConstants.CognitoAuthRegistrationKey)
        }
        AWSCognitoAuth.registerCognitoAuth(with: cognitoAuthConfig, forKey: AWSMobileClientConstants.CognitoAuthRegistrationKey)
        isCognitoAuthRegistered = true
        let cognitoAuth = AWSCognitoAuth.init(forKey: AWSMobileClientConstants.CognitoAuthRegistrationKey)
        cognitoAuth.delegate = self
    }
}

// MARK:- AWSMobileClient Cognito configuration

public extension AWSMobileClient {

    /// Updates the service configuration for the Cognito Services
    ///
    /// - Warning: This method is intended for internal use only.
    static func updateCognitoService(userPoolConfiguration: AWSServiceConfiguration?,
                                     identityPoolConfiguration: AWSServiceConfiguration?) {
        let configuration = CognitoServiceConfiguration(userPoolServiceConfiguration: userPoolConfiguration,
                                                        identityPoolServiceConfiguration: identityPoolConfiguration)
        self.serviceConfiguration = configuration
        UserPoolOperationsHandler.serviceConfiguration = configuration
        AWSInfo.configureIdentityPoolService(configuration.identityPoolServiceConfiguration)
    }
}

struct CognitoServiceConfiguration {

    let userPoolServiceConfiguration: AWSServiceConfiguration?

    let identityPoolServiceConfiguration: AWSServiceConfiguration?
}
