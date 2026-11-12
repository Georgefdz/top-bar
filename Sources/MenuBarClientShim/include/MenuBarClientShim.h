#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Bridge to macOS 27's private MenuBarClientCore framework (the allow-list behind
// assessment/exam mode). Objective-C so exceptions from a changed private API are
// caught instead of crashing. Same approach as Hidden Bar 1.11.1 (MIT).

/// Whether the framework, its classes and selectors all resolve on this macOS.
BOOL TBVisibilityIsAvailable(void);

/// Asks macOS to show only the given system items and apps; every other status
/// item is hidden until the returned assertion is invalidated or this process exits.
/// `completion` runs on the main queue.
void TBVisibilityActivate(NSArray<NSNumber *> *allowedSystemItems,
                          NSArray<NSString *> *allowedBundleIdentifiers,
                          void (^completion)(id _Nullable assertion, NSError *_Nullable error));

void TBVisibilityInvalidate(id assertion);

NS_ASSUME_NONNULL_END
