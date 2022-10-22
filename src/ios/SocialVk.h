//
//  SocialVk.h

#import <Cordova/CDV.h>
#import <VK_ios_sdk/VKSdk.h>

@interface SocialVk : CDVPlugin <VKSdkDelegate, VKSdkUIDelegate>
{
    NSString*     clientId;
}

@property (nonatomic, retain) NSString*     clientId;

- (void)initSocialVk:(CDVInvokedUrlCommand*)command;
- (void)login:(CDVInvokedUrlCommand*)command;
- (void)share:(CDVInvokedUrlCommand*)command;
- (void)logout:(CDVInvokedUrlCommand*)command;

// API methods

- (void)users_get:(CDVInvokedUrlCommand*)command;
- (void)users_search:(CDVInvokedUrlCommand*)command;
- (void)users_isAppUser:(CDVInvokedUrlCommand*)command;
- (void)users_getSubscriptions:(CDVInvokedUrlCommand*)command;
- (void)users_getFollowers:(CDVInvokedUrlCommand*)command;

- (void)friends_get:(CDVInvokedUrlCommand*)command;
- (void)callApiMethod:(CDVInvokedUrlCommand*)command;

@end
