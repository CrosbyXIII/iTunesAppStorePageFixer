#import <Foundation/Foundation.h>

BOOL FRIsFeaturedURL(NSURL *url);
BOOL FRIsPodcastDetailURL(NSURL *url);
BOOL FRShouldPatchURL(NSURL *url);
NSURL *FRPublicFeedURL(NSURL *url);
NSString *FRQueryValue(NSURL *url, NSString *key);
NSString *FRReplacementStorefront(NSString *storefront);
BOOL FRPatchRequest(NSMutableURLRequest *request);
