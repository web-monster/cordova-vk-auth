//
//  SocialVk.m

#import "SocialVk.h"
#import <VK_ios_sdk/VKBundle.h>

static NSString *VK_AUTHORIZE_URL_STRING = @"vkauthorize://authorize";

@implementation SocialVk {
    CDVInvokedUrlCommand *savedCommand;
    void (^vkCallBackBlock)(NSString *, NSString *);
    BOOL inited;
    NSMutableDictionary *loginDetails;
    NSArray *_permissions;
    VKSdk* _vkSdk;
}

@synthesize clientId;

- (void) initSocialVk:(CDVInvokedUrlCommand*)command
{
    _permissions = @[VK_PER_OFFLINE, VK_PER_EMAIL];
    CDVPluginResult* pluginResult = nil;

    if(!inited) {
        NSString *appId = [[NSString alloc] initWithString:[command.arguments objectAtIndex:0]];
        _vkSdk = [VKSdk initializeWithAppId:appId];
        [_vkSdk registerDelegate:self];
        [_vkSdk setUiDelegate:self];
        _vkSdk.uiDelegate = self;
        [VKSdk wakeUpSession:_permissions completeBlock:^(VKAuthorizationState state, NSError *err) {
            if(err) {
                NSLog(@"VK init error: %@", err);
            }
            if(state == VKAuthorizationAuthorized) {
                NSLog(@"VK user authorized with token %@", [VKSdk accessToken].accessToken);
            }
        }];
        NSLog(@"SocialVk Plugin initalized");
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(myOpenUrl:) name:CDVPluginHandleOpenURLNotification object:nil];
        inited = YES;
    }
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(UIViewController*)findViewController
{
    id vc = self.webView;
    do {
        vc = [vc nextResponder];
    } while([vc isKindOfClass:UIView.class]);
    return vc;
}

-(void)myOpenUrl:(NSNotification*)notification
{
    NSURL *url = notification.object;
    if(![url isKindOfClass:NSURL.class]) return;
    BOOL wasHandled = [VKSdk processOpenURL:url fromApplication:nil];
}

-(void) login:(CDVInvokedUrlCommand *)command
{
    NSArray *permissions = [command.arguments objectAtIndex:0];
    if(![VKSdk isLoggedIn]) {
        [self vkLoginWithPermissions:permissions andBlock:^(NSString *token, NSString *error) {
            if(token) {
                VKRequest *req = [VKRequest requestWithMethod:@"users.get" parameters:@{@"fields": @"id, nickname, first_name, last_name, sex, bdate, timezone, photo, photo_big, city, country"}];
                [req executeWithResultBlock:^(VKResponse *response) {
                    NSLog(@"User response %@", response);
                    
                    CDVPluginResult* pluginResult = nil;
                    loginDetails = [NSMutableDictionary new];
                    loginDetails[@"token"] = token;
                    if([response.json isKindOfClass:NSArray.class] && [(NSArray*)response.json count]>0 )
                        loginDetails[@"user"] = [response.json objectAtIndex:0];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:loginDetails];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } errorBlock:^(NSError *error) {
                    NSLog(@"Cant load user details");
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }];
            } else {
                NSLog(@"Cant login to VKontakte");
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }];
    } else {
        if(loginDetails) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:loginDetails];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            VKAccessToken *token = [VKSdk accessToken];
            VKRequest *req = [VKRequest requestWithMethod:@"users.get" parameters:@{@"fields": @"sex,bdate,city,country,screen_name,photo_50,photo_200_orig"}];
            [req executeWithResultBlock:^(VKResponse *response) {
                NSLog(@"User response %@", response);
                CDVPluginResult* pluginResult = nil;
                loginDetails = [NSMutableDictionary new];
                loginDetails[@"token"] = token.accessToken;
                if([response.json isKindOfClass:NSArray.class] && [(NSArray*)response.json count]>0 )
                    loginDetails[@"user"] = [response.json objectAtIndex:0];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:loginDetails];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } errorBlock:^(NSError *error) {
                NSLog(@"Cant load user details");
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
        }
    }
}

-(void) share:(CDVInvokedUrlCommand*)command {
    NSBundle *vkb = [VKBundle vkLibraryResourcesBundle];
    NSLog(@"VK Bundle path %@", vkb.bundlePath);
    
    savedCommand = command;
    NSString *sourceURL = [command.arguments objectAtIndex:0];
    NSString* description = [command.arguments objectAtIndex:1];
    NSString* imageURL = [command.arguments objectAtIndex:2];
    //NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];

    if(![VKSdk isLoggedIn]) {
        [self vkLoginWithPermissions:nil andBlock:^(NSString *token, NSString *error) {
            CDVPluginResult* pluginResult = nil;
            if(token) {
                VKShareDialogController *sh = [VKShareDialogController new];
                sh.edgesForExtendedLayout = UIRectEdgeAll;
                sh.shareLink = [[VKShareLink alloc] initWithTitle:sourceURL link:[NSURL URLWithString:sourceURL]];
                sh.text =  description;
                //sh.uploadImages = @[[VKUploadImage uploadImageWithData:imageData andParams:nil]];
                UIViewController *vc = [self findViewController];
                [sh performSelector:@selector(presentIn:) withObject:vc afterDelay:2.f];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                NSLog(@"Cant login to VKontakte");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }];
    } else {
        VKShareDialogController *sh = [VKShareDialogController new];
        sh.edgesForExtendedLayout = UIRectEdgeAll;
        sh.shareLink = [[VKShareLink alloc] initWithTitle:sourceURL link:[NSURL URLWithString:sourceURL]];
        sh.text =  description;
        //sh.uploadImages = @[[VKUploadImage uploadImageWithData:imageData andParams:nil]];
        UIViewController *vc = [self findViewController];
        sh.dismissAutomatically = YES;
        [vc presentViewController:sh animated:YES completion:nil];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void)vkLoginWithPermissions:(NSArray*)permissions andBlock:(void (^)(NSString *, NSString *))block
{
    vkCallBackBlock = [block copy];
    if(!permissions || permissions.count < 1) {
        permissions = @[VK_PER_EMAIL, VK_PER_OFFLINE];
    }

    [VKSdk authorize:permissions withOptions:VKAuthorizationOptionsUnlimitedToken|VKAuthorizationOptionsDisableSafariController|VKAuthorizationOptionsEnableProviders];
}

-(void)logout:(CDVInvokedUrlCommand *)command
{
    loginDetails = [NSMutableDictionary new];
    [VKSdk forceLogout];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - API methods

-(void)performRequest:(VKRequest*)request withCommand:(CDVInvokedUrlCommand*)command
{
    savedCommand = command;
    [request executeWithResultBlock:^(VKResponse *response) {
        savedCommand = nil;
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response.json];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } errorBlock:^(NSError *error) {
        savedCommand = nil;
        NSLog(@"VK Error: %@", error);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

-(void) users_get:(CDVInvokedUrlCommand*) command
{
    NSString* user_ids = [command.arguments objectAtIndex:0];
    NSString* fields = [command.arguments objectAtIndex:1];
    NSString* name_case = [command.arguments objectAtIndex:2];
    VKRequest *req = [[VKApi users] get:@{VK_API_USER_IDS: user_ids, VK_API_FIELDS: fields, VK_API_NAME_CASE: name_case}];
    [self performRequest:req withCommand:command];
}

-(void) users_search:(CDVInvokedUrlCommand*) command
{
    //query, sort, offset, count, fields, city, country, hometown, university_country, university, university_year, university_faculty, university_chair, sex, status, age_from, age_to, birth_day, birth_month, birth_year, online, has_photo, school_country, school_city, school_class, school, school_year, religion, interests, company, position, group_id, from_list
    id arg = [command.arguments objectAtIndex:0];
    NSDictionary *params;
    if([arg isKindOfClass:NSDictionary.class]) {
        params = arg;
    } else {
        params = @{VK_API_Q: arg};
    }
    VKRequest *req = [[VKApi users] search:params];
    [self performRequest:req withCommand:command];
}

- (void)users_isAppUser:(CDVInvokedUrlCommand*)command
{
    NSNumber *user_id = [command.arguments objectAtIndex:0];
    VKRequest *req;
    if(user_id && user_id.integerValue > 0)
        req = [[VKApi users] isAppUser:user_id.integerValue];
    else
        req = [[VKApi users] isAppUser];
    [self performRequest:req withCommand:command];
}

- (void)users_getSubscriptions:(CDVInvokedUrlCommand*)command
{
    NSNumber *user_id = [command.arguments objectAtIndex:0];
    NSNumber *extended = [command.arguments objectAtIndex:1];
    NSNumber *offset = [command.arguments objectAtIndex:2];
    NSNumber *count = [command.arguments objectAtIndex:3];
    NSString *fields = [command.arguments objectAtIndex:4];
    VKRequest *req = [[VKApi users] getSubscriptions:@{VK_API_USER_ID: user_id, VK_API_EXTENDED: extended, VK_API_OFFSET: offset, VK_API_COUNT: count, VK_API_FIELDS: fields}];
    [self performRequest:req withCommand:command];
}

- (void)users_getFollowers:(CDVInvokedUrlCommand*)command
{
    NSNumber *user_id = [command.arguments objectAtIndex:0];
    NSNumber *offset = [command.arguments objectAtIndex:1];
    NSNumber *count = [command.arguments objectAtIndex:2];
    NSString *fields = [command.arguments objectAtIndex:3];
    NSString *name_case = [command.arguments objectAtIndex:4];
    VKRequest *req = [[VKApi users] getFollowers:@{VK_API_USER_ID: user_id, VK_API_OFFSET: offset, VK_API_COUNT: count, VK_API_FIELDS: fields, VK_API_NAME_CASE: name_case}];
    [self performRequest:req withCommand:command];
}

- (void)friends_get:(CDVInvokedUrlCommand*)command
{
    NSNumber *user_id = [command.arguments objectAtIndex:0];
    NSString *order = [command.arguments objectAtIndex:1];
    NSNumber *count = [command.arguments objectAtIndex:2];
    NSNumber *offset = [command.arguments objectAtIndex:3];
    NSString *fields = [command.arguments objectAtIndex:4];
    NSString *name_case = [command.arguments objectAtIndex:5];
    VKRequest *req = [[VKApi friends] get:@{VK_API_USER_ID: user_id, VK_API_ORDER: order, VK_API_COUNT: count, VK_API_OFFSET: offset, VK_API_FIELDS: fields, VK_API_NAME_CASE: name_case}];
    [self performRequest:req withCommand:command];
}

- (void)callApiMethod:(CDVInvokedUrlCommand *)command
{
    NSString *method = [command.arguments objectAtIndex:0];
    NSDictionary *params = [command.arguments objectAtIndex:1];
    VKRequest *req = [VKRequest requestWithMethod:method parameters:params];
    [self performRequest:req withCommand:command];
}

#pragma mark - VKSdkDelegate


- (void)vkSdkAccessAuthorizationFinishedWithResult:(VKAuthorizationResult *)result;
{
    NSLog(@"VK Access authorization finished");
    if(result.error) {
        NSLog(@"VK Error %@", result.error);
        if(vkCallBackBlock) {
            vkCallBackBlock(nil, result.error.description);
            vkCallBackBlock = nil;
        } else if(savedCommand) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:result.error.description];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:savedCommand.callbackId];
        }
    }
}

- (void)vkSdkUserAuthorizationFailed;
{
    NSLog(@"VK User authorization failed");
}

- (void)vkSdkAccessTokenUpdated:(VKAccessToken *)newToken oldToken:(VKAccessToken *)oldToken;
{
    NSLog(@"VK Token %@", newToken.accessToken);
    if(vkCallBackBlock) vkCallBackBlock(newToken.accessToken, nil);
    vkCallBackBlock = nil;
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken;
{
    NSLog(@"VK Token has expired");
}


#pragma mark - VKSdkUIDelegate

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller;
{
    [[self findViewController] presentViewController:controller animated:YES completion:nil];
}

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError;
{
    NSLog(@"Need captcha %@", captchaError);
}

- (void)vkSdkWillDismissViewController:(UIViewController *)controller;
{
    NSLog(@"VK view controller will be dismissed");
}

- (void)vkSdkDidDismissViewController:(UIViewController *)controller;
{
    NSLog(@"VK view controller dismissed");
}


@end
