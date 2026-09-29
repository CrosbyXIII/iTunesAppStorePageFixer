#import <Foundation/Foundation.h>

// Returns nil for unrecognized pages; the relay then passes the original through.
NSData *FRIPadPage(NSData *data, NSURL *url);
