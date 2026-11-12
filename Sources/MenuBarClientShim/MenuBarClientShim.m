#import "MenuBarClientShim.h"
#import <dlfcn.h>
#import <objc/message.h>

static NSString *const kFramework = @"/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";
static NSString *const kConfigurationClass = @"MBAssessmentModeConfiguration";
static NSString *const kAssertionClass = @"MBAssessmentModeAssertion";
#define kInitSelector @selector(initWithAllowedSystemItems:allowedBundleIdentifiers:)
#define kActivateSelector @selector(activateWithConfiguration:completionHandler:)

static NSError *TBError(NSString *reason) {
    return [NSError errorWithDomain:@"TopBar.NativeVisibility" code:1
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

BOOL TBVisibilityIsAvailable(void) {
    if (!dlopen(kFramework.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL)) return NO;
    Class configuration = NSClassFromString(kConfigurationClass);
    Class assertion = NSClassFromString(kAssertionClass);
    return configuration && assertion
        && [configuration instancesRespondToSelector:kInitSelector]
        && [assertion instancesRespondToSelector:kActivateSelector]
        && [assertion instancesRespondToSelector:@selector(invalidate)];
}

void TBVisibilityActivate(NSArray<NSNumber *> *allowedSystemItems,
                          NSArray<NSString *> *allowedBundleIdentifiers,
                          void (^completion)(id _Nullable, NSError *_Nullable)) {
    void (^finish)(id, NSError *) = ^(id assertion, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(assertion, error); });
    };
    if (!TBVisibilityIsAvailable()) {
        finish(nil, TBError(@"MenuBarClientCore is unavailable on this macOS"));
        return;
    }
    @try {
        // Must be NSArrays: the framework indexes into them.
        id configuration = ((id (*)(id, SEL, NSArray *, NSArray *))objc_msgSend)(
            [NSClassFromString(kConfigurationClass) alloc], kInitSelector,
            [allowedSystemItems copy], [allowedBundleIdentifiers copy]);
        id assertion = [[NSClassFromString(kAssertionClass) alloc] init];
        if (!configuration || !assertion) {
            finish(nil, TBError(@"Could not create the visibility configuration"));
            return;
        }
        ((void (*)(id, SEL, id, void (^)(NSError *)))objc_msgSend)(
            assertion, kActivateSelector, configuration, ^(NSError *error) {
                finish(error ? nil : assertion, error);
            });
    } @catch (NSException *exception) {
        finish(nil, TBError([NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]));
    }
}

void TBVisibilityInvalidate(id assertion) {
    @try {
        if ([assertion respondsToSelector:@selector(invalidate)]) {
            ((void (*)(id, SEL))objc_msgSend)(assertion, @selector(invalidate));
        }
    } @catch (NSException *exception) {
        NSLog(@"TopBar: invalidate raised %@: %@", exception.name, exception.reason);
    }
}
