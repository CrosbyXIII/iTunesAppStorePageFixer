#import <Foundation/Foundation.h>
#import "FeaturedPolicy.h"
#include <assert.h>

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *allowed = [NSArray arrayWithObjects:
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewAppsMain",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewMusicMain",
        @"https://apps.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?cc=us&id=25204",
        @"https://music.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?id=1",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewMoviesMain",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTVShowsMain",
        @"https://books.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?id=28",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?genreId=36",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewFeaturedSoftwareCategories",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewAutoSourcedGenrePage?id=6014",
        @"https://podcasts.apple.com/us/podcast/the-daily/id1200361736", nil];
    for (NSString *url in allowed) {
        NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [r setValue:@"143444-2,9" forHTTPHeaderField:@"X-Apple-Store-Front"];
        [r setValue:@"unchanged" forHTTPHeaderField:@"X-Test"];
        assert(FRPatchRequest(r));
        assert([[r valueForHTTPHeaderField:@"X-Apple-Store-Front"] isEqualToString:@"143444-2,4"]);
        assert([[r valueForHTTPHeaderField:@"X-Test"] isEqualToString:@"unchanged"]);
        assert([[[r URL] absoluteString] isEqualToString:url]);
        assert(!FRPatchRequest(r)); // Applying it twice must be harmless.
        [r setValue:@"143444-2,9" forHTTPHeaderField:@"X-Apple-Store-Front"];
        [r setHTTPMethod:@"POST"];
        assert(!FRPatchRequest(r));
    }
    NSArray *excluded = [NSArray arrayWithObjects:
        @"https://auth.itunes.apple.com/auth/v1/native/fast",
        @"https://p23-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate",
        @"https://itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/search",
        @"https://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=123",
        @"https://itunes.apple.com/WebObjects/MZSoftwareUpdate.woa/wa/viewSoftwareUpdates",
        @"https://myapp.itunes.apple.com/WebObjects/MZAppPersonalizer.woa/wa/appRecommendations?mt=8",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/iTunesURedirect?cc=us",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?id=27753&mt=10",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewFeaturedITunesUCategories",
        @"https://itunes.apple.com/us/movie/title/id123",
        @"https://books.apple.com/us/audiobook/title/id123",
        @"https://apps.apple.com.attacker.invalid/WebObjects/MZStore.woa/wa/viewGrouping",
        @"https://example.com/WebObjects/MZStore.woa/wa/viewGrouping",
        @"file:///WebObjects/MZStore.woa/wa/viewGrouping", nil];
    for (NSString *url in excluded) {
        NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [r setValue:@"143441-1,9" forHTTPHeaderField:@"X-Apple-Store-Front"];
        assert(!FRPatchRequest(r));
        assert([[r valueForHTTPHeaderField:@"X-Apple-Store-Front"] isEqualToString:@"143441-1,9"]);
    }
    assert(FRReplacementStorefront(nil) == nil);
    assert(FRReplacementStorefront(@"143441-1,4") == nil);
    assert(FRReplacementStorefront(@"143441-1,19") == nil);
    assert(FRReplacementStorefront(@",9") == nil);
    assert(FRPublicFeedURL([NSURL URLWithString:@"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?id=39"]) == nil);
    NSURL *podcasts = FRPublicFeedURL([NSURL URLWithString:@"https://podcasts.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?cc=gb&id=33"]);
    assert([[podcasts absoluteString] isEqualToString:@"https://itunes.apple.com/gb/rss/toppodcasts/limit=30/json"]);
    assert(!FRIsFeaturedURL([NSURL URLWithString:@"https://podcasts.apple.com/us/podcast/the-daily/id1200361736"]));
    NSURL *chart = FRPublicFeedURL([NSURL URLWithString:@"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?cc=us&genreId=36&selected-tab-index=1&top-ten-m=2"]);
    assert([FRQueryValue(chart,@"popId") isEqualToString:@"44"]);
    assert([FRQueryValue(chart,@"pageNumbers") isEqualToString:@"1"]);
    assert(FRPublicFeedURL([NSURL URLWithString:@"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?genreId=1"])==nil);
    puts("PASS: Featured routing, country preservation, idempotence, and excluded account/search/product/download routes");
    [pool drain];
    return 0;
}
