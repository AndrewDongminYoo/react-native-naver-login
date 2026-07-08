#import "NaverLogin.h"
#import <NaverThirdPartyLogin/NaverThirdPartyLogin.h>
#import <React/RCTUtils.h>

// Private category: declares NaverThirdPartyLoginConnectionDelegate conformance
// and internal state. This keeps the public .h file free of SDK headers so it
// compiles before `pod install` runs.
@interface NaverLogin () <NaverThirdPartyLoginConnectionDelegate>
// Stored while a login() Promise is in flight. nil when idle.
@property (nonatomic, copy, nullable) RCTPromiseResolveBlock loginResolve;
@property (nonatomic, copy, nullable) RCTPromiseRejectBlock loginReject;
// Stored while a refreshToken() Promise is in flight. nil when idle.
@property (nonatomic, copy, nullable) RCTPromiseResolveBlock refreshResolve;
@property (nonatomic, copy, nullable) RCTPromiseRejectBlock refreshReject;
// Stored while a deleteToken() Promise is in flight. nil when idle.
@property (nonatomic, copy, nullable) RCTPromiseResolveBlock deleteTokenResolve;
@property (nonatomic, copy, nullable) RCTPromiseRejectBlock deleteTokenReject;
@end

@implementation NaverLogin

// -------------------------------------------------------------------------
// TurboModule boilerplate
// -------------------------------------------------------------------------

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeNaverLoginSpecJSI>(params);
}

+ (NSString *)moduleName
{
    return @"NaverLogin";
}

// -------------------------------------------------------------------------
// initialize
// -------------------------------------------------------------------------

- (void)initialize:(JS::NativeNaverLogin::NaverLoginInitParams &)params
{
    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];

    conn.consumerKey    = params.consumerKey();
    conn.consumerSecret = params.consumerSecret();
    conn.appName        = params.appName();

    NSString *serviceScheme = params.serviceUrlSchemeIOS();
    if (serviceScheme != nil) {
        conn.serviceUrlScheme = serviceScheme;
    }

    auto disableApp = params.disableNaverAppAuthIOS();
    conn.isNaverAppOauthEnable = !(disableApp.has_value() && disableApp.value());

    // Observe RCTLinkingManager URL events so the host app's AppDelegate
    // does NOT need a custom openURL: handler.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"RCTOpenURLNotification"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleOpenURL:)
                                                 name:@"RCTOpenURLNotification"
                                               object:nil];
}

- (void)handleOpenURL:(NSNotification *)notification
{
    NSURL *url = notification.userInfo[@"url"];
    if (url) {
        [[NaverThirdPartyLoginConnection getSharedInstance]
         application:[UIApplication sharedApplication]
         openURL:url
         options:@{}];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// -------------------------------------------------------------------------
// login
// -------------------------------------------------------------------------

- (void)login:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    if (self.loginResolve != nil) {
        reject(@"LOGIN_IN_PROGRESS", @"A login request is already in progress.", nil);
        return;
    }

    self.loginResolve = resolve;
    self.loginReject  = reject;

    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];
    conn.delegate = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [conn requestThirdPartyLogin];
    });
}

// -------------------------------------------------------------------------
// refreshToken — reissue the access token using the stored refresh token
// -------------------------------------------------------------------------

- (void)refreshToken:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    if (self.refreshResolve != nil) {
        reject(@"REFRESH_IN_PROGRESS", @"A refreshToken request is already in progress.", nil);
        return;
    }

    self.refreshResolve = resolve;
    self.refreshReject  = reject;

    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];
    conn.delegate = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [conn requestAccessTokenWithRefreshToken];
    });
}

// -------------------------------------------------------------------------
// logout — clears local tokens only (no server revocation)
// -------------------------------------------------------------------------

- (void)logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    [[NaverThirdPartyLoginConnection getSharedInstance] resetToken];
    resolve(nil);
}

// -------------------------------------------------------------------------
// deleteToken — server revocation then local clear
// -------------------------------------------------------------------------

- (void)deleteToken:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    self.deleteTokenResolve = resolve;
    self.deleteTokenReject  = reject;

    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];
    conn.delegate = self;
    [conn requestDeleteToken];
}

// -------------------------------------------------------------------------
// getProfile
// -------------------------------------------------------------------------

- (void)getProfile:(NSString *)accessToken
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject
{
    NSURL *url = [NSURL URLWithString:@"https://openapi.naver.com/v1/nid/me"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", accessToken]
       forHTTPHeaderField:@"Authorization"];

    [[[NSURLSession sharedSession]
      dataTaskWithRequest:req
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            reject(@"PROFILE_ERROR", error.localizedDescription, error);
            return;
        }
        if (!data) {
            reject(@"PROFILE_ERROR", @"Empty response body", nil);
            return;
        }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (http.statusCode < 200 || http.statusCode >= 300) {
            reject(@"PROFILE_HTTP_ERROR",
                   [NSString stringWithFormat:@"HTTP %ld", (long)http.statusCode],
                   nil);
            return;
        }
        NSError *parseError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data
                                                  options:0
                                                    error:&parseError];
        if (parseError || ![json isKindOfClass:[NSDictionary class]]) {
            reject(@"PARSE_ERROR",
                   parseError ? parseError.localizedDescription : @"Unexpected response format",
                   parseError);
            return;
        }
        resolve(json);
    }] resume];
}

// -------------------------------------------------------------------------
// NaverThirdPartyLoginConnectionDelegate
// -------------------------------------------------------------------------

- (void)oauth20ConnectionDidFinishRequestACTokenWithAuthCode
{
    [self resolveLoginWithConnection:[NaverThirdPartyLoginConnection getSharedInstance]];
}

- (void)oauth20ConnectionDidFinishRequestACTokenWithRefreshToken
{
    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];

    // An explicit refreshToken() call takes priority over the login path: the
    // same delegate fires for both, so route by which Promise is pending.
    if (self.refreshResolve) {
        self.refreshResolve([self successResultForConnection:conn]);
        self.refreshResolve = nil;
        self.refreshReject  = nil;
        return;
    }

    [self resolveLoginWithConnection:conn];
}

- (void)oauth20ConnectionDidFinishDeleteToken
{
    // Server revocation succeeded — clear local tokens now.
    [[NaverThirdPartyLoginConnection getSharedInstance] resetToken];
    if (self.deleteTokenResolve) {
        self.deleteTokenResolve(nil);
        self.deleteTokenResolve = nil;
        self.deleteTokenReject  = nil;
    }
}

// Required delegate method: called for login failures and deleteToken failures.
- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)oauthConnection
        didFailWithError:(NSError *)error
{
    if (self.loginResolve) {
        // CANCELBYUSER == 2 per NaverThirdPartyConstantsForApp.h
        BOOL isCancel = (error.code == CANCELBYUSER);
        NSDictionary *result = @{
            @"isSuccess": @NO,
            @"failureResponse": @{
                @"message": error.localizedDescription ?: @"Unknown error",
                @"isCancel": @(isCancel),
            }
        };
        self.loginResolve(result);
        self.loginResolve = nil;
        self.loginReject  = nil;
    } else if (self.refreshResolve) {
        // refreshToken() mirrors login(): failures resolve as { isSuccess: NO },
        // they do not reject. Lets callers treat an expired refresh token as a
        // signal to re-login rather than an exception.
        BOOL isCancel = (error.code == CANCELBYUSER);
        NSDictionary *result = @{
            @"isSuccess": @NO,
            @"failureResponse": @{
                @"message": error.localizedDescription ?: @"Unknown error",
                @"isCancel": @(isCancel),
            }
        };
        self.refreshResolve(result);
        self.refreshResolve = nil;
        self.refreshReject  = nil;
    } else if (self.deleteTokenReject) {
        self.deleteTokenReject(@"DELETE_TOKEN_FAILED",
                               error.localizedDescription ?: @"Unknown error",
                               error);
        self.deleteTokenResolve = nil;
        self.deleteTokenReject  = nil;
    }
}

// Optional delegate method: fired when the auth flow fails with a typed reason.
// Handles cancel before didFailWithError: clears loginResolve.
- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)oauthConnection
  didFailAuthorizationWithReceiveType:(THIRDPARTYLOGIN_RECEIVE_TYPE)receiveType
{
    if (receiveType == CANCELBYUSER && self.loginResolve) {
        NSDictionary *result = @{
            @"isSuccess": @NO,
            @"failureResponse": @{
                @"message": @"User cancelled.",
                @"isCancel": @YES,
            }
        };
        self.loginResolve(result);
        self.loginResolve = nil;
        self.loginReject  = nil;
    }
}

// -------------------------------------------------------------------------
// Private helpers
// -------------------------------------------------------------------------

- (NSDictionary *)successResultForConnection:(NaverThirdPartyLoginConnection *)conn
{
    NSString *expiresAt = conn.accessTokenExpireDate
        ? [NSString stringWithFormat:@"%.0f",
           [conn.accessTokenExpireDate timeIntervalSince1970]]
        : @"";

    return @{
        @"isSuccess": @YES,
        @"successResponse": @{
            @"accessToken":              conn.accessToken  ?: @"",
            @"refreshToken":             conn.refreshToken ?: @"",
            @"expiresAtUnixSecondString": expiresAt,
            @"tokenType":                conn.tokenType    ?: @"",
        }
    };
}

- (void)resolveLoginWithConnection:(NaverThirdPartyLoginConnection *)conn
{
    if (self.loginResolve) {
        self.loginResolve([self successResultForConnection:conn]);
        self.loginResolve = nil;
        self.loginReject  = nil;
    }
}

@end
