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

    conn.consumerKey    = [NSString stringWithUTF8String:params.consumerKey().c_str()];
    conn.consumerSecret = [NSString stringWithUTF8String:params.consumerSecret().c_str()];
    conn.appName        = [NSString stringWithUTF8String:params.appName().c_str()];

    auto serviceScheme = params.serviceUrlSchemeIOS();
    if (serviceScheme.has_value()) {
        conn.serviceUrlScheme = [NSString stringWithUTF8String:serviceScheme.value().c_str()];
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
// logout
// -------------------------------------------------------------------------

- (void)logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    [[NaverThirdPartyLoginConnection getSharedInstance] requestDeleteToken];
    resolve(nil);
}

// -------------------------------------------------------------------------
// deleteToken
// -------------------------------------------------------------------------

- (void)deleteToken:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
    NaverThirdPartyLoginConnection *conn = [NaverThirdPartyLoginConnection getSharedInstance];
    [conn requestDeleteToken];
    [conn requestUnlinkToken];
    resolve(nil);
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
    [self resolveLoginWithConnection:[NaverThirdPartyLoginConnection getSharedInstance]];
}

- (void)oauth20ConnectionDidFinishDeleteToken
{
    // logout/deleteToken resolve immediately; nothing to do here.
}

- (void)oauth20Connection:(NaverThirdPartyLoginConnection *)connection
     didFailWithRequestType:(NaverThirdPartyLoginConnectionRequestType)requestType
{
    NSString *errorCode = connection.lastErrorCode ?: @"";
    BOOL isCancel = [errorCode isEqualToString:@"user_cancel"];

    NSDictionary *result = @{
        @"isSuccess": @NO,
        @"failureResponse": @{
            @"message": connection.lastErrorDescription ?: @"Unknown error",
            @"isCancel": @(isCancel),
        }
    };

    if (self.loginResolve) {
        self.loginResolve(result);
        self.loginResolve = nil;
        self.loginReject  = nil;
    }
}

// -------------------------------------------------------------------------
// Private helpers
// -------------------------------------------------------------------------

- (void)resolveLoginWithConnection:(NaverThirdPartyLoginConnection *)conn
{
    NSDictionary *result = @{
        @"isSuccess": @YES,
        @"successResponse": @{
            @"accessToken":              conn.accessToken  ?: @"",
            @"refreshToken":             conn.refreshToken ?: @"",
            @"expiresAtUnixSecondString": conn.expiresAt   ?: @"",
            @"tokenType":                conn.tokenType    ?: @"",
        }
    };

    if (self.loginResolve) {
        self.loginResolve(result);
        self.loginResolve = nil;
        self.loginReject  = nil;
    }
}

@end
